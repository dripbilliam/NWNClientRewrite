extends SceneTree
# Exercise the actual runtime/BFS/reference owner across asynchronous publication.
# Authored physical nodes: no invented server packets or copied original art.
const Runtime=preload("res://systems/visual_runtime.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Graph=preload("res://systems/native_render/reference_graph.gd")
const Reference=preload("res://systems/native_render/model_reference.gd")
class Helper extends Reference:
	func _ready() -> void: set_process(false)
class ChildModel extends Node3D:
	func retire() -> void: queue_free()
class BeamModel extends Actor:
	var binds:=0
	func attach_to(anchor: Node3D,_flags: int) -> void: global_position=anchor.global_position; binds+=1
	func detach() -> void: pass
class Manager extends Node3D:
	var hosts: Dictionary={}
	var parts: Dictionary={}
	func host(id: int,_token: int=0) -> Node3D: return hosts.get(id)
	func anchor(id: int,_token: int,part: String) -> Node3D: return parts.get(str(id)+"/"+part)
	func diagnose(_code: String,_detail: String,_id: int) -> void: pass
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var manager:=Manager.new(); root.add_child(manager)
	for id in [1,2]:
		var host:=Node3D.new(); manager.add_child(host); manager.hosts[id]=host
		for part in ["root","impact","handconjure"]:
			var node:=Node3D.new(); host.add_child(node); node.position=Vector3(id*3,1,0); manager.parts[str(id)+"/"+part]=node
	var model:=BeamModel.new(); manager.add_child(model)
	var part:=Node3D.new(); model.add_child(part)
	var helper:=Helper.new(); helper.name="native_reference"; helper.original_header={"reattachable":1}; part.add_child(helper)
	var graph:=Graph.new(); check(graph.configure(model,[{"name":"root","parent":-1}],[part]),"Authored physical reference graph configures")
	model.reference_graphs=[graph]
	var runtime:=Runtime.new(); manager.add_child(runtime); runtime.manager=manager
	runtime.definition={"hosts":{"1":{"type":5},"2":{"type":5}},"programs":{"0":{"type":{"value":7}}}}
	runtime.state={"proceduralB8":model,"target54":2,"source58":1,"sourceAnchor28":"handconjure","targetAnchor38":"impact","attached114":1,"programPhaseFa":1,"programsD0":[0,65535,65535]}
	runtime.refresh_bindings()
	check(model.binds==1 and helper.model68==null,"Beam attaches while reference asset is still pending")
	check(helper.install_model(ChildModel.new(),helper.generation),"Late referenced model publishes through actual helper")
	var target: Node3D=manager.parts["2/impact"]
	runtime.refresh_bindings()
	check(model.binds==2 and helper.external_anchor!=null and helper.external_anchor.get_ref()==target,"Publication refreshes BFS endpoint binding to the actual target Part")
	check(helper.model68.global_position.distance_to(target.global_position)<0.00001,"Late model endpoint reaches the target rather than its original source anchor")
	var revision:=helper.revision
	for i in 8: runtime.refresh_bindings()
	check(model.binds==2 and helper.revision==revision,"Stable references do not reattach or increment revision every frame")
	target.position+=Vector3(2,3,1); helper.synchronize_reference_pose(); runtime.refresh_bindings()
	check(model.binds==2 and helper.model68.global_position.distance_to(target.global_position)<0.00001,"Moving target follows the native reference pose without rebinding")
	var replacement:=Node3D.new(); manager.hosts[2].add_child(replacement); replacement.position=Vector3(-3,2,4); manager.parts["2/impact"]=replacement
	runtime.refresh_bindings()
	check(model.binds==3 and helper.external_anchor.get_ref()==replacement and helper.model68.global_position.distance_to(replacement.global_position)<0.00001,"Replacement physical target Part causes one endpoint rebind")
	manager.parts.erase("2/impact"); runtime.refresh_bindings()
	check(not model.visible and runtime.beam_signature.is_empty(),"Missing target Part hides the beam instead of guessing an endpoint")
	manager.parts["2/impact"]=target; runtime.refresh_bindings()
	check(model.binds==4 and model.visible and helper.external_anchor.get_ref()==target,"Restored physical target rebinds and restores visibility")
	runtime.close(); model.retire(); await process_frame; manager.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual native beam runtime/BFS/reference owners over authored nodes; asynchronous publication, stable/moving/replaced/missing endpoints"},"\t")); file.close()
	print("NATIVE_BEAM_BINDING ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
