extends CanvasLayer
const Timing=preload("res://systems/native_render/frame_profile.gd")
const Plate=preload("res://systems/native_nameplate.gd")
const PlateState=preload("res://systems/native_data/nameplate_state.gd")
const UiRules=preload("res://systems/native_data/game_ui_rules.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const NameplateAnchor=preload("res://systems/native_data/nameplate_anchor.gd")
const SpeechAnchor=preload("res://systems/native_data/overhead_speech_anchor.gd")
const SpeechScope=preload("res://systems/native_data/overhead_speech_scope.gd")
const WorldHighlight=preload("res://systems/native_data/world_highlight.gd")
const WorldHighlightAssets=preload("res://systems/native_data/world_highlight_assets.gd")
const RendererPerformanceView=preload("res://systems/native_render/renderer_performance_view.gd")

signal examine_requested(id: int)

const DraggablePanel = preload("res://systems/draggable_panel.gd")
var registry
var camera: Camera3D
var root: Control
var panels: Dictionary = {}
var nameplates: Dictionary = {}
var nameplate_signatures: Dictionary={}
var nameplate_values: Dictionary={}
var nameplate_shown: Dictionary={}
var nameplate_ui: WeakRef
var highlight_failures: Dictionary={}
var nameplate_source
var nameplate_source_owned:=false
var nameplate_rules:=UiRules.new()
var details: Label
var object_list: ItemList
var object_ids: Array = []
var current_id := -1
var metrics: Label
var performance_view: PanelContainer
var nameplate_root: Control
var world_highlight_labels
var storage := "user://native-menu-layout.cfg"
var live_mode := false
var instructions: Label
var refresh_queued:=false

func enable_live_mode() -> void:
	live_mode = true
	panels.details.set_caption("Object details · local server")
	panels.objects.set_caption("World objects · local server")
	instructions.text = "Middle drag: orbit · Wheel: zoom\nW/S: forward/back · A/D: turn · Q/E: strafe\nShift: walk · Enter: chat · Hold Tab: highlights\nHome: initial view · Left click: move / interact\nRight click: actions · I: inventory · X: examine · B: spellbook\nF1–F12: shortcuts · Ctrl+Alt+F1/F2/F3: debug\n\nNative movement/animation. Effects / full menus pending."

func configure(value, view: Camera3D, settings: String = "user://native-menu-layout.cfg") -> void:
	registry = value
	camera = view
	storage = settings
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	metrics = Label.new()
	metrics.position = Vector2(16, 16)
	metrics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metrics.add_theme_color_override("font_shadow_color", Color.BLACK)
	metrics.add_theme_constant_override("shadow_offset_x", 2)
	metrics.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(metrics)
	performance_view=RendererPerformanceView.new()
	root.add_child(performance_view)
	performance_view.configure()
	nameplate_root = Control.new()
	nameplate_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nameplate_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nameplate_root)
	world_highlight_labels=preload("res://systems/world_highlight_labels.gd").new()
	nameplate_root.add_child(world_highlight_labels)
	world_highlight_labels.configure(registry,camera,self)
	var inspect = _panel("Object details · captured state", "details", Vector2(36, 160))
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(310, 180)
	inspect.content.add_child(details)
	var objects = _panel("World objects · captured state", "objects", Vector2(400, 160))
	object_list = ItemList.new()
	object_list.custom_minimum_size = Vector2(320, 330)
	object_list.focus_mode = Control.FOCUS_NONE
	objects.content.add_child(object_list)
	object_list.item_selected.connect(func(index): inspect_entity(int(object_ids[index])))
	for id in registry.eligible_ids():
		object_ids.append(id)
		object_list.add_item(_name(id))
	var help = _panel("Controls", "help", Vector2(36, 420))
	instructions = Label.new()
	instructions.text = "Middle drag: orbit · Wheel: zoom\nWASD: pan inspection camera · Shift: faster\nHome: captured view · Hold Tab: highlights\nLeft click: select · Right click / I: details\nF1: controls · F2: objects · F3: performance\n\nOffline captured state. No server actions."
	help.content.add_child(instructions)
	for panel in panels.values():
		panel.hide()

