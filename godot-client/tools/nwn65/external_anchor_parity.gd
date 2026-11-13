extends SceneTree
const Legacy=preload("res://systems/model_rigs.gd")
const Skeletal=preload("res://systems/native_render/skeletal_rigs.gd")
var checks:=0
var failures: Array=[]
var maximum_position_error:=0.0

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)

func _initialize() -> void:call_deferred("run")

func _world_pose(skeleton: Skeleton3D,index: int) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(index)

func run() -> void:
	var report: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var space:=Node3D.new();root.add_child(space)
	var old:=Legacy.new();space.add_child(old);old.set_process(false)
	var new:=Skeletal.new();space.add_child(new);new.set_process(false)
	old.transform=Transform3D(Basis(Quaternion.from_euler(Vector3(0.1,-0.2,0.3))),Vector3(2.0,-1.0,4.0))
	new.transform=old.transform
	var old_root:=Node3D.new();old.add_child(old_root)
	var held:=Node3D.new();old_root.add_child(held)
	var skeleton:=Skeleton3D.new();new.add_child(skeleton)
	skeleton.add_bone("held");skeleton.set_bone_parent(0,-1);skeleton.set_bone_rest(0,Transform3D.IDENTITY)
	var anchor:=Node3D.new();anchor.name="anchor";space.add_child(anchor)
	var player:=AnimationPlayer.new();space.add_child(player);player.root_node=NodePath("..")
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clip:=Animation.new();clip.length=1.0
	var track:=clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track,NodePath("anchor"))
	clip.track_insert_key(track,0.0,Vector3(0.0,-0.5,1.0))
	clip.track_insert_key(track,1.0,Vector3(2.6,-0.1,0.2))
	var library:=AnimationLibrary.new();library.add_animation("move",clip);player.add_animation_library("",library)
	player.play("move")
	var old_attachment:={"node":0,"anchor":-1,"external_anchor":anchor,"scale":[1.0,1.0,1.0],"flags":0,"reference_visible":true}
	var new_attachment:=old_attachment.duplicate()
	old.entities[7]={"nodes":[held],"attachments":[old_attachment]}
	new.entities[7]={"skeleton":skeleton,"parents":[-1],"bone_nodes":{},"attachments":[new_attachment]}
	for frame in 18:
		player.advance(0.05)
		anchor.quaternion=Quaternion.from_euler(Vector3(0.02*frame,-0.01*frame,0.03*frame))
		old.sync_attachments(7);new.sync_attachments(7)
		check(is_equal_approx(player.current_animation_position,0.05*float(frame+1)),"attachment source clock frame %d"%frame)
		var actual:=_world_pose(skeleton,0)
		maximum_position_error=maxf(maximum_position_error,held.global_position.distance_to(actual.origin))
		check(held.global_position.is_equal_approx(actual.origin),"moving anchor position frame %d"%frame)
		check(held.global_basis.get_rotation_quaternion().is_equal_approx(actual.basis.get_rotation_quaternion()),"moving anchor rotation frame %d"%frame)
	var replacement:=Node3D.new();space.add_child(replacement)
	replacement.position=Vector3(-3.0,2.0,5.0);replacement.quaternion=Quaternion.from_euler(Vector3(0.3,0.2,-0.1))
	old_attachment.external_anchor=replacement;new_attachment.external_anchor=replacement
	old.sync_attachments(7);new.sync_attachments(7)
	check(held.global_position.is_equal_approx(_world_pose(skeleton,0).origin),"replacement anchor position")
	check(held.global_basis.get_rotation_quaternion().is_equal_approx(_world_pose(skeleton,0).basis.get_rotation_quaternion()),"replacement anchor rotation")
	old_attachment.reference_visible=false;new_attachment.reference_visible=false
	old.sync_attachments(7);new.sync_attachments(7)
	check(not held.visible and not new.node_at(7,0).visible,"reference visibility flag tracks bone attachment")
	old_attachment.reference_visible=true;new_attachment.reference_visible=true
	old.sync_attachments(7);new.sync_attachments(7)
	check(held.visible and new.node_at(7,0).visible,"reference visibility recovers")
	replacement.queue_free()
	old.sync_attachments(7);new.sync_attachments(7)
	check(not held.visible and not new.node_at(7,0).visible,"queued anchor hides reference")
	old.entities.clear();new.entities.clear();space.free()
	await process_frame
	var result:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"maximum_position_error":maximum_position_error,"scope":"Synthetic external-anchor position/rotation at 18 real AnimationPlayer clock steps, replacement, visibility flag and queued retirement. No GPU mesh visibility, actual original model, picking, or FPS claim."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
