extends "res://tests/native_perf140_loading_processor_capture_test.gd"
const Route=preload("res://systems/native_data/static_actor_route.gd")
const Writes=preload("res://systems/native_data/prepared_write_queue.gd")
class TraceAssets:
	extends "res://systems/native_data/asset_service.gd"
	var trace: Array=[]
	var trace_mutex:=Mutex.new()
	var current_model:=""
	func _work(job: Dictionary) -> void:
		current_model=str(job.name)
		super._work(job)
	func decode(bytes: PackedByteArray,type: int,decoder: String,cache_path: String,store=null,immutable_source: bool=false) -> Dictionary:
		var result: Dictionary=super.decode(bytes,type,decoder,cache_path,store,immutable_source)
		trace_mutex.lock(); trace.append({"event":"decode","model":current_model,"decoder":decoder,"source_bytes":bytes.size(),"sha256":result.get("sha256"),"error":result.get("error"),"memory_hit":result.get("memory_decode_hit",false),"disk_hit":result.get("cache_hit",false),"timings":result.get("timings",{}).duplicate(true)}); trace_mutex.unlock()
		return result
	func decode_uncached(bytes: PackedByteArray,type: int,decoder: String,cache_path: String,known_sha: String="",defer_write: bool=false) -> Dictionary:
		trace_mutex.lock(); trace.append({"event":"uncached","model":current_model,"decoder":decoder,"sha256":known_sha if not known_sha.is_empty() else Cache.digest(bytes)}); trace_mutex.unlock()
		return super.decode_uncached(bytes,type,decoder,cache_path,known_sha,defer_write)
func minimal(nodes: int=1) -> PackedByteArray:
	var bytes:=PackedByteArray(); bytes.resize(12+232+112*nodes+nodes*4)
	bytes.encode_u32(4,bytes.size()-12); bytes.encode_u32(84,232); bytes.encode_u32(88,nodes)
	for index in nodes:
		var node:=12+232+index*112; bytes.encode_u32(node+108,1)
		if index+1<nodes:
			bytes.encode_u32(node+72,232+112*nodes+index*4); bytes.encode_u32(node+76,1)
			bytes.encode_u32(12+232+112*nodes+index*4,232+(index+1)*112)
	return bytes
func hint_checks() -> void:
	var bytes:=minimal(); var before:=bytes.duplicate()
	check(Route.binary_hint(bytes)=={"known":true,"emitter":false,"nodes":1},"plain binary topology is conclusive")
	check(bytes==before,"hint never mutates source bytes")
	bytes.encode_u32(12+232+108,5); check(Route.binary_hint(bytes).get("emitter",false),"root emitter is recognized")
	bytes=minimal(3); bytes.encode_u32(12+232+2*112+108,5); check(Route.binary_hint(bytes).get("emitter",false),"descendant emitter is recognized")
	bytes=minimal(); bytes.encode_u32(12+232+108,9); check(not Route.binary_hint(bytes).known,"unknown flags retain original route")
	check(not Route.binary_hint(PackedByteArray()).known,"missing header retains original route")
	check(not Route.binary_hint("newmodel test\n".to_ascii_buffer()).known,"ASCII retains original route")
	bytes=minimal(); bytes.encode_u32(4,bytes.size()); check(not Route.binary_hint(bytes).known,"truncated section is unknown")
	bytes=minimal(); bytes.encode_u32(8,1); check(not Route.binary_hint(bytes).known,"truncated raw section is unknown")
	bytes=minimal(); bytes.encode_u32(88,0); check(not Route.binary_hint(bytes).known,"zero declared nodes is unknown")
	bytes=minimal(); bytes.encode_u32(88,100001); check(not Route.binary_hint(bytes).known,"excessive declared nodes is unknown")
	bytes=minimal(); bytes.encode_u32(84,bytes.size()); check(not Route.binary_hint(bytes).known,"out-of-bounds root is unknown")
	bytes=minimal(); bytes.encode_u32(12+232+72,232+112); bytes.encode_u32(12+232+76,1); bytes.encode_u32(12+232+112,232); check(not Route.binary_hint(bytes).known,"cycle retains original route")
	bytes=minimal(2); bytes.encode_u32(88,1); check(not Route.binary_hint(bytes).known,"count overflow retains original route")
	bytes=minimal(130); check(not Route.binary_hint(bytes).known,"depth overflow retains original route")
	bytes=minimal(); bytes.encode_u32(12+232+72,bytes.size()); check(not Route.binary_hint(bytes).known,"even empty out-of-bounds child table retains original route")
