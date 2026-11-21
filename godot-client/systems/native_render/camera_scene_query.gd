extends RefCounted

# Scene::HitCheck for the camera uses WOK faces and static tile models. Dynamic
# objects and the separate world static-object index are not camera occluders.
const TileSurface = preload("res://systems/native_data/tile_surface.gd")
const ProjectileScene = preload("res://systems/native_render/projectile_scene.gd")
const Polygon = preload("res://systems/native_data/polygon_hit.gd")
const SceneGeometry = preload("res://systems/native_render/scene_geometry.gd")
const Timing = preload("res://systems/native_render/frame_profile.gd")
static var use_wok_grid := not OS.get_cmdline_user_args().has("--camera-wok-index=off")

# camera_query_bounds.js admits uncertain faces to the exact polygon predicate.
static func _face_bounds(geometry,at: int) -> Variant:
	var vertices: Array=geometry.face(at)
	var offset: int=at/3*4
	if vertices.size()!=3 or geometry.planes.size()<offset+4:return null
	var normal: Array=[float(geometry.planes[offset]),float(geometry.planes[offset+1]),float(geometry.planes[offset+2])]
	var constant:=float(geometry.planes[offset+3])
	if not is_finite(constant):return null
	for vertex in vertices:
		if not vertex is Array or vertex.size()!=3:return null
		for value in vertex:
			if not is_finite(float(value)):return null
	for value in normal:
		if not is_finite(float(value)):return null
	var a: Array=[];var b: Array=[]
	for i in 3:a.append(float(vertices[1][i])-float(vertices[0][i]));b.append(float(vertices[2][i])-float(vertices[0][i]))
	var cross: Array=[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
	var area:=sqrt(cross[0]*cross[0]+cross[1]*cross[1]+cross[2]*cross[2])
	var length:=sqrt(normal[0]*normal[0]+normal[1]*normal[1]+normal[2]*normal[2])
	var edge:=maxf(a[0]*a[0]+a[1]*a[1]+a[2]*a[2],b[0]*b[0]+b[1]*b[1]+b[2]*b[2])
	if not (length>1e-8 and area>edge*1e-4) or cross[0]*normal[0]+cross[1]*normal[1]+cross[2]*normal[2]<area*length*0.99999:return null
	var low: Array=[];var high: Array=[];var scale:=1.0
	for i in 3:
		var small:=minf(float(vertices[0][i]),minf(float(vertices[1][i]),float(vertices[2][i])))
		var large:=maxf(float(vertices[0][i]),maxf(float(vertices[1][i]),float(vertices[2][i])))
		low.append(small);high.append(large);scale=maxf(scale,maxf(absf(small),absf(large)))
	var margin:=scale*0.000003814697265625
	for vertex in vertices:
		if absf(float(vertex[0])*normal[0]+float(vertex[1])*normal[1]+float(vertex[2])*normal[2]+constant)>margin*length:return null
	for i in 3:low[i]-=margin;high[i]+=margin
	return {"min":low,"max":high}

static func _segment_overlaps(bounds: Variant,start: Array,finish: Array) -> bool:
	if bounds==null:return true
	for value in start+finish:
		if not is_finite(float(value)):return true
	for i in 3:
		if maxf(float(start[i]),float(finish[i]))<float(bounds.min[i]) or minf(float(start[i]),float(finish[i]))>float(bounds.max[i]):return false
	return true

static func _geometry_bounds(geometry) -> Dictionary:
	if geometry.has_meta("native_camera_face_bounds"):return geometry.get_meta("native_camera_face_bounds")
	var rows: Array=[];var uncertain:=false
	for at in range(0,geometry.indices.size(),3):
		var bounds: Variant=_face_bounds(geometry,at)
		rows.append(bounds)
		if bounds==null:uncertain=true
	var record:={"faces":rows,"uncertain":uncertain}
	geometry.set_meta("native_camera_face_bounds",record)
	return record

static func _wok_hit(geometry,start: Array,finish: Array,details: bool=false) -> Variant:
	var bounds: Dictionary=_geometry_bounds(geometry)
	if not bool(bounds.uncertain):return geometry.nearest(start,finish,details)
	var best: Variant=null;var limit: Array=finish;var normal: Array=[]
	for at in range(0,geometry.indices.size(),3):
		if at/3<geometry.surface_types.size() and (int(geometry.surface_types[at/3])&63)==30:continue
		if not _segment_overlaps(bounds.faces[at/3],start,limit):continue
		var offset: int=at/3*4
		var hit: Variant=Polygon.hit(geometry.face(at),[geometry.planes[offset],geometry.planes[offset+1],geometry.planes[offset+2]],geometry.planes[offset+3],start,limit)
		if hit!=null:best=hit;limit=hit;normal=[geometry.planes[offset],geometry.planes[offset+1],geometry.planes[offset+2]]
	return {"position":best,"normal":normal} if details and best!=null else best

static func _wok_cells(low: Vector2, high: Vector2, limit: int) -> Variant:
	if not low.is_finite() or not high.is_finite() or high.x < low.x or high.y < low.y:
		return null
	# Vector2i keys represent native world cells. Broad input is cheaper to
	# send through the original sequential path than to enumerate its cells.
	if maxf(maxf(absf(low.x), absf(low.y)), maxf(absf(high.x), absf(high.y))) >= 21474835200.0:
		return null
	var a := Vector2i(floori(low.x / 10), floori(low.y / 10))
	var b := Vector2i(floori(high.x / 10), floori(high.y / 10))
	if int(b.x) - int(a.x) + 1 > limit or int(b.y) - int(a.y) + 1 > limit:
		return null
	if (int(b.x) - int(a.x) + 1) * (int(b.y) - int(a.y) + 1) > limit:
		return null
	return [a,b]

static func _make_wok_grid(surface, geometries: Dictionary, tiles: int) -> Dictionary:
	var grid: Dictionary = {}
	var unbounded := PackedInt32Array()
	for index in tiles:
		if not geometries.has(index):
			return {}
		var geometry = geometries[index]
		var bounds: AABB = geometry.bounds
		# Only the native `nearest` path already rejects by this world AABB.
		# Degenerate/uncertified faces always remain in authored query order.
		var cells: Variant = null if bool(_geometry_bounds(geometry).uncertain) else _wok_cells(
			Vector2(bounds.position.x, bounds.position.y), Vector2(bounds.end.x, bounds.end.y), maxi(16,tiles))
		if cells == null:
			unbounded.append(index)
			continue
		for y in range(cells[0].y, cells[1].y + 1):
			for x in range(cells[0].x, cells[1].x + 1):
				var cell := Vector2i(x,y)
				if not grid.has(cell):
					grid[cell] = []
				grid[cell].append(index)
	return {"grid":grid,"unbounded":unbounded,"definition":surface.definition,"meshes":surface.meshes,"tile_count":tiles}

static func _wok_order(surface, start: Array, finish: Array) -> Variant:
	var tiles: int = surface.definition.tiles.size()
	if not use_wok_grid or tiles < 4 or surface.meshes.size() != surface.definition.get("models", {}).size():
		return tiles
	for value in start + finish:
		if not is_finite(float(value)):
			return tiles
	var low := Vector2(minf(start[0],finish[0]), minf(start[1],finish[1]))
	var high := Vector2(maxf(start[0],finish[0]), maxf(start[1],finish[1]))
	# A nearest-hit segment can be shortened at a rounded hit point. Retain
	# neighboring cells at numeric seams while the old predicates choose hits.
	var margin := maxf(1.0,maxf(low.abs().length(),high.abs().length())) * 0.000003814697265625
	var cells: Variant = _wok_cells(low-Vector2.ONE*margin,high+Vector2.ONE*margin,tiles)
	if cells == null:
		return tiles
	var record: Dictionary = surface.get_meta("native_camera_wok_grid",{})
	if record.is_empty() or not is_same(record.definition,surface.definition) or not is_same(record.meshes,surface.meshes) or record.tile_count != tiles:
		var geometries: Dictionary = surface.get_meta("native_camera_world_geometry",{})
		if geometries.size() != tiles:
			return tiles
		record = _make_wok_grid(surface,geometries,tiles)
		if record.is_empty():
			return tiles
		surface.set_meta("native_camera_wok_grid",record)
	var indices: Dictionary = {}
	for index in record.unbounded:
		indices[index] = true
	for y in range(cells[0].y, cells[1].y + 1):
		for x in range(cells[0].x, cells[1].x + 1):
			for index in record.grid.get(Vector2i(x,y),[]):
				indices[index] = true
	var selected := indices.keys()
	selected.sort()
	Timing.count("count_camera_wok_tiles_skipped", tiles - selected.size())
	return selected

# loadAreaWalkmesh assembled each tile in world coordinates and appended its
# walkable faces before denied faces. Keep that immutable order and its planes
# camera-only; the movement/height owner retains the physical WOK face order.
static func _camera_wok_tile(surface,index: int):
	var cached: Dictionary=surface.get_meta("native_camera_world_geometry",{})
	if cached.has(index):return cached[index]
	var tile: Dictionary=surface.definition.tiles[index]
	var source: Dictionary=surface.meshes[str(tile.model)]
	var origin: Vector2=surface.tile_origin(index)
	var orientation:=int(tile.orientation)
	var vertices:=PackedFloat32Array()
	for vertex in source.vertices:
		var x:=TileSurface.f(TileSurface.f(origin.x)+TileSurface.f(float(vertex[0])))
		var y:=TileSurface.f(TileSurface.f(origin.y)+TileSurface.f(float(vertex[1])))
		var local:=TileSurface.canonical([TileSurface.f(x-origin.x),TileSurface.f(y-origin.y)],posmod(4-orientation,4))
		vertices.append_array(PackedFloat32Array([TileSurface.f(origin.x+local[0]),TileSurface.f(origin.y+local[1]),TileSurface.f(float(vertex[2])+TileSurface.f(float(tile.position.y)))]))
	var indices:=PackedInt32Array();var planes:=PackedFloat32Array();var types:=PackedInt32Array()
	for allowed in [true,false]:
		for face_index in source.faces.size():
			var material:=int(source.materials[face_index])
			if TileSurface.walkable(surface.table,material)!=allowed:continue
			var face: Array=source.faces[face_index]
			var points: Array=[]
			for vertex_index in face:
				var at:=int(vertex_index)*3
				points.append([vertices[at],vertices[at+1],vertices[at+2]])
			var plane: Dictionary=Polygon.plane(points)
			indices.append_array(PackedInt32Array(face))
			planes.append_array(PackedFloat32Array(plane.normal+[plane.constant]))
			types.append(material)
	var geometry=SceneGeometry.new()
	geometry.configure({"vertices":vertices,"indices":indices,"native_planes":planes,"native_surface_types":types})
	cached[index]=geometry
	surface.set_meta("native_camera_world_geometry",cached)
	return geometry

# CameraSceneQuery used the source nativeCameraHitFaces on every tile mesh.
# Unlike WOK faces, those model faces were not surface-type masked. Keep this
# camera-only path separate from the projectile/scene masked hit owner.
static func _unmasked_geometry_hit(geometry,start: Array,finish: Array,details: bool=false) -> Variant:
	var bounds: Dictionary=_geometry_bounds(geometry)
	var native_owner: RefCounted=geometry.prepare_native_unmasked_support() if not bool(bounds.uncertain) else null
	if native_owner!=null:
		var native_hit: Variant=native_owner.call("dispatch",1,{"start":start,"end":finish})
		if native_hit is Dictionary and native_hit.has("error"):push_error(str(native_hit.error))
		elif native_hit is Dictionary and native_hit.get("position") is Array:return native_hit if details else native_hit.position
		elif native_hit==null:return null
	var best: Variant=null;var limit: Array=finish;var normal: Array=[]
	for at in range(0,geometry.indices.size(),3):
		if not _segment_overlaps(bounds.faces[at/3],start,limit):continue
		var offset: int=at/3*4
		var hit: Variant=Polygon.hit(geometry.face(at),[geometry.planes[offset],geometry.planes[offset+1],geometry.planes[offset+2]],geometry.planes[offset+3],start,limit)
		if hit!=null:best=hit;limit=hit;normal=[geometry.planes[offset],geometry.planes[offset+1],geometry.planes[offset+2]]
	return {"position":best,"normal":normal} if details and best!=null else best

static func _mesh_inverse(surface: Node3D,geometry) -> Transform3D:
	# The old meshInfo cache kept the inverse until either the geometry or the
	# exact world matrix changed. Keep that ownership on the tile mesh itself.
	var transform: Transform3D=surface.global_transform
	var record: Variant=surface.get_meta("native_camera_mesh_inverse",false)
	if record is Dictionary and record.get("geometry")==geometry and record.get("transform")==transform and record.get("inverse") is Transform3D:
		return record.inverse
	var inverse:=transform.affine_inverse()
	surface.set_meta("native_camera_mesh_inverse",{"geometry":geometry,"transform":transform,"inverse":inverse})
	return inverse

static func _camera_model_hit(instance,start: Array,finish: Array,nearest: bool,details: bool=false) -> Variant:
	if not instance.get("parts") is Array:return null
	var best: Variant=null;var limit: Array=finish
	for part in instance.parts:
		if not is_instance_valid(part):continue
		var surface: Node3D=part
		var geometry=null
		var drawable: Variant=part if part is MeshInstance3D else part.get_node_or_null("mesh")
		if drawable is MeshInstance3D and drawable.mesh!=null:
			surface=drawable
			geometry=drawable.mesh.get_meta("native_scene_geometry",null)
		elif part.has_meta("native_pick_geometry"):
			geometry=part.get_meta("native_pick_geometry").get_meta("native_scene_geometry",null)
		if geometry==null:continue
		var inverse: Transform3D=_mesh_inverse(surface,geometry)
		var local_from: Array=ProjectileScene.native(inverse*ProjectileScene.engine(start))
		var local_to: Array=ProjectileScene.native(inverse*ProjectileScene.engine(limit))
		var local_hit: Variant=_unmasked_geometry_hit(geometry,local_from,local_to,details)
		if local_hit==null:continue
		if details:
			best={"position":ProjectileScene.native(surface.global_transform*ProjectileScene.engine(local_hit.position)),"normal":ProjectileScene.native((inverse.basis.transposed()*ProjectileScene.engine(local_hit.normal)).normalized())}
		else:best=ProjectileScene.native(surface.global_transform*ProjectileScene.engine(local_hit))
		if not nearest:return best
		limit=best.position if details else best
	return best

static func _model_has_uncertain_face(instance) -> bool:
	if not instance.get("parts") is Array:return false
	for part in instance.parts:
		if not is_instance_valid(part):continue
		var drawable: Variant=part if part is MeshInstance3D else part.get_node_or_null("mesh")
		var geometry=null
		if drawable is MeshInstance3D and drawable.mesh!=null:geometry=drawable.mesh.get_meta("native_scene_geometry",null)
		elif part.has_meta("native_pick_geometry"):geometry=part.get_meta("native_pick_geometry").get_meta("native_scene_geometry",null)
		if geometry!=null and bool(_geometry_bounds(geometry).uncertain):return true
	return false

static func _camera_candidates(terrain,start: Array,finish: Array) -> Array:
	if not terrain.has_method("collision_candidates"):return terrain.instances.values()
	var candidates: Array=terrain.collision_candidates(ProjectileScene.engine(start),ProjectileScene.engine(finish))
	var scope: Dictionary=terrain.get_meta("native_camera_uncertain",{})
	if int(scope.get("generation",-1))!=int(terrain.generation) or int(scope.get("size",-1))!=terrain.instances.size():
		var uncertain: Array=[]
		for instance in terrain.instances.values():
			if is_instance_valid(instance) and _model_has_uncertain_face(instance):uncertain.append(instance)
		scope={"generation":int(terrain.generation),"size":terrain.instances.size(),"instances":uncertain}
		terrain.set_meta("native_camera_uncertain",scope)
	for instance in scope.instances:
		if is_instance_valid(instance) and not candidates.has(instance):candidates.append(instance)
	candidates.sort_custom(func(a,b):return int(a.get_meta("native_tile_index",0))<int(b.get_meta("native_tile_index",0)))
	return candidates

static func blocked(world: Object, start: Array, finish: Array) -> bool:
	if not is_instance_valid(world) or start.size() != 3 or finish.size() != 3:
		return false
	var surface = world.get("surface")
	if is_instance_valid(surface) and surface.ready():
		for index in _wok_order(surface,start,finish):
			var tile: Dictionary = surface.definition.tiles[index]
			if not surface.meshes.has(tile.model):
				continue
			# SceneGeometry excludes material/surface type 30 and uses the stored
			# native face planes rather than visible render triangles.
			if _wok_hit(_camera_wok_tile(surface,index),start,finish) != null:
				return true
	var terrain = world.get("terrain")
	if not is_instance_valid(terrain):
		return false
	var candidates: Array = _camera_candidates(terrain,start,finish)
	for instance in candidates:
		if is_instance_valid(instance) and _camera_model_hit(instance, start, finish,false) != null:
			return true
	return false

# The collision camera needs the closest point, while clear view needs only a
# boolean. Keep the existing blocked() path and its face order unchanged.
static func nearest(world: Object,start: Array,finish: Array) -> Variant:
	return _nearest(world,start,finish,false)

static func nearest_hit(world: Object,start: Array,finish: Array) -> Variant:
	return _nearest(world,start,finish,true)

static func _nearest(world: Object,start: Array,finish: Array,details: bool) -> Variant:
	if not is_instance_valid(world) or start.size()!=3 or finish.size()!=3:return null
	var best: Variant=null
	var limit: Array=finish
	var surface=world.get("surface")
	if is_instance_valid(surface) and surface.ready():
		for index in _wok_order(surface,start,limit):
			var tile: Dictionary=surface.definition.tiles[index]
			if not surface.meshes.has(tile.model):continue
			var hit: Variant=_wok_hit(_camera_wok_tile(surface,index),start,limit,details)
			var position: Variant=hit.get("position") if details and hit is Dictionary else hit
			if position is Array and position.size()==3:
				best=hit
				limit=position
	var terrain=world.get("terrain")
	if not is_instance_valid(terrain):return best
	var candidates: Array=_camera_candidates(terrain,start,limit)
	for instance in candidates:
		if not is_instance_valid(instance):continue
		var hit: Variant=_camera_model_hit(instance,start,limit,true,details)
		var world_position: Variant=hit.get("position") if details and hit is Dictionary else hit
		if world_position is Array and world_position.size()==3:best=hit;limit=world_position
	return best
