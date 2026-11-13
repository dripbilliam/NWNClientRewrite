extends RefCounted
# Opt-in NWN-73 preview search on a private, plain-data collision snapshot.
# This object never reads a live Node, ObjectDB entry, scene service or mutable
# source collection. The owning collision view validates the snapshot again
# before a result can be admitted on the main thread.
const Plan=preload("res://systems/native_data/drive_preview.gd")
const Surface=preload("res://systems/native_data/tile_surface.gd")
const Collision=preload("res://systems/native_render/drive_collision_indexed.gd")
var packet: Dictionary={}
var probes: Array=[]
var missing:=false

func run() -> Dictionary:
	if packet.is_empty():return {"valid":false,"reason":"empty-packet"}
	var began:=Time.get_ticks_usec()
	var path: Dictionary=Plan.path(packet.from,packet.target,packet.render,Callable(self,"clear"))
	return {"valid":not missing,"reason":"snapshot-outside-envelope" if missing else "","path":path,"probes":probes,"worker_ms":(Time.get_ticks_usec()-began)/1000.0}

func clear(from: Vector3,to: Vector3) -> bool:
	if probes.is_empty():
		var initial: bool=bool(packet.first_clear)
		probes.append([from,to,initial,str(packet.get("first_reason","")) if not initial else ""])
		return initial
	if missing:return false
	if not Collision.preview_inside(from,packet.minimum,packet.maximum) or not Collision.preview_inside(to,packet.minimum,packet.maximum):
		missing=true;return false
	var reason:=_clear_geometry(from,to)
	var accepted:=reason.is_empty()
	probes.append([from,to,accepted,reason])
	return accepted

func _height(point: Vector3,previous: float) -> float:
	var surface: Dictionary=packet.surface
	var x:=floori(point.x/10.0);var y:=floori(point.y/10.0)
	if x<0 or y<0 or x>=int(surface.width) or y>=int(surface.height):return previous
	var tile_index:=y*int(surface.width)+x
	if not surface.tiles.has(tile_index):missing=true;return previous
	var tile: Dictionary=surface.tiles[tile_index]
	var mesh: Dictionary=surface.meshes.get(str(tile.model),{})
	if mesh.is_empty():missing=true;return previous
	var local:=Surface.canonical([Surface.f(Surface.f(point.x)-Surface.f(Surface.f(x)*10)),Surface.f(Surface.f(point.y)-Surface.f(Surface.f(y)*10))],int(tile.orientation))
	return Surface.f(Surface.height(mesh,surface.table,local)+Surface.f(tile.position.y))

func _clear_geometry(from: Vector3,to: Vector3) -> String:
	var a:=Vector2(from.x,from.y);var b:=Vector2(to.x,to.y)
	var geometry: Dictionary=packet.geometry
	for p in geometry.pending:
		if Collision.point_distance(p,a,b)<144:return "pending_object"
	for creature in geometry.creatures:
		if Collision.point_distance(creature.point,a,b)<=float(creature.radius)*float(creature.radius):return "creature"
	var start_z:=_height(from,from.z)
	var end_z:=_height(to,from.z)
	if missing:return "snapshot-outside-envelope"
	var low:=minf(start_z,end_z)-0.1;var high:=maxf(start_z,end_z)+float(packet.height)+0.1
	var intervals: Array=[];var coverage_pending: Array=[];var coverage_end:=0.0;var coverage_tracking:=true
	var floor_complete:=false;var radius: float=packet.radius;var surface: Dictionary=packet.surface
	var left:=maxi(0,floori((minf(a.x,b.x)-radius)/10));var right:=mini(int(surface.width)-1,floori((maxf(a.x,b.x)+radius)/10))
	var bottom:=maxi(0,floori((minf(a.y,b.y)-radius)/10));var top:=mini(int(surface.height)-1,floori((maxf(a.y,b.y)+radius)/10))
	for y in range(bottom,top+1):
		for x in range(left,right+1):
			var tile_index:=y*int(surface.width)+x
			if not surface.triangles.has(tile_index):missing=true;return "snapshot-outside-envelope"
			var triangle_inputs: Array=surface.triangles[tile_index]
			for tri in triangle_inputs:
				if tri.walk:
					if floor_complete:continue
					var span: Vector2=Collision.interval(a,b,tri)
					if span.x<=span.y:
						if span.y<=coverage_end:continue
						if coverage_tracking:
							if span.x<=coverage_end+0.00001:
								coverage_end=maxf(coverage_end,span.y)
								var pending_index:=0
								while pending_index<coverage_pending.size():
									var pending_span: Vector2=coverage_pending[pending_index]
									if pending_span.x<=coverage_end+0.00001:
										coverage_end=maxf(coverage_end,pending_span.y);coverage_pending.remove_at(pending_index);pending_index=0
									else:pending_index+=1
									floor_complete=coverage_end>=0.99999
							elif coverage_pending.size()<8:coverage_pending.append(span)
							else:coverage_tracking=false;coverage_pending.clear()
						if not floor_complete:intervals.append(span)
				elif Collision.hits(a,b,tri,radius,low,high):return "tile_polygon"
	var end:=1.0 if floor_complete else 0.0
	if not floor_complete:
		intervals.sort_custom(func(x,y):return x.x<y.x)
		for span in intervals:
			if span.x>end+0.00001:break
			end=maxf(end,span.y)
	if end<0.99999:return "floor_coverage"
	for shape in geometry.obstacles:
		if maxf(a.x,b.x)+radius<shape.min.x or minf(a.x,b.x)-radius>shape.max.x or maxf(a.y,b.y)+radius<shape.min.y or minf(a.y,b.y)-radius>shape.max.y:continue
		for tri in shape.triangles:
			if Collision.hits(a,b,tri,radius,low,high):return "object_polygon"
	return ""
