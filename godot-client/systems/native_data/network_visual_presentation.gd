extends RefCounted
# The old NetworkVisualPresentation's ordered, area-scoped event facade. The
# physical visual/model/dummy lifecycle remains with EffectWorld.

class Ticket:
	extends RefCounted
	signal completed(result: Variant)
	var done:=false
	var result: Variant=null
	func finish(value: Variant) -> void:
		if done:return
		done=true;result=value;completed.emit(value)
	func wait_done() -> Variant:
		if not done:await completed
		return result

var provider: Dictionary={}
var queue: Array=[]
var closed:=false
var draining:=false
var stats: Dictionary={"added":0,"removed":0,"instant":0}

func configure(callbacks: Dictionary) -> void:
	provider=callbacks

func _call(name: String,args: Array=[]) -> Variant:
	var callback: Variant=provider.get(name)
	return callback.callv(args) if callback is Callable and callback.is_valid() else null

func _call_async(name: String,args: Array) -> Variant:
	var callback: Variant=provider.get(name)
	if not callback is Callable or not callback.is_valid():return null
	return await callback.callv(args)

static func network_visual_identity(map: Variant) -> bool:
	if map==null or (map is bool and not map):return true
	if not map is Dictionary:return false
	if bool(map.get("legacy",false)):return false
	var entries: Array=map.get("entries",[])
	var keys: Array=map.get("keys",[])
	if entries.is_empty():return keys.is_empty()
	if entries.size()!=1 or not entries[0] is Dictionary or entries[0].get("key")!=0 or keys.size()!=1 or keys[0]!=0:return false
	var leaf: Variant=entries[0].get("value")
	if not leaf is Dictionary:return false
	if bool(leaf.get("identity",false)):return true
	var channels: Array=leaf.get("channels",[])
	if channels.size()!=10:return false
	for i in channels.size():
		var channel: Variant=channels[i]
		if not channel is Dictionary or channel.get("value")!=(1 if i in [0,1,2,9] else 0) or channel.get("duration")!=0:return false
	return true

static func _has_cessation(state: Dictionary) -> bool:
	var models: Array=state.get("models88",[])
	var statuses: Array=state.get("modelStates68",[])
	for i in models.size():
		if models[i]!=null and i<statuses.size() and (int(statuses[i])&65535)==3:return true
	return false

static func select_for_removal(entries: Array,visual_id: int) -> Variant:
	for entry in entries:
		if not entry is Dictionary or bool(entry.get("removed",false)):continue
		var record: Variant=entry.get("record")
		if not record is Dictionary or (int(record.get("visualId",0))&65535)!=(visual_id&65535):continue
		var instance: Variant=entry.get("instance")
		var state: Variant=instance.get("nativeState") if instance is Dictionary else null
		if state is Dictionary and (bool(state.get("finishedF4",false)) or _has_cessation(state)):continue
		return entry
	return null

static func record(change: Dictionary) -> Dictionary:
	var transform: Variant=change.get("visualTransform")
	if transform is Dictionary or transform is Array:transform=transform.duplicate(true)
	return {"visualId":change.get("visualId"),"sourceId":change.get("target",0x7f000000),"bodyPart":0,"transform":{"scale":1,"translate":[0,0,0],"rotate":[0,0,0]},"networkTransform":transform,"delivery":{"instant":0,"sourcePart":change.get("field8",0),"targetPart":0,"point":[0,0,0]}}

func _enqueue(kind: String,inputs: Array) -> Ticket:
	var ticket:=Ticket.new()
	if closed:ticket.finish(null);return ticket
	queue.append({"kind":kind,"inputs":inputs,"ticket":ticket})
	if not draining:call_deferred("_drain")
	return ticket

func receive(events: Array) -> Ticket:
	var inputs: Array=[]
	var area: Variant=_call("areaId")
	for event in events:
		if not event is Dictionary or str(event.get("action",""))!="visual-effects":continue
		var id:=int(event.get("id",-1))
		inputs.append({"event":event.duplicate(true),"canonical":_call("canonical",[id]),"areaId":area})
	return _enqueue("loop",inputs)

func receive_instant(message: Dictionary) -> Ticket:
	var target_id:=int(message.get("targetId",-1))
	var projected: Dictionary=message.duplicate(true)
	projected.transform={"scale":1,"translate":[0,0,0],"rotate":[0,0,0]}
	return _enqueue("instant",[{"message":projected,"canonical":_call("canonical",[target_id]),"areaId":_call("areaId"),"targetId":target_id}])

func _drain() -> void:
	if draining or closed:return
	draining=true
	while not queue.is_empty() and not closed:
		var item: Dictionary=queue.pop_front()
		if item.kind=="loop":
			for input in item.inputs:
				if closed:break
				var event: Dictionary=input.event
				var id:=int(event.get("id",-1))
				if _call("areaId")!=input.areaId or not is_same(_call("canonical",[id]),input.canonical):continue
				for change in event.get("changes",[]):
					if not change is Dictionary:continue
					var actor: Variant=_call("view",[id])
					if change.get("action")=="A":
						var added: Variant=await _call_async("loopAdd",[actor,record(change)])
						if int(added if added!=null else 0)>0:stats.added+=1
					elif change.get("action")=="D":
						var removed: Variant=_call("loopRemove",[actor,int(change.get("visualId",0))])
						if int(removed if removed!=null else 0)>0:stats.removed+=1
					else:_call("report",["network.visual-action-unhandled","Native looping visual action is unavailable",{"objectId":id,"action":change.get("action")}])
		else:
			for input in item.inputs:
				if closed or _call("areaId")!=input.areaId:continue
				if input.canonical!=null and not is_same(_call("canonical",[int(input.targetId)]),input.canonical):continue
				var delivered: Variant=await _call_async("instant",[input.message])
				if int(delivered if delivered!=null else 0)>0:stats.instant+=1
		item.ticket.finish(null)
	for item in queue:item.ticket.finish(null)
	queue.clear();draining=false

func dispose() -> void:
	closed=true
	for item in queue:item.ticket.finish(null)
	queue.clear()

func snapshot() -> Dictionary:
	return {"added":stats.added,"removed":stats.removed,"instant":stats.instant,"pending":queue.size()}
