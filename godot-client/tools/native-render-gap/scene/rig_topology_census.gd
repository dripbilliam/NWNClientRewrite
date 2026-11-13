extends RefCounted
# One cold traversal after the timing window. Never reads global transforms,
# materializes native Part snapshots, changes a Node or advances a controller.
static func subtree_work(node: Node3D,memo: Dictionary)->Dictionary:
	var id:=node.get_instance_id()
	if memo.has(id):return memo[id]
	var work:={"visits":1,"meshes":1 if node is MeshInstance3D else 0,"lights":1 if node is Light3D else 0,"depth":1}
	for child: Node in node.get_children(true):
		if not child is Node3D or child.is_set_as_top_level():continue
		var below:=subtree_work(child,memo)
		work.visits+=int(below.visits);work.meshes+=int(below.meshes);work.lights+=int(below.lights);work.depth=maxi(int(work.depth),1+int(below.depth))
	memo[id]=work
	return work
static func model_work(entry: Dictionary,parts: Array,memo: Dictionary)->Dictionary:
	var result:={"parts":parts.size(),"manual_skips":0,"setters_per_publication":0,"propagation_visits_per_publication":0,"mesh_visits_per_publication":0,"light_visits_per_publication":0,"maximum_subtree_depth":0,"scripted_parts":0,"local_notifications":0,"transform_notifications":0,"nonplain_parts":0,"part_node_ids":[],"mesh_node_ids":[]}
	var meshes: Dictionary={}
	for source in parts:
		var index:=int(source)
		if entry.manual_poses.has(index):result.manual_skips+=1;continue
		if index<0 or index>=entry.nodes.size():result["error"]="Invalid source binding";continue
		var node: Node3D=entry.nodes[index]
		if not is_instance_valid(node):result["error"]="Retired source binding";continue
		result.part_node_ids.append(node.get_instance_id())
		var work:=subtree_work(node,memo)
		result.setters_per_publication+=3;result.propagation_visits_per_publication+=3*int(work.visits)
		result.mesh_visits_per_publication+=3*int(work.meshes);result.light_visits_per_publication+=3*int(work.lights)
		result.maximum_subtree_depth=maxi(int(result.maximum_subtree_depth),int(work.depth))
		if node.get_script()!=null:result.scripted_parts+=1
		if node.is_local_transform_notification_enabled():result.local_notifications+=1
		if node.is_transform_notification_enabled():result.transform_notifications+=1
		if node.get_class()!=&"Node3D":result.nonplain_parts+=1
		var stack: Array[Node3D]=[node]
		while not stack.is_empty():
			var member: Node3D=stack.pop_back()
			if member is MeshInstance3D:meshes[member.get_instance_id()]=true
			for child: Node in member.get_children(true):
				if child is Node3D and not child.is_set_as_top_level():stack.append(child)
	result.mesh_node_ids=meshes.keys()
	return result
static func capture(root_node: Node)->Dictionary:
	var result:={"version":1,"kind":"native-render-gap-rig-topology","rigs":0,"native_models":0,"parts":0,"setters_per_publication_sum":0,"propagation_visits_per_publication_sum":0,"rows":[],"physics_interpolation":root_node.get_tree().is_physics_interpolation_enabled(),"limitations":["Cold current topology/ownership census; visit totals describe one publication per listed native owner, not measured calls per frame.","A controller may publish zero/multiple times. Cumulative owner publication counters are included without advancing them.","Node3D descendant visitation mirrors the current engine non-top-level traversal; scene queue insertion may still coalesce later."]}
	var memo: Dictionary={};var pending: Array[Node]=[root_node]
	while not pending.is_empty():
		var owner: Node=pending.pop_back()
		for child: Node in owner.get_children(true):pending.append(child)
		var script: Script=owner.get_script()
		if script==null or script.resource_path!="res://systems/model_rigs.gd":continue
		result.rigs+=1
		var entities: Dictionary=owner.get("entities")
		for actor in entities:
			var entry: Dictionary=entities[actor]
			for model_index in entry.models.size():
				var model: Dictionary=entry.models[model_index]
				if not model.has("native_owner"):continue
				var pose: RefCounted=model.native_owner.pose
				var row:=model_work(entry,pose.binding.parts,memo)
				row.actor=int(actor);row.model_index=model_index;row.resource=str(model.get("asset_source",{}).get("name",""));row.clip=str(model.get("clip",""));row.native_publish_calls=int(pose.native_publish_calls);row.native_calls=int(pose.native_calls);row.native_storage=pose.native_context!=null
				result.native_models+=1;result.parts+=int(row.parts);result.setters_per_publication_sum+=int(row.setters_per_publication);result.propagation_visits_per_publication_sum+=int(row.propagation_visits_per_publication)
				result.rows.append(row)
	result.rows.sort_custom(func(a,b):return int(a.propagation_visits_per_publication)>int(b.propagation_visits_per_publication))
	return result
