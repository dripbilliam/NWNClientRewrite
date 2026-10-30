extends RefCounted
const Definition=preload("res://systems/native_data/visual_definition.gd")
static func terminated(text: String) -> String:
	for i in text.length():
		if text.unicode_at(i)==0: return text.left(i)
	return text
static func ref_name(text: String) -> String: return terminated(text).left(16).to_lower()
static func casting(table: Dictionary,id: int) -> Variant:
	if id<0 or id>=table.get("orderedRows",[]).size(): return null
	var ref:=func(column):return ref_name(str(Definition.query(table,id,column,"string").value))
	return {"conjure":[ref.call("ConjHeadVisual"),ref.call("ConjHandVisual"),ref.call("ConjGrndVisual")],"conjureSoundMale":ref.call("ConjSoundMale"),"conjureSoundFemale":ref.call("ConjSoundFemale"),"conjureSound":ref.call("ConjSoundVFX")}
static func prepare(table: Dictionary,id: int) -> Dictionary:
	if id<0 or id>=table.get("orderedRows",[]).size(): return {}
	var text:=func(column):return str(Definition.query(table,id,column,"string").value)
	var spawn: String=terminated(text.call("ProjSpwnPoint")).to_lower(); var orientation: String=terminated(text.call("ProjOrientation")).to_lower()
	return {"id":id,"model":ref_name(text.call("ProjModel")),"castHead":ref_name(text.call("CastHeadVisual")),"castHand":ref_name(text.call("CastHandVisual")),"castGround":ref_name(text.call("CastGrndVisual")),"castSound":ref_name(text.call("CastSound")),"projectileSound":ref_name(text.call("ProjSound")),
		"useProjectile":int(Definition.query(table,id,"Proj","integer").value),"projectilePath":int({"homing":1,"ballistic":2,"highballistic":3,"accelerating":5,"spiral":6,"linked":7,"bounce":8,"burst":9,"test":50}.get(terminated(text.call("ProjType")).to_lower(),0)),
		"spawn":1 if spawn=="hand" else 2 if spawn=="head" else 3+clampi(spawn.substr(7).to_int(),0,9) if spawn.begins_with("monster") else 0,"facing":1 if orientation=="target" else 2 if orientation=="path" else 0}
