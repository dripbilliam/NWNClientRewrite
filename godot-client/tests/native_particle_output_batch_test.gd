extends "res://tests/native_particle_output_pixels_test.gd"
func capture_renderer(effect: CompositorEffect,renderer: RefCounted) -> Image:
	effect.configure(renderer); renderer.call("dispatch",1,{}); await settle(5)
	return root.get_texture().get_image()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(256,256); var world:=LiveWorld.new(); root.add_child(world); world.set_process(false)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=16; camera.current=true
	var environment:=WorldEnvironment.new(); world.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(.03,.04,.05).linear_to_srgb(); environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var batched: RefCounted=ClassDB.instantiate("NwnParticleStreamRender"); var reference: RefCounted=ClassDB.instantiate("NwnParticleStreamRender")
	for pair in [[batched,true],[reference,false]]: check(not pair[0].call("dispatch",0,{"presentation":presentation,"native_surface_output":true,"batch_ranges":pair[1]}).has("error"),"Native renderer configures paired range policy")
	var effect:=ParticleEffect.new(); effect.configure(batched); Stack.install(camera,effect)
	var gamma:=Gamma.new(); world.add_child(gamma); gamma.attach(camera); gamma.effect.set_surface_output(true)
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color(.2,.4,.6,.7)); var texture:=ImageTexture.create_from_image(image)
	var second:=Image.create(1,1,false,Image.FORMAT_RGBA8); second.fill(Color(.8,.1,.2,.6)); var other:=ImageTexture.create_from_image(second)
	var emitters: Dictionary={}
	for n in 5:
		var selected: Texture2D=other if n==4 else texture; var emitter:=particle(world,selected,n==3,.5); emitter.get_parent().position.z=n*.02; emitters[emitter.get_instance_id()]=emitter
		check(not presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":emitter.native_owner,"providers":emitter.providers,"source_flags":0,"culling":false,"texture":selected,"additive":n==3,"two_sided":false}).has("error"),"Ordered overlapping source registers "+str(n))
	var driver:=Driver.new(); driver.presentation=presentation; driver.renderer=batched; driver.camera=camera; world.add_child(driver); await settle(12); driver.set_process(false)
	check(driver.failure.is_empty(),"Frozen native packet prepares without failure")
	var merged:=await capture_renderer(effect,batched); var merged_stats: Dictionary=batched.call("dispatch",2,{})
	var separate:=await capture_renderer(effect,reference); var separate_stats: Dictionary=reference.call("dispatch",2,{})
	check(merged.get_data()==separate.get_data(),"Consecutive same-state batching preserves every overlapping alpha/additive pixel exactly")
	check(merged_stats.last_draws==3 and separate_stats.last_draws==5 and merged_stats.last_vertices==30 and separate_stats.last_vertices==30,"Only the contiguous same-sampler/same-blend triple is merged")
	var packet: Dictionary=presentation.call("dispatch",2,{})
	var hidden_id:=int(packet.ranges[3].id); emitters[hidden_id].get_parent().hide()
	var refreshed: Dictionary=presentation.call("dispatch",11,{})
	check(not refreshed.has("error"),"Paused visibility produces a native-color packet")
	var hidden_merged:=await capture_renderer(effect,batched); var hidden_merged_stats: Dictionary=batched.call("dispatch",2,{})
	var hidden_separate:=await capture_renderer(effect,reference); var hidden_separate_stats: Dictionary=reference.call("dispatch",2,{})
	check(hidden_merged.get_data()==hidden_separate.get_data() and merged.get_data()!=hidden_merged.get_data(),"Batching neither resurrects a hidden middle source nor changes remaining painter order")
	check(hidden_merged_stats.last_draws==4 and hidden_separate_stats.last_draws==4 and hidden_merged_stats.last_vertices==24,"A hidden-source vertex gap splits the batch instead of spanning stale geometry")
	emitters[hidden_id].get_parent().show(); presentation.call("dispatch",11,{})
	var restored:=await capture_renderer(effect,batched); check(restored.get_data()==merged.get_data(),"Restoring a paused source restores exact original pixels and batching")
	root.msaa_3d=Viewport.MSAA_2X; root.size=Vector2i(239,193)
	var resized:=await capture_renderer(effect,batched); var resized_reference:=await capture_renderer(effect,reference)
	check(resized.get_data()==resized_reference.get_data(),"Batched painter order survives MSAA pipeline recreation and resize")
	check(batched.call("dispatch",2,{}).error==0 and reference.call("dispatch",2,{}).error==0,"Both native raster policies remain valid")
	Stack.remove(camera,effect); effect.close(); reference.call("dispatch",3,{}); presentation.call("dispatch",5,{})
	for emitter in emitters.values(): emitter.retire()
	world.close(); world.free(); await settle(4); texture=null; other=null; presentation=null; reference=null; batched=null
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"batched":merged_stats,"separate":separate_stats,"hidden_batched":hidden_merged_stats,"publicConnections":0,"scope":"Actual GPU exact-pixel A/B for consecutive native particle draw merging, sampler/blend boundaries, overlapping normal/additive painter order, paused middle-source gaps/restoration, MSAA/resize and retirement. No reordering or geometry omission; not full-world FPS acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
