extends "res://tests/native_surface_output_cost_test.gd"
const LiveWorld=preload("res://systems/native_render/live_world.gd")
const Area=preload("res://systems/area_environment.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
func run() -> void:
	var report:="";var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg.begins_with("--install="):install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	root.size=Vector2i(1920,1080);root.msaa_3d=Viewport.MSAA_DISABLED;Engine.max_fps=0
	var catalog:=Catalog.new();check(catalog.mount_install(install),"Original profile mounts for native tonal cost fixture")
	var world:=LiveWorld.new();world.catalog=catalog;world.set_meta("native_surface_output",true);world.set_meta("native_enhanced_lighting",true);root.add_child(world);world.set_process(false)
	var focus=world.focus_lighting;focus.set_process(false);focus.enable_history(128)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,20,35);camera.look_at(Vector3.ZERO);camera.fov=75;camera.current=true
	var area:=Area.new();world.add_child(area);area.configure({},world);area.camera=camera;area.set_process(false)
	var fields:={"98":0,"9c":0,"a0":0,"a4":0,"a8":false,"b8":0x110a08,"bc":0x050e18,"c0":0x664422,"c4":28,"c8":false,"cc":0,"d0":-1,"d4":0,"d8":true,"dc":false,"e0":0,"104":0,"108":45}
	check(area.receive({"revision":1,"state":{"fields":fields,"time":{"timeOfDay":1,"transition":0},"minutesPerHour":1,"elapsed":0}}),"Actual area colors prepare")
	for n in 128:
		var light:=PointLight.new();light.set_meta("native_enhanced_light",true);light.configure({"color":[.3,.4,.5],"radius":4,"fadinglight":0});world.add_child(light);light.position=Vector3(float(n%16)-8,2,float(n/16)-4);light.force_update_transform()
	for n in 15:area.advance(0);focus.history_frame(.1)
	var gamma:=Gamma.new();root.add_child(gamma);gamma.attach(camera);gamma.effect.set_surface_output(true)
	var options:={"mask":28,"midpoint":.4,"intensity":.35,"vibrance":.7}
	var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true);var runs: Array=[]
	for count in [32,128]:
		focus.history_maximum=count
		for n in 15:focus.history_frame(1)
		for tonal in [false,true,true,false]:
			if tonal:check(gamma.configure_postprocess(world,area,options),"Actual native scene tonal mode configures")
			else:gamma.clear_postprocess()
			await frames(90)
			var before: Dictionary=gamma.snapshot();var gpu: Array=[];var cpu: Array=[];var wall: Array=[];var previous:=Time.get_ticks_usec()
			for n in 240:
				await process_frame;var now:=Time.get_ticks_usec();wall.append((now-previous)/1000.0);previous=now;gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
			var after: Dictionary=gamma.snapshot();var sampled: int=int(after.scene_inputs.frames)-int(before.scene_inputs.frames)
			check(after.failure.is_empty() and after.scene_inputs.error.is_empty() and (not tonal or after.postprocess_lights==count),"Measured window retains its exact native admitted-light input")
			runs.append({"lights":count,"tonal":tonal,"gpu_ms":distribution(gpu),"render_cpu_ms":distribution(cpu),"wall_ms":distribution(wall),"scene_input_frames":sampled,"scene_input_mean_ms":(float(after.scene_inputs.total_ms)-float(before.scene_inputs.total_ms))/sampled if sampled>0 else 0.0,"state":after})
	check(float(runs[0].gpu_ms.mean)>0 and float(runs[0].render_cpu_ms.mean)>0,"Actual GPU and render-thread timestamps captured")
	RenderingServer.viewport_set_measure_render_time(viewport,false);gamma.free();world.close();world.free();await frames(3)
	check(Palette.active.is_empty(),"All tonal cost-fixture light ownership retires")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"runs":runs,"resolution":[1920,1080],"publicConnections":0,"scope":"Paired ABBA actual-world native final-output versus added dynamic contrast/vibrance/Gamma, 32/128 admitted lamps and real per-frame main-thread snapshot plus one GPU midpoint invocation. Background-only scene, no meshes/shadows/particles/streaming or matched-room FPS acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
