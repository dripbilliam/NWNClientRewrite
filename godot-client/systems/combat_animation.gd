extends RefCounted

signal presentation_event(value: Dictionary)
signal presentation_failure(value: Dictionary)
const Queue = preload("res://systems/animation_queue.gd")
const Selector = preload("res://systems/attack_animation.gd")
const MovementCue=preload("res://systems/native_data/movement_cue.gd")
const CastCue=preload("res://systems/native_data/native_cast_animation_records.gd")
const NetworkBase=preload("res://systems/native_data/network_combat_base.gd")
const RELEASE = {17: 250, 18: 251, 19: 252, 20: 253, 61: 261}
const GAITS = [2, 3, 4, 78, 79, 84, 85, 86, 87]
var rigs
var pivots: Dictionary = {}
var actors: Dictionary = {}
var states: Dictionary = {}
var selector = Selector.new()
var day_length := 7200000
var last_ms := 0
var seconds := 0.0
var frames := 0
var frame_milliseconds := 0
var record_identity := 0
var pending: Array = []
var events: Array = []
var failures: Array = []
var failed: Dictionary = {}
var stats := {"casts": 0, "attacks": 0, "hits": 0, "plays": 0, "reactions": 0, "retired": 0,"movement_cues":0}
var clock_ms: Callable
var body_clock_ms: Callable
var object_lookup: Callable

func source_object(id: int) -> Variant:
	return object_lookup.call(id) if object_lookup.is_valid() else actors.get(id)
static func source_visual(object: Dictionary) -> int:
	var replicated: Variant=object.get("replicated")
	return int(replicated.get("animation",0)) if replicated is Dictionary else int(object.get("base",0))
static func source_hit_points(object: Dictionary) -> Variant:
	var replicated: Variant=object.get("replicated")
	if not replicated is Dictionary:return null
	var hit_points: Variant=replicated.get("hitPoints")
	return hit_points.get("current") if hit_points is Dictionary else null
static func source_has_parry_weapon(object: Dictionary) -> bool:
	var appearance: Variant=object.get("appearance")
	if not appearance is Dictionary:return false
	var equipment: Variant=appearance.get("equipment")
	if not equipment is Array:return false
	for entry in equipment:
		if entry is Dictionary and int(entry.get("slot",-1)) in [16,16384,32768,65536] and entry.get("item")!=null:return true
	return false

func now() -> int:
	return int(clock_ms.call()) if clock_ms.is_valid() else Time.get_ticks_msec()

func body_now(id: int) -> int:
	if body_clock_ms.is_valid():
		var value: Variant=body_clock_ms.call(id)
		if value is int:return value
	return now()

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
	if type==5:
		var base:=animation&65535
		return base not in [5,6,7,8,9] and (category(type,base)==1 or base in [2,3,4])
	return category(type,animation)==1

static func body_transition(previous: int, requested: int) -> Variant:
	# clientBodyTransition: comparisons intentionally run in source order. A
	# later leave state can replace an earlier enter state.
	previous &= 65535
	requested &= 65535
	var known_previous := previous <= 170 or previous >= 250 and previous <= 253 or previous in [261,267,273]
	var known_requested := requested <= 170 or requested >= 250 and requested <= 253 or requested in [261,267,273]
	if not known_previous or not known_requested: return null
	if previous == requested or category(5, requested) == 0 or previous in [0,1] and requested in [0,1]: return []
	var animation := 0
	var reaction := 0
	var reaction_duration := 0
	for entry in [[59,255,256],[60,257,258],[36,239,240],[47,211,212],[97,282,283],[98,284,285]]:
		if requested == entry[0]: animation = entry[1]
		if previous == entry[0]: animation = entry[2]
	for i in 70:
		if requested == 101+i: animation = 286+i*2
		if previous == 101+i: animation = 287+i*2
	if requested in [32,33]: animation = 237
	if previous in [32,33]: animation = 238
	if requested == 22: animation = 302 if previous == 50 else 303
	if previous == 22: animation = 300 if requested == 50 else 301
	if requested == 75: animation = 402
	if previous == 75: animation = 403
	if requested == 73: animation = 401
	if previous == 73: animation = 400
	if requested == 72: animation = 404
	if previous == 6:
		animation = 225
		if requested != 5:
			reaction = 223
			reaction_duration = 1000
	elif previous == 8:
		animation = 226
		if requested != 7:
			reaction = 224
			reaction_duration = 1000
	elif previous == 5: animation = 223
	elif previous == 7: animation = 224
	if requested == 5: animation = 219
	elif requested == 7: animation = 220
	elif requested == 63: animation = 267
	elif requested == 95: animation = 273
	elif requested == 62: animation = 266
	elif requested == 94: animation = 272
	elif requested == 6:
		animation = 219
		reaction = 221
		reaction_duration = 1000
	elif requested == 8:
		animation = 220
		reaction = 222
		reaction_duration = 1000
	if requested in [30,38,39,40,41]: animation = 271
	return [{"animation":animation,"reaction":reaction,"reactionDuration":reaction_duration}] if animation else []

