extends "res://tests/native_particle_schedule_test.gd"
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
const Switch=preload("res://systems/native_render/particle_visibility.gd")
func spawn(world: Node3D,reference: bool,counter: Dictionary) -> Node3D:
	var part:=Node3D.new(); world.add_child(part)
	var out:=Emitter.new(); out.force_reference=reference; out.source_path=NodePath(".."); out.source_model_flags=0; out.frustum_enabled=false
	out.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","flags":16|32|128|256,"birthrate":30,"lifeexp":2,"velocity":0.3,"mass":0.1,"sizestart":0.1,"sizeend":0.1,"alphastart":1,"alphaend":1,"bounce_co":0.5}
	out.services.collide=func(_old,_goal,_out,_hit): counter.calls+=1; return false
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE); out.original_texture=ImageTexture.create_from_image(image)
	part.add_child(out); out.set_process(false); return out
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var world:=Node3D.new(); root.add_child(world); var switch:=Switch.new(); world.add_child(switch); switch.set_enabled(true)
	var camera:=Camera3D.new(); world.add_child(camera); camera.current=true; camera.position=Vector3(0,1,10); camera.look_at(Vector3.ZERO)
	for reference in [false,true]:
		switch.set_collision_enabled(true); var counter:={"calls":0}; var out=spawn(world,reference,counter)
		check(out.failure.is_empty() and (out.native_owner==null)==reference,"Real emitter selects resident/reference backend")
		for frame in 12: out.tick(1.0/60)
		check(counter.calls>0 and out.active_count()>0 and out.surface.vertex_count>0,"Collision on calls scene provider while simulating/drawing")
		var calls: int=counter.calls; var active: int=out.active_count(); var draws: int=out.rng.draws
		switch.set_collision_enabled(false)
		for frame in 12: out.tick(1.0/60)
		check(counter.calls==calls,"Collision off skips all scene callbacks on existing emitter")
		check(out.active_count()>=active and out.rng.draws>draws and out.surface.vertex_count>0,"Off continues births, simulation and GPU geometry")
		check(int(out.state.flags)==(32|128|256) and int(out.original_properties.flags)==(16|32|128|256),"Only effective collision bit changes; authored flags remain intact")
		switch.set_enabled(false); switch.set_collision_enabled(true); out.tick(0.2)
		check(counter.calls==calls,"Paused emitter performs no collision work after changing preference")
		switch.set_enabled(true); out.set_process(false); out.tick(1.0/60)
		check(counter.calls>calls and int(out.state.flags)==int(out.original_properties.flags),"Re-enable patches private native state and restores scene callbacks")
		out.retire(); out.get_parent().queue_free(); await process_frame
		switch.set_collision_enabled(false); counter={"calls":0}; out=spawn(world,reference,counter)
		for frame in 12: out.tick(1.0/60)
		check(counter.calls==0 and out.active_count()>0 and int(out.state.flags)==(32|128|256),"New streamed emitter inherits off before native initialization")
		out.retire(); out.get_parent().queue_free(); await process_frame
	check(switch.emitters.is_empty(),"Retirement releases all emitter registrations")
	world.free(); await process_frame
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Actual resident/reference GPU emitters: callback suppression, resumed collisions, independent visibility, unchanged authored flags and streamed initialization"},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
