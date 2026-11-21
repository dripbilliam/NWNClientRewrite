extends RefCounted
const Definition=preload("res://systems/native_data/visual_definition.gd")
const ScriptString=preload("res://systems/native_data/native_script_string.gd")
const Metadata=preload("res://systems/native_data/spell_metadata.gd")
const ResRef=preload("res://systems/native_data/visual_type10.gd")
static func terminated(text: String) -> String:
	for i in text.length():
		if text.unicode_at(i)==0: return text.left(i)
	return text
static func ref_name(text: String) -> Dictionary: return ResRef.object_template_resref(text)
static func casting(table: Dictionary,id: int) -> Variant:
	if id<0 or id>=table.get("orderedRows",[]).size(): return null
	var references:Dictionary={}
	for column in ["ConjHeadVisual","ConjHandVisual","ConjGrndVisual","ConjSoundMale","ConjSoundFemale","ConjSoundVFX"]:
		var reference:Dictionary=ref_name(Metadata.spell_string_entry(table,id,column))
		if reference.has("error"):return reference
		references[column]=str(reference.value)
	var metadata:Dictionary=Metadata.casting_spell(table,id)
	metadata.merge({"conjure":[references.ConjHeadVisual,references.ConjHandVisual,references.ConjGrndVisual],"conjureSoundMale":references.ConjSoundMale,"conjureSoundFemale":references.ConjSoundFemale,"conjureSound":references.ConjSoundVFX},true)
	return metadata
static func prepare(table: Dictionary,id: int) -> Dictionary:
	if id<0 or id>=table.get("orderedRows",[]).size(): return {}
	var text:=func(column):return Metadata.spell_string_entry(table,id,column)
	var spawn: String=terminated(text.call("ProjSpwnPoint")).to_lower(); var orientation: String=terminated(text.call("ProjOrientation")).to_lower()
	var spawn_value:=0
	if spawn=="hand":spawn_value=1
	elif spawn=="head":spawn_value=2
	elif spawn.begins_with("monster"):
		var parsed: Dictionary=ScriptString.to_int(spawn.substr(7))
		if parsed.has("error"):return parsed
		spawn_value=3+clampi(int(parsed.value),0,9)
	var references:Dictionary={}
	for column in ["ProjModel","CastHeadVisual","CastHandVisual","CastGrndVisual","CastSound","ProjSound"]:
		var reference:Dictionary=ref_name(text.call(column))
		if reference.has("error"):return reference
		references[column]=str(reference.value)
	var prepared:Dictionary={"id":id,"model":references.ProjModel,"castHead":references.CastHeadVisual,"castHand":references.CastHandVisual,"castGround":references.CastGrndVisual,"castSound":references.CastSound,"projectileSound":references.ProjSound,
		"useProjectile":int(Definition.query(table,id,"Proj","integer").value),"projectilePath":int({"homing":1,"ballistic":2,"highballistic":3,"accelerating":5,"spiral":6,"linked":7,"bounce":8,"burst":9,"test":50}.get(terminated(text.call("ProjType")).to_lower(),0)),
		"spawn":spawn_value,"facing":1 if orientation=="target" else 2 if orientation=="path" else 0}
	var casting_metadata:Variant=casting(table,id)
	if casting_metadata is Dictionary and casting_metadata.has("error"):return casting_metadata
	prepared.merge(casting_metadata,false)
	return prepared
