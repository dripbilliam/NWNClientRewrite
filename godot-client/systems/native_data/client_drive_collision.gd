extends RefCounted

# Client 7e6a20/7e7210/767740. Providers are supplied by the scene's
# resolver-owned geometry, just as in the original client.
const INVALID:=0x7f000000
static func f(value: float)->float:return Vector3(value,0.0,0.0).x
static func slot(value: float)->int:
	for index in 32:
		if f(float(index*10))<=value and value<f(float((index+1)*10)):return index
	return -1
static func cvtt(value: float)->int:
	return int(value) if value>=-2147483648.0 and value<2147483648.0 else -2147483648
static func _next(state: Dictionary,providers: Dictionary)->Variant:
	var ids: Array=state.get("ids",[])
	if ids.is_empty():return null
	state.cursor=(int(state.get("cursor",-1))+1)%ids.size()
	return providers.object.call(ids[int(state.cursor)])

static func client_drive_line(area: Dictionary,start: Array,end: Array,radius: float,height: float,actor_id: int,check_creatures: int,providers: Dictionary)->Variant:
	for value in start+end+[radius,height]:
		if not is_finite(float(value)):return {"error":"Native client drive line is unavailable"}
	var from: Array=[f(float(start[0])),f(float(start[1])),f(float(start[2]))]
	var to: Array=[f(float(end[0])),f(float(end[1])),f(float(end[2]))]
	radius=f(radius);height=f(height)
	var x:=slot(float(from[0]));var y:=slot(float(from[1]))
	var dx:=1 if float(from[0])<=float(to[0]) else -1
	var dy:=1 if float(from[1])<=float(to[1]) else -1
	var visited: Dictionary={}
	var epsilon:=f(0.0001);var edge:=f(9.9999)
	while true:
		var key:=str(x)+":"+str(y)
		if visited.has(key):return {"error":"Native client tile traversal made no progress"}
		visited[key]=true
		var tile: Variant=await providers.tile.call(area,x,y)
		if tile is Dictionary and tile.has("error"):return tile
		if tile==null:return 0
		var clipped: Dictionary=await providers.clippedWalkable.call(tile,from,to)
		if clipped.has("error"):return clipped
		if int(clipped.get("status",0))!=1:return 0
		var low:=f(float(clipped.minHeight)-f(0.1))
		var high:=f(float(clipped.maxHeight)+f(height+f(0.1)))
		var tile_result: Variant=await providers.noNonWalkTile.call(tile,clipped.entry,clipped.exit,low,high,radius,0)
		if tile_result is Dictionary:return tile_result
		if int(tile_result)!=1:return 0
		var world_result: Variant=await providers.noNonWalkWorld.call(clipped.entry,clipped.exit,low,high,radius,INVALID)
		if world_result is Dictionary:return world_result
		if int(world_result)!=1:return 0
		if check_creatures!=0:
			var creature_result: Variant=await providers.noCreatures.call(clipped.entry,clipped.exit,actor_id,radius)
			if creature_result is Dictionary:return creature_result
			if int(creature_result)!=1:return 0
		var ex:=float(clipped.exit[0]);var ey:=float(clipped.exit[1])
		if not (ex<f(float(to[0])-epsilon) or f(float(to[0])+epsilon)<ex or ey<f(float(to[1])-epsilon) or f(float(to[1])+epsilon)<ey):break
		var local_x:=f(ex-f(float(x*10)));var local_y:=f(ey-f(float(y*10)))
		if (local_x>=edge if dx==1 else local_x<=epsilon):x+=dx
		if (local_y>=edge if dy==1 else local_y<=epsilon):y+=dy
	var extension: Array=[f(float(to[0])+f(float(dx)*radius)),f(float(to[1])+f(float(dx)*radius)),0]
	var scale:=f(0.1)
	if cvtt(f(float(to[0])*scale))!=cvtt(f(float(extension[0])*scale)) or cvtt(f(float(to[1])*scale))!=cvtt(f(float(extension[1])*scale)):
		var extension_result: Variant=await providers.extensionWalkable.call(to,extension,radius)
		if extension_result is Dictionary:return extension_result
		return 0 if int(extension_result)==0 else 1
	return 1

