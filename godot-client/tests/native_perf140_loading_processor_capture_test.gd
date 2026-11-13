extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Identity=preload("res://systems/native_data/scoped_processor_identity.gd")
var checks:=0
var failures: Array=[]
var packets: Array=[]
class Overrides:
	extends RefCounted
	var source
	var overrides: Dictionary={}
	var failure:=""
	var stats: Dictionary:
		get: return source.stats
	func fork():
		var copy:=Overrides.new(); copy.source=source.fork(); copy.overrides=overrides; return copy
	func preparation_cache(): return source.preparation_cache()
	func decoded_cache(): return source.decoded_cache()
	func has_resource(name: String,type: int) -> bool: return source.has_resource(name,type)
	func raster_location(name: String) -> Dictionary: return source.raster_location(name)
	func recorded_texture_miss(name: String) -> bool: return source.recorded_texture_miss(name)
	func get_resource(name: String,type: int) -> PackedByteArray:
		var key:=name.to_lower()+":"+str(type)
		if overrides.has(key): failure=""; return overrides[key].duplicate()
		var bytes: PackedByteArray=source.get_resource(name,type); failure=source.failure; return bytes
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func argument(prefix: String,fallback: String="") -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return fallback
func _initialize() -> void: call_deferred("run")
func canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary={}; var keys: Array=value.keys()
		keys.sort_custom(func(a,b): return var_to_bytes(a).hex_encode()<var_to_bytes(b).hex_encode())
		for key in keys: result[key]=canonical(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for row in value: result.append(canonical(row))
		return result
	return value
func data_equal(actual: Dictionary,expected: Dictionary) -> bool:
	return var_to_bytes(canonical(data_view(actual)))==var_to_bytes(canonical(data_view(expected)))
func data_view(content: Dictionary) -> Dictionary:
	# These are decoder/publication observations, not model/image data. Preserve
	# the raw envelope separately and never strip arbitrary nested field names.
	var view:=content.duplicate()
	for field in ["textures","emitter_textures"]:
		if not content.get(field) is Dictionary: continue
		var textures: Dictionary=content[field].duplicate()
		for name in textures:
			if not textures[name] is Dictionary: continue
			var packet: Dictionary=textures[name].duplicate()
			for key in ["cache_hit","memory_decode_hit","memory_cache_hit","timings"]: packet.erase(key)
			textures[name]=packet
		view[field]=textures
	if content.get("dependencies") is Array:
		var dependencies: Array=[]
		for original in content.dependencies:
			var row: Dictionary=original.duplicate()
			for key in ["cache_hit","read_ms","timings"]: row.erase(key)
			dependencies.append(row)
		view.dependencies=dependencies
	return view
func request(service,name: String) -> Dictionary:
	var id: int=service.request(name,2002,"static-model",{"icon_descriptor":[name]}); check(id>0,"real worker admits "+name)
	var deadline:=Time.get_ticks_msec()+20000
	while packets.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not packets.is_empty(),"real worker finishes "+name)
	return packets.pop_front() if not packets.is_empty() else {"error":"timeout"}
