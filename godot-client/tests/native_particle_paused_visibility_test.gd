extends "res://tests/native_particle_resident_scene_test.gd"
var shared_texture: Texture2D
func emitter(model: Node3D,lit: bool,color: Array) -> Node3D:
	var source:=Node3D.new(); model.add_child(source)
	var value:=Emitter.new(); value.source_path=NodePath(".."); value.source_model_flags=0
	value.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","flags":32|128|(8 if lit else 0),"birthrate":30.0,"lifeexp":8.0,"loop":1,"velocity":0.0,"randvel":0.0,"spread":0.0,"sizestart":.6,"sizeend":.6,"alphastart":.8,"alphaend":.8,"colorstart":color,"colorend":color}
	value.original_texture=shared_texture; source.add_child(value); return value
func settle(count: int=3) -> void:
	for frame in count: await process_frame
	await RenderingServer.frame_post_draw; RenderingServer.force_sync()
func changed(a: Image,b: Image) -> int:
	var count:=0
	for y in range(0,a.get_height(),3):
		for x in range(0,a.get_width(),3):
			if a.get_pixel(x,y)!=b.get_pixel(x,y): count+=1
	return count
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	root.size=Vector2i(512,320)
	var world:=LiveWorld.new(); root.add_child(world); world.set_process(false)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,2,8); camera.look_at(Vector3(0,.5,0)); camera.current=true
	var environment:=WorldEnvironment.new(); world.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(.01,.02,.03); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.WHITE
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE); shared_texture=ImageTexture.create_from_image(image)
	var first:=Node3D.new(); world.add_child(first); first.position=Vector3(-.7,.5,0)
	var second:=Node3D.new(); world.add_child(second); second.position=Vector3(.7,.5,0)
	var third:=Node3D.new(); world.add_child(third); third.position=Vector3(0,.5,-3)
	var a:=emitter(first,true,[1.0,.1,.1]); var b:=emitter(second,true,[.1,.2,1.0]); var c:=emitter(third,false,[.1,1.0,.2])
	await settle(50)
	var group: Node=world.particle_stream_group
	check(is_instance_valid(group) and group.fast_members==3 and group.pooled_lighting,"Actual shared owner has three fast effects and pooled lighting")
	if not is_instance_valid(group) or group.fast_members!=3: world.close(); world.free(); quit(1); return
	world.process_mode=Node.PROCESS_MODE_DISABLED; await settle()
	var shown:=root.get_texture().get_image(); var state: Array=[group.info(a.get_instance_id()),group.info(b.get_instance_id()),group.info(c.get_instance_id())]
	var rng_before: int=world.get_meta("native_particle_random").draws
	var original: Dictionary=group.native.call("dispatch",2,{})
	var scene_before: Dictionary=group.native.call("dispatch",9,{})
	check(original.scene_batches==1 and original.scene_vertices>int(state[0].vertices),"Two emitter sources share one lit batch before hiding")
	var uploads: int=group.renderer.call("dispatch",2,{}).uploads
	first.hide(); await settle()
	var hidden_first:=root.get_texture().get_image(); var scene_hidden: Dictionary=group.native.call("dispatch",9,{})
	check(changed(shown,hidden_first)>10,"Ancestor hide changes pooled particles while simulation is paused")
	check(scene_hidden.batches.size()==1 and int(scene_hidden.batches[0].count)==int(state[1].vertices),"Only hidden emitter spans leave the merged scene batch")
	first.show(); await settle()
	var restored:=root.get_texture().get_image()
	check(changed(shown,restored)==0,"Showing a paused model restores the exact cached particle image")
	first.hide(); second.hide(); third.hide(); await settle()
	var empty: Dictionary=group.native.call("dispatch",2,{})
	check(empty.vertices==0 and empty.scene_vertices==0 and empty.ranges.is_empty(),"All hidden frozen effects publish zero draw ranges")
	check(changed(shown,root.get_texture().get_image())>20,"Both compositor and pooled pixels hide while the world is paused")
	first.show(); second.show(); third.show(); await settle()
	check(changed(shown,root.get_texture().get_image())==0,"Both renderer paths restore original pixels without simulation")
	check(group.renderer.call("dispatch",2,{}).uploads==uploads,"Visibility publications reuse unlit GPU geometry")
	check(group.native.call("dispatch",2,{}).buffer==original.buffer,"Visibility does not modify immutable source vertex bytes")
	check([group.info(a.get_instance_id()),group.info(b.get_instance_id()),group.info(c.get_instance_id())]==state and world.get_meta("native_particle_random").draws==rng_before,"Hidden/show transitions advance no clocks, counters, control samples, RNG or particle lifetime")
	first.hide(); a.set_particles_enabled(false); await settle(); first.show(); await settle()
	check(int(group.native.call("dispatch",9,{}).batches[0].count)==int(state[1].vertices),"Preference-off remains hidden when the parent returns")
	a.set_particles_enabled(true); await settle()
	check(changed(shown,root.get_texture().get_image())==0,"Preference-on restores the same paused snapshot")
	third.free(); await settle()
	check(group.native.call("dispatch",2,{}).ranges.is_empty(),"Retiring a paused source removes its retained compositor ranges")
	check(group.failure.is_empty(),"Visibility-only publication has no owner or renderer failure")
	var final: Dictionary=group.snapshot(); world.close(); world.free(); shared_texture=null; await settle()
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"state_before":state,"last":final,"publicConnections":0,"scope":"Actual paused-world ancestor visibility on native unlit compositor and merged lit batches, exact image/source-byte restoration, unchanged simulation/RNG, preferences and source retirement"},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
