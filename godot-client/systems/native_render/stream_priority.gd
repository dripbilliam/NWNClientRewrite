extends RefCounted
# Presentation priority only. Never change canonical IDs, wire order, geometry,
# collision, or the complete set of objects that will eventually be admitted.
static func sort_rows(rows: Array,origin: Vector3) -> void:
	rows.sort_custom(func(a,b):
		var da: float=origin.distance_squared_to(a.position); var db: float=origin.distance_squared_to(b.position)
		return da<db or (da==db and int(a.get("id",a.get("index",0)))<int(b.get("id",b.get("index",0)))))
static func model_order(names: Array,groups: Dictionary,origin: Vector3,tiles: Array=[]) -> Array:
	var ranked: Array=[]
	for name in names:
		var distance:=INF
		for row in groups.get(name,[]):
			var position: Vector3=tiles[int(row)].position if not tiles.is_empty() else row.position
			distance=minf(distance,origin.distance_squared_to(position))
		ranked.append({"name":name,"distance":distance})
	ranked.sort_custom(func(a,b):return a.distance<b.distance or (a.distance==b.distance and str(a.name)<str(b.name)))
	return ranked.map(func(row):return row.name)
static func request_order(requests: Dictionary,names: Array) -> Array:
	var ranks: Dictionary={}
	for index in names.size(): ranks[names[index]]=index
	var ids: Array=requests.keys()
	ids.sort_custom(func(a,b):return int(ranks.get(requests[a],2147483647))<int(ranks.get(requests[b],2147483647)))
	return ids
