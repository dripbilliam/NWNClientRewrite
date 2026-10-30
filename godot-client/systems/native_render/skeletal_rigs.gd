extends "res://systems/model_rigs.gd"
# Experimental native bone graph. Original physical indices, local transforms,
# clips/events and skin references remain unchanged. No per-bone Node3D tree.
# Kept opt-in until pose/GPU/picking/lifetime comparisons accept this path.
func configure(value,pivots: Dictionary,metadata: Dictionary) -> void:
	registry=value
	var data: Dictionary=metadata.get("rigs",{})
	for source in data.get("entities",[]):
		var id:=int(source.id)
		if not pivots.has(id): continue
		var before: Dictionary=stats.duplicate(true); var rig:=Node3D.new(); rig.name="NativeSkeletalRig"; pivots[id].add_child(rig)
		var skeleton:=Skeleton3D.new(); skeleton.name="OriginalBones"; rig.add_child(skeleton)
		for index in source.nodes.size():
			var row: Dictionary=source.nodes[index]; var parent:=int(row.parent)
			if parent>=index or parent< -1: _fail("Native bone graph has invalid physical parent"); return
			skeleton.add_bone("part_"+str(index)); skeleton.set_bone_parent(index,parent)
			skeleton.set_bone_rest(index,Transform3D.IDENTITY)
			skeleton.set_bone_pose_position(index,_vec(row.position)); skeleton.set_bone_pose_rotation(index,_quat(row.quaternion)); skeleton.set_bone_pose_scale(index,_vec(row.scale))
		var entry:={"root":rig,"skeleton":skeleton,"bone_nodes":{},"nodes":[],"parents":source.nodes.map(func(row): return int(row.parent)),"models":[],"animated_models":[],"skins":[],"gpu_meshes":[],"attachments":source.get("attachments",[]),"clip_map":source.get("clipMap",{}),"side_maps":source.get("sideMaps",{}),"context":source.get("context",{}).duplicate(true),"body_type":int(source.get("bodyType",0)),"side":0,"loop_map":source.get("loopMap",{}),"animation":-1,"authored_names":source.nodes.map(func(row): return str(row.name)),"model_parts":source.models.map(func(model): return model.parts.duplicate()),"manual_poses":{},"model18":false,"model18_unavailable":false}
		entities[id]=entry
		var no_nodes: Array[Node3D]=[]
		for model_index in source.models.size():
			var original: Dictionary=source.models[model_index]; var binding: Dictionary=original.duplicate(); binding.skeleton_target=skeleton
			var asset: Dictionary=data.assets[int(original.asset)]; var model: Dictionary=_model(rig,no_nodes,binding,asset)
			model.asset_source=asset; model.part_source=binding; model.event_source=model_index==int(source.get("animationSource",0))
			if model.player!=null: entry.animated_models.append(model_index)
			entry.models.append(model)
		var conservative:=AABB(); var has_bounds:=false
		for row in metadata.get("meshes",[]):
			if int(row.get("objectId",-1))!=id: continue
			var mesh: MeshInstance3D=registry.meshes_by_name.get(str(row.name))
			if mesh==null: _fail("Native skeletal mesh binding absent"); continue
			var part:=int(row.rigNode)
			var box: AABB=skeleton.get_bone_global_pose(part)*mesh.get_aabb(); conservative=conservative.merge(box) if has_bounds else box; has_bounds=true
			mesh.reparent(rig,false); mesh.transform=Transform3D.IDENTITY
			if row.has("skin"):
				var original_model: Dictionary=source.models[int(row.skin.model)]
				var skin: Dictionary=_skin(mesh,row.skin,original_model.parts)
				if skin.is_empty(): continue
				var bind:=Skin.new()
				for slot in skin.bones.size(): bind.add_bind(int(skin.bones[slot]) if int(skin.bones[slot])>=0 else part,skin.inverse[slot])
				bind.add_bind(part,Transform3D.IDENTITY); mesh.skin=bind; skin.skeleton.free()
			else:
				var bind:=Skin.new(); bind.add_bind(part,Transform3D.IDENTITY); mesh.skin=bind; stats.rigid_meshes+=1
			mesh.skeleton=mesh.get_path_to(skeleton); entry.gpu_meshes.append(mesh)
			if mesh.has_meta("native_pick_shape") or mesh.has_meta("native_pick_geometry"): mesh.set_meta("native_pick_anchor",node_at(id,part)); mesh.set_meta("native_pick_bounds",mesh.get_aabb())
		# Preserve all potentially posed geometry while this experiment lacks
		# original animated bounds; a broad conservative box never drops a limb.
		if has_bounds:
			conservative=conservative.grow(maxf(1.0,conservative.size.length()))
			for mesh in entry.gpu_meshes: mesh.custom_aabb=conservative
		stats.entities+=1; stats.nodes+=source.nodes.size(); entry.counts={}
		for key in ["entities","nodes","players","clips","indexed_clip_models","indexed_clip_metadata","skin_meshes","skin_prepared_meshes","skin_main_meshes","rigid_meshes","skin_vertices"]: entry.counts[key]=stats[key]-before[key]
		for model in entry.models: model.entity_counts=entry.counts
	_update(0.0)
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
		if attachment.has("external_anchor"): _fail("Experimental bone graph needs an external reference adapter"); continue
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
