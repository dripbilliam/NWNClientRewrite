extends SceneTree
const Observation=preload("res://systems/native_render/camera_observation.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var parent:=Node3D.new();root.add_child(parent);parent.position=Vector3(10,3,-2);parent.rotation.y=0.5
	var camera:=Camera3D.new();parent.add_child(camera);camera.position=Vector3(1,2,3);camera.fov=45;camera.keep_aspect=Camera3D.KEEP_HEIGHT
	await process_frame
	var local:=camera.position;var expected:=parent.global_transform*local
	var defaults:={"position":[0,0,0],"quaternion":[0,0,0,1],"pose_valid":false,"size":[3440,1369]}
	var view:=Observation.capture_view(camera,null,defaults)
	check(view.position==[expected.x,expected.y,expected.z],"world position survives defaults")
	check(view.position!=[local.x,local.y,local.z],"reparented local position is not capture pose")
	check(view.pose_valid and view.pose_space=="world","valid world pose declaration")
	check(view.quaternion!=[0,0,0,1],"world rotation survives placeholder")
	check(view.fov==45 and view.fov_degrees==45,"actual FOV captured")
	check(view.projection==Camera3D.PROJECTION_PERSPECTIVE and view.keep_aspect==Camera3D.KEEP_HEIGHT,"projection convention captured")
	check(view.near>0 and view.far>view.near,"actual clip planes captured")
	check(view.size==defaults.size,"unrelated view settings retained")
	check(defaults.position==[0,0,0] and not defaults.pose_valid,"fallback dictionary remains detached")
	check(camera.position==local,"observation never moves camera")
	check(Observation.capture_view(null,null,defaults)==defaults,"missing camera retains explicit unavailable fallback")
	parent.free()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Real reparented native Camera3D read-only capture/projection evidence; no world, network or GPU acceptance"}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			var file:=FileAccess.open(argument.trim_prefix("--out="),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
