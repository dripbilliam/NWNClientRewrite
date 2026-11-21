extends RefCounted
# Main-thread cooperative construction. The live registry sees only complete
# entities. A cancelled job restores borrowed meshes before freeing its roots.
const COUNTERS=["entities","nodes","players","clips","indexed_clip_models","indexed_clip_metadata","skin_meshes","skin_prepared_meshes","skin_main_meshes","rigid_meshes","skin_vertices"]
var owner
var pivots: Dictionary
var metadata: Dictionary
var data: Dictionary
var skeletal:=false
var source_index:=0
var phase:="entity"
var index:=0
var source: Dictionary={}
var entry: Dictionary={}
var ready: Array=[]
var restores: Array=[]
var total_counts: Dictionary={}
var entry_counts: Dictionary={}
var status:="pending"
var failure:=""
var steps:=0
var max_step_us:=0
func configure(target,value: Dictionary,context: Dictionary,bones: bool)->void:
	owner=target;pivots=value;metadata=context;data=context.get("rigs",{});skeletal=bones
func _counts()->Dictionary:
	var result: Dictionary={}
	for key in COUNTERS:result[key]=int(owner.stats[key])
	return result
func _record(before: Dictionary)->void:
	for key in COUNTERS:
		var change:=int(owner.stats[key])-int(before[key]);total_counts[key]=int(total_counts.get(key,0))+change;entry_counts[key]=int(entry_counts.get(key,0))+change
func _begin_entity()->void:
	source=data.entities[source_index];source_index+=1;entry_counts={}
	var rig:=Node3D.new();rig.name="NativeSkeletalRig" if skeletal else "ModelRig"
	rig.hide();owner.add_child(rig)
	var nodes: Array[Node3D]=[]
	entry={"root":rig,"nodes":nodes,"parents":[],"models":[],"animated_models":[],"skins":[],"attachments":source.get("attachments",[]),"clip_map":source.get("clipMap",{}),"side_maps":source.get("sideMaps",{}),"context":source.get("context",{}).duplicate(true),"body_type":int(source.get("bodyType",0)),"side":0,"loop_map":source.get("loopMap",{}),"animation":-1,"authored_names":[],"model_parts":[],"manual_poses":{},"model18":false if skeletal else bool(source.get("model18",false)),"model18_unavailable":false if skeletal else bool(source.get("model18Unavailable",false))}
	if skeletal:
		var skeleton:=Skeleton3D.new();skeleton.name="OriginalBones";rig.add_child(skeleton);entry.skeleton=skeleton;entry.bone_nodes={};entry.gpu_meshes=[];entry.conservative=AABB();entry.has_bounds=false
	phase="nodes";index=0
func _node()->bool:
	var row: Dictionary=source.nodes[index];var parent:=int(row.parent)
	if parent>=index or parent< -1:failure="Native rig construction contains an invalid physical parent";return false
	if skeletal:
		var skeleton: Skeleton3D=entry.skeleton;skeleton.add_bone("part_"+str(index));skeleton.set_bone_parent(index,parent);skeleton.set_bone_rest(index,Transform3D.IDENTITY)
		skeleton.set_bone_pose_position(index,owner._vec(row.position));skeleton.set_bone_pose_rotation(index,owner._quat(row.quaternion));skeleton.set_bone_pose_scale(index,owner._vec(row.scale))
	else:
		var node:=Node3D.new();node.name="part_%s"%index
		(entry.root if parent== -1 else entry.nodes[parent]).add_child(node);node.position=owner._vec(row.position);node.quaternion=owner._quat(row.quaternion);node.scale=owner._vec(row.scale);node.visible=row.get("visible",true);entry.nodes.append(node)
	entry.parents.append(parent);entry.authored_names.append(str(row.name));index+=1;return true