func clock(ms: int) -> Dictionary:
	# Leave a whole day before this engine's epoch for deferred loading cues.
	return {"day": 1 + int(ms / day_length), "time": posmod(ms, day_length)}

func configure(value, roots: Dictionary) -> void:
	reset()
	rigs = value
	pivots = roots
	last_ms = now()
	seconds = 0.0
	frames = 0
	frame_milliseconds = 0
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
	for s in states.values():
		if s.has("queue"):s.queue.clear()
	states.clear()
	pending.clear()
	failed.clear()
	events.clear()
	failures.clear()
	record_identity = 0
	selector.random_state = 1
	selector.draws = 0
	object_lookup=Callable()
	body_clock_ms=Callable()
	for key in stats:
		stats[key] = 0

func retire_state(id: int) -> void:
	if states.has(id):
		var s: Dictionary=states[id]
		if s.has("queue"):s.queue.clear()
		states.erase(id)

func event(kind: String, id: int, values: Dictionary = {}) -> void:
	var row := {"kind": kind, "id": id, "objectId": id, "atMs": now(), "at": seconds}
	row.merge(values)
	# Old NetworkCombatPresentation.snapshot records selected sound output,
	# playback and overdue cues; raw provider/visual handoff events stay live.
	if kind in ["play","overdue","hit","parry-visual","blood-visual"] or kind=="sound" and not values.has("record"):
		events.append(row)
		if events.size() > 100:events.pop_front()
	presentation_event.emit(row)

func failure(id: int, reason: String, code: String = "network.scene-combat-unhandled") -> void:
	var lifetime: int=int(actors.get(id,{}).get("lifetime",0))
	var key := "%s:%s:%s:%s" % [id,lifetime,code,reason]
	if not failed.has(key):
		failed[key] = true
		failures.append(key)
		if failures.size() > 100:
			failures.pop_front()
		presentation_failure.emit({"id":id,"code":code,"reason":reason})

func ensure(id: int) -> Dictionary:
	if not actors.has(id) or not is_instance_valid(rigs) or not rigs.entities.has(id):
		return {}
	var model: Dictionary = rigs.entities[id]
	if not is_instance_valid(model.root):
		return {}
	var identity: int = model.root.get_instance_id()
	if states.has(id) and (int(states[id].model_identity) != identity or int(states[id].lifetime) != int(actors[id].lifetime)):
		retire_state(id)
		stats.retired += 1
	if not states.has(id):
		var context: Dictionary = model.context.duplicate(true)
		if int(actors[id].objectType) == 5 and context.is_empty():
			failure(id, "Original animation context is unavailable")
			return {}
		var initial_base: int=0 if int(actors[id].objectType)==5 else int(actors[id].get("base",0))
		var queue:=Queue.new()
		queue.day_length=day_length
		states[id] = {"model_identity": identity, "lifetime": actors[id].lifetime, "context": context, "side": 0, "observed": -1, "base": initial_base, "visual": initial_base, "speed": 1.0, "queue": queue, "current": {}, "pending": null, "body_transitions": [], "body_current": {}, "body_requested": -1, "action": {"type":0,"sourceId":0x7f000000,"targetId":0x7f000000}}
	actors[id]["context"] = states[id].context
	return states[id]

func receive(message: Dictionary) -> void:
	if message.kind == "combat-actors":
		var alive := {}
		for row in message.actors:
			var id := int(row.id)
			if actors.has(id) and int(actors[id].lifetime) != int(row.lifetime):
				retire_state(id)
			actors[id] = row.duplicate(true)
			alive[id] = true
		for id in actors.keys():
			if not alive.has(id):
				actors.erase(id)
				retire_state(id)
	else:
		for row in message.events:
			if pending.size() < 512:
				pending.append({"row": row, "received": now()})

