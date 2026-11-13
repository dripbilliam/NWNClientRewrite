extends "res://tests/native_perf140_loading_processor_capture_test.gd"
const Writes=preload("res://systems/native_data/prepared_write_queue.gd")
func run() -> void:
	var mode:=argument("--mode="); var catalog:=Recorded.new(); check(catalog.mount(argument("--recorded-catalog=")),"sealed captured catalog mounts")
	var service:=Assets.new(); root.add_child(service); service.maximum_workers=1; service.cache_directory=argument("--cache-root="); service.prework_write=false; service.prework_read=false; service.configure(catalog)
	service.completed.connect(func(_id,result):packets.append(result))
	var names:=argument("--models=").split(",",false); var cases: Array=[]
	for name in names:
		var result: Dictionary=await request(service,name); check(str(result.get("error","")).is_empty(),"actual captured worker succeeds: "+name)
		if not str(result.get("error","")).is_empty(): continue
		var content: Dictionary=service.bundle_content(result); var raw:=FileAccess.open(argument("--report=").get_base_dir().path_join(name+".bin"),FileAccess.WRITE); raw.store_var(content,false); raw.close()
		var file_path:=argument("--baseline-root=").path_join(name+".bin")
		if mode=="default":
			var file:=FileAccess.open(file_path,FileAccess.WRITE); file.store_var(content,false); file.close()
		else:
			var file:=FileAccess.open(file_path,FileAccess.READ); check(file!=null,"original complete packet exists: "+name)
			if file!=null:
				var expected: Dictionary=file.get_var(false); file.close(); check(data_equal(content,expected),"all calculated model/image/resource facts remain exact: "+name)
		var textures: Dictionary=content.get("textures",{}).duplicate(); textures.merge(content.get("emitter_textures",{}),true)
		for texture in textures:
			var packet: Dictionary=textures[texture]
			if packet.is_empty() or packet.get("memory_decode_hit",false): continue
			check(bool(packet.get("timings",{}).get("cache_write_deferred",false))==(mode=="deferred"),"only opted-in raster cache writes use existing queue: "+name+":"+str(texture))
		cases.append({"name":name,"sha256":result.sha256,"data_hash":Cache.digest(var_to_bytes(canonical(data_view(content)))),"raw_envelope_sha256":Cache.digest(var_to_bytes(content)),"nodes":content.value.nodes.size(),"textures":textures.size()})
	var before_close:=Writes.snapshot(); service.close(); service.free(); var after_close:=Writes.snapshot()
	check(int(after_close.get("failed",0))==0 and after_close.get("errors",[]).is_empty(),"actual background cache writes have no failures")
	check(int(after_close.pending)==0 and bool(after_close.closed),"actual last service drains and closes the existing writer")
	check(int(after_close.get("completed",0))==int(after_close.get("submitted",0)),"every admitted actual model/raster packet drains")
	var expected_writes: int=(21 if OS.get_cmdline_user_args().has("--combined-flow") else 26) if mode=="deferred" else 13
	check(int(after_close.get("submitted",0))==expected_writes,"exact existing writer census follows admitted original/combined MDL/raster work")
	catalog.preparation_cache().clear(); catalog.decoded_cache().clear()
	var proof:={"success":failures.is_empty() and cases.size()==8,"mode":mode,"checks":checks,"failures":failures,"cases":cases,"writer_before_close":before_close,"writer_after_close":after_close,"raw_envelopes_preserved":true,"data_comparison_omits":["textures.<name>.cache_hit","textures.<name>.memory_decode_hit","textures.<name>.memory_cache_hit","textures.<name>.timings","emitter_textures.<name>.cache_hit","emitter_textures.<name>.memory_decode_hit","emitter_textures.<name>.memory_cache_hit","emitter_textures.<name>.timings","dependencies[<row>].cache_hit","dependencies[<row>].read_ms","dependencies[<row>].timings"],"server_connections":0,"graphics":0,"timing_claim":false}
	var file:=FileAccess.open(argument("--report="),FileAccess.WRITE); file.store_string(JSON.stringify(proof)); file.close(); print(JSON.stringify({"success":proof.success,"mode":mode,"checks":checks,"failures":failures})); quit(0 if proof.success else 1)
