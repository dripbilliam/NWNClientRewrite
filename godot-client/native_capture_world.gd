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
var label: Label
var closing:=false
var loaded:=false
var frames:=0
var started:=0
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
	var overlay:=CanvasLayer.new(); host.add_child(overlay); label=Label.new(); overlay.add_child(label); label.position=Vector2(12,12)
	label.add_theme_color_override("font_shadow_color",Color.BLACK); label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	label.text="Opening original captured resources…"; await process_frame
	if not catalog.mount(data.capture,data.context,data.supplements): failed(catalog.failure); return
	if catalog.events_sha256!=data.eventsSha256: failed("Decoded protocol input belongs to another capture"); return
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
	terrain=Terrain.new(); terrain.use_terrain_batches=false; host.add_child(terrain); terrain.open_network_area(catalog,data.area,pool,cache_path)
	objects=Objects.new(); host.add_child(objects); objects.configure(catalog,pool,data.objects,int(data.area.id),cache_path)
	creatures=Creatures.new(); host.add_child(creatures); creatures.configure(catalog,pool,data.objects,int(data.area.id),cache_path)
func failed(reason: String) -> void:
	report.failure=reason; report.success=false
	if is_instance_valid(label): label.text=reason
	if args.has("report"): shutdown()
func tick() -> void:
	if closing or not is_instance_valid(terrain) or not is_instance_valid(objects) or not is_instance_valid(creatures): return
	label.text="%.1f FPS · %d/%d terrain · %d/%d static objects\n%d/%d creatures · %d/%d ground items · native original models/animation\nEffects, dynamic overrides and live campaign integration pending\nMiddle drag: orbit · wheel: zoom · WASD: inspection camera" % [Engine.get_frames_per_second(),terrain.completed_tiles,data.area.tiles.size(),objects.stats.rendered,objects.stats.planned,creatures.stats.rendered_creatures,creatures.stats.planned_creatures,creatures.stats.rendered_items,creatures.stats.planned_items]
	if not loaded and terrain.done and objects.done and creatures.done:
		loaded=true; report.terrain=terrain.snapshot(); report.objects=objects.stats.duplicate(true); report.actors=creatures.snapshot(); report.resources=pool.stats.duplicate(); report.environment=environment.snapshot(); report.success=report.terrain.success and report.objects.errors.is_empty() and report.actors.errors.is_empty() and report.actors.planned_creatures==report.actors.rendered_creatures and report.actors.planned_items==report.actors.rendered_items and bool(report.environment_accepted)
		if args.has("report"):
			for id in creatures.actors: before_poses[id]=creatures.actors[id].rigs.diagnostic_sample([id])
	if not loaded and args.has("report") and Time.get_ticks_msec()-started>120000:
		report.terrain=terrain.snapshot(); report.objects=objects.stats.duplicate(true); report.actors=creatures.snapshot(); failed("Native world preparation exceeded functional-test timeout"); return
	if loaded:
		frames+=1
		if int(args.get("frames",0))>0 and frames>=int(args.frames): shutdown()
func shutdown() -> void:
	if closing: return
	closing=true
	if is_instance_valid(light_budget): report.model_lights={"lights":light_budget.lights,"shadow_budget":light_budget.maximum,"active_shadows":light_budget.active}
	if args.has("report") and loaded: root.get_texture().get_image().save_png(str(args.report).trim_suffix(".json")+".png")
	if loaded and is_instance_valid(creatures):
		report.character_animation=[]
		for id in before_poses:
			if creatures.actors.has(id): report.character_animation.append({"id":id,"delta":creatures.actors[id].rigs.compare_samples(before_poses[id],creatures.actors[id].rigs.diagnostic_sample([id]))})
	if is_instance_valid(terrain): terrain.close()
	if is_instance_valid(objects): objects.close()
	if is_instance_valid(creatures): creatures.close()
	before_poses.clear()
	await process_frame; await process_frame; pool.clear()
	if is_instance_valid(host): host.free()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	report.frames=frames; report.worker_tasks_remaining=0
	if args.has("report"):
		var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	quit(0 if report.success else 1)