func base_frame(id: int, animation: int, speed: float = 1.0, update_motion: bool = false, remaining_path: Variant = null) -> void:
	var s := ensure(id)
	# A binding failure can synchronously notify the owner. Keep the second
	# lookup from the former two calls when that notification can bind a rig.
	if update_motion and s.is_empty():
		s = ensure(id)
		update_motion = false
	if s.is_empty():
		if is_instance_valid(rigs):
			if animation != 9:
				rigs.set_animation(id, int(RELEASE.get(animation, animation)), speed)
		return
	if update_motion:
		_set_motion_path(s,remaining_path)
	if pivots.has(id):
		actors[id].position = pivots[id].global_position
		var rotation: float = pivots[id].rotation.y
		actors[id].orientation = Vector3(-sin(rotation), 0, -cos(rotation))
	if int(s.observed) == animation:
		if int(s.get("body_requested",-1))>=0: return
		if animation in GAITS and s.has("motionPathActive") and not s.motionPathActive:
			return
		if s.current.is_empty() and s.queue.entries.is_empty() and animation != 9 and not RELEASE.has(animation):
			_play_validated(id,s,animation,speed,bool(rigs.entities[id].loop_map.get(str(animation),base_loop(int(actors[id].objectType),animation))),false)
		return
	var previous: int=int(s.observed)
	s.observed = animation
	var decision: Dictionary=NetworkBase.creature(animation,s.pending!=null,not s.current.is_empty(),not s.queue.entries.is_empty())
	if int(actors[id].objectType)==5 and previous>=0 and start_body_transition(id,s,previous,animation):
		s.base=int(decision.get("base",animation))
		return
	if decision.mode=="cast":
		s.base=int(decision.base)
		return
	if decision.mode=="hold":return
	if int(actors[id].objectType)!=5 and NetworkBase.object_base(category(int(actors[id].objectType),animation),int(s.base),animation):
		s.queue.clear();s.current={};s.visual=animation;s.speed=speed
	# SetBaseAnimation764300 retains its independent+64 resting owner for
	# locomotion. The current gait is visual+5c, never a replacement rest base.
	s.base=int(decision.base)
	if decision.mode=="locomotion":
		s.queue.clear()
		s.current = {}
		play(id, animation, speed, bool(rigs.entities[id].loop_map.get(str(animation), true)), false)
		return
	if decision.mode=="pending":
		var record: Dictionary = s.pending
		s.pending = null
		s.visual = animation
		attack(id, record)
		return
	if s.current.is_empty() and s.queue.entries.is_empty():
		play(id, animation, speed, base_loop(int(actors[id].objectType),animation), false)

func start_body_transition(id: int,s: Dictionary,previous: int,requested: int) -> bool:
	var calls: Variant=body_transition(previous,requested)
	if calls==null:
		failure(id,"Native base transition %s to %s is not connected"%[previous,requested])
		return false
	if calls.is_empty(): return false
	# The old bridge drops queued actor presentation cues, not undelivered
	# canonical network messages. Subsequent clips play in source order.
	s.queue.clear()
	s.current={}
	s.body_transitions=[]
	s.body_current={}
	s.body_requested=requested
	for call in calls:
		var first_duration: Variant=1000 if int(call.reaction)!=0 and int(call.animation) in [219,220,221,222] else null
		s.body_transitions.append({"animation":int(call.animation),"duration":first_duration})
		if int(call.reaction)!=0:
			s.body_transitions.append({"animation":int(call.reaction),"duration":int(call.reactionDuration)})
	advance_body_transition(id,s,body_now(id))
	return true

func advance_body_transition(id: int,s: Dictionary,at_ms: int) -> void:
	if not s.body_transitions.is_empty():
		var cue: Dictionary=s.body_transitions.pop_front()
		var code: int=int(cue.animation)
		var clip_seconds: float=rigs.clip_length(id,code,int(s.context.get("fieldE0",0)))
		var actor_speed: float=float(actors[id].get("animationSpeed",1.0))
		var duration_ms: float=0.0
		if cue.duration!=null: duration_ms=float(cue.duration)
		elif actor_speed>0: duration_ms=clip_seconds*1000.0/actor_speed
		if duration_ms<=0 or not is_finite(duration_ms):
			failure(id,"Native animation %s requires unavailable duration"%code)
			s.body_current={}
			return
		var playback_speed: float=clip_seconds*1000.0/duration_ms
		if not play(id,code,playback_speed,false):
			s.body_current={}
			return
		s.body_current={"at":at_ms,"duration":duration_ms}
		return
	s.body_current={}
	var requested: int=int(s.body_requested)
	if requested<0:return
	s.body_requested=-1
	var restored: int=1 if requested==9 else requested
	play(id,restored,float(actors[id].get("animationSpeed",1.0)),base_loop(int(actors[id].objectType),restored))

