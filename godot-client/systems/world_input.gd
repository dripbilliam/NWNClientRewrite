extends Node
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
const GameInput=preload("res://systems/native_data/game_input.gd")

var registry
var camera: Camera3D
var hud
var hovered := -1
var selected := -1
var tab := false
var pending_button := 0
var left_press: Dictionary={}
var pending_run:=true
var last_pick_ms := -INF
var pointer_dirty := false
var pointer_inside := false
var last_camera_transform: Transform3D
var highlight_pointer:=Vector2.ZERO
var highlight_pointer_active:=false
var highlight_dirty:=false
var highlight_last_pick_ms:=-INF
var highlight_hovered:=-1
var request_smoke := false
var smoke_result: Dictionary = {}
var smoke_locked := false
var camera_controller
var player_id_query: Callable
var include_player_query: Callable
var action: Callable
var pointer_miss: Callable
var clear_movement: Callable
var extra_pointer_block: Callable
var context_action: Callable
var cursor_action: Callable
var hover_presentation: Callable
var pending_point := Vector2.ZERO
var last_hit: Dictionary = {}
var pointer_attempts: Array[Dictionary] = []
var key_bindings
var highlight_key:=0
func set_key_bindings(value) -> void:
	if is_instance_valid(key_bindings):
		if key_bindings.changed.is_connected(clear_binding_keys): key_bindings.changed.disconnect(clear_binding_keys)
		if key_bindings.capture_changed.is_connected(binding_capture): key_bindings.capture_changed.disconnect(binding_capture)
	key_bindings=value
	if is_instance_valid(key_bindings):
		key_bindings.changed.connect(clear_binding_keys); key_bindings.capture_changed.connect(binding_capture)
	clear_binding_keys()
func clear_binding_keys() -> void: tab=false; highlight_key=0; highlight_pointer_active=false; highlight_hovered=-1
func binding_capture(active: bool) -> void:
	if active: clear_binding_keys()

func configure(value, view: Camera3D, interface) -> void:
	registry = value
	camera = view
	if registry.has_method("configure_highlights"):registry.configure_highlights(view)
	hud = interface
	get_viewport().gui_focus_changed.connect(text_focus_changed)

func text_focus_changed(control: Control) -> void:
	if GameInput.is_text_entry(control):
		clear_binding_keys()
		if registry!=null:registry.mark([], -1, false)
		if hud!=null and hud.has_method("highlight_labels"):hud.highlight_labels([], -1, false)
		if hud!=null:hud.labels([], -1)

func record_pointer_attempt(result: String, point: Vector2, hit: Dictionary = {}) -> void:
	var row := {"at_ms": Time.get_ticks_msec(), "result": result, "point": [point.x, point.y]}
	if result == "press_not_delivered" or result == "blocked":
		var control := get_viewport().gui_get_hovered_control()
		if is_instance_valid(control): row.control = str(control.get_path())
		row.focused = get_window().has_focus()
		if result == "blocked":
			row.in_viewport = get_viewport().get_visible_rect().has_point(point)
			row.hud_block = hud.blocks_pointer(point)
			row.session_block = extra_pointer_block.is_valid() and bool(extra_pointer_block.call(point))
			row.mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	elif not hit.is_empty():
		row.id = int(hit.get("id", -1))
		row.type = int(hit.get("entity", {}).get("type", -1))
	pointer_attempts.append(row)
	if pointer_attempts.size() > 16: pointer_attempts.pop_front()

func release_left_pointer(kind: String,pointer_id: int,position: Vector2,shift_pressed: bool) -> void:
	var press: Dictionary=left_press
	left_press={}
	if press.is_empty() or str(press.get("kind",""))!=kind or int(press.get("id",-1))!=pointer_id:
		record_pointer_attempt("press_not_delivered",position)
		return
	var origin: Vector2=press.position
	if origin.distance_to(position)>5.0:
		record_pointer_attempt("drag",position)
		return
	if not get_window().has_focus() or not get_viewport().get_visible_rect().has_point(position) or hud.blocks_pointer(position) or extra_pointer_block.is_valid() and bool(extra_pointer_block.call(position)):
		record_pointer_attempt("blocked",position)
		return
	pending_button=MOUSE_BUTTON_LEFT
	pending_point=position
	pending_run=not shift_pressed
	pointer_inside=true
	pointer_dirty=true

