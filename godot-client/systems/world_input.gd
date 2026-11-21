extends Node
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")

var registry
var camera: Camera3D
var hud
var hovered := -1
var selected := -1
var tab := false
var pending_button := 0
var since_pick := 0.0
var request_smoke := false
var smoke_result: Dictionary = {}
var smoke_locked := false
var camera_controller
var action: Callable
var extra_pointer_block: Callable
var context_action: Callable
var cursor_action: Callable
var hover_presentation: Callable
var pending_point := Vector2.ZERO
var last_hit: Dictionary = {}
var key_bindings
var highlight_key:=0
func set_key_bindings(value) -> void:
	if is_instance_valid(key_bindings):
		if key_bindings.changed.is_connected(clear_binding_keys): key_bindings.changed.disconnect(clear_binding_keys)
		if key_bindings.capture_changed.is_connected(binding_capture): key_bindings.capture_changed.disconnect(binding_capture)
		if key_bindings.highlight_changed.is_connected(highlight_changed): key_bindings.highlight_changed.disconnect(highlight_changed)
	key_bindings=value
	if is_instance_valid(key_bindings):
		key_bindings.changed.connect(clear_binding_keys); key_bindings.capture_changed.connect(binding_capture); key_bindings.highlight_changed.connect(highlight_changed)
	clear_binding_keys()
	if is_instance_valid(key_bindings): highlight_changed(key_bindings.highlighted)
func highlight_changed(enabled: bool) -> void: tab=enabled
func clear_binding_keys() -> void: tab=false; highlight_key=0
func binding_capture(active: bool) -> void:
	if active: clear_binding_keys()

func configure(value, view: Camera3D, interface) -> void:
	registry = value
	camera = view
	if registry.has_method("configure_highlights"):registry.configure_highlights(view)
	hud = interface
	get_viewport().gui_focus_changed.connect(text_focus_changed)

func text_focus_changed(control: Control) -> void:
	if control is LineEdit or control is TextEdit: clear_binding_keys()

func _input(event: InputEvent) -> void:
	# GUI text controls may consume key-up before _unhandled_input. Observe
	# release without taking the event, so holding Tab cannot leave plates on
	# after entering chat, editing a field or moving focus between controls.
	if event is InputEventKey and not event.pressed:
		if not is_instance_valid(key_bindings) and event.keycode==KEY_TAB: clear_binding_keys()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if not is_instance_valid(key_bindings) and event.keycode == KEY_TAB and not event.echo:
			tab = event.pressed
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		pending_button = event.button_index
		pending_point = event.position
		since_pick = 1.0

func _physics_process(delta: float) -> void:
	var phase_began:=FrameProfile.begin()
	_pointer_step(delta)
	FrameProfile.finish("physics_pointer",phase_began)
func _pointer_step(delta: float) -> void:
	if registry == null:
		return
	if request_smoke and smoke_result.is_empty():
		_run_smoke()
	if smoke_locked:
		return
	since_pick += delta
	var point := pending_point if pending_button else get_viewport().get_mouse_position()
	var blocked: bool = hud.blocks_pointer(point) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if extra_pointer_block.is_valid():
		blocked = blocked or extra_pointer_block.call(point)
	if blocked:
		hovered = -1
		pending_button = 0
		last_hit.clear()
	elif since_pick >= 0.05:
		since_pick = 0.0
		var hit: Dictionary = registry.pick(camera, pending_point if pending_button else point)
		last_hit = hit
		hovered = int(hit.get("id", -1))
		if not registry.entities.get(hovered, {}).get("eligible", false):
			hovered = -1
		if pending_button != 0:
			if pending_button == MOUSE_BUTTON_LEFT and action.is_valid() and not hit.is_empty():
				action.call(hit)
			selected = hovered
			hud.current_id = selected
			if pending_button == MOUSE_BUTTON_RIGHT:
				if context_action.is_valid() and not hit.is_empty():
					context_action.call(hit, pending_point)
				else:
					hud.inspect_entity(selected)
			pending_button = 0
	var selection_hover:=hovered
	if hover_presentation.is_valid():
		var presentation: Variant=hover_presentation.call(last_hit,blocked)
		if presentation is Dictionary and presentation.get("suppress_hover",false):selection_hover=-1
	var ids: Array = registry.eligible_ids() if tab else ([selection_hover] if selection_hover >= 0 else [])
	registry.mark(ids,selection_hover,tab)
	hud.labels(ids,selection_hover)
	if cursor_action.is_valid():
		cursor_action.call(last_hit, blocked)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered >= 0 else Input.CURSOR_ARROW)

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
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		clear_binding_keys()
		hovered = -1
		pending_button = 0
