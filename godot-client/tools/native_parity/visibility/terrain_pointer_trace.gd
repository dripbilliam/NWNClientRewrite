extends RefCounted
# One explicit cold ray over the already-published terrain index. This is not
# an input handler, picking policy, visibility rule or another world store.
const Trace=preload("res://tools/native_parity/visibility/entity_visibility_trace.gd")
const Provenance=preload("res://tools/native_parity/visibility/mesh_provenance.gd")
const HARD_ENTRIES:=4096
const HARD_CANDIDATES:=64
const HARD_PARTS:=512
static func native(value: Vector3) -> Array: return [value.x,-value.z,value.y]
static func engine(value: Array) -> Vector3: return Vector3(value[0],value[2],-value[1])
static func capture(world: Node,camera: Camera3D,request: Dictionary) -> Dictionary:
	var result:={"version":1,"status":"unavailable","read_only":true,"kind":"single_cold_published_terrain_ray","errors":[],"truncated":false,"candidate_count":0,"part_count":0,"hit":null}
	if OS.get_thread_caller_id()!=OS.get_main_thread_id(): result.errors.append("main_thread_required");return result
	if request.get("post_window")!=true or request.get("measurement_active")!=false:result.errors.append("explicit_post_window_required");return result
	if not is_instance_valid(world) or not world.is_inside_tree() or Trace.property(world,"closed",true)!=false or Trace.property(world,"retiring",true)!=false:result.errors.append("active_world_required");return result
	var generation: Variant=Trace.property(world,"generation");var area: Variant=Trace.property(world,"area_id")
	if request.get("expected_world_instance_id")!=world.get_instance_id() or request.get("expected_generation")!=generation or request.get("expected_area_id")!=area:result.errors.append("scope_mismatch");return result
	var a:=Trace.point(request.get("start"),"godot_world");var b:=Trace.point(request.get("end"),"godot_world")
	if not a.available or not b.available:result.errors.append("finite_explicit_world_ray_required");return result
	var start:=Vector3(a.value[0],a.value[1],a.value[2]);var end:=Vector3(b.value[0],b.value[1],b.value[2])
	if start==end or start.distance_squared_to(end)>40000.0:result.errors.append("ray_length_must_be_positive_at_most_200");return result
	var maximum:=clampi(int(request.get("max_candidates",32)),1,HARD_CANDIDATES);var part_maximum:=clampi(int(request.get("max_parts",128)),1,HARD_PARTS)
	var terrain: Variant=Trace.property(world,"terrain")
	var indexes: Array=[Trace.property(terrain,"collision_index") if terrain is Object else null,Trace.property(world,"static_collision_index")]
	var candidates: Array=[];var seen: Dictionary={};var entry_count:=0
	# An explicit bounded diagnostic may inspect retained entries. Do not call
	# query/prepare_parts: even their lazy caches and counters stay untouched.
	for index in indexes:
		var entries: Variant=Trace.property(index,"entries") if index is Object else null
		if not entries is Dictionary:continue
		entry_count+=entries.size()
		if entry_count>HARD_ENTRIES:result.errors.append("published_index_bound_exceeded");return result
		for entry in entries.values():
			if not entry is Dictionary or not entry.get("node") is WeakRef:continue
			if entry.get("bounds") is AABB and entry.bounds.intersects_segment(start,end)==null:continue
			var owner: Variant=entry.node.get_ref()
			if not owner is Node3D or not is_instance_valid(owner) or seen.has(owner.get_instance_id()):continue
			seen[owner.get_instance_id()]=true;candidates.append(owner)
	if entry_count==0:result.errors.append("published_scene_indexes_empty");return result
	result.candidate_count=candidates.size();result.truncated=candidates.size()>maximum;result.ray={"start":a,"end":b};result.scope={"world_id":str(world.get_instance_id()),"generation":generation,"area_id":area}
	var limit:=end;var best_distance:=INF
	for candidate_index in mini(candidates.size(),maximum):
		var owner: Variant=candidates[candidate_index]
		if not owner is Node3D or not is_instance_valid(owner) or not owner.is_inside_tree():continue
		# Never call prepare_parts: that would mutate owner metadata/lazy caches.
		if not owner.has_meta("native_scene_parts"):result.errors.append("published_part_index_unavailable");continue
		var parts: Variant=owner.get_meta("native_scene_parts")
		if not parts is Array:result.errors.append("published_part_index_invalid");continue
		for part in parts:
			if result.part_count>=part_maximum:result.truncated=true;break
			result.part_count+=1
			if not part is Dictionary:continue
			var node: Variant=part.get("node");var data: Variant=part.get("data")
			if not node is Node3D or not is_instance_valid(node) or not node.is_inside_tree() or not data is Object or not is_instance_valid(data) or not data.has_method("nearest"):continue
			var transform: Transform3D=node.global_transform
			if not transform.is_finite() or transform.basis.determinant()==0.0:result.errors.append("part_transform_unsupported");continue
			var inverse:=transform.affine_inverse()
			# Ordinary CPU predicate only. Compiled/native owner publication is not
			# initialized by this cold helper. Existing material30 policy is retained.
			var hit: Variant=data.call("nearest",native(inverse*start),native(inverse*limit),true,false)
			if not hit is Dictionary or not hit.get("position") is Array:continue
			var point:=Trace.point(hit.position,"nwn_model_z_up")
			if not point.available:continue
			var world_point:=transform*engine(point.value);var distance:=start.distance_squared_to(world_point)
			if not world_point.is_finite() or distance>=best_distance:continue
			best_distance=distance;limit=world_point
			var facts: Variant=node.get_meta("native_mesh_source") if node.has_meta("native_mesh_source") else null
			var tile_index: Variant=owner.get_meta("native_tile_index") if owner.has_meta("native_tile_index") else null
			result.hit={"owner_instance_id":str(owner.get_instance_id()),"object_id":owner.get_meta("world_object_id") if owner.has_meta("world_object_id") else null,"part_instance_id":str(node.get_instance_id()),"tile_index":tile_index if tile_index is int else null,"world_position":Trace.point(world_point,"godot_world"),"source":Provenance.detached(facts) if facts is Dictionary else null,"source_available":facts is Dictionary,"mesh":Trace.mesh_view(node,owner,camera) if node is MeshInstance3D else null,"policy":"published CPU geometry, not native pointer priority or GPU visibility"}
	if not is_instance_valid(world) or generation!=Trace.property(world,"generation") or area!=Trace.property(world,"area_id"):result.hit=null;result.errors.append("scope_changed_during_observation");return result
	result.status="truncated" if result.truncated else "complete" if result.errors.is_empty() else "partial"
	return result
