extends "res://tests/native_perf140_loading_raster_census.gd"
const Child=preload("res://systems/native_data/prework_raster_children.gd")
func require(value: bool,message: String) -> void:
	if not value: failures.append(message)
func exact_order(value: Variant) -> Variant:
	if value is Dictionary:
		var output: Dictionary=value.duplicate(); output.clear(); var keys: Array=value.keys()
		keys.sort_custom(func(a,b):return var_to_bytes(a).hex_encode()<var_to_bytes(b).hex_encode())
		for key in keys: output[key]=exact_order(value[key])
		return output
	if value is Array:
		var output: Array=value.duplicate()
		for index in output.size(): output[index]=exact_order(value[index])
		return output
	return value
func ask(service,name: String) -> Dictionary:
	var id: int=service.request(name,2002,"static-model")
	if id<0: return {"error":service.failure}
	var deadline:=Time.get_ticks_msec()+20000
	while packets.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	return packets.pop_front() if not packets.is_empty() else {"error":"timeout"}
func file_bytes(directory: String) -> Dictionary:
	var total:=0; var files:=0
	if not DirAccess.dir_exists_absolute(directory): return {"bytes":0,"files":0}
	for name in DirAccess.get_files_at(directory):
		if not name.ends_with(".bin") or not Child.valid_sha(name.get_basename()): continue
		var file:=FileAccess.open(directory.path_join(name),FileAccess.READ)
		if file!=null: total+=file.get_length(); files+=1; file.close()
	return {"bytes":total,"files":files}
func run() -> void:
	var names:=argument("--models=").split(",",false)
	var catalog:=Recorded.new(); require(catalog.mount(argument("--recorded-catalog=")),"sealed recorded catalog mounts")
	var service:=Assets.new(); root.add_child(service); service.maximum_workers=1; service.cache_directory=argument("--cache-root="); service.prework_write=true; service.configure(catalog)
	service.completed.connect(func(_id,result): packets.append(result))
	var cold: Dictionary={}; var source_hashes: Dictionary={}; var corpus: Array=[]
	for name in names:
		var result: Dictionary=await ask(service,name)
		require(str(result.get("error","")).is_empty(),"cold original model succeeds: "+name)
		if not str(result.get("error","")).is_empty(): continue
		require(bool(result.get("prework_saved",false)),"cold final artifact publishes: "+name)
		var content: Dictionary=service.bundle_content(result); held.append(content)
		cold[name]=Cache.digest(var_to_bytes(exact_order(content))); source_hashes[name]=result.sha256
		corpus.append({"name":name,"source_sha256":result.sha256,"nodes":result.value.nodes.size(),"rasters":raster_rows(name,content)})
	var cold_accounting:=Accounting.retained_cost({"completed_model_packets":held},1024*1024*1024)
	held.clear(); catalog.preparation_cache().clear(); catalog.decoded_cache().clear()
	var before:=Child.snapshot(); var warm: Array=[]
	for name in names:
		var result: Dictionary=await ask(service,name)
		require(str(result.get("error","")).is_empty(),"warm original model succeeds: "+name)
		if not str(result.get("error","")).is_empty(): continue
		require(bool(result.get("prework_hit",false)),"warm path reads actual final artifact: "+name)
		var content: Dictionary=service.bundle_content(result); held.append(content)
		require(Cache.digest(var_to_bytes(exact_order(content)))==cold.get(name),"entire original packet, image descriptor and diagnostic data roundtrip exactly: "+name)
		require(result.sha256==source_hashes.get(name),"warm source binding remains original: "+name)
		warm.append({"name":name,"prework_hit":result.get("prework_hit",false),"data_hash":Cache.digest(var_to_bytes(exact_order(content)))})
	var after:=Child.snapshot(); var warm_accounting:=Accounting.retained_cost({"completed_model_packets":held},1024*1024*1024)
	var store:=Prework.new(); require(store.configure(service.cache_directory),"saved artifact directory is measurable")
	var parents:=file_bytes(store.directory); var children:=file_bytes(store.directory.path_join(Child.DIRECTORY))
	var unique_bytes:=0
	for image in images.values(): unique_bytes+=int(image.encoded_bytes)
	if Child.enabled():
		require(int(after.reads)-int(before.reads)==images.size(),"each unique child is read once across actual warm model jobs")
		require(int(after.memory_hits)-int(before.memory_hits)>0,"repeated actual model references use the existing decoded store")
		require(children.files==images.size(),"persistent sidecar count equals actual unique image values")
	else:
		require(after==before and int(after.directories)==0 and int(after.reads)==0 and int(after.writes)==0,"disabled actual worker path performs zero child-store I/O")
		require(children.files==0,"disabled mode creates no sidecar artifacts")
	service.close(); service.free(); held.clear(); catalog.preparation_cache().clear(); catalog.decoded_cache().clear()
	var proof:={"success":failures.is_empty() and corpus.size()==names.size() and names.size()>=4,"failures":failures,"enabled":Child.enabled(),"models":corpus,"warm":warm,"parents":parents,"children":children,"combined_artifact_bytes":int(parents.bytes)+int(children.bytes),"image_occurrences":corpus.reduce(func(total,row):return total+row.rasters.size(),0),"unique_images":images.size(),"image_occurrence_encoded_bytes":occurrence_bytes,"unique_image_encoded_bytes":unique_bytes,"cold_memory_owner_result":cold_accounting if not cold_accounting.is_empty() else null,"warm_memory_owner_result":warm_accounting if not warm_accounting.is_empty() else null,"child_stats":after,"warm_child_delta":{"reads":int(after.reads)-int(before.reads),"memory_hits":int(after.memory_hits)-int(before.memory_hits)},"server_connections":0,"graphics":0,"timing_claim":false,"scope":"Functional eight-tile artifact byte and retained-graph accounting comparison; not RSS, latency, GPU or FPS evidence"}
	var report:=FileAccess.open(argument("--report="),FileAccess.WRITE); report.store_string(JSON.stringify(proof)); report.close(); print(JSON.stringify({"success":proof.success,"enabled":Child.enabled(),"combined_artifact_bytes":proof.combined_artifact_bytes,"failures":failures})); quit(0 if proof.success else 1)
