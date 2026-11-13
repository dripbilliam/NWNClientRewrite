extends "res://systems/draggable_panel.gd"
signal particles_changed(value: bool)
signal tile_borders_changed(value: bool)
signal show_blockers_changed(value: bool)
signal gamma_changed(value: float)
signal fov_changed(value: float)
signal creature_shadow_detail_changed(value: int)
signal particle_collision_changed(value: bool)
signal profiling_changed(value: bool)
signal creature_slots_changed(value: bool)
signal gore_changed(value: int)
signal compact_scenery_changed(value: bool)
signal entity_inspector_requested
signal prework_requested
signal prework_cancel_requested
signal prework_clear_requested
signal prework_workers_changed(value: int)
signal prework_folder_requested
signal ui_preload_requested
signal ui_preload_cancel_requested
signal login_profiles_requested
signal chat_settings_requested
signal radial_preferences_changed(value: Dictionary)
var radial_preferences: Dictionary={"group_abilities":false,"group_spells":false,"submenu_previews":true,"submenu_mode":1,"text_mode":1,"hide_icons":false,"text_in_center":false,"center_align_text":false,"screen_center":false,"left_mirror":true}
var radial_toggles: Dictionary={}
var radial_choices: Dictionary={}
const TooltipPreferences=preload("res://systems/native_data/tooltip_preferences.gd")
const CameraFov=preload("res://tools/native_parity/ui/camera_fov_projection.gd")
var fov_degrees:=CameraFov.DEFAULT_DEGREES
var fov_control: HSlider
var fov_value: Label
var fov_reset: Button
# Original CreatureShadowDetail / graphics.shadows.creatures.mode, default2.
# This policy is separate from the point-light/shadow-map budget.
var creature_shadow_detail:=2
var creature_shadow_select: OptionButton
var tooltip_delay_usec:=TooltipPreferences.DEFAULT_USEC
var tooltip_delay_control: SpinBox
var tooltip_doubletap_ms:=TooltipPreferences.Highlight.DEFAULT_MS
var tooltip_doubletap_control: SpinBox
var ui_preload_prepare: Button
var ui_preload_cancel: Button
var ui_preload_content: OptionButton
var ui_preload_progress: ProgressBar
var ui_preload_status: Label
var ui_preload_active:=false
var prework_prepare: Button
var prework_cancel: Button
var prework_clear: Button
var prework_status: Label
var prework_scope: OptionButton
var prework_content: OptionButton
var prework_workers: OptionButton
var prework_worker_setting:=0
var prework_folder: Button
var prework_sources_signature: Array=[]
var prework_progress: ProgressBar
var prework_available:=false
var prework_active:=false
var prework_clearing:=false
var entity_inspector_button: Button
var preference_path:="user://native-options.cfg"
var particles_enabled:=false
var tile_borders_enabled:=true
var tile_borders_toggle: CheckBox
var show_blockers_enabled:=false
var show_blockers_toggle: CheckBox
var gamma_value:=2.2
var gamma_control: SpinBox
var particle_collision_enabled:=true
var profiling_enabled:=false
var creature_slots:=false
var gore:=1
var compact_scenery_enabled:=false
var compact_scenery_toggle: CheckBox
var gore_select: OptionButton
var creature_toggle: CheckBox
var particles_toggle: CheckBox
var particle_collision_toggle: CheckBox
var profile_toggle: CheckBox
var performance: RichTextLabel
var tabs: TabContainer
func setup(preferences: String="user://native-options.cfg",layout: String="user://native-menu-layout.cfg",profile_requested: bool=false,static_parts_requested: String="",profiling_override: String="") -> void:
	preference_path=preferences
	var config:=ConfigFile.new(); config.load(preference_path)
	tooltip_delay_usec=TooltipPreferences.apply(config.get_value("interface","tooltip_delay_usec",TooltipPreferences.DEFAULT_USEC))
	tooltip_doubletap_ms=TooltipPreferences.apply_doubletap(config.get_value("interface","tooltip_doubletap_ms",TooltipPreferences.Highlight.DEFAULT_MS))
	var saved_gamma: Variant=config.get_value("rendering","gamma",2.2)
	if preload("res://systems/native_render/native_gamma_effect.gd").valid_value(saved_gamma): gamma_value=clampf(float(saved_gamma),0.0,1000.0)
	var saved_fov: Variant=config.get_value("rendering","fov_degrees",CameraFov.DEFAULT_DEGREES)
	fov_degrees=float(saved_fov) if CameraFov.valid(saved_fov) else CameraFov.DEFAULT_DEGREES
	var saved_shadows: Variant=config.get_value("rendering","creature_shadow_detail",2)
	creature_shadow_detail=int(saved_shadows) if (saved_shadows is int or saved_shadows is float) and is_finite(float(saved_shadows)) and saved_shadows in [0,1,2] else 2
	for key in radial_preferences:
		var setting: Variant=config.get_value("interface","radial_"+str(key),radial_preferences[key])
		if typeof(setting)==typeof(radial_preferences[key]) and (setting is bool or int(setting) in [0,1,2]): radial_preferences[key]=setting
	if not config.has_section_key("interface","radial_submenu_mode"): radial_preferences.submenu_mode=int(radial_preferences.submenu_previews)
	radial_preferences.submenu_previews=int(radial_preferences.submenu_mode)!=0
	var value: Variant=config.get_value("rendering","particles_enabled",false)
	particles_enabled=value if value is bool else false
	# Original graphics.tile-borders.enabled / Enable TileBorder defaults on.
	# A server area's separate TileBorderDisabled state still takes priority.
	value=config.get_value("rendering","tile_borders_enabled",true)
	tile_borders_enabled=value if value is bool else true
	value=config.get_value("rendering","show_blockers",false)
	show_blockers_enabled=value if value is bool else false
	value=config.get_value("rendering","particle_collision_enabled",true)
	particle_collision_enabled=value if value is bool else true
	value=config.get_value("rendering","profiling_enabled",false)
	profiling_enabled=profile_requested or (value if value is bool else false)
	if profiling_override in ["true","false"]: profiling_enabled=profiling_override=="true"
	value=config.get_value("interface","creature_slots",false)
	creature_slots=value if value is bool else false
	value=config.get_value("rendering","gore",1)
	gore=value if value is int and value>=0 and value<=2 else 1
	value=config.get_value("rendering","compact_scenery",false)
	compact_scenery_enabled=value if value is bool else false
	if static_parts_requested in ["compact","separate"]: compact_scenery_enabled=static_parts_requested=="compact"
	value=config.get_value("rendering","prework_workers",0)
	prework_worker_setting=value if value is int and value in [0,1,2,4,8] else 0
	configure("Client Options","native-render-settings",Vector2(220,100),layout)
	apply_native_theme(preload("res://systems/native_client_menu_style.gd").base_theme())
	var built:=MenuBuilder.build(content,preload("res://systems/native_data/client_options_layout.gd").definition())
	assert(str(built.error).is_empty(),str(built.error))
	for key in radial_preferences:
		if key=="submenu_previews": continue # Migrate the former Boolean, no duplicate control.
		if radial_preferences[key] is int:
			var choice: OptionButton=built.nodes["radial_"+str(key)]; choice.select(int(radial_preferences[key])); radial_choices[key]=choice
			choice.item_selected.connect(func(index):save_radial_preference(key,index)); continue
		var toggle: CheckBox=built.nodes["radial_"+str(key)]; toggle.set_pressed_no_signal(bool(radial_preferences[key]))
		radial_toggles[key]=toggle
		toggle.toggled.connect(func(on):save_radial_preference(key,on))
	tabs=built.nodes.tabs
	tooltip_delay_control=built.nodes.tooltip_delay_control; tooltip_delay_control.set_value_no_signal(float(tooltip_delay_usec)/1000.0)
	tooltip_delay_control.value_changed.connect(func(value):tooltip_delay_usec=TooltipPreferences.save(preference_path,roundi(value*1000.0)))
	tooltip_doubletap_control=built.nodes.tooltip_doubletap_control; tooltip_doubletap_control.set_value_no_signal(tooltip_doubletap_ms)
	tooltip_doubletap_control.value_changed.connect(func(value):tooltip_doubletap_ms=TooltipPreferences.save_doubletap(preference_path,roundi(value)))
	gamma_control=built.nodes.gamma_control; gamma_control.set_value_no_signal(gamma_value)
	gamma_control.value_changed.connect(func(value):gamma_value=value; persist("gamma",value); gamma_changed.emit(value))
	fov_value=built.nodes.fov_value;fov_reset=built.nodes.fov_reset
	fov_control=HSlider.new();fov_control.min_value=CameraFov.MIN_DEGREES;fov_control.max_value=CameraFov.MAX_DEGREES;fov_control.step=1;fov_control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;fov_control.custom_minimum_size.x=120;fov_control.tooltip_text="Vertical angle. Original gameplay camera:45°. Wider angles show more of the world."
	built.nodes.fov_row.add_child(fov_control);built.nodes.fov_row.move_child(fov_control,1)
	fov_control.set_value_no_signal(fov_degrees);fov_degrees=fov_control.value;fov_value.text="%d°"%roundi(fov_degrees)
	fov_control.value_changed.connect(set_fov_degrees)
	fov_reset.pressed.connect(func():set_fov_degrees(CameraFov.DEFAULT_DEGREES))
	creature_shadow_select=built.nodes.creature_shadow_select
	creature_shadow_select.select(creature_shadow_select.get_item_index(creature_shadow_detail))
	creature_shadow_select.item_selected.connect(func(index):
		creature_shadow_detail=creature_shadow_select.get_item_id(index)
		persist("creature_shadow_detail",creature_shadow_detail);creature_shadow_detail_changed.emit(creature_shadow_detail))
	particles_toggle=built.nodes.particles_toggle
	tile_borders_toggle=built.nodes.tile_borders_toggle
	show_blockers_toggle=built.nodes.show_blockers_toggle
	particle_collision_toggle=built.nodes.particle_collision_toggle
	gore_select=built.nodes.gore_select
	compact_scenery_toggle=built.nodes.compact_scenery_toggle
	profile_toggle=built.nodes.profile_toggle
	entity_inspector_button=built.nodes.entity_inspector_button
	built.nodes.login_profiles_button.pressed.connect(func():login_profiles_requested.emit())
	built.nodes.chat_settings_button.pressed.connect(func():chat_settings_requested.emit())
	performance=built.nodes.performance
	creature_toggle=built.nodes.creature_toggle
	prework_content=built.nodes.prework_content
	prework_scope=built.nodes.prework_scope
	prework_workers=built.nodes.prework_workers
	prework_prepare=built.nodes.prework_prepare
	prework_cancel=built.nodes.prework_cancel
	prework_progress=built.nodes.prework_progress
	prework_status=built.nodes.prework_status
	prework_clear=built.nodes.prework_clear
	prework_folder=built.nodes.prework_folder
	ui_preload_content=built.nodes.ui_preload_content
	ui_preload_prepare=built.nodes.ui_preload_prepare
	ui_preload_cancel=built.nodes.ui_preload_cancel
	ui_preload_progress=built.nodes.ui_preload_progress
	ui_preload_status=built.nodes.ui_preload_status
	particles_toggle.set_pressed_no_signal(particles_enabled)
	tile_borders_toggle.set_pressed_no_signal(tile_borders_enabled)
	show_blockers_toggle.set_pressed_no_signal(show_blockers_enabled)
	particle_collision_toggle.set_pressed_no_signal(particle_collision_enabled)
	compact_scenery_toggle.set_pressed_no_signal(compact_scenery_enabled)
	profile_toggle.set_pressed_no_signal(profiling_enabled); creature_toggle.set_pressed_no_signal(creature_slots)
	gore_select.select(gore); prework_workers.select(prework_workers.get_item_index(prework_worker_setting))
	for control in [prework_clear,prework_folder]: control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	particles_toggle.toggled.connect(func(on): particles_enabled=on; persist("particles_enabled",on); particles_changed.emit(on))
	tile_borders_toggle.toggled.connect(func(on):tile_borders_enabled=on;persist("tile_borders_enabled",on);tile_borders_changed.emit(on))
	show_blockers_toggle.toggled.connect(func(on):show_blockers_enabled=on;persist("show_blockers",on);show_blockers_changed.emit(on))
	particle_collision_toggle.toggled.connect(func(on): particle_collision_enabled=on; persist("particle_collision_enabled",on); particle_collision_changed.emit(on))
	gore_select.item_selected.connect(func(index): gore=index; persist("gore",index); gore_changed.emit(index))
	compact_scenery_toggle.toggled.connect(func(on): compact_scenery_enabled=on; persist("compact_scenery",on); compact_scenery_changed.emit(on))
	profile_toggle.toggled.connect(func(on): profiling_enabled=on; persist("profiling_enabled",on); profiling_changed.emit(on))
	entity_inspector_button.pressed.connect(func():entity_inspector_requested.emit())
	creature_toggle.toggled.connect(func(on):
		creature_slots=on
		var saved:=ConfigFile.new(); saved.load(preference_path); saved.set_value("interface","creature_slots",on); saved.save(preference_path)
		creature_slots_changed.emit(on))
	prework_workers.item_selected.connect(func(index):
		prework_worker_setting=prework_workers.get_item_id(index); persist("prework_workers",prework_worker_setting); prework_workers_changed.emit(prework_worker_setting))
	prework_prepare.pressed.connect(func():prework_requested.emit())
	prework_cancel.pressed.connect(func():prework_cancel_requested.emit())
	prework_clear.pressed.connect(func():prework_clear_requested.emit())
	prework_folder.pressed.connect(func():prework_folder_requested.emit())
	ui_preload_prepare.pressed.connect(func():ui_preload_requested.emit())
	ui_preload_cancel.pressed.connect(func():ui_preload_cancel_requested.emit())
	hide()
