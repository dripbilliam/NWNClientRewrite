extends Node
# Connection-owned access adapter; only verified5/6/7/8 owners are bound here.
const Policy=preload("res://systems/native_data/gui_panel_access.gd")
const NAMES={"pvp":5,"journal":6,"spells":7,"character":8}
const CONTEXTS={"ground":[16,-1],"trigger":[17,7],"creature":[18,5],"item":[19,6],"placeable":[20,9],"door":[21,10]}
var owner_ui
var policy:=Policy.new()
var pending: Array=[]
var effects_seen:=0
var attempt_serial:=0
var control: Dictionary={}
var diagnostics: Dictionary={}
var closed:=false
var draining:=false
func configure(ui) -> void: owner_ui=ui
func note(code: String) -> void: diagnostics[code]=mini(65535,int(diagnostics.get(code,0))+1)
func observe_header(value: Variant) -> void:
	if closed or value==null: return
	var result:=policy.observe_header(value)
	if result.is_empty(): note("invalid_header"); return
	var next: Dictionary=result.control
	if control.is_empty() or next.controlLifetime==null or control.controlLifetime==null or int(next.controlLifetime)>=int(control.controlLifetime): control=next
	retire_through(int(result.retiredThrough))
	for value_event in result.events: enqueue(value_event)
	drain()
func receive_event(value: Variant) -> void:
	if closed: return
	var normalized:=Policy.event(value)
	if normalized.is_empty(): note("invalid_event"); return
	policy.observe_event(normalized); retire_through(int(normalized.retiredThrough)); enqueue(normalized); drain()
func retire_through(sequence: int) -> void:
	if sequence>effects_seen: note("retired_effects"); effects_seen=sequence
	pending=pending.filter(func(value):return int(value.sequence)>effects_seen)
func enqueue(value: Dictionary) -> void:
	if int(value.sequence)<=effects_seen or pending.any(func(row):return int(row.sequence)==int(value.sequence)): return
	pending.append(value.duplicate(true)); pending.sort_custom(func(a,b):return int(a.sequence)<int(b.sequence))
	if pending.size()>Policy.LIMIT: effects_seen=maxi(effects_seen,int(pending.pop_front().sequence)); note("pending_overflow")
func drain() -> void:
	if closed or draining or not is_instance_valid(owner_ui) or not is_instance_valid(owner_ui.desktop): return
	draining=true
	while not closed and not pending.is_empty() and int(pending[0].sequence)==effects_seen+1:
		var value: Dictionary=pending[0]
		if value.kind=="popup":
			var readiness:=popup_readiness(value.scope)
			var node=bound(int(value.panelId))
			# A server command is consumed only when this selected owner can open.
			# Already-open owners are an idempotent no-op even during a text refresh.
			var needs_open: bool=is_instance_valid(node) and not node.wanted
			if is_instance_valid(node) and int(value.panelId)==8:
				var d=owner_ui.desktop
				var shown: Variant=d.current_sheet_target() if d.has_method("current_sheet_target") else null
				needs_open=not node.wanted or not Policy.uint(shown) or int(shown)!=owner_ui.controlled_id
			if readiness=="ready" and is_instance_valid(node) and needs_open:
				var name: String=NAMES.find_key(int(value.panelId))
				if not owner_ui.panel_ready(name): readiness="wait"
			if readiness=="wait": draining=false; return
			pending.pop_front(); effects_seen=int(value.sequence)
			if readiness!="ready": note(readiness)
			else: force_open(int(value.panelId))
		else:
			pending.pop_front(); effects_seen=int(value.sequence)
			if value.disabled: disable_close(int(value.panelId),int(value.targetId))
	draining=false
func popup_readiness(scope: Variant) -> String:
	if not scope is Dictionary or [scope.get("actorId"),scope.get("areaId"),scope.get("areaGeneration"),scope.get("controlLifetime")].has(null): return "unavailable_scope"
	var d=owner_ui.desktop
	if int(scope.areaGeneration)<owner_ui.generation: return "retired_popup"
	if int(scope.areaGeneration)>owner_ui.generation: return "wait"
	if int(scope.areaId)!=owner_ui.area_id or int(scope.actorId)!=owner_ui.controlled_id: return "retired_popup"
	if control.is_empty() or control.get("controlLifetime")==null: return "wait"
	if int(scope.controlLifetime)<int(control.controlLifetime): return "retired_popup"
	if int(scope.controlLifetime)>int(control.controlLifetime): return "wait"
	var actor: Variant=d.objects.get(d.actor_id)
	if not actor is Dictionary or actor.get("objectType")!=5 or actor.get("id")!=d.actor_id: return "wait"
	return "ready"
func bound(panel_id: int):
	var d=owner_ui.desktop
	match panel_id:
		5: return d.players
		6: return d.journal
		7: return d.book
		8: return d.sheet
	return null
func ordinary(name: String) -> bool:
	if not NAMES.has(name): return true
	if closed: return false
	if not policy.complete: note("state_gap"); return false
	var id:=int(NAMES[name]); var d=owner_ui.desktop; var node=bound(id)
	if not is_instance_valid(node): note("unavailable_owner"); return false
	var target: int=d.actor_id if id==8 else Policy.INVALID
	if not Policy.uint(target): note("unavailable_target"); return false
	if node.wanted or not policy.matches(id,target): return true
	# Each physical blocked attempt is distinct; do not dedupe by panel/lifetime.
	if d.objects.has(d.actor_id) and d.generation==owner_ui.generation and d.actor_id==owner_ui.controlled_id and d.area_id==owner_ui.area_id:
		attempt_serial+=1; d.command({"kind":"native-panel","panel":"blocked-attempt","open":true,"guiPanelId":id,"targetId":target,"accessRevision":policy.revision,"attemptSerial":attempt_serial})
	return false