func observe_object_base(id: int,animation: int,speed: float) -> void:
	# Door/placeable base playback stays with their instance owners. This is the
	# NetworkCombatPresentation combat state reset for a new looping base.
	var s:=ensure(id)
	if s.is_empty() or category(int(actors[id].objectType),animation)!=1 or int(s.base)==animation:return
	s.queue.clear()
	s.current={}
	s.base=animation
	s.visual=animation
	s.speed=speed

func motion_frame(id: int,remaining_path: Variant) -> void:
	var s:=ensure(id)
	if s.is_empty(): return
	_set_motion_path(s,remaining_path)

static func _set_motion_path(s: Dictionary,remaining_path: Variant) -> void:
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
	# NetworkCombatPresentation.base updates the release base before the cue.
	s.base = int(RELEASE[animation])

func play(id: int, animation: int, speed: float, loop: bool, restart: bool = true) -> bool:
	var s := ensure(id)
	return false if s.is_empty() else _play_validated(id,s,animation,speed,loop,restart)

func _play_validated(id: int,s: Dictionary,animation: int,speed: float,loop: bool,restart: bool) -> bool:
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
		failure(id,"Original movement clip unavailable for animation %s"%code,"network.scene-movement-cue-unavailable"); return false
	var cue:=MovementCue.build(request,length,float(actors[id].get("animationSpeed",1.0)))
	if cue.has("error"): failure(id,str(cue.error),"network.scene-movement-cue-unavailable"); return false
	insert(id,cue,0,"network.scene-movement-cue-unavailable"); stats.movement_cues+=1
	event("movement-cue",id,{"animation":code,"type":int(request.get("type",0)),"duration":cue.duration,"speed":cue.speed})
	return true
func insert(id: int, cue: Dictionary, age: int = 0, code: String = "network.scene-combat-unhandled") -> void:
	var s := ensure(id)
	if s.is_empty():
		return
	cue.side = int(s.context.get("fieldE0", 0))
	if not s.queue.insert(cue, clock(now() - age)) and not s.queue.failure.is_empty():
		failure(id,s.queue.failure,code)

func attack(id: int, record: Dictionary, age: int = 0) -> void:
	var s := ensure(id)
	if s.is_empty() or int(record.get("type", 0)) != 1:
		return
	if int(s.visual) in [2, 4, 24, 25] and int(record.ranged) == 0 and int(rigs.entities[id].body_type) == 1:
		s.pending = record
		event("prepare-moving-melee", id)
		return
	var previous_side: int=int(s.side)
	var animation: int = selector.select(actors[id], record)
	if animation < 0:
		var class_state: Dictionary=actors[id].get("classState",{})
		var absent_classes: bool=str(class_state.get("source",""))=="undisclosed-classes"
		var reached_class_check: bool=int(record.ranged)==0 and absent_classes and selector.range_class(actors[id],actors.get(int(record.targetId),{}),record)==2
		failure(id,"Native animation class list is unavailable" if reached_class_check else "Replicated attack selector metadata is unavailable")
		return
	# The old selector calls NetworkCombatPresentation.base(o,1) when a
	# side-2 attack releases to side 1. Its idle visual/speed update occurs
	# before the new attack cue is inserted.
	if previous_side==2 and int(s.side)==1 and int(s.base)==1 and s.current.is_empty() and s.queue.entries.is_empty():
		s.visual=1
		s.speed=float(actors[id].get("animationSpeed",1.0))
	var length: float = Queue.f(rigs.clip_length(id, animation, int(s.context.get("fieldE0", 0))) * 1000)
	if length <= 0 or int(record.duration) <= 0:
		failure(id, "Attack model clip or duration is unavailable")
		return
	insert(id, {"animation": animation, "duration": int(record.duration), "speed": Queue.f(Queue.f(length) / Queue.f(float(record.duration))), "record": record, "delay": 0}, age)
	stats.attacks += 1
	if selector.random() % 3 == 0:
		event("bark", id, {"code": 11 + selector.random() % 3})
	var target := int(record.targetId)
	var target_object: Variant=source_object(target)
	if not target_object is Dictionary:return
	var ts := ensure(target)
	var target_visual: int=int(ts.visual) if not ts.is_empty() else source_visual(target_object)
	if bit(0x4ab, int(record.result)) or target_visual not in [0, 1] or int(record.reaction) < 2:
		return
	if ts.is_empty():
		failure(id,"Native combat model binding is unavailable")
		return
	var reaction_length: float = Queue.f(rigs.clip_length(target, int(record.reaction)) * 1000)
	var divisor := Queue.f(Queue.f(float(record.reactionDuration)) + (Queue.f(float(record.reactionDelay)) if int(record.reaction) == 262 else 0.0))
	if reaction_length<=0:
		failure(id,"Native animation %s requires unavailable clip %s"%[str(record.reaction),rigs.clip_name(target,int(record.reaction))]);return
	if divisor<=0:
		failure(id,"Native nonpositive/nonfinite combat model playback is not connected");return
	insert(target, {"animation": int(record.reaction), "duration": int(record.reactionDuration), "speed": Queue.f(reaction_length / divisor), "record": null, "delay": 0}, age)
	stats.reactions += 1

