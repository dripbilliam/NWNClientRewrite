extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Original keyboard scheduling plus native local preview. Canonical server
# objects are never changed; preview geometry is supplied by the live world.
const Driver=preload("res://systems/keyboard_drive.gd")
const Motion=preload("res://systems/network_motion.gd")
var context_query: Callable
var transmit: Callable
var predict: Callable
var end_prediction: Callable
var held: Dictionary={}
var walking:=false
var owner_identity:=""
var moving:=false
var last_flags:=0
var last_sent:=-INF
var preview_at:=-INF
var input_pending:=false
var request_serial:=0
var accepted_serial:=-1
var minimum_serial:=0
var require_focus:=true
var key_bindings
var physical_held: Dictionary={}
var walk_forward_held: Dictionary={}
func set_key_bindings(value) -> void:
	if is_instance_valid(key_bindings):
		if key_bindings.changed.is_connected(binding_changed): key_bindings.changed.disconnect(binding_changed)
		if key_bindings.capture_changed.is_connected(binding_capture): key_bindings.capture_changed.disconnect(binding_capture)
	key_bindings=value
	if is_instance_valid(key_bindings): key_bindings.changed.connect(binding_changed); key_bindings.capture_changed.connect(binding_capture)
	stop()
func binding_changed() -> void: stop()
func binding_capture(active: bool) -> void:
	if active: stop()
var stats:={"drive":0,"stop":0,"turn":0,"stale_scopes":0,"previews":0,"preview_ticks":0,"acks":0,"stale_acks":0}
func context() -> Dictionary:
	return context_query.call() if context_query.is_valid() else {}
func enabled() -> bool:
	var focus:=get_viewport().gui_get_focus_owner()
	return (not is_instance_valid(key_bindings) or not key_bindings.blocked()) and (not require_focus or get_window().has_focus()) and not (focus is LineEdit or focus is TextEdit)
func stop(send_stop: bool=true) -> void:
	var current:=context()
	if not current.is_empty() and str(current.identity)==owner_identity and end_prediction.is_valid(): end_prediction.call(current.id)
	if moving and send_stop and not current.is_empty() and str(current.identity)==owner_identity:
		request(current,{"operation":"stop"}); stats.stop+=1
	held.clear(); physical_held.clear(); walk_forward_held.clear(); walking=false; moving=false; last_flags=0; last_sent=-INF; preview_at=-INF; input_pending=false; owner_identity=""; accepted_serial=-1
func request(current: Dictionary,value: Dictionary) -> void:
	value.merge({"kind":"drive","actorId":current.id})
	request_serial+=1; value.requestId=request_serial; value.lifetime=int(current.state.get("lifetime",0))
	if transmit.is_valid(): transmit.call(value)
func key(code: int,pressed: bool,modifiers: bool=false) -> bool:
	if code==KEY_SHIFT:
		walking=pressed; update_input(); return false
	if code not in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_Q,KEY_E,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: return false
	if not pressed:
		if not held.has(code): return false
		held.erase(code); update_input(); return true
	if modifiers or context().is_empty() or not enabled(): return false
	var focus:=get_viewport().gui_get_focus_owner()
	if code in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT] and (focus is BaseButton or focus is Range or focus is ItemList or focus is Tree or focus is TabBar): return false
	held[code]=true; input_pending=true; update_input()
	return true
func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	if is_instance_valid(key_bindings):
		if mapped_input(event): get_viewport().set_input_as_handled()
		return
	var code:=int(event.physical_keycode) if event.physical_keycode!=0 else int(event.keycode)
	if event.pressed and code!=KEY_SHIFT: walking=event.shift_pressed
	if key(code,event.pressed,event.ctrl_pressed or event.alt_pressed or event.meta_pressed): get_viewport().set_input_as_handled()
