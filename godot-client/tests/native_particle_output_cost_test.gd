extends "res://tests/native_particle_stream_scene_test.gd"
const Gamma=preload("res://systems/native_render/native_gamma.gd")
class LightDriver extends Node:
	var presentation: RefCounted
	var renderer: RefCounted
	var camera: Camera3D
	var lighting: Dictionary={}
	var failure:=""
	func _process(delta: float) -> void:
		var result: Dictionary=presentation.call("dispatch",1,{"delta":delta,"view":Bounds.native_view(camera,false),"native_surface_output":true,"lighting":lighting,"fog":[.03,.04,.06,0,5,100,1.0/95,3]})
		if not result.has("error"): result=renderer.call("dispatch",1,{})
		if result.has("error"): failure=str(result.error); set_process(false)
func frames(count: int) -> void:
	for frame in count: await process_frame
	await RenderingServer.frame_post_draw
func distribution(values: Array) -> Dictionary:
	var ordered:=values.duplicate(); ordered.sort(); var sum:=0.0
	for value in ordered: sum+=float(value)
	return {"mean":sum/ordered.size(),"median":ordered[ordered.size()/2],"p95":ordered[ceili(ordered.size()*.95)-1],"maximum":ordered.back(),"samples":ordered.size()}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	root.size=Vector2i(1920,1080); root.msaa_3d=Viewport.MSAA_DISABLED; Engine.max_fps=0
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original particle texture catalog mounts")
	var location: Dictionary=catalog.raster_location("fxpa_flame00"); var bytes: PackedByteArray=catalog.get_resource("fxpa_flame00",int(location.type)); var raster:=Raster.new(); var decoded:=raster.parse(bytes,int(location.type)); var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); var texture_sha:=hash.finish().hex_encode(); var pool:=Pool.new(); var texture:=pool.texture({"sha256":texture_sha,"value":decoded})
	check(raster.failure.is_empty() and texture!=null,"Original compressed particle texture decodes without replacement")
	var world:=Node3D.new(); root.add_child(world)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,35,45); camera.look_at(Vector3.ZERO); camera.fov=75; camera.current=true
	var environment:=WorldEnvironment.new(); world.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(.03,.04,.06).linear_to_srgb(); environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation"); var batched: RefCounted=ClassDB.instantiate("NwnParticleStreamRender"); var separate: RefCounted=ClassDB.instantiate("NwnParticleStreamRender")
	for pair in [[batched,true],[separate,false]]: check(not pair[0].call("dispatch",0,{"presentation":presentation,"native_surface_output":true,"batch_ranges":pair[1]}).has("error"),"Native lit particle draw policy configures")
	var effect:=Effect.new(); effect.configure(separate); var compositor:=Compositor.new(); compositor.compositor_effects=[effect]; camera.compositor=compositor
	var gamma:=Gamma.new(); world.add_child(gamma); gamma.attach(camera); gamma.effect.set_surface_output(true)
	var emitters: Array=[]; var count:=1506
	for n in count:
		var part:=Node3D.new(); world.add_child(part); part.position=Vector3((n%41-20)*.8,.1,(int(n/41)-18)*.8)
		var emitter:=Emitter.new(); emitter.source_path=NodePath(".."); emitter.source_model_flags=0
		emitter.original_properties={"update":"Single","render":"Normal","blend":"Normal","flags":8,"birthrate":1.0,"lifeexp":1.0,"loop":1,"velocity":0.0,"randvel":0.0,"spread":0.0,"mass":0.0,"xsize":0.0,"ysize":0.0,"sizestart":.4,"sizeend":.4,"alphastart":1.0,"alphaend":1.0,"colorstart":[1,1,1],"colorend":[1,1,1],"fps":0,"framestart":0,"frameend":0,"xgrid":1,"ygrid":1}
		emitter.original_texture=texture; part.add_child(emitter); emitter.set_process(false); emitter.surface.retire(); emitters.append(emitter)
		check(not presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":emitter.native_owner,"providers":emitter.providers,"source_flags":0,"culling":false,"texture":texture,"additive":false,"two_sided":false,"lighting":true}).has("error"),"Dense original lit emitter registers "+str(n))
	var lighting:={"lights":[],"ambient":{"color":[.15,.15,.2],"fade":1.0}}
	for n in 32: lighting.lights.append({"position":[(n%8-4)*4,0,(n/8-2)*4],"color":[.1,.15,.2],"radius":24,"fade":1.0})
	var driver:=LightDriver.new(); driver.presentation=presentation; driver.renderer=separate; driver.camera=camera; driver.lighting=lighting; world.add_child(driver)
	var viewport:=root.get_viewport_rid(); RenderingServer.viewport_set_measure_render_time(viewport,true); var runs: Array=[]
	for merged in [false,true,true,false]:
		var renderer: RefCounted=batched if merged else separate; driver.renderer=renderer; effect.configure(renderer); await frames(90)
		var gpu: Array=[]; var cpu: Array=[]; var wall: Array=[]; var previous:=Time.get_ticks_usec()
		for frame in 240:
			await process_frame; var tick:=Time.get_ticks_usec(); wall.append((tick-previous)/1000.0); previous=tick; gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport)); cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		var stats: Dictionary=renderer.call("dispatch",2,{}); var native_stats: Dictionary=presentation.call("dispatch",7,{})
		check(driver.failure.is_empty() and stats.error==0 and stats.last_vertices==count*6 and native_stats.active==count,"All original effects remain present through the measured window")
		check(stats.last_draws==(1 if merged else count),"Measured draw count matches the selected adjacent-range policy")
		runs.append({"batch_ranges":merged,"gpu_ms":distribution(gpu),"render_cpu_ms":distribution(cpu),"wall_ms":distribution(wall),"renderer":stats,"native":native_stats})
	driver.set_process(false); RenderingServer.viewport_set_measure_render_time(viewport,false)
	check(float(runs[0].gpu_ms.mean)>0 and float(runs[0].render_cpu_ms.mean)>0,"Cost fixture contains measured GPU and render-thread timestamps")
	camera.compositor=null; effect.close(); batched.call("dispatch",3,{}); separate.call("dispatch",3,{}); presentation.call("dispatch",5,{})
	for emitter in emitters: emitter.retire()
	world.free(); await frames(4); texture=null; pool.clear(); presentation=null; batched=null; separate=null
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"runs":runs,"texture_sha256":texture_sha,"resolution":[1920,1080],"emitters":count,"sample_lights":32,"publicConnections":0,"scope":"Paired ABBA performance fixture with 1506 original-textured lit particles, compiled CPU sample of 32 lights, native fog/gamma output and adjacent batching versus separate identical draws. Same active geometry throughout. No room meshes, shadows, live registry snapshot, fallback/soft-depth, streaming or full-game FPS acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
