extends RefCounted

# Original140761d90..140761ff7 and140762c10..140762ccf. Physical list order and
# state identity matter: equal priorities choose the LAST eligible entry.
static func select(actor: Dictionary, type: int, p: Dictionary) -> void:
	if actor.suppressed108:
		return
	type &= 255
	var selected: Variant = null
	var priority := 255
	for effect in actor.visuals80:
		if effect.finishedF4 or p.programType.call(effect) != type:
			continue
		var visual := int(effect.visualF8) & 65535
		if (visual == 182 or ((visual - 242) & 65535) <= 2) and actor.id != p.selectedObjectId1406ac1c0.call():
			continue
		var scope := int(effect.scope10c) & 255
		if scope == 0:
			if effect.field110 and not p.viewGate1407dadb0.call():
				if effect.attached114:
					p.detach.call(effect)
				continue
			if not effect.attached114:
				p.attach.call(effect)
		elif scope <= priority:
			selected = effect
			priority = scope
	for effect in actor.visuals80:
		if effect.finishedF4 or p.programType.call(effect) != type or (int(effect.scope10c) & 255) == 0:
			continue
		if is_same(effect, selected):
			if p.programType.call(effect) == 4:
				if effect.field110 and not p.viewGate1407dadb0.call():
					if effect.attached114 and not effect.closedEc:
						p.stop.call(effect, 0)
					continue
				if effect.closedEc:
					p.start.call(effect)
			if not effect.attached114:
				p.attach.call(effect)
		elif effect.attached114:
			p.detach.call(effect)

static func detach_competing(actor: Dictionary, current: Dictionary, p: Dictionary) -> void:
	for index in range(actor.visuals80.size() - 1, -1, -1):
		var candidate: Dictionary = actor.visuals80[index]
		if p.programType.call(current) == 7:
			continue
		var kind: int = p.programType.call(candidate)
		if p.programType.call(current) != kind or is_same(candidate, current) or (int(candidate.scope10c) & 255) == 0 or candidate.finishedF4:
			continue
		if candidate.attached114:
			p.detach.call(candidate)
		return
