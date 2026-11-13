extends RefCounted
# One-shot, read-only world subtree census. Never call this inside a timed FPS
# window: the full Node walk and JSON serialization intentionally cost work.
const MAX_NODES:=100000

static func capture(world: Node3D,phase: String) -> Dictionary:
	var began:=Time.get_ticks_usec()
	var pending: Array[Node]=[world]
	var owners: Array[String]=["world"]
	var classes: Dictionary={};var branches: Dictionary={}
	var unique_meshes: Dictionary={}
	var nodes:=0;var visible_3d:=0;var hidden_3d:=0;var parts:=0;var emitters:=0;var meshes:=0;var mesh_without_resource:=0
	while not pending.is_empty() and nodes<MAX_NODES:
		var node: Node=pending.pop_back();var owner: String=owners.pop_back()
		nodes+=1
		var kind: String=node.get_class()
		classes[kind]=int(classes.get(kind,0))+1
		branches[owner]=int(branches.get(owner,0))+1
		if node is Node3D:
			if node.visible:visible_3d+=1
			else:hidden_3d+=1
		if str(node.name).begins_with("part_"):parts+=1
		if str(node.name)=="native_emitter":emitters+=1
		if node is MeshInstance3D:
			meshes+=1
			if node.mesh==null:mesh_without_resource+=1
			else:unique_meshes[node.mesh.get_instance_id()]=true
		for index in node.get_child_count():
			var child: Node=node.get_child(index)
			pending.append(child)
			if node==world:
				var script: Variant=child.get_script()
				owners.append(str(script.resource_path) if script is Script else str(child.name))
			else:owners.append(owner)
	var motion: Variant=world.get("motion")
	var drive: Variant=world.get("drive_collision")
	var terrain: Variant=world.get("terrain")
	var query: Variant=world.get("static_collision_index")
	var drive_static:=0
	if is_instance_valid(drive):
		for group in drive.static_groups.values():drive_static+=int(group.index.snapshot().entries)
	var settled:=0;var active:=0
	if is_instance_valid(motion):
		for row in motion.objects.values():
			if row.get("active",false):active+=1
			elif row.get("facingTurn")==null and int(row.get("correction",0))==0:settled+=1
	return {"phase":phase,"generation":int(world.get("generation")),"area_id":int(world.get("area_id")),"world_instance_id":world.get_instance_id(),"world_script":str(world.get_script().resource_path),"desired":world.desired.size(),"installed":world.installed.size(),"instances":world.instances.size(),"batches":world.batches.size(),"motion_rows":motion.objects.size() if is_instance_valid(motion) else 0,"motion_active":active,"motion_settled_no_correction":settled,"controlled_active":bool(motion.objects.get(world.controlled_id,{}).get("active",false)) if is_instance_valid(motion) else false,"subtree_nodes":nodes,"truncated":not pending.is_empty(),"global_nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"global_resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"mesh_instances":meshes,"unique_mesh_resources":unique_meshes.size(),"mesh_instances_without_resource":mesh_without_resource,"authored_parts":parts,"named_emitters":emitters,"visible_3d":visible_3d,"hidden_3d":hidden_3d,"classes":classes,"branches":branches,"query_memberships":{"scene_static_roots":query.entries.size() if query!=null else 0,"drive_static_entries":drive_static,"drive_static_groups":drive.static_groups.size() if is_instance_valid(drive) else 0,"terrain_tiles":terrain.instances.size() if is_instance_valid(terrain) else 0,"terrain_query_roots":terrain.collision_index.entries.size() if is_instance_valid(terrain) else 0},"census_ms":(Time.get_ticks_usec()-began)/1000.0,"scope":"One-shot main-thread Node and query-membership census; unlike query roles are separate counts, not duplicate-node claims."}
