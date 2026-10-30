extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Dummies=preload("res://systems/native_render/client_dummies.gd")
const Model=preload("res://systems/native_render/effect_model.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
var checks:=0
var failures: Array=[]
class World extends Node3D:
	var minutes_per_hour:=5
class Manager extends Node3D:
	var world
	var controlled_id:=0x80000001
	var bundle: Dictionary={}
	var pool:=Pool.new()
	var models: Dictionary={}
	var diagnostics: Array=[]
	func create_model(_id: int,name: String):
		if name!="c_dummy": return null
		var model:=Model.new(); add_child(model)
		if not model.load_model(bundle,pool): model.retire(); return null
		models[model.get_instance_id()]=model; return model
	func release_model(model) -> void: models.erase(model.get_instance_id()); model.retire()
	func diagnose(code: String,detail: String,_id: int) -> void: diagnostics.append({"code":code,"detail":detail})
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Read-only original resource mount")
	var manager:=Manager.new(); root.add_child(manager); manager.world=World.new(); manager.add_child(manager.world); manager.pool.picking=false
	var assets:=Assets.new(); manager.add_child(assets); assets.configure(catalog); var result: Dictionary={}
	assets.completed.connect(func(_id,data):result.merge(data))
	assets.request("c_dummy",2002,"actor-model")
	var deadline:=Time.get_ticks_msec()+15000
	while result.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not result.is_empty() and str(result.get("error","unfinished")).is_empty(),"Native original c_dummy model and anchors prepare")
	var dummies:=Dummies.new(); manager.add_child(dummies); dummies.configure(manager)
	if not result.is_empty() and str(result.get("error","unfinished")).is_empty():
		manager.bundle=result
		var point: Variant=dummies.create("point",[1.25,2.5,3.75],50)
		check(point is Dictionary and int(point.id)==0 and int(point.appearance.appearance)==201,"Private original ascending allocation and appearance201")
		if point is Dictionary:
			var token: int=point.privateToken; var model:=dummies.host(int(point.id),token)
			check(model!=null and model.position==Vector3(1.25,3.75,-2.5) and dummies.anchor(int(point.id),token,"root")!=null,"Original dummy model position/physical root binding")
			check(not dummies.has(int(point.id),token+1) and dummies.host(int(point.id),token+1)==null,"Stale private tokens cannot bind another host")
			check(model.find_children("*","CollisionObject3D",true,false).is_empty(),"Private model has no world picking or movement collider")
			check(int(dummies.entries[int(point.id)].state.temporary)==1 and int(dummies.entries[int(point.id)].state.duration)==50 and dummies.stats.display_calls==2,"Native delay is configured before temporary-object flag")
			var weak: WeakRef=weakref(model); await create_timer(0.1).timeout; await process_frame; await process_frame
			check(dummies.entries.is_empty() and manager.models.is_empty() and weak.get_ref()==null and dummies.stats.expired==1,"Native expiry retires AI host, model and rig references")
		var source: Variant=dummies.create("source",[0,0,0],1000)
		check(source==null and dummies.stats.aborted==1 and dummies.entries.is_empty() and manager.models.is_empty() and dummies.next_id==2,"Original source status-zero abort is preserved and consumes its ID")
		var area:=dummies.allocate(true)
		check(int(area.id)==2 and int(area.object.objectType)==11 and area.model==null,"Type11 area allocation shares the private cursor without c_dummy geometry")
		dummies.remove(int(area.id)); var next: Variant=dummies.create("target",[0,0,0],1000)
		check(next is Dictionary and int(next.id)==3,"Private object deletion never recycles an ID")
	dummies.close(); assets.close(); manager.pool.clear(); check(dummies.entries.is_empty() and manager.models.is_empty(),"Closing retires all private hosts independently of the server registry")
	manager.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Original c_dummy model with authored native admission/expiry cases; not proof that every corresponding server packet is emitted"},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