func set_fov_degrees(value: float) -> void:
	if not CameraFov.valid(value):return
	fov_control.set_value_no_signal(value);fov_degrees=fov_control.value
	fov_value.text="%d°"%roundi(fov_degrees)
	persist("fov_degrees",fov_degrees);fov_changed.emit(fov_degrees)
func save_radial_preference(key: String,value: Variant) -> void:
	if not radial_preferences.has(key) or typeof(value)!=typeof(radial_preferences[key]): return
	if value is int and value not in [0,1,2]: return
	radial_preferences[key]=value
	var saved:=ConfigFile.new(); saved.load(preference_path); saved.set_value("interface","radial_"+key,value)
	if key=="submenu_mode":
		radial_preferences.submenu_previews=int(value)!=0; saved.set_value("interface","radial_submenu_previews",radial_preferences.submenu_previews)
	saved.save(preference_path); radial_preferences_changed.emit(radial_preferences.duplicate())
func set_prework_available(available: bool) -> void:
	prework_available=available; update_preparation_controls()
func update_preparation_controls() -> void:
	var busy:=prework_active or ui_preload_active
	prework_prepare.disabled=not prework_available or busy
	prework_content.disabled=not prework_available or busy; prework_scope.disabled=busy
	ui_preload_prepare.disabled=not prework_available or busy
	ui_preload_content.disabled=not prework_available or busy
	ui_preload_cancel.disabled=not ui_preload_active
	prework_clear.disabled=ui_preload_active or prework_clearing
