extends RefCounted
# Ordered scene delivery after accepted World imports. Session/DirectWorld own
# the adapter Callables; this helper retains no model or canonical world row.
const MAX:=9007199254740991
class Ticket extends RefCounted:
	signal finished(result: Variant)
	var done:=false
	var result: Variant=null
	func complete(value: Variant)->void:
		if done:return
		done=true;result=value;finished.emit(value)

var scene: WeakRef
var providers: Dictionary={}
var queue: Array=[]
var pending:=0
var closed:=false
var draining:=false
var error: String=""

func _init(given_scene: Object,callbacks: Dictionary)->void:
	if given_scene==null or not is_instance_valid(given_scene):error="Scene owner is unavailable";return
	for key in ["areaId","canonical","row","sceneClosed","requestSync","receiveMovementChanges","receiveAnimationChanges","receiveVisualChanges","receiveObjectVisual","receiveProjectile","receiveAreaVisual","report"]:
		var callback: Variant=callbacks.get(key)
		if not callback is Callable or not callback.is_valid():error="Scene callback is unavailable: "+key;return
	scene=weakref(given_scene);providers=callbacks.duplicate()

func _call(name: String,args: Array=[])->Variant:return providers[name].callv(args)
func _area()->Variant:return _call("areaId")
func _scene_closed()->bool:
	return closed or scene==null or scene.get_ref()==null or bool(_call("sceneClosed"))
func _valid_area(area: Variant)->bool:return not _scene_closed() and _area()==area
func _capture_actors(ids: Array)->Dictionary:
	var actors: Dictionary={}
	for id in ids:
		if id==null or actors.has(id):continue
		actors[id]=_call("canonical",[id])
	return actors
func _current(id: Variant,actors: Dictionary,area: Variant)->bool:
	if not actors.has(id):return true
	var original: Variant=actors[id]
	var now: Variant=_call("canonical",[id])
	if now!=original:return false
	if original==null:return true
	var row: Variant=_call("row",[id])
	return row is Dictionary and not bool(row.get("replicationRemoved",false)) and row.get("areaId")==area

func enqueue(kind: String,payload: Variant,ids: Array=[])->Ticket:
	var ticket:=Ticket.new()
	if not error.is_empty() or _scene_closed():ticket.complete(null);return ticket
	var area: Variant=_area()
	var actors:=_capture_actors(ids)
	pending+=1
	queue.append({"kind":kind,"payload":payload,"area":area,"actors":actors,"ticket":ticket})
	if not draining:call_deferred("_drain")
	return ticket

func _reported(result: Variant,code: String="network.scene-delivery-failed")->void:
	if not result is Dictionary or not result.has("error") or _scene_closed():return
	_call("report",[code,str(result.error)])
func _drain()->void:
	if draining:return
	draining=true
	while not queue.is_empty():
		var work: Dictionary=queue.pop_front()
		var result: Variant=null
		if _valid_area(work.area):
			result=await providers["requestSync"].call()
			_reported(result,"network.scene-sync-failed")
			if _valid_area(work.area) and not (result is Dictionary and result.has("error")):
				match work.kind:
					"updates":
						var live: Array=[]
						for event in work.payload:
							if _current(event.get("id"),work.actors,work.area):live.append(event)
						_call("receiveAnimationChanges",[live])
						result=await providers["receiveVisualChanges"].call(live)
					"objectVisual":
						var visual_source: Variant=work.payload.get("sourceId") if work.payload.get("nativeSourceIdentity")!=null else null
						if _current(work.payload.get("targetId"),work.actors,work.area) and _current(visual_source,work.actors,work.area):result=await providers["receiveObjectVisual"].call(work.payload)
					"projectile":
						var projectile_header: Dictionary=work.payload.get("header",{})
						var projectile_source: Variant=projectile_header.get("sourceId") if int(work.payload.get("sourceLifetime",0))>0 else null
						if _current(projectile_source,work.actors,work.area) and _current(projectile_header.get("targetId"),work.actors,work.area):result=await providers["receiveProjectile"].call(work.payload)
					"areaVisual":result=await providers["receiveAreaVisual"].call(work.payload)
				_reported(result)
		pending-=1
		work.ticket.complete(result)
	draining=false

func _finish_movement(ticket: Ticket,events: Array)->void:
	# Start this helper before scene synchronization, then retain its result
	# in an explicit ticket across the helper's await boundary.
	var result: Variant=await providers["receiveMovementChanges"].call(events)
	ticket.complete(result)
func _movement_ticket(events: Array)->Ticket:
	var ticket:=Ticket.new()
	_finish_movement(ticket,events)
	return ticket

func updates(events: Array)->Variant:
	# Movement starts immediately, before queued scene synchronization.
	var motion_ticket:=_movement_ticket(events)
	var captured: Array=[]
	for event in events:
		if event is Dictionary and event.get("action") in ["attack-animation","cast-animation","cast-state","visual-effects"]:captured.append(event.duplicate(true))
	if captured.is_empty():
		var sync_result: Variant=await providers["requestSync"].call()
		_reported(sync_result,"network.scene-sync-failed")
		var motion_result: Variant=motion_ticket.result
		if not motion_ticket.done:motion_result=await motion_ticket.finished
		return [motion_result,sync_result]
	var ids: Array=[]
	for event in captured:ids.append(event.get("id"))
	var ticket:=enqueue("updates",captured,ids)
	# Promise.all in the original updates owner settles only after this ordered
	# animation/visual delivery. An immediately retired ticket has no future
	# signal, so read its stored result before awaiting completion.
	var delivered: Variant=ticket.result
	if not ticket.done:delivered=await ticket.finished
	var motion_result: Variant=motion_ticket.result
	if not motion_ticket.done:motion_result=await motion_ticket.finished
	return [motion_result,delivered]
func object_visual(message: Dictionary)->Ticket:
	var source_id: Variant=message.get("sourceId") if message.get("nativeSourceIdentity")!=null else null
	return enqueue("objectVisual",message.duplicate(true),[message.get("targetId"),source_id])
func projectile(header: Dictionary)->Ticket:
	var source_id: Variant=header.get("header",{}).get("sourceId") if int(header.get("sourceLifetime",0))>0 else null
	var target_id: Variant=header.get("header",{}).get("targetId")
	return enqueue("projectile",header.duplicate(true),[source_id,target_id])
func area_visual(message: Dictionary)->Ticket:return enqueue("areaVisual",message.duplicate(true))
func dispose()->void:closed=true
