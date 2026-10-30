extends RefCounted
# Unchanged owners810680/8033c0: independent initialization and eye-model state.
# Providers supply the active rule table, actual models and physical Parts.
const Special=preload("res://systems/native_data/special_attack_visual.gd")
const M=preload("res://systems/native_render/particle_math.gd")
static func initialize(s: Dictionary,p: Dictionary) -> void:
	var strike:=int(p.gate.call(0)); var eyes:=int(p.gate.call(1))
	var unarmed:=bool(p.present.call()) and (int(p.style.call())&255) in [1,2]
	if eyes==1: p.eyes.call()
	if strike!=1: return
	if unarmed: Special.load_models(s,0,p); return
	for index in 2:
		if s.slots[index]!=null: p.play.call(s.slots[index],"cessation",1.0,1,0.0)
static func create_eye() -> Dictionary:
	return {"model":null,"flags":[0,0,0]}
static func category(alignment: int) -> int:
	var signed:=(alignment&65535)-65536 if (alignment&65535)>=32768 else alignment&65535
	return 0 if signed<31 else (1 if signed>69 else 2)
static func resource(alignment: int,appearance: int,gender: int) -> String:
	appearance&=65535; gender&=255
	if appearance>6: return ""
	var stem:="vfx_monkeyes"
	if gender==1: stem+=["df","ef","gf","af","f","of","f"][appearance]
	else: stem+=["d","","g","ha","","",""][appearance]
	return stem+["","01","02"][category(alignment)]
static func eye(s: Dictionary,alignment: int,appearance: int,gender: int,phenotype: int,p: Dictionary) -> void:
	appearance&=65535; gender&=255; phenotype&=255
	if appearance>6: return
	var index:=category(alignment)
	if int(s.flags[index])!=0: return
	if s.model!=null: p.destroy.call(s.model); s.model=null
	s.model=p.create.call(resource(alignment,appearance,gender),"monkeyes")
	s.flags=[int(index==0),int(index==1),int(index==2)]
	if s.model==null: return # Original commits flags even if allocation failed.
	p.attach.call(s.model,p.sourceModel.call(255,1),"head_g",0)
	var column:="HELMET_SCALE_F" if gender==1 else "HELMET_SCALE_M"
	var value: Dictionary=p.scale_entry.call(appearance,column)
	var scale_value:=M.f(value.value) if value.found else 1.0
	if phenotype==2: scale_value=M.f(scale_value+M.f(0.13))
	p.scale.call(s.model,scale_value,0)
	p.play.call(s.model,"impact",1.0,0,0.0)
