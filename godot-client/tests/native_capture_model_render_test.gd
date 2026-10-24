extends SceneTree
const Capture=preload("res://systems/native_data/capture_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Instance=preload("res://systems/native_render/model_instance.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value: failures.append(reason)
func frame() -> void:
	await process_frame; await RenderingServer.frame_post_draw
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("fixture") or FileAccess.file_exists(args.report) or DisplayServer.get_name()=="headless": quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var catalog:=Capture.new()
	check(catalog.mount(fixture.capture,"context-1",[fixture.supplement]),"Native original capture mount: "+catalog.failure)
	root.size=Vector2i(960,720); var host:=Node3D.new(); root.add_child(host)
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.02,0.03,0.04); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=0.7; host.add_child(environment)
	var light:=DirectionalLight3D.new(); host.add_child(light); light.rotation_degrees=Vector3(-50,-30,0)
	var camera:=Camera3D.new(); host.add_child(camera); camera.position=Vector3(18,16,20); camera.look_at(Vector3(0,2,0)); camera.current=true
	var service:=Assets.new(); host.add_child(service); service.configure(catalog); service.cache_directory=OS.get_temp_dir().path_join("nwn-native-capture-gpu-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var pool:=Pool.new(); var received: Array=[]; var observations: Array=[]; service.completed.connect(func(_id,result): received.append(result))
	for sample in fixture.samples:
		service.request(sample.name,2002,"static-model")
		var deadline:=Time.get_ticks_msec()+30000
		while received.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		check(not received.is_empty(),"Original captured model preparation finishes")
		if received.is_empty(): break
		var result: Dictionary=received.pop_front()
		check(str(result.error).is_empty(),"Original ASCII model and all original textures prepare natively: "+str(result.error))
		if not str(result.error).is_empty(): continue
		check(int(result.thread)!=OS.get_main_thread_id() and result.value.format=="ASCII MDL" and result.sha256==sample.sha256,"Native worker selects and decodes original ASCII, retaining its source hash")
		var model:=Instance.new(); host.add_child(model)
		check(model.install(result,pool),"Direct native captured-model publication: "+model.failure)
		check(model.meshes.size()>10,"Original captured room model has its actual geometry")
		await frame(); await frame()
		var image:=root.get_texture().get_image(); var visible:=0
		for y in range(0,image.get_height(),4):
			for x in range(0,image.get_width(),4):
				var color:=image.get_pixel(x,y)
				if color.r>0.06 or color.g>0.07 or color.b>0.08: visible+=1
		check(visible>500,"Original captured ASCII geometry and textures are visibly rendered")
		image.save_png(str(args.report).trim_suffix(".json")+"-"+str(sample.name)+".png")
		observations.append({"name":sample.name,"source_sha256":result.sha256,"meshes":model.meshes.size(),"textures":result.textures.size(),"limitations":model.limitations.duplicate(),"visible_samples":visible})
		model.retire(); await frame(); await frame()
	service.close(); check(service.running.is_empty() and service.pending.is_empty(),"Captured model workers drain on close")
	pool.clear(); host.free(); await frame(); await frame()
	var hashes: Dictionary={}
	for folder in ["native_data","native_render"]:
		for name in DirAccess.get_files_at("res://systems/"+folder):
			if name.ends_with(".gd"): hashes["systems/"+folder+"/"+name]=FileAccess.get_sha256("res://systems/"+folder+"/"+name)
	hashes["tests/native_capture_model_render_test.gd"]=FileAccess.get_sha256("res://tests/native_capture_model_render_test.gd")
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"complete_migration":false,"scope":"Functional original captured ASCII model/texture rendering, no JS/network; full world, lighting/animation/effects still incomplete; not a performance test","models":observations,"sourceSha256":hashes}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
