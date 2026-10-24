extends SceneTree

const Selector = preload("res://systems/attack_animation.gd")
const Queue = preload("res://systems/animation_queue.gd")
const Combat = preload("res://systems/combat_animation.gd")
const Rigs = preload("res://systems/model_rigs.gd")
var output := ""
var failures: Array = []
var checks := 0
var fake_ms := 1000

class Models extends Node:
	signal animation_event(id: int, name: String, serial: int)
	var entities: Dictionary = {}
	var played: Array = []
	func clip_length(_id: int, _animation: int, _side: int = -1) -> float:
		return 1.0
	func clip_name(_id: int, animation: int, _side: int = -1) -> String:
		return "authored_%s" % animation
	func set_playback(id: int, animation: int, speed: float, loop: bool, restart: bool, side: int) -> void:
		played.append({"id": id, "animation": animation, "speed": speed, "loop": loop, "restart": restart, "side": side})
	func set_animation(id: int, animation: int, speed: float) -> void:
		set_playback(id, animation, speed, true, false, 0)

func scheduler_checks() -> void:
	var models := Models.new()
	root.add_child(models)
	var roots := {}
	var actors: Array = []
	for id in [1, 2]:
		var node := Node3D.new()
		root.add_child(node)
		node.position = Vector3(0, 0, -2.5) if id == 2 else Vector3.ZERO
		roots[id] = node
		models.entities[id] = {"root": node, "context": {"fieldDE": 1, "fieldDD": 1, "fieldDF": 2, "fieldE0": 0}, "body_type": 1, "loop_map": {}, "model18": false}
		actors.append({"id": id, "lifetime": id, "objectType": 5, "equipment": {}, "monk": false, "hitDistance": 0.5, "preferredDistance": 2.0, "weaponScale": 1.0, "targetHeight": "", "facingTarget": 0x7f000000, "hitPoints": 100, "animationSpeed": 1.0, "abortOnParry": 0})
	var combat := Combat.new()
	combat.clock_ms = func(): return fake_ms
	combat.configure(models, roots)
	combat.receive({"kind": "combat-actors", "actors": actors})
	combat.base_frame(1, 0)
	combat.base_frame(2, 0)
	combat.receive({"kind": "combat-events", "events": [{"id": 1, "lifetime": 1, "action": "cast-animation", "animation": 17, "record": {"type": 4}, "ageMs": 0}]})
	combat.update()
	check(int(combat.states[1].visual) == 17 and int(combat.states[1].current.remaining) == 500, "Server cast starts one native 500 ms cue")
	check(is_equal_approx(float(models.played[-1].speed), 2.0) and not models.played[-1].loop, "Original clip length scales into the fixed cast duration")
	combat.base_frame(1, 17)
	fake_ms = 1500
	combat.update()
	check(int(combat.states[1].visual) == 17, "Native signed countdown retains a zero-duration current action")
	fake_ms = 1501
	combat.update()
	check(int(combat.states[1].visual) == 250 and models.played[-1].loop, "Cast release restores its original looping base only after negative countdown")
	combat.base_frame(1, 0)
	var attack := {"type": 1, "sourceId": 1, "targetId": 2, "duration": 1000, "result": 1, "reaction": 14, "reactionDuration": 500, "reactionDelay": 0, "attackType": 0, "ranged": 0, "weaponAttackType": 1, "killingBlow": 0, "damage": 1}
	combat.receive({"kind": "combat-events", "events": [{"id": 1, "lifetime": 1, "action": "attack-animation", "records": [attack, attack.duplicate(true)], "ageMs": 0}]})
	combat.update()
	check(int(combat.stats.attacks) == 1 and int(combat.states[1].visual) in [200, 201, 202], "Actual action records select and play a native melee clip")
	var serial := models.played.size()
	models.animation_event.emit(1, "HiT", 1)
	combat.update()
	check(int(combat.stats.hits) == 1 and int(combat.stats.attacks) == 2 and models.played.size() > serial, "Original hit event advances a linked attack before the first clip ends")
	check(combat.actors[2].hitPoints == 100, "Native combat presentation never applies damage to replicated HP")
	combat.base_frame(1, 2)
	check(combat.states[1].current.is_empty() and combat.states[1].queue.entries.is_empty(), "Changed moving base interrupts the presentation queue")
	combat.receive({"kind": "combat-events", "events": [{"id": 1, "lifetime": 1, "action": "attack-animation", "records": [attack], "ageMs": 0}]})
	combat.update()
	check(combat.states[1].pending != null, "Moving melee waits for a resting native base")
	combat.base_frame(1, 0)
	combat.update()
	check(combat.states[1].pending == null and not combat.states[1].current.is_empty(), "Resting resumes the original deferred attack record")
	var old_identity: int = combat.states[1].model_identity
	var replacement := Node3D.new()
	root.add_child(replacement)
	models.entities[1].root = replacement
	combat.base_frame(1, 0)
	check(int(combat.states[1].model_identity) != old_identity and combat.states[1].current.is_empty(), "A replacement physical model retires all old playback ownership")
	var changed := actors.duplicate(true)
	changed[0].lifetime = 55
	combat.receive({"kind": "combat-actors", "actors": changed})
	var before: int = combat.stats.casts
	combat.receive({"kind": "combat-events", "events": [{"id": 1, "lifetime": 1, "action": "cast-animation", "animation": 17, "record": {"type": 4}}]})
	combat.update()
	check(int(combat.stats.casts) == before, "Reused object IDs cannot accept an old creature's cast")
	combat.reset()
	check(combat.states.is_empty() and combat.pending.is_empty() and not models.animation_event.is_connected(combat.model_event), "World retirement releases native queues and model-event callbacks")
	for node in roots.values():
		node.free()
	replacement.free()
	models.free()

