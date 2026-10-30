extends RefCounted
# Reviewed receiver1407857f0..14078644b. Model/allocator services are explicit;
# ordinary effects discard extended fields, P/B/999 retain the native routing.
const Phases=preload("res://systems/visual_phases.gd")
const INVALID=0x7f000000
static func valid(object: Variant) -> bool: return object is Dictionary and int(object.get("objectType",0)) in [5,9,10]
static func type_name(value: String) -> String:
	var kind:=""
	for i in value.length():
		if value.unicode_at(i)==0: break
		kind+=value[i]
	return kind
static func deliver(message: Dictionary,p: Dictionary) -> int:
	var visual:=int(message.visualId)&65535; var target:=int(message.targetId)&0xffffffff
	var kind:=type_name(str(p.visualType.call(visual).value))
	var special:=kind in ["P","B"] or visual==999
	var point: Array=message.position.map(func(v):return Phases.f32(float(v)))
	var actor: Variant=null; var source:=INVALID; var source_part:=0; var target_part:=0; var instant:=1
	if not special:
		actor=p.createDummy.call("point",point,10000) if target==INVALID else p.object.call(target)
		if actor==null: return 0
	else:
		source=int(message.sourceId)&0xffffffff; source_part=int(message.flag)&255; target_part=int(message.missMode)&255
		var duration:=Phases.f32(float(message.duration)) if target==INVALID else 0.0
		var lifetime:=6000 if duration==0.0 else Phases.milliseconds(duration)
		if not valid(p.object.call(source)):
			if not message.get("sourcePosition") is Array: return 0
			if p.createDummy.call("source",message.sourcePosition.map(func(v):return Phases.f32(float(v))),lifetime)==null: return 0
		var object: Variant=p.object.call(target)
		actor=p.renderObject.call(object) if valid(object) else p.createDummy.call("target",point,lifetime)
		if actor==null: return 0
		instant=1 if duration==0.0 else 0
	p.add.call(actor,{"visualId":visual,"sourceId":source,"bodyPart":0,"transform":message.get("transform",{"scale":1,"translate":[0,0,0],"rotate":[0,0,0]}).duplicate(true),"networkTransform":message.get("visualTransform"),"delivery":{"instant":instant,"sourcePart":source_part,"targetPart":target_part,"point":[0,0,0] if special and target!=INVALID else point}})
	return 1
