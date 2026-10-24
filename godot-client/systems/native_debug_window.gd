extends Window
signal closed_by_user
signal request(message: Dictionary)
const TABS := ["Performance", "Gameplay", "Diagnostics", "Inspector", "Resources"]
var tabs: TabContainer
var bodies: Array[RichTextLabel] = []
var client
var elapsed := 0.0
var backend: Dictionary = {}
var frame_ms: Array[float] = []
var storage := "user://native-debug-window.cfg"
var updates := 0

func _init() -> void:
	# Gameplay popups stay embedded; only diagnostics need a separate OS window.
	visible = false; force_native = true

func setup(owner, path: String = "user://native-debug-window.cfg") -> void:
	client = owner; storage = path; title = "NWN Debug"; size = Vector2i(720, 720); min_size = Vector2i(420, 320); transient = false; exclusive = false
	var saved := ConfigFile.new()
	if not storage.is_empty() and saved.load(storage) == OK:
		size = saved.get_value("window", "size", size); position = saved.get_value("window", "position", Vector2i(100, 100))
	tabs = TabContainer.new(); add_child(tabs); tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for caption in TABS:
		var body := RichTextLabel.new(); body.name = caption; body.bbcode_enabled = false; body.selection_enabled = true; body.add_theme_color_override("default_color", Color("ecdfbd")); body.add_theme_font_size_override("normal_font_size", 14); tabs.add_child(body); bodies.append(body)
	close_requested.connect(func():
		save_layout(); hide(); closed_by_user.emit()
		if DisplayServer.get_name() != "headless" and is_instance_valid(get_parent()): get_parent().get_viewport().get_window().grab_focus())
	visibility_changed.connect(func():
		if visible: refresh(); request.emit({"kind":"client-debug-request"})
		else: save_layout())
	tabs.tab_changed.connect(func(_index): if visible: refresh())
	hide()

func save_layout() -> void:
	if storage.is_empty(): return
	var saved := ConfigFile.new(); saved.set_value("window", "size", size); saved.set_value("window", "position", position); saved.save(storage)

func _process(delta: float) -> void:
	if not visible: return
	frame_ms.append(delta * 1000)
	if frame_ms.size() > 180: frame_ms.pop_front()
	elapsed += delta
	if elapsed >= 0.5:
		elapsed = 0; refresh(); request.emit({"kind":"client-debug-request"})

func receive(message: Dictionary) -> void:
	backend = message.get("snapshot", {}).duplicate(true)
	if visible: refresh()

func refresh() -> void:
	if tabs == null: return
	updates += 1
	var scene = client.owner_scene if is_instance_valid(client) else null
	var registry = scene.registry if is_instance_valid(scene) else null
	match tabs.current_tab:
		0:
			var samples := frame_ms.duplicate(); samples.sort()
			var average := 0.0
			for sample in samples: average += sample
			average /= maxf(1, samples.size())
			bodies[0].text = "NATIVE PERFORMANCE\n\nFPS: %.1f\nFrame avg: %.2f ms\nFrame p95: %.2f ms\nDraw calls: %s\nRendered objects: %s\nPrimitives: %s\nStatic memory: %.1f MiB\n\nFrame intervals, not GPU timing or server ping. Render totals include all viewports, including this debug window." % [Engine.get_frames_per_second(), average, samples[mini(samples.size() - 1, floori(samples.size() * 0.95))] if not samples.is_empty() else 0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]
		1:
			var gameplay := {"connection":client.connection,"area":client.area_id,"generation":client.generation,"controlled":client.controlled_id,"targeting":client.targeting.mode,"radial":client.radial.active,"backend":backend.get("gameplay", {})} if is_instance_valid(client) else {}
			bodies[1].text = "GAMEPLAY\n\n" + JSON.stringify(gameplay, "  ")
		2: bodies[2].text = "DIAGNOSTICS\n\n" + JSON.stringify(backend.get("diagnostics", []), "  ")
		3:
			var objects: Array = []
			if registry != null:
				for id in registry.entities:
					var row: Dictionary = registry.entities[id]
					objects.append({"id":id,"name":row.get("name", ""),"type":row.get("type"),"eligible":row.get("eligible"),"resources":row.get("resources", [])})
			bodies[3].text = "RECEIVED WORLD OBJECTS · READ ONLY\n\n" + JSON.stringify(objects, "  ")
		4:
			var resources := {"live_objects":registry.entities.size() if registry != null else 0,"picking_surfaces":registry.stats.colliders if registry != null else 0,"backend":backend.get("resources", {})}
			bodies[4].text = "RESOURCES\n\n" + JSON.stringify(resources, "  ")
