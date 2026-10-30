extends "res://systems/draggable_panel.gd"
signal particles_changed(value: bool)
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
	var value: Variant=config.get_value("rendering","particles_enabled",false)
	particles_enabled=value if value is bool else false
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
	tabs=built.nodes.tabs
	particles_toggle=built.nodes.particles_toggle
	particle_collision_toggle=built.nodes.particle_collision_toggle
	gore_select=built.nodes.gore_select
	compact_scenery_toggle=built.nodes.compact_scenery_toggle
	profile_toggle=built.nodes.profile_toggle
	entity_inspector_button=built.nodes.entity_inspector_button
	built.nodes.login_profiles_button.pressed.connect(func():login_profiles_requested.emit())
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
	particle_collision_toggle.set_pressed_no_signal(particle_collision_enabled)
	compact_scenery_toggle.set_pressed_no_signal(compact_scenery_enabled)
	profile_toggle.set_pressed_no_signal(profiling_enabled); creature_toggle.set_pressed_no_signal(creature_slots)
	gore_select.select(gore); prework_workers.select(prework_workers.get_item_index(prework_worker_setting))
	for control in [prework_clear,prework_folder]: control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	particles_toggle.toggled.connect(func(on): particles_enabled=on; persist("particles_enabled",on); particles_changed.emit(on))
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