func _panel(caption: String, key: String, initial: Vector2):
	var panel = DraggablePanel.new()
	panel.configure(caption, key, initial, storage)
	root.add_child(panel)
	panels[key] = panel
	return panel

func _name(id: int) -> String:
	var row: Dictionary = registry.entities.get(id, {})
	var value := str(row.get("name", ""))
	return value if not value.is_empty() else "Object %s" % id

func refresh_entities() -> void:
	object_list.clear()
	object_ids.clear()
	for id in registry.eligible_ids():
		object_ids.append(id)
		object_list.add_item(_name(id))
	for id in nameplates.keys():
		if not registry.entities.has(id):
			drop_nameplate(id)
	if current_id >= 0 and not registry.entities.has(current_id):
		current_id = -1
		panels.details.hide()
func queue_refresh_entities() -> void:
	if refresh_queued: return
	refresh_queued=true; _flush_entities.call_deferred()
func _flush_entities() -> void:
	var began:=Timing.begin(); refresh_queued=false
	if is_inside_tree(): refresh_entities()
	Timing.finish("hud_deferred_refresh_ms",began)

func inspect_entity(id: int) -> void:
	if not registry.entities.has(id):
		return
	current_id = id
	if live_mode:
		examine_requested.emit(id)
		return
	var row: Dictionary = registry.entities[id]
	details.text = "%s\nID: %s · type: %s\n\nModels:\n%s\n\nRead-only captured state.\nInteraction and movement await the live bridge." % [_name(id), id, row.get("type", "?"), "\n".join(row.get("resources", []))]
	panels.details.show()
	panels.details.move_to_front()

func toggle_panel(key: String) -> void:
	var panel = panels[key]
	panel.visible = not panel.visible
	if panel.visible:
		panel.move_to_front()

func blocks_pointer(point: Vector2) -> bool:
	for panel in panels.values():
		if panel.visible and panel.get_global_rect().has_point(point):
			return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var children := root.get_children()
		children.reverse()
		for panel in children:
			if panel is PanelContainer and panel.visible and panel.get_global_rect().has_point(event.position):
				panel.move_to_front()
				break

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if live_mode and event.keycode != KEY_X: return
	match event.keycode:
		KEY_F1: toggle_panel("help")
		KEY_F2: toggle_panel("objects")
		KEY_F3: metrics.visible = not metrics.visible
		KEY_I:
			if not live_mode: inspect_entity(current_id)
		KEY_X:
			if live_mode: inspect_entity(current_id)

func bind_gameplay(ui) -> void:
	clear_nameplates(); release_nameplate_source(); highlight_failures.clear(); nameplate_ui=weakref(ui)
	if is_instance_valid(world_highlight_labels):
		world_highlight_labels.clear()
		world_highlight_labels.set_art(ui.desktop.art if is_instance_valid(ui.desktop) else null)
		world_highlight_labels.set_fonts(ui.popup_fonts if is_instance_valid(ui.get("popup_fonts")) else null)
	if is_instance_valid(ui.get("overhead_popup_source")):
		nameplate_source=ui.overhead_popup_source;nameplate_source_owned=false;return
	if ui.get("catalog")!=null:
		nameplate_source=preload("res://systems/native_nameplate_resources.gd").new(); add_child(nameplate_source)
		nameplate_source_owned=true
		var assets=ui.get("assets"); var cache_path: String=str(assets.cache_directory) if is_instance_valid(assets) else ""
		nameplate_source.configure(ui.catalog,cache_path)
func report_highlight_failure(ui,id: int,kind: String,signature: String,reason: String) -> void:
	if reason.is_empty():return
	var key: String="%s:%s:%s" % [ui.area_id,id,kind]
	if highlight_failures.get(key)==signature:return
	highlight_failures[key]=signature
	ui.stats.errors.append({"code":"world.highlight-label-failed","reason":reason,"objectId":id,"operation":kind})
