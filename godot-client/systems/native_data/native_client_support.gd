extends RefCounted
# Client FUN_1407ff030 controller in NWN coordinates. The providers retain their
# own scene, tile, transform and lifetime authority; this owns no world store.
# The current caller supplies immutable numeric snapshots, never live Nodes.
# Integration remains disabled until the native/controller + scene gates pass.
static func f(value: float) -> float:
	return Vector3(value,0,0).x

static func unavailable(candidate: Vector3,previous: float,reason: String) -> Dictionary:
	return {"available":false,"reason":reason,"position":Vector3(candidate.x,candidate.y,previous)}

static func completed(point: Vector3,normal: Vector3,branch: String,rays: int,tiles: int) -> Dictionary:
	return {"available":true,"position":point,"normal":normal,"branch":branch,"rays":rays,"tiles":tiles}

static func tile_probe(point: Vector3,provider: Callable) -> Dictionary:
	var result: Variant=provider.call(point)
	if result is bool: return {"available":true,"present":result}
	if result is Dictionary and result.get("available") is bool and not result.available:
		return {"available":false,"reason":str(result.get("reason","Tile provider unavailable"))}
	return {"available":false,"reason":"Malformed client support tile result"}

static func ray_pair(point: Vector3,low: float,high: float,provider: Callable) -> Dictionary:
	var rays:=0
	for window: Vector2 in [Vector2(high,low),Vector2(90.0,-9.0)]:
		rays+=1
		var result: Variant=provider.call(Vector3(point.x,point.y,window.x),Vector3(point.x,point.y,window.y))
		if not result is Dictionary or not result.get("available") is bool:
			return {"available":false,"reason":"Malformed client support ray result","rays":rays}
		if not result.available: return {"available":false,"reason":str(result.get("reason","Scene provider unavailable")),"rays":rays}
		if not result.get("hit") is bool: return {"available":false,"reason":"Malformed client support hit result","rays":rays}
		if not result.hit: continue
		if not result.get("position") is Vector3 or not result.position.is_finite() or not result.get("normal") is Vector3 or not result.normal.is_finite():
			return {"available":false,"reason":"Malformed client support hit geometry","rays":rays}
		return {"available":true,"hit":true,"height":result.position.z,"normal":result.normal,"rays":rays}
	return {"available":true,"hit":false,"rays":rays}

static func project(candidate: Vector3,previous: float,providers: Dictionary) -> Dictionary:
	# Unknown/unready provider state is distinct from a known native null
	# area/scene or missing tile. Only an executed native branch produces Z9.
	if not candidate.is_finite() or not is_finite(previous): return unavailable(candidate,previous,"Nonfinite client support input")
	if not providers.get("available") is bool or not providers.available:
		return unavailable(candidate,previous,str(providers.get("reason","Client support binding unavailable")))
	if not providers.get("area_present") is bool: return unavailable(candidate,previous,"Unknown client area state")
	var point:=Vector3(candidate.x,candidate.y,9.0)
	var normal:=Vector3(0,0,1)
	if not providers.area_present: return completed(point,normal,"missing_area",0,0)
	if not providers.get("scene_present") is bool or not providers.get("tile") is Callable or not providers.tile.is_valid():
		return unavailable(candidate,previous,"Unknown client scene/tile state")
	var tile: Dictionary=tile_probe(point,providers.tile)
	if not tile.available: return unavailable(candidate,previous,tile.reason)
	if not providers.scene_present: return completed(point,normal,"missing_scene",0,1)
	if not tile.present: return completed(point,normal,"missing_tile",0,1)
	if not providers.get("trace") is Callable or not providers.trace.is_valid(): return unavailable(candidate,previous,"Client support scene trace unavailable")
	# The native parameter is float, while a GDScript float is double. Narrow
	# at the ABI boundary before the two native scalar operations.
	var reference:=f(previous)
	var low:=f(reference-f(1.0)); var high:=f(reference+f(1.0))
	var selected: Dictionary=ray_pair(point,low,high,providers.trace)
	var rays:=int(selected.rays)
	if not selected.available: return unavailable(candidate,previous,selected.reason)
	if selected.hit:
		point.z=selected.height
		return completed(point,selected.normal,"original",rays,1)
	# These are ordered f32 writes/restores, not an epsilon added to polygon
	# predicates. Restoring a seam probe can change the original XY's last bit.
	point.y=f(point.y-f(0.0001)); point.x=f(point.x-f(0.001))
	tile=tile_probe(point,providers.tile)
	if not tile.available: return unavailable(candidate,previous,tile.reason)
	selected={"available":true,"hit":false,"rays":0}
	if tile.present:
		selected=ray_pair(point,low,high,providers.trace); rays+=int(selected.rays)
		if not selected.available: return unavailable(candidate,previous,selected.reason)
		if selected.hit: point.z=selected.height; normal=selected.normal
	point.x=f(point.x+f(0.001)); point.y=f(point.y+f(0.0001))
	if selected.hit: return completed(point,normal,"negative_seam",rays,2)
	point.y=f(point.y+f(0.001)); point.x=f(point.x+f(0.0001))
	tile=tile_probe(point,providers.tile)
	if not tile.available: return unavailable(candidate,previous,tile.reason)
	selected={"available":true,"hit":false,"rays":0}
	if tile.present:
		selected=ray_pair(point,low,high,providers.trace); rays+=int(selected.rays)
		if not selected.available: return unavailable(candidate,previous,selected.reason)
		if selected.hit: point.z=selected.height; normal=selected.normal
	point.x=f(point.x-f(0.0001)); point.y=f(point.y-f(0.001))
	return completed(point,normal,"positive_seam" if selected.hit else "no_hit",rays,3)
