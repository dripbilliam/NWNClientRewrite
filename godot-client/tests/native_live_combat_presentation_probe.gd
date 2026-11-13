extends "res://tests/native_live_world_radial_probe.gd"
# Owned headless original-server presentation check. No injected actor, path,
# animation or resource state; all samples are CPU private-node/clock data.
var events: Array=[]
var started_us:=0
func presentation(value: Dictionary) -> void:
	if int(value.get("id",-1))==desktop.actor_id and events.size()<128:
		var copy:=value.duplicate(true); copy.observedUs=Time.get_ticks_usec()-started_us; events.append(copy)
func engine_state() -> Dictionary:
	if not is_instance_valid(probe.session.world) or not is_instance_valid(probe.session.world.combat): return {}
	return probe.session.world.combat.engine.states.get(desktop.actor_id,{})
func clock_sample() -> Array:
	var result: Array=[]
	if not probe.session.world.instances.has(desktop.actor_id): return result
	var rigs=probe.session.world.instances[desktop.actor_id].rigs
	for model in rigs.entities.get(desktop.actor_id,{}).get("models",[]):
		result.append({"clip":str(model.get("clip","")),"time":float(model.get("last_time",0)),"speed":float(model.get("speed",0)),"loop":bool(model.get("loop",false)),"follow":bool(model.get("follow",false))})
	return result
func changed_clocks(before: Array,after: Array) -> bool:
	for index in mini(before.size(),after.size()):
		if before[index].clip==after[index].clip and before[index].time!=after[index].time: return true
	return false
func pose_check(kind: String) -> bool:
	var instance=probe.session.world.instances[desktop.actor_id]; var rigs=instance.rigs
	var before: Dictionary=rigs.diagnostic_sample([desktop.actor_id],false); var clocks:=clock_sample(); var box: Dictionary={}
	var state:=engine_state(); var expected: String=rigs.clip_name(desktop.actor_id,int(state.get("visual",-1)),int(state.get("context",{}).get("fieldE0",0)))
	var playing: Array=clocks.filter(func(model):return model.follow and str(model.clip).to_lower()==expected.to_lower())
	if not probe.check(not expected.is_empty() and not playing.is_empty() and playing.all(func(model):return not model.loop and is_equal_approx(float(model.speed),float(state.get("speed",-1)))),"Actual native %s body clip, speed and one-shot mode match its selected cue"%kind,{"expectedClip":expected,"state":state.duplicate(true),"clocks":clocks}): return false
	var began:=Time.get_ticks_usec()
	if not await probe.wait_for(func():
		box.comparison=rigs.compare_samples(before,rigs.diagnostic_sample([desktop.actor_id],false)); box.clocks=clock_sample()
		return int(box.comparison.changed_local_parts)>0 and changed_clocks(clocks,box.clocks),"Actual native %s private nodes and original model clock advance without GPU waits"%kind): return false
	return probe.check(true,"Native %s pose timing retained separately from server latency"%kind,{"observationUs":Time.get_ticks_usec()-began,"comparison":box.comparison,"beforeClocks":clocks,"afterClocks":box.clocks,"pivot":instance.position,"receivedPosition":probe.current().get("replicated",{}).get("position"),"pixelsAccepted":false})
func facing_dot(target: int) -> float:
	var world=probe.session.world
	if not world.instances.has(desktop.actor_id) or not world.desired.has(target): return -2.0
	var actor=world.instances[desktop.actor_id]; var point: Dictionary=world.object_pose(world.desired[target].object)
	if point.is_empty(): return -2.0
	var delta: Vector3=point.position-actor.position; delta.y=0
	return (-actor.basis.z).dot(delta.normalized()) if delta.length_squared()>0.000001 else 1.0
func light_row() -> Dictionary:
	for row in desktop.book.state.get("memory",[]):
		if int(row.get("spellId",-1))==100 and row.get("ready",false) and row.get("canCast",false) and desktop.book.widgets.has(int(row.entryId)) and desktop.book.widgets[int(row.entryId)].is_visible_in_tree(): return row
	return {}