func run() -> void:
	var phase:=argument("--phase=")
	var catalog:=Recorded.new(); check(catalog.mount(argument("--recorded-catalog=")),"sealed recorded catalog mounts read-only")
	var reader:=Overrides.new(); reader.source=catalog
	var model_names:=PackedStringArray(["ttu01_w06_01","plc_s07"])
	var service:=Assets.new(); root.add_child(service); service.maximum_workers=1; service.cache_directory=argument("--cache-root="); service.prework_write=true; service.prework_read=true; service.configure(reader)
	service.completed.connect(func(_id,result): packets.append(result))
	var baseline_directory:=argument("--baseline-root="); var cases: Array=[]
	for index in model_names.size():
		var name: String=model_names[index]
		var raw: PackedByteArray=catalog.get_resource(name,2002)
		check(catalog.failure.is_empty() and not raw.is_empty(),"actual sealed MDL payload validates checksum: "+name)
		var original_sha:=Cache.digest(raw)
		var path:=baseline_directory.path_join(name+".bin")
		var expected: Dictionary={}
		if phase!="cold":
			var previous:=FileAccess.open(path,FileAccess.READ)
			check(previous!=null,"cold checkpoint exists for "+name)
			if previous!=null: expected=previous.get_var(false); previous.close()
		if phase=="changed-source" and index==0:
			var changed:=raw.duplicate()
			if changed.size()>=4 and changed.decode_u32(0)==0: changed.append(0)
			else: changed.append_array("\n# Owned changed-source fixture\n".to_utf8_buffer())
			reader.overrides[name+":2002"]=changed
			raw=changed
			check(Cache.digest(raw)!=original_sha,"private same-name source bytes have a distinct actual digest")
		if phase=="cold":
			# Prove the real MDL path cannot warm from a legacy lower derivative.
			var cache:=Cache.new(); check(cache.configure(service.cache_directory),"owned lower cache configures")
			var legacy:=Cache.key(Cache.digest(raw),"mdl-original:2002:emitter-3:reference-1:clip-duration-1:classification-1:mesh-area-1:hit-faces-1:ambient-1:vertex-color-1")
			if service.mesh_preparation_enabled: legacy=Cache.key(legacy,service.mesh_revision())
			check(cache.save_data(legacy,Cache.digest(raw),"mdl-original",{"legacy_marker":99}),"legacy real-MDL lower entry is deliberately isolated")
		var result: Dictionary=await request(service,name)
		check(str(result.get("error","")).is_empty(),phase+" real captured model prepares: "+name)
		if not str(result.get("error","")).is_empty(): continue
		check(result.sha256==Cache.digest(raw),phase+" root digest follows returned bytes: "+name)
		check(str(result.get("prework_icon_key","")).is_empty()==(phase=="relevant-drift"),phase+" actual worker accepts original Array icon descriptors: "+name)
		check(result.value is Dictionary and not result.value.has("legacy_marker") and result.value.get("nodes",[]).size()>0,phase+" real geometry bypasses legacy lower poison: "+name)
		var content: Dictionary=service.bundle_content(result)
		var raw_bundle:=FileAccess.open(argument("--report=").get_base_dir().path_join(name+".bin"),FileAccess.WRITE)
		raw_bundle.store_var(content,false); raw_bundle.close()
		var hit:=bool(result.get("prework_hit",false))
		if phase=="cold":
			check(not hit and bool(result.get("prework_saved",false)),"cold captured model writes a fresh final bundle: "+name)
			var checkpoint:=FileAccess.open(path,FileAccess.WRITE); checkpoint.store_var(content,false); checkpoint.close()
		elif phase in ["warm","hud-warm"]:
			check(hit,"unchanged actual data graph reuses final saved artifact: "+name)
			check(content==expected,"warm captured geometry/textures/dependencies are exactly identical: "+name)
		elif phase in ["relevant-drift","relevant-regenerated"]:
			check(not hit,"relevant preparation source edit never reuses old final artifact: "+name)
			check(data_equal(content,expected),"comment-only source edit computes exactly identical data apart from explicit observation envelopes: "+name)
		elif phase=="changed-source":
			check(hit==(index!=0),"only the changed same-name source misses its old final artifact: "+name)
			check(content.value==expected.value and data_view(content).textures==data_view(expected).textures,"private trailing/comment data preserves actual model geometry/textures: "+name)
			if index==0: check(result.sha256!=expected.sha256,"same-name changed bytes cannot retain original source identity")
		cases.append({"name":name,"phase":phase,"original_sha256":original_sha,"actual_sha256":result.sha256,"prework_hit":hit,"prework_saved":result.get("prework_saved",false),"nodes":result.value.nodes.size(),"textures":content.get("textures",{}).size(),"raw_envelope_hash":Cache.digest(var_to_bytes(content)),"data_hash":Cache.digest(var_to_bytes(canonical(data_view(content))))})
		catalog.preparation_cache().clear(); catalog.decoded_cache().clear()
	var identity:=Identity.resolve("static-model")
	check(identity.is_empty()==(phase=="relevant-drift"),"processor proof is unavailable only for deliberate unregenerated source drift")
	service.close(); service.free(); catalog.preparation_cache().clear(); catalog.decoded_cache().clear()
	var proof:={"success":failures.is_empty(),"phase":phase,"checks":checks,"failures":failures,"cases":cases,"processor_identity":identity,"identity_status":Identity.status(),"data_comparison_omits":["textures.<name>.cache_hit","textures.<name>.memory_decode_hit","textures.<name>.memory_cache_hit","textures.<name>.timings","emitter_textures.<name>.cache_hit","emitter_textures.<name>.memory_decode_hit","emitter_textures.<name>.memory_cache_hit","emitter_textures.<name>.timings","dependencies[<row>].cache_hit","dependencies[<row>].read_ms","dependencies[<row>].timings"],"raw_bundles_preserved":true,"server_connections":0,"graphics":0,"timing_claim":false}
	var report:=FileAccess.open(argument("--report="),FileAccess.WRITE); report.store_string(JSON.stringify(proof)); report.close()
	print(JSON.stringify({"success":proof.success,"phase":phase,"checks":checks,"failures":failures})); quit(0 if proof.success else 1)
