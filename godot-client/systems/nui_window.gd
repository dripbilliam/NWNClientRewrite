extends Control
var manager
var window_id := -1
var state: Dictionary = {}
var nodes: Dictionary = {}
var staged: Dictionary = {}
var staged_state: Dictionary = {}
var title: Label
var close: Button
var collapse: Button
var header: Control
var body: Control
var resize_handle: Control
var root_element
var spawn_pointer := Vector2.ZERO
var dragging := false
var resizing := false
var drag_start := Vector2.ZERO
var start_rect := Rect2()
var header_height := 0.0
var retired := false
const Element = preload("res://systems/nui_element.gd")

func configure(owner, id: int) -> void:
	manager = owner; window_id = id; spawn_pointer = get_viewport().get_mouse_position() if is_inside_tree() else Vector2.ZERO
	clip_contents = true; mouse_filter = Control.MOUSE_FILTER_STOP
	header = Control.new(); add_child(header)
	title = Label.new(); title.clip_text = true; title.mouse_filter = Control.MOUSE_FILTER_STOP; title.gui_input.connect(func(event): begin_drag(event, false, title)); header.add_child(title)
	close = Button.new(); close.text = "×"; close.focus_mode = Control.FOCUS_NONE; close.pressed.connect(func(): request({"operation": "close"})); header.add_child(close)
	collapse = Button.new(); collapse.text = "−"; collapse.focus_mode = Control.FOCUS_NONE; collapse.pressed.connect(func(): request({"operation": "collapse", "value": not state.get("collapsed", false)})); header.add_child(collapse)
	body = Control.new(); body.clip_contents = true; body.mouse_filter = Control.MOUSE_FILTER_PASS; add_child(body)
	resize_handle = Control.new(); resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE; resize_handle.gui_input.connect(func(event): begin_drag(event, true, resize_handle)); add_child(resize_handle)
	for button in [close, collapse]:
		button.mouse_entered.connect(func(): if not retired: manager.style(button, "window_close" if button == close else "window_minimize", str(state.get("font", "(default)")), null))
		button.mouse_exited.connect(func(): if not retired: manager.style(button, "window_close" if button == close else "window_minimize", str(state.get("font", "(default)")), null))
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and state.get("acceptsInput", true): move_to_front())
	resized.connect(layout)
func request(message: Dictionary) -> void:
	if not retired: manager.request.emit({"kind": "nui-input", "windowId": window_id}.merged(message))
func accepts() -> bool: return not retired and state.get("acceptsInput", true)
func commit() -> void:
	var first := state.is_empty(); state = staged_state.duplicate(true)
	for id in nodes.keys():
		if not staged.has(id):
			var node = nodes[id]; node.retire()
			# Detach retained descendants before retiring an old parent.
			for child in node.logical_children:
				if staged.has(child.control_id) and child.get_parent() != null: child.get_parent().remove_child(child)
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.queue_free(); nodes.erase(id)
	for id in staged:
		var row: Dictionary = staged[id]
		if not nodes.has(id):
			var node := Element.new(); node.configure(manager, window_id, row); nodes[id] = node
		else: nodes[id].apply(row)
	for id in staged:
		var children: Array = []
		for child_id in staged[id].children: children.append(nodes[int(child_id)])
		nodes[id].children_changed(children)
	root_element = nodes.get(int(state.rootId))
	if root_element != null and root_element.get_parent() != body:
		if root_element.get_parent() != null: root_element.get_parent().remove_child(root_element)
		body.add_child(root_element)
	title.text = str(state.title); close.visible = bool(state.closable); collapse.visible = bool(state.collapsible); header.visible = bool(state.header); resize_handle.visible = bool(state.resizable) and not state.collapsed
	body.visible = not state.collapsed; header_height = 28.0 if state.header else 0.0
	if state.collapsed or not accepts():
		for node in nodes.values(): node.dismiss_popup()
	apply_geometry(); restyle(); manager.input_policy(self, accepts()); layout(); show()
	if first: request({"operation": "open"})
