extends RefCounted
const Base=preload("res://tools/native-render-gap/scene/rig_topology_census.gd")
# Cold read-only census of every live AnimationPlayer plus known rig/manual/
# attachment publishers. Loaded resources only: never resolve a lazy clip.
static func descendants(node: Node3D)->Array:
	var result: Array=[];var pending: Array[Node3D]=[node]
	while not pending.is_empty():
		var current: Node3D=pending.pop_back()
		if current is MeshInstance3D:result.append(current.get_instance_id())
		for child: Node in current.get_children(true):
			if child is Node3D and not child.is_set_as_top_level():pending.append(child)
	return result
static func player_snapshot(player: AnimationPlayer,context: Dictionary,memo: Dictionary,skin_meshes: Dictionary)->Dictionary:
	var row:={"player_id":player.get_instance_id(),"name":str(player.name),"path":str(player.get_path()),"playing":player.is_playing(),"current_animation":str(player.current_animation),"assigned_animation":str(player.assigned_animation),"callback_mode":int(player.callback_mode_process),"active":player.active,"speed_scale":player.speed_scale,"process_mode":int(player.process_mode),"context":context,"tracks":[],"node_transform_targets":[],"bone_targets":[],"unresolved_targets":0}
	row["effective_ordinary_publisher"]=row.playing and row.active and not bool(context.get("native_owner",false))
	var clip_name: String=player.current_animation
	if clip_name.is_empty():clip_name=player.assigned_animation
	if clip_name.is_empty() or not player.has_animation(clip_name):return row
	var animation: Animation=player.get_animation(clip_name)
	var animation_root: Node=player.get_node_or_null(player.root_node)
	row["length"]=animation.length;row["time"]=player.current_animation_position if not player.current_animation.is_empty() else 0.0
	row["track_count"]=animation.get_track_count()
	var node_targets: Dictionary={};var bone_targets: Dictionary={}
	for track_index in animation.get_track_count():
		var path: NodePath=animation.track_get_path(track_index);var type:=animation.track_get_type(track_index)
		var subnames:=path.get_concatenated_subnames()
		var trs:=type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]
		var property_trs:=type in [Animation.TYPE_VALUE,Animation.TYPE_BEZIER] and (subnames.get_slice(":",0) in ["position","rotation","rotation_degrees","quaternion","scale","transform","global_position","global_transform","basis"] or subnames.begins_with("bones/"))
		if not trs and not property_trs:continue
		var record:={"index":track_index,"type":int(type),"path":str(path),"enabled":animation.track_is_enabled(track_index),"keys":animation.track_get_key_count(track_index),"subnames":subnames,"node_id":0,"node_class":"","bone":false,"subtree_visits":0,"mesh_node_ids":[]}
		var target: Node=null
		if animation_root!=null:target=animation_root if path.get_name_count()==0 else animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
		if target==null:row.unresolved_targets+=1;row.tracks.append(record);continue
		record.node_id=target.get_instance_id();record.node_class=target.get_class()
		if target is Node3D:
			record.bone=target is Skeleton3D and (not subnames.is_empty())
			if record.bone:
				bone_targets[target.get_instance_id()]=true;record.mesh_node_ids=skin_meshes.get(target.get_instance_id(),[])
			else:
				node_targets[target.get_instance_id()]=true
				var work:=Base.subtree_work(target,memo);record.subtree_visits=int(work.visits);record.mesh_node_ids=descendants(target)
		row.tracks.append(record)
	row.node_transform_targets=node_targets.keys();row.bone_targets=bone_targets.keys()
	return row
