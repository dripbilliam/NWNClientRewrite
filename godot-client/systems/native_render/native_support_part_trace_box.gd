extends "res://systems/native_render/native_support_part_trace.gd"
# Private successor: authored ordinary-TriMesh bounds and its actual zero
# output normal. Existing WOK/AABB material semantics and query grids remain.
const AuthoredBox=preload("res://systems/native_data/native_support_authored_box.gd")
const CandidateGrid=preload("res://systems/native_render/native_support_part_candidates.gd")
const KernelPolicy=preload("res://systems/native_render/particle_kernel.gd")
var _world_part_box:=OS.get_cmdline_user_args().has("--client-support-world-part-box")
var _retain_part_candidates:=not OS.get_cmdline_user_args().has("--client-support-part-candidates=exact")
var _use_native_fixed_support:=not OS.get_cmdline_user_args().has("--scene-geometry=gd") and KernelPolicy.enabled()
var _last_candidate_build_frame:=-1

func _init() -> void:
	for key in ["authored_box_queries","authored_box_misses","authored_box_unavailable","aabb_box_retained","tilefade_excluded","inverse_builds","inverse_reuses","world_box_builds","world_box_reuses","world_box_misses","world_box_fallbacks","retained_grid_builds","retained_grid_build_us","retained_grid_build_max_us","retained_grid_queries","retained_grid_parts_avoided","retained_grid_segment_changes","retained_grid_box_misses"]:stats[key]=0
	stats.native_fixed_tile_queries=0
	stats.native_fixed_tile_fallbacks=0

func _candidate_grid(instance: Node3D, parts: Array, pose: Transform3D) -> CandidateGrid:
	if not instance.get_meta("native_support_fixed_parts",false):
		return null
	var grid: CandidateGrid
	if instance.has_meta("native_support_part_candidates"):
		grid=instance.get_meta("native_support_part_candidates") as CandidateGrid
	if grid==null:
		# Spread cold work over frames and build only for tiles that actually
		# receive support queries. The next ray can still use the full list.
		var frame:=Engine.get_process_frames()
		if frame==_last_candidate_build_frame:
			return null
		_last_candidate_build_frame=frame
		var began:=Time.get_ticks_usec()
		grid=CandidateGrid.new()
		var compile_batch:=_use_native_fixed_support and ClassDB.class_exists("NwnFixedTerrainSupport")
		grid.prepare(parts,pose,_ordinary_world_box,compile_batch)
		instance.set_meta("native_support_part_candidates",grid)
		var elapsed:=Time.get_ticks_usec()-began
		stats.retained_grid_builds+=1
		stats.retained_grid_build_us+=elapsed
		stats.retained_grid_build_max_us=maxi(stats.retained_grid_build_max_us,elapsed)
	if not grid.valid or grid.pose!=pose or grid.part_count!=parts.size() or not is_same(grid.parts,parts):
		return null
	return grid

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
	var root_pose:=Transform3D.IDENTITY
	if instance.has_meta("native_scene_bounds"):
		root_pose=instance.global_transform
		var box: AABB=root_pose*instance.get_meta("native_scene_bounds")
		if box.intersects_segment(world_start,world_limit)==null:return {"available":true,"hit":false}
	Query.prepare_parts(instance)
	var parts: Array=instance.get_meta("native_scene_parts")
	if _retain_part_candidates and not _world_part_box and world_start.x==world_limit.x and world_start.z==world_limit.z and CandidateGrid.supported_point(world_start) and world_limit.is_finite():
		var grid:=_candidate_grid(instance,parts,root_pose)
		if grid!=null:
			var column:=CandidateGrid.cell(world_start)
			var selected: Array=grid.columns.get(column,grid.fallback)
			stats.retained_grid_queries+=1
			if _use_native_fixed_support and grid.native_batch!=null:
				var mask: int=grid.native_masks.get(column,grid.native_fallback_mask)
				var batch_result: Variant=grid.native_batch.call("dispatch",1,{"start":start,"end":end,"mask":mask})
				if batch_result is Dictionary and batch_result.has("hit"):
					stats.native_fixed_tile_queries+=1
					stats.parts+=int(batch_result.tested)
					stats.compiled_queries+=int(batch_result.triangle_calls)
					stats.retained_grid_box_misses+=int(batch_result.rejected)
					stats.retained_grid_parts_avoided+=parts.size()-int(batch_result.visits)
					stats.retained_grid_segment_changes+=int(batch_result.column_changed)
					return {"available":true,"hit":batch_result.hit,"position":batch_result.get("position"),"normal":batch_result.get("normal",[])}
				stats.native_fixed_tile_fallbacks+=1
				return _parts_hit(parts,world_start,world_limit)
			var result:=_parts_hit(selected,world_start,world_limit,column,grid)
			if not result.has("resume_after"):
				stats.retained_grid_parts_avoided+=parts.size()-selected.size()
				return result
			# Keep the earlier hit and check the original remaining order if
			# rounding moved its shortened endpoint out of the selected cell.
			var after: Dictionary=result.resume_after
			result.erase("resume_after")
			var index:=parts.find(after)
			stats.retained_grid_parts_avoided+=index-selected.find(after)
			stats.retained_grid_segment_changes+=1
			var remainder:=_parts_hit(parts.slice(index+1),world_start,Query.engine(result.position))
			return remainder if not remainder.available or remainder.hit else result
	return _parts_hit(parts,world_start,world_limit)

func _parts_hit(parts: Array,world_start: Vector3,world_limit: Vector3,column: Variant=null,grid: CandidateGrid=null) -> Dictionary:
	var best: Variant=null;var normal: Array=[]
	var ray_min:=world_start.min(world_limit)
	var ray_max:=world_start.max(world_limit)
	for part: Dictionary in parts:
		if not is_instance_valid(part.node) or part.node.is_queued_for_deletion():return unavailable("Support physical Part retired during query")
		if grid!=null:
			var bounds: Variant=grid.world_boxes.get(part.node)
			if bounds is AABB:
				# The column admits the whole cell. Use the retained, expanded
				# Part bound to reject a strictly disjoint current segment.
				var low: Vector3=bounds.position
				var high: Vector3=bounds.end
				if ray_max.x<low.x or ray_max.y<low.y or ray_max.z<low.z or ray_min.x>high.x or ray_min.y>high.y or ray_min.z>high.z:
					stats.retained_grid_box_misses+=1
					continue
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
			best=M.values(Query.native(transform*Query.engine(hit.position)))
			world_limit=Query.engine(best)
			# Original905b0 clears CHitInfo normal to zero for polygon hits;
			# Part::HitCheck08fd80 rotates it without replacing/normalizing it.
			# Do not substitute the polygon plane's normal for this branch.
			normal=[0.0,0.0,0.0] if source.node_is_aabb==false else M.values(Query.native((inverse.basis.transposed()*Query.engine(hit.normal)).normalized()))
			if column!=null and (not CandidateGrid.supported_point(world_limit) or CandidateGrid.cell(world_limit)!=column):
				return {"available":true,"hit":true,"position":best,"normal":normal,"resume_after":part}
			if grid!=null:
				ray_min=world_start.min(world_limit)
				ray_max=world_start.max(world_limit)
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