func apply_geometry() -> void:
	if dragging or resizing: return
	var g: Dictionary = state.get("geometry", {}); var viewport := get_viewport_rect().size; var constraint: Dictionary = state.get("sizeConstraint", {})
	var extent := Vector2(maxf(80, float(g.get("w", 500))), maxf(30, float(g.get("h", 400))))
	extent.x = maxf(extent.x, float(constraint.get("x", 0))); extent.y = maxf(extent.y, float(constraint.get("y", 0)))
	if float(constraint.get("w", 0)) > 0: extent.x = minf(extent.x, float(constraint.w))
	if float(constraint.get("h", 0)) > 0: extent.y = minf(extent.y, float(constraint.h))
	var at := Vector2(float(g.get("x", -1)), float(g.get("y", -1)))
	for axis in 2:
		if at[axis] == -2: at[axis] = spawn_pointer[axis]
		elif at[axis] == -3: at[axis] = spawn_pointer[axis] - extent[axis] / 2
		elif at[axis] < 0: at[axis] = (viewport[axis] - extent[axis]) / 2
		else: at[axis] = minf(at[axis], viewport[axis] - 20)
	var edges: Dictionary = state.get("edgeConstraint", {})
	if not edges.is_empty(): at = at.max(Vector2(float(edges.get("x", 0)), float(edges.get("y", 0)))).min(viewport - Vector2(float(edges.get("w", 20)) if float(edges.get("w", 0)) > 0 else 20.0, float(edges.get("h", 20)) if float(edges.get("h", 0)) > 0 else 20.0))
	position = at.max(Vector2.ZERO); size = Vector2(extent.x, maxf(28, header_height) if state.get("collapsed", false) else extent.y)
func restyle() -> void:
	manager.style(title, "window_title", str(state.get("font", "(default)")), null)
	manager.style(close, "window_close", str(state.get("font", "(default)")), null); manager.style(collapse, "window_minimize", str(state.get("font", "(default)")), null)
	for node in nodes.values():
		if node.widget != null: manager.style(node.widget, node.kind, str(node.values.get("font", "(default)")), node.values.get("foreground_color"))
		for button in node.option_buttons: manager.style(button, "option" if node.kind == "options" else "button_select", str(node.values.get("font", "(default)")), node.values.get("foreground_color"))
		if node.scroll != null: manager.theming.scrollbar(node.scroll.get_v_scroll_bar(), true); manager.theming.scrollbar(node.scroll.get_h_scroll_bar(), false)
		node.background.queue_redraw(); node.foreground.queue_redraw()
		if node.image_canvas != null: node.image_canvas.queue_redraw()
	queue_redraw()
func layout() -> void:
	if body == null: return
	header.size = Vector2(size.x, header_height); title.position = Vector2(8, 0); title.size = Vector2(maxf(0, size.x - 68), header_height)
	close.position = Vector2(size.x - 26, 2); close.size = Vector2(24, 24); collapse.position = Vector2(size.x - 52, 2); collapse.size = Vector2(24, 24)
	body.position = Vector2(0, header_height); body.size = Vector2(size.x, maxf(0, size.y - header_height))
	if root_element != null: root_element.position = Vector2.ZERO; root_element.size = body.size; root_element.layout()
	resize_handle.position = size - Vector2(12, 12); resize_handle.size = Vector2(12, 12)
	queue_redraw()
func begin_drag(event: InputEvent, resize: bool, source: Control) -> void:
	if not accepts(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = not resize; resizing = resize; drag_start = source.get_global_transform() * event.position; start_rect = get_global_rect(); move_to_front(); accept_event()
func _input(event: InputEvent) -> void:
	if retired or not dragging and not resizing: return
	if event is InputEventMouseMotion:
		var delta: Vector2 = event.global_position - drag_start
		if dragging: position = (start_rect.position + delta).max(Vector2.ZERO)
		else: size = (start_rect.size + delta).max(Vector2(80, 40))
		layout()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var was_resize := resizing; dragging = false; resizing = false; request({"operation": "geometry", "resize": was_resize, "geometry": {"x": position.x, "y": position.y, "w": size.x, "h": float(state.get("geometry", {}).get("h", size.y)) if state.get("collapsed", false) else size.y}})
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: dragging = false; resizing = false
func _draw() -> void:
	if state.is_empty(): return
	if not state.get("transparent", false): draw_rect(Rect2(Vector2.ZERO, size), manager.skin_color("window", "fixed_background", Color.BLACK))
	if state.get("border", true): draw_style_box(manager.box("window", "border_image", Color.TRANSPARENT), Rect2(Vector2.ZERO, size))
	if state.get("header", false): draw_style_box(manager.box("window.header", "normal", Color.BLACK), Rect2(Vector2.ZERO, Vector2(size.x, header_height)))
	if resize_handle.visible:
		draw_line(size - Vector2(3, 10), size - Vector2(10, 3), Color(0.68, 0.56, 0.38)); draw_line(size - Vector2(3, 6), size - Vector2(6, 3), Color(0.68, 0.56, 0.38))
func retire() -> void:
	retired = true
	for node in nodes.values(): node.retire()
	nodes.clear(); staged.clear(); state.clear(); hide(); queue_free()