func _model()->void:
	var original: Dictionary=source.models[index];var binding: Dictionary=original.duplicate() if skeletal else original
	if skeletal:binding.skeleton_target=entry.skeleton
	var asset: Dictionary=data.assets[int(original.asset)];var model: Dictionary=owner._model(entry.root,entry.nodes,binding,asset)
	model.asset_source=asset;model.part_source=binding;model.event_source=index==int(source.get("animationSource",0))
	if model.player!=null:entry.animated_models.append(index)
	entry.models.append(model);entry.model_parts.append(original.parts.duplicate());index+=1
func _bone_node(part: int)->Node3D:
	if not entry.bone_nodes.has(part):
		var node:=BoneAttachment3D.new();node.bone_name="part_"+str(part);entry.skeleton.add_child(node);entry.bone_nodes[part]=node
	return entry.bone_nodes[part]
func _remember(mesh: MeshInstance3D)->void:
	restores.append({"mesh":mesh,"parent":weakref(mesh.get_parent()) if mesh.get_parent()!=null else null,"transform":mesh.transform,"mesh_resource":mesh.mesh,"skin":mesh.skin,"skeleton":mesh.skeleton,"custom_aabb":mesh.custom_aabb,"anchor":mesh.get_meta("native_pick_anchor") if mesh.has_meta("native_pick_anchor") else null,"bounds":mesh.get_meta("native_pick_bounds") if mesh.has_meta("native_pick_bounds") else null})
func _mesh()->void:
	var row: Dictionary=metadata.get("meshes",[])[index];index+=1
	if int(row.get("objectId",-1) if row.get("objectId")!=null else -1)!=int(source.id) or not row.has("rigNode") or not skeletal and row.get("particle",false):return
	var mesh: MeshInstance3D=owner.registry.meshes_by_name.get(str(row.name))
	if mesh==null:owner._fail("An animated source mesh binding is missing");return
	_remember(mesh)
	var part:=int(row.rigNode)
	if skeletal:
		var skeleton: Skeleton3D=entry.skeleton;var box: AABB=skeleton.get_bone_global_pose(part)*mesh.get_aabb();entry.conservative=entry.conservative.merge(box) if entry.has_bounds else box;entry.has_bounds=true
		mesh.reparent(entry.root,false);mesh.transform=Transform3D.IDENTITY
		if row.has("skin"):
			var original: Dictionary=source.models[int(row.skin.model)];var skin: Dictionary=owner._skin(mesh,row.skin,original.parts)
			if skin.is_empty():return
			var bind:=Skin.new()
			for slot in skin.bones.size():bind.add_bind(int(skin.bones[slot]) if int(skin.bones[slot])>=0 else part,skin.inverse[slot])
			bind.add_bind(part,Transform3D.IDENTITY);mesh.skin=bind;skin.skeleton.free()
		else:
			var bind:=Skin.new();bind.add_bind(part,Transform3D.IDENTITY);mesh.skin=bind;owner.stats.rigid_meshes+=1
		mesh.skeleton=mesh.get_path_to(skeleton);entry.gpu_meshes.append(mesh)
		if mesh.has_meta("native_pick_shape") or mesh.has_meta("native_pick_geometry"):mesh.set_meta("native_pick_anchor",_bone_node(part));mesh.set_meta("native_pick_bounds",mesh.get_aabb())
	else:
		var target: Node3D=entry.nodes[part];mesh.reparent(target,false);mesh.position=owner._vec(row.rigLocal.position);mesh.quaternion=owner._quat(row.rigLocal.quaternion);mesh.scale=owner._vec(row.rigLocal.scale)
		if row.has("skin"):
			var original: Dictionary=source.models[int(row.skin.model)];var skin: Dictionary=owner._skin(mesh,row.skin,original.parts)
			if not skin.is_empty():entry.skins.append(skin)
		else:
			owner.stats.rigid_meshes+=1
			var body=mesh.get_meta("collision_body") if mesh.has_meta("collision_body") else null
			if is_instance_valid(body):
				restores.append({"body":body,"parent":weakref(body.get_parent()) if body.get_parent()!=null else null,"transform":body.transform});body.reparent(target,true)
