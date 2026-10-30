extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Own original WOKs independently of visual meshes; reuse each decoded local
# tile across placements, and apply exact quarter-turns at query time.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Surface=preload("res://systems/native_data/tile_surface.gd")
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Priority=preload("res://systems/native_render/stream_priority.gd")
var priority_origin:=Vector3.ZERO
var has_priority_origin:=false
func set_priority_origin(value: Vector3) -> void:
	if not value.is_finite() or has_priority_origin and priority_origin.distance_squared_to(value)<4.0: return
	priority_origin=value; has_priority_origin=true
	if definition.is_empty(): return
	var names: Array=Priority.model_order(definition.models.keys(),definition.models,priority_origin,definition.tiles)
	var ranks: Dictionary={}
	for index in names.size(): ranks[names[index]]=index
	waiting.sort_custom(func(a,b):return int(ranks[a])<int(ranks[b]))
	assets.prioritize(Priority.request_order(requests,names))
var assets
var definition: Dictionary={}
var table: Dictionary={}
var meshes: Dictionary={}
var requests: Dictionary={}
var waiting: Array=[]
var closed:=false
var done:=false
var vertical_grid: Dictionary={}
var vertical_bounds: Dictionary={}
var vertical_global: Array=[]
var collision_meshes: Dictionary={}
var stats:={"models":0,"cache_hits":0,"queries":0,"outside_queries":0,"worker_ms":0.0,"errors":[],"native_only":true,"complete_collision":false}
func configure(catalog,source: Dictionary,cache_path: String) -> void:
	definition=source; waiting=source.models.keys()
	assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	requests[assets.request("surfacemat",2017,"2da")]="@surfacemat"
func prepared(id: int,result: Dictionary) -> void:
	if closed or not requests.has(id): return
	var name:=str(requests[id]); requests.erase(id)
	stats.worker_ms+=float(result.worker_ms)
	if not str(result.error).is_empty(): stats.errors.append({"resource":name,"reason":result.error}); return
	if result.cache_hit: stats.cache_hits+=1
	if name=="@surfacemat": table=result.value
	else: meshes[name]=result.value; stats.models+=1
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_walkmesh",began)
func _profile_process(_delta: float) -> void:
	if closed or done: return
	while not waiting.is_empty() and assets.pending.size()+assets.running.size()<mini(assets.maximum_pending,assets.maximum_workers*2):
		var name:=str(waiting.pop_front()); var id: int=assets.request(name,2016,"tile-surface-v1")
		if id<0: stats.errors.append({"resource":name,"reason":assets.failure})
		else: requests[id]=name
	if waiting.is_empty() and requests.is_empty():
		done=true
		if stats.errors.is_empty(): index_vertical_tiles()
func index_vertical_tiles() -> void:
	vertical_grid.clear(); vertical_bounds.clear(); vertical_global.clear()
	for i in definition.tiles.size():
		var tile: Dictionary=definition.tiles[i]; var mesh: Dictionary=meshes[tile.model]; var low: Array=mesh.bounds_min; var high: Array=mesh.bounds_max; var minimum:=Vector2(INF,INF); var maximum:=Vector2(-INF,-INF); var origin:=tile_origin(i)
		for x in [low[0],high[0]]:
			for y in [low[1],high[1]]:
				var xy:=Surface.canonical([x,y],posmod(4-int(tile.orientation),4)); var p:=Vector2(xy[0]+origin.x,xy[1]+origin.y); minimum=minimum.min(p); maximum=maximum.max(p)
		var margin:=maxf(1.0,maxf(minimum.abs().length(),maximum.abs().length()))*0.000003814697265625
		minimum-=Vector2.ONE*margin; maximum+=Vector2.ONE*margin; vertical_bounds[i]={"min":minimum,"max":maximum}
		var a:=Vector2i(floori(minimum.x/10),floori(minimum.y/10)); var b:=Vector2i(floori(maximum.x/10),floori(maximum.y/10))
		if (b.x-a.x+1)*(b.y-a.y+1)>1024: vertical_global.append(i); continue
		for y in range(a.y,b.y+1):
			for x in range(a.x,b.x+1):
				var key:=Vector2i(x,y)
				if not vertical_grid.has(key): vertical_grid[key]=[]
				vertical_grid[key].append(i)