static func client_drive_edge(area: Dictionary,start: Array,end: Array,providers: Dictionary)->Variant:
	var from: Array=[f(float(start[0])),f(float(start[1])),f(float(start[2]))]
	var to: Array=[f(float(end[0])),f(float(end[1])),f(float(end[2]))]
	var x:=slot(float(from[0]));var y:=slot(float(from[1]))
	var dx:=1 if float(from[0])<=float(to[0]) else -1
	var dy:=1 if float(from[1])<=float(to[1]) else -1
	var visited: Dictionary={}
	var epsilon:=f(0.0001);var edge:=f(9.9999)
	while true:
		var key:=str(x)+":"+str(y)
		if visited.has(key):return {"error":"Native client edge traversal made no progress"}
		visited[key]=true
		var tile: Variant=await providers.tile.call(area,x,y)
		if tile is Dictionary and tile.has("error"):return tile
		if tile==null:return 0
		var clipped: Dictionary=await providers.clippedWalkable.call(tile,from,to)
		if clipped.has("error"):return clipped
		if int(clipped.get("status",0))!=1:return 0
		var ex:=float(clipped.exit[0]);var ey:=float(clipped.exit[1])
		if not (ex<f(float(to[0])-epsilon) or f(float(to[0])+epsilon)<ex or ey<f(float(to[1])-epsilon) or f(float(to[1])+epsilon)<ey):return 1
		var local_x:=f(ex-f(float(x*10)));var local_y:=f(ey-f(float(y*10)))
		if (local_x>=edge if dx==1 else local_x<=epsilon):x+=dx
		if (local_y>=edge if dy==1 else local_y<=epsilon):y+=dy
	return {"error":"Native client edge traversal stopped unexpectedly"}

static func client_creature_line(state: Dictionary,start: Array,end: Array,radius: float,ignored_id: int,providers: Dictionary)->Variant:
	var x1:=f(float(start[0]));var y1:=f(float(start[1]))
	var x2:=f(float(end[0]));var y2:=f(float(end[1]));radius=f(radius)
	if not [x1,y1,x2,y2,radius].all(func(value):return is_finite(value)):return {"error":"Native client creature line is unavailable"}
	if x1==x2 and y1==y2:return 1
	var owner: Variant=providers.owner.call(ignored_id) if providers.get("owner") is Callable else null
	if owner is Dictionary and (int(owner.get("field3b0_110",0))==1 and int(owner.get("field3b0_114",0))==0 or int(owner.get("id",-1))==int(providers.get("controlledId",-1)) and int(providers.get("controlFlag",0))==1):return 1
	var dx:=f(x2-x1);var min_x:=minf(x1,x2);var max_x:=maxf(x1,x2);var min_y:=minf(y1,y2);var max_y:=maxf(y1,y2)
	var slope:=0.0 if dx==0 else f(f(y2-y1)/dx)
	var constant:=0.0 if dx==0 else f(y1-f(slope*x1))
	var normal_scale:=0.0 if dx==0 else f(sqrt(f(1.0/f(f(slope*slope)+1.0))))
	var first: Variant=_next(state,providers)
	if first==null:return 1
	var object: Variant=first
	for _index in state.ids.size():
		if object is Dictionary and int(object.get("id",-1))!=ignored_id and int(object.get("objectType",0))==5:
			var cx:=f(float(object.position[0]));var cy:=f(float(object.position[1]))
			var combined:=f(radius+f(float(providers.radius.call(object))))
			var clear:=true
			if dx==0 and cy>min_y and cy<max_y:clear=cx<f(max_x-combined) or f(combined+max_x)<cx
			elif dx==0:
				var endpoint: Array=[min_x,min_y] if cy<=min_y else [max_x,max_y]
				var ox:=f(cx-f(float(endpoint[0])));var oy:=f(cy-f(float(endpoint[1])))
				clear=combined<f(sqrt(f(f(ox*ox)+f(oy*oy))))
			else:
				var line_y:=f(f(cx*slope)+constant);var perpendicular:=f(absf(f(cy-line_y))*normal_scale)
				if perpendicular<combined:
					var sign:=-1 if cy<line_y else 1
					var projected_x:=f(f(f(f(float(sign)*perpendicular)*slope)*normal_scale)+cx)
					if min_x<=projected_x and projected_x<=max_x:return 0
				var ox:=f(cx-x2);var oy:=f(cy-y2)
				clear=combined<f(sqrt(f(f(ox*ox)+f(oy*oy))))
			if not clear:return 0
		object=_next(state,providers)
	return 1
