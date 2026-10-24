extends VBoxContainer
const Model = preload("res://systems/creation_model.gd")
const MAX_BYTES := 64 * 1024 * 1024
signal retry_requested
var surface: SubViewportContainer
var viewport: SubViewport
var pivot: Node3D
var camera: Camera3D
var auto_rotate: CheckBox
var message: Label
var model
var active := false
var failed := false
var preview_id := -1
var buffers: Dictionary = {}
var pending_parts: Dictionary = {}
var expected: Dictionary = {}
var base_distance := 4.0
var zoom := 1.0
var installs := 0
var retired := 0
var old_models: Array = []
var last: Dictionary = {}
var base64_pattern := RegEx.new()

func _ready() -> void:
	custom_minimum_size.x = 300; size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new(); title.text = "Appearance preview"; add_child(title)
	surface = SubViewportContainer.new(); surface.custom_minimum_size = Vector2(280, 360); surface.size_flags_vertical = Control.SIZE_EXPAND_FILL; surface.stretch = true; add_child(surface); surface.gui_input.connect(_surface_input)
	viewport = SubViewport.new(); viewport.size = Vector2i(300, 400); viewport.own_world_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE; viewport.msaa_3d = Viewport.MSAA_2X; surface.add_child(viewport)
	var world := Node3D.new(); viewport.add_child(world)
	var environment := WorldEnvironment.new(); var settings := Environment.new(); settings.background_mode = Environment.BG_COLOR; settings.background_color = Color("080d12"); settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_color = Color.WHITE; settings.ambient_light_energy = 0.7; environment.environment = settings; world.add_child(environment)
	var light := DirectionalLight3D.new(); light.light_energy = 1.5; light.rotation_degrees = Vector3(-25, -150, 0); world.add_child(light)
	pivot = Node3D.new(); world.add_child(pivot)
	camera = Camera3D.new(); camera.fov = 35; camera.near = 0.01; camera.far = 1000; camera.current = true; world.add_child(camera); _camera()
	var hint := Label.new(); hint.text = "Drag to rotate · Wheel to zoom"; hint.add_theme_font_size_override("font_size", 13); add_child(hint)
	auto_rotate = CheckBox.new(); auto_rotate.text = "Rotate automatically"; auto_rotate.button_pressed = true; auto_rotate.focus_mode = Control.FOCUS_NONE; add_child(auto_rotate)
	var buttons := HBoxContainer.new(); add_child(buttons)
	for definition in [["Reset view", reset_view], ["Retry", func(): retry_requested.emit()]]:
		var button := Button.new(); button.text = definition[0]; button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(definition[1]); buttons.add_child(button)
	message = Label.new(); message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; message.custom_minimum_size.x = 280; add_child(message)
	base64_pattern.compile("^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$")
	hide()

func set_active(value: bool) -> void:
	active = value; visible = value
	if not value: reset()

func release_model() -> void:
	if is_instance_valid(model):
		old_models = old_models.filter(func(reference): return is_instance_valid(reference.get_ref()))
		old_models.append(weakref(model)); model.retire(); retired += 1
	model = null

func reset() -> void:
	release_model(); buffers.clear(); pending_parts.clear(); expected.clear(); preview_id = -1; failed = false; last.clear()
	if is_instance_valid(message): message.text = ""

func fail(reason: String) -> void:
	failed = true; release_model(); buffers.clear(); pending_parts.clear(); message.text = reason
	last = {"previewId":preview_id,"state":"failed","reason":reason}

func _camera() -> void:
	camera.position = Vector3(0, 0, -base_distance * zoom); camera.look_at(Vector3.ZERO, Vector3.UP)

func reset_view() -> void:
	pivot.rotation = Vector3.ZERO; zoom = 1; auto_rotate.button_pressed = true; _camera()

func _surface_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		pivot.rotation.y += event.relative.x * 0.012; auto_rotate.button_pressed = false; surface.accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom = clampf(zoom * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.4, 2.5); _camera(); surface.accept_event()

func _process(delta: float) -> void:
	if active and is_instance_valid(model) and auto_rotate.button_pressed: pivot.rotation.y += delta * 0.35