func exercise() -> bool:
	if not probe.check(DisplayServer.get_name()=="headless" and probe.session.args.get("actions-combat-presentation-check","")=="true","Combat presentation uses only the isolated owned headless mode"): return false
	if not await probe.wait_for(func():return is_instance_valid(probe.session.world) and probe.session.world.instances.has(desktop.actor_id) and probe.session.world.combat.engine.actors.has(desktop.actor_id),"Actual controlled model and native combat owner are admitted"): return false
	var speaker:=-1
	for id in desktop.objects:
		if desktop.objects[id].get("objectType")==5 and probe.ui.text.name(null,int(id))=="Native Speaker": speaker=int(id); break
	if not probe.check(speaker>=0,"Original durable combat target is actually disclosed"): return false
	# Retire setup-only views through their existing controls before exercising
	# the actual spellbook and world-pointer path. Retained server stats survive.
	if probe.ui.inventory.ui.wanted: probe.ui.inventory.ui.close_button.pressed.emit()
	if desktop.sheet.wanted: desktop.sheet.close_button.pressed.emit()
	if not desktop.book.wanted: desktop.panel("spells")
	desktop.book.query({"classIndex":0,"level":0,"metamagic":0})
	if not await probe.wait_for(func():return desktop.book_frame.layout_ready and not light_row().is_empty(),"Actual original spellbook publishes a received ready Light preparation",30): return false
	var uses: int=desktop.rules.spell_uses(probe.current(),100,0)
	if not probe.check(uses>0,"Original server supplies an actual prepared use",{"uses":uses}): return false
	var row:=light_row(); var entry_id:=int(row.entryId)
	await click(desktop.book.widgets[entry_id].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	if not await probe.wait_for(func():return desktop.book_frame.action_window.visible and not desktop.book.cast.disabled,"Physical prepared-spell context exposes its actual native Cast control"): return false
	var point: Vector3=probe.position()+Vector3(6,0,0)
	desktop.command({"kind":"walk","position":[point.x,-point.z,point.y]})
	if not await probe.wait_for(func():return not probe.current().get("replicated",{}).get("path",[]).is_empty() and probe.session.world.motion.objects.get(desktop.actor_id,{}).get("active",false),"Original server supplies a genuine active path before moving-to-cast trigger"): return false
	probe.check(true,"Moving cast setup retains received path provenance",{"path":probe.current().replicated.path.duplicate(true),"wireAnimation":probe.current().replicated.get("animation"),"nativeAnimation":probe.session.world.motion.objects[desktop.actor_id].animation})
	var cast_begin:=Time.get_ticks_usec(); var casts_before: int=probe.session.world.combat.engine.stats.casts
	await click(desktop.book.cast.get_global_rect().get_center())
	if not probe.check(int(desktop.target.get("type",-1))==2 and int(desktop.target.get("spellId",desktop.target.get("intParam",-1)))==100,"Actual Cast input enters the native received-spell targeting owner",{"target":desktop.target.duplicate(true)}): return false
	await click(desktop.book.close_button.get_global_rect().get_center())
	if not probe.check(not desktop.book.wanted and not desktop.target.is_empty(),"Actual book Close retains the valid targeting owner"): return false
	if not await probe.wait_for(func():return probe.session.world.instances.has(speaker),"Actual target model is admitted for native pointer selection"): return false
	var screen: Vector2=probe.session.camera.unproject_position(probe.session.world.instances[speaker].global_position+Vector3.UP)
	if not probe.check(probe.get_viewport().get_visible_rect().has_point(screen),"Actual received target projects inside the owned native viewport",{"screen":screen}): return false
	var hit: Dictionary=probe.session.registry.pick(probe.session.camera,screen)
	if not probe.check(int(hit.get("id",-1))==speaker and not probe.ui.blocks_pointer(screen),"Actual native CPU geometry resolves the intended unobstructed target",{"hitId":hit.get("id"),"targetId":speaker,"position":hit.get("position"),"screen":screen}): return false
	await click(screen)
	if not probe.check(desktop.target.is_empty(),"Physical native world pointer consumes the spell targeting owner"): return false
	if not await probe.wait_for(func():
		var state:=engine_state(); var action: Variant=state.get("action")
		return int(probe.session.world.combat.engine.stats.casts)>casts_before and action is Dictionary and int(action.get("type",0))==4 and int(action.get("spellId",-1))==100 and int(action.get("targetId",-1))==speaker and int(state.get("current",{}).get("remaining",0))>100,"Original server cast record starts its actual native private clip",25): return false
	probe.check(true,"Input-to-cast observation includes server/transport/frame scheduling",{"elapsedUs":Time.get_ticks_usec()-cast_begin,"explicitInputFrames":3,"state":engine_state().duplicate(true),"clocks":clock_sample(),"events":events.duplicate(true)})
	if not await pose_check("cast"): return false
	if not await probe.wait_for(func():return desktop.rules.spell_uses(probe.current(),100,0)<uses,"Original server consumes the prepared spell independently of local playback"): return false
	if not await probe.wait_for(func():return engine_state().get("current",{}).is_empty() and int(probe.current().get("replicated",{}).get("animation",-1)) in [0,1],"Original server and private cue finish before the separate attack check"): return false
	if not await open_creature(speaker): return false
	if not probe.check(desktop.radial_entries.get(2,{}).get("action")=="world-attack","Actual target source wheel exposes Attack"): return false
	var chat_before: int=probe.ui.chat.sequence; var attacks_before: int=probe.session.world.combat.engine.stats.attacks; var attack_begin:=Time.get_ticks_usec()
	if not await choose(2): return false
	if not await probe.wait_for(func():return probe.ui.chat.rows.any(func(value):return int(value.get("chat_sequence",0))>chat_before and value.get("category","")=="attack-feedback"),"Original server returns real attack feedback",25): return false
	if not await probe.wait_for(func():
		var state:=engine_state(); var action: Variant=state.get("action")
		return int(probe.session.world.combat.engine.stats.attacks)>attacks_before and action is Dictionary and int(action.get("type",0))==1 and int(action.get("targetId",-1))==speaker and int(state.get("visual",-1)) in [200,201,202,203,204,205,263,264,265] and int(state.get("current",{}).get("remaining",0))>100,"Received attack record owns an actual native attack clip",25): return false
	probe.check(true,"Input-to-attack observation retained separately",{"elapsedUs":Time.get_ticks_usec()-attack_begin,"explicitInputFrames":3,"state":engine_state().duplicate(true),"clocks":clock_sample()})
	if not await pose_check("attack"): return false
	if not await probe.wait_for(func():return int(probe.current().get("replicated",{}).get("facingTarget",-1))==speaker and int(probe.session.world.motion.objects[desktop.actor_id].get("facingTarget",-1))==speaker and facing_dot(speaker)>0.9,"Actual received facing lock turns the native actor toward the attacked target"): return false
	probe.check(true,"Facing preserves received/presentation distinction",{"dot":facing_dot(speaker),"wire":probe.current().replicated.get("orientation"),"wirePosition":probe.current().replicated.position,"pivotPosition":probe.session.world.instances[desktop.actor_id].position,"events":events.duplicate(true)})
	if not await probe.wait_for(func():return desktop.action_queue.rows.any(func(value):return int(value.get("type",-1))==3 and desktop.action_queue.buttons.has(int(value.widgetSerial))),"Original server attack has its actual native queue cancel control"): return false
	var serial:=-1
	for value in desktop.action_queue.rows:
		if int(value.get("type",-1))==3: serial=int(value.widgetSerial); break
	await click(desktop.action_queue.buttons[serial].get_global_rect().get_center())
	return await probe.wait_for(func():return not desktop.action_queue.rows.any(func(value):return int(value.get("type",-1))==3),"Original server retires the physically cancelled attack queue")
func run(owner) -> void:
	probe=owner; desktop=probe.desktop; started_us=Time.get_ticks_usec()
	var combat=probe.session.world.combat
	combat.engine.presentation_event.connect(presentation)
	var passed: bool=await exercise()
	if is_instance_valid(combat) and combat.engine.presentation_event.is_connected(presentation): combat.engine.presentation_event.disconnect(presentation)
	probe.check(passed,"Combat presentation scoped original-server outcome complete",{"events":events.duplicate(true),"gpu":false,"fullCombatParity":false,"pixelsAccepted":false})
