extends "res://tests/nwn65_rig_skin_publisher_test.gd"
# Compares the current script path with its explicit unchanged-setter opt-out.
# This exercises actual AnimationPlayer, attachments, sparse skins, callbacks,
# reentry and external Skeleton3D edits; it does not measure frame time.

func run() -> void:
	for combined in [true,false]:
		for sparse in [true,false]:
			var reference: Dictionary=setup(false,false,false)
			var candidate: Dictionary=setup(false,false,false)
			reference.rigs.use_combined_skin_setter=combined
			candidate.rigs.use_combined_skin_setter=combined
			reference.rigs.use_skip_identity_skin_setter=sparse
			candidate.rigs.use_skip_identity_skin_setter=sparse
			reference.rigs.use_skip_unchanged_skin_setter=false
			candidate.rigs.use_skip_unchanged_skin_setter=true
			for frame in 24:
				for row in [reference,candidate]:
					if frame==6:
						row.entry.skins[0].skeleton.set_bone_pose_position(2,Vector3(9.0,3.0,-7.0))
						row.entry.skins[1].skeleton.set_bone_pose_rotation(10,Quaternion(Vector3.UP,0.7))
					if frame==12:row.entry.nodes[2].position.y+=0.25
					if frame==16:row.rigs.set_manual_pose(1,row.entry.nodes[1],Vector3(0.2,-0.3,0.4),Quaternion(Vector3.RIGHT,0.2))
					row.rigs._update(0.125 if frame%3==0 else 0.0)
				check(var_to_bytes(capture(reference))==var_to_bytes(capture(candidate)),"Exact skin, clock, event, attachment and force output frame %d combined=%s sparse=%s"%[frame,combined,sparse])
			check(candidate.rigs.skin_unchanged_setter_skips>0 and reference.rigs.skin_unchanged_setter_skips==0,"Unchanged valid-bone setters were avoided combined=%s sparse=%s"%[combined,sparse])
			check(reference.rigs.stats.failures.is_empty() and candidate.rigs.stats.failures.is_empty(),"No rig failure combined=%s sparse=%s"%[combined,sparse])
			for row in [reference,candidate]:
				row.rigs.forget_entity(1)
				row.host.free()
				row.clear()
	coverage.append("Script skin unchanged setter skip: exact 24-frame state, four setter/sparse policies, external bone edits and force callbacks")
	finish()
