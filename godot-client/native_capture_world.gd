extends SceneTree
# Native world assembly from raw protocol-state fixtures and original assets.
# No JS rendering, GLB import, scene export or public/server connection.
const Capture=preload("res://systems/native_data/capture_catalog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Terrain=preload("res://systems/native_render/area_stream.gd")
const Objects=preload("res://systems/native_render/object_stream.gd")
const Creatures=preload("res://systems/native_render/creature_stream.gd")
const CameraController=preload("res://systems/camera_controller.gd")
const AreaEnvironment=preload("res://systems/area_environment.gd")
const LightBudget=preload("res://systems/native_render/model_light_budget.gd")
const ReferenceAssets=preload("res://systems/native_render/reference_assets.gd")
const ParticleRandom=preload("res://systems/native_render/particle_random.gd")
const ParticleVisibility=preload("res://systems/native_render/particle_visibility.gd")
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
const CaptureSetup=preload("res://systems/native_data/capture_setup.gd")
var args: Dictionary={}
var data: Dictionary={}
var catalog:=Capture.new()
var pool:=Pool.new()
var host: Node3D
var terrain
var objects
var creatures
var before_poses: Dictionary={}
var environment
var light_budget
var references
var frame_profile
var capture_setup
var point_wind
var label: Label
var closing:=false
var loaded:=false
var frames:=0
var started:=0
var last_frame_usec:=0
var loading_frames:=PackedFloat64Array()
var settled_frames:=PackedFloat64Array()
var report: Dictionary={"success":false,"native_rendering":true,"complete_migration":false,"world_complete":false,"scope":"Native captured world/actors from original assets; complete effects, dynamic overrides and live campaign integration pending; no network or performance acceptance"}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	auto_accept_quit=false; root.close_requested.connect(shutdown); process_frame.connect(tick)
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("input") or not args.has("input-sha256") or (args.has("report") and FileAccess.file_exists(args.report)): quit(2); return
	if FileAccess.get_sha256(args.input)!=args["input-sha256"]: quit(2); return
	var decoded: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.input))
	if not decoded is Dictionary or decoded.get("version")!=1: quit(2); return
	data=decoded; report.input_sha256=args["input-sha256"]
	started=Time.get_ticks_msec()
	host=Node3D.new(); root.add_child(host)
	var particle_visibility:=ParticleVisibility.new(); host.add_child(particle_visibility); particle_visibility.set_enabled(args.get("particles","off")=="on"); report.particles_enabled=particle_visibility.enabled
	frame_profile=FrameProfile.new(); host.add_child(frame_profile); frame_profile.configure(root)
	var overlay:=CanvasLayer.new(); host.add_child(overlay); label=Label.new(); overlay.add_child(label); label.position=Vector2(12,12)
	label.add_theme_color_override("font_shadow_color",Color.BLACK); label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	label.text="Opening original captured resources…"; await process_frame
	capture_setup=CaptureSetup.new(); host.add_child(capture_setup)
	var prepared: Dictionary={}
	capture_setup.completed.connect(func(value,error,stats):prepared.merge({"catalog":value,"error":error,"stats":stats}))
	capture_setup.start(data,str(args.get("source-supplement","")),str(args.get("source-supplement-sha256","")))
	while prepared.is_empty() and not closing: await process_frame
	if closing: return
	if not str(prepared.error).is_empty(): failed(prepared.error); return
	catalog=prepared.catalog; report.native_catalog=prepared.stats
	var view: Dictionary=data.view; root.size=Vector2i(view.buffer[0],view.buffer[1])
	var camera:=Camera3D.new(); host.add_child(camera); camera.position=Vector3(view.position[0],view.position[1],view.position[2]); camera.quaternion=Quaternion(view.quaternion[0],view.quaternion[1],view.quaternion[2],view.quaternion[3]).normalized(); camera.fov=float(view.fov); camera.near=float(view.near); camera.far=float(view.far); camera.current=true
	var controller:=CameraController.new(); host.add_child(controller); controller.configure(camera,Vector3(view.target[0],view.target[1],view.target[2]))
	light_budget=LightBudget.new(); host.add_child(light_budget); light_budget.camera=camera
	var requested: Variant=view.get("shadowLights")
	light_budget.maximum=int(requested) if requested is int or requested is float else 0
	environment=AreaEnvironment.new(); host.add_child(environment); environment.configure({},host); environment.camera=camera; environment.controller=controller
	var fields: Dictionary=data.area.fields.duplicate(true)
	for key in fields:
		if fields[key] is bool: fields[key]=1 if fields[key] else 0
	var minutes:=float(data.module.get("minutesPerHour",0)); var clock: Dictionary=data.time
	report.environment_accepted=environment.receive({"revision":1,"state":{"fields":fields,"time":{"timeOfDay":clock.timeOfDay,"transition":clock.get("transition",0)},"minutesPerHour":minutes,"elapsed":float(clock.get("transition",0))/1000.0}})
	var cache_path:=ProjectSettings.globalize_path("user://native-prepared-v2")
	point_wind=preload("res://systems/native_render/scene_point_wind.gd").new(); host.add_child(point_wind); host.set_meta("native_point_wind_owner",point_wind)
	references=ReferenceAssets.new(); host.add_child(references); references.configure(catalog,pool,cache_path); host.set_meta("native_reference_hub",references); host.set_meta("native_particle_random",ParticleRandom.new())
	terrain=Terrain.new(); terrain.use_terrain_batches=false; host.add_child(terrain); terrain.open_network_area(catalog,data.area,pool,cache_path)
	objects=Objects.new(); host.add_child(objects); objects.configure(catalog,pool,data.objects,int(data.area.id),cache_path)
	creatures=Creatures.new(); host.add_child(creatures); creatures.configure(catalog,pool,data.objects,int(data.area.id),cache_path)
