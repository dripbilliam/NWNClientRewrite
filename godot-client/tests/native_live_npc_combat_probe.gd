extends "res://tests/native_live_quickbar_probe.gd"
# NPC state comes solely from the owned original server. Setup chat signals its
# event script; the probe never edits NPC classes/flags/path/animation/targets.
var attacker:=-1
var defender:=-1
var lifetime:=-1
var defender_lifetime:=-1
var generation:=-1
var area_id:=-1
var events: Array=[]
var started:=0
func state() -> Dictionary:
	return probe.session.world.combat.engine.states.get(attacker,{}) if is_instance_valid(probe.session.world) and is_instance_valid(probe.session.world.combat) else {}
func metadata() -> Dictionary:
	return probe.session.world.combat.engine.actors.get(attacker,{}) if is_instance_valid(probe.session.world) and is_instance_valid(probe.session.world.combat) else {}
func current_source(id: int) -> Dictionary: return desktop.objects.get(id,{}) if is_instance_valid(desktop) else {}
func scope_valid() -> bool:
	var world=probe.session.world
	return is_instance_valid(world) and int(world.generation)==generation and int(world.area_id)==area_id and int(current_source(attacker).get("nativeLifetime",-2))==lifetime and int(current_source(defender).get("nativeLifetime",-2))==defender_lifetime and world.instances.has(attacker) and world.instances.has(defender) and is_instance_valid(world.instances[attacker].rigs)
func capture(value: Dictionary) -> void:
	if int(value.get("id",-1))==attacker and events.size()<128:
		var row:=value.duplicate(true);row.observedUs=Time.get_ticks_usec()-started;events.append(row)
func clocks() -> Array:
	var rows: Array=[]
	if not scope_valid(): return rows
	for model in probe.session.world.instances[attacker].rigs.entities.get(attacker,{}).get("models",[]):
		rows.append({"clip":str(model.get("clip","")),"time":float(model.get("last_time",0)),"speed":float(model.get("speed",0)),"loop":bool(model.get("loop",false)),"follow":bool(model.get("follow",false))})
	return rows
func status(prefix: String,after: int) -> String:
	for row in probe.ui.chat.rows:
		if int(row.get("chat_sequence",0))>after and str(row.get("text","")).contains(prefix): return str(row.text)
	return ""
func status_action(text: String,prefix: String) -> int:
	var regex:=RegEx.new();regex.compile(prefix+"([0-9]+)");var found:=regex.search(text)
	return found.get_string(1).to_int() if found!=null else -1
func facing() -> float:
	var world=probe.session.world
	if not scope_valid(): return -2.0
	var delta: Vector3=world.instances[defender].position-world.instances[attacker].position;delta.y=0
	return (-world.instances[attacker].basis.z).dot(delta.normalized()) if delta.length_squared()>0.000001 else 1.0
func pose() -> bool:
	if not scope_valid(): return false
	var rigs=probe.session.world.instances[attacker].rigs;var selected: Dictionary=state()
	var expected: String=rigs.clip_name(attacker,int(selected.get("visual",-1)),int(selected.get("context",{}).get("fieldE0",0)))
	var before_clocks:=clocks();var playing: Array=before_clocks.filter(func(model):return model.follow and model.clip.to_lower()==expected.to_lower())
	if not probe.check(not expected.is_empty() and not playing.is_empty() and playing.all(func(model):return not model.loop and is_equal_approx(float(model.speed),float(selected.get("speed",-1)))),"Actual NPC private body clip/speed/one-shot mode match its selected near cue",{"clip":expected,"state":selected.duplicate(true),"clocks":before_clocks}): return false
	var sample: Dictionary=rigs.diagnostic_sample([attacker],false);var result: Dictionary={};var began:=Time.get_ticks_usec()
	if not await probe.wait_for(func():
		if not scope_valid() or not is_instance_valid(rigs): return false
		result.comparison=rigs.compare_samples(sample,rigs.diagnostic_sample([attacker],false));result.clocks=clocks()
		var advanced:=false
		for index in mini(before_clocks.size(),result.clocks.size()):
			if before_clocks[index].clip==result.clocks[index].clip and before_clocks[index].time!=result.clocks[index].time: advanced=true
		return int(result.comparison.changed_local_parts)>0 and advanced,"Actual NPC private pose and selected original clip clock advance without GPU waits"): return false
	return probe.check(true,"NPC private pose observation is separate from server/transport latency",{"observationUs":Time.get_ticks_usec()-began,"comparison":result.comparison,"clocks":result.clocks})