func receive(packet: Dictionary) -> void:
	var id := int(packet.get("previewId", -1))
	if not active: return
	if packet.kind == "creation-preview-stop":
		if id >= preview_id: reset()
		return
	if packet.kind == "creation-preview-loading":
		if id <= preview_id: return
		release_model(); buffers.clear(); pending_parts.clear(); preview_id = id; failed = false; expected = packet.get("appearance", {}).duplicate(true); message.text = "Preparing appearance…"; return
	if id != preview_id or id < 0 or failed: return
	if packet.kind == "creation-preview-error": fail(str(packet.text)); return
	var part := str(packet.get("part", ""))
	if packet.kind == "creation-preview-begin":
		var count := int(packet.get("bytes", 0))
		if part not in ["manifest", "glb"] or count < 1 or count > MAX_BYTES or str(packet.get("sha256", "")).length() != 64 or buffers.has(part) or pending_parts.has(part): fail("Invalid appearance transfer metadata"); return
		var buffer := StreamPeerBuffer.new(); buffer.resize(count); pending_parts[part] = {"buffer":buffer,"bytes":count,"sha256":str(packet.sha256),"received":0,"chunks":0}
	elif packet.kind == "creation-preview-chunk":
		if not pending_parts.has(part): return
		var transfer: Dictionary = pending_parts[part]; var encoded := str(packet.get("data", ""))
		if int(packet.get("index", -1)) != int(transfer.chunks) or encoded.length() < 4 or encoded.length() > 174768 or base64_pattern.search(encoded) == null: fail("Invalid appearance transfer chunk"); return
		var bytes := Marshalls.base64_to_raw(encoded)
		if bytes.is_empty() or bytes.size() > 131072 or int(transfer.received) + bytes.size() > int(transfer.bytes): fail("Appearance chunk exceeds its owner"); return
		if transfer.buffer.put_data(bytes) != OK: fail("Appearance transfer failed"); return
		transfer.received += bytes.size(); transfer.chunks += 1
	elif packet.kind == "creation-preview-part":
		if not pending_parts.has(part): return
		var transfer: Dictionary = pending_parts[part]
		if int(transfer.received) != int(transfer.bytes) or int(packet.get("chunks", -1)) != int(transfer.chunks): fail("Appearance transfer is incomplete"); return
		var bytes: PackedByteArray = transfer.buffer.data_array
		if _digest(bytes) != transfer.sha256: fail("Appearance transfer checksum failed"); return
		buffers[part] = bytes; pending_parts.erase(part)
	elif packet.kind == "creation-preview-ready":
		if buffers.size() != 2 or not pending_parts.is_empty(): fail("Appearance model is incomplete"); return
		var metadata = JSON.parse_string(buffers.manifest.get_string_from_utf8())
		if not metadata is Dictionary or int(metadata.get("bytes", 0)) != buffers.glb.size() or str(metadata.get("sha256", "")) != _digest(buffers.glb) or metadata.get("creationAppearance", {}) != expected: fail("Appearance model does not match the current choice"); return
		var next := Model.new(); pivot.add_child(next)
		if not next.prepare_bytes(buffers.glb, metadata):
			var reason: String = next.error; next.retire(); fail(reason); return
		release_model(); model = next; installs += 1
		var minimum := _vec(metadata.bounds.min); var maximum := _vec(metadata.bounds.max); var extent := maximum - minimum
		model.position = -(maximum + minimum) * 0.5; base_distance = maxf(0.5, maxf(extent.y * 1.8, extent.x * 2.5)); _camera()
		last = {"previewId":id,"state":"ready","appearance":expected.duplicate(true),"resources":metadata.modelResources,"counts":metadata.counts,"rigs":metadata.rigs.counts,"glbSha256":metadata.sha256}
		buffers.clear(); pending_parts.clear(); message.text = ""

func _digest(bytes: PackedByteArray) -> String:
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(bytes); return digest.finish().hex_encode()

func _vec(value: Array) -> Vector3: return Vector3(float(value[0]), float(value[1]), float(value[2]))

func snapshot() -> Dictionary:
	var alive := 0
	for reference in old_models:
		if is_instance_valid(reference.get_ref()): alive += 1
	return {"previewId":preview_id,"installed":is_instance_valid(model),"installs":installs,"retired":retired,"retiredAlive":alive,"pendingParts":pending_parts.size(),"bufferParts":buffers.size(),"rotation":pivot.rotation.y,"zoom":zoom,"last":last.duplicate(true)}

func animation_sample() -> Dictionary:
	if not is_instance_valid(model): return {}
	if DisplayServer.get_name() != "headless": return model.rigs.diagnostic_sample([0])
	# Dummy rendering has no registered GPU skeleton to bake. Keep its pose/clock
	# evidence distinct; actual skin readback belongs to the rendered test.
	var sample := {"nodes":{},"clocks":{},"skins":{}}
	var entry: Dictionary = model.rigs.entities[0]
	for index in entry.nodes.size(): sample.nodes["0:" + str(index)] = entry.nodes[index].transform
	for index in entry.models.size():
		var player = entry.models[index].player
		if player != null and player.is_playing(): sample.clocks["0:" + str(index)] = {"clip":entry.models[index].clip,"time":player.current_animation_position}
	return sample

func _exit_tree() -> void: reset()
