extends RefCounted

const Q = preload("res://systems/animation_queue.gd")
var random_state := 1
var draws := 0
var actors: Dictionary = {}
var state: Dictionary = {}

func random() -> int:
	random_state = (random_state * 0x343fd + 0x269ec3) & 0xffffffff
	draws += 1
	return (random_state >> 16) & 0x7fff

static func normalize(v: Vector3) -> Vector3:
	var y := Q.f(-v.z)
	var squared := Q.f(Q.f(Q.f(v.x * v.x) + Q.f(y * y)) + Q.f(v.y * v.y))
	if squared == 1 or squared >= Q.f(0.99999) and squared <= Q.f(1.00001):
		return v
	if squared == 0:
		return Vector3(1, 0, 0)
	var factor := Q.f(sqrt(Q.f(1 / squared)))
	return Vector3(Q.f(v.x * factor), Q.f(v.y * factor), Q.f(-Q.f(y * factor)))

func weapon(actor: Dictionary, kind: int) -> Dictionary:
	return actor.get("equipment", {}).get(str({1: 16, 2: 32, 3: 16384, 4: 32768, 5: 65536, 6: 16}.get(kind, -1)), {})

func directional(actor: Dictionary, target: Dictionary) -> int:
	var base := int(state.get(int(target.id), {}).get("base", target.get("base", 0)))
	if base in [5, 7, 8, 6]:
		return int({5: 217, 7: 218, 8: 8, 6: 6}[base])
	if int(target.objectType) != 5 or int(target.get("facingTarget", 0x7f000000)) == int(actor.id):
		return 215
	var direction := normalize(actor.position - target.position)
	var orientation := normalize(target.orientation)
	var dot := Q.f(Q.f(Q.f(Q.f(-direction.z) * Q.f(-orientation.z)) + Q.f(direction.x * orientation.x)) + Q.f(direction.y * orientation.y))
	if dot >= Q.f(0.707):
		return 215
	if dot <= Q.f(-0.707):
		return 216
	var cross_z := Q.f(Q.f(orientation.x * Q.f(-direction.z)) - Q.f(Q.f(-orientation.z) * direction.x))
	return 214 if cross_z < 0 else 213

func range_class(actor: Dictionary, target: Dictionary, record: Dictionary) -> int:
	if target.is_empty() or int(target.objectType) != 5:
		return 2
	if target.get("hitDistance") == null or actor.get("preferredDistance") == null:
		return 0
	var difference: Vector3 = actor.position - target.position
	var x := difference.x
	var y := Q.f(-difference.z)
	var z := difference.y
	var distance := Q.f(Q.f(sqrt(Q.f(Q.f(Q.f(x * x) + Q.f(y * y)) + Q.f(z * z)))) - Q.f(float(target.hitDistance)))
	var item := weapon(actor, int(record.weaponAttackType))
	var reach := float(actor.preferredDistance)
	if not item.is_empty() and not int(item.baseItem) in [69, 70, 71, 72]:
		if item.get("preferredDistance") == null:
			return 0
		reach = float(item.preferredDistance)
		if int(actor.context.fieldDE) == 1 and actor.get("weaponScale") != null:
			reach = Q.f(reach * float(actor.weaponScale))
	return 1 if Q.f(reach - Q.f(0.25)) > distance else (2 if Q.f(reach + Q.f(0.25)) >= distance else 3)

func select(actor: Dictionary, record: Dictionary) -> int:
	var target: Dictionary = actors.get(int(record.targetId), {})
	var s: Dictionary = state[int(actor.id)]
	var side := int(s.side)
	var animation := 9
	if int(record.ranged) != 0:
		if side == 2:
			s.side = 1
			s.context.fieldE0 = 1
			s.base = 1
		animation = 200
		if int(record.reaction) == 12:
			record.reaction = 262
			if not target.is_empty() and int(target.objectType) == 5:
				var item := weapon(actor, int(record.weaponAttackType))
				var travel := 0
				if not item.is_empty():
					var d: Vector3 = target.position - actor.position
					var squared := Q.f(Q.f(Q.f(d.x * d.x) + Q.f(d.z * d.z)) + Q.f(d.y * d.y))
					var magnitude := Q.f(sqrt(squared)) if squared > 0 else 0.0
					var base := int(item.baseItem)
					var slow := base in [31, 59, 63]
					travel = int(Q.f(Q.f(magnitude / (40.0 if slow else 55.0)) * 1000))
				record.reactionDelay = ((int(record.duration) >> 1) + travel) & 65535
	else:
		var branch := range_class(actor, target, record)
		if branch == 0:
			return -1
		if branch == 1 or branch == 3:
			if branch == 1 and target.is_empty():
				return 9
			var base := int(state.get(int(record.targetId), {}).get("base", target.get("base", 0)))
			animation = (204 if base in [5, 7, 8, 6] or target.get("targetHeight", "") == "L" else 203) if branch == 1 else 205
			if side == 2:
				s.side = 1
				s.context.fieldE0 = 1
			if int(record.reaction) in [11, 12]:
				record.reaction = (209 if animation == 203 else 210) if branch == 1 else (207 if int(record.reaction) == 12 else 209)
			elif int(record.reaction) == 14:
				record.reaction = directional(actor, target)
		else:
			if actor.get("monk") == null:
				return -1
			var monk := bool(actor.monk)
			var left: Dictionary = actor.get("equipment", {}).get("32", {}) if int(s.context.fieldDD) in [1, 2] else {}
			var shield := not left.is_empty() and int(left.baseItem) in [14, 15, 56, 57]
			var item := weapon(actor, int(record.weaponAttackType))
			if side == 1:
				if not item.is_empty():
					animation = 200 if random() % 100 <= (int(item.slashLeft) & 255) else 202
				else:
					var first := random() % 3
					animation = (265 if monk and random() % 2 == 0 else 202) if first == 1 else (263 if monk and random() % 3 == 0 else 200)
				s.side = 2
				s.context.fieldE0 = 2
			else:
				if not item.is_empty():
					animation = (202 if shield else 201) if random() % 100 <= (int(item.slashRight) & 255) else 202
				else:
					var first := random() % 3
					if first == 1:
						animation = 265 if monk and random() % 2 == 0 else 202
					elif monk and random() % 3 == 0:
						animation = 264
					else:
						animation = 202 if shield else 201
				s.side = 1
				s.context.fieldE0 = 1
			if int(record.reaction) == 12:
				record.reaction = 206 if animation in [200, 263] else 207
			elif int(record.reaction) == 11:
				record.reaction = 210 if animation in [202, 265] else 209
			elif int(record.reaction) == 14:
				var base := int(state.get(int(record.targetId), {}).get("base", target.get("base", 0)))
				if base in [5, 7, 8, 6]:
					record.reaction = int({5: 217, 7: 218, 8: 8, 6: 6}[base])
				elif target.is_empty() or int(target.objectType) != 5 or int(target.get("facingTarget", 0x7f000000)) == int(actor.id):
					record.reaction = 215 if animation in [202, 265] else (213 if animation in [200, 263] else 214)
				else:
					record.reaction = directional(actor, target)
	s.attackType = int(record.attackType) & 65535
	return animation
