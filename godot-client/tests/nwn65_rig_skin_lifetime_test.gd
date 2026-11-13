extends "res://tests/nwn65_rig_skin_publisher_test.gd"

func replacing_case(native: bool) -> Dictionary:
	var row:=setup(native,false,false)
	row.replacement={"done":false,"old":null,"new":null}
	row.entry.skins[0].skeleton.pose_updated.connect(func():
		if row.replacement.done:return
		row.replacement.done=true
		var skin: Dictionary=row.entry.skins[1]
		var old: Skeleton3D=skin.skeleton
		var owner_node: Node=old.get_parent()
		var replacement:=Skeleton3D.new()
		for index in old.get_bone_count():
			replacement.add_bone(old.get_bone_name(index));replacement.set_bone_parent(index,old.get_bone_parent(index));replacement.set_bone_rest(index,old.get_bone_rest(index))
			replacement.set_bone_pose_position(index,old.get_bone_pose_position(index));replacement.set_bone_pose_rotation(index,old.get_bone_pose_rotation(index));replacement.set_bone_pose_scale(index,old.get_bone_pose_scale(index))
		row.replacement.old=weakref(old)
		old.free();owner_node.add_child(replacement)
		skin.skeleton=replacement;skin.mesh.skeleton=skin.mesh.get_path_to(replacement)
		replacement.pose_updated.connect(func():row.forces.append(1))
		row.replacement.new=weakref(replacement))
	return row

func run() -> void:
	if not ClassDB.class_exists("NwnRigSkinPublisher"):check(false,"Native publisher available");finish();return
	var original:=replacing_case(false);var optimized:=replacing_case(true)
	for frame in 12:
		for row in [original,optimized]:
			row.entry.nodes[2].position.x=float(frame)*0.13
			row.rigs._update(0.0625)
		check(var_to_bytes(capture(original))==var_to_bytes(capture(optimized)),"Exact pose/events/force state after later-skin destruction/replacement "+str(frame))
	check(original.replacement.done and optimized.replacement.done,"First force callback replaced later skin")
	check(original.replacement.old.get_ref()==null and optimized.replacement.old.get_ref()==null,"Destroyed old skeleton is not retained by validation")
	check(original.replacement.new.get_ref()!=null and optimized.replacement.new.get_ref()!=null,"Replacement skeleton owns actual later publication")
	check(int(optimized.rigs.native_skin_snapshot(1).completed)==12,"Native route continues across supported live replacement")
	for row in [original,optimized]:
		row.rigs.forget_entity(1);row.host.free()
		check(row.replacement.new.get_ref()==null,"Replacement skeleton retires with original owner")
		row.clear()
	coverage.append("First force destroys and replaces later plain skeleton; fresh validation uses new identity, old Node is released and replacement retires without stale ownership")
	finish()
