extends SceneTree
const Access=preload("res://systems/native_data/native_network_gui_access.gd")
var failures: Array=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func source_event(value: Dictionary)->Dictionary:
	if value.kind=="disabled":return {"kind":"gui-panel-disabled","panelId":int(value.panelId),"disabled":bool(value.disabled),"targetId":int(value.targetId),"targetSource":str(value.targetSource)}
	return {"kind":"gui-panel-popup","panelId":int(value.panelId)}
func comparable(value: Variant)->Variant:
	if value is Dictionary:
		var result: Dictionary={}
		for key in value:result[key]=comparable(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item in value:result.append(comparable(item))
		return result
	if value is int or value is float:return float(value)
	return value
func same(actual: Variant,expected: Variant)->bool:return comparable(actual)==comparable(expected)
func run()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_gui_panel_state_oracle.json"))
	if not fixture is Dictionary or not fixture.get("events") is Array or fixture.events.size()!=100:
		printerr("NWN79 GUI panel canonical JS oracle unavailable");quit(1);return
	var state=Access.State.new()
	var actor: Dictionary=fixture.actor;var replacement: Dictionary=fixture.replacement
	var context:={"actor":actor,"actorId":int(actor.id),"areaId":int(actor.areaId),"areaGeneration":1}
	var first_input: Dictionary={}
	for index in fixture.events.size():
		if index==11:context={"actor":replacement,"actorId":int(replacement.id),"areaId":int(replacement.areaId),"areaGeneration":2}
		var expected: Dictionary=fixture.events[index]
		var message: Dictionary=source_event(expected)
		if index==0:first_input=message
		var admitted: Dictionary=state.observe(message)
		check(admitted.get("accepted",false) and int(admitted.get("sequence",0))==index+1,"canonical-sequence-"+str(index))
		var event: Dictionary=state.bind_event(message,context)
		check(same(event,expected),"canonical-bound-event-"+str(index))
		if index==3:check(same(state.snapshot(context),fixture.seed),"original-JS-seed-header")
		if index==12:check(same(state.snapshot(context),fixture.next),"original-JS-area-replacement-header")
		if index==13:
			context.actor=replacement.duplicate(true)
			check(same(state.snapshot(context),fixture.reused),"original-JS-same-ID-new-actor-lifetime")
	check(same(state.snapshot(context),fixture.flood),"original-JS-32-event-journal-retirement")
	check(state.bind_event(first_input,context).is_empty(),"older-input-cannot-rebind-latest-event")
	check(state.matches(8,0x7f000000) and state.matches(8,0xffffffce) and state.matches(8,1) and not state.matches(9,1),"original-default-target-blocks-all-valid-targets")
	var detached: Dictionary=state.snapshot(context);detached.events.clear();detached.disabled.clear()
	check(not state.snapshot(context).events.is_empty() and not state.snapshot(context).disabled.is_empty(),"header-copies-cannot-mutate-state")
	var prior: int=int(state.sequence)
	check(not state.observe({"kind":"gui-panel-popup","panelId":23}).get("accepted",false) and state.sequence==prior,"unsupported-panel-does-not-advance-order")
	check(not state.observe({"kind":"gui-panel-disabled","panelId":6,"disabled":true,"targetId":0,"targetSource":"legacy_protocol_default"}).get("accepted",false) and state.sequence==prior,"invalid-default-target-does-not-advance-order")
	state.reset()
	check(state.snapshot({}).revision==0 and state.snapshot({}).events.is_empty() and not state.matches(8,0x7f000000),"connection-reset-retires-membership-and-journal")
	var physical=Access.State.new()
	var received_actor: Dictionary={"id":77,"objectType":5,"areaId":9,"nativeLifetime":12,"clientKnownLifetime":12,"replicated":{"appearance":1}}
	var received_context: Dictionary={"actor":received_actor,"actorId":77,"areaId":9,"areaGeneration":4}
	var original_control: Dictionary=physical.snapshot(received_context).control
	check(original_control.controlLifetime==1,"physical-actor-first-lifetime")
	var popup_message: Dictionary={"kind":"gui-panel-popup","panelId":6}
	check(physical.observe(popup_message).get("accepted",false),"physical-popup-admitted")
	var bound: Dictionary=physical.bind_event(popup_message,received_context)
	check(bound.scope==original_control,"physical-popup-binds-actor-lifetime")
	received_context.actor=received_actor.duplicate(true)
	received_context.actor.replicated.appearance=2
	check(physical.snapshot(received_context).control==original_control and physical.snapshot(received_context).events[-1].scope==original_control,"ordinary-deep-copy-update-preserves-popup-scope")
	received_context.actor.nativeLifetime=13
	received_context.actor.clientKnownLifetime=13
	var replaced_control: Dictionary=physical.snapshot(received_context).control
	check(replaced_control.controlLifetime==2 and physical.snapshot(received_context).events[-1].scope==original_control,"same-ID-physical-replacement-retires-old-popup-scope")
	received_context.actor=received_context.actor.duplicate(true)
	check(physical.snapshot(received_context).control==replaced_control,"replacement-deep-copy-update-is-stable")
	received_context.actor=null
	check(physical.snapshot(received_context).control.controlLifetime==null,"missing-physical-actor-has-no-control-scope")
	if failures.is_empty():print("NWN79 GUI panel canonical state PASS checks=",checks," original_js_events=100")
	else:printerr("NWN79 GUI panel canonical state FAIL ",JSON.stringify(failures.slice(0,12)))
	quit(0 if failures.is_empty() else 1)
