extends "res://systems/native_render/native_support_part_trace.gd"
# Private successor: authored ordinary-TriMesh bounds and its actual zero
# output normal. Existing WOK/AABB material semantics and query grids remain.
const AuthoredBox=preload("res://systems/native_data/native_support_authored_box.gd")
var _world_part_box:=OS.get_cmdline_user_args().has("--client-support-world-part-box")

func _init() -> void:
	for key in ["authored_box_queries","authored_box_misses","authored_box_unavailable","aabb_box_retained","tilefade_excluded","inverse_builds","inverse_reuses","world_box_builds","world_box_reuses","world_box_misses","world_box_fallbacks"]:stats[key]=0

func _ordinary_world_box(part: Dictionary,source: Dictionary,pose: Transform3D) -> Variant:
	# This is a conservative rejection only. Unsupported provenance, zero-size
	# authored boxes and degenerate poses still take the exact local admission.
	if not source.get("node_is_aabb") is bool or source.node_is_aabb or source.get("native_tilefade_available")!=true or not source.get("native_tilefade") is int or int(source.native_tilefade) in [2,4] or source.get("native_bounds_available")!=true or source.get("native_bounds_valid")!=true:
		return null
	var bounds: Variant=source.get("native_bounds")
	if not bounds is Dictionary or not pose.is_finite() or is_zero_approx(pose.basis.determinant()):return null
	var raw_low: Variant=bounds.get("min");var raw_high: Variant=bounds.get("max")
	# The original gate can only be used to reject a Part if it encloses its
	# triangles. Include the published geometry bound too: a bad but finite
	# authored box may still admit a ray that hits geometry outside that box.
	var geometry: Variant=part.get("data")
	if not geometry is Resource or not geometry.get("bounds") is AABB or not geometry.get("vertices") is PackedFloat32Array or not geometry.get("indices") is PackedInt32Array or not geometry.get("planes") is PackedFloat32Array:return null
	var vertices: PackedFloat32Array=geometry.vertices;var indices: PackedInt32Array=geometry.indices;var planes: PackedFloat32Array=geometry.planes
	if vertices.size()<9 or vertices.size()%3!=0 or indices.size()<3 or indices.size()%3!=0 or planes.size()!=indices.size()/3*4:return null
	var geo: AABB=geometry.bounds
	if not geo.position.is_finite() or not geo.end.is_finite() or geo.size.x<0 or geo.size.y<0 or geo.size.z<0:return null
	# Compare the three-value authored arrays with saved copies before converting
	# them again. Copies detect in-place edits as well as source replacement;
	# the provenance and geometry validity checks above still run every query.
	if part.get("support_world_box_pose")==pose and part.get("support_world_box_raw_low")==raw_low and part.get("support_world_box_raw_high")==raw_high and part.get("support_world_box_geo")==geo and part.get("support_world_box") is AABB:
		stats.world_box_reuses+=1
		return part.support_world_box
	var low: Variant=AuthoredBox.vector(raw_low);var high: Variant=AuthoredBox.vector(raw_high)
	if not low is Vector3 or not high is Vector3 or high.x<=low.x or high.y<=low.y or high.z<=low.z:return null
	# Authored bounds are NWN XYZ; the actual Part pose is in Godot X,Z,-Y.
	var local:=AABB(Vector3(low.x,low.z,-high.y),Vector3(high.x-low.x,high.z-low.z,high.y-low.y))
	var geometry_local:=AABB(Vector3(geo.position.x,geo.position.z,-geo.end.y),Vector3(geo.size.x,geo.size.z,geo.size.y))
	var world_box: AABB=(pose*local).merge(pose*geometry_local)
	if not world_box.position.is_finite() or not world_box.end.is_finite():return null
	world_box=world_box.grow(maxf(1.0,maxf(world_box.position.abs().length(),world_box.end.abs().length()))*0.0000152587890625)
	part.support_world_box_pose=pose;part.support_world_box_raw_low=raw_low.duplicate();part.support_world_box_raw_high=raw_high.duplicate();part.support_world_box_geo=geo;part.support_world_box=world_box
	stats.world_box_builds+=1
	return world_box

