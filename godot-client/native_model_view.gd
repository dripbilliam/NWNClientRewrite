extends SceneTree
# Native-only resource review entry. No network session or JS process.
const Catalog = preload("res://systems/native_data/resource_catalog.gd")
const Assets = preload("res://systems/native_data/asset_service.gd")
const Pool = preload("res://systems/native_render/resource_pool.gd")
const Instance = preload("res://systems/native_render/model_instance.gd")
const CameraController = preload("res://systems/camera_controller.gd")
var catalog := Catalog.new()
var pool := Pool.new()
var service
var model
var host: Node3D
var label: Label
var args := {}
var loaded := false
var closing := false
var frames := 0
var start := 0
var report := {"scope":"Direct original-model native preview, not full-world/animation/multiplayer or performance acceptance","native_rendering":true,"complete_migration":false,"success":false}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	auto_accept_quit = false; root.close_requested.connect(shutdown); process_frame.connect(tick)
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or (args.has("report") and FileAccess.file_exists(args.report)): quit(2); return
	host = Node3D.new(); root.add_child(host)
	var overlay := CanvasLayer.new(); host.add_child(overlay); label = Label.new(); overlay.add_child(label); label.position=Vector2(12,12)
	label.add_theme_color_override("font_shadow_color",Color.BLACK); label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	label.text = "Loading original resources…"
	await process_frame
	start = Time.get_ticks_usec()
	if not catalog.mount_install(args.install): failed(catalog.failure); return
	report.index_ms = (Time.get_ticks_usec()-start)/1000.0
	var environment := WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.08,0.1,0.12); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=0.35; host.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-30,0); light.light_energy=0.9; host.add_child(light)
	service=Assets.new(); host.add_child(service); service.configure(catalog); service.cache_directory=ProjectSettings.globalize_path("user://native-prepared-v2")
	service.completed.connect(prepared)
	start = Time.get_ticks_usec()
	service.request(str(args.get("model","c_golstone")),2002,"static-model")
func prepared(_id: int, result: Dictionary) -> void:
	if closing: return
	if not str(result.error).is_empty(): failed(result.error); return
	model=Instance.new(); host.add_child(model)
	var begin := Time.get_ticks_usec()
	if not model.install(result,pool): failed(model.failure); return
	report.publish_ms = (Time.get_ticks_usec()-begin)/1000.0
	report.prepare_ms = result.worker_ms; report.load_ms=(Time.get_ticks_usec()-start)/1000.0; report.cache_hit=result.cache_hit; report.dependencies=result.dependencies; report.model_sha256=result.sha256; report.model=args.get("model","c_golstone"); report.limitations=model.limitations; report.meshes=model.meshes.size(); report.resources=pool.stats.duplicate()
	var camera := Camera3D.new(); camera.position=Vector3(8,6,10); host.add_child(camera); camera.look_at(Vector3(0,2,0)); camera.current=true
	var controller := CameraController.new(); host.add_child(controller); controller.configure(camera,Vector3(0,2,0))
	loaded=true; report.success=true
func tick() -> void:
	if closing or not loaded: return
	frames+=1
	label.text = "%.1f FPS · %s\nStatic native resource preview · middle drag: orbit · wheel: zoom\nFull world and animation migration remains incomplete" % [Engine.get_frames_per_second(),str(args.get("model","c_golstone"))]
	if int(args.get("frames",0))>0 and frames>=int(args.frames): shutdown()
func failed(reason: String) -> void:
	report.success=false; report.failure=reason
	if is_instance_valid(label): label.text=reason
	if args.has("report"): shutdown()
func shutdown() -> void:
	if closing: return
	closing=true
	if is_instance_valid(service): service.close()
	if is_instance_valid(model): model.retire()
	await process_frame; await process_frame
	pool.clear()
	if is_instance_valid(host): host.free()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	report.frames=frames; report.worker_tasks_remaining=0 if not is_instance_valid(service) else service.running.size()
	if args.has("report"):
		var file := FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	quit(0 if report.success else 1)