func set_prework_sources(labels: Array,connected: bool) -> void:
	var signature: Array=[labels,connected]
	if signature==prework_sources_signature: return
	var previous:=prework_content.get_item_text(prework_content.selected) if prework_content.selected>=0 else ""
	var initial:=prework_sources_signature.is_empty(); prework_sources_signature=signature.duplicate(true)
	prework_content.clear()
	if connected: prework_content.add_item("Current server")
	for label in labels: prework_content.add_item(str(label))
	if prework_content.item_count==0: prework_content.add_item("No local content available")
	prework_content.disabled=prework_active or not connected and labels.is_empty()
	var selected:=0 if connected or labels.size()<2 else 1
	for index in prework_content.item_count:
		if prework_content.get_item_text(index)==previous: selected=index; break
	prework_content.select(selected)
	var ui_previous:=ui_preload_content.get_item_text(ui_preload_content.selected) if ui_preload_content.selected>=0 else ""
	ui_preload_content.clear()
	for index in prework_content.item_count: ui_preload_content.add_item(prework_content.get_item_text(index))
	var ui_selected:=selected
	for index in ui_preload_content.item_count:
		if ui_preload_content.get_item_text(index)==ui_previous: ui_selected=index; break
	ui_preload_content.select(ui_selected)
	if initial and not connected: prework_scope.select(1)
	set_prework_available(connected or not labels.is_empty())
	if not prework_active and prework_status.text in ["Finding installed and downloaded content…","Connect to a server to prepare its available assets."]:
		prework_status.text="Ready to prepare the selected local content." if prework_available else "Local content is unavailable."
