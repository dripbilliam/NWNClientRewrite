extends RefCounted

signal presentation_event(value: Dictionary)
const Queue = preload("res://systems/animation_queue.gd")
const Selector = preload("res://systems/attack_animation.gd")
const MovementCue=preload("res://systems/native_data/movement_cue.gd")
const RELEASE = {17: 250, 18: 251, 19: 252, 20: 253, 61: 261}
const GAITS = [2, 3, 4, 78, 79, 84, 85, 86, 87]
var rigs
var pivots: Dictionary = {}
var actors: Dictionary = {}
var states: Dictionary = {}
var selector = Selector.new()
var last_ms := 0
var record_identity := 0
var pending: Array = []
var events: Array = []
var failures: Array = []
var failed: Dictionary = {}
var stats := {"casts": 0, "attacks": 0, "hits": 0, "plays": 0, "reactions": 0, "retired": 0,"movement_cues":0}
var clock_ms: Callable
var _base_pivot_position: Dictionary = {}
var _base_pivot_rotation: Dictionary = {}
var _base_actor_orientation: Dictionary = {}

func now() -> int:
	return int(clock_ms.call()) if clock_ms.is_valid() else Time.get_ticks_msec()

static func category(type: int, animation: int) -> int:
	type &= 255
	animation &= 65535
	if type == 5:
		return int(animation <= 33 and (0x3400181e3 >> animation) & 1 or animation >= 36 and animation <= 98 and (0x6e0000000de1083d >> (animation - 36)) & 1 or animation >= 101 and animation <= 170 or animation >= 250 and animation <= 253 or animation == 261)
	if type == 10:
		return int(animation <= 51 and (0xc000000400001 >> animation) & 1 or animation == 72)
	if type == 9:
		return int(animation >= 72 and animation <= 76 or animation == 0)
	return 0

static func base_loop(type: int,animation: int) -> bool:
	# Animation category is an action-queue classification, not a loop flag.
	# A repeated locomotion observation must retain its initial looping gait.
	return type==5 and (animation&65535) in GAITS or category(type,animation)==1

static func clock(ms: int) -> Dictionary:
	# Leave a whole day before this engine's epoch for deferred loading cues.
	return {"day": 1 + int(ms / 7200000), "time": posmod(ms, 7200000)}

func configure(value, roots: Dictionary) -> void:
	reset()
	rigs = value
	pivots = roots
	last_ms = now()
	if is_instance_valid(rigs) and not rigs.animation_event.is_connected(model_event):
		rigs.animation_event.connect(model_event)
	selector.actors = actors
	selector.state = states

func reset() -> void:
	if is_instance_valid(rigs) and rigs.animation_event.is_connected(model_event):
		rigs.animation_event.disconnect(model_event)
	rigs = null
	pivots = {}
	actors.clear()
	states.clear()
	pending.clear()
	failed.clear()
	events.clear()
	failures.clear()
	record_identity = 0
	selector.random_state = 1
	selector.draws = 0
	_base_pivot_position.clear()
	_base_pivot_rotation.clear()
	_base_actor_orientation.clear()
	for key in stats:
		stats[key] = 0

func event(kind: String, id: int, values: Dictionary = {}) -> void:
	var row := {"kind": kind, "id": id, "atMs": now()}
	row.merge(values)
	events.append(row)
	if events.size() > 180:
		events.pop_front()
	presentation_event.emit(row)

func failure(id: int, reason: String) -> void:
	var key := "%s:%s" % [id, reason]
	if not failed.has(key):
		failed[key] = true
		failures.append(key)
		if failures.size() > 100:
			failures.pop_front()

