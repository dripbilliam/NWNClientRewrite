extends RefCounted
# Whole original807240 voice owner, with SSF/Exists/source boundaries explicit.
static func play(s: Dictionary,code: int,positional: int,p: Dictionary) -> bool:
	if (int(s.soundsetId)&65535)==65535: return false
	var data: Variant=p.demandSet.call(int(s.soundsetId)&65535)
	if data==null: return false
	var item: Variant=p.entry.call(data,code&65535); p.releaseSet.call(data)
	var resource:=str(item.get("resRef","")) if item is Dictionary else ""
	if resource.is_empty() or not p.exists.call(resource): return false
	var priority:=6 if p.controlled.call() else (7 if p.player.call() else (15 if int(p.sizeCategory.call())<4 else 14))
	s.delay=0
	if s.sound!=null: p.destroySound.call(s.sound)
	s.sound=p.createSound.call(resource)
	if s.sound==null: return false
	p.sound3d.call(s.sound,positional); p.soundPriority.call(s.sound,priority)
	if positional!=0: p.updateSound.call(s.sound,p.position.call(),1.5)
	p.playSound.call(s.sound); return true
