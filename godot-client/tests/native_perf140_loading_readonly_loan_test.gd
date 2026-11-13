extends SceneTree
const Loan=preload("res://systems/native_data/readonly_bundle_loan.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
var checks:=0
var failures: Array=[]
var args: Dictionary={}
var expect_loan:=false
var packets: Array=[]
class Capture:
	extends Logger
	var gate:=Mutex.new()
	var tag:=""
	var errors: Array=[]
	func _log_error(function: String,file: String,line: int,code: String,rationale: String,_notify: bool,error_type: int,_traces: Array[ScriptBacktrace]) -> void:
		gate.lock();errors.append({"tag":tag,"function":function,"file":file,"line":line,"code":code,"rationale":rationale,"type":error_type});gate.unlock()
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	expect_loan=args.get("expect-loan","false")=="true";call_deferred("run")
func source() -> Dictionary:
	return {"meta":{"label":"original","rows":[[1,2],[3,4]],"tree":{"name":"immutable","values":[10,11,12]}},"streams":{"byte":PackedByteArray([1,2]),"int":PackedInt32Array([3,4]),"long":PackedInt64Array([5,6]),"float":PackedFloat32Array([0.5,1.5]),"double":PackedFloat64Array([2.5,3.5]),"string":PackedStringArray(["a","b"]),"v2":PackedVector2Array([Vector2(1,2)]),"v3":PackedVector3Array([Vector3(1,2,3)]),"v4":PackedVector4Array([Vector4(1,2,3,4)]),"color":PackedColorArray([Color(0.1,0.2,0.3,1)])}}
func replacement(name: String):
	return {"byte":9,"int":99,"long":999,"float":9.5,"double":10.5,"string":"changed","v2":Vector2(4,5),"v3":Vector3(4,5,6),"v4":Vector4(5,6,7,8),"color":Color(0.7,0.8,0.9,1)}[name]
func packed_isolation(a: Dictionary,b: Dictionary,pristine: Dictionary,label: String) -> void:
	for name in a.streams:
		var original=pristine.streams[name][0];var packed=a.streams[name]
		packed[0]=replacement(name);packed.set(0,replacement(name));packed.append(replacement(name))
		check(b.streams[name][0]==original and b.streams[name].size()==pristine.streams[name].size(),label+": packed recipient writes/set/append are private: "+name)
		check(pristine.streams[name][0]==original,label+": original packed input stays private: "+name)
func helper_checks() -> void:
	var cold:=source();var original:=source();var prepared:=Loan.prepare(cold)
	check(prepared.ready,"Data-only packed fixture is loanable")
	check(not cold.is_read_only() and not cold.meta.is_read_only() and not cold.meta.rows.is_read_only(),"Canonical compilation never freezes caller containers")
	var a:=Loan.borrow(prepared.plan);var b:=Loan.borrow(prepared.plan)
	check(not a.is_read_only() and a.meta.is_read_only() and a.meta.rows.is_read_only() and a.meta.rows[0].is_read_only(),"Outer headers are mutable and scalar metadata recursively readonly")
	check(is_same(a.meta,b.meta) and not is_same(a.streams,b.streams),"Only metadata with no packed leaves is structurally shared")
	a.worker_ms=3.5;a.cache_hit=true
	check(not b.has("worker_ms") and not prepared.value.has("worker_ms"),"Result-header writes remain recipient-owned")
	packed_isolation(a,b,original,"Sparse loan")
	cold.meta.label="cold mutation";cold.meta.rows[0][0]=99;cold.streams.byte[0]=100
	check(b.meta.label=="original" and b.meta.rows[0][0]==1 and b.streams.byte[0]==1,"Caller mutations cannot change retained canonical containers or packed data")
	var typed: Array[int]=[1,2];var typed_graph:=Loan.prepare({"typed":typed})
	var typed_view:=Loan.borrow(typed_graph.plan)
	check(typed_view.typed.is_typed() and typed_view.typed.get_typed_builtin()==TYPE_INT and typed_view.typed.is_read_only(),"Scalar typed arrays retain type and readonly policy")
	var object:=Resource.new();var node:=Node.new();var objects: Array[Node]=[]
	for unsafe in [object,node,Callable(self,"source"),Signal(self,"tree_changed"),RID(),objects]:
		check(not Loan.prepare({"unsafe":unsafe}).ready,"Objects/resources/callables/signals/RIDs/object-typed arrays reject loans")
	node.free()
	var key: Array=[1];var keyed: Dictionary={};keyed[key]="value"
	check(not Loan.prepare(keyed).ready and not key.is_read_only(),"Unsafe container dictionary keys reject without freezing caller keys")
	var cycle: Dictionary={};cycle.self=cycle
	check(not Loan.prepare(cycle).ready,"Cycles/deep graphs fail bounded compilation rather than recurse forever");cycle.erase("self")
func publish(store,request: String,identity: String,data: Dictionary,epoch: int) -> bool:
	if store.has_method("save_readonly_data"):return store.save_readonly_data(request,identity,data,epoch)
	store.save_data(request,identity,data,epoch);return true
func borrow(store,request: String,epoch: int) -> Dictionary:
	return store.load_readonly_data(request,epoch) if store.has_method("load_readonly_data") else store.load_data(request,epoch)
func store_checks() -> void:
	var store:=Store.new();var epoch:=store.generation();var cold:=source()
	check(publish(store,"request","identity",cold,epoch),"Completed-bundle publication is accepted")
	check(not cold.meta.is_read_only(),"Completed cache publication never freezes mutable cold job state")
	var a:=borrow(store,"request",epoch);var b:=borrow(store,"request",epoch)
	check(a==b and (a.meta.is_read_only()==expect_loan),"Completed lookup follows selected immutable policy")
	check(is_same(a.meta,b.meta)==expect_loan,"Candidate shares only proven immutable metadata")
	packed_isolation(a,b,source(),"Completed cache")
	var private:=store.load_data("request",epoch)
	check(not private.is_read_only() and not private.meta.is_read_only() and not private.meta.rows.is_read_only(),"Default nonloan clients still receive fully mutable container copies")
	private.meta.rows[0][0]=42;private.meta.label="private";private.streams.byte[0]=43
	check(borrow(store,"request",epoch).meta.rows[0][0]==1 and borrow(store,"request",epoch).streams.byte[0]==1,"Mutable nonloan clients cannot alter canonical/loaned data")
	var lease:=store.begin_data("request",epoch,false)
	lease.value.streams.byte[0]=88
	check(borrow(store,"request",epoch).streams.byte[0]==(1 if expect_loan else 88),"Generic begin_data protects loanable entries; baseline fixture demonstrates its old immutable-borrow trust contract")
	if not expect_loan:lease.value.streams.byte[0]=1
	var held:=borrow(store,"request",epoch);store.clear();var next:=store.generation()
	check(next!=epoch and borrow(store,"request",epoch).is_empty(),"Clear retires old request generation")
	check(held.meta.label=="original" and held.streams.byte[0]==1,"Detached snapshots remain valid after cache clear")
	check(not publish(store,"late","late",source(),epoch) if expect_loan else true,"Stale readonly publication is rejected")
	check(borrow(store,"late",next).is_empty(),"Stale worker cannot publish into the new generation")
	store.maximum_entries=1
	check(publish(store,"new","new",source(),next),"New generation accepts new data")
	var retained:=borrow(store,"new",next);check(publish(store,"replacement","replacement",source(),next),"Capacity eviction accepts replacement")
	check(borrow(store,"new",next).is_empty() and retained.meta.label=="original","Eviction removes bindings while detached views survive")
	store.clear();store.maximum_bytes=1
	check(not publish(store,"large","large",source(),store.generation()) if expect_loan else true,"Oversized loan is not retained")
	check(borrow(store,"large",store.generation()).is_empty(),"Oversized data cannot silently escape the cache bound")
	store.clear()
	if expect_loan:
		var unsafe:=Resource.new();var rejected:=Store.new()
		check(not rejected.save_readonly_data("unsafe","unsafe",{"resource":unsafe},rejected.generation()),"Unsafe object data rejects explicit loan publication")
		check(rejected.entries.is_empty() and rejected.snapshot().readonly_bundle_loans.rejected==1,"Rejected loan creates no binding or partially frozen cache entry")
		var legacy:=Store.new();legacy.save_data("legacy","legacy",source(),legacy.generation())
		var fallback: Dictionary=legacy.load_readonly_data("legacy",legacy.generation())
		check(not fallback.meta.is_read_only(),"Explicit readonly lookup safely deep-copies a legacy nonloanable entry")
		fallback.meta.label="recipient";fallback.streams.byte[0]=77
		check(legacy.load_data("legacy",legacy.generation()).meta.label=="original" and legacy.load_data("legacy",legacy.generation()).streams.byte[0]==1,"Legacy fallback mutations cannot affect cached content")
		legacy.clear();rejected.clear()
func follow(store,key: String,epoch: int,private: bool) -> Dictionary:
	return store.begin_data(key,epoch,private)
func coalesced_checks() -> void:
	for private in [false,true]:
		var store:=Store.new();var epoch:=store.generation();var leader:=store.begin_data("flight",epoch,private)
		check(leader.owner,"Coalesced fixture has one leader")
		var worker:=Thread.new();check(worker.start(follow.bind(store,"flight",epoch,private))==OK,"Follower starts on its own native thread")
		var deadline:=Time.get_ticks_msec()+10000
		while store.snapshot().coalesced<1 and Time.get_ticks_msec()<deadline:await process_frame
		check(store.snapshot().coalesced==1,"Follower is waiting at the existing publication boundary")
		var cold:=source();check(publish(store,"flight","flight",cold,epoch),"Leader publishes a private completed snapshot")
		store.finish_data("flight",epoch,cold);var packet: Dictionary=worker.wait_to_finish()
		check(not packet.owner and packet.value.meta.label=="original","Follower receives the actual completed result")
		check(packet.value.meta.is_read_only()==(expect_loan and not private),"Follower private-vs-loan container contract is preserved")
		packet.value.streams.byte[0]=55
		check(borrow(store,"flight",epoch).streams.byte[0]==(55 if not expect_loan and not private else 1),"Coalesced loan/default-private paths isolate canonical packed data")
		check(cold.streams.byte[0]==1 and not cold.meta.is_read_only(),"Leader's mutable cold graph is never shared/frozen by follower publication")
		store.clear()
	# A late old-generation flight must not borrow a new-generation same-key entry.
	var store:=Store.new();var epoch:=store.generation();store.begin_data("reused",epoch,false)
	var worker:=Thread.new();check(worker.start(follow.bind(store,"reused",epoch,false))==OK,"Stale follower starts")
	var deadline:=Time.get_ticks_msec()+10000
	while store.snapshot().coalesced<1 and Time.get_ticks_msec()<deadline:await process_frame
	check(store.snapshot().coalesced==1,"Stale follower is actually waiting")
	store.clear();var current:=source();current.meta.label="new generation"
	check(publish(store,"reused","new identity",current,store.generation()),"New generation publishes the reused request key")
	var old:=source();old.meta.label="old generation";store.finish_data("reused",epoch,old)
	var packet: Dictionary=worker.wait_to_finish()
	check(packet.value.meta.label=="old generation" and borrow(store,"reused",store.generation()).meta.label=="new generation","Old flight completion cannot resolve a newer request lifetime")
	packet.value.streams.byte[0]=66
	check(old.streams.byte[0]==1 and current.streams.byte[0]==1 and borrow(store,"reused",store.generation()).streams.byte[0]==1,"Retired flight packed mutations cannot affect either cold job or current cache")
	var independent:=Store.new()
	check(borrow(independent,"reused",independent.generation()).is_empty(),"Independent catalog/cache owners never resolve another owner's request")
	store.clear();independent.clear()
func write(path: String,text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir());var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()
func model_text(name: String,x: int=1) -> String:
	return "newmodel "+name+"\nbeginmodelgeom "+name+"\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n"+str(x)+" 0 0\n0 0 1\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom "+name+"\n"
func request(service,name: String) -> Dictionary:
	var id: int=service.request(name,2002,"static-model");check(id>0,"Actual static request is admitted")
	var deadline:=Time.get_ticks_msec()+10000
	while packets.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(not packets.is_empty(),"Actual static request completes")
	return packets.pop_front() if not packets.is_empty() else {"error":"timeout"}
func actual_static_checks() -> void:
	var first_path:=ProjectSettings.globalize_path("res://loan-fixtures/first");var second_path:=ProjectSettings.globalize_path("res://loan-fixtures/second")
	write(first_path.path_join("auth_loan.mdl"),model_text("auth_loan"));write(first_path.path_join("auth_bad.mdl"),"not a valid model")
	write(second_path.path_join("auth_loan.mdl"),model_text("auth_loan",2))
	var catalog:=Catalog.new();check(catalog.mount_directory(first_path),"Authored original-data catalog mounts")
	var service:=Assets.new();root.add_child(service);service.maximum_workers=1;service.configure(catalog);service.completed.connect(func(_id,result):packets.append(result))
	var cold: Dictionary=await request(service,"auth_loan");var warm: Dictionary=await request(service,"auth_loan")
	check(cold.error.is_empty() and warm.error.is_empty() and warm.get("memory_cache_hit",false),"Real static model repeats use completed preparation cache")
	check(not cold.value.is_read_only() and (warm.value.is_read_only()==expect_loan),"Real cold job remains mutable while selected warm view is readonly")
	var vertices: PackedFloat32Array=warm.value.nodes[0].mesh.vertices;vertices[0]=99
	var again: Dictionary=await request(service,"auth_loan")
	check(again.value.nodes[0].mesh.vertices[0]==0 and cold.value.nodes[0].mesh.vertices[0]==0,"Real warm packed geometry cannot mutate another result or cold job")
	var pool:=Pool.new();var template=pool.model_template(again);check(template!=null,"Native template consumes the actual completed-bundle view")
	if template!=null:
		var placement=template.create();check(placement!=null and placement.meshes.size()==1,"Actual view publishes ordinary physical geometry");placement.free()
	pool.clear();template=null
	var old_epoch: int=catalog.preparation_cache().generation();check(catalog.mount_directory(second_path,20000000),"Catalog switch mounts an authoritative replacement layer")
	check(catalog.preparation_cache().generation()!=old_epoch,"Resource catalog switch invalidates completed bindings")
	var replaced: Dictionary=await request(service,"auth_loan")
	check(replaced.error.is_empty() and replaced.sha256!=cold.sha256 and not replaced.get("memory_cache_hit",false),"Changed winning source cannot reuse an older completed loan")
	var bad: Dictionary=await request(service,"auth_bad");var bad_again: Dictionary=await request(service,"auth_bad")
	check(not bad.error.is_empty() and not bad_again.error.is_empty() and not bad_again.get("memory_cache_hit",false),"Errored actual preparations are never published as completed loans")
	service.close();service.free();catalog.preparation_cache().clear()
func probe_index(value: Dictionary) -> void:value["label"]="rejected"
func mutation_probe() -> Dictionary:
	var capture:=Capture.new();OS.add_logger(capture)
	var prepared:=Loan.prepare(source());var value:=Loan.borrow(prepared.plan)
	capture.tag="dictionary_set";value.meta.set("label","rejected")
	capture.tag="array_set";value.meta.rows[0].set(0,99)
	capture.tag="array_append";value.meta.rows.append([99])
	capture.tag="dictionary_index";probe_index(value.meta)
	capture.tag="";OS.remove_logger(capture)
	check(value.meta.label=="original" and value.meta.rows[0][0]==1 and value.meta.rows.size()==2,"Attempted set/index/append mutations are rejected without changing shared state")
	check(capture.errors.size()==5,"Four intentional readonly rejections emit five diagnostics: indexed assignment includes native and script rejection")
	return {"expected_rejections":4,"expected_engine_diagnostics":5,"errors":capture.errors}
func run() -> void:
	var extra: Dictionary={}
	if args.get("mutation-probe","false")=="true":extra=mutation_probe()
	else:
		helper_checks();store_checks();await coalesced_checks();await actual_static_checks()
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"expect_loan":expect_loan,"mutation_probe":extra,"scope":"Headless completed static-bundle ownership, readonly structural sharing, packed wrapper isolation and catalog/cache lifecycle; no graphics/server/FPS acceptance"}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close();print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