static func bit(mask: int, result: int) -> bool:
	return result < 11 and result >= 0 and bool((mask >> result) & 1)

func end(id: int) -> void:
	var s := ensure(id)
	if not s.is_empty():
		s.current = {}
		s.visual = s.base

func reaction(id: int, animation: int,report_id: int=-1) -> bool:
	var s := ensure(id)
	if s.is_empty():
		failure(report_id if report_id>=0 else id,"Native combat model binding is unavailable");return false
	var speed := 1.0 if int(actors[id].objectType) == 9 else float(actors[id].get("animationSpeed", 1.0))
	var length: float = Queue.f(rigs.clip_length(id, animation) * 1000)
	if length<=0:
		failure(report_id if report_id>=0 else id,"Native animation %s requires unavailable clip %s"%[str(animation),rigs.clip_name(id,animation)]);return false
	insert(id, {"animation": animation, "duration": int(length if speed == 0 else length / absf(speed)), "speed": speed, "record": null, "delay": 0})
	stats.reactions += 1
	return true

func model_event(id: int, name: String, _serial: int) -> void:
	var original_event:=name.to_lower()
	if original_event in ["blur_start","blur_end","doneattack01","doneattack02"]:
		var state:=ensure(id)
		if not state.is_empty(): event("weapon-start" if original_event=="blur_start" else "weapon-end",id,{"animation":state.visual,"attackType":int(state.get("attackType",0)),"modelEvent":original_event})
		return
	if name.to_lower() != "hit":
		return
	var s := ensure(id)
	if s.is_empty() or int(actors.get(id,{}).get("objectType",0))!=5:return
	# The old binding listener records every creature hit marker before it asks
	# whether the current action is an attack.
	event("hit",id,{"animation":s.visual,"targetId":int(s.get("action",{}).get("targetId",0x7f000000))})
	if s.action == null or int(s.action.type) != 1:
		return
	var record: Dictionary = s.action
	if int(record.get("sourceId",-1))!=id or int(actors.get(id,{}).get("objectType",0))!=5:return
	var target := int(record.targetId)
	var target_object: Variant=source_object(target)
	if not target_object is Dictionary:return
	var target_type: int=int(target_object.get("objectType",0))
	stats.hits += 1
	var ts := ensure(target)
	var target_visual: int=int(ts.visual) if not ts.is_empty() else source_visual(target_object)
	if int(record.ranged) == 0:
		if bit(0x4aa, int(record.result)):
			event("sound", id, {"phase": 0, "record": record.duplicate(true)})
			if target_type != 5 or target_visual not in [0, 1]:
				if target_type in [9, 10] and int(record.reaction) > 1:
					if not reaction(target, int(record.reaction),id):return
			elif record.get("next") == null and int(record.reaction) > 1:
				if not reaction(target, int(record.reaction),id):return
			if target_type == 5:
				var hp: Variant = source_hit_points(target_object)
				if hp == null:
					failure(target, "Native target HP for damage bark is unavailable")
				if hp != null and int(hp) > 0 and int(record.killingBlow) == 0 and (int(record.damage) & 65535) != 0 and selector.random() % 3 == 0:
					event("bark", target, {"code": 14 + selector.random() % 3})
		elif target_visual in [206, 207, 208, 262] and int(record.result) in [2, 4]:
			event("sound", id, {"phase": 0, "record": record.duplicate(true)})
			if actors[id].get("abortOnParry") != null and int(actors[id].abortOnParry) != 0:
				event("weapon-end", id)
				if rigs.entities[id].get("model18_unavailable", false):
					failure(id, "Native robe model18 for parry abort is unavailable")
					return
				if not rigs.entities[id].get("model18", false):
					end(id)
			if record.get("next") != null:
				end(target)
			if target_type == 5 and int(record.weaponAttackType) != 7:
				if source_has_parry_weapon(target_object):event("parry", id, {"targetId":target,"record":record.duplicate(true)})
		var signed_damage := int(record.damage) & 65535
		if signed_damage & 32768:
			signed_damage -= 65536
		if bit(0x4aa, int(record.result)) and signed_damage > 0 and target_type == 5:
			event("impact", target, {"sourceId": id, "record": record.duplicate(true)})
	if record.get("next") != null:
		end(id)
		event("weapon-end", id)
		attack(id, record.next)
		event("sound", id, {"phase": 1, "record": record.duplicate(true)})

