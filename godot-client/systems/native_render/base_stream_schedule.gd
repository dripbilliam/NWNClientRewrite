extends RefCounted
# Sparse pending-work metadata only. Canonical rows stay on World.desired.
# Receive/removal boundaries update it; refill never scans the whole registry.
var entries: Dictionary={}
var order: Array=[]
var cursor:=0
var dirty:=false
var origin:=Vector3.ZERO
var stats:={"updates":0,"removals":0,"sorts":0,"examined":0,"reserved":0,"stale":0}

func clear() -> void:
	entries.clear();order.clear();cursor=0;dirty=false

func update(id: int,key: String,position: Vector3) -> void:
	if not position.is_finite():erase(id);return
	var prior: Dictionary=entries.get(id,{})
	if not prior.is_empty() and prior.key==key and prior.position==position:return
	entries[id]={"key":key,"position":position};dirty=true;stats.updates+=1

func erase(id: int) -> void:
	if entries.erase(id):stats.removals+=1

func set_origin(value: Vector3) -> void:
	if not value.is_finite() or origin==value:return
	origin=value;dirty=true

func _prepare() -> void:
	if not dirty:return
	order=entries.keys();cursor=0;dirty=false;stats.sorts+=1
	order.sort_custom(func(a,b):
		var da: float=origin.distance_squared_to(entries[a].position)
		var db: float=origin.distance_squared_to(entries[b].position)
		return da<db or (da==db and int(a)<int(b)))

func peek(limit: int,desired: Dictionary,inflight: Dictionary,installed: Dictionary,failed: Dictionary) -> Array:
	if limit<=0:return []
	_prepare()
	var result: Array=[]
	for index in range(cursor,order.size()):
		var id: int=order[index]
		if not entries.has(id):
			if index==cursor:cursor+=1
			continue
		stats.examined+=1
		var wanted: Dictionary=desired.get(id,{})
		var key: String=entries[id].key
		if wanted.is_empty() or str(wanted.get("key",""))!=key or str(installed.get(id,""))==key or failed.has(id) and str(failed[id].get("key",""))==key:
			erase(id);stats.stale+=1
			if index==cursor:cursor+=1
			continue
		if inflight.has(id):continue
		result.append(wanted.object)
		if result.size()>=limit:break
	return result

func reserved(objects: Array,desired: Dictionary) -> void:
	for object in objects:
		var id:=int(object.id)
		if entries.has(id) and desired.has(id) and entries[id].key==str(desired[id].key):
			entries.erase(id);stats.reserved+=1

func snapshot() -> Dictionary:
	var result:=stats.duplicate()
	result.pending=entries.size();result.order_slots=order.size();result.cursor=cursor
	result.scope="World-lifetime sparse pending ID/signature/position scheduling metadata"
	return result
