extends "res://systems/native_render/native_support_part_trace.gd"
# Private successor: authored ordinary-TriMesh bounds and its actual zero
# output normal. Existing WOK/AABB material semantics and query grids remain.
const AuthoredBox=preload("res://systems/native_data/native_support_authored_box.gd")

func _init() -> void:
	for key in ["authored_box_queries","authored_box_misses","authored_box_unavailable","aabb_box_retained","tilefade_excluded"]:stats[key]=0

func model_hit(instance,start: Array,end: Array) -> Dictionary:
	stats.models+=1
	if instance.has_meta("native_scene_bounds"):
		var box: AABB=instance.global_transform*instance.get_meta("native_scene_bounds")
		if box.intersects_segment(Query.engine(start),Query.engine(end))==null:return {"available":true,"hit":false}
	Query.prepare_parts(instance)
	var best: Variant=null;var normal: Array=[];var limit: Array=end
	for part: Dictionary in instance.get_meta("native_scene_parts"):
		if not is_instance_valid(part.node) or part.node.is_queued_for_deletion():return unavailable("Support physical Part retired during query")
		var transform: Transform3D=part.node.global_transform;var inverse:=transform.affine_inverse()
		var a: Array=Query.native(inverse*Query.engine(start));var b: Array=Query.native(inverse*Query.engine(limit))
		var source: Variant=part.node.get_meta("native_mesh_source") if part.node.has_meta("native_mesh_source") else null
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