func _input(event: InputEvent) -> void:
	# Browser pointercancel drops the pending press without producing a pick.
	# Godot exposes the same cancellation bit on native mouse/touch events.
	if (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag) and event.is_canceled():
		left_press.clear()
		return
	if event is InputEventMouseMotion:
		pointer_inside=get_viewport().get_visible_rect().has_point(event.position)
		pointer_dirty=true
		highlight_pointer=event.position
		highlight_pointer_active=event.button_mask==0 and pointer_inside
		highlight_dirty=true
		if not highlight_pointer_active:highlight_hovered=-1
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
		if event.pressed:highlight_pointer_active=false;highlight_hovered=-1
		else:
			highlight_pointer=event.position
			highlight_pointer_active=get_viewport().get_visible_rect().has_point(event.position)
			highlight_dirty=true
		if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and not (event.device==InputEvent.DEVICE_ID_EMULATION and str(left_press.get("kind",""))=="touch"):
			release_left_pointer("mouse",event.device,event.position,event.shift_pressed)
		elif not event.pressed and event.button_index!=MOUSE_BUTTON_LEFT and str(left_press.get("kind",""))=="mouse":
			# The old canvas pointerup retires a pending left press on any button.
			left_press.clear()
	if event is InputEventScreenTouch and not event.pressed:
		release_left_pointer("touch",event.index,event.position,Input.is_key_pressed(KEY_SHIFT))
	# GUI text controls may consume key-up before _unhandled_input. Observe
	# release without taking the event, so holding Tab cannot leave plates on
	# after entering chat, editing a field or moving focus between controls.
	if event is InputEventKey and not event.pressed:
		if event.keycode==KEY_TAB:
			if tab:get_viewport().set_input_as_handled()
			tab=false

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag) and event.is_canceled():return
	# The old canvas focuses on every pointerdown, before the world-input gate.
	# GUI controls receive the event first; only a world-surface press reaches here.
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and get_viewport().get_visible_rect().has_point(event.position) and not hud.blocks_pointer(event.position):
		var focused: Control=get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused):focused.release_focus()
	if event is InputEventKey:
		if event.keycode == KEY_TAB and event.pressed and not event.echo and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and not GameInput.is_text_entry(get_viewport().gui_get_focus_owner()) and not (is_instance_valid(key_bindings) and key_bindings.capturing):
			tab = true
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.device==InputEvent.DEVICE_ID_EMULATION and str(left_press.get("kind",""))=="touch":return
			left_press={"kind":"mouse","id":event.device,"position":event.position}
			if clear_movement.is_valid():clear_movement.call()
		else:
			pointer_inside=get_viewport().get_visible_rect().has_point(event.position)
			pointer_dirty=true
			# The old world right-click cancels active targeting before trying to
			# pick a hit. An empty ground/sky pick must still cancel the target.
			if include_player_query.is_valid() and bool(include_player_query.call()):
				if pointer_inside and get_window().has_focus() and not hud.blocks_pointer(event.position) and not (extra_pointer_block.is_valid() and bool(extra_pointer_block.call(event.position))) and context_action.is_valid():context_action.call({},event.position)
				return
			pending_button=event.button_index
			pending_point=event.position
	if event is InputEventScreenTouch and event.pressed:
		left_press={"kind":"touch","id":event.index,"position":event.position}
		if clear_movement.is_valid():clear_movement.call()

func _physics_process(delta: float) -> void:
	var phase_began:=FrameProfile.begin()
	_pointer_step(delta)
	FrameProfile.finish("physics_pointer",phase_began)
func _highlight_step() -> void:
	var focus:=get_viewport().gui_get_focus_owner()
	if GameInput.is_text_entry(focus):clear_binding_keys();return
	if not highlight_pointer_active or not get_window().has_focus() or not get_viewport().get_visible_rect().has_point(highlight_pointer) or hud.blocks_pointer(highlight_pointer) or (extra_pointer_block.is_valid() and bool(extra_pointer_block.call(highlight_pointer))):
		highlight_hovered=-1;return
	var now_ms:=float(Time.get_ticks_msec())
	if now_ms-highlight_last_pick_ms >= (50.0 if highlight_dirty else 100.0):
		highlight_dirty=false;highlight_last_pick_ms=now_ms
		var player_id: int=int(player_id_query.call()) if player_id_query.is_valid() else -1
		var hit: Dictionary=registry.pick(camera,highlight_pointer,true,true,player_id)
		var id:=int(hit.get("id",-1))
		highlight_hovered=id if registry.entities.get(id,{}).get("eligible",false) else -1
	if highlight_hovered>=0 and not registry.entities.get(highlight_hovered,{}).get("eligible",false):highlight_hovered=-1