func update(_delta: float = 0.0, now_ms: int = -1) -> void:
	if not is_instance_valid(rigs):
		return
	if now_ms < 0:
		now_ms = now()
	var elapsed := now_ms - last_ms
	last_ms = now_ms
	seconds += _delta
	frames += 1
	frame_milliseconds = elapsed
	for id in actors:
		if pivots.has(id):
			actors[id].position = pivots[id].global_position
			var rotation: float = pivots[id].rotation.y
			actors[id].orientation = Vector3(-sin(rotation), 0, -cos(rotation))
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
				failure(id, "Invalid native cast animation", "network.scene-cast-animation-unhandled")
				continue
			cast_base(id,s,animation)
			var length: float = Queue.f(rigs.clip_length(id, animation) * 1000)
			var cast_cue:=CastCue.new()
			var cue: Dictionary=cast_cue.client_cast_animation_cue(animation,length,row.record)
			if not cast_cue.failure.is_empty():failure(id,cast_cue.failure,"network.scene-cast-animation-unhandled");continue
			record_identity+=1
			cue.record=cue.record.duplicate(true)
			cue.record._identity=record_identity
			insert(id,cue,age,"network.scene-cast-animation-unhandled")
			stats.casts += 1
		else:
			var records: Array = row.records.duplicate(true)
			for i in records.size():
				record_identity += 1
				records[i]._identity = record_identity
				records[i]["next"] = records[i + 1] if i + 1 < records.size() else null
			if not records.is_empty():
				event("sound", id, {"phase": 1, "record": records[0].duplicate(true)})
				attack(id, records[0], age)
	pending = waiting
	for id in states.keys():
		var s := ensure(id)
		if s.is_empty():
			retire_state(id)
			continue
		if int(s.get("body_requested",-1))>=0:
			var body_ms: int=body_now(id)
			var current_body: Dictionary=s.body_current
			if current_body.is_empty():
				advance_body_transition(id,s,body_ms)
			elif body_ms-int(current_body.at)>=float(current_body.duration):
				advance_body_transition(id,s,int(current_body.at+current_body.duration))
			if int(s.get("body_requested",-1))>=0: continue
		finish_locomotion(id,s)
		if not s.current.is_empty():
			s.current.remaining = Queue.signed(int(s.current.remaining) - elapsed)
			if int(s.current.remaining) < 0:
				s.current = {}
				play(id, int(s.base), float(actors[id].get("animationSpeed", 1.0)), category(int(actors[id].objectType), int(s.base)) == 1)
		if s.queue.entries.is_empty() or category(int(actors[id].objectType), int(s.visual)) != 1:
			continue
		var cue: Dictionary = s.queue.next(clock(now_ms))
		if int(cue.get("ready",0))==0:
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
		rows.append({"id": id, "animation": s.visual, "base": s.base, "visual": s.visual, "pending": s.queue.entries.size(), "remaining": s.current.get("remaining"), "deferred": s.pending != null})
	return {"frames":frames,"frameMilliseconds":frame_milliseconds,"stats": stats.duplicate(true), "actors": rows, "events": events.duplicate(true), "failures": failures.duplicate()}