func character_target(target_id: int) -> bool:
	# Original6fb330 gates the requested displayed target even when this shared
	# sheet is already wanted. Ordinary self-toggle admission remains separate.
	if closed or not policy.complete or not Policy.uint(target_id) or target_id==Policy.INVALID or not is_instance_valid(owner_ui) or not is_instance_valid(owner_ui.desktop): return false
	var d=owner_ui.desktop
	if d.get("closed")==true or d.generation!=owner_ui.generation or d.area_id!=owner_ui.area_id or d.actor_id!=owner_ui.controlled_id: return false
	var actor: Variant=d.objects.get(d.actor_id); var target: Variant=d.objects.get(target_id)
	for entry in [[actor,d.actor_id],[target,target_id]]:
		var object: Variant=entry[0]
		if not object is Dictionary or object.get("id")!=entry[1] or object.get("objectType")!=5 or object.get("areaId")!=d.area_id or object.get("replicationRemoved")==true or object.get("destroyed")==true or not Policy.integer(object.get("clientKnownLifetime"),1):
			note("unavailable_record_target"); return false
	if not is_instance_valid(d.sheet): note("unavailable_owner"); return false
	if not policy.matches(8,target_id): return true
	if attempt_serial>=Policy.MAX_SERIAL: note("attempt_exhausted"); return false
	attempt_serial+=1
	var intent:={"kind":"native-panel","panel":"blocked-attempt","open":true,"guiPanelId":8,"targetId":target_id,"accessRevision":policy.revision,"attemptSerial":attempt_serial}
	if target_id!=d.actor_id:
		intent.recordActorLifetime=int(actor.clientKnownLifetime); intent.recordTargetLifetime=int(target.clientKnownLifetime)
	d.command(intent)
	return false
func context_attempt(source_kind: String,target_id: int,nwn_position: Vector3) -> bool:
	if closed or not policy.complete or not CONTEXTS.has(source_kind) or not nwn_position.is_finite() or not is_instance_valid(owner_ui) or not is_instance_valid(owner_ui.desktop): return false
	var d=owner_ui.desktop
	if d.get("closed")==true or d.generation!=owner_ui.generation or d.area_id!=owner_ui.area_id or d.actor_id!=owner_ui.controlled_id: return false
	var actor: Variant=d.objects.get(d.actor_id)
	if not actor is Dictionary or actor.get("id")!=d.actor_id or actor.get("objectType")!=5 or actor.get("areaId")!=d.area_id or actor.get("replicationRemoved")==true or actor.get("destroyed")==true: return false
	var source: Array=CONTEXTS[source_kind]
	var context_target: Variant=null
	var scope: Array=[d.generation,d.area_id,d.actor_id]
	if source_kind=="ground":
		if target_id!=Policy.INVALID: return false
	else:
		context_target=d.objects.get(target_id)
		if not Policy.uint(target_id) or target_id==Policy.INVALID or not context_target is Dictionary or context_target.get("id")!=target_id or context_target.get("objectType")!=source[1] or context_target.get("areaId")!=d.area_id or context_target.get("replicationRemoved")==true or context_target.get("destroyed")==true: return false
	var position: Array=[nwn_position.x,nwn_position.y,nwn_position.z] if source_kind=="ground" else [0,0,0]
	var blocked:=policy.matches(int(source[0]),target_id)
	attempt_serial+=1
	d.command({"kind":"native-panel","panel":"context-attempt","open":true,"sourceKind":source_kind,"guiPanelId":int(source[0]),"targetId":target_id,"position":position,"accessRevision":policy.revision,"attemptSerial":attempt_serial})
	if blocked or closed: return false
	if d.get("closed")==true or scope!=[owner_ui.generation,owner_ui.area_id,owner_ui.controlled_id] or scope!=[d.generation,d.area_id,d.actor_id]: return false
	if not is_same(d.objects.get(d.actor_id),actor) or actor.get("areaId")!=d.area_id or actor.get("replicationRemoved")==true or actor.get("destroyed")==true: return false
	return context_target==null or is_same(d.objects.get(target_id),context_target) and context_target.get("areaId")==d.area_id and context_target.get("objectType")==source[1] and context_target.get("replicationRemoved")!=true and context_target.get("destroyed")!=true
func disable_close(panel_id: int,target: int) -> void:
	var node=bound(panel_id)
	if not is_instance_valid(node): note("unbound_close"); return
	if not node.wanted: return
	if panel_id==8 and target!=Policy.INVALID:
		var d=owner_ui.desktop
		var shown: Variant=d.current_sheet_target() if d.has_method("current_sheet_target") else null
		if not Policy.uint(shown) or int(shown)!=target: return
	match panel_id:
		5: node.close_players()
		6: node.close_journal()
		7: node.wanted=false; node.hide()
		8: node.close_sheet()
func force_open(panel_id: int) -> void:
	var node=bound(panel_id)
	if not is_instance_valid(node): note("unbound_popup"); return
	if panel_id==8:
		var d=owner_ui.desktop
		if not d.has_method("force_self_character_record") or not d.force_self_character_record(): note("unavailable_record_owner")
		return
	if not node.wanted: node.open() # No ordinary toggle, no membership mutation.
func snapshot() -> Dictionary:
	return {"policy":policy.snapshot(),"effects_seen":effects_seen,"pending":pending.duplicate(true),"control":control.duplicate(true),"diagnostics":diagnostics.duplicate(),"bound_panels":[5,6,7,8]}
func close() -> void:
	if closed: return
	closed=true; pending.clear(); control.clear(); policy=Policy.new(); owner_ui=null
func _exit_tree() -> void: close()
