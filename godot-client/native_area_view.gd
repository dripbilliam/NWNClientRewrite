extends SceneTree
# Native-only original terrain entry. Protocol/gameplay migration is separate.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Stream=preload("res://systems/native_render/area_stream.gd")
const CameraController=preload("res://systems/camera_controller.gd")
var args: Dictionary={}
var pool:=Pool.new()
var catalog
var host: Node3D
var stream
var camera: Camera3D
var controller
var label: Label
var mounted: Dictionary={}
var mutex:=Mutex.new()
var mount_task: int=-1
var closing:=false
var loaded:=false
var frames:=0
var began:=0
var report: Dictionary={"native_rendering":true,"success":false,"complete_migration":false,"scope":"Native terrain preview only; no JS/network, actors, effects or full-world FPS acceptance"}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	auto_accept_quit=false; root.close_requested.connect(shutdown); process_frame.connect(tick)
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("module") or not args.has("area") or (args.has("report") and FileAccess.file_exists(args.report)): quit(2); return
	host=Node3D.new(); root.add_child(host)
	var overlay:=CanvasLayer.new(); host.add_child(overlay); label=Label.new(); overlay.add_child(label); label.position=Vector2(12,12)
	label.add_theme_color_override("font_shadow_color",Color.BLACK); label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	label.text="Indexing original resources on native worker…"
	began=Time.get_ticks_usec(); mount_task=WorkerThreadPool.add_task(mount_originals,false,"Native original catalog")
	while mount_task!=-1 and not WorkerThreadPool.is_task_completed(mount_task): await process_frame
	if closing: return
	WorkerThreadPool.wait_for_task_completion(mount_task); mount_task=-1
	mutex.lock(); var result:=mounted; mounted={}; mutex.unlock()
	report.index_ms=(Time.get_ticks_usec()-began)/1000.0; report.index_thread=result.thread
	if not str(result.error).is_empty(): failed(result.error); return
	catalog=result.catalog
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.06,0.08,0.1); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=0.7; host.add_child(environment)
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-50,-30,0); host.add_child(light)
	stream=Stream.new(); host.add_child(stream); stream.pool=pool
	stream.progress.connect(area_progress); stream.finished.connect(area_finished)
	stream.open_area(catalog,args.area,pool,ProjectSettings.globalize_path("user://native-prepared-v2"))
func mount_originals() -> void:
	var source:=Catalog.new(); var okay:=source.mount_install(args.install) and source.mount_erf(args.module,4000000)
	var result: Dictionary={"catalog":source,"error":"" if okay else source.failure,"thread":OS.get_thread_caller_id()}
	mutex.lock(); mounted=result; mutex.unlock()
func area_progress(state: Dictionary) -> void:
	if closing: return
	if camera==null:
		var center:=Vector3(stream.definition.width*5,0,-stream.definition.height*5)
		var distance:=maxf(stream.definition.width,stream.definition.height)*10
		camera=Camera3D.new(); camera.far=maxf(500,distance*4); camera.position=center+Vector3(distance,distance,distance); host.add_child(camera); camera.look_at(center); camera.current=true
		controller=CameraController.new(); host.add_child(controller); controller.configure(camera,center)
	label.text="%.1f FPS · Preparing native terrain %d / %d\nOriginal-resource preview · actors/effects/gameplay remain incomplete" % [Engine.get_frames_per_second(),state.rendered_tiles,state.tiles]
func area_finished(state: Dictionary) -> void:
	if closing: return
	report.area=state; report.resources=pool.stats.duplicate(); report.success=state.success
	if not state.success: failed(JSON.stringify(state.errors)); return
	report.are_sha256=stream.definition.are_sha256; report.set_sha256=stream.definition.set_sha256; loaded=true
func failed(reason: String) -> void:
	report.success=false; report.failure=reason
	if is_instance_valid(label): label.text=reason
	if args.has("report"): shutdown()
func tick() -> void:
	if closing or not loaded: return
	frames+=1
	label.text="%.1f FPS · %s · %d tiles\nNative terrain preview · middle drag: orbit · wheel: zoom\nFixed review lighting · actors/effects/gameplay migration incomplete" % [Engine.get_frames_per_second(),args.area,stream.instances.size()]
	if int(args.get("frames",0))>0 and frames>=int(args.frames): shutdown()
func shutdown() -> void:
	if closing: return
	closing=true
	if mount_task!=-1: WorkerThreadPool.wait_for_task_completion(mount_task); mount_task=-1
	mutex.lock(); mounted={}; mutex.unlock()
	if is_instance_valid(stream): stream.close()
	await process_frame; await process_frame; pool.clear()
	if is_instance_valid(host): host.free()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	report.frames=frames; report.worker_tasks_remaining=0 if not is_instance_valid(stream) else stream.assets.running.size()
	if args.has("report"):
		var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	quit(0 if report.success else 1)
