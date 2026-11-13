extends SceneTree
const Stream=preload("res://systems/native_render/area_border_stream.gd")
const Loader=preload("res://systems/native_render/area_border_loader.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const SessionRoot=preload("res://native_session_world.gd")
class ControlledAssets extends Node:
	signal completed(id: int,result: Dictionary)
	var pending: Array=[]
	var running: Dictionary={}
	var maximum_workers:=1
	var maximum_pending:=8
	var cache_directory:=""
	var history: Array=[]
	var serial:=0
	var closed:=false
	func configure(_catalog)->void:pass
	func request(name: String,_type: int,_decoder: String)->int:
		serial+=1;pending.append({"id":serial,"name":name});history.append(name);return serial
	func prioritize(_ids: Array)->void:pass
	func answer_all()->void:
		while not pending.is_empty():
			var row: Dictionary=pending.pop_front();completed.emit(int(row.id),{"name":row.name,"error":"","value":{"nodes":[]}})
	func retire_scope()->void:pending.clear()
	func detach_retired_results()->Dictionary:return {}
	func close()->void:closed=true;pending.clear()
class ControlledTemplate extends RefCounted:
	func create()->Node3D:return Node3D.new()
class ControlledPool extends RefCounted:
	var attempted: Array=[]
	var accounted:=0
	var rejected:=false
	var last_bundle: Dictionary={}
	func can_publish()->bool:return true
	func publication_finished(_began: int)->void:accounted+=1
	func model_template(bundle: Dictionary):
		last_bundle=bundle
		attempted.append(bundle.get("resource_name",bundle.get("name","")))
		return null if rejected else ControlledTemplate.new()
class ControlledStream extends "res://systems/native_render/area_border_stream.gd":
	func make_assets():return ControlledAssets.new()
class MissingCatalog extends RefCounted:
	var failure:=""
	func fork():return self
	func has_resource(_name: String,_type: int)->bool:return false
var checks:=0
var failures: Array=[]
var observations: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
func placement(name: String,x: float,orientation: int=0)->Dictionary:
	return {"model":name,"position":Vector3(x,5,-7),"orientation":orientation,"nativeSpawnFlags":1,"sourceIndex":0}
func until(condition: Callable,seconds: float=20.0)->bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while not condition.call() and Time.get_ticks_msec()<deadline:await process_frame
	return condition.call()
func run()->void:
	var output:="";var install:="";var installed_fixture:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
		if argument.begins_with("--install="):install=argument.trim_prefix("--install=")
		if argument.begins_with("--installed-fixture="):installed_fixture=argument.trim_prefix("--installed-fixture=")
	if output.is_empty() or install.is_empty() or installed_fixture.is_empty() or FileAccess.file_exists(output):quit(2);return
	var nonce:=get_instance_id();var context:=[nonce,1,7]
	check(SessionRoot!=null,"Final current SessionWorld source graph compiles against last private lifecycle guards")
	check(Stream.valid_scope(context) and Stream.valid_scope([-99,1,7]) and not Stream.valid_scope([0,1,7]),"Private World nonce is opaque nonzero Godot identity, not invented network connection")
	var plan:={"ready":true,"enabled":true,"loaded":true,"placements":[placement("far",100,3),placement("near",1),placement("near",2,1),placement("near",3,2)]}
	var original:=plan.duplicate(true);var pool:=ControlledPool.new();var stream:=ControlledStream.new();root.add_child(stream);stream.maximum_instances_per_frame=1;stream.set_priority_origin(Vector3.ZERO)
	check(not stream.done and not stream.opened,"Pre-open player priority cannot prematurely complete an unopened decorative owner")
	check(stream.open_plan(MissingCatalog.new(),plan,pool,context),"Prepared original decorative plan opens without any entity/selection owners")
	stream._process(0);check(stream.assets.history==["near","far"],"Existing asset jobs use nearest remaining native placement priority")
	stream.assets.answer_all();stream._process(0)
	check(stream.instances.size()==1 and stream.instances.has(1),"One private clone per budget and nearest ready placement first")
	check(stream.instances[1].position==plan.placements[1].position and not stream.instances[1].has_meta("objectId"),"Exact source transform is applied without a gameplay object ID")
	for tick in 3:stream._process(0)
	check(stream.done and stream.instances.size()==4 and not stream.is_processing(),"Every source decorative placement completes with no idle processing")
	check(stream.instances[2]!=stream.instances[1] and is_equal_approx(stream.instances[2].rotation.y,PI/2) and is_equal_approx(stream.instances[0].rotation.y,3*PI/2),"Shared templates create distinct private scenes with original quarter turns")
	check(pool.attempted.size()==2 and pool.accounted==4,"Only shared Pool template API is used, with every clone publication accounted")
	check(plan==original,"Scheduling consumes private normalized rows without changing pure source plan")
	stream.begin_retirement();var first_step:=stream.retirement_step(1000)
	check(not first_step and stream.instances.size()==3 and not stream.visible,"Retirement hides immediately and releases one private instance per configured step")
	var payload:=stream.detach_prepared_data();check(payload.has("border_plans") and not payload.has("templates") and not payload.has("instances"),"Detached retirement payload contains only data graphs, not scene/GPU owners")
	while not stream.retirement_step(1000):pass
	check(stream.instances.is_empty() and stream.asset_owners().size()==1 and stream.worker_tasks().is_empty(),"Bounded retirement exposes owned asset service and reaches empty private instance set")
	stream.close();stream.free()
	var rejected_pool:=ControlledPool.new();rejected_pool.rejected=true;var failed:=ControlledStream.new();root.add_child(failed);failed.maximum_instances_per_frame=1
	failed.open_plan(MissingCatalog.new(),{"ready":true,"enabled":true,"placements":[placement("bad1",1),placement("bad2",2),placement("bad3",3)]},rejected_pool,context)
	failed._process(0);failed.assets.answer_all();failed._process(0)
	check(rejected_pool.attempted.size()==1 and rejected_pool.accounted==1,"Failed template attempt consumes both local and shared publication budget")
	var stale_id: int=failed.requests.keys()[0] if not failed.requests.is_empty() else 999
	failed.begin_retirement();failed.model_prepared(stale_id,{"error":"","name":"bad3"})
	check(failed.instances.is_empty() and int(failed.stats.stale)>0,"Retired scope rejects late model data without building a scene")
	failed.close();failed.free()
	var malformed:=plan.duplicate(true);malformed.placements[0].position=Vector3(INF,0,0)
	check(not Loader.render_plan(malformed).ready,"Malformed static placement cannot invent a render position")
	var retired:=ControlledStream.new();root.add_child(retired);retired.begin_retirement()
	check(not retired.open_plan(MissingCatalog.new(),plan,ControlledPool.new(),context),"A retired unopened owner cannot revive under a new request")
	retired.close();retired.free()
	var catalog:=Catalog.new();check(catalog.mount_install(install),"Read-only original installation catalog mounts")
	var reference: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(installed_fixture));var sample: Dictionary=reference.samples[0]
	for row in reference.samples:
		if str(row.setName)=="ttr01":sample=row;break
	var definition:={"width":2,"height":2,"tiles":[],"tileset_name":sample.setName,"tileset":{"transition":float(sample.general.Transition),"tiles":sample.tiles}}
	for index in 4:definition.tiles.append({"tile_id":index*17,"orientation":index,"height":index-1})
	var loader:=Loader.new();root.add_child(loader);var loaded: Dictionary={}
	loader.completed.connect(func(ticket,scope,value):loaded.merge({"ticket":ticket,"scope":scope,"value":value},true))
	var first:=loader.request(catalog,definition,{"enabled":true,"disabled":false},context)
	loader.request(catalog,definition,{"enabled":false,"disabled":false},context)
	var last:=loader.request(catalog,definition,{"enabled":true,"disabled":false},context)
	check(first>0 and last>first and await until(func():return not loaded.is_empty()),"Bounded one-active/one-latest planning finishes current optional Edge2DA")
	check(loaded.get("ticket")==last and loaded.scope==context and loader.stats.coalesced==1 and loader.stats.stale>=1,"Older planning result and intermediate toggle cannot replace latest exact scope")
	var prepared: Dictionary=loaded.value
	check(prepared.render.ready and not prepared.render.placements.is_empty() and int(prepared.thread)!=OS.get_main_thread_id(),"Actual installed Edge2DA plan and render grouping run on a private worker")
	var model_name: String=prepared.render.placements[0].model;check(catalog.has_resource(model_name,2002),"Exact original planned border model resolves from active installed catalog")
	var native_stream:=Stream.new();root.add_child(native_stream);var native_pool:=ControlledPool.new()
	check(native_stream.open_plan(catalog,{"ready":true,"enabled":true,"placements":[prepared.plan.placements[0]]},native_pool,context,output.get_base_dir().path_join("data-cache")) and await until(func():return native_stream.done),"Actual private Stream reenables its real Assets and decodes exact planned model")
	check(native_stream.stats.models_prepared==1 and native_stream.instances.size()==1 and native_pool.last_bundle.get("value",{}).get("nodes") is Array,"Actual native static model data reaches private controlled publication without GPU")
	check(not native_stream.assets.is_processing() and not native_stream.is_processing(),"Actual real Assets child and stream stop polling after decorative model completion")
	observations.append({"model":model_name,"plan_thread":prepared.thread,"plan_worker_ms":prepared.worker_ms,"placements":prepared.render.placements.size(),"sha256":native_pool.last_bundle.get("sha256","")})
	native_stream.close();native_stream.free();loader.close();loader.free()
	var missing:=Loader.new();root.add_child(missing);var absent: Dictionary={};missing.completed.connect(func(_ticket,_scope,value):absent.merge(value))
	missing.request(MissingCatalog.new(),definition,{"enabled":true,"disabled":false},context)
	check(await until(func():return not absent.is_empty()) and absent.known_missing and absent.render.ready and absent.render.placements.is_empty(),"Known missing optional Edge2DA completes as empty without filler")
	missing.close();missing.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Private decorative stream priority/publication/error-budget/retirement with controlled scenes; actual installed optional Edge2DA worker plus existing Assets native static-model DATA decoding. No shared World hooks, collision/selection/walkmesh/entity registration, GPU or original-world pixel acceptance."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