func ensure(id: int) -> Dictionary:
	if not actors.has(id) or not is_instance_valid(rigs) or not rigs.entities.has(id):
		return {}
	var model: Dictionary = rigs.entities[id]
	if not is_instance_valid(model.root):
		return {}
	var identity: int = model.root.get_instance_id()
	if states.has(id) and (int(states[id].model_identity) != identity or int(states[id].lifetime) != int(actors[id].lifetime)):
		states.erase(id)
		stats.retired += 1
	if not states.has(id):
		var context: Dictionary = model.context.duplicate(true)
		if int(actors[id].objectType) == 5 and context.is_empty():
			failure(id, "Original animation context is unavailable")
			return {}
		states[id] = {"model_identity": identity, "lifetime": actors[id].lifetime, "context": context, "side": 0, "observed": -1, "base": 0, "visual": 0, "speed": 1.0, "queue": Queue.new(), "current": {}, "pending": null, "action": null}
	actors[id]["context"] = states[id].context
	return states[id]

func receive(message: Dictionary) -> void:
	if message.kind == "combat-actors":
		var alive := {}
		for row in message.actors:
			var id := int(row.id)
			if actors.has(id) and int(actors[id].lifetime) != int(row.lifetime):
				states.erase(id)
			actors[id] = row.duplicate(true)
			alive[id] = true
		for id in actors.keys():
			if not alive.has(id):
				actors.erase(id)
				states.erase(id)
	else:
		for row in message.events:
			if pending.size() < 512:
				pending.append({"row": row, "received": now()})

func base_frame(id: int, animation: int, speed: float = 1.0) -> void:
	var s := ensure(id)
	if s.is_empty():
		if is_instance_valid(rigs):
			if animation != 9:
				rigs.set_animation(id, int(RELEASE.get(animation, animation)), speed)
		return
	if pivots.has(id):
		actors[id].position = pivots[id].global_position
		var rotation: float = pivots[id].rotation.y
		actors[id].orientation = Vector3(-sin(rotation), 0, -cos(rotation))
		_base_pivot_position[id] = actors[id].position
		_base_pivot_rotation[id] = rotation
		_base_actor_orientation[id] = actors[id].orientation
	if int(s.observed) == animation:
		if animation in GAITS and s.has("motionPathActive") and not s.motionPathActive:
			return
		if s.current.is_empty() and s.queue.entries.is_empty() and animation != 9 and not RELEASE.has(animation):
			play(id, animation, speed, bool(rigs.entities[id].loop_map.get(str(animation), base_loop(int(actors[id].objectType),animation))), false)
		return
	s.observed = animation
	if RELEASE.has(animation):
		cast_base(id,s,animation)
		return
	if animation == 9:
		return
	# SetBaseAnimation764300 retains its independent+64 resting owner for
	# locomotion. The current gait is visual+5c, never a replacement rest base.
	if animation not in GAITS: s.base = animation
	if animation in [2, 3, 4, 5, 6, 7, 8, 24, 25]:
		s.queue.clear()
		s.current = {}
		play(id, animation, speed, bool(rigs.entities[id].loop_map.get(str(animation), true)), false)
		return
	if s.pending != null and animation in [0, 1]:
		var record: Dictionary = s.pending
		s.pending = null
		s.visual = animation
		attack(id, record)
		return
	if s.current.is_empty() and s.queue.entries.is_empty():
		play(id, animation, speed, base_loop(int(actors[id].objectType),animation), false)

func motion_frame(id: int,remaining_path: Variant) -> void:
	var s:=ensure(id)
	if s.is_empty(): return
	if remaining_path is bool: s.motionPathActive=remaining_path
	else: s.erase("motionPathActive")

func finish_locomotion(id: int,s: Dictionary) -> void:
	# Original7fcd70 restores GetBaseAnimation before queue lookup when the
	# current visual is a gait with no remaining path. Received attack handling
	# happens first, so deferred moving-melee records retain their owner.
	if not s.has("motionPathActive") or s.motionPathActive or int(s.visual) not in GAITS: return
	var base:=int(s.base)
	if not play(id,base,float(actors[id].get("animationSpeed",1.0)),bool(rigs.entities[id].loop_map.get(str(base),base_loop(int(actors[id].objectType),base))),false): return
	if s.pending!=null:
		var record: Dictionary=s.pending; s.pending=null
		attack(id,record)

