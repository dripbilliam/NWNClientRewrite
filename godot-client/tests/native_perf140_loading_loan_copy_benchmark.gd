extends SceneTree
const Loan=preload("res://systems/native_data/readonly_bundle_loan.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
var args: Dictionary={}
var failures: Array=[]
var packets: Array=[]
var sink:=0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	call_deferred("run")
func synthetic(packed: bool) -> Dictionary:
	var rows: Array=[]
	for index in 160:
		var row:={"name":"part_"+str(index),"parent":index-1,"position":[1.0,2.0,3.0],"orientation":[0.0,0.0,0.0,1.0],"features":["mesh"],"diffuse":[1.0,0.5,0.25],"ambient":[0.5,0.5,0.5],"metadata":{"render":true,"shadow":true,"labels":["one","two","three"]}}
		if packed:row.mesh={"vertices":PackedFloat32Array([0,0,0,1,0,0,0,1,0]),"indices":PackedInt32Array([0,1,2]),"normals":PackedFloat32Array([0,0,1,0,0,1,0,0,1]),"uv":[PackedFloat32Array([0,0,1,0,0,1])]}
		rows.append(row)
	return {"value":{"name":"synthetic","nodes":rows,"animations":[]},"textures":{},"sha256":"synthetic-control"}
func measure(source: Dictionary,plan: Dictionary,iterations: int,loan: bool,cold: bool) -> int:
	var began:=Time.get_ticks_usec()
	for ignored in iterations:
		var copy: Dictionary=Loan.prepare(source) if cold and loan else (Loan.borrow(plan) if loan else source.duplicate(true))
		sink+=copy.size();copy.clear()
	return Time.get_ticks_usec()-began
func median(values: Array) -> int:
	var sorted:=values.duplicate();sorted.sort();return int(sorted[sorted.size()/2])
func compare(name: String,source: Dictionary) -> Dictionary:
	var prepared:=Loan.prepare(source)
	if not prepared.ready:return {"name":name,"loanable":false,"reason":prepared.reason,"stats":prepared.stats}
	var warm_before: Array=[];var warm_after: Array=[];var cold_before: Array=[];var cold_after: Array=[]
	var iterations:=64
	for repetition in 7:
		if repetition%2==0:
			warm_before.append(measure(source,{},iterations,false,false));warm_after.append(measure(source,prepared.plan,iterations,true,false))
			cold_before.append(measure(source,{},1,false,true));cold_after.append(measure(source,{},1,true,true))
		else:
			warm_after.append(measure(source,prepared.plan,iterations,true,false));warm_before.append(measure(source,{},iterations,false,false))
			cold_after.append(measure(source,{},1,true,true));cold_before.append(measure(source,{},1,false,true))
	return {"name":name,"source_sha256":source.get("sha256",""),"content_sha256":Cache.digest(var_to_bytes(source)),"serialized_bytes":var_to_bytes(source).size(),"nodes":source.get("value",{}).get("nodes",[]).size(),"loanable":true,"plan_stats":prepared.stats,"warm_iterations":iterations,"repetitions":7,"warm_before_us":warm_before,"warm_after_us":warm_after,"cold_before_us":cold_before,"cold_after_us":cold_after,"warm_before_median_us":median(warm_before),"warm_after_median_us":median(warm_after),"cold_before_median_us":median(cold_before),"cold_after_median_us":median(cold_after),"scope":"Interleaved clone/compile and copy+release microbenchmark. Does not include store accounting/eviction, resource discovery/decoding, GPU work, full area entry or frame rate."}
func recorded_cases() -> Array:
	var cases: Array=[]
	if not args.has("recorded-catalog"):return cases
	var catalog:=Recorded.new()
	if not catalog.mount(args["recorded-catalog"]):failures.append(catalog.failure);return cases
	var service:=Assets.new();root.add_child(service);service.maximum_workers=1;service.configure(catalog);service.completed.connect(func(_id,result):packets.append(result))
	for name in str(args.get("models","ttu01_w06_01,plc_s07,ttu_udoor_04")).split(",",false):
		var id: int=service.request(name,2002,"static-model")
		if id<0:failures.append(service.failure);continue
		var deadline:=Time.get_ticks_msec()+30000
		while packets.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
		if packets.is_empty():failures.append("Recorded model timed out: "+name);break
		var result: Dictionary=packets.pop_front()
		if not str(result.get("error","")).is_empty():cases.append({"name":name,"skipped":true,"reason":result.error});continue
		cases.append(compare(name,service.bundle_content(result)))
	service.close();service.free();catalog.preparation_cache().clear();catalog.decoded_cache().clear()
	return cases
func run() -> void:
	var cases: Array=[compare("metadata-only-control",synthetic(false)),compare("packed-heavy-control",synthetic(true))]
	cases.append_array(await recorded_cases())
	var proof:={"success":failures.is_empty(),"failures":failures,"cases":cases,"sink":sink,"scope":"Headless preparation-copy microbenchmark only. Actual recorded source hashes are pinned per case when available; no server connection, world rendering or FPS acceptance."}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close();print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