func mapped_input(event: InputEventKey) -> bool:
	var code: int=key_bindings.physical(event)
	if not event.pressed and physical_held.has(code):
		physical_held.erase(code); walk_forward_held.erase(code); held.clear()
		for canonical in physical_held.values(): held[int(canonical)]=true
		walking=event.shift_pressed; update_input(); return true
	if key_bindings.blocked() or not enabled(): return false
	walking=event.shift_pressed
	if code==KEY_SHIFT: update_input(); return false
	if not event.pressed or context().is_empty(): return false
	var action: int=key_bindings.action(event,[87,88,89,90,91,92,93],true)
	var canonical: int={87:KEY_Q,88:KEY_E,89:KEY_W,90:KEY_W,91:KEY_S,92:KEY_A,93:KEY_D}.get(action,0)
	if canonical==0: return false
	var focus:=get_viewport().gui_get_focus_owner()
	if code in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT] and (focus is BaseButton or focus is Range or focus is ItemList or focus is Tree or focus is TabBar): return false
	physical_held[code]=canonical; held[canonical]=true
	if action==89: walk_forward_held[code]=true
	input_pending=true; update_input(); return true
func update_input(now_ms: float=-1) -> void:
	var current:=context()
	if current.is_empty() or not enabled(): stop(); return
	if not owner_identity.is_empty() and owner_identity!=str(current.identity): stats.stale_scopes+=1; stop(false); return
	if owner_identity.is_empty(): minimum_serial=request_serial+1
	owner_identity=str(current.identity)
	var flags:=Driver.flags(held,walking or not walk_forward_held.is_empty())
	if flags==0:
		var keys:=held.duplicate(); var walk:=walking
		var physical_keys:=physical_held.duplicate(); var walk_keys:=walk_forward_held.duplicate()
		stop(); held=keys; walking=walk; physical_held=physical_keys; walk_forward_held=walk_keys; return
	var now:=Time.get_ticks_usec()/1000.0 if now_ms<0 else now_ms
	var turn_only:=(flags&15)==0
	var changed:=input_pending or flags!=last_flags
	var send_due:=changed or now-last_sent>=(250 if turn_only else 500)
	var preview_due:=changed or send_due or now-preview_at>=250
	if not preview_due: return
	var state: Dictionary=current.state; var forward: Vector3=state.orientation
	if send_due: last_sent=now
	if turn_only:
		if send_due:
			if moving: request(current,{"operation":"stop"}); stats.stop+=1
			moving=false
			var turned:=preload("res://systems/native_data/drive_preview.gd").turn(forward,flags)
			request(current,{"operation":"turn","position":[turned.x,turned.y]}); stats.turn+=1
			if predict.is_valid(): predict.call(int(current.id),flags,-1)
	else:
		var heading:=int(round(fposmod(atan2(forward.y,forward.x)*180.0/PI,360)*10))%3600
		var position: Vector3=state.position
		request(current,{"operation":"drive","position":[position.x,position.y],"heading":heading,"flags":flags,"transmit":send_due})
		if send_due: stats.drive+=1
		stats.preview_ticks+=1; moving=true
		if predict.is_valid():
			var result: Dictionary=predict.call(int(current.id),flags,heading if send_due else -1)
			if not result.is_empty():
				stats.previews+=1
				if result.has("resendFraction"): last_sent=now-(500000-int(Motion.f(float(result.resendFraction))*500000))/1000.0
	last_flags=flags; input_pending=false
	preview_at=now
func result(message: Dictionary) -> void:
	var current:=context()
	if current.is_empty() or not moving or owner_identity!=str(current.identity) or int(message.get("actorId",-1))!=int(current.id) or int(message.get("lifetime",-1))!=int(current.state.get("lifetime",0)) or int(message.get("requestId",-1))<maxi(accepted_serial,minimum_serial):
		stats.stale_acks+=1; return
	if message.has("sequence"):
		current.state.driveSequence=int(message.sequence); accepted_serial=int(message.requestId); stats.acks+=1
		# Preview-only requests reserve the original local sequence as well. They
		# cannot change which sequence the server actually received on the wire.
		if message.get("sent") is bool and message.sent:
			current.state.driveSentSequence=int(message.sequence)
			current.state.driveSentRequestId=int(message.requestId)
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_keyboard",began)
func _profile_process(_delta: float) -> void: update_input()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: stop()
