extends Node
signal request(message: Dictionary)
const WindowPanel = preload("res://systems/nui_window.gd")
var theming = preload("res://systems/nui_theme.gd").new()
var json_packets = preload("res://systems/nui_packets.gd").new()
var overlay: CanvasLayer
var windows: Dictionary = {}
var resources: Dictionary = {}
var transfers: Dictionary = {}
var skin: Dictionary = {}
var fonts: Dictionary = {}
var images: Dictionary = {}
var boxes: Dictionary = {}
var resources_dirty := false
var retired_windows: Array = []
var retired_resources: Array = []
var statistics := {"frames": 0, "nodes": 0, "resources": 0, "failed": 0, "largest_list": 0}
func setup(parent: CanvasLayer) -> void: overlay = parent; theming.owner = self
func skin_ready() -> bool:
	if skin.is_empty() or resources_dirty: return false
	for id in images.values():
		if not resources.get(int(id)) is Texture2D: return false
	for row in fonts.values():
		if not resources.get(int(row.get("resourceId", -1))) is FontFile: return false
	return true
func reset() -> void:
	json_packets.reset()
	if not windows.is_empty(): retired_windows = windows.values().map(func(value): return weakref(value))
	if not resources.is_empty(): retired_resources = (resources.values() + theming.derived.values()).map(func(value): return weakref(value))
	for window in windows.values(): window.retire()
	windows.clear(); resources.clear(); transfers.clear(); skin.clear(); fonts.clear(); images.clear(); boxes.clear(); theming.invalidate(); resources_dirty = false
func retired_state() -> Dictionary:
	return {"windows": retired_windows.filter(func(value): return value.get_ref() != null).size(), "resources": retired_resources.filter(func(value): return value.get_ref() != null).size()}
func accepts(id: int) -> bool: return windows.has(id) and windows[id].accepts()
func blocks_pointer(point: Vector2) -> bool:
	for window in windows.values():
		if not window.visible or not window.accepts(): continue
		if window.get_global_rect().has_point(point): return true
		for node in window.nodes.values():
			if node.popup_blocks_pointer(point): return true
	return false
func receive(message: Dictionary) -> void:
	if str(message.get("kind", "")).begins_with("nui-json-"):
		var decoded: Variant = json_packets.receive(message)
		if not json_packets.failure.is_empty(): fail(json_packets.failure)
		elif decoded != null: receive(decoded)
		return
	match message.kind:
		"nui-notice":
			var window = windows.get(int(message.windowId))
			if window != null: window.tooltip_text = str(message.text)
		"nui-remove":
			var id := int(message.windowId)
			if windows.has(id): windows[id].retire(); windows.erase(id)
		"nui-frame":
			var id := int(message.windowId)
			if not windows.has(id):
				var window := WindowPanel.new(); overlay.add_child(window); window.configure(self, id); windows[id] = window
			windows[id].staged_state = message.duplicate(true); windows[id].staged.clear()
		"nui-nodes":
			var window = windows.get(int(message.windowId))
			if window != null and int(window.staged_state.version) == int(message.version):
				for row in message.nodes: window.staged[int(row.controlId)] = row
		"nui-commit":
			var window = windows.get(int(message.windowId))
			if window != null and int(window.staged_state.version) == int(message.version): window.commit(); statistics.frames += 1; statistics.nodes = windows.values().reduce(func(n, w): return n + w.nodes.size(), 0)
		"nui-skin":
			skin = message.tables.duplicate(true); images = message.images.duplicate()
			for row in message.fonts: fonts[str(row.name)] = row.duplicate()
			resources_dirty = true
		"nui-resource-begin":
			if int(message.bytes) < 0 or int(message.bytes) > 32 * 1024 * 1024 or int(message.parts) > 1000: fail("Invalid NUI resource size"); return
			transfers[int(message.transferId)] = {"message": message.duplicate(true), "parts": [], "bytes": 0}
		"nui-resource-part":
			var transfer = transfers.get(int(message.transferId))
			if transfer == null or int(message.part) != transfer.parts.size() or str(message.data).length() > 48000: fail("Out-of-order NUI resource part"); return
			transfer.parts.append(str(message.data))
		"nui-resource-end": finish_resource(int(message.transferId))
func finish_resource(id: int) -> void:
	var transfer = transfers.get(id); transfers.erase(id)
	if transfer == null: fail("Unknown NUI resource transfer"); return
	var row: Dictionary = transfer.message
	if transfer.parts.size() != int(row.parts): fail("Truncated NUI resource transfer"); return
	var bytes := Marshalls.base64_to_raw("".join(transfer.parts))
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	if bytes.size() != int(row.bytes) or hash.finish().hex_encode() != str(row.sha256): fail("NUI resource digest mismatch"); return
	if row.meta.type == "font":
		var font := FontFile.new(); font.data = bytes; resources[int(row.resourceId)] = font
	else:
		var image := Image.new()
		if image.load_png_from_buffer(bytes) != OK or image.get_width() > 4096 or image.get_height() > 4096: fail("Invalid NUI texture"); return
		resources[int(row.resourceId)] = ImageTexture.create_from_image(image)
	statistics.resources += 1; resources_dirty = true
func fail(reason: String) -> void:
	statistics.failed += 1; push_error(reason)
func _process(_delta: float) -> void:
	if resources_dirty:
		resources_dirty = false; boxes.clear(); theming.invalidate()
		for window in windows.values(): window.restyle(); window.layout()
func font_for(name: String) -> Font:
	var row: Dictionary = fonts.get(name, fonts.get("(default)", {})); var font = resources.get(int(row.get("resourceId", -1)))
	return font if font is Font else ThemeDB.fallback_font
func font_size(name: String) -> int: return maxi(1, int(fonts.get(name, fonts.get("(default)", {})).get("font_size", 17)))
func skin_color(table: String, key: String, fallback: Color) -> Color:
	var value = skin.get(table, {}).get(key)
	return Color.html(value) if value is String and value.begins_with("#") else fallback
func box(table: String, key: String, fallback: Color) -> StyleBox:
	var cache_key := table + "/" + key + "/" + fallback.to_html()
	if boxes.has(cache_key): return boxes[cache_key]
	var value = skin.get(table, {}).get(key); var texture = resources.get(int(images.get(str(value), -1)))
	var result: StyleBox
	if texture is Texture2D:
		var image := StyleBoxTexture.new(); image.texture = texture; result = image
	else:
		var flat := StyleBoxFlat.new(); flat.bg_color = skin_color(table, key, fallback); result = flat
	result.set_content_margin_all(0); boxes[cache_key] = result; return result
func style(control: Control, kind: String, font_name: String, foreground: Variant) -> void:
	theming.style(control, kind, font_name, foreground)
func input_policy(node: Node, enabled: bool) -> void:
	if node is Control:
		if not node.has_meta("nui_mouse_filter"): node.set_meta("nui_mouse_filter", node.mouse_filter)
		node.mouse_filter = int(node.get_meta("nui_mouse_filter")) if enabled else Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): input_policy(child, enabled)
