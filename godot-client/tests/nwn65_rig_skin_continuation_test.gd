extends "res://tests/nwn65_rig_skin_publisher_test.gd"
class CustomSkeleton:
	extends Skeleton3D
func continuation_setup(native: bool) -> Dictionary:
	var row: Dictionary=setup(native,false,false)
	var extra: Dictionary=row.rigs._skin(make_mesh(row.entry.nodes[2]),skin_source(),[0,1,2,3,4])
	row.entry.skins.append(extra);extra.skeleton.pose_updated.connect(func() -> void:row.forces.append(2))
	row.original_skins=row.entry.skins
	row.continuation_state={"changed":false,"nested":false}
	var first: Skeleton3D=row.original_skins[0].skeleton
	var second: Skeleton3D=row.original_skins[1].skeleton
	first.pose_updated.connect(func() -> void:
		if row.continuation_state.changed:return
		row.continuation_state.changed=true
		# Preflight accepted all three plain skins. This current force callback
		# makes the later skin unsupported, changes Node inputs, and replaces the
		# entry's skins Array. Original outer iteration still owns the old Array
		# and its precallback rigid matrices, so a restart/recompute is incorrect.
		second.set_script(CustomSkeleton)
		row.entry.nodes[2].position+=Vector3(0.21,0.37,-0.13)
		row.entry.skins=[row.original_skins[0]])
	second.pose_updated.connect(func() -> void:
		if row.continuation_state.nested:return
		row.continuation_state.nested=true
		# In the candidate this occurs during the legacy continuation, after the
		# native outer call returned. The nested native call reuses its scratch;
		# the last outer skin must still consume an independent OLD matrix Array.
		row.rigs._update(0.03125))
	return row
func continuation_capture(row: Dictionary) -> Dictionary:
	var entry: Dictionary=row.entry.duplicate();entry.skins=row.original_skins
	var inspected: Dictionary=row.duplicate();inspected.entry=entry
	return capture(inspected)
func run() -> void:
	if not ClassDB.class_exists("NwnRigSkinPublisher") or not ClassDB.class_has_method("NwnRigSkinPublisher","take_continuation"):
		check(false,"Private v2 engine continuation exists");finish();return
	check(int(ClassDB.class_call_static("NwnRigSkinPublisher","abi_version"))==2,"Continuation ABI is explicit")
	var ordinary: Dictionary=continuation_setup(false);var candidate: Dictionary=continuation_setup(true)
	for frame: int in 3:
		for row: Dictionary in [ordinary,candidate]:
			if frame==1:row.entry.skins=row.original_skins
			if frame==2:row.original_skins[1].skeleton.set_script(null)
			row.rigs._update(0.125)
		check(var_to_bytes(continuation_capture(ordinary))==var_to_bytes(continuation_capture(candidate)),"Exact unsupported-after-force continuation, independent outer matrices and same original Array frame "+str(frame))
	check(ordinary.forces.slice(0,4)==[0,1,0,2] and candidate.forces.slice(0,4)==[0,1,0,2],"No repeated/lost outer force; nested update remains in original order")
	var state: Dictionary=candidate.rigs.native_skin_snapshot(1)
	check(int(state.continuations)==1 and int(state.partial_failures)==0 and int(state.fallbacks)==1 and int(state.completed)>=2 and not bool(state.continuation_pending),"Exactly one continuation consumed, later preflight fallback and restored native route")
	var publisher: RefCounted=candidate.rigs.native_skin_publishers[1][1]
	check(publisher.call("take_continuation").is_empty(),"Continuation is single-use")
	publisher=null
	for row: Dictionary in [ordinary,candidate]:
		check(row.rigs.stats.failures.is_empty(),"No new rig failure from supported fallback semantics")
		var weak: WeakRef=weakref(row.rigs.native_skin_publishers[1][1]) if row.rigs.native_skin_publishers.has(1) else null
		row.rigs.forget_entity(1);check(weak==null or weak.get_ref()==null,"Continuation owner releases after forget")
		row.host.free();row.clear()
	coverage.append("actual original/native three-skin force callback script attachment, array replacement, fresh Node mutation, nested scratch reuse, old-matrix continuation, recovery and lifetime")
	finish()
