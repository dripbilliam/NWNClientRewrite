extends RefCounted

const Tile=preload("res://systems/native_data/tile_surface.gd")
const NativeMath=preload("res://systems/native_data/native_math.gd")
const DriveTile=preload("res://systems/native_data/native_tile_drive_surface.gd")
const AreaCollision=preload("res://systems/native_data/native_area_collision.gd")
static func f(value: float)->float:return Vector3(value,0.0,0.0).x

static func door_mesh_bounding_box(surface: Dictionary,position: Array,orientation: Array)->Variant:
	if not surface.get("states") is Array:return {"error":"Native door mesh bounding geometry is unavailable"}
	for value in position+orientation:
		if not is_finite(float(value)):return {"error":"Native door mesh bounding geometry is unavailable"}
	var ox:=f(float(orientation[0]));var oy:=f(float(orientation[1]))
	orientation[0]=oy;orientation[1]=-ox
	var bounds: Variant=null
	for state in surface.states:
		for vertex in state.vertices:
			var x:=float(vertex[0]);var y:=float(vertex[1]);var z:=float(vertex[2])
			var point: Array=[f(f(f(oy*x)+f(-ox*y))+f(float(position[0]))),f(f(f(oy*y)-f(-ox*x))+f(float(position[1]))),f(z+f(float(position[2])))]
			if bounds==null:bounds=[point.duplicate(),point.duplicate()]
			else:
				for axis in 3:
					if float(point[axis])>float(bounds[1][axis]):bounds[1][axis]=point[axis]
					if float(bounds[0][axis])>float(point[axis]):bounds[0][axis]=point[axis]
	return {"status":1 if bounds!=null else 0,"bounds":bounds}

static func intersect_door_surface_segments(start: Array,end: Array,edge_start: Array,edge_end: Array)->Variant:
	var from: Array=[];var to: Array=[];var first: Array=[];var last: Array=[]
	for value in start:from.append(f(float(value)))
	for value in end:to.append(f(float(value)))
	for value in edge_start:first.append(f(float(value)))
	for value in edge_end:last.append(f(float(value)))
	var dx:=f(float(to[0])-float(from[0]));var dy:=f(float(to[1])-float(from[1]))
	var ex:=f(float(last[0])-float(first[0]));var ey:=f(float(last[1])-float(first[1]))
	var a:=f(sqrt(f(f(dx*dx)+f(dy*dy))));var b:=f(sqrt(f(f(ex*ex)+f(ey*ey))))
	if f(f(f(f(dx*ex)+f(ey*dy))/a)/b)==1.0:return null
	return AreaCollision.intersect_area_segments(from,to,first,last)

static func native_placement_orientation(bearing: float)->Variant:
	if not is_finite(bearing):return {"error":"Native placement bearing is unavailable"}
	var half:=f(f(bearing)*f(0.5));var sine:=NativeMath.native_sinf(half);var cosine:=NativeMath.native_cosf(half)
	var axis_x:=f(0.0*sine);var axis_y:=f(0.0*sine);var axis_z:=f(1.0*sine)
	var side:=f(f(axis_y*axis_x)-f(cosine*axis_z));var x:=f(side+side)
	var squared:=f(f(axis_z*axis_z)+f(axis_x*axis_x));var y:=f(1.0-f(squared+squared))
	var magnitude:=f(f(f(y*y)+f(x*x))+0.0)
	return [0.0,1.0,0.0] if magnitude<=f(1e-8) else Tile.normalize([x,y,0.0])

static func no_door_surface_polygons(surface: Dictionary,state: int,start: Array,end: Array,low: float,high: float,radius: float,initial_inside: Variant=[null,null,null])->Variant:
	var states: Array=surface.get("states",[])
	if state<0 or state>=states.size():return {"error":"Native door collision state is unavailable"}
	return DriveTile.no_denied_tile_polygons({"denied":states[state]},start,end,low,high,radius,0,initial_inside,false,func(a,b,c,d):return intersect_door_surface_segments(a,b,c,d),"door")
static func _door_transform(point: Array,orientation: Array,position: Array)->Array:
	var x:=f(f(float(point[0]))-float(position[0]));var y:=f(f(float(point[1]))-float(position[1]))
	return [f(f(-float(orientation[0])*y)+f(float(orientation[1])*x)),f(f(float(orientation[1])*y)-f(-float(orientation[0])*x))]
static func no_door_polygons(door: Dictionary,start: Array,end: Array,low: float,high: float,radius: float,state_globals: Dictionary,initial_inside: Variant=[null,null,null])->Variant:
	var animation:=int(door.get("nativeAnimation",-1))
	if animation not in [22,50,51]:return 1 if animation==72 else 0
	if not door.get("nativeDoorSurface") is Dictionary:return 0
	var state: Variant=state_globals.get(animation)
	if typeof(state)!=TYPE_INT or int(state)<0 or int(state)>2:return {"error":"Native door collision-state global is unavailable"}
	var raw_orientation: Array=door.get("nativeOrientation",[]);var orientation: Array=[];var position: Array=[]
	for value in raw_orientation:orientation.append(f(float(value)))
	for value in door.get("nativePosition",[]):position.append(f(float(value)))
	orientation=Tile.normalize(orientation)
	var result: Variant=no_door_surface_polygons(door.nativeDoorSurface,int(state),_door_transform(start,orientation,position),_door_transform(end,orientation,position),f(f(low)-float(position[2])),f(f(high)-float(position[2])),radius,initial_inside)
	return result if result is Dictionary else 0 if int(result)==0 else 1