func cast_base(id: int,s: Dictionary,animation: int) -> void:
	# Original receiver781e80 sets250..253/261 before queuing the cast.
	# SetBaseAnimation764300 immediately replaces a looping/current gait or an
	# expired cue, while a positive-duration one-shot keeps its visual owner.
	s.base = int(RELEASE[animation])
	var visual:=int(s.visual)
	if category(int(actors[id].objectType),visual)==1 or visual in GAITS or int(s.current.get("remaining",0))<1:
		play(id,int(s.base),float(actors[id].get("animationSpeed",1.0)),bool(rigs.entities[id].loop_map.get(str(s.base),base_loop(int(actors[id].objectType),int(s.base)))),false)

func play(id: int, animation: int, speed: float, loop: bool, restart: bool = true) -> bool:
	var s := ensure(id)
	if s.is_empty():
		return false
	if not is_finite(speed) or speed <= 0 or rigs.clip_length(id, animation, int(s.context.get("fieldE0", 0))) <= 0:
		failure(id, "Original clip/speed unavailable for animation %s" % animation)
		return false
	var changed := int(s.visual) != animation or restart
	rigs.set_playback(id, animation, speed, loop, restart, int(s.context.get("fieldE0", 0)))
	s.visual = animation
	s.speed = speed
	if changed:
		stats.plays += 1
		event("play", id, {"animation": animation, "clip": rigs.clip_name(id, animation), "speed": speed, "loop": loop})
	return true

func movement_cue(id: int,request: Dictionary) -> bool:
	var s:=ensure(id)
	if s.is_empty() or not s.current.is_empty() or not s.queue.entries.is_empty() or int(s.visual) not in [0,1]: return false
	var code:=int(request.get("animation",-1))
	if code not in [24,25,26,27,80,81,82,83]: return false
	var length: float=rigs.clip_length(id,code,int(s.context.get("fieldE0",0)))
	if length<=0:
		failure(id,"Original movement clip unavailable for animation %s"%code); return false
	var cue:=MovementCue.build(request,length,float(actors[id].get("animationSpeed",1.0)))
	if cue.has("error"): failure(id,str(cue.error)); return false
	insert(id,cue); stats.movement_cues+=1
	event("movement-cue",id,{"animation":code,"type":int(request.get("type",0)),"duration":cue.duration,"speed":cue.speed})
	return true
func insert(id: int, cue: Dictionary, age: int = 0) -> void:
	var s := ensure(id)
	if s.is_empty():
		return
	cue.side = int(s.context.get("fieldE0", 0))
	if not s.queue.insert(cue, clock(now() - age)) and s.queue.entries.size() >= 255:
		failure(id, "Native animation queue rejected a cue")

func attack(id: int, record: Dictionary, age: int = 0) -> void:
	var s := ensure(id)
	if s.is_empty() or int(record.get("type", 0)) != 1:
		return
	if int(s.visual) in [2, 4, 24, 25] and int(record.ranged) == 0 and int(rigs.entities[id].body_type) == 1:
		s.pending = record
		event("prepare-moving-melee", id)
		return
	var animation: int = selector.select(actors[id], record)
	if animation < 0:
		failure(id, "Replicated attack selector metadata is unavailable")
		return
	var length: float = Queue.f(rigs.clip_length(id, animation, int(s.context.get("fieldE0", 0))) * 1000)
	if length <= 0 or int(record.duration) <= 0:
		failure(id, "Attack model clip or duration is unavailable")
		return
	insert(id, {"animation": animation, "duration": int(record.duration), "speed": Queue.f(length / float(record.duration)), "record": record, "delay": 0}, age)
	stats.attacks += 1
	if selector.random() % 3 == 0:
		event("bark", id, {"code": 11 + selector.random() % 3})
	var target := int(record.targetId)
	var ts := ensure(target)
	if ts.is_empty() or bit(0x4ab, int(record.result)) or int(ts.visual) not in [0, 1] or int(record.reaction) < 2:
		return
	var reaction_length: float = Queue.f(rigs.clip_length(target, int(record.reaction)) * 1000)
	var divisor := Queue.f(float(record.reactionDuration) + (Queue.f(float(record.reactionDelay)) if int(record.reaction) == 262 else 0.0))
	if reaction_length > 0 and divisor > 0:
		insert(target, {"animation": int(record.reaction), "duration": int(record.reactionDuration), "speed": Queue.f(reaction_length / divisor), "record": null, "delay": 0}, age)
		stats.reactions += 1

