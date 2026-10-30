extends RefCounted
# Original client 98b0a0/98b100/98b130/98b450/98b9f0/98baa0/98bb50,
# driven by 8018d0. Models/audio/scene remain explicit lower providers.
static func create() -> Dictionary:
	return {"conjure":[null,null,null],"cast":[null,null,null],"conjureTime":0,"castTime":0,"released":0,"done":[0,0,0]}
static func text(value: Variant) -> String:
	var result:=str(value) if value!=null else ""
	for i in result.length():
		if result.unicode_at(i)==0: return result.left(i)
	return result
static func casting(animation: int) -> bool:
	animation&=65535
	return ((animation-15)&65535)<6 or animation==61 or ((animation-250)&65535)<4 or animation==261
static func clear(s: Dictionary,group: String,p: Dictionary) -> void:
	for i in 3:
		if s[group][i]!=null:
			p.attach.call(s[group][i],null,null,0)
			if s[group][i]!=null: p.destroy.call(s[group][i])
			s[group][i]=null
static func done_fade(model: Variant,s: Variant) -> void:
	if s!=null:
		for i in 3:
			if is_same(model,s.conjure[i]): s.done[i]=1
static func release(s: Dictionary,refs: Array,source: Dictionary,p: Dictionary) -> int:
	for i in 3:
		if not text(refs[i]).is_empty():
			var model: Variant=p.create.call(text(refs[i]),"castgroundvisual" if i==2 else "castvisual"); s.cast[i]=model
			if model!=null:
				p.attach.call(model,p.sourceModel.call(source,255,1),["headconjure","handconjure","root"][i],0)
				p.play.call(s.cast[i],"cast01",1.0,1,0)
	for i in [1,0,2]:
		if s.conjure[i]!=null: p.play.call(s.conjure[i],"fade",1.0,1,0)
	return 1
static func start(s: Dictionary,refs: Array,sounds: Array,source: Dictionary,p: Dictionary) -> int:
	for i in 3:
		if not text(refs[i]).is_empty():
			var model: Variant=p.create.call(text(refs[i]),"conjuregroundvisual" if i==2 else "conjurevisual"); s.conjure[i]=model
			if model!=null:
				s.done[i]=0; p.listen.call(model,"donefade",done_fade,s)
				p.attach.call(model,p.sourceModel.call(source,255,1),["headconjure","handconjure","root"][i],0)
				p.play.call(s.conjure[i],"conjure01",1.0,0,0)
	var position: Array=[0.0,0.0,0.0]; var q: Array=[1.0,0.0,0.0,0.0]; var model: Variant=p.sourceModel.call(source,255,1)
	if model==null or int(p.nodePose.call(model,"handconjure",position,q))==0: position.assign(source.position)
	for sound in sounds:
		if not text(sound).is_empty(): p.oneShot.call(text(sound),position.duplicate(),11,1.5)
	return 1
static func update(s: Dictionary,elapsed: int,p: Dictionary) -> void:
	for i in 3:
		if int(s.done[i])!=0 and s.conjure[i]!=null:
			p.attach.call(s.conjure[i],null,null,0)
			if s.conjure[i]!=null: p.destroy.call(s.conjure[i])
			s.conjure[i]=null
	elapsed&=0xffffffff
	if int(s.released)!=0:
		var first:=int(s.conjureTime)&0xffffffff
		if first!=0:
			if first<=elapsed: clear(s,"conjure",p); s.conjureTime=0; return
			s.conjureTime=(first-elapsed)&0xffffffff; return
		if (int(s.castTime)&0xffffffff)==0: s.released=0; return
		var second:=int(s.castTime)&0xffffffff
		if second<=elapsed: clear(s,"cast",p); s.castTime=0; s.released=0; return
		s.castTime=(second-elapsed)&0xffffffff
static func drive(actor: Dictionary,elapsed: int,p: Dictionary) -> void:
	var s: Dictionary=actor.visuals; var animation:=int(actor.animation)&65535
	var is_casting:=casting(animation)
	var is_release:=((animation-17)&65535)<4 or animation==61 or ((animation-250)&65535)<4 or animation==261
	var spell: Variant=p.spell.call(int(actor.spellId)) if is_casting else null
	if is_release:
		if int(actor.previousCasting)==0: s.conjureTime=5000; s.castTime=5000; s.released=0; actor.previousCasting=1
		actor.suppressSound=0
	if is_casting:
		if int(actor.previousCasting)==0 and spell!=null:
			var sounds: Array=["",""]
			if int(actor.suppressSound)==0:
				if int(actor.race)>=0 and int(actor.race)<=6: sounds[0]=spell.conjureSoundFemale if int(actor.gender)==1 else spell.conjureSoundMale
				sounds[1]=spell.conjureSound
			clear(s,"conjure",p); clear(s,"cast",p); start(s,spell.conjure,sounds,actor.source,p)
			s.conjureTime=5000; s.castTime=5000; s.released=0
	elif int(actor.previousCasting)==1:
		if int(s.released)==0: clear(s,"conjure",p); clear(s,"cast",p)
		actor.spellId=-1; actor.suppressSound=0
	update(s,elapsed,p); actor.previousCasting=int(is_casting)