func vertical_candidates(point: Array) -> Array:
	var candidates: Array=vertical_grid.get(Vector2i(floori(float(point[0])/10),floori(float(point[1])/10)),[]).duplicate(); candidates.append_array(vertical_global); var result: Array=[]
	for i in candidates:
		var bounds: Dictionary=vertical_bounds[i]
		if point[0]>=bounds.min.x and point[1]>=bounds.min.y and point[0]<=bounds.max.x and point[1]<=bounds.max.y: result.append(i)
	result.sort(); return result
func tile_origin(index: int) -> Vector2:
	# Decoded WOK vertices already include the native +5 offset. Their origin
	# is the grid corner, whereas visual MDL tile.position is the grid center.
	return Vector2((index%int(definition.width))*10,floori(float(index)/int(definition.width))*10)
func collision_geometry(resource: String):
	if collision_meshes.has(resource): return collision_meshes[resource]
	# WOKs use the same original polygon predicate as MDL collision faces. Keep
	# their stored planes and physical face order; share one immutable native
	# snapshot across all placements rather than scripting every vertical hit.
	var source: Dictionary=meshes[resource]; var vertices:=PackedFloat32Array(); var indices:=PackedInt32Array(); var planes:=PackedFloat32Array()
	for vertex in source.vertices: vertices.append_array(PackedFloat32Array(vertex))
	for index in source.faces.size():
		indices.append_array(PackedInt32Array(source.faces[index])); planes.append_array(PackedFloat32Array(source.normals[index]+[source.constants[index]]))
	var geometry:=Geometry.new(); geometry.configure({"vertices":vertices,"indices":indices,"native_planes":planes,"native_surface_types":PackedInt32Array(source.materials)})
	collision_meshes[resource]=geometry; return geometry
func ready() -> bool: return done and stats.errors.is_empty() and not table.is_empty()
func height(point: Vector3,previous: float) -> float:
	if not ready(): return previous
	stats.queries+=1
	var x:=floori(point.x/10.0); var y:=floori(point.y/10.0)
	if x<0 or y<0 or x>=int(definition.width) or y>=int(definition.height): stats.outside_queries+=1; return previous
	var tile: Dictionary=definition.tiles[y*int(definition.width)+x]
	var local:=Surface.canonical([Surface.f(Surface.f(point.x)-Surface.f(Surface.f(x)*10)),Surface.f(Surface.f(point.y)-Surface.f(Surface.f(y)*10))],int(tile.orientation))
	return Surface.f(Surface.height(meshes[tile.model],table,local)+Surface.f(tile.position.y))
func snapshot() -> Dictionary:
	var state:=stats.duplicate(true); state.merge({"done":done,"ready":ready(),"pending":waiting.size()+requests.size(),"scope":"Original native tile WOK height only; adjacency, line collision, door/placeable obstacles and WASD prediction pending"}); return state
func detach_prepared_data() -> Dictionary:
	var payload:={"definition":definition.duplicate(),"table":table.duplicate(),"meshes":meshes.duplicate(),"vertical_grid":vertical_grid.duplicate(),"vertical_bounds":vertical_bounds.duplicate(),"vertical_global":vertical_global.duplicate()}
	definition={}; table={}; meshes={}; vertical_grid={}; vertical_bounds={}; vertical_global=[]
	# Native scene-query owners in collision_meshes are not moved to workers.
	return payload
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(assets): assets.close()
	meshes.clear(); requests.clear(); waiting.clear(); table.clear(); definition={}
	vertical_grid.clear(); vertical_bounds.clear(); vertical_global.clear()
	collision_meshes.clear()
func _exit_tree() -> void: close()