func update_prework(state: Dictionary) -> void:
	prework_clearing=str(state.get("message","")).begins_with("Clearing")
	prework_active=bool(state.get("active",false)); prework_prepare.disabled=not prework_available or prework_active
	prework_content.disabled=prework_active or not prework_available; prework_scope.disabled=prework_active
	prework_cancel.disabled=not prework_active; prework_clear.disabled=str(state.get("message","")).begins_with("Clearing")
	prework_progress.max_value=maxi(1,int(state.get("total",0))); prework_progress.value=int(state.get("completed",0))
	prework_status.text=str(state.get("message",""))
	if int(state.get("total",0))>0:
		prework_status.text+="\n%d / %d · Saved %d · Reused %d · Unavailable %d"%[int(state.get("completed",0)),int(state.total),int(state.get("saved",0)),int(state.get("reused",0)),int(state.get("failed",0))]
	if state.has("workers"):
		prework_status.text+="\n%d workers · %d active · %.1f items/s"%[int(state.workers),int(state.get("running",0)),float(state.get("items_per_second",0.0))]
		if int(state.get("rejection_hits",0))>0: prework_status.text+=" · %d known issues skipped"%int(state.rejection_hits)
	if state.has("last_error"):
		var model:=str(state.get("last_error_model","")); var route:=str(state.get("last_error_route",""))
		prework_status.text+="\nLast issue"+(" · "+model+(" ["+route+"]" if not route.is_empty() else "") if not model.is_empty() else "")+": "+str(state.last_error).left(180)
	prework_status.tooltip_text=prework_status.text
	if state.has("diagnostics_path"): prework_status.tooltip_text+="\nFull model diagnostics: "+str(state.diagnostics_path)
	update_preparation_controls()
	call_deferred("_clamp")
