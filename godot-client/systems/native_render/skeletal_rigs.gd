extends "res://systems/model_rigs.gd"
# Experimental native bone graph. Original physical indices, local transforms,
# clips/events and skin references remain unchanged. No per-bone Node3D tree.
# Kept opt-in until pose/GPU/picking/lifetime comparisons accept this path.
func construction_skeletal() -> bool:return true
func node_at(id: int,index: int) -> Node3D:
	if not entities.has(id) or index<0 or index>=entities[id].parents.size(): return null
	var entry: Dictionary=entities[id]
	if not entry.bone_nodes.has(index):
		var node:=BoneAttachment3D.new(); node.bone_name="part_"+str(index); entry.skeleton.add_child(node); entry.bone_nodes[index]=node
	return entry.bone_nodes[index]
func node_for(id: int,model_index: int,part_name: String="root") -> Node3D:
	if not entities.has(id) or model_index<0 or model_index>=entities[id].model_parts.size(): return null
	var entry: Dictionary=entities[id]; var parts: Array=entry.model_parts[model_index]
	for part in parts:
		var matches: bool=not parts.has(int(entry.parents[int(part)])) if part_name.to_lower()=="root" else str(entry.authored_names[int(part)]).to_lower()==part_name.to_lower()
		if matches: return node_at(id,int(part))
	return null
func sync_attachments(id: int) -> void:
	if not entities.has(id): return
	var entry: Dictionary=entities[id]; var skeleton: Skeleton3D=entry.skeleton
	for attachment in entry.attachments:
		if attachment.has("external_anchor"):
			var held:=int(attachment.node)
			var reference: Node3D=attachment.external_anchor
			var held_attachment: BoneAttachment3D=node_at(id,held)
			if not is_instance_valid(reference) or reference.is_queued_for_deletion():
				held_attachment.visible=false
				continue
			held_attachment.visible=bool(attachment.get("reference_visible",true))
			# Authored reference roots have no bone parent. Convert the exact
			# world-space target used by ModelRigs into Skeleton3D pose space.
			# A non-root held bone also needs its parent's current global pose.
			var rotation: Quaternion=(skeleton.global_basis*skeleton.get_bone_global_pose(held).basis if int(attachment.get("flags",0))==3 else reference.global_basis).orthonormalized().get_rotation_quaternion()
			var target:=skeleton.global_transform.affine_inverse()*Transform3D(Basis(rotation).scaled(_vec(attachment.scale)),reference.global_position)
			var parent:=skeleton.get_bone_parent(held)
			if parent>=0:target=skeleton.get_bone_global_pose(parent).affine_inverse()*target
			skeleton.set_bone_pose_position(held,target.origin)
			skeleton.set_bone_pose_rotation(held,target.basis.get_rotation_quaternion())
			skeleton.set_bone_pose_scale(held,target.basis.get_scale())
			continue
		var pose: Transform3D=skeleton.get_bone_global_pose(int(attachment.anchor)); var held:=int(attachment.node)
		var rotation: Quaternion=(skeleton.get_bone_global_pose(held).basis if int(attachment.get("flags",0))==3 else pose.basis).orthonormalized().get_rotation_quaternion()
		skeleton.set_bone_pose_position(held,pose.origin); skeleton.set_bone_pose_rotation(held,rotation); skeleton.set_bone_pose_scale(held,_vec(attachment.scale))
func diagnostic_sample(ids: Array=[],include_skins: bool=true) -> Dictionary:
	var sample:={"nodes":{},"skins":{},"clocks":{}}
	for id in entities:
		if not ids.is_empty() and not ids.has(id): continue
		var entry: Dictionary=entities[id]
		for index in entry.parents.size(): sample.nodes[str(id)+":"+str(index)]=entry.skeleton.get_bone_pose(index)
		for index in entry.models.size():
			var player: AnimationPlayer=entry.models[index].player
			if player!=null and player.is_playing(): sample.clocks[str(id)+":"+str(index)]={"clip":entry.models[index].clip,"time":player.current_animation_position}
		if not include_skins: continue
		for index in entry.gpu_meshes.size():
			var mesh: MeshInstance3D=entry.gpu_meshes[index]; var baked:=mesh.bake_mesh_from_current_skeleton_pose(); var vertices:=PackedVector3Array()
			for surface in baked.get_surface_count(): vertices.append_array(baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
			sample.skins[str(id)+":"+str(index)]=vertices
	return sample