func world_highlight_label_data(id: int) -> Dictionary:
	var ui=nameplate_ui.get_ref() if nameplate_ui!=null else null
	if not is_instance_valid(ui) or ui.closed:return {}
	var object: Dictionary=ui.text.objects.get(id,{})
	if object.is_empty() or int(object.get("areaId",-1))!=ui.area_id:return {}
	var state: Dictionary=object.get("replicated") if object.get("replicated") is Dictionary else {}
	var value: Variant=WorldHighlight.name_value(object)
	var signature: String=JSON.stringify([ui.text.revision,value,state.get("damageLevel"),state.get("hitPoints"),state.get("portrait"),state.get("portraitRef")])
	var name_result: Dictionary={"error":""}
	var resolver:=func(token):
		var result: String=ui.text.resolve(token,id)
		if name_result.error.is_empty() and not ui.text.network_last_error.is_empty():name_result.error=ui.text.network_last_error
		return result
	var name: String=WorldHighlight.name(value,resolver)
	report_highlight_failure(ui,id,"name",signature,str(name_result.error))
	var details: Dictionary={}
	if int(object.get("objectType",0))==5:
		var level_to_resolve: int=WorldHighlight.damage_level(object)
		var table_error: String=""
		if level_to_resolve>=0 and is_instance_valid(ui.assets):
			var table_state: Dictionary=ui.text.network_table("damagelevels")
			table_error=str(table_state.get("error",""))
		ui.text.network_last_error=""
		details=WorldHighlightAssets.creature_details(object,ui)
		report_highlight_failure(ui,id,"details",signature,table_error if not table_error.is_empty() else ui.text.network_last_error)
	var level:=int(details.get("level",-1))
	var condition_colors:=["#80ff40","#80ff40","#ffff40","#ffad40","#ff5555","#aaaaaa"]
	return {"id":id,"name":name,"name_color":WorldHighlight.name_color(object,ui.controlled_id),"condition":str(details.get("condition","")),"condition_color":Color(condition_colors[level]) if level>=0 and level<condition_colors.size() else Color("#80ff40"),"portrait":str(details.get("portrait","")),"creature":int(object.get("objectType",0))==5,"signature":signature}
func release_nameplate_source() -> void:
	if nameplate_source_owned and is_instance_valid(nameplate_source): nameplate_source.close(); nameplate_source.queue_free()
	nameplate_source=null;nameplate_source_owned=false
func drop_nameplate(id: int) -> void:
	if nameplates.has(id):
		nameplates[id].close(); nameplates[id].queue_free(); nameplates.erase(id)
	nameplate_signatures.erase(id);nameplate_values.erase(id);nameplate_shown.erase(id)
func clear_nameplates() -> void:
	for id in nameplates.keys(): drop_nameplate(int(id))
func highlight_labels(ids: Array,hovered: int,tab: bool) -> void:
	if is_instance_valid(world_highlight_labels):world_highlight_labels.update(ids,hovered,tab)