static func bit(mask: int, result: int) -> bool:
	return result < 11 and result >= 0 and bool((mask >> result) & 1)

func end(id: int) -> void:
	var s := ensure(id)
	if not s.is_empty():
		s.current = {}
		s.visual = s.base

func reaction(id: int, animation: int) -> void:
	var s := ensure(id)
	if s.is_empty():
		return
	var speed := 1.0 if int(actors[id].objectType) == 9 else float(actors[id].get("animationSpeed", 1.0))
	var length: float = Queue.f(rigs.clip_length(id, animation) * 1000)
	if length > 0:
		insert(id, {"animation": animation, "duration": int(length if speed == 0 else length / absf(speed)), "speed": speed, "record": null, "delay": 0})
		stats.reactions += 1

func model_event(id: int, name: String, _serial: int) -> void:
	var original_event:=name.to_lower()
	if original_event in ["blur_start","blur_end","doneattack01","doneattack02"]:
		var state:=ensure(id)
		if not state.is_empty(): event("weapon-start" if original_event=="blur_start" else "weapon-end",id,{"animation":state.visual,"attackType":int(state.get("attackType",0)),"modelEvent":original_event})
		return
	if name.to_lower() != "hit":
		return
	var s := ensure(id)
	if s.is_empty() or s.action == null or int(s.action.type) != 1:
		return
	var record: Dictionary = s.action
	var target := int(record.targetId)
	if not actors.has(target):
		return
	stats.hits += 1
	event("hit", id, {"animation": s.visual, "targetId": target})
	var ts := ensure(target)
	if int(record.ranged) == 0:
		if bit(0x4aa, int(record.result)):
			event("sound", id, {"phase": 0})
			if int(actors[target].objectType) != 5 or ts.is_empty() or int(ts.visual) not in [0, 1]:
				if int(actors[target].objectType) in [9, 10] and int(record.reaction) > 1:
					reaction(target, int(record.reaction))
			elif record.get("next") == null and int(record.reaction) > 1:
				reaction(target, int(record.reaction))
			if int(actors[target].objectType) == 5:
				var hp: Variant = actors[target].get("hitPoints")
				if hp == null:
					failure(target, "Native target HP for damage bark is unavailable")
				if hp != null and int(hp) > 0 and int(record.killingBlow) == 0 and (int(record.damage) & 65535) != 0 and selector.random() % 3 == 0:
					event("bark", target, {"code": 14 + selector.random() % 3})
		elif not ts.is_empty() and int(ts.visual) in [206, 207, 208, 262] and int(record.result) in [2, 4]:
			event("sound", id, {"phase": 0})
			if actors[id].get("abortOnParry") != null and int(actors[id].abortOnParry) != 0:
				event("weapon-end", id)
				if rigs.entities[id].get("model18_unavailable", false):
					failure(id, "Native robe model18 for parry abort is unavailable")
					return
				if not rigs.entities[id].get("model18", false):
					end(id)
			if record.get("next") != null:
				end(target)
			if int(actors[target].objectType) == 5 and int(record.weaponAttackType) != 7:
				for slot in [16, 16384, 32768, 65536]:
					if actors[target].get("equipment", {}).has(str(slot)):
						event("parry", id, {"targetId":target,"record":record.duplicate(true)})
						break
		var signed_damage := int(record.damage) & 65535
		if signed_damage & 32768:
			signed_damage -= 65536
		if bit(0x4aa, int(record.result)) and signed_damage > 0 and int(actors[target].objectType) == 5:
			event("impact", target, {"sourceId": id, "record": record.duplicate(true)})
	if record.get("next") != null:
		end(id)
		event("weapon-end", id)
		attack(id, record.next)
		event("sound", id, {"phase": 1})

