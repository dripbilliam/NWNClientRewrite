extends "res://tests/native_enhanced_lighting_pixels_test.gd"
const Gamma=preload("res://systems/native_render/native_gamma.gd")
func distribution(values: Array) -> Dictionary:
	var ordered:=values.duplicate(); ordered.sort(); var sum:=0.0
	for value in ordered: sum+=float(value)
	return {"mean":sum/ordered.size(),"median":ordered[ordered.size()/2],"p95":ordered[ceili(ordered.size()*.95)-1],"maximum":ordered.back(),"samples":ordered.size()}
func frames(count: int) -> void:
	for frame in count: await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(1920,1080); root.msaa_3d=Viewport.MSAA_DISABLED; Engine.max_fps=0
	var world:=Node3D.new(); root.add_child(world); world.add_child(Palette.new())
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color.BLACK; environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.BLACK; environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR; world.add_child(environment)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4; camera.make_current()
	var gamma:=Gamma.new(); world.add_child(gamma); gamma.attach(camera)
	var surface:=MeshInstance3D.new(); var quad:=QuadMesh.new(); quad.size=Vector2(8,4); surface.mesh=quad; world.add_child(surface)
	var source:=StandardMaterial3D.new(); var material:=NativeMaterial.new(); material.configure(source,[1,1,1],[0,0,0],true,2); surface.material_override=material
	Palette.ambient(Vector3(.001,.002,.003)); Palette.environment(null)
	var lights: Array=[]
	for n in 32:
		var light:=PointLight.new(); light.set_meta("native_enhanced_light",true); light.configure({"color":[.07,.1,.15],"radius":20}); world.add_child(light); light.position=Vector3((n%3-1)*.7,0,2); light.force_update_transform(); lights.append(light)
	Palette.flush()
	var viewport:=root.get_viewport_rid(); RenderingServer.viewport_set_measure_render_time(viewport,true)
	var runs: Array=[]
	for count in [1,8,32]:
		for n in lights.size(): lights[n].visible=n<count
		for native_output in [false,true,true,false]:
			material.native_surface_output=native_output; gamma.effect.set_surface_output(native_output)
			await frames(90)
			var gpu: Array=[]; var cpu: Array=[]; var setup: Array=[]; var wall: Array=[]; var previous:=Time.get_ticks_usec()
			for frame in 120:
				await process_frame
				var tick:=Time.get_ticks_usec(); wall.append((tick-previous)/1000.0); previous=tick
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport)); cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport)); setup.append(RenderingServer.get_frame_setup_time_cpu())
			var row:={"lights":count,"native_surface_output":native_output,"gpu_ms":distribution(gpu),"render_cpu_ms":distribution(cpu),"setup_cpu_ms":distribution(setup),"wall_ms":distribution(wall)}
			runs.append(row); check(float(row.gpu_ms.mean)>0 and float(row.render_cpu_ms.mean)>0,"Actual GPU/CPU timings captured "+str([count,native_output]))
	check(gamma.snapshot().failure.is_empty(),"Output cost fixture has no GPU pipeline failure")
	RenderingServer.viewport_set_measure_render_time(viewport,false); world.free(); material=null; source=null
	await frames(3); check(Palette.active.is_empty(),"Output cost fixture retires all lamp slots")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"runs":runs,"resolution":[1920,1080],"publicConnections":0,"scope":"Paired ABBA full-screen ordinary material microbenchmark, 1/8/32 overlapping point lights and optional native surface/final transfer. No particles/shadows/crowds/streaming or matched native-room performance acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