func failed(reason: String) -> void:
	report.failure=reason; report.success=false
	if is_instance_valid(label): label.text=reason
	if args.has("report"): shutdown()
func tick() -> void:
	if is_instance_valid(frame_profile): frame_profile.start_frame()
	var began:=FrameProfile.begin(); _profile_tick(); FrameProfile.finish("callback_root",began)
func _profile_tick() -> void:
	if closing or not is_instance_valid(terrain) or not is_instance_valid(objects) or not is_instance_valid(creatures): return
	var now:=Time.get_ticks_usec()
	if last_frame_usec>0:
		var elapsed:=(now-last_frame_usec)/1000.0
		if loaded: settled_frames.append(elapsed)
		else: loading_frames.append(elapsed)
	last_frame_usec=now
	label.text="%.1f FPS · %d/%d terrain · %d/%d static objects\n%d/%d creatures · %d/%d ground items · native original models/animation\nEffects, dynamic overrides and live campaign integration pending\nMiddle drag: orbit · wheel: zoom · WASD: inspection camera" % [Engine.get_frames_per_second(),terrain.completed_tiles,data.area.tiles.size(),objects.stats.rendered,objects.stats.planned,creatures.stats.rendered_creatures,creatures.stats.planned_creatures,creatures.stats.rendered_items,creatures.stats.planned_items]
	if not loaded and terrain.done and objects.done and creatures.done and references.ready():
		report.preparation_ms=Time.get_ticks_msec()-started
		loaded=true; report.terrain=terrain.snapshot(); report.objects=objects.stats.duplicate(true); report.actors=creatures.snapshot(); report.resources=pool.stats.duplicate(); report.environment=environment.snapshot(); report.success=report.terrain.success and report.objects.errors.is_empty() and report.actors.errors.is_empty() and report.actors.planned_creatures==report.actors.rendered_creatures and report.actors.planned_items==report.actors.rendered_items and bool(report.environment_accepted)
		report.references=references.snapshot()
		if args.has("report"):
			for id in creatures.actors: before_poses[id]=creatures.actors[id].rigs.diagnostic_sample([id])
		# GPU readback above is a functional diagnostic; exclude its blocking
		# time from settled frame intervals and retain preparation separately.
		last_frame_usec=Time.get_ticks_usec()
	if not loaded and args.has("report") and Time.get_ticks_msec()-started>120000:
		report.terrain=terrain.snapshot(); report.objects=objects.stats.duplicate(true); report.actors=creatures.snapshot(); failed("Native world preparation exceeded functional-test timeout"); return
	if loaded:
		frames+=1
		if int(args.get("frames",0))>0 and frames>=int(args.frames): shutdown()
