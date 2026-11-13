extends "res://tests/nwn62_construction_test.gd"
const World=preload("res://systems/native_render/live_world.gd")
const Creatures=preload("res://systems/native_render/creature_stream.gd")
class Hub extends Node:
	var generation:=1
	var assets
	var requests: Array=[]
	var total_requested:=0
	var on_request: Callable
	func request_reference(reference,_name: String)->void:
		reference.generation=generation;requests.append(reference);total_requested+=1
		if on_request.is_valid():on_request.call()
	func cancel_reference(reference)->void:requests.erase(reference)
	func close()->void:requests.clear()
func setup()->Dictionary:
	var world:=World.new();root.add_child(world);world.set_process(false)
	if root.get_camera_3d()==null:
		var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,0,10);camera.current=true
	# Ambient wind has its own valid RNG work; isolate the publication owner
	# while retaining the actual initialized wind service for emitter binding.
	world.point_wind.set_process(false)
	var hub:=Hub.new();world.add_child(hub);world.references=hub;world.set_meta("native_reference_hub",hub)
	var actor:=Actor.new();actor.hide();world.add_child(actor)
	var random=world.get_meta("native_particle_random")
	return {"world":world,"hub":hub,"actor":actor,"random":random,"initial_draws":int(random.draws)}
func input_with_clock()->Dictionary:
	var input:=actor_input();var defaults: Array=input.value.rig_asset.defaults
	input.value.nodes[1].features.append("light");input.value.nodes[1].light={"color":[1.0,0.5,0.25],"radius":2.0,"multiplier":1.0,"shadow":0.0}
	input.value.rig_asset={"defaults":defaults,"unsupported":[],"clips":[{"name":"walk","length":1.0,"transition":0.0,"events":[],"tracks":[{"part":0,"property":"position","keys":[{"time":0.0,"value":[1.0,0.0,0.0]},{"time":1.0,"value":[2.0,0.0,0.0]}],"sourceInterpolation":"linear"}]}]}
	return input
func check_unpublished(setup: Dictionary)->void:
	var actor=setup.actor
	check(setup.hub.total_requested==0 and setup.random.draws==setup.initial_draws,"Unpublished frame gaps cannot request references or consume world particle RNG")
	check(actor.find_children("native_emitter","Node3D",true,false).is_empty() and actor.find_children("native_reference","Node3D",true,false).is_empty(),"Unpublished helpers are not attached to live physical parts")
	check(root.get_nodes_in_group("native_original_model_lights").is_empty(),"Unpublished lights do not join scene collection")
	if is_instance_valid(actor.rigs) and actor.rigs.entities.has(7):
		check(not actor.rigs.is_processing() and float(actor.rigs.playback_state(7,0).time)==0.0,"Unpublished rig clocks remain paused across actual engine frames")
func cleanup(setup: Dictionary)->void:
	if is_instance_valid(setup.actor):setup.actor.retire()
	await process_frame;await process_frame
	setup.world.close();setup.world.free()
func run()->void:
	var input:=input_with_clock();var pieces: Array=[{"bundle":input,"initial_clip":"walk","follow":true}]
	var first:=setup();check(first.actor.begin_install(pieces,first.world.pool,7,{}),"Frame-gap actor begins")
	var turns:=0;var result: Dictionary={}
	while turns<512:
		result=first.actor.install_step(1,1);turns+=1
		if result.status!="pending":break
		check_unpublished(first);await process_frame;check_unpublished(first)
	check(result.status=="ready" and first.hub.total_requested==2 and first.world.particle_metrics.entries.size()==1,"Atomic commit activates the complete reference/emitter service set once")
	var second:=setup();var baseline:=ActorBefore.new();second.actor.free();second.actor=baseline;baseline.hide();second.world.add_child(baseline)
	check(baseline.install(pieces,first.world.pool,7,{}),"Independent synchronous actor initializes at the same admission boundary")
	check(actor_sample(first.actor)==actor_sample(second.actor),"Admission transforms, helper bindings and initial animation clock equal synchronous source")
	first.actor.show();second.actor.show()
	for frame in 6:await process_frame
	var a=first.actor.find_children("native_emitter","Node3D",true,false)[0];var b=second.actor.find_children("native_emitter","Node3D",true,false)[0]
	var emitter_observations: Array=[]
	for emitter in [a,b]:emitter_observations.append({"frames":emitter.frames,"elapsed":emitter.elapsed,"failure":emitter.failure,"retired":emitter.retired,"processing":emitter.is_processing(),"visible":emitter.is_visible_in_tree()})
	check(a.frames>0 and a.frames==b.frames and a.failure==b.failure,"Admitted emitter callbacks resume with equal frame clocks")
	check(first.actor.rigs.playback_state(7,0)==second.actor.rigs.playback_state(7,0),"Admitted animated rigs retain aligned clocks across visible frames")
	await cleanup(first);await cleanup(second)
	var cancelled:=setup();cancelled.actor.begin_install(pieces,cancelled.world.pool,7,{})
	turns=0
	while turns<256 and cancelled.actor._actor_install.helper_emitters.is_empty():cancelled.actor.install_step(1,1);turns+=1;await process_frame
	check(not cancelled.actor._actor_install.helper_emitters.is_empty(),"Cancellation fixture reaches prepared off-tree emitters after actual frame gaps")
	check_unpublished(cancelled);cancelled.actor.cancel_install();await process_frame
	check(cancelled.hub.total_requested==0 and cancelled.random.draws==cancelled.initial_draws and cancelled.world.particle_metrics.entries.is_empty(),"Cancelled helper preparation never leaks service/RNG ownership")
	await cleanup(cancelled)
	for retire_scope in [false,true]:
		var reentrant:=setup();reentrant.actor.actor_alpha_enabled=true
		var stream=Creatures.new();stream.pool=reentrant.world.pool;stream.pool.publication_budget_us=1000000
		stream.set_process(false);reentrant.world.add_child(stream)
		reentrant.actor.begin_install(pieces,stream.pool,7,{})
		if retire_scope:
			stream._actor_pending={"actor":reentrant.actor,"plan":{"id":7},"began":Time.get_ticks_usec(),"cpu_ms":0.0,"max_step_ms":0.0}
			reentrant.hub.on_request=func():stream.close()
			for step in 256:
				stream.resume_actor_publication()
				if stream.closed:break
			check(stream.closed and stream._actor_pending.is_empty() and stream.actors.is_empty() and stream.stats.publications.is_empty(),"Reentrant scope close during helper activation cannot publish cancelled actor")
		else:
			reentrant.hub.on_request=func():reentrant.actor.cancel_install()
			for step in 256:
				result=reentrant.actor.install_step(1,0)
				if result.status!="pending":break
			check(result.status=="failed" and reentrant.actor._actor_install.is_empty() and reentrant.actor.rigs==null and not reentrant.actor.installation_complete,"Reentrant helper cancellation safely unwinds add_child before graph release")
		await process_frame
		check(reentrant.hub.requests.is_empty() and reentrant.hub.total_requested==1 and reentrant.world.particle_metrics.entries.is_empty(),"Reentrant cancellation releases activated reference and prevents remaining emitter registration")
		await cleanup(reentrant)
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"emitters":emitter_observations,"scope":"Real process_frame gaps during staged actor/rig/helper construction, no early light/reference/particle/RNG ownership, synchronous admission clock comparison, post-admission callbacks and cancellation. No FPS sampling."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
