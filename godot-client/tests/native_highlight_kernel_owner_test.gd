extends SceneTree
const Bounds=preload("res://tools/native_parity/highlighting/native_highlight_bounds_kernel.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	check(not ClassDB.class_exists("NwnHighlightGeometry"),"Fixture starts without explicit/global highlight extension loading")
	var bounds:=Bounds.new();root.add_child(bounds)
	check(ClassDB.class_exists("NwnHighlightGeometry") and Bounds.kernel_extension!=null,"Actual opt-in bounds owner loads private extension through relocation descriptor")
	check(bounds.batch.get_parent()==bounds,"Derived adapter retains original batch-node ownership")
	var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(3,4,5)
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
	check(bounds.configure_texture(ImageTexture.create_from_image(image),{"filter":true,"mipmap":true,"clamp":0},false),"Test texture binds existing shader path without alternative rendering")
	var physical:=Node3D.new();root.add_child(physical)
	var part_a:=Node3D.new();var part_b:=Node3D.new();physical.add_child(part_a);physical.add_child(part_b);part_b.position=Vector3(2,0,0)
	var descriptors: Array=[]
	for part in [part_a,part_b]:descriptors.append({"anchor":part,"native_bounds":{"min":[-1,-1,-1],"max":[1,1,1]},"is_skin":false,"subtree_enabled":true,"model_index":3})
	var calls:={"alpha":0,"color":0}
	var alpha:=func(_model):calls.alpha+=1;return 0.25
	var color:=func(_model):calls.color+=1;return Vector3(0,1,0)
	check(bounds.register_entity(1,physical,[1,2,3],descriptors,Color.WHITE,alpha,color),"Explicit Part ownership registers through unchanged helper contract")
	bounds.mark([1]);check(bounds.tick(camera,2.5,0.3),"Native adapter publishes actual retained vertex and attribute regions")
	check(calls.alpha==1 and calls.color==1,"Alpha/colour callbacks are once per selected model rather than per Part")
	check(bounds.kernel_stats.calls==1 and bounds.kernel_stats.failures==0 and bounds.batch.visible and bounds.stats.vertices==36,"Native call covers both physical Parts and current draw bounds")
	var rebuilds: int=bounds.stats.membership_rebuilds;bounds.tick(camera,2.5,0.3)
	check(bounds.stats.membership_rebuilds==rebuilds and calls.alpha==2 and calls.color==2,"Steady frames reuse membership and query fresh model state once")
	bounds.entries[1].color_source=func(_model):bounds.forget(1);return Vector3.ONE
	var native_calls: int=bounds.kernel_stats.calls
	check(not bounds.tick(camera,2.5,0.3) and bounds.kernel_stats.calls==native_calls and not bounds.batch.visible,"Synchronous provider removal revokes pending native call and publication")
	bounds.register_entity(2,physical,[1,2,4],descriptors,Color.WHITE,alpha,color);bounds.mark([2]);physical.free()
	bounds.tick(camera,2.5,0.3)
	check(bounds.members.is_empty() and not bounds.batch.visible and bounds.kernel_stats.failures==0,"Freed physical owners retire membership rather than submitting invalid native Transform variants")
	bounds.close();bounds.close();check(bounds.kernel_shapes.is_empty() and bounds.kernel_poses.is_empty() and not bounds.tick(camera,2.5,0.3),"Idempotent close releases only local POD buffers and prevents later submission")
	bounds.free();camera.free();await process_frame
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual helper/extension load, weak lifetime/provider/reentry and native buffer publication; no GPU/FPS or server claim"}
	if not output.is_empty():FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("NATIVE_HIGHLIGHT_KERNEL_OWNER ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
