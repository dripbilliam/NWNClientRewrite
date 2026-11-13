extends RefCounted
# Existing-grid, support-only material-policy correction. Membership remains the
# published WOK/terrain/staticState adaptation until native BSP registration is
# recovered. This is not a new entity store or scene index.
const Query=preload("res://systems/native_render/projectile_scene.gd")
const Surface=preload("res://systems/native_data/tile_surface.gd")
const M=preload("res://systems/native_render/particle_math.gd")
const Triangle=preload("res://systems/native_data/native_support_triangle.gd")
var stats:={"rays":0,"models":0,"parts":0,"triangle_tests":0,"compiled_queries":0,"gd_unmasked_queries":0,"gd_aabb_queries":0,"unavailable":0}

func unavailable(reason: String) -> Dictionary:
	stats.unavailable+=1
	return {"available":false,"reason":reason}

func model_hit(instance,start: Array,end: Array) -> Dictionary:
	stats.models+=1
	if instance.has_meta("native_scene_bounds"):
		var box: AABB=instance.global_transform*instance.get_meta("native_scene_bounds")
		if box.intersects_segment(Query.engine(start),Query.engine(end))==null:return {"available":true,"hit":false}
	Query.prepare_parts(instance)
	var best: Variant=null;var normal: Array=[];var limit: Array=end
	for part: Dictionary in instance.get_meta("native_scene_parts"):
		if not is_instance_valid(part.node) or part.node.is_queued_for_deletion():return unavailable("Support physical Part retired during query")
		var transform: Transform3D=part.node.global_transform; var inverse:=transform.affine_inverse()
		var a: Array=Query.native(inverse*Query.engine(start));var b: Array=Query.native(inverse*Query.engine(limit))
		var source: Variant=part.node.get_meta("native_mesh_source") if part.node.has_meta("native_mesh_source") else null
		if not source is Dictionary:return unavailable("Support Part provenance not published")
		stats.parts+=1
		var hit: Dictionary=Triangle.nearest(part.data,a,b,source)
		stats.triangle_tests+=int(hit.get("triangle_tests",0))
		if not hit.available:return unavailable(str(hit.reason))
		match str(hit.route):
			"compiled-raw":stats.compiled_queries+=1
			"gd-unmasked-trimesh":stats.gd_unmasked_queries+=1
			"gd-aabb-mask":stats.gd_aabb_queries+=1
		if hit.hit:
			best=M.values(Query.native(transform*Query.engine(hit.position)));limit=best
			normal=M.values(Query.native((inverse.basis.transposed()*Query.engine(hit.normal)).normalized()))
	return {"available":true,"hit":best!=null,"position":best,"normal":normal}

func trace(world,start: Array,end: Array) -> Dictionary:
	stats.rays+=1
	var best: Variant=null;var normal: Array=[];var limit: Array=M.values(end)
	var terrain=world.get("terrain");var surface=world.get("surface")
	if is_instance_valid(surface) and surface.ready() and start[0]==end[0] and start[1]==end[1]:
		for index in surface.vertical_candidates(start):
			var tile: Dictionary=surface.definition.tiles[index];var origin: Vector2=surface.tile_origin(index)
			var xy:=Surface.canonical([M.f(start[0]-origin.x),M.f(start[1]-origin.y)],int(tile.orientation))
			var a: Array=[xy[0],xy[1],M.f(start[2]-tile.position.y)];var b: Array=[xy[0],xy[1],M.f(limit[2]-tile.position.y)]
			var geometry=surface.collision_geometry(str(tile.model))
			var hit: Dictionary=Triangle.nearest(geometry,a,b,{"node_is_aabb":true})
			stats.triangle_tests+=int(hit.get("triangle_tests",0))
			if not hit.available:return unavailable(str(hit.reason))
			if hit.hit:
				best=[start[0],start[1],M.f(hit.position[2]+tile.position.y)];limit=best;normal=Query.tile_normal(hit.normal,int(tile.orientation))
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

func snapshot() -> Dictionary:
	return stats.duplicate()