func shutdown() -> void:
	if closing: return
	closing=true
	if is_instance_valid(capture_setup): capture_setup.close()
	if is_instance_valid(frame_profile): report.frame_profile=frame_profile.snapshot()
	report.native_particles={"emitters":0,"active":0,"vertices":0,"failed":0,"fused_simulated":0,"composed_simulated":0,"native_parameter_simulated":0,"gd_parameter_simulated":0,"constant_channel_hits":0,"sampled_channels":0,"diagnostics":{}}
	report.native_particles.merge({"culling_checks":0,"culled_frames":0,"culled_emitters":0,"currently_culled":0,"culling_fallbacks":0,"classification_counts":{},"resident_simulated":0})
	for emitter in get_nodes_in_group("native_original_particle_emitters"):
		if not is_instance_valid(host) or not host.is_ancestor_of(emitter): continue
		var sample: Dictionary=emitter.snapshot(); report.native_particles.emitters+=1; report.native_particles.active+=int(sample.active); report.native_particles.vertices+=int(sample.vertices)
		for field in ["culling_checks","culled_frames","culling_fallbacks"]: report.native_particles[field]+=int(sample[field])
		if int(sample.culled_frames)>0: report.native_particles.culled_emitters+=1
		if bool(sample.culled): report.native_particles.currently_culled+=1
		var classification:=str(sample.source_model_flags); report.native_particles.classification_counts[classification]=int(report.native_particles.classification_counts.get(classification,0))+1
		report.native_particles.constant_channel_hits+=int(sample.channel_cache.constant_hits); report.native_particles.sampled_channels+=int(sample.channel_cache.sampled_channels)
		if int(sample.frames)>0:
			if str(sample.backend)=="resident": report.native_particles.resident_simulated+=1
			var dispatch: String="fused_simulated" if bool(sample.fused_dispatch) else "composed_simulated"
			report.native_particles[dispatch]+=1
			var transfer: String="native_parameter_simulated" if bool(sample.native_parameter_transfer) else "gd_parameter_simulated"
			report.native_particles[transfer]+=1
		if not str(sample.failure).is_empty():
			report.native_particles.failed+=1; report.native_particles.diagnostics[sample.failure]=int(report.native_particles.diagnostics.get(sample.failure,0))+1
	if is_instance_valid(light_budget): report.model_lights={"lights":light_budget.lights,"shadow_budget":light_budget.maximum,"active_shadows":light_budget.active}
	if args.has("report") and loaded and DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(str(args.report).trim_suffix(".json")+".png")
	if loaded and is_instance_valid(creatures):
		report.character_animation=[]
		for id in before_poses:
			if creatures.actors.has(id): report.character_animation.append({"id":id,"delta":creatures.actors[id].rigs.compare_samples(before_poses[id],creatures.actors[id].rigs.diagnostic_sample([id]))})
	if is_instance_valid(terrain): terrain.close()
	if is_instance_valid(objects): objects.close()
	if is_instance_valid(creatures): creatures.close()
	if is_instance_valid(references): references.close()
	if is_instance_valid(point_wind): report.native_point_wind=point_wind.snapshot(); point_wind.close()
	catalog.close_sources()
	var workers_remaining:=0
	for stream in [terrain,objects,creatures,references]:
		if is_instance_valid(stream) and is_instance_valid(stream.assets): workers_remaining+=stream.assets.running.size()
	before_poses.clear()
	await process_frame; await process_frame; pool.clear()
	if is_instance_valid(host): host.free()
	await process_frame; await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	report.frames=frames; report.worker_tasks_remaining=workers_remaining; report.frame_intervals={"loading":frame_summary(loading_frames),"settled":frame_summary(settled_frames),"scope":"Wall-clock process-frame intervals, not GPU timings or clean benchmark. Settled samples exclude initial pose diagnostic readback; effects and live gameplay incomplete."}
	if args.has("report"):
		var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	quit(0 if report.success else 1)
func frame_summary(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty(): return {"count":0}
	var ordered:=values.duplicate(); ordered.sort(); var total:=0.0; var hitches:=0
	for value in values:
		total+=value
		if value>50: hitches+=1
	return {"count":values.size(),"average_ms":total/values.size(),"p95_ms":ordered[mini(ordered.size()-1,int(ceil(ordered.size()*0.95))-1)],"worst_ms":ordered[-1],"over_50ms":hitches}
