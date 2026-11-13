extends "res://tests/nwn65_rig_components_test.gd"

class CallingModifier extends SkeletonModifier3D:
	var callback: Callable
	var calls:=0
	func _process_modification_with_delta(delta: float) -> void:
		calls+=1
		if callback.is_valid():callback.call(delta)

func modifier_case(native: bool) -> Dictionary:
	var row:=create_case(12)
	var skeleton: Skeleton3D=row.skins[0].skeleton
	skeleton.modifier_callback_mode_process=Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var modifier:=CallingModifier.new();skeleton.add_child(modifier)
	modifier.callback=func(_delta):
		if native:row.publisher.call("publish")
		else:original_publish(row)
	row.modifier=modifier;row.modified=[];row.blended=[]
	modifier.modification_processed.connect(func():row.modified.append(capture(row)))
	skeleton.skeleton_updated.connect(func():row.blended.append(capture(row)))
	return row

func run() -> void:
	if not options.has("report") or FileAccess.file_exists(options.report):quit(2);return
	if not ClassDB.class_exists("NwnRigSkinPublisher"):check(false,"Native publisher available");await finish({});return
	var original:=modifier_case(false);var optimized:=modifier_case(true)
	for influence in [0.0,0.25,0.5,0.75,1.0]:
		var original_before: int=original.modifier.calls;var optimized_before: int=optimized.modifier.calls
		for row in [original,optimized]:
			row.modifier.influence=influence
			row.nodes[3].position=Vector3(0.3+influence,-0.8,1.2)
			row.nodes[5].quaternion=Quaternion.from_euler(Vector3(0.3,-0.7,0.2+influence))
			var skeleton: Skeleton3D=row.skins[0].skeleton
			for bone in skeleton.get_bone_count():
				skeleton.set_bone_pose(bone,Transform3D(Basis(Quaternion.from_euler(Vector3(0.1,0.2,0.3))).scaled(Vector3(0.8,1.3,0.9)),Vector3(0.2*bone,0.3,-0.4)))
			skeleton.advance(0.125)
		await process_frame;await process_frame
		check(original.modifier.calls>original_before and optimized.modifier.calls>optimized_before,"Real modifier callback runs at influence "+str(influence))
		check(original.modifier.calls==optimized.modifier.calls,"Modifier invocation count preserved "+str(influence))
		check(original.modified==optimized.modified,"Exact components inside modifier callback before influence "+str(influence))
		check(original.blended==optimized.blended,"Exact post-influence skeleton state and signal count "+str(influence))
		check(capture(original)==capture(optimized),"Exact unmodified pose restoration after deferred update "+str(influence))
	check(not optimized.blended.is_empty(),"Actual post-modifier skeleton signals observed")
	var metadata:={"modifier_calls":optimized.modifier.calls,"modified_snapshots":optimized.modified.size(),"blended_snapshots":optimized.blended.size(),"publication":optimized.publisher.call("inspect")}
	for row in [original,optimized]:row.modifier.callback=Callable();row.publisher=null
	await finish(metadata)
