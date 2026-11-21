extends RefCounted
# NetworkCombatPresentation.receive gives cast releases precedence over attack
# cues within one accepted delivery, while preserving order inside each kind.
static func ordered(events: Array) -> Array:
	var result: Array=[]
	for event in events:
		if event is Dictionary and str(event.get("action",""))=="cast-animation":result.append(event.duplicate(true))
	for event in events:
		if event is Dictionary and str(event.get("action",""))=="attack-animation":result.append(event.duplicate(true))
	return result