func update_ui_preload(state: Dictionary) -> void:
	ui_preload_active=bool(state.get("active",false)); update_preparation_controls()
	ui_preload_progress.max_value=maxi(1,int(state.get("total",0))); ui_preload_progress.value=int(state.get("completed",0))
	ui_preload_status.text=str(state.get("message",""))
	if int(state.get("total",0))>0:
		ui_preload_status.text+="\n%d / %d resources · Saved %d images · Reused %d\nUnavailable %d · %.1f s"%[int(state.get("completed",0)),int(state.total),int(state.get("saved",0)),int(state.get("reused",0)),int(state.get("failed",0)),float(state.get("elapsed_ms",0))/1000.0]
	if not ui_preload_active and not state.get("issues",[]).is_empty():
		for problem in state.issues: ui_preload_status.text+="\n"+str(problem)
	elif state.has("last_error"): ui_preload_status.text+="\nLast issue: "+str(state.last_error).left(240)
	ui_preload_status.tooltip_text=ui_preload_status.text
	call_deferred("_clamp")
func persist(key: String,value: Variant) -> void:
	if preference_path.is_empty(): return
	var config:=ConfigFile.new(); config.load(preference_path); config.set_value("rendering",key,value); config.save(preference_path)
func update_performance(profile: Dictionary) -> void:
	if not visible: return
	var lines: Array[String]=["Particles: "+("on" if particles_enabled else "off")]
	lines.append("Particle collision: "+("on" if particle_collision_enabled else "off"))
	if profile.is_empty() or not profile.get("enabled",true): lines.append("Detailed profiling is off.")
	elif profile.get("pending",false): lines.append("Collecting frame statistics…")
	else:
		var metrics: Dictionary=profile.get("metrics",{})
		for row in [["wall_ms","Frame interval"],["callback_envelope_ms","Frame callbacks"],["callback_particles","Particles (including bookkeeping)"],["callback_rigs","Creature/model animation"],["callback_assets","Asset completion / publication"],["callback_ui","UI presentation"],["callback_environment","Environment / weather"],["callback_lights","Light/shadow selection"],["profiler_record_ms","Profiler record overhead"],["profiler_summary_ms","Profiler summaries"],["unattributed_callback_ms","Unattributed callback time"],["outside_callback_ms","Outside callback interval"],["render_cpu_ms","Render CPU"],["render_gpu_ms","Render GPU"]]:
			if metrics.has(row[0]): lines.append("%s: %.2f ms (p95 %.2f)"%[row[1],float(metrics[row[0]].mean),float(metrics[row[0]].p95)])
		for row in [["render_setup_cpu_ms","Render setup CPU"],["postdraw_render_frame_wall_ms","Rendering frame interval"]]:
			if metrics.has(row[0]): lines.append("%s: %.2f ms (p95 %.2f)"%[row[1],float(metrics[row[0]].mean),float(metrics[row[0]].p95)])
		lines.append("Full breakdown, memory and queue counts are in the session log.")
	performance.text="\n".join(lines)
