extends "res://tests/native_particle_resident_scene_test.gd"
func make_emitter(world: Node3D,kind: String,reference: bool,index: int) -> Node3D:
	var part:=Node3D.new(); world.add_child(part); part.position=Vector3((index-1)*0.8,0.5,0)
	var emitter:=Emitter.new(); emitter.force_reference=reference; emitter.source_path=NodePath(".."); emitter.source_model_flags=0
	emitter.original_properties={"update":kind,"render":"Normal","blend":"Normal","flags":32|128,"birthrate":18.0,"lifeexp":2.0,"loop":1,"velocity":0.2,"randvel":0.1,"spread":0.5,"sizestart":0.4,"sizeend":0.2,"alphastart":0.8,"alphaend":0.5,"colorstart":[0.8,0.4,0.1],"colorend":[0.2,0.8,0.5]}
	var image:=Image.create(2,2,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE); emitter.original_texture=ImageTexture.create_from_image(image); part.add_child(emitter); return emitter
func settle(count: int=3) -> void:
	for frame in count: await process_frame
	await RenderingServer.frame_post_draw; RenderingServer.force_sync()
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var world:=LiveWorld.new(); root.add_child(world); world.set_process(false)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,3,7); camera.look_at(Vector3(0,0.5,0)); camera.current=true
	var environment:=WorldEnvironment.new(); world.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.03,0.04,0.06)
	environment.environment.fog_enabled=true; environment.environment.fog_mode=Environment.FOG_MODE_DEPTH; environment.environment.fog_depth_begin=2.0; environment.environment.fog_depth_end=14.0; environment.environment.fog_density=1.0; environment.environment.fog_sun_scatter=0.0; environment.environment.fog_height_density=0.0; environment.environment.fog_aerial_perspective=0.0
	var group: Node=world.particle_stream_group
	check(is_instance_valid(group) and group.native!=null and group.failure.is_empty(),"Actual LiveWorld enables the explicitly selected native shared frame")
	if not is_instance_valid(group) or group.native==null: world.close(); world.free(); quit(1); return
	var a=make_emitter(world,"Fountain",false,0); var b=make_emitter(world,"Explosion",false,1); var c=make_emitter(world,"Fountain",true,2)
	b.detonate(); await settle(30)
	var first: Dictionary=group.snapshot(); var totals: Dictionary=world.particle_metrics.snapshot()
	check(group.members.size()==3 and group.fast_members==2 and int(first.native.fallbacks)==1,"Fast and reference effects share one ordered world update without omissions")
	check(totals.emitters==3 and totals.simulated==3 and totals.active==a.active_count()+b.active_count()+c.active_count(),"Native fixed counters include every fast/fallback particle")
	check(totals.vertices==int(group.last.vertices)+int(c.surface.vertex_count),"Native counters preserve exact GPU vertex totals")
	check(a.surface.mesh==null and b.surface.mesh==null and c.surface.mesh!=null,"Only fast effects retire the old capacity meshes")
	check(first.renderer.error==0 and first.renderer.draws>0 and first.renderer.uploads>0,"Actual world submits shared GPU ranges")
	check(not group.closed and environment.environment.fog_enabled,"Real area depth fog retains fast native particles")
	check(camera.compositor!=null and camera.compositor.compositor_effects.has(group.effect),"World attaches its scoped compositor to the active camera")
	var before:=root.get_texture().get_image(); var rng_before: int=world.get_meta("native_particle_random").draws
	for emitter in [a,b,c]: emitter.set_particles_enabled(false)
	await settle()
	var hidden:=root.get_texture().get_image(); var changed:=0
	for y in range(0,before.get_height(),3):
		for x in range(0,before.get_width(),3):
			if before.get_pixel(x,y)!=hidden.get_pixel(x,y): changed+=1
	check(changed>10 and group.last.vertices==0,"Particle off hides all shared and fallback pixels")
	check(world.get_meta("native_particle_random").draws==rng_before,"Paused particles consume no scene RNG")
	b.detonate(); a.set_collision_enabled(false)
	for emitter in [a,b,c]: emitter.set_particles_enabled(true)
	await settle()
	a.sync_stream_diagnostics(); b.sync_stream_diagnostics()
	check(not b.queued_detonate and not a.collision_flags_pending,"Fast frame consumes queued explosion and collision commands once")
	check(a.frames>0 and a.native_active>0 and a.native_typed_frame and a.native_stream_vertices>0,"Cold entity inspection reports native shared state")
	check(a.snapshot().vertices==a.native_stream_vertices,"Entity inspection uses active shared vertices rather than the retired mesh")
	var original_camera:=camera.global_transform
	camera.position.x+=10000; a.frustum_enabled=true; await settle()
	check(group.info(a.get_instance_id()).culled,"Far current camera culls a native grouped emitter")
	a.frustum_enabled=false; await settle()
	check(not group.info(a.get_instance_id()).culled,"A runtime culling change reaches the native group")
	a.frustum_enabled=true; camera.global_transform=original_camera; await settle()
	c.retire(); c.get_parent().queue_free(); b.retire(); b.get_parent().queue_free(); await settle()
	var reduced: Dictionary=world.particle_metrics.snapshot()
	check(group.members.size()==1 and group.fast_members==1 and reduced.emitters==1 and reduced.active==a.active_count(),"Retirement removes exact fast/fallback counter records")
	var final: Dictionary=group.snapshot(); world.close(); await settle()
	check(group.closed and group.native.call("dispatch",7,{}).registered==0 and world.particle_metrics.snapshot().emitters==0,"World retirement clears shared registry and counters")
	check(camera.compositor==null,"World retirement restores the original camera compositor")
	check(not group.renderer.call("dispatch",2,{}).alive,"World retirement cancels queued GPU publication")
	world.free(); await process_frame; RenderingServer.force_sync()
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"first":first,"totals":totals,"last":final,"changed_samples":changed,"publicConnections":0,"scope":"Actual LiveWorld opt-in shared GPU path with native and reference effects, native counters, original fallback surface, particle toggle/RNG pause, queued detonation/collision changes, cold inspection, fast/fallback retirement and camera/compositor/GPU cleanup. Not full server combat acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
