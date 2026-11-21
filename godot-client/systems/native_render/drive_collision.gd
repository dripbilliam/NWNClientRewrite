extends Node
# Native prediction geometry, independent of highlighting/picking. Reads the
# active original WOK/PWK/DWK and appearance tables. Conservative capsule/face
# tests are a Godot adaptation; exact original polygon scratch behavior remains
# separate research. The server always owns accepted movement.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Surface=preload("res://systems/native_data/tile_surface.gd")
const Objects=preload("res://systems/native_render/object_stream.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
var world
var assets
var tables: Dictionary={}
var requests: Dictionary={}
var models: Dictionary={}
var tiles: Dictionary={}
var objects: Dictionary={}
var closed:=false
var warm_dirty:=true
var warm_queue: Array=[]
var stats:={"queries":0,"blocked":0,"reasons":{},"models":0,"missing":0,"errors":[],"native_only":true,"exact_polygon_parity":false}
func deny(reason: String,from: Vector3,to: Vector3) -> bool:
	stats.blocked+=1; stats.reasons[reason]=int(stats.reasons.get(reason,0))+1
	stats.last_blocked={"reason":reason,"from":[from.x,from.y,from.z],"to":[to.x,to.y,to.z]}; return false
func configure(owner,source,cache_path: String) -> void:
	world=owner; assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(source); assets.cache_directory=cache_path
	assets.completed.connect(prepared)
	for name in ["appearance","placeables","genericdoors","doortypes"]: requests[assets.request(name,2017,"2da")]={"table":name}
func prepared(id: int,result: Dictionary) -> void:
	if closed or not requests.has(id): return
	var job: Dictionary=requests[id]; requests.erase(id)
	if not str(result.error).is_empty():
		stats.errors.append({"resource":job.get("table",job.get("model","")),"reason":str(result.error)})
		if job.has("model"): models[job.model]={"error":str(result.error)}
		return
	if job.has("table"): tables[job.table]=result.value
	else: models[job.model]=result.value; stats.models+=1
func ready() -> bool: return tables.size()==4 and is_instance_valid(world.surface) and world.surface.ready()
func _process(_delta: float) -> void:
	var began:=preload("res://systems/native_render/frame_profile.gd").begin()
	if not closed and is_instance_valid(assets) and tables.size()==4:
		if warm_dirty: warm_queue=world.desired.keys(); warm_dirty=false
		for i in 32:
			if warm_queue.is_empty() or assets.pending.size()+assets.running.size()>=assets.maximum_pending: break
			var id: int=warm_queue.pop_front()
			if not world.desired.has(id): continue
			var object: Dictionary=world.desired[id].object
			if int(object.objectType) not in [9,10]: continue
			var spec:=descriptor(object)
			if not spec.is_empty(): demand(spec)
	preload("res://systems/native_render/frame_profile.gd").finish("callback_drive_geometry",began)
func row(table: String,index: int) -> Dictionary:
	var rows: Array=tables.get(table,{}).get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() else {}
func dimensions(id: int) -> Vector2:
	var object: Dictionary=world.desired.get(id,{}).get("object",{}); var data:=row("appearance",int(object.get("appearance",{}).get("appearance",-1)))
	return Vector2(maxf(0,float(Rules.cell(data,"PERSPACE","0"))),maxf(0,float(Rules.cell(data,"HEIGHT","0"))))
func descriptor(object: Dictionary) -> Dictionary:
	var kind:=int(object.objectType); var state: Dictionary=object.get("replicated",{}); var fixed: Dictionary=object.get("staticState",object.get("lightState",{})); var data: Dictionary={}
	if kind==9: data=row("placeables",int(state.get("appearance",fixed.get("appearance",-1))))
	elif kind==10:
		var type:=int(state.get("doorType",0)); data=row("genericdoors" if type==0 else "doortypes",int(state.get("genericType",0)) if type==0 else type)
		if str(Rules.cell(data,"VisibleModel","1"))=="0": return {}
	else: return {}
	var name:=str(Rules.cell(data,"ModelName",Rules.cell(data,"Model",""))).to_lower()
	if name in ["","****"]: return {}
	return {"model":name,"door":kind==10,"state":int(state.get("doorOpenState",0))}
func demand(spec: Dictionary) -> void:
	var key:=str(spec.model)+(":door" if spec.door else ":placeable")
	if models.has(key): return
	if requests.values().any(func(job):return str(job.get("model",""))==key): return
	var type:=2052 if spec.door else 2053
	if not assets.catalog.has_resource(str(spec.model),type): models[key]={"states":[]}; stats.missing+=1; return
	var id: int=assets.request(str(spec.model),type,"dwk-surface-v1" if spec.door else "pwk-surface-v1")
	if id>=0: requests[id]={"model":key}
static func triangle(a: Vector3,b: Vector3,c: Vector3) -> Dictionary:
	return {"a":a,"b":b,"c":c,"min":a.min(b).min(c),"max":a.max(b).max(c)}
func tile(index: int) -> Array:
	if tiles.has(index): return tiles[index]
	var source: Dictionary=world.surface.definition.tiles[index]; var mesh: Dictionary=world.surface.meshes[source.model]; var vertices: Array=[]
	var width:=int(world.surface.definition.width); var x:=index%width; var y:=index/width
	for original in mesh.vertices:
		var p: Array=Surface.canonical([original[0],original[1]],(4-int(source.orientation))%4)
		vertices.append(Vector3(p[0]+x*10,p[1]+y*10,float(original[2])+source.position.y))
	var result: Array=[]
	for i in mesh.faces.size():
		var face: Array=mesh.faces[i]; var value:=triangle(vertices[face[0]],vertices[face[1]],vertices[face[2]])
		value.walk=Surface.walkable(world.surface.table,int(mesh.materials[i])); result.append(value)
	tiles[index]=result; return result
func obstacle(id: int,object: Dictionary,spec: Dictionary) -> Dictionary:
	var key:=str(spec.model)+(":door" if spec.door else ":placeable"); var pose:=Objects.pose(object)
	if pose.is_empty(): return {}
	var signature: Array=[key,spec.state,pose.position,pose.rotation]
	if objects.has(id) and objects[id].signature==signature: return objects[id]
	var model: Dictionary=models.get(key,{})
	if model.is_empty() or model.has("error"): return {"pending":true,"position":pose.position}
	var states: Array=model.get("states",[]); var state:=int(spec.state) if spec.door else 0
	if state<0 or state>=states.size(): return {}
	var result:={"signature":signature,"triangles":[],"min":Vector3(INF,INF,INF),"max":Vector3(-INF,-INF,-INF)}; var vertices: Array=[]
	for source in states[state].vertices:
		var p: Vector3=Basis(Vector3.UP,float(pose.rotation))*Vector3(source.x,source.z,-source.y)+pose.position
		var nwn:=Vector3(p.x,-p.z,p.y); vertices.append(nwn); result.min=result.min.min(nwn); result.max=result.max.max(nwn)
	for face in states[state].faces: result.triangles.append(triangle(vertices[face[0]],vertices[face[1]],vertices[face[2]]))
	objects[id]=result; return result
func query(id: int,radius_override: float=-1) -> Callable:
	if not ready(): return Callable()
	var dims:=dimensions(id); var radius:=dims.x if radius_override<0 else radius_override
	var obstacles: Array=[]; var creatures: Array=[]; var pending: Array=[]
	for key in world.desired:
		var object: Dictionary=world.desired[key].object
		if int(object.objectType)==5 and int(key)!=id and radius_override<0:
			var motion: Dictionary=world.motion.objects.get(key,{})
			if not motion.is_empty(): creatures.append({"point":Vector2(motion.render.x,motion.render.y),"radius":dimensions(int(key)).x+radius})
		elif int(object.objectType) in [9,10]:
			var spec:=descriptor(object)
			if spec.is_empty(): continue
			demand(spec); var shape:=obstacle(int(key),object,spec)
			if shape.get("pending",false): pending.append(Vector2(shape.position.x,-shape.position.z))
			elif not shape.is_empty() and not shape.triangles.is_empty(): obstacles.append(shape)
	for key in objects.keys():
		if not world.desired.has(key): objects.erase(key)
	return func(from: Vector3,to: Vector3):return clear(from,to,radius,dims.y if radius_override<0 else radius_override,obstacles,creatures,pending)
static func cross(a: Vector2,b: Vector2) -> float: return a.x*b.y-a.y*b.x
static func interval(from: Vector2,to: Vector2,tri: Dictionary) -> Vector2:
	var points: Array=[Vector2(tri.a.x,tri.a.y),Vector2(tri.b.x,tri.b.y),Vector2(tri.c.x,tri.c.y)]; var area:=cross(points[1]-points[0],points[2]-points[0])
	if absf(area)<0.0000001: return Vector2(1,-1)
	var low:=0.0; var high:=1.0; var sign_value:=1.0 if area>0 else -1.0
	for i in 3:
		var edge: Vector2=points[(i+1)%3]-points[i]; var a:=sign_value*cross(edge,from-points[i]); var b:=sign_value*cross(edge,to-points[i]); var d:=b-a
		if absf(d)<0.0000001:
			if a< -0.00001: return Vector2(1,-1)
		elif d>0: low=maxf(low,-a/d)
		else: high=minf(high,-a/d)
	return Vector2(low,high)
static func point_distance(point: Vector2,a: Vector2,b: Vector2) -> float:
	var delta:=b-a; var t:=clampf((point-a).dot(delta)/delta.length_squared(),0,1) if delta.length_squared()>0 else 0.0
	return point.distance_squared_to(a+delta*t)
static func segment_distance(a: Vector2,b: Vector2,c: Vector2,d: Vector2) -> float:
	var den:=cross(b-a,d-c)
	if absf(den)>0.00000001:
		var t:=cross(c-a,d-c)/den; var u:=cross(c-a,b-a)/den
		if t>=0 and t<=1 and u>=0 and u<=1: return 0.0
	return minf(minf(point_distance(a,c,d),point_distance(b,c,d)),minf(point_distance(c,a,b),point_distance(d,a,b)))
static func hits(from: Vector2,to: Vector2,tri: Dictionary,radius: float,low: float,high: float) -> bool:
	if tri.max.z<low or tri.min.z>high: return false
	if maxf(from.x,to.x)+radius<tri.min.x or minf(from.x,to.x)-radius>tri.max.x or maxf(from.y,to.y)+radius<tri.min.y or minf(from.y,to.y)-radius>tri.max.y: return false
	var inside:=interval(from,to,tri)
	if inside.x<=inside.y and inside.y>=0 and inside.x<=1: return true
	var points: Array=[Vector2(tri.a.x,tri.a.y),Vector2(tri.b.x,tri.b.y),Vector2(tri.c.x,tri.c.y)]
	for i in 3:
		if segment_distance(from,to,points[i],points[(i+1)%3])<radius*radius: return true
	return false
func clear(from: Vector3,to: Vector3,radius: float,height: float,obstacles: Array,creatures: Array,pending: Array) -> bool:
	stats.queries+=1
	var a:=Vector2(from.x,from.y); var b:=Vector2(to.x,to.y)
	for p in pending:
		if point_distance(p,a,b)<144: return deny("pending_object",from,to)
	for creature in creatures:
		if point_distance(creature.point,a,b)<=float(creature.radius)*float(creature.radius): return deny("creature",from,to)
	var start_z: float=world.surface.height(from,from.z); var end_z: float=world.surface.height(to,from.z); var low:=minf(start_z,end_z)-0.1; var high:=maxf(start_z,end_z)+height+0.1
	var intervals: Array=[]; var definition: Dictionary=world.surface.definition
	var left:=maxi(0,floori((minf(a.x,b.x)-radius)/10)); var right:=mini(int(definition.width)-1,floori((maxf(a.x,b.x)+radius)/10))
	var bottom:=maxi(0,floori((minf(a.y,b.y)-radius)/10)); var top:=mini(int(definition.height)-1,floori((maxf(a.y,b.y)+radius)/10))
	for y in range(bottom,top+1):
		for x in range(left,right+1):
			for tri in tile(y*int(definition.width)+x):
				if tri.walk:
					var span:=interval(a,b,tri)
					if span.x<=span.y: intervals.append(span)
				elif hits(a,b,tri,radius,low,high): return deny("tile_polygon",from,to)
	intervals.sort_custom(func(x,y):return x.x<y.x); var end:=0.0
	for span in intervals:
		if span.x>end+0.00001: break
		end=maxf(end,span.y)
	if end<0.99999: return deny("floor_coverage",from,to)
	for shape in obstacles:
		if maxf(a.x,b.x)+radius<shape.min.x or minf(a.x,b.x)-radius>shape.max.x or maxf(a.y,b.y)+radius<shape.min.y or minf(a.y,b.y)-radius>shape.max.y: continue
		for tri in shape.triangles:
			if hits(a,b,tri,radius,low,high): return deny("object_polygon",from,to)
	return true
func snapshot() -> Dictionary:
	var state:=stats.duplicate(true); state.pending=requests.size(); state.ready=ready() if not closed else false; return state
func detach_prepared_data() -> Dictionary:
	var payload:={"tables":tables.duplicate(),"models":models.duplicate(),"tiles":tiles.duplicate(),"objects":objects.duplicate()}
	tables={}; models={}; tiles={}; objects={}; return payload
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(assets): assets.close()
	requests.clear(); models.clear(); objects.clear(); tiles.clear(); tables.clear(); warm_queue.clear(); world=null
func _exit_tree() -> void: close()
