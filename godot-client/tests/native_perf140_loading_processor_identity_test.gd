extends SceneTree
const Identity=preload("res://systems/native_data/scoped_processor_identity.gd")
const Prework=preload("res://systems/native_data/prework_store.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
var checks:=0
var failures: Array=[]
class Reader:
	extends RefCounted
	var failure:=""
	var bytes:=PackedByteArray([1,2,3])
	var present:=true
	var selected:={"name":"test","type":3,"provider":"base"}
	var missing:=false
	func get_resource(_name: String,_type: int) -> PackedByteArray: return bytes.duplicate()
	func has_resource(_name: String,_type: int) -> bool: return present
	func raster_location(_name: String) -> Dictionary: return selected.duplicate(true)
	func recorded_texture_miss(_name: String) -> bool: return missing
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func argument(prefix: String,fallback: String="") -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return fallback
func graph_for(kind: String) -> Dictionary:
	return {"ready":true,"kind":kind,"files":[{"path":"systems/a.gd","sha256":"a".repeat(64)},{"path":"systems/b.gd","sha256":"b".repeat(64)}],"libraries":[".cache/native-test.dll"],"argument_prefixes":[],"environment":[],"native_classes":[]}
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var candidate:=argument("--expect-scoped=")=="true"
	var description:={"format":Identity.FORMAT,"generator":"c".repeat(64)}
	var context:={"engine":{"version":"fixture"},"engine_sha256":"8".repeat(64),"arguments":[],"environment":[],"classes":[],"schema":Identity.FORMAT,"renderer":["fixture-method","fixture-driver","fixture-display"]}
	var hashes:={"systems/a.gd":"a".repeat(64),"systems/b.gd":"b".repeat(64),".cache/native-test.dll":"d".repeat(64)}
	var reader: Callable=func(relative: String) -> String: return str(hashes.get(relative,""))
	var kinds:=["static-model","actor-model","gui-icon-v1","finished-icon-v1","rejection:static-model","rejection:actor-model","rejection:gui-icon-v1"]
	var identities: Array=[]
	for kind in kinds:
		var graph:=graph_for(kind)
		var original:=graph.duplicate(true)
		var result:=Identity.verify(kind,description,graph,reader,context)
		check(Identity.valid_digest(result.identity) and result.error.is_empty(),kind+" accepts a complete exact source graph")
		check(result.sources==2 and result.libraries==1,kind+" counts exact proof owners")
		check(result==Identity.verify(kind,description,graph,reader,context),kind+" deterministic identity")
		check(graph==original,kind+" graph ownership stays detached")
		identities.append(result.identity)
		hashes["systems/a.gd"]="e".repeat(64)
		check(Identity.verify(kind,description,graph,reader,context).identity.is_empty(),kind+" changed source fails closed before regeneration")
		graph.files[0].sha256=hashes["systems/a.gd"]
		check(Identity.verify(kind,description,graph,reader,context).identity!=result.identity,kind+" regenerated exact source changes namespace")
		hashes["systems/a.gd"]="a".repeat(64); graph=original.duplicate(true)
		hashes[".cache/native-test.dll"]="f".repeat(64)
		check(Identity.verify(kind,description,graph,reader,context).identity!=result.identity,kind+" actual DLL bytes change namespace")
		hashes[".cache/native-test.dll"]=""
		check(Identity.verify(kind,description,graph,reader,context).identity.is_empty(),kind+" missing native library fails closed")
		hashes[".cache/native-test.dll"]="d".repeat(64)
		for field in ["engine","engine_sha256","arguments","environment","classes","schema"]:
			var changed:=context.duplicate(true); changed[field]="changed-context"
			check(Identity.verify(kind,description,graph,reader,changed).identity!=result.identity,kind+" captures actual runtime "+field)
		graph.ready=false
		check(Identity.verify(kind,description,graph,reader,context).identity.is_empty(),kind+" unresolved graph cannot produce a reusable key")
		graph=original.duplicate(true); graph.files[0].path="../outside.gd"
		check(Identity.verify(kind,description,graph,reader,context).identity.is_empty(),kind+" path traversal rejected")
		graph=original.duplicate(true); graph.files.append(graph.files[0])
		check(Identity.verify(kind,description,graph,reader,context).identity.is_empty(),kind+" duplicate/out-of-order proof rows rejected")
		graph=original.duplicate(true); graph.files[0].sha256="A".repeat(64)
		check(Identity.verify(kind,description,graph,reader,context).identity.is_empty(),kind+" malformed source digest rejected")
		graph=original.duplicate(true); graph.erase("libraries")
		check(Identity.verify(kind,description,graph,reader,context).identity.is_empty(),kind+" malformed graph shape rejected")
	var unique: Dictionary={}
	for identity in identities: unique[identity]=true
	check(unique.size()==kinds.size(),"all artifact kinds have distinct namespaces")
	check(Identity.verify("unknown",description,graph_for("unknown"),reader,context).identity.is_empty(),"unknown decoder fails closed")
	var wrong:=description.duplicate(); wrong.generator="manual-v1"
	check(Identity.verify("static-model",wrong,graph_for("static-model"),reader,context).identity.is_empty(),"manual revision cannot replace generator source fingerprint")
	check(Identity.verify("static-model",description,graph_for("static-model"),Callable(),context).identity.is_empty(),"missing byte reader fails closed")
	check(Identity.verify("static-model",description,graph_for("static-model"),reader,{}).identity.is_empty(),"missing runtime attestation fails closed")
	var no_renderer:=context.duplicate(true); no_renderer.erase("renderer")
	check(Identity.verify("finished-icon-v1",description,graph_for("finished-icon-v1"),reader,no_renderer).identity.is_empty(),"finished pixels require actual renderer context")
	for index in 3:
		var renderer_changed:=context.duplicate(true); renderer_changed.renderer[index]="changed-renderer"
		check(Identity.verify("finished-icon-v1",description,graph_for("finished-icon-v1"),reader,renderer_changed).identity!=identities[3],"finished pixels separate actual renderer attribute "+str(index))
	for kind in kinds:
		check(Identity.runtime_context(graph_for(kind)).has("renderer")== (kind=="finished-icon-v1"),kind+" queries renderer context only for calculated pixels")
		var resolved:=Identity.resolve(kind)
		check(Identity.valid_digest(resolved)==candidate,kind+" real private project validates only its exact source graph")
		check(Identity.resolve(kind)==resolved,kind+" process identity is memoized deterministically")
	var status:=Identity.status(); var reads:=int(status.source_reads)
	status.identities.clear(); status.failures.clear()
	check(Identity.status().identities.size()==kinds.size(),"diagnostic views cannot mutate live identity memo")
	for kind in kinds: Identity.resolve(kind)
	check(int(Identity.status().source_reads)==reads,"repeated resolution never rehashes a source or DLL")
	var key:=Prework.request_key("test",2002,"static-model",{},Cache.digest(PackedByteArray([1,2,3])),[true,true,"fixture"])
	check(Identity.valid_digest(key),"normal valid model request remains usable")
	if candidate:
		check(Prework.request_key("test",2002,"unknown",{},"a".repeat(64),[]).is_empty(),"unknown model request cannot manufacture an optional key")
		var owner=Prework.new()
		check(str(owner.call("icon_request_key","",{})).is_empty(),"empty parent cannot manufacture a pixel key")
		check(str(owner.call("rejection_request_key","","static-model")).is_empty(),"empty parent cannot manufacture a rejection key")
		check(str(owner.call("rejection_request_key",key,"unknown")).is_empty(),"unknown rejection kind cannot manufacture a key")
		check(Identity.valid_digest(owner.call("icon_request_key",key,{})),"finished icon uses its own complete processor proof")
		check(Identity.valid_digest(owner.call("icon_request_key",key,["item","fixture"])),"actual item icon Array descriptor contract remains supported")
		check(Identity.valid_digest(owner.call("icon_request_key",key,["gui:fixture:up"])),"actual GUI model Array descriptor contract remains supported")
		check(owner.call("icon_request_key",key,["one"])!=owner.call("icon_request_key",key,["two"]),"different original Array descriptors preserve distinct pixel keys")
		check(Identity.valid_digest(owner.call("rejection_request_key",key,"static-model")),"rejection uses its own complete policy proof")
	var saved=Prework.new(); check(saved.configure(argument("--cache-root=")),"isolated saved cache configures")
	var source:=Reader.new()
	var inputs:=[{"operation":"bytes","name":"test","type":2002,"sha256":Cache.digest(source.bytes)},{"operation":"exists","name":"test","type":2002,"present":true},{"operation":"raster","name":"test","selected":source.selected.duplicate(true)},{"operation":"missing","name":"test","missing":false}]
	var ticket:=int(saved.generation())
	check(saved.save_entry(key,inputs,{"marker":17},ticket),"normal data bundle persists with original checksum/publication owner")
	check(saved.load_entry(key,source).get("marker")==17,"unchanged actual source facts permit reuse")
	source.bytes[0]=9
	check(saved.load_entry(key,source).is_empty(),"actual model byte changes still invalidate saved entry")
	source.bytes[0]=1; source.present=false
	check(saved.load_entry(key,source).is_empty(),"actual lookup presence changes still invalidate saved entry")
	source.present=true; source.selected.provider="override"
	check(saved.load_entry(key,source).is_empty(),"actual raster winner changes still invalidate saved entry")
	source.selected.provider="base"; source.missing=true
	check(saved.load_entry(key,source).is_empty(),"actual recorded absence changes still invalidate saved entry")
	source.missing=false; source.failure="source error"
	check(saved.load_entry(key,source).is_empty(),"source errors never become a cache hit")
	source.failure=""
	var cleared: Dictionary=saved.clear()
	check(cleared.get("errors",[]).is_empty() and saved.load_entry(key,source).is_empty(),"clear retires saved entries using original owner")
	check(not saved.save_entry(key,inputs,{"marker":18},ticket),"old generation cannot republish after clear")
	var tga:=PackedByteArray(); tga.resize(21); tga[2]=2; tga.encode_u16(12,1); tga.encode_u16(14,1); tga[16]=24; tga[18]=5; tga[19]=10; tga[20]=20
	var lower_directory:=argument("--cache-root=").path_join("lower-decoded")
	var lower=Cache.new(); check(lower.configure(lower_directory),"isolated lower decoder cache configures")
	var source_sha:=Cache.digest(tga)
	var legacy_key:=Cache.key(source_sha,"raster:3")
	check(lower.save_data(legacy_key,source_sha,"raster",{"legacy_marker":99}),"legacy derivative fixture saved under its original key")
	var assets=Assets.new()
	var decoded: Dictionary=assets.decode_uncached(tga,3,"raster",lower_directory)
	if candidate:
		check(not bool(decoded.cache_hit) and not decoded.value.has("legacy_marker") and str(decoded.error).is_empty(),"new source graph cannot warm from a legacy lower raster derivative")
		var again: Dictionary=assets.decode_uncached(tga,3,"raster",lower_directory)
		check(bool(again.cache_hit) and not again.value.has("legacy_marker"),"current complete graph reuses its own lower derivative")
		var restore: String=Identity.identities["gui-icon-v1"]
		Identity.identities["gui-icon-v1"]="" # Owned isolated test; simulate unavailable processor proof.
		var uncached: Dictionary=assets.decode_uncached(tga,3,"raster",lower_directory)
		check(not bool(uncached.cache_hit) and str(uncached.error).is_empty(),"unavailable processor proof also disables lower persistent raster reads/writes")
		Identity.identities["gui-icon-v1"]=restore
	else:
		check(bool(decoded.cache_hit) and decoded.value.get("legacy_marker")==99,"baseline lower derivative remains the explicit original-code oracle")
	var animation_sources:=[{"name":"fixture","sha256":"7".repeat(64)}]
	var rig_source:=Cache.digest(var_to_bytes(animation_sources))
	var rig_decoder:="actor-rig-emitter-v11-vertex-samples"
	check(lower.save_data(Cache.key(rig_source,rig_decoder),rig_source,rig_decoder,{"legacy_rig_marker":99}),"legacy calculated-rig fixture persists under original key")
	var rig_model:={"nodes":[],"animations":[],"name":"fixture"}
	var rig: Dictionary=assets.rig_data(rig_model,animation_sources,lower_directory)
	check(rig.get("legacy_rig_marker")==99 if not candidate else not rig.has("legacy_rig_marker"),"calculated-rig provenance follows explicit original/candidate ownership")
	if candidate:
		check(assets.rig_data(rig_model,animation_sources,lower_directory)==rig,"current calculated-rig derivative reuses identical data")
	assets.free()
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"candidate":candidate,"identity_status":Identity.status(),"server_connections":0,"graphics":0}
	var report:=FileAccess.open(argument("--report="),FileAccess.WRITE)
	if report!=null: report.store_string(JSON.stringify(proof)); report.close()
	print(JSON.stringify({"success":proof.success,"checks":checks,"failures":failures})); quit(0 if proof.success else 1)