func update(_delta: float = 0.0, now_ms: int = -1) -> void:
	if not is_instance_valid(rigs):
		_base_pivot_position.clear(); _base_pivot_rotation.clear(); _base_actor_orientation.clear()
		return
	if now_ms < 0:
		now_ms = now()
	var elapsed := now_ms - last_ms
	last_ms = now_ms
	for id in actors:
		if pivots.has(id):
			var position: Vector3 = pivots[id].global_position
			var rotation: float = pivots[id].rotation.y
			if _base_pivot_position.has(id) and _base_pivot_position[id] == position and _base_pivot_rotation[id] == rotation and actors[id].position == position and actors[id].orientation == _base_actor_orientation[id]:
				continue
			actors[id].position = position
			actors[id].orientation = Vector3(-sin(rotation), 0, -cos(rotation))
	_base_pivot_position.clear(); _base_pivot_rotation.clear(); _base_actor_orientation.clear()
	var waiting: Array = []
	for item in pending:
		var row: Dictionary = item.row
		var id := int(row.id)
		if not actors.has(id) or int(actors[id].lifetime) != int(row.lifetime):
			continue
		var s := ensure(id)
		if s.is_empty():
			waiting.append(item)
			continue
		var age := int(row.get("ageMs", 0)) + maxi(0, now_ms - int(item.received))
		if row.action == "cast-animation":
			var animation := int(row.animation)
			if not RELEASE.has(animation):
				failure(id, "Invalid native cast animation")
				continue
			cast_base(id,s,animation)
			var length: float = Queue.f(rigs.clip_length(id, animation) * 1000)
			insert(id, {"animation": animation, "duration": 500, "speed": Queue.f(length / 500), "record": row.record, "delay": 0}, age)
			stats.casts += 1
		else:
			var records: Array = row.records.duplicate(true)
			for i in records.size():
				record_identity += 1
				records[i]._identity = record_identity
				records[i]["next"] = records[i + 1] if i + 1 < records.size() else null
			if not records.is_empty():
				event("sound", id, {"phase": 1})
				attack(id, records[0], age)
	pending = waiting
	for id in states.keys():
		var s := ensure(id)
		if s.is_empty():
			states.erase(id)
			continue
		finish_locomotion(id,s)
		if not s.current.is_empty():
			s.current.remaining = Queue.signed(int(s.current.remaining) - elapsed)
			if int(s.current.remaining) < 0:
				s.current = {}
				play(id, int(s.base), float(actors[id].get("animationSpeed", 1.0)), category(int(actors[id].objectType), int(s.base)) == 1)
		if category(int(actors[id].objectType), int(s.visual)) != 1:
			continue
		var cue: Dictionary = s.queue.next(clock(now_ms))
		if cue.is_empty():
			continue
		if cue.record != null and (int(cue.record.type) == 4 or int(cue.animation) in [200, 201, 202, 203, 204, 205, 263, 264, 265]):
			s.action = cue.record
		s.context.fieldE0 = int(cue.side)
		if play(id, int(cue.animation), float(cue.speed), false):
			s.current = {"remaining": Queue.signed(int(cue.duration))}
		s.queue.remove()

func snapshot() -> Dictionary:
	var rows: Array = []
	for id in states:
		var s: Dictionary = states[id]
		rows.append({"id": id, "base": s.base, "visual": s.visual, "pending": s.queue.entries.size(), "remaining": s.current.get("remaining"), "deferred": s.pending != null})
	return {"stats": stats.duplicate(true), "actors": rows, "events": events.duplicate(true), "failures": failures.duplicate()}
