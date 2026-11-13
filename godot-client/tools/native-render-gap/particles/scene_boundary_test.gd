extends SceneTree
var failures: Array[String]=[]
var checks: int=0
const API="NwnParticleSceneBoundary"
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func invoke(name: String,args: Array=[]) -> Variant:
	return ClassDB.class_call_static.callv([API,name]+args)
func flags(node: Node3D) -> int:return int(invoke("eligibility_flags",[node.get_instance_id()]))
func exact_pose(node: Node3D,message: String) -> void:
	var expected: Transform3D=node.global_transform
	var actual: Transform3D=invoke("global_transform",[node.get_instance_id()])
	check(var_to_bytes(expected)==var_to_bytes(actual),message)
func finish() -> void:
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Exact live scene reads; no FPS/GPU/authority claim"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file: FileAccess=FileAccess.open(arg.substr(9),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(report,"\t")+"\n")
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func run() -> void:
	if not ClassDB.class_exists(API):check(false,"Required private engine scene boundary exists");finish();return
	check(int(invoke("abi_version"))==1,"Versioned float32 helper")
	var host: Node3D=Node3D.new();root.add_child(host)
	var parent: Node3D=Node3D.new();host.add_child(parent)
	var node: Node3D=Node3D.new();parent.add_child(node)
	check(flags(node)==31,"Fresh eligible member")
	exact_pose(node,"Initial live global transform")
	parent.position=Vector3(2,3,4);parent.quaternion=Quaternion(Vector3.UP,0.77);parent.scale=Vector3(-2,3,0.5)
	node.position=Vector3(0.3,-1,2);node.quaternion=Quaternion(Vector3.RIGHT,0.31)
	exact_pose(node,"Dirty ancestor is resolved at the current boundary")
	# Stand in for an earlier readiness/clock/provider callback. There is no
	# cached frame packet, so the later consumer sees each same-frame mutation.
	parent.hide();check(flags(node)==7,"Same-frame ancestor hide")
	parent.show();node.process_mode=Node.PROCESS_MODE_DISABLED;check(flags(node)==15,"Current process mode")
	node.process_mode=Node.PROCESS_MODE_INHERIT;paused=true;check(flags(node)==15,"Current tree pause")
	node.process_mode=Node.PROCESS_MODE_ALWAYS;check(flags(node)==31,"Always-process exemption")
	paused=false;node.process_mode=Node.PROCESS_MODE_INHERIT
	var other: Node3D=Node3D.new();host.add_child(other);other.position=Vector3(30,20,10)
	node.reparent(other,false);exact_pose(node,"Same-frame reparent and new dirty ancestry")
	other.remove_child(node);check(flags(node)==3,"Outside-tree eligibility")
	other.add_child(node);exact_pose(node,"Same-instance re-entry")
	var old_id: int=node.get_instance_id();node.free()
	check(int(invoke("eligibility_flags",[old_id]))==0,"Freed ID is absent immediately")
	var missing: Transform3D=invoke("global_transform",[old_id])
	check(is_nan(missing.origin.x) and int(invoke("pose_status"))==1,"Freed pose has explicit status, never substituted identity")
	var plain: Node=Node.new();host.add_child(plain)
	check(int(invoke("eligibility_flags",[plain.get_instance_id()]))==1,"Non-Node3D existence/type distinction")
	var wrong: Transform3D=invoke("global_transform",[plain.get_instance_id()])
	check(is_nan(wrong.origin.x) and int(invoke("pose_status"))==2,"Wrong-type pose status")
	var replacement: Node3D=Node3D.new();other.add_child(replacement);replacement.position=Vector3(7,8,9)
	exact_pose(replacement,"Replacement object has its own current identity")
	var replacement_id: int=replacement.get_instance_id()
	var worker: Thread=Thread.new()
	worker.start(func() -> Array:
		var unsupported_flags: int=int(ClassDB.class_call_static(API,"eligibility_flags",replacement_id))
		var unsupported_pose: Transform3D=ClassDB.class_call_static(API,"global_transform",replacement_id)
		return [unsupported_flags,is_nan(unsupported_pose.origin.x),int(ClassDB.class_call_static(API,"pose_status"))])
	var worker_result: Array=worker.wait_to_finish()
	check(worker_result==[1<<30,true,3],"Worker requests reject before touching ObjectDB/Nodes")
	exact_pose(replacement,"Worker rejection does not corrupt main-thread status")
	check(int(invoke("pose_status"))==0,"Pose status is thread-local and current")
	host.free();finish()
