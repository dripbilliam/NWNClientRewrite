extends RefCounted
# Original7fdca0/803c50/8074b0 and unarmed7fd6b0 boundaries. Model handles
# are opaque; the native scene owner supplies real resources/physical Parts.
static func gate(classes: Array,feats: Array,mode: int) -> int:
	var allowed:=0; var last_level:=0
	for cls in classes:
		if (int(cls.get("type",cls.get("id",255)))&255)!=5: continue
		last_level=int(cls.level)&255
		if feats.any(func(list):return list.any(func(id):return (int(id)&65535)==213)): allowed=1
	return int(last_level>=20) if mode==1 else allowed
static func create() -> Dictionary:
	return {"enabled":0,"attackType":0,"slots":[null,null,null,null]}
static func load_models(s: Dictionary,kind: int,p: Dictionary) -> void:
	kind&=255
	if kind<2:
		for i in 2:
			if s.slots[i]==null: s.slots[i]=p.create.call("vcm_monkki","kistrike")
	elif kind==2:
		if s.slots[2]==null: s.slots[2]=p.create.call("vcm_monkstun","stunfist")
	elif kind==3:
		if s.slots[3]==null: s.slots[3]=p.create.call("vcm_monkquiv","quivpalm")
	else:
		p.warning.call("Unknown special-attack model type"); return
	var animation:=int(p.animation.call())&65535; var part:=""
	if animation in [203,200,202] or int(p.modelPart.call(254))==1: part="rhand"
	elif animation==201: part="lhand"
	elif animation in [204,263]: part="rfoot_g"
	elif animation in [264,265,205]: part="lfoot_g"
	if not part.is_empty() and s.slots[kind]!=null: p.attach.call(s.slots[kind],p.sourceModel.call(255,1),part,0)
static func play(s: Dictionary,kind: int,p: Dictionary) -> void:
	kind&=255
	var selected: Array=[0,1] if kind<2 else ([kind] if kind in [2,3] else [])
	if selected.is_empty(): p.warning.call("Unknown special-attack model type"); return
	for index in selected:
		if s.slots[index]!=null: p.play.call(s.slots[index],"impact",1.0,1,0.0)
static func unarmed(s: Dictionary,enabled: int,p: Dictionary) -> void:
	if int(s.enabled)==enabled: return
	if enabled==1:
		if (int(s.attackType)&65535) in [39,296]:
			var kind:=2 if (int(s.attackType)&65535)==39 else 3
			load_models(s,kind,p)
			if s.slots[kind]!=null: p.play.call(s.slots[kind],"impact",1.0,1,0.0)
		elif int(p.gate.call(0))==1:
			load_models(s,0,p); play(s,0,p)
	else:
		for index in [2,3,0,1]:
			if s.slots[index]!=null: p.play.call(s.slots[index],"cessation",1.0,1,0.0)
	s.enabled=enabled
static func clear(s: Dictionary,p: Dictionary) -> void:
	for i in 4:
		if s.slots[i]!=null: p.destroy.call(s.slots[i]); s.slots[i]=null
