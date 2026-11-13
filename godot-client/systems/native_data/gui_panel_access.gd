extends RefCounted
# Original6f7870 policy. Missing scalar context is unavailable, never zero.
const INVALID:=2130706432
const LIMIT:=32
const MAX_SERIAL:=9007199254740991
var revision:=0
var complete:=true
var disabled: Dictionary={}
static func integer(value: Variant,minimum: int=0,maximum: int=MAX_SERIAL) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=minimum and value<=maximum
static func uint(value: Variant) -> bool: return integer(value,0,4294967295)
static func panel(value: Variant) -> bool: return integer(value,0,22)
static func event(value: Variant,floor_value: int=0) -> Dictionary:
	if not value is Dictionary or not panel(value.get("panelId")) or not integer(value.get("sequence"),1): return {}
	var retired: Variant=value.get("retiredThrough",floor_value)
	if not integer(retired) or retired>=value.sequence: return {}
	var result:={"kind":value.get("kind"),"panelId":int(value.panelId),"sequence":int(value.sequence),"retiredThrough":int(retired)}
	if result.kind=="disabled":
		if not value.get("disabled") is bool or not uint(value.get("targetId")) or value.get("targetSource") not in ["received","legacy_protocol_default"]: return {}
		if value.targetSource=="legacy_protocol_default" and int(value.targetId)!=INVALID: return {}
		result.merge({"disabled":value.disabled,"targetId":int(value.targetId),"targetSource":value.targetSource})
	elif result.kind=="popup":
		var scope: Variant=value.get("scope")
		if scope!=null:
			if not scope is Dictionary or scope.get("source")!="client_receive_context": return {}
			var copy:={"source":"client_receive_context"}
			for key in ["actorId","areaId","areaGeneration","controlLifetime"]:
				var scalar: Variant=scope.get(key)
				if scalar!=null and not integer(scalar,1 if key=="controlLifetime" else 0,4294967295 if key in ["actorId","areaId"] else MAX_SERIAL): return {}
				copy[key]=null if scalar==null else int(scalar)
			scope=copy
		result.scope=scope
	else: return {}
	return result
func observe_event(value: Dictionary) -> void:
	if int(value.sequence)<=revision: return
	if int(value.sequence)!=revision+1: complete=false
	revision=int(value.sequence)
	if value.kind=="disabled": _membership(value)
func _membership(value: Dictionary) -> void:
	var id:=int(value.panelId); var target:=int(value.targetId)
	if value.disabled:
		if not disabled.has(id): disabled[id]={}
		disabled[id][target]=str(value.targetSource)
	elif disabled.has(id):
		disabled[id].erase(target)
		if disabled[id].is_empty(): disabled.erase(id)
func observe_header(value: Variant) -> Dictionary:
	if not value is Dictionary or not integer(value.get("revision")) or not integer(value.get("retiredThrough")) or value.retiredThrough>value.revision or not value.get("disabled") is Array or not value.get("events") is Array or value.events.size()>LIMIT: return {}
	var next: Dictionary={}; var events: Array=[]
	for entry in value.disabled:
		if not entry is Dictionary or not panel(entry.get("panelId")) or not uint(entry.get("targetId")) or entry.get("targetSource") not in ["received","legacy_protocol_default"]: return {}
		if entry.targetSource=="legacy_protocol_default" and int(entry.targetId)!=INVALID: return {}
		if not next.has(int(entry.panelId)): next[int(entry.panelId)]={}
		next[int(entry.panelId)][int(entry.targetId)]=str(entry.targetSource)
	for source in value.events:
		var normalized:=event(source,int(value.retiredThrough))
		if normalized.is_empty() or int(normalized.sequence)>value.revision: return {}
		events.append(normalized)
	var control: Variant=event({"kind":"popup","panelId":6,"sequence":1,"scope":value.get("control")}).get("scope")
	if not value.get("control") is Dictionary or control==null: return {}
	if int(value.revision)>=revision: revision=int(value.revision); disabled=next; complete=true
	return {"events":events,"retiredThrough":int(value.retiredThrough),"control":control}
func matches(panel_id: int,target: int) -> bool:
	return complete and disabled.has(panel_id) and (disabled[panel_id].has(target) or disabled[panel_id].has(INVALID))
static func original_gate(panel_id: int,target: int,members: Array,context: Dictionary) -> Dictionary:
	if panel_id<0 or panel_id>22: return {"available":true,"blocked":false}
	if not context.get("bypass") is bool: return {"available":false}
	if context.bypass or (not members.has(target) and not members.has(INVALID)): return {"available":true,"blocked":false}
	var blocked:=false
	if panel_id in [2,4,5,6,7,8]:
		if not context.get("ownerPresent") is bool: return {"available":false}
		if panel_id in [5,6,7,8]: blocked=not context.ownerPresent
		elif context.ownerPresent:
			if not context.get("visible") is bool: return {"available":false}
			blocked=not context.visible
			if panel_id==4:
				if not context.get("containerMode") is bool: return {"available":false}
				blocked=blocked and not context.containerMode
	elif panel_id>=9: blocked=true
	return {"available":true,"blocked":blocked}
func snapshot() -> Dictionary: return {"revision":revision,"complete":complete,"disabled":disabled.duplicate(true)}
