extends SceneTree
const Settings=preload("res://systems/native_render_settings.gd")
const Switch=preload("res://systems/native_render/particle_visibility.gd")
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
const Metrics=preload("res://systems/native_render/particle_metrics.gd")
const Menu=preload("res://systems/native_main_menu.gd")
const Session=preload("res://native_session_world.gd")
var checks:=0
var failures: Array=[]
var report_path:=""
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point; event.global_position=point; root.push_input(event,true); await process_frame
func emitter(parent: Node3D) -> Node3D:
	var instance:=Emitter.new(); instance.source_path=NodePath(".."); instance.source_model_flags=0
	instance.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","birthrate":16,"lifeexp":1,"sizestart":0.1,"sizeend":0.1,"alphastart":1,"alphaend":1}
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE); instance.original_texture=ImageTexture.create_from_image(image)
	parent.add_child(instance); return instance
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path=arg.substr(9)
	if report_path.is_empty() or FileAccess.file_exists(report_path): quit(2); return
	root.size=Vector2i(1100,800)
	var scene:=Node3D.new(); root.add_child(scene)
	var metrics_owner:=Metrics.new(); scene.set_meta("native_particle_metrics",metrics_owner)
	var switch:=Switch.new(); scene.add_child(switch)
	var camera:=Camera3D.new(); scene.add_child(camera); camera.current=true; camera.position=Vector3(0,2,5); camera.look_at(Vector3.ZERO)
	var light:=OmniLight3D.new(); scene.add_child(light)
	var layer:=CanvasLayer.new(); root.add_child(layer)
	var settings:=Settings.new(); layer.add_child(settings); settings.setup(report_path+".cfg","")
	var menu:=Menu.new(); root.add_child(menu); menu.options_requested.connect(func(): settings.show())
	settings.particles_changed.connect(switch.set_enabled)
	settings.particle_collision_changed.connect(switch.set_collision_enabled)
	check(not settings.particles_enabled and not settings.particles_toggle.button_pressed and not switch.enabled,"Particles default off for both controls and newly streamed emitters")
	check(settings.particle_collision_enabled and settings.particle_collision_toggle.button_pressed and switch.collision_enabled,"Particle collision defaults on independently of particles defaulting off")
	menu.choose("options"); settings.move_to_front(); await process_frame; await process_frame
	check(settings.visible,"Main Menu Options opens the native settings panel")
	check(settings.gore==1 and settings.gore_select.selected==1,"Blood setting defaults to original Normal level")
	check(not settings.compact_scenery_enabled and not settings.compact_scenery_toggle.button_pressed,"Compact scenery defaults off in the Graphics tab")
	var compact_signals: Array=[]; settings.compact_scenery_changed.connect(func(on):compact_signals.append(on))
	await click(settings.compact_scenery_toggle.get_global_rect().get_center())
	check(settings.compact_scenery_enabled and compact_signals==[true],"Actual Graphics checkbox enables the experimental scenery option")
	var saved_compact:=Settings.new(); layer.add_child(saved_compact); saved_compact.setup(report_path+".cfg","")
	check(saved_compact.compact_scenery_enabled and saved_compact.compact_scenery_toggle.button_pressed,"Scenery preference survives reconstructing the menu")
	var explicit_separate:=Settings.new(); layer.add_child(explicit_separate); explicit_separate.setup(report_path+".cfg","",false,"separate")
	check(not explicit_separate.compact_scenery_enabled and saved_compact.compact_scenery_enabled,"Explicit diagnostic layout overrides the saved preference without changing it")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(report_path+".graphics.png")
	await click(settings.compact_scenery_toggle.get_global_rect().get_center())
	var compact_off:=Settings.new(); layer.add_child(compact_off); compact_off.setup(report_path+".cfg","")
	check(not settings.compact_scenery_enabled and not compact_off.compact_scenery_enabled and compact_signals==[true,false],"Disabling scenery compaction also persists and emits the requested policy")
	var explicit_compact:=Settings.new(); layer.add_child(explicit_compact); explicit_compact.setup(report_path+".cfg","",false,"compact")
	check(explicit_compact.compact_scenery_enabled and not compact_off.compact_scenery_enabled,"Explicit compact diagnostic overrides an off preference without saving it")
	settings.gore_select.select(2); settings.gore_select.item_selected.emit(2)
	var saved_gore:=Settings.new(); layer.add_child(saved_gore); saved_gore.setup(report_path+".cfg","")
	check(saved_gore.gore==2,"Full blood preference persists independently of particle visibility")
	await click(settings.particle_collision_toggle.get_global_rect().get_center())
	check(not settings.particle_collision_enabled and not switch.collision_enabled and not switch.enabled,"Collision checkbox works while particles are disabled")
	await click(settings.particles_toggle.get_global_rect().get_center())
	var first=emitter(scene); first.set_process(false); first.tick(0.2)
	check(not first.collision_enabled,"New emitter inherits collision preference before its first tick")
	check(first.failure.is_empty() and first.frames>0 and first.active_count()>0 and first.surface.vertex_count>0,"Actual native emitter simulates and draws before the toggle")
	await click(settings.particles_toggle.get_global_rect().get_center())
	var frozen: int=first.frames
	check(not settings.particles_enabled and not switch.enabled and not first.is_processing() and not first.is_visible_in_tree(),"Actual checkbox click stops simulation callbacks and hides particle drawing")
	first.tick(0.2); await process_frame; await process_frame
	check(first.frames==frozen and light.is_visible_in_tree() and camera.current,"Off pauses manual and automatic ticks while world lights and camera remain intact")
	var second=emitter(scene); var second_frames: int=second.frames; await process_frame; await process_frame
	check(not second.particles_enabled and not second.is_processing() and not second.visible and second.frames==second_frames,"Newly streamed particles inherit the disabled setting before their first tick")
	var restored:=Settings.new(); layer.add_child(restored); restored.setup(report_path+".cfg","")
	check(not restored.particles_enabled and not restored.particles_toggle.button_pressed,"Particle preference survives reconstructing the settings menu")
	check(not restored.particle_collision_enabled and not restored.particle_collision_toggle.button_pressed,"Collision preference persists independently of particle visibility")
	await click(settings.particle_collision_toggle.get_global_rect().get_center())
	check(first.collision_enabled and second.collision_enabled and not switch.enabled,"Collision can be restored on existing paused emitters")
	await click(settings.particles_toggle.get_global_rect().get_center()); await process_frame
	check(switch.enabled and first.is_processing() and second.is_processing() and first.is_visible_in_tree() and second.frames>second_frames,"Re-enabling resumes both existing and later emitters without reloading models")
	var profile:=Profile.new(); scene.add_child(profile); profile.configure(root)
	settings.profiling_changed.connect(profile.set_enabled)
	settings.tabs.current_tab=1; await process_frame
	var inspector_requests: Array=[]; settings.entity_inspector_requested.connect(func():inspector_requests.append(true))
	await click(settings.entity_inspector_button.get_global_rect().get_center()); await process_frame
	check(inspector_requests==[true],"Actual Performance-tab inspector button emits one local inspection request")
	await click(settings.profile_toggle.get_global_rect().get_center()); await process_frame
	check(profile.enabled and settings.profiling_enabled,"Performance tab enables detailed profiling from the UI")
	var forced_off:=Settings.new(); layer.add_child(forced_off); forced_off.setup(report_path+".cfg","",false,"","false")
	var persisted_on:=Settings.new(); layer.add_child(persisted_on); persisted_on.setup(report_path+".cfg","")
	check(not forced_off.profiling_enabled and not forced_off.profile_toggle.button_pressed and persisted_on.profiling_enabled,"Explicit clean-benchmark profiling override does not erase the saved on preference")
	await create_timer(0.12).timeout
	var summary:=profile.snapshot(); var summary_deadline:=Time.get_ticks_msec()+5000
	while summary.get("pending",false) and Time.get_ticks_msec()<summary_deadline:
		await process_frame; summary=profile.snapshot()
	var metrics: Dictionary=summary.get("metrics",{})
	check(summary.enabled and summary.frames>0 and metrics.has("callback_particles") and metrics.has("native_particle_dispatch") and metrics.has("native_particle_metrics"),"Particle callback timing includes native calls and bookkeeping")
	check(metrics.has("unattributed_callback_ms") and metrics.has("outside_callback_ms") and metrics.has("profiler_collect_ms") and metrics.has("profiler_record_ms"),"Frame accounting exposes unattributed time and profiler self-work")
	check(metrics.has("video_memory_bytes") and metrics.has("memory_static_bytes") and metrics.has("resources") and metrics.has("orphan_nodes"),"CPU/GPU memory and object lifecycle counters are reported")
	check(profile.rows.all(func(row): return absf(float(row.accounted_callback_ms)+float(row.unattributed_callback_ms)-float(row.callback_overlap_ms)-float(row.callback_envelope_ms))<0.001),"Callback accounting closes without hiding overlaps")
	var periodic:=Profile.new(); periodic.worker_statistics=false; periodic.rows=[{"wall_ms":1.0,"periodic_work_ms":3.0},{"wall_ms":1.0},{"wall_ms":1.0}]
	var periodic_metrics: Dictionary=periodic.snapshot().metrics
	check(periodic_metrics.periodic_work_ms.mean==1.0 and periodic_metrics.periodic_work_ms.when_present_mean==3.0 and periodic_metrics.periodic_work_ms.samples==3 and periodic_metrics.periodic_work_ms.active_samples==1,"Periodic work is averaged across all frames, with conditional cost separately identified")
	periodic.free()
	settings.update_performance(summary)
	check(settings.performance.text.contains("Unattributed") and settings.performance.text.contains("Render GPU"),"Performance tab displays the measured frame breakdown")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(report_path+".png")
	await click(settings.profile_toggle.get_global_rect().get_center())
	check(not profile.enabled and profile.snapshot()=={"enabled":false},"Profiling can be stopped without restarting or continuing detailed measurements")
	var restored_profile:=Settings.new(); layer.add_child(restored_profile); restored_profile.setup(report_path+".cfg","")
	check(not restored_profile.profiling_enabled,"Profiling preference persists independently of particle visibility")
	settings.tabs.current_tab=2; await process_frame
	check(not settings.creature_slots and not settings.creature_toggle.button_pressed,"Creature slots default off and are configured in Options Interface")
	await click(settings.creature_toggle.get_global_rect().get_center())
	var restored_interface:=Settings.new(); layer.add_child(restored_interface); restored_interface.setup(report_path+".cfg","")
	check(settings.creature_slots and restored_interface.creature_slots,"The Options creature-slot preference persists independently")
	var count: int=switch.snapshot().registered
	first.queue_free(); second.queue_free(); await process_frame; await process_frame
	check(count==2 and switch.snapshot().registered==0,"Particle visibility owner releases retired emitter registrations")
	var config:=ConfigFile.new(); config.set_value("rendering","particles_enabled","invalid"); config.set_value("rendering","particle_collision_enabled","invalid"); config.set_value("rendering","compact_scenery","invalid"); config.save(report_path+".invalid.cfg")
	var invalid:=Settings.new(); layer.add_child(invalid); invalid.setup(report_path+".invalid.cfg","")
	check(not invalid.particles_enabled,"Malformed saved values safely retain particles off")
	check(invalid.particle_collision_enabled,"Malformed collision preference retains the original default on")
	check(not invalid.compact_scenery_enabled,"Malformed scenery preference retains the conservative default off")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"profile":summary,"publicConnections":0,"scope":"Actual native graphics checkbox/input, streaming inheritance, persistence and callback frame accounting; no clean FPS acceptance"}
	layer.free(); menu.free(); scene.free(); await process_frame
	var file:=FileAccess.open(report_path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
