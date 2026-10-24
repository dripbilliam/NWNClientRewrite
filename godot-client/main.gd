extends Node3D

const EntityRegistry = preload("res://systems/entity_registry.gd")
const CameraController = preload("res://systems/camera_controller.gd")
const NativeHud = preload("res://systems/native_hud.gd")
const WorldInput = preload("res://systems/world_input.gd")

var report: Dictionary = {"engine": Engine.get_version_info(), "scope": "Native engine scene-import milestone; no full-game fidelity or FPS acceptance", "accepted": false}
var frame_times: Array[float] = []
var label: Label
var report_path := ""
var remaining_frames := 0
var warmup := 120
var warmup_until := 0
var previous_tick := 0
var camera: Camera3D
var registry
var native_hud
var camera_controller
var world_input
var systems_smoke := false
var local_bridge
var room_owner: Node
var environment_owner: Node

func _ready() -> void:
	label = Label.new()
	label.position = Vector2(16, 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	var scene_path := ""
	var local_ticket := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.substr(8)
		elif arg.begins_with("--report="):
			report_path = arg.substr(9)
		elif arg.begins_with("--frames="):
			remaining_frames = int(arg.substr(9))
		elif arg == "--systems-smoke":
			systems_smoke = true
		elif arg.begins_with("--local-ticket="):
			local_ticket = arg.substr(15)
	if not local_ticket.is_empty():
		local_bridge = preload("res://systems/local_connection.gd").new()
		add_child(local_bridge)
		local_bridge.configure(self, local_ticket)
		label.hide()
		return
	if scene_path.is_empty():
		label.text = "Native Godot prototype ready.\nPass --scene=<external room.glb> to load the captured room.\nNo server connections are made."
		return
	if not report_path.is_empty() and (FileAccess.file_exists(report_path) or FileAccess.file_exists(report_path.get_basename() + ".png")):
		push_error("Refusing to overwrite an existing engine report")
		get_tree().quit(1)
		return
	load_room(scene_path)

func clear_room() -> void:
	camera = null
	for owned in [world_input, camera_controller, native_hud, registry, room_owner, environment_owner]:
		if is_instance_valid(owned):
			remove_child(owned)
			owned.queue_free()
	world_input = null
	camera_controller = null
	native_hud = null
	registry = null
	room_owner = null
	environment_owner = null

func load_room(scene_path: String) -> void:
	clear_room()
	if not scene_path.is_absolute_path() or scene_path.begins_with(ProjectSettings.globalize_path("res://")):
		_fail("Scene must be an absolute external runtime asset path")
		return
	var started := Time.get_ticks_usec()
	var metadata_path := scene_path.get_basename() + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not parsed is Dictionary:
		_fail("External scene metadata is absent or invalid")
		return
	var metadata: Dictionary = parsed
	if metadata.get("version", 0) != 1 or FileAccess.get_sha256(scene_path) != metadata.get("sha256", ""):
		_fail("External scene metadata/hash validation failed")
		return
	var dimensions: Array = metadata.get("buffer", [])
	if dimensions.size() != 2:
		_fail("Captured drawing buffer is absent")
		return
	get_window().size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(scene_path, state)
	if error != OK:
		_fail("glTF import failed: %s" % error)
		return
	var room := document.generate_scene(state)
	if room == null:
		_fail("glTF scene generation returned null")
		return
	add_child(room)
	room_owner = room
	var meshes := _count_meshes(room)
	if meshes != int(metadata.get("counts", {}).get("meshes", -1)):
		_fail("Imported mesh count differs from source export")
		return
	for source_light in metadata.get("lights", []):
		var light := room.find_child(str(source_light["name"]), true, false)
		if light is Light3D:
			light.shadow_enabled = bool(source_light["shadow"])
			if light is OmniLight3D:
				light.omni_range = maxf(0.1, absf(float(source_light.get("distance", 5.0))))
	var environment := preload("res://systems/area_environment.gd").new()
	environment.configure(metadata,room)
	add_child(environment)
	environment_owner = environment
	camera = _find_camera(room)
	if camera == null:
		_fail("Captured camera is absent; refusing a different test view")
		return
	camera.current = true
	if metadata.get("systemsVersion", 0) == 1:
		registry = EntityRegistry.new()
		add_child(registry)
		registry.configure(room, metadata, state)
		if registry.stats.missing_bindings > 0 or registry.stats.particle_errors > 0:
			_fail("Native object/material binding failed")
			return
		camera_controller = CameraController.new()
		add_child(camera_controller)
		var focus: Vector3 = camera.global_position - camera.global_basis.z * 20.0
		if metadata.get("focus") is Array:
			focus = Vector3(float(metadata.focus[0]), float(metadata.focus[1]), float(metadata.focus[2]))
		camera_controller.configure(camera, focus)
		environment.camera = camera
		environment.controller = camera_controller
		native_hud = NativeHud.new()
		add_child(native_hud)
		native_hud.configure(registry, camera)
		world_input = WorldInput.new()
		add_child(world_input)
		world_input.configure(registry, camera, native_hud)
		world_input.camera_controller = camera_controller
		if local_bridge != null:
			local_bridge.bind_world(metadata)
		label.hide()
		report["native_systems"] = registry.stats
	report["scene"] = scene_path
	report["load_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	report["mesh_instances"] = meshes
	report["source_counts"] = metadata.get("counts", {})
	report["source_inventory_objects"] = metadata.get("inventory", []).size()
	report["scene_sha256"] = metadata["sha256"]
	report["rendering_method"] = RenderingServer.get_current_rendering_method()
	report["driver"] = RenderingServer.get_current_rendering_driver_name()
	report["buffer"] = [get_viewport().size.x, get_viewport().size.y]
	report["fidelity_gaps"] = metadata.get("gaps", [])
	report["headless"] = DisplayServer.get_name() == "headless"
	print("OFFLINE_CAPTURE_LOADED " if local_bridge == null else "LOCAL_SCENE_PREPARED ", JSON.stringify({"meshes": meshes, "objects": report.source_inventory_objects, "sha256": metadata.sha256, "fps_visible": native_hud == null or native_hud.metrics.visible, "network": local_bridge != null}))
	warmup_until = Time.get_ticks_usec() + 16000000
	set_process(true)

func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null

func _count_meshes(node: Node) -> int:
	var count := int(node is MeshInstance3D)
	for child in node.get_children():
		count += _count_meshes(child)
	return count

func _process(_delta: float) -> void:
	if camera == null:
		return
	var now := Time.get_ticks_usec()
	var gap := (now - previous_tick) / 1000.0
	previous_tick = now
	# Show the live counter immediately. Benchmark warmup excludes timing
	# samples, not the player's HUD.
	if native_hud != null:
		native_hud.update_metrics()
	if warmup > 0 or now < warmup_until:
		warmup -= 1
		return
	if remaining_frames > 0:
		frame_times.append(gap)
	if systems_smoke and world_input != null:
		world_input.request_smoke = true
		if not world_input.smoke_result.is_empty():
			report["systems_smoke"] = world_input.smoke_result
			if not world_input.smoke_result.passed:
				_fail("Native captured-room systems smoke failed")
				return
	label.text = "NATIVE GODOT · import prototype, fidelity pending\n%.1f FPS · %s mesh instances\nFrozen captured poses; this is not gameplay acceptance." % [Engine.get_frames_per_second(), report.get("mesh_instances", 0)]
	if remaining_frames > 0:
		remaining_frames -= 1
		if remaining_frames == 0:
			_finish()

func _finish() -> void:
	if systems_smoke and not report.get("systems_smoke", {}).get("passed", false):
		_fail("Native systems smoke did not complete")
		return
	var sorted := frame_times.duplicate()
	sorted.sort()
	var total := 0.0
	for value in frame_times:
		total += value
	report["frames"] = frame_times.size()
	report["average_ms"] = total / frame_times.size()
	report["p95_ms"] = sorted[ceili(sorted.size() * 0.95) - 1]
	report["worst_ms"] = sorted.back()
	report["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	report["primitives"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	await RenderingServer.frame_post_draw
	if not report_path.is_empty():
		get_viewport().get_texture().get_image().save_png(report_path.get_basename() + ".png")
	_write_report()
	get_tree().quit()

func _fail(message: String) -> void:
	report["failure"] = message
	push_error(message)
	_write_report()
	get_tree().quit(1)

func _write_report() -> void:
	print(JSON.stringify(report))
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t") + "\n")