func _finish_entity()->void:
	if skeletal and entry.has_bounds:
		var bounds: AABB=entry.conservative.grow(maxf(1.0,entry.conservative.size.length()))
		for mesh in entry.gpu_meshes:mesh.custom_aabb=bounds
	owner.stats.entities+=1;owner.stats.nodes+=source.nodes.size()
	ready.append({"id":int(source.id),"pivot":pivots[int(source.id)],"entry":entry});phase="entity";index=0
func _commit()->void:
	for row in ready:
		if not is_instance_valid(row.pivot) or row.pivot.is_queued_for_deletion() or not is_instance_valid(row.entry.root) or row.entry.root.get_parent()!=owner:failure="Native rig construction pivot retired";return
	for row in ready:
		row.entry.root.reparent(row.pivot,false);row.entry.root.name="NativeSkeletalRig" if skeletal else "ModelRig";row.entry.root.show();owner.native_skin_publishers.erase(int(row.id));owner.entities[int(row.id)]=row.entry
	ready.clear();restores.clear();total_counts.clear();owner._update(0.0);owner._refresh_processing();status="ready"
func step(maximum_units: int=8,budget_us: int=1500)->Dictionary:
	if status!="pending":return {"status":status,"reason":failure,"units":0}
	var began:=Time.get_ticks_usec();var units:=0
	while units<maxi(1,maximum_units) and status=="pending":
		if units>0 and budget_us>0 and Time.get_ticks_usec()-began>=budget_us:break
		var before:=_counts()
		if phase=="entity":
			if source_index>=data.get("entities",[]).size():
				_commit()
				if not failure.is_empty():cancel();status="failed"
				break
			var candidate: Dictionary=data.entities[source_index]
			if not pivots.has(int(candidate.id)):source_index+=1;units+=1;continue
			_begin_entity()
		elif not is_instance_valid(pivots.get(int(source.id))) or pivots[int(source.id)].is_queued_for_deletion():failure="Native rig construction pivot retired"
		elif phase=="nodes":
			if index>=source.nodes.size():phase="models";index=0;continue
			_node()
		elif phase=="models":
			if index>=source.models.size():phase="meshes";index=0;continue
			_model()
		elif phase=="meshes":
			if index>=metadata.get("meshes",[]).size():phase="finish";continue
			_mesh()
		elif phase=="finish":_finish_entity()
		_record(before);units+=1
		if phase=="entity" and not ready.is_empty():
			var complete: Dictionary=ready[-1].entry;complete.counts=entry_counts.duplicate()
			for model in complete.models:model.entity_counts=complete.counts
		if not failure.is_empty():cancel();status="failed";break
	var elapsed:=Time.get_ticks_usec()-began;steps+=1;max_step_us=maxi(max_step_us,elapsed)
	return {"status":status,"reason":failure,"phase":phase,"units":units,"step_us":elapsed}
func cancel()->void:
	if status!="pending":return
	for row in restores:
		var node=row.get("body",row.get("mesh"))
		if not is_instance_valid(node):continue
		var parent: Node=row.parent.get_ref() if row.parent!=null else null
		if is_instance_valid(parent):
			if node.get_parent()!=parent:node.reparent(parent,false)
		elif node.get_parent()!=null:node.get_parent().remove_child(node)
		node.transform=row.transform
		if row.has("mesh"):
			node.mesh=row.mesh_resource;node.skin=row.skin;node.skeleton=row.skeleton;node.custom_aabb=row.custom_aabb
			for name in ["native_pick_anchor","native_pick_bounds"]:
				var value: Variant=row.anchor if name=="native_pick_anchor" else row.bounds
				if value!=null:node.set_meta(name,value)
				elif node.has_meta(name):node.remove_meta(name)
	restores.clear()
	var roots: Array=[]
	for row in ready:roots.append(row.entry.root)
	if not entry.is_empty() and not roots.has(entry.root):roots.append(entry.root)
	for root in roots:
		if is_instance_valid(root):root.free()
	for key in total_counts:owner.stats[key]-=int(total_counts[key])
	ready.clear();entry={};total_counts.clear();status="cancelled"
