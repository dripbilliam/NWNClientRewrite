extends RefCounted
# Original Scene::HitCheck mode1/maskFFFFFFFFBFFFFFFF excludes dynamic Gobs.
# Static scene membership/transforms remain an adapter, not the native BSP.
const M=preload("res://systems/native_render/particle_math.gd")
const Surface=preload("res://systems/native_data/tile_surface.gd")
const Polygon=preload("res://systems/native_data/polygon_hit.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
static func native(point: Vector3) -> Array: return [point.x,-point.z,point.y]
static func engine(point: Array) -> Vector3: return Vector3(point[0],point[2],-point[1])
static func tile_normal(n: Array,orientation: int) -> Array:
	match orientation:
		1: return [M.f(-n[1]),n[0],n[2]]
		2: return [M.f(-n[0]),M.f(-n[1]),n[2]]
		3: return [n[1],M.f(-n[0]),n[2]]
	return n.duplicate()
static func mesh_hit(_mesh,geometry,transform: Transform3D,start: Array,end: Array,details: bool=false) -> Variant:
	if geometry==null: return null
	var inverse:=transform.affine_inverse(); var result: Variant=geometry.nearest(native(inverse*engine(start)),native(inverse*engine(end)),details)
	if result==null: return null
	if details: return {"position":M.values(native(transform*engine(result.position))),"normal":M.values(native((inverse.basis.transposed()*engine(result.normal)).normalized()))}
	return native(transform*engine(result))
static func prepare_parts(instance) -> void:
	# A published model has a fixed physical mesh list. Resolve its immutable
	# geometry once, but check actual Part transforms on every query (including
	# same-frame pose changes). Distant Parts need no local-ray arrays or inverses.
	if not instance.has_meta("native_scene_parts"):
		var nodes: Array=instance.meshes.duplicate(); var parts: Array=[]
		if instance.get("pick_surfaces") is Array: nodes.append_array(instance.pick_surfaces)
		for node in nodes:
			var data=null
			if node is MeshInstance3D: data=node.mesh.get_meta("native_scene_geometry",null)
			elif node.has_meta("native_pick_geometry"): data=node.get_meta("native_pick_geometry").get_meta("native_scene_geometry",null)
			if data!=null: parts.append({"node":node,"data":data})
		instance.set_meta("native_scene_parts",parts)
static func prepare_model(instance) -> RefCounted:
	prepare_parts(instance)
	if not instance.has_meta("native_scene_model_attempted"):
		instance.set_meta("native_scene_model_attempted",true)
		var records: Array=[]; var ready:=true
		for part in instance.get_meta("native_scene_parts"):
			var geometry: RefCounted=part.data.prepare_native()
			if geometry==null: ready=false; break
			var box: AABB=part.data.bounds
			records.append({"node":part.node.get_instance_id(),"geometry":geometry.call("dispatch",2,{}),"low":[box.position.x,box.position.y,box.position.z],"high":[box.end.x,box.end.y,box.end.z]})
		if ready and not records.is_empty():
			var owner: RefCounted=ClassDB.instantiate("NwnSceneModel"); var setup: Variant=owner.call("dispatch",0,{"parts":records})
			if setup is Dictionary and setup.has("error"): push_error(str(setup.error))
			else: instance.set_meta("native_scene_model",owner)
	# Geometry-free models are valid scene members. Godot treats a null default
	# as no default and logs an error for an absent key; keep the existing null
	# fallback without issuing that error on every scene-index update.
	return instance.get_meta("native_scene_model") if instance.has_meta("native_scene_model") else null
static func model_hit(instance,start: Array,end: Array,details: bool=false,compiled: bool=true) -> Variant:
	# Source-local collision bounds are built once per immutable template,
	# including non-rendered faces/overhangs, and transformed by the current pose.
	# Reject distant models before allocating lists/inverses or visiting Parts.
	if instance.has_meta("native_scene_bounds"):
		var bounds: AABB=instance.global_transform*instance.get_meta("native_scene_bounds")
		if bounds.intersects_segment(engine(start),engine(end))==null: return null
	prepare_parts(instance)
	if compiled:
		var owner: RefCounted=prepare_model(instance)
		if owner!=null:
			var hit: Variant=owner.call("dispatch",1,{"start":start,"end":end})
			if hit==null: return null
			if hit.has("error"): push_error(str(hit.error)); return null
			return hit if details else hit.position
	var best: Variant=null; var limit: Array=end; var a:=engine(start); var b:=engine(end)
	for part in instance.get_meta("native_scene_parts"):
		if not is_instance_valid(part.node): continue
		var transform: Transform3D=part.node.global_transform; var box: AABB=part.data.bounds
		if not part.has("pose") or part.pose!=transform or part.local_bounds!=box:
			part.pose=transform; part.local_bounds=box; part.inverse=transform.affine_inverse()
			var world_box: AABB=transform*AABB(Vector3(box.position.x,box.position.z,-box.end.y),Vector3(box.size.x,box.size.z,box.size.y))
			part.world_bounds=world_box.grow(maxf(1.0,maxf(world_box.position.abs().length(),world_box.end.abs().length()))*0.000003814697265625)
		if part.world_bounds.intersects_segment(a,b)==null: continue
		var result: Variant=part.data.nearest(native(part.inverse*a),native(part.inverse*b),details,compiled)
		if result!=null:
			if details: best={"position":M.values(native(transform*engine(result.position))),"normal":M.values(native((part.inverse.basis.transposed()*engine(result.normal)).normalized()))}; limit=best.position
			else: best=native(transform*engine(result)); limit=best
			b=engine(limit)
	return best
static func trace(world,start: Array,end: Array,details: bool=false,indexed: bool=true) -> Dictionary:
	var phase:=Profile.begin()
	var best: Variant=null; var normal: Array=[0.0,0.0,0.0]; var limit: Array=M.values(end); var terrain=world.get("terrain"); var surface=world.get("surface")
	# These projectile builders issue vertical finite rays. Original WOK faces
	# retain physical order, native planes, quarter turns and surface30 exclusion.
	if is_instance_valid(surface) and surface.ready() and start[0]==end[0] and start[1]==end[1]:
		for index in surface.vertical_candidates(start):
			var tile: Dictionary=surface.definition.tiles[index]; var data: Dictionary=surface.meshes[tile.model]
			var origin: Vector2=surface.tile_origin(index); var xy:=Surface.canonical([M.f(start[0]-origin.x),M.f(start[1]-origin.y)],int(tile.orientation)); var a: Array=[xy[0],xy[1],M.f(start[2]-tile.position.y)]; var b: Array=[xy[0],xy[1],M.f(limit[2]-tile.position.y)]
			if surface.has_method("collision_geometry"):
				var hit: Variant=surface.collision_geometry(str(tile.model)).nearest(a,b,true,indexed)
				if hit!=null:
					best=[start[0],start[1],M.f(hit.position[2]+tile.position.y)]; limit=best
					if details: normal=tile_normal(hit.normal,int(tile.orientation))
			else:
				for i in data.faces.size():
					if (int(data.materials[i])&63)==30: continue
					var face: Array=data.faces[i]; var hit: Variant=Polygon.hit([data.vertices[face[0]],data.vertices[face[1]],data.vertices[face[2]]],data.normals[i],data.constants[i],a,b)
					if hit!=null:
						best=[start[0],start[1],M.f(hit[2]+tile.position.y)]; limit=best; b[2]=hit[2]
						if details: normal=tile_normal(data.normals[i],int(tile.orientation))
	Profile.finish("native_scene_wok",phase); phase=Profile.begin()
	if is_instance_valid(terrain):
		var terrain_index=terrain.get("collision_index")
		if indexed and terrain_index!=null and terrain_index.native_ready():
			var hit: Variant=terrain_index.nearest(start,limit)
			if hit!=null:
				best=hit.position; limit=best
				if details: normal=hit.normal
		else:
			var candidates: Array=terrain.collision_candidates(engine(start),engine(limit)) if indexed and terrain.has_method("collision_candidates") else terrain.instances.values()
			for instance in candidates:
				var hit: Variant=model_hit(instance,start,limit,details)
				if hit!=null:
					best=hit.position if details else hit; limit=best
					if details: normal=hit.normal
		if is_instance_valid(terrain.batcher):
			for mesh in terrain.batcher.owners:
				var geometry=mesh.mesh if mesh is MeshInstance3D else mesh.multimesh.mesh; var data=geometry.get_meta("native_scene_geometry",null)
				for i in (1 if mesh is MeshInstance3D else mesh.multimesh.instance_count):
					var pose: Transform3D=mesh.global_transform if mesh is MeshInstance3D else mesh.global_transform*mesh.multimesh.get_instance_transform(i); var hit: Variant=mesh_hit(mesh,data,pose,start,limit,details)
					if hit!=null:
						best=hit.position if details else hit; limit=best
						if details: normal=hit.normal
	Profile.finish("native_scene_terrain",phase); phase=Profile.begin()
	var static_index=world.get("static_collision_index")
	if indexed and static_index!=null and static_index.native_ready():
		var hit: Variant=static_index.nearest(start,limit)
		if hit!=null:
			best=hit.position; limit=best
			if details: normal=hit.normal
	else:
		var static_candidates: Array=static_index.query(engine(start),engine(limit)) if indexed and static_index!=null else world.instances.keys().filter(func(id):return world.desired.get(id,{}).get("object",{}).has("staticState")).map(func(id):return world.instances[id])
		for instance in static_candidates:
			var hit: Variant=model_hit(instance,start,limit,details)
			if hit!=null:
				best=hit.position if details else hit; limit=best
				if details: normal=hit.normal
	Profile.finish("native_scene_static",phase)
	var result:={"hit":best!=null,"position":best if best!=null else [0.0,0.0,0.0]}
	if details: result.normal=normal
	return result