func exercise() -> bool:
	if not probe.check(DisplayServer.get_name()=="headless" and probe.session.args.get("actions-npc-combat-check","")=="true","NPC combat uses only its owned headless fixture mode"): return false
	for id in desktop.objects:
		if int(desktop.objects[id].get("objectType",0))!=5: continue
		var name: String=probe.ui.text.name(null,int(id))
		if name=="Native Speaker": attacker=int(id)
		elif name=="Native Defender": defender=int(id)
	if not probe.check(attacker>=0 and defender>=0 and attacker!=defender and attacker!=desktop.actor_id and defender!=desktop.actor_id,"Two exact received NPC identities are distinct from the controlled PC",{"attacker":attacker,"defender":defender,"controlled":desktop.actor_id}): return false
	if not await probe.wait_for(func():return probe.session.world.instances.has(attacker) and probe.session.world.instances.has(defender) and probe.session.world.combat.engine.actors.has(attacker),"Both original NPC models and actual private combat owners are admitted",30): return false
	lifetime=int(current_source(attacker).get("nativeLifetime",-1));defender_lifetime=int(current_source(defender).get("nativeLifetime",-1));generation=int(probe.session.world.generation);area_id=int(probe.session.world.area_id)
	if not probe.check(lifetime>0 and int(metadata().get("lifetime",-2))==lifetime and metadata().get("classState",{}).get("known",false),"Actual NPC class projection belongs to its received logical lifetime",{"attackerLifetime":lifetime,"classState":metadata().get("classState",{}),"classesDisclosed":current_source(attacker).get("replicated",{}).get("stats",{}).has("classes")}): return false
	var sequence: int=probe.ui.chat.sequence;var began:=Time.get_ticks_usec()
	probe.ui.chat.submit("-native-npc-start")
	if not await probe.wait_for(func():return not status("NATIVE_NPC_START:",sequence).is_empty(),"Original NPC UserDefined script acknowledges its actual ActionAttack setup"): return false
	probe.check(true,"NPC start query records the original server action without predicting it",{"status":status("NATIVE_NPC_START:",sequence),"source":"Actual server NPC script/GetCurrentAction"})
	if not await probe.wait_for(func():
		if not scope_valid(): return false
		var value:=state();var action: Variant=value.get("action")
		return action is Dictionary and int(action.get("type",0))==1 and int(action.get("targetId",-1))==defender and int(value.get("visual",-1)) in [200,201,202,263,264,265] and int(value.get("current",{}).get("remaining",0))>100,"Original NPC attack record starts a genuine private near-range clip",25): return false
	var action: Dictionary=state().action
	var branch: int=probe.session.world.combat.engine.selector.range_class(metadata(),probe.session.world.combat.engine.actors.get(defender,{}),action)
	if not probe.check(branch==2 and int(metadata().lifetime)==lifetime and int(current_source(attacker).get("nativeLifetime",-1))==lifetime,"Actual current NPC positions/appearance yield original near branch2",{"branch":branch,"elapsedUs":Time.get_ticks_usec()-began,"state":state().duplicate(true),"classState":metadata().classState,"attackerPosition":metadata().position,"defenderPosition":probe.session.world.combat.engine.actors[defender].position}): return false
	if not await pose(): return false
	if not await probe.wait_for(func():return events.any(func(value):return value.kind=="hit" and int(value.get("targetId",-1))==defender),"Original NPC selected clock reaches its actual authored Hit event",20): return false
	if not await probe.wait_for(func():return scope_valid() and int(current_source(attacker).get("replicated",{}).get("facingTarget",-1))==defender and int(probe.session.world.motion.objects.get(attacker,{}).get("facingTarget",-1))==defender and facing()>0.9,"Received NPC facing lock turns its private body toward the actual defender"): return false
	probe.check(true,"NPC facing and class provenance stay explicit",{"dot":facing(),"classState":metadata().classState,"constructorPathExercised":metadata().classState.get("source")=="native-constructor-7ea230","constructorGameplayAccepted":false,"limit":"Absent-class gameplay is not claimed when the original server discloses classes."})
	sequence=probe.ui.chat.sequence;probe.ui.chat.submit("-native-npc-stop")
	if not await probe.wait_for(func():return not status("NATIVE_NPC_STOP:",sequence).is_empty(),"Original NPC script executes its actual ClearAllActions stop"): return false
	var stopped:=status_action(status("NATIVE_NPC_STOP:",sequence),"NATIVE_NPC_STOP:");var invalid:=int(probe.session.args.get("npc-action-invalid","-2"))
	if not probe.check(stopped==invalid and invalid>=0,"Original GetCurrentAction confirms the NPC queue is empty",{"actual":stopped,"expectedFromInstalledHeader":invalid}): return false
	return await probe.wait_for(func():return scope_valid() and int(current_source(attacker).get("replicated",{}).get("animation",-1)) in [0,1] and state().get("current",{}).is_empty() and int(state().get("visual",-1)) in [0,1],"Original NPC stop returns the received and private presentation to its idle/ready base")
func run(owner) -> void:
	probe=owner;desktop=probe.desktop;started=Time.get_ticks_usec();var combat=probe.session.world.combat
	combat.engine.presentation_event.connect(capture)
	var passed: bool=await exercise()
	if is_instance_valid(combat) and combat.engine.presentation_event.is_connected(capture): combat.engine.presentation_event.disconnect(capture)
	probe.check(passed and scope_valid(),"NPC combat scoped original-server presentation outcome complete",{"attacker":attacker,"defender":defender,"controlledId":desktop.actor_id,"lifetime":lifetime,"defenderLifetime":defender_lifetime,"generation":generation,"areaId":area_id,"state":state().duplicate(true),"metadata":metadata().duplicate(true),"events":events.duplicate(true),"gpu":false,"pixelsAccepted":false,"fullCombatParity":false})