func actual_player_checks() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var rigs := Rigs.new()
	host.add_child(rigs)
	rigs.set_process(false)
	var player := AnimationPlayer.new()
	host.add_child(player)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length = 0.1
	library.add_animation("one", clip)
	player.add_animation_library("", library)
	var model := {"player": player, "names": {"one": "one"}, "clip": "", "loop": false, "speed": 1.0, "event_source": true, "play_serial": 0, "events": {"one": [{"time": 0.1, "name": "hit"}]}, "transitions": {}}
	rigs.entities[1] = {"models": [model], "nodes": [], "parents": [], "skins": [], "attachments": []}
	var hit_events: Array = []
	rigs.animation_event.connect(func(_id, name, _serial): hit_events.append(name))
	for frame in 3:
		rigs._update(0.02)
	check(hit_events.is_empty() and not player.is_playing(), "Real inactive AnimationPlayer never queries a missing current clock")
	rigs._play(model, "one", false, 1.0)
	rigs._update(0.2)
	check(hit_events == ["hit"] and not player.is_playing(), "Finishing an actual one-shot emits its final original model event once")
	rigs._update(0.2)
	check(hit_events == ["hit"], "Finished one-shots neither query an invalid clock nor repeat terminal events")
	rigs._play(model, "one", false, 1.0, 0.0, true)
	rigs._update(0.2)
	check(hit_events == ["hit", "hit"], "Repeated identical action restarts the actual player and its event timeline")
	host.free()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value and failures.size() < 20:
		failures.append(message)

func vector(data: Array) -> Vector3:
	return Vector3(data[0], data[1], data[2])

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):
		quit(2)
		return
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/combat-oracle-v1.json"))
	for index in oracle.cases.size():
		var row: Dictionary = oracle.cases[index]
		var selector := Selector.new()
		selector.random_state = int(row.seed)
		var actor: Dictionary = row.actor.duplicate(true)
		var target: Dictionary = row.target.duplicate(true)
		actor.position = vector(actor.position)
		target.position = vector(target.position)
		target.orientation = vector(target.orientation)
		var state := {"side": int(row.side), "context": actor.context.duplicate(true), "base": 0}
		selector.actors = {1: actor, 2: target}
		selector.state = {1: state, 2: {"base": int(target.base)}}
		var record: Dictionary = row.record.duplicate(true)
		var animation: int = selector.select(actor, record)
		var expected: Dictionary = row.expected
		check(animation == int(expected.animation) and state.side == int(expected.side) and int(state.context.fieldE0) == int(expected.contextSide) and state.base == int(expected.base) and int(record.reaction) == int(expected.reaction) and int(record.reactionDelay) == int(expected.reactionDelay) and selector.draws == int(expected.draws), "Attack selector case %s: got %s/%s/%s/%s/%s draws%s expected%s" % [index, animation, state.side, state.context.fieldE0, record.reaction, record.reactionDelay, selector.draws, expected])
	for row in oracle.queues:
		var queue := Queue.new()
		queue.insert({"animation": 17, "duration": int(row.duration), "speed": Queue.f(1.7), "record": null}, row.start)
		var next: Dictionary = queue.next(row.now)
		check(int(next.duration) == int(row.expected.duration) and absf(float(next.speed) - float(row.expected.speed)) < 0.000001, "Native unsigned animation queue timing %s" % row)
	for row in oracle.category:
		check(Combat.category(int(row.type), int(row.id)) == int(row.expected), "Original loop category %s/%s" % [row.type, row.id])
	for row in oracle.intervals:
		check(Rigs.model_events(oracle.events, row.from, row.to, int(row.flags)) == row.expected, "Original event interval %s" % row)
	scheduler_checks()
	actual_player_checks()
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": oracle.scope, "checks": checks, "failures": failures}, "  "))
	file.close()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