func run() -> void:
	hint_checks()
	var enabled:=Route.enabled(); var baseline:=argument("--baseline-root="); var names:=argument("--models=").split(",",false)
	var catalog:=Recorded.new(); check(catalog.mount(argument("--recorded-catalog=")),"sealed recorded catalog mounts")
	var reader:=Overrides.new(); reader.source=catalog
	var service:=TraceAssets.new(); root.add_child(service); service.maximum_workers=1; service.cache_directory=argument("--cache-root="); service.prework_write=false; service.prework_read=false; service.configure(reader)
	service.completed.connect(func(_id,result):packets.append(result))
	var jobs: Array=[]
	for name in names: jobs.append({"name":name,"case":name,"mutation":"none"})
	for mutation in ["truncated","unknown-flags","bad-controller","bad-actor-scale","empty-model-name"]: jobs.append({"name":"ttu01_a01_01","case":"ttu01_a01_01-"+mutation,"mutation":mutation})
	var cases: Array=[]; var normalized: Dictionary={}
	for job in jobs:
		var name: String=job.name; var raw: PackedByteArray=catalog.get_resource(name,2002)
		check(catalog.failure.is_empty() and not raw.is_empty(),"original MDL source validates: "+job.case)
		if job.mutation!="none":
			raw=raw.duplicate(); var root_at:=12+int(raw.decode_u32(84))
			match str(job.mutation):
				"truncated": raw.resize(100)
				"unknown-flags": raw.encode_u32(root_at+108,int(raw.decode_u32(root_at+108))|8)
				"bad-controller": raw.encode_u32(root_at+84,0x7fffffff); raw.encode_u32(root_at+88,1); raw.encode_u32(root_at+96,0); raw.encode_u32(root_at+100,1)
				"bad-actor-scale": raw.encode_u32(12+164,0x7fc00000)
				"empty-model-name":
					for index in 64: raw[20+index]=0
			reader.overrides[name+":2002"]=raw
		else: reader.overrides.erase(name+":2002")
		if job.mutation!="none": catalog.preparation_cache().clear(); catalog.decoded_cache().clear()
		var offset:=service.trace.size(); var result: Dictionary=await request(service,name)
		var content: Dictionary=service.bundle_content(result); var error:=str(result.get("error","")); var envelope:={"content":content,"error":error}
		var filename: String=baseline.path_join(str(job.case)+".bin")
		var raw_file:=FileAccess.open(argument("--report=").get_base_dir().path_join(str(job.case)+".bin"),FileAccess.WRITE); raw_file.store_var(envelope,false); raw_file.close()
		if not enabled:
			var file:=FileAccess.open(filename,FileAccess.WRITE); file.store_var(envelope,false); file.close()
		else:
			var file:=FileAccess.open(filename,FileAccess.READ); check(file!=null,"baseline envelope exists: "+job.case)
			if file!=null:
				var expected: Dictionary=file.get_var(false); file.close()
				check(error==str(expected.error),"original error precedence remains exact: "+job.case)
				check(data_equal(content,expected.content),"all calculated model/image/dependency fields remain exact: "+job.case)
		check(error.is_empty()==(job.mutation=="none"),"original valid/error admission: "+job.case)
		var trace: Array=service.trace.slice(offset); var static_calls:=trace.filter(func(row):return row.event=="uncached" and row.decoder=="mdl-original").size()
		var actor_calls:=trace.filter(func(row):return row.event=="uncached" and str(row.decoder).begins_with("mdl-actor")).size()
		if job.mutation=="none":
			var hint:=Route.binary_hint(raw); check(hint.known,"captured tile has proven binary topology: "+name)
			check(static_calls==(0 if enabled and hint.emitter else 1),"only emitter roots omit unused static preparation: "+name)
			check(actor_calls==int(hint.emitter),"actor preparation still occurs exactly where originally required: "+name)
		cases.append({"case":job.case,"sha256":Cache.digest(raw),"error":error,"static_uncached":static_calls,"actor_uncached":actor_calls,"direct":result.get("phases",{}).get("direct_static_actor",false),"trace":trace,"data_hash":Cache.digest(var_to_bytes(canonical(data_view(content))))})
	var writer_before:=Writes.snapshot(); service.close(); service.free(); var writer_after:=Writes.snapshot()
	check(int(writer_after.get("pending",0))==0 and int(writer_after.get("failed",0))==0,"all admitted original/combined cache jobs drain without failure")
	check(int(writer_after.get("completed",0))==int(writer_after.get("submitted",0)),"last owner completes every admitted model/raster write")
	catalog.preparation_cache().clear(); catalog.decoded_cache().clear()
	var proof:={"success":failures.is_empty(),"enabled":enabled,"checks":checks,"failures":failures,"cases":cases,"writer_before_close":writer_before,"writer_after_close":writer_after,"data_comparison_omits":["textures.<name>.cache_hit","textures.<name>.memory_decode_hit","textures.<name>.memory_cache_hit","textures.<name>.timings","emitter_textures.<name>.cache_hit","emitter_textures.<name>.memory_decode_hit","emitter_textures.<name>.memory_cache_hit","emitter_textures.<name>.timings","dependencies[<row>].cache_hit","dependencies[<row>].read_ms","dependencies[<row>].timings"],"raw_envelopes_preserved":true,"server_connections":0,"graphics":0,"timing_claim":false,"scope":"Exact eight captured tile packets plus original error precedence; uncached decoder counts exclude GPU and do not imply latency."}
	var file:=FileAccess.open(argument("--report="),FileAccess.WRITE); file.store_string(JSON.stringify(proof)); file.close(); print(JSON.stringify({"success":proof.success,"enabled":enabled,"checks":checks,"failures":failures})); quit(0 if proof.success else 1)