func model_hit(instance,start: Array,end: Array) -> Dictionary:
	stats.models+=1
	var world_start: Vector3=Query.engine(start)
	var world_limit: Vector3=Query.engine(end)
	if instance.has_meta("native_scene_bounds"):
		var box: AABB=instance.global_transform*instance.get_meta("native_scene_bounds")
		if box.intersects_segment(world_start,world_limit)==null:return {"available":true,"hit":false}
	Query.prepare_parts(instance)
	var best: Variant=null;var normal: Array=[];var limit: Array=end
	for part: Dictionary in instance.get_meta("native_scene_parts"):
		if not is_instance_valid(part.node) or part.node.is_queued_for_deletion():return unavailable("Support physical Part retired during query")
		var transform: Transform3D=part.node.global_transform
		var source: Variant=null
		if _world_part_box and world_start.is_finite() and world_limit.is_finite():
			source=part.node.get_meta("native_mesh_source") if part.node.has_meta("native_mesh_source") else null
			if source is Dictionary:
				var world_box: Variant=_ordinary_world_box(part,source,transform)
				if world_box is AABB:
					if not world_box.has_point(world_start) and not world_box.has_point(world_limit) and world_box.intersects_segment(world_start,world_limit)==null:
						stats.world_box_misses+=1;continue
				else:stats.world_box_fallbacks+=1
			else:stats.world_box_fallbacks+=1
		# Published Parts normally keep the same pose across thousands of
		# support rays. Rebuild only when this Part's actual global pose changes;
		# the cached inverse never substitutes for the current transform.
		if not part.has("support_cached_pose") or part.support_cached_pose!=transform:
			part.support_cached_pose=transform
			part.support_cached_inverse=transform.affine_inverse()
			stats.inverse_builds+=1
		else:stats.inverse_reuses+=1
		var inverse: Transform3D=part.support_cached_inverse
		var a: Array=Query.native(inverse*world_start);var b: Array=Query.native(inverse*world_limit)
		if source==null:source=part.node.get_meta("native_mesh_source") if part.node.has_meta("native_mesh_source") else null
		if not source is Dictionary:return unavailable("Support Part provenance not published")
		stats.parts+=1
		var admission: Dictionary=AuthoredBox.admit(source,a,b)
		if not admission.available:
			stats.authored_box_unavailable+=1;return unavailable(str(admission.reason))
		if admission.route=="static-tilefade-excluded":
			stats.tilefade_excluded+=1;continue
		if admission.route=="aabb-existing":stats.aabb_box_retained+=1
		else:stats.authored_box_queries+=1
		if not admission.admit:
			stats.authored_box_misses+=1;continue
		var hit: Dictionary=Triangle.nearest(part.data,a,b,source)
		stats.triangle_tests+=int(hit.get("triangle_tests",0))
		if not hit.available:return unavailable(str(hit.reason))
		match str(hit.route):
			"compiled-raw":stats.compiled_queries+=1
			"gd-unmasked-trimesh":stats.gd_unmasked_queries+=1
			"gd-aabb-mask":stats.gd_aabb_queries+=1
		if hit.hit:
			best=M.values(Query.native(transform*Query.engine(hit.position)));limit=best
			world_limit=Query.engine(limit)
			# Original905b0 clears CHitInfo normal to zero for polygon hits;
			# Part::HitCheck08fd80 rotates it without replacing/normalizing it.
			# Do not substitute the polygon plane's normal for this branch.
			normal=[0.0,0.0,0.0] if source.node_is_aabb==false else M.values(Query.native((inverse.basis.transposed()*Query.engine(hit.normal)).normalized()))
	return {"available":true,"hit":best!=null,"position":best,"normal":normal}

func trace(world,start: Array,end: Array) -> Dictionary:
	# Native support mode1 visits the instantiated scene's static Part buckets.
	# Standalone .wok/navigation height is a different owner; querying it here
	# would add an unproved duplicate floor and change native scene tie order.
	stats.rays+=1
	var best: Variant=null;var normal: Array=[];var limit: Array=M.values(end)
	var terrain=world.get("terrain")
	if is_instance_valid(terrain):
		if is_instance_valid(terrain.batcher) and not terrain.batcher.owners.is_empty():return unavailable("Support Part policy for batched terrain unavailable")
		if not terrain.has_method("collision_candidates"):return unavailable("Published terrain query index unavailable")
		for instance in terrain.collision_candidates(Query.engine(start),Query.engine(limit)):
			var hit:=model_hit(instance,start,limit)
			if not hit.available:return hit
			if hit.hit:best=hit.position;limit=best;normal=hit.normal
	var statics=world.get("static_collision_index")
	if statics==null:return unavailable("Published static query index unavailable")
	for instance in statics.query(Query.engine(start),Query.engine(limit)):
		var hit:=model_hit(instance,start,limit)
		if not hit.available:return hit
		if hit.hit:best=hit.position;limit=best;normal=hit.normal
	return {"available":true,"hit":best!=null,"position":best,"normal":normal}