func labels(ids: Array,hovered: int=-1) -> void:
	var prior_shown: Dictionary=nameplate_shown.duplicate();nameplate_shown.clear()
	for id in nameplates:
		nameplates[id].hide()
	var ui=nameplate_ui.get_ref() if nameplate_ui!=null else null
	if nameplate_ui!=null and (not is_instance_valid(ui) or ui.closed): clear_nameplates(); release_nameplate_source(); return
	if is_instance_valid(ui) and not ui.presentation_enabled: return
	var viewport:=get_viewport().get_visible_rect()
	var context: Dictionary=ui.overhead_context() if is_instance_valid(ui) else {}
	# Only explicit absence of an admitted connection permits the inspection
	# AABB path. Pending native scope/model data cannot borrow that fallback.
	var native_projection: bool=is_instance_valid(ui) and context.get("connection")!=null
	var current:=SpeechScope.context(context.get("connection"),context.get("generation"),context.get("areaId")) if native_projection else {}
	for id in PlateState.visible_ids(ids,registry.entities,hovered):
		var raw: Dictionary=ui.text.objects.get(id,{}) if is_instance_valid(ui) else {}
		if is_instance_valid(ui) and (raw.is_empty() or int(raw.get("areaId",-1))!=ui.area_id):continue
		var screen: Vector2
		if native_projection:
			if not SpeechScope.current_context(current) or not ui.overhead_anchor_query.is_valid():continue
			var anchor: Dictionary=ui.overhead_anchor(id,SpeechAnchor.witness(raw),[current.connection,current.generation,current.areaId])
			if not anchor.get("ready",false) or not anchor.get("screen") is Vector2 or not anchor.screen.is_finite():continue
			screen=anchor.screen # Raw native head projection; Plate owns one truncation.
		else:
			# Explicit offline/debug inspection retains its older AABB, culling
			# and footprint policy. This branch is not native popup acceptance.
			var point: Vector3=registry.nameplate_position(id,camera.global_position)
			if camera.is_position_behind(point):continue
			screen=camera.unproject_position(point)
			if not screen.is_finite() or not viewport.has_point(screen):continue
			screen=NameplateAnchor.screen(screen)
		var source: Dictionary={}; var signature: int
		if is_instance_valid(ui):
			var state: Dictionary=raw.get("replicated",{})
			source=raw if state.has("name") and (int(raw.get("objectType",0))!=5 or state.has("portrait") or state.has("portraitRef")) else nameplate_rules.presentation_object(ui.text.objects,id,ui.desktop.state.get("players",[]))
			signature=PlateState.signature(source,ui.controlled_id,ui.text.revision)
		else:
			signature=hash([_name(id),registry.entities[id].get("type"),registry.entities[id].get("color")])
		if not nameplates.has(id):
			var plate:=Plate.new(); nameplate_root.add_child(plate)
			var constructed_popup: Dictionary=ui.overhead_popup_registry.caption_record(id,ui.text.objects.get(id,{})) if is_instance_valid(ui) and is_instance_valid(ui.get("overhead_popup_registry")) and ui.overhead_popup_registry.has_method("caption_record") else {}
			var fonts=ui.popup_fonts if is_instance_valid(ui) and is_instance_valid(ui.get("popup_fonts")) else ui.inventory.frame_skin.fonts if is_instance_valid(ui) else null
			plate.configure(ui.desktop.art if is_instance_valid(ui) else null,fonts,nameplate_source,str(constructed_popup.get("font",Plate.FONT)))
			if not constructed_popup.is_empty():plate.set_popup_preferences(int(constructed_popup.mode),str(constructed_popup.font));ui.overhead_popup_registry.bind_view(id,ui.text.objects[id],"hover",plate)
			nameplates[id]=plate
			if is_instance_valid(ui) and is_instance_valid(ui.get("overhead_popup_registry")):ui.overhead_popup_registry.register(id,ui.text.objects.get(id,{}))
		if nameplate_signatures.get(id)!=signature:
			nameplate_signatures[id]=signature
			var value:=PlateState.project(source,ui.controlled_id,ui.text) if is_instance_valid(ui) else {"available":true,"creature":int(registry.entities[id].get("type",0))==5,"name":Rich.parse(_name(id)),"condition":Rich.parse(""),"portrait":"","color":Color(str(registry.entities[id].get("color","#cfffff"))),"condition_color":Color("#80ff80")}
			nameplate_values[id]=value
		# Original object+b8 owns both speech and its cached hover caption. Keep
		# the current exact-lifetime caption, but never draw two simultaneous
		# popups for that visual. Expiry simply releases the speech priority.
		if prior_shown.has(id):nameplate_shown[id]=true
		var current_value: Dictionary=nameplate_values.get(id,{})
		if is_instance_valid(ui) and ui.has_method("overhead_claims_nameplate") and ui.overhead_claims_nameplate(id,ui.text.objects.get(id,{}),current_value):continue
		var popup_record: Dictionary=ui.overhead_popup_registry.caption_record(id,ui.text.objects[id]) if is_instance_valid(ui) and is_instance_valid(ui.get("overhead_popup_registry")) and ui.overhead_popup_registry.has_method("caption_record") else {}
		if not popup_record.is_empty():
			var previous_identity: Array=nameplates[id].get_meta("native_popup_witness",[])
			var current_identity: Array=ui.overhead_popup_registry.slots[id].witness
			if previous_identity!=current_identity:prior_shown.erase(id);nameplate_shown.erase(id)
			ui.overhead_popup_registry.bind_view(id,ui.text.objects[id],"hover",nameplates[id]);nameplates[id].set_popup_preferences(int(popup_record.mode),str(popup_record.font))
		# Speech expiry retires its timed popup even if Tab/mouse hover never
		# left this actor. A current known hover caption is a separate writer
		# from cached restoration (which may lack relation text). Re-admit that
		# current caption once; writer=hover prevents per-frame timer resets.
		var hover_caption: Dictionary=current_value.get("caption",current_value.get("name",{}))
		var fresh_hover_known: bool=current_value.get("available",false) and hover_caption.get("nativeRawBytes") is PackedByteArray
		var expired_caption: bool=not popup_record.is_empty() and popup_record.get("writer")=="cached-name" and fresh_hover_known and int(popup_record.get("timedFlag",0))==0 and not popup_record.get("guiRegistered",false)
		if not prior_shown.has(id) or nameplates[id].get_meta("hover_signature",-1)!=signature or expired_caption:
			nameplates[id].set_content(current_value);nameplates[id].set_meta("hover_signature",signature)
			if not popup_record.is_empty():ui.overhead_popup_registry.write_hover(id,ui.text.objects[id],current_value)
		nameplate_shown[id]=true
		if not popup_record.is_empty():
			ui.overhead_popup_registry.project_speech(id,ui.text.objects[id],true)
			nameplates[id].presentation_active=popup_record.sceneActive and not popup_record.hidden
		nameplates[id].place(screen,viewport,native_projection)
		if is_instance_valid(ui) and is_instance_valid(ui.get("overhead_popup_registry")):ui.overhead_popup_registry.offer(id,ui.text.objects.get(id,{}),nameplates[id])

	if is_instance_valid(ui) and is_instance_valid(ui.get("overhead_popup_registry")) and ui.overhead_popup_registry.has_method("leave_hover"):
		for id in prior_shown:
			if not nameplate_shown.has(id):ui.overhead_popup_registry.leave_hover(int(id))

