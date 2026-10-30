extends "res://native_live_world.gd"
# Authoritative real-door stress probe. All resource/stream/retirement/input
# owners are production code; no teleport, forced position or fabricated ack.
func probe_drive() -> void:
	if not is_instance_valid(keyboard) or not world.ready_for_control(): fail("Held-gait probe has no admitted actor"); return
	keyboard.require_focus=false; keyboard.key(KEY_W,true)
	var deadline:=Time.get_ticks_msec()+3000; var prior_clip:=""; var prior_time:=0.0; var wraps:=0; var advancing:=0; var gait_samples:=0; var nonlooping:=0
	while not closing and Time.get_ticks_msec()<deadline:
		await process_frame
		if not world.instances.has(world.controlled_id): continue
		var instance=world.instances[world.controlled_id]; var model: Dictionary=instance.rigs.entities[world.controlled_id].models[0]
		var code:=int(instance.rigs.entities[world.controlled_id].animation)
		if code not in [2,3,4,78,79,84,85,86,87]: prior_clip=""; continue
		gait_samples+=1
		if not model.loop: nonlooping+=1
		var at: float=model.player.current_animation_position if model.player!=null and not model.player.current_animation.is_empty() else float(model.get("last_time",0))
		if str(model.clip)==prior_clip:
			if at<prior_time-0.01: wraps+=1
			elif at>prior_time+0.00001: advancing+=1
		prior_clip=str(model.clip); prior_time=at
	keyboard.key(KEY_W,false); keyboard.require_focus=true
	report.held_gait_probe={"gait_samples":gait_samples,"phase_wraps":wraps,"advancing_samples":advancing,"nonlooping_samples":nonlooping,"held_ms":3000}
	if gait_samples<20 or advancing<20 or wraps<1 or nonlooping!=0: fail("Held W did not retain an advancing repeating gait: "+str(report.held_gait_probe)); return
	await super.probe_drive()
func probe_door(id: int) -> void:
	var old_epoch:=epoch
	var old_area: int=world.area_id
	if not registry.entities.has(id): fail("Original campaign transition door is not rendered"); return
	var state: Dictionary=world.desired.get(id,{}).get("object",{}).get("replicated",{})
	if not bool(state.get("hasTransition",false)): fail("Original campaign door has no server transition"); return
	var initially_open:=int(state.get("doorOpenState",0))!=0
	var physical=world.instances.get(id)
	if not is_instance_valid(physical) or not physical.has_method("observe_door"): fail("Live campaign door lacks native animated owner"); return
	var before_pose: Array=physical.rigs.entities[id].nodes.map(func(node):return node.transform)
	var door_animation: Dictionary={"initially_open":initially_open,"samples":0,"moved":false,"clips":[]}
	var began:=Time.get_ticks_msec()
	if not initially_open:
		world_action({"id":id,"entity":registry.entities[id]})
		var open_deadline:=Time.get_ticks_msec()+25000
		while not closing and epoch==old_epoch and int(world.desired.get(id,{}).get("object",{}).get("replicated",{}).get("doorOpenState",0))==0 and Time.get_ticks_msec()<open_deadline: await process_frame
		if closing: return
		if epoch!=old_epoch: fail("Closed door transitioned before the open acknowledgement"); return
		state=world.desired.get(id,{}).get("object",{}).get("replicated",{})
		if int(state.get("doorOpenState",0))==0: fail("Original campaign door did not open"); return
		var visual_deadline:=Time.get_ticks_msec()+2500
		while not closing and Time.get_ticks_msec()<visual_deadline:
			await process_frame
			var model: Dictionary=physical.rigs.entities[id].models[0]; var clip:=str(model.clip)
			door_animation.samples+=1
			if not door_animation.clips.has(clip): door_animation.clips.append(clip)
			if physical.rigs.entities[id].nodes.map(func(node):return node.transform)!=before_pose: door_animation.moved=true
			if clip in ["opened1","opened2"]: break
		if not door_animation.moved or not door_animation.clips.any(func(clip):return clip in ["opening1","opening2"]): fail("Server opened door but original physical animation did not play: "+str(door_animation)); return
	world_action({"id":id,"entity":registry.entities[id]})
	var deadline:=Time.get_ticks_msec()+35000
	var sample: Dictionary={}
	while not closing and Time.get_ticks_msec()<deadline:
		if epoch>old_epoch and world.ready_for_control():
			sample=world.snapshot()
			# A gap between bounded batches is deliberately playable. It is not
			# proof that all desired objects have been admitted for this probe.
			if bool(sample.object_visuals_complete) or not sample.errors.is_empty() or not sample.failed_objects.is_empty(): break
		await process_frame
	if closing: return
	# A ready world must also have completed the actual presentation gate.
	for frame in 3: await process_frame
	var ready: bool=epoch>old_epoch and world.area_id!=old_area and world.ready_for_control()
	sample=world.snapshot()
	var row:={"target":id,"initially_open":initially_open,"opened_by_server":true,"previous_generation":old_epoch,"generation":epoch,"previous_area":old_area,"area":world.area_id,"new_area_ready":ready,"object_visuals_complete":sample.object_visuals_complete,"entities":sample.entities,"desired":sample.desired,"tiles":sample.terrain.rendered_tiles,"errors":sample.errors,"failed_objects":sample.failed_objects,"elapsed_ms":Time.get_ticks_msec()-began,"retirement":world_retirement.snapshot()}
	row.door_animation=door_animation; row.playable_ms=sample.get("playable_ms",-1); row.terrain=sample.terrain; row.preparation_cache=sample.preparation_cache
	report.door_probe=row
	row.loading_screen=loading_screen.snapshot()
	if loading_screen.active or not loading_screen.history.any(func(entry):return int(entry.generation)==epoch and bool(entry.milestones.terrain) and bool(entry.milestones.player) and bool(entry.milestones.camera)):
		fail("Native transition loading screen did not reveal at the three readiness milestones"); return
	row.render_cache=sample.pool
	if not report.has("door_probes"): report.door_probes=[]
	report.door_probes.append(row)
	if not ready or not bool(sample.object_visuals_complete): fail("Repeated original-server transition did not render its admitted objects"); return
	send({"kind":"door-probe-done","generation":epoch})
