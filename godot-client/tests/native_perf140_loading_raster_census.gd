extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Prework=preload("res://systems/native_data/prework_store.gd")
const Accounting=preload("res://systems/native_data/resource_index_backend.gd")
var failures: Array=[]
var packets: Array=[]
var images: Dictionary={}
var cases: Array=[]
var held: Array=[]
var occurrence_bytes:=0
var packed_occurrence_bytes:=0
func argument(prefix: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""
func _initialize() -> void: call_deferred("run")
func canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary={}; var keys: Array=value.keys(); keys.sort_custom(func(a,b): return var_to_bytes(a).hex_encode()<var_to_bytes(b).hex_encode())
		for key in keys: result[key]=canonical(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for row in value: result.append(canonical(row))
		return result
	return value
func packed_bytes(value: Variant) -> int:
	if value is PackedByteArray: return value.size()
	var total:=0
	if value is Dictionary:
		for child in value.values(): total+=packed_bytes(child)
	elif value is Array:
		for child in value: total+=packed_bytes(child)
	return total
func raster_rows(name: String,content: Dictionary) -> Array:
	var rows: Array=[]
	for field in ["textures","emitter_textures"]:
		for texture in content.get(field,{}):
			var packet: Variant=content[field][texture]
			if not packet is Dictionary or not packet.get("value") is Dictionary: continue
			var value: Dictionary=packet.value
			var encoded:=var_to_bytes(canonical(value)); var bytes:=packed_bytes(value)
			if bytes<=0: continue
			var sha:=Cache.digest(encoded); occurrence_bytes+=encoded.size(); packed_occurrence_bytes+=bytes
			if not images.has(sha): images[sha]={"digest":sha,"encoded_bytes":encoded.size(),"packed_bytes":bytes,"occurrences":0,"width":value.get("width"),"height":value.get("height"),"references":[]}
			images[sha].occurrences+=1; images[sha].references.append({"model":name,"field":field,"texture":texture,"source_sha256":packet.get("sha256")})
			rows.append({"field":field,"texture":texture,"digest":sha,"encoded_bytes":encoded.size(),"packet_encoded_bytes":var_to_bytes(packet).size(),"packed_bytes":bytes})
	return rows
func run() -> void:
	var catalog:=Recorded.new()
	if not catalog.mount(argument("--recorded-catalog=")): failures.append(catalog.failure)
	var service:=Assets.new(); root.add_child(service); service.maximum_workers=1; service.cache_directory=argument("--cache-root="); service.prework_write=true; service.configure(catalog)
	service.completed.connect(func(_id,result): packets.append(result))
	var artifact_bytes:=0
	for name in argument("--models=").split(",",false):
		var id: int=service.request(name,2002,"static-model")
		if id<0: failures.append(service.failure); break
		var deadline:=Time.get_ticks_msec()+20000
		while packets.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		if packets.is_empty(): failures.append("Model request timed out: "+name); break
		var result: Dictionary=packets.pop_front()
		if not str(result.get("error","")).is_empty(): failures.append(name+": "+str(result.error)); continue
		if not bool(result.get("prework_saved",false)): failures.append("Final artifact was not saved: "+name)
		var content: Dictionary=service.bundle_content(result); held.append(content)
		var prework:=Prework.new(); prework.configure(service.cache_directory)
		var key:=Prework.request_key(name,2002,"static-model",{},str(result.sha256),[service.mesh_preparation_enabled,service.skin_preparation_enabled,service.mesh_revision()])
		var artifact:=FileAccess.open(prework.cache.filename(key),FileAccess.READ)
		var size: Variant=artifact.get_length() if artifact!=null else null
		if artifact==null: failures.append("Saved artifact could not be measured: "+name)
		if artifact!=null: artifact_bytes+=artifact.get_length(); artifact.close()
		cases.append({"model":name,"source_sha256":result.sha256,"artifact_bytes":size,"nodes":result.value.nodes.size(),"rasters":raster_rows(name,content)})
	service.close(); service.free()
	var unique_bytes:=0; var unique_packed:=0; var occurrences:=0; var shared_images:=0; var shared: Array=[]
	for image in images.values():
		unique_bytes+=int(image.encoded_bytes); unique_packed+=int(image.packed_bytes); occurrences+=int(image.occurrences)
		if int(image.occurrences)>1: shared_images+=1; shared.append(image)
	shared.sort_custom(func(a,b): return int(a.encoded_bytes)*(int(a.occurrences)-1)>int(b.encoded_bytes)*(int(b.occurrences)-1))
	var accounting:=Accounting.retained_cost({"completed_model_packets":held},1024*1024*1024)
	var proof:={"success":failures.is_empty() and cases.size()>=4,"failures":failures,"models":cases,"artifact_bytes":artifact_bytes,"raster_occurrences":occurrences,"unique_raster_values":images.size(),"shared_raster_values":shared_images,"occurrence_encoded_bytes":occurrence_bytes,"unique_encoded_bytes":unique_bytes,"duplicate_encoded_bytes":occurrence_bytes-unique_bytes,"packed_occurrence_bytes":packed_occurrence_bytes,"unique_packed_bytes":unique_packed,"shared_images":shared,"memory_accounting":{"available":not accounting.is_empty(),"native_owner_result":accounting if not accounting.is_empty() else null,"scope":"Eight retained producer packet graphs only; logical serialized counts are not RSS or proof of duplicated physical packed storage"},"server_connections":0,"graphics":0,"timing_claim":false}
	var report:=FileAccess.open(argument("--report="),FileAccess.WRITE); report.store_string(JSON.stringify(proof)); report.close()
	held.clear(); catalog.preparation_cache().clear(); catalog.decoded_cache().clear()
	print(JSON.stringify({"success":proof.success,"models":cases.size(),"artifact_bytes":artifact_bytes,"duplicate_encoded_bytes":proof.duplicate_encoded_bytes,"failures":failures})); quit(0 if proof.success else 1)