func _exit_tree() -> void:
	clear_nameplates();release_nameplate_source()
	if is_instance_valid(world_highlight_labels):world_highlight_labels.clear()

func update_metrics() -> void:
	if live_mode:
		metrics.text = "%.1f FPS" % Engine.get_frames_per_second()
		return
	metrics.text = "NATIVE GODOT · captured-world prototype\n%.1f FPS · %s objects · %s picking surfaces\nMiddle drag / wheel / WASD camera · F1 controls\nFrozen animation; no server connection." % [Engine.get_frames_per_second(), registry.entities.size(), registry.stats.colliders]

func record_performance(frame: Dictionary) -> void:
	if not is_instance_valid(performance_view):return
	# The live owner supplies completion timestamps and render counters. Add only
	# measurements the Godot runtime actually exposes; the old Three.js stage
	# fields remain unavailable when there is no equivalent instrumented owner.
	var observed:=frame.duplicate(true)
	var timing: Dictionary=observed.get("timing",{}).duplicate()
	var process_ms:=Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
	if is_finite(process_ms) and process_ms>0.0:timing.totalMs=process_ms
	if Timing.enabled and is_instance_valid(camera):
		var render_cpu_ms:=RenderingServer.viewport_get_measured_render_time_cpu(camera.get_viewport().get_viewport_rid())
		if is_finite(render_cpu_ms) and render_cpu_ms>0.0:timing.renderMs=render_cpu_ms
	if Timing.enabled and Timing.phase_frame==Engine.get_process_frames():
		var phases: Dictionary=Timing.phases
		if phases.has("callback_particles"):timing.particlesMs=float(phases.callback_particles)
		if phases.has("callback_camera") and phases.has("callback_audio"):
			timing.cameraStages={"cameraAndAudioMs":float(phases.callback_camera)+float(phases.callback_audio)}
	observed.timing=timing
	performance_view.record(observed)

func toggle_performance() -> void:
	if is_instance_valid(performance_view): performance_view.visible = not performance_view.visible

func performance_snapshot() -> Dictionary:
	return performance_view.snapshot() if is_instance_valid(performance_view) else {}