func _pointer_step(delta: float) -> void:
	if registry == null:
		return
	if request_smoke and smoke_result.is_empty():
		_run_smoke()
	if smoke_locked:
		return
	# The old pointer-up handler picks outside withWorldPickFrame. It may mutate
	# the world before the highlight and pointer overlays enter their new scope.
	var point := pending_point if pending_button else get_viewport().get_mouse_position()
	var blocked: bool = not pointer_inside or not get_window().has_focus() or not get_viewport().get_visible_rect().has_point(point) or hud.blocks_pointer(point) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if extra_pointer_block.is_valid():
		blocked = blocked or extra_pointer_block.call(point)
	if blocked:
		if pending_button == MOUSE_BUTTON_LEFT: record_pointer_attempt("blocked",point)
		hovered = -1
		pending_button = 0
		last_hit.clear()
	elif pending_button!=0:
		var click_button:=pending_button
		var click_player_id: int=int(player_id_query.call()) if player_id_query.is_valid() else -1
		var click_targeting:=include_player_query.is_valid() and bool(include_player_query.call())
		var click_hit: Dictionary=registry.pick(camera,pending_point,click_button==MOUSE_BUTTON_RIGHT or click_targeting,false,click_player_id)
		if click_button == MOUSE_BUTTON_LEFT:
			record_pointer_attempt("no_hit" if click_hit.is_empty() else "hit",pending_point,click_hit)
		var click_hovered:=int(click_hit.get("id",-1))
		if not registry.entities.get(click_hovered,{}).get("eligible",false):click_hovered=-1
		if click_button==MOUSE_BUTTON_LEFT and click_hit.is_empty():
			if pointer_miss.is_valid():pointer_miss.call()
		else:
			if click_button==MOUSE_BUTTON_LEFT and action.is_valid():
				click_hit.run=pending_run
				action.call(click_hit)
				selected=click_hovered
				hud.current_id=selected
		if click_button==MOUSE_BUTTON_RIGHT:
			if context_action.is_valid() and not click_hit.is_empty():context_action.call(click_hit,pending_point)
			else:hud.inspect_entity(selected)
		pending_button=0
	if registry.has_method("begin_pick_frame"):registry.begin_pick_frame()
	_highlight_step()
	# WorldPointerView updates after highlights. Its throttled hover pick is
	# independent of the click query and sees any click-time world mutation.
	if not blocked:
		if camera.global_transform!=last_camera_transform:pointer_dirty=true;last_camera_transform=camera.global_transform
		var targeting:=include_player_query.is_valid() and bool(include_player_query.call())
		var interval:=25.0 if targeting else (40.0 if pointer_dirty else 120.0)
		var now_ms:=float(Time.get_ticks_msec())
		if now_ms-last_pick_ms>=interval:
			last_pick_ms=now_ms;pointer_dirty=false
			var player_id: int=int(player_id_query.call()) if player_id_query.is_valid() else -1
			last_hit=registry.pick(camera,get_viewport().get_mouse_position(),targeting,false,player_id)
			hovered=int(last_hit.get("id",-1))
			if not registry.entities.get(hovered,{}).get("eligible",false):hovered=-1
	var selection_hover:=highlight_hovered
	if hover_presentation.is_valid():
		hover_presentation.call(last_hit,blocked)
	var ids: Array = registry.highlight_ids() if tab else ([selection_hover] if selection_hover >= 0 else [])
	registry.mark(ids,selection_hover,tab,int(player_id_query.call()) if player_id_query.is_valid() else -1)
	if hud.has_method("highlight_labels"):hud.highlight_labels(ids,selection_hover,tab)
	hud.labels(ids,selection_hover)
	if cursor_action.is_valid():
		cursor_action.call(last_hit, blocked)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered >= 0 else Input.CURSOR_ARROW)
	if registry.has_method("end_pick_frame"):registry.end_pick_frame()

func _run_smoke() -> void:
	var id := -1
	for candidate in registry.eligible_ids():
		var center: Vector3 = registry.bounds[candidate].get_center()
		if camera.is_position_behind(center):
			continue
		var point := camera.unproject_position(center)
		if not get_viewport().get_visible_rect().has_point(point):
			continue
		var hit: Dictionary = registry.pick(camera, point)
		if hit.get("id", -1) == candidate:
			id = candidate
			break
	var home := camera.global_transform
	camera_controller.orbit(Vector2(35, 12))
	camera_controller.pan(Vector2(1, 1), 0.1)
	camera_controller.zoom(0.9)
	camera_controller.reset()
	hud.toggle_panel("help")
	hud.toggle_panel("objects")
	hud.inspect_entity(id)
	registry.mark([id])
	hud.labels([id])
	smoke_result = {"picked_object": id, "camera_reset": camera.global_transform.is_equal_approx(home), "multiple_menus": hud.panels.help.visible and hud.panels.objects.visible and hud.panels.details.visible, "outside_menu_input": not hud.blocks_pointer(Vector2(get_viewport().size) - Vector2(1, 1)), "particle_materials": registry.stats.particle_materials}
	smoke_result["passed"] = id >= 0 and smoke_result.camera_reset and smoke_result.multiple_menus and smoke_result.outside_menu_input and registry.stats.particle_errors == 0 and registry.stats.missing_bindings == 0
	smoke_locked = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		highlight_pointer_active=false
		highlight_hovered=-1
		highlight_dirty=true
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		clear_binding_keys()
		left_press.clear()
		hovered = -1
		pending_button = 0
		pointer_inside=false
		if registry!=null:registry.mark([], -1, false)
		if hud!=null and hud.has_method("highlight_labels"):hud.highlight_labels([], -1, false)
		if hud!=null:hud.labels([], -1)
