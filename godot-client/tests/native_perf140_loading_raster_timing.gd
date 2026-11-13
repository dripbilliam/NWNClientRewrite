extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Prework=preload("res://systems/native_data/prework_store.gd")
const Writes=preload("res://systems/native_data/prepared_write_queue.gd")
const Identity=preload("res://systems/native_data/scoped_processor_identity.gd")
var packets: Array=[]
var failures: Array=[]
func argument(prefix: String,fallback: String="") -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return fallback
func _initialize() -> void: call_deferred("run")
func ordered(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary=value.duplicate(); result.clear(); var keys: Array=value.keys(); keys.sort_custom(func(a,b):return var_to_bytes(a).hex_encode()<var_to_bytes(b).hex_encode())
		for key in keys: result[key]=ordered(value[key])
		return result
	if value is Array:
		var result: Array=value.duplicate()
		for index in result.size(): result[index]=ordered(value[index])
		return result
	return value
func run() -> void:
	var child: Variant=load("res://systems/native_data/prework_raster_children.gd") if FileAccess.file_exists("res://systems/native_data/prework_raster_children.gd") else null
	var began:=Time.get_ticks_usec(); var phase:=argument("--phase="); var names:=argument("--models=").split(",",false); var expected: Dictionary={}
	var checkpoint:=argument("--checkpoint=")
	if phase=="prepared-read":
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(checkpoint))
		if parsed is Dictionary: expected=parsed
		else: failures.append("Prepared checkpoint unavailable")
	var mount_began:=Time.get_ticks_usec(); var catalog:=Recorded.new()
	if not catalog.mount(argument("--recorded-catalog=")): failures.append(catalog.failure)
	var mount_us:=Time.get_ticks_usec()-mount_began
	# Observe initialization separately; production scheduling is unchanged.
	# Older frozen candidates have no executable proof and remain readable.
	var engine_identity_us: Variant=null; var engine_fingerprint: Variant=null
	if Identity.status().has("engine_fingerprint"):
		var identity_owner: RefCounted=Identity.new()
		var engine_began:=Time.get_ticks_usec(); var actual_engine: Variant=identity_owner.call("engine_identity")
		engine_identity_us=Time.get_ticks_usec()-engine_began; engine_fingerprint=Identity.status().get("engine_fingerprint")
		if not Identity.valid_digest(actual_engine): failures.append("Actual executable proof unavailable in timing cohort")
	var identity_began:=Time.get_ticks_usec(); var identities: Dictionary={}
	for kind in ["static-model","actor-model","gui-icon-v1"]: identities[kind]=Prework.processor_identity(kind)
	var identity_us:=Time.get_ticks_usec()-identity_began
	var service:=Assets.new(); root.add_child(service); service.maximum_workers=1; service.cache_directory=argument("--cache-root="); service.prework_write=phase=="populate"; service.configure(catalog); service.completed.connect(func(_id,result):packets.append(result))
	var samples: Array=[]; var actual: Dictionary={}; var rounds:=2 if phase=="prepared-read" else 1
	for round_index in rounds:
		for name in names:
			var request_began:=Time.get_ticks_usec(); var id: int=service.request(name,2002,"static-model"); var deadline:=Time.get_ticks_msec()+20000
			while packets.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
			var elapsed:=Time.get_ticks_usec()-request_began
			if id<0 or packets.is_empty(): failures.append("Request failed/timed out: "+name); continue
			var result: Dictionary=packets.pop_front()
			# Measurement ends before data verification/serialization below.
			samples.append({"name":name,"round":round_index,"request_us":elapsed,"worker_ms":result.get("worker_ms"),"prework_hit":result.get("prework_hit",false),"memory_hit":result.get("memory_cache_hit",false),"prework_saved":result.get("prework_saved",false),"phases":result.get("phases",{})})
			if not str(result.get("error","")).is_empty(): failures.append(name+": "+str(result.error)); continue
			var hash:=Cache.digest(var_to_bytes(ordered(service.bundle_content(result)))); actual[name]={"data_hash":hash,"source_sha256":result.sha256}
			if phase=="populate" and (bool(result.get("prework_hit",false)) or not bool(result.get("prework_saved",false))): failures.append("Populate was not a cold final write: "+name)
			if phase=="runtime-cold" and bool(result.get("prework_hit",false)): failures.append("Runtime cold unexpectedly had a final artifact: "+name)
			if phase=="prepared-read":
				if round_index==0 and not bool(result.get("prework_hit",false)): failures.append("Fresh-process warm request missed its final artifact: "+name)
				if round_index==1 and not bool(result.get("memory_cache_hit",false)): failures.append("Second pass missed the completed-model memory cache: "+name)
				if actual[name]!=expected.get(name): failures.append("Full packet/source checkpoint mismatch: "+name)
	if phase=="populate":
		var file:=FileAccess.open(checkpoint,FileAccess.WRITE); file.store_string(JSON.stringify(actual)); file.close()
	var writer_before:=Writes.snapshot(); var close_began:=Time.get_ticks_usec()
	service.close(); service.free(); var close_us:=Time.get_ticks_usec()-close_began; var writer_after:=Writes.snapshot(); catalog.preparation_cache().clear(); catalog.decoded_cache().clear()
	var proof:={"success":failures.is_empty() and actual.size()==names.size(),"phase":phase,"enabled":bool(child!=null and child.enabled()),"failures":failures,"catalog_mount_us":mount_us,"engine_identity_us":engine_identity_us,"engine_fingerprint":engine_fingerprint,"processor_identity_us":identity_us,"phase_total_us":Time.get_ticks_usec()-began,"writer_close_us":close_us,"writer_before_close":writer_before,"writer_after_close":writer_after,"samples":samples,"identities":identities,"child_stats":child.snapshot() if child!=null else {},"scope":"Headless asset preparation/read timing; request clock excludes verification; phase total includes verification/mount/identity. OS cache uncontrolled/warm. No GPU/FPS/server claim."}
	var report:=FileAccess.open(argument("--report="),FileAccess.WRITE); report.store_string(JSON.stringify(proof)); report.close(); print(JSON.stringify({"success":proof.success,"phase":phase,"failures":failures})); quit(0 if proof.success else 1)
