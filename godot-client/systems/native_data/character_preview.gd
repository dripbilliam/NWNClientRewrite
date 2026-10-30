extends RefCounted
# Native BIC display extraction only. No creature/world/effect/script import.
const ABILITIES=["Str","Dex","Con","Int","Wis","Cha"]
const FIELDS={"race":"Race","subrace":"Subrace","gender":"Gender","experience":"Experience","hitPoints":"HitPoints","currentHitPoints":"CurrentHitPoints","portrait":"PortraitId","portraitRef":"Portrait","lawChaos":"LawfulChaotic","goodEvil":"GoodEvil"}
static func localized(value: Variant,language: int,gender: int) -> Dictionary:
	if value is String: return {"text":value}
	if not value is Dictionary: return {}
	var entries: Array=value.get("entries",[])
	for id in [language*2+gender,language*2,0]:
		for entry in entries:
			if int(entry.get("languageId",-1))==id: return {"text":str(entry.get("text",""))}
	return {"text":str(entries[0].get("text",""))} if not entries.is_empty() else {"strRef":value.get("strRef",4294967295)}
static func project(root: Dictionary,language: int=0) -> Dictionary:
	for field in ["ClassList","SkillList","FeatList"]:
		if root.has(field) and not root[field] is Array: return {"error":"Invalid native BIC list: "+field}
	var result:={"abilities":{},"classes":[],"skills":[],"feats":[],"spells":[],"native_only":true,"derived_combat_ready":false,"available":{"skills":root.has("SkillList"),"feats":root.has("FeatList"),"classes":root.has("ClassList")}}
	for name in ABILITIES:
		if root.get(name) is int: result.abilities[name]=root[name]
	for name in FIELDS:
		if root.has(FIELDS[name]): result[name]=root[FIELDS[name]]
	for name in {"firstName":"FirstName","lastName":"LastName","description":"Description"}:
		var field: String={"firstName":"FirstName","lastName":"LastName","description":"Description"}[name]
		if root.has(field): result[name]=localized(root[field],language,int(root.get("Gender",0)))
	for item in root.get("ClassList",[]):
		if not item is Dictionary or not item.get("Class") is int or not item.get("ClassLevel") is int: continue
		result.classes.append({"id":item.Class,"level":item.ClassLevel})
		for level in 10:
			if item.has("KnownList"+str(level)) and not item["KnownList"+str(level)] is Array: return {"error":"Invalid native BIC known-spell list."}
			for spell in item.get("KnownList"+str(level),[]):
				if spell is Dictionary and spell.get("Spell") is int: result.spells.append({"classId":item.Class,"level":level,"id":spell.Spell})
	var skills: Array=root.get("SkillList",[])
	for index in skills.size():
		if skills[index] is Dictionary and skills[index].get("Rank") is int: result.skills.append({"id":index,"rank":skills[index].Rank})
	for feat in root.get("FeatList",[]):
		if feat is Dictionary and feat.get("Feat") is int: result.feats.append(int(feat.Feat)&65535)
	return result