static func capture(root_node: Node)->Dictionary:
	var result:={"version":2,"kind":"native-render-gap-all-animation-topology","physics_interpolation":root_node.get_tree().is_physics_interpolation_enabled(),"native_models":[],"ordinary_players":[],"manual_poses":[],"attachments":[],"chunks":[],"chunk_owner_count":0,"chunk_resources":{},"rigs":[],"skeleton_mesh_bindings":{},"limitations":["Cold post-window topology and loaded active-clip inspection, not measured writes or per-frame CPU attribution.","Native owner supersedes a stopped/manual AnimationPlayer; both are identified without advancing either.","Transform track types coalesce within AnimationMixer. Node target/mesh joins are not asserted setter counts.","Skeleton bone tracks have zero Node3D subtree-walk estimate and list their actual bound skin meshes separately.","Opaque script/engine writers outside known rigs and AnimationPlayer remain unmeasured; wind field sampling itself does not write Node3D transforms."]}
	var pending: Array[Node]=[root_node];var rigs: Array[Node]=[];var players: Array[AnimationPlayer]=[];var chunk_owners: Array[Node]=[];var contexts: Dictionary={};var memo: Dictionary={};var skin_meshes: Dictionary={}
	while not pending.is_empty():
		var current: Node=pending.pop_back()
		for child: Node in current.get_children(true):pending.append(child)
		if current is AnimationPlayer:players.append(current)
		if current is MeshInstance3D and not current.skeleton.is_empty():
			var skeleton: Node=current.get_node_or_null(current.skeleton)
			if skeleton is Skeleton3D:
				if not skin_meshes.has(skeleton.get_instance_id()):skin_meshes[skeleton.get_instance_id()]=[]
				skin_meshes[skeleton.get_instance_id()].append(current.get_instance_id())
		var script: Script=current.get_script()
		if script!=null and script.resource_path in ["res://systems/model_rigs.gd","res://systems/native_render/skeletal_rigs.gd"]:rigs.append(current)
		if script!=null and script.resource_path=="res://systems/native_render/chunk_models.gd":chunk_owners.append(current)
	result.skeleton_mesh_bindings=skin_meshes
	for rig: Node in rigs:
		var script: Script=rig.get_script();var entities: Dictionary=rig.get("entities")
		result.rigs.append({"node_id":rig.get_instance_id(),"script":script.resource_path,"entities":entities.size()})
		for actor in entities:
			var entry: Dictionary=entities[actor]
			for model_index in entry.models.size():
				var model: Dictionary=entry.models[model_index]
				var context:={"rig_id":rig.get_instance_id(),"actor":int(actor),"model_index":model_index,"resource":str(model.get("asset_source",{}).get("name","")),"selected_clip":str(model.get("clip","")),"native_owner":model.has("native_owner"),"skeletal":entry.has("skeleton")}
				if model.get("player") is AnimationPlayer:contexts[model.player.get_instance_id()]=context
				if not model.has("native_owner"):continue
				var pose: RefCounted=model.native_owner.pose
				var native:=Base.model_work(entry,pose.binding.parts,memo) if not entry.nodes.is_empty() else {"parts":pose.binding.parts.size(),"note":"Native owner with skeleton-only nodes needs a separate direct bone-pose adapter; do not infer Node3D walks"}
				native.merge(context);native.native_publish_calls=int(pose.native_publish_calls);native.native_calls=int(pose.native_calls);native.native_storage=pose.native_context!=null;result.native_models.append(native)
			for index in entry.get("manual_poses",{}):
				var part:=int(index)
				if part>=0 and part<entry.nodes.size():result.manual_poses.append({"actor":int(actor),"rig_id":rig.get_instance_id(),"part":part,"node_id":entry.nodes[part].get_instance_id(),"subtree":Base.subtree_work(entry.nodes[part],memo),"mesh_node_ids":descendants(entry.nodes[part])})
			for attachment in entry.get("attachments",[]):
				var part:=int(attachment.node)
				if part>=0 and part<entry.nodes.size():result.attachments.append({"actor":int(actor),"rig_id":rig.get_instance_id(),"node_id":entry.nodes[part].get_instance_id(),"anchor":int(attachment.get("anchor",-1)),"external_anchor":attachment.has("external_anchor"),"flags":int(attachment.get("flags",0)),"subtree":Base.subtree_work(entry.nodes[part],memo),"mesh_node_ids":descendants(entry.nodes[part])})
	for player: AnimationPlayer in players:result.ordinary_players.append(player_snapshot(player,contexts.get(player.get_instance_id(),{}),memo,skin_meshes))
	for chunks: Node in chunk_owners:
		result.chunk_owner_count+=1
		var resource:=str(chunks.get("resource"))
		if not result.chunk_resources.has(resource):result.chunk_resources[resource]={"owners":0,"models":0,"visible_in_tree":0,"process_disabled":0}
		var counts: Dictionary=result.chunk_resources[resource];counts.owners+=1
		for model in chunks.get("models"):
			if not is_instance_valid(model) or not model is Node3D:continue
			counts.models+=1
			if model.is_visible_in_tree():counts.visible_in_tree+=1
			if model.process_mode==Node.PROCESS_MODE_DISABLED:counts.process_disabled+=1
			result.chunks.append({"owner_id":chunks.get_instance_id(),"emitter_id":chunks.get_parent().get_instance_id() if chunks.get_parent()!=null else 0,"resource":str(chunks.get("resource")),"model_id":model.get_instance_id(),"visible":model.visible,"visible_in_tree":model.is_visible_in_tree(),"process_mode":int(model.process_mode),"script":model.get_script().resource_path if model.get_script()!=null else "","local_notifications":model.is_local_transform_notification_enabled(),"transform_notifications":model.is_transform_notification_enabled(),"subtree":Base.subtree_work(model,memo),"mesh_node_ids":descendants(model)})
	return result
