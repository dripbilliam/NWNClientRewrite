extends RefCounted
# Native BIC display extraction only. No creature/world/effect/script import.
const ABILITIES=["Str","Dex","Con","Int","Wis","Cha"]
const Derived=preload("res://systems/native_data/character_preview_stats.gd")
const FIELDS={"race":"Race","subrace":"Subrace","gender":"Gender","experience":"Experience","hitPoints":"HitPoints","currentHitPoints":"CurrentHitPoints","portrait":"PortraitId","portraitRef":"Portrait","lawChaos":"LawfulChaotic","goodEvil":"GoodEvil"}
static func localized(value: Variant,language: int,gender: int) -> Dictionary:
	if value is String: return {"text":value}
	if not value is Dictionary: return {}
	var entries: Array=value.get("entries",[])
	for id in [language*2+gender,language*2,0]:
		for entry in entries:
			if int(entry.get("languageId",-1))==id: return {"text":str(entry.get("text",""))}
	return {"text":str(entries[0].get("text",""))} if not entries.is_empty() else {"strRef":value.get("strRef",4294967295)}
static func network_localized(value: Variant) -> Variant:
	# The old preview checks entry.language, while parsed GFF entries expose
	# languageId. Its find therefore misses and selects the first entry.
	if not value is Dictionary or not value.get("entries") is Array or value.entries.is_empty():return value
	return {"text":str(value.entries[0].get("text",""))}
static func project(root: Dictionary,language: int=0,network_source: bool=false) -> Dictionary:
	for field in ["ClassList","SkillList","FeatList"]:
		if root.has(field) and not root[field] is Array: return {"error":"Invalid native BIC list: "+field}
	var result:={"abilities":{},"classes":[],"skills":[],"feats":[],"spells":[],"native_only":true,"derived_combat_ready":false,"available":{"skills":root.has("SkillList"),"feats":root.has("FeatList"),"classes":root.has("ClassList")}}
	for name in ABILITIES:
		if root.get(name) is int: result.abilities[name]=root[name]
	for name in FIELDS:
		if root.has(FIELDS[name]): result[name]=root[FIELDS[name]]
	for name in {"firstName":"FirstName","lastName":"LastName","description":"Description"}:
		var field: String={"firstName":"FirstName","lastName":"LastName","description":"Description"}[name]
		if root.has(field): result[name]=network_localized(root[field]) if network_source else localized(root[field],language,int(root.get("Gender",0)))
	for item in root.get("ClassList",[]):
		if not item is Dictionary or not item.get("Class") is int or not item.get("ClassLevel") is int: continue
		result.classes.append({"id":item.Class,"level":item.ClassLevel})
		for level in 10:
			if item.has("KnownList"+str(level)) and not item["KnownList"+str(level)] is Array: return {"error":"Invalid native BIC known-spell list."}
			for spell in item.get("KnownList"+str(level),[]):
				if spell is Dictionary and spell.get("Spell") is int: result.spells.append({"classId":item.Class,"level":level,"id":spell.Spell})
	var skills: Array=root.get("SkillList",[])
	for index in skills.size():
		result.skills.append({"id":index,"rank":skills[index].get("Rank") if skills[index] is Dictionary else null})
	for feat in root.get("FeatList",[]):
		if feat is Dictionary and feat.get("Feat") is int: result.feats.append(int(feat.Feat))
	return result

static func project_document(document: Dictionary,language: int=0,rules_snapshot: Dictionary={},network_source: bool=false,require_rules: bool=false) -> Dictionary:
	var result: Dictionary=project(document.get("root",{}),language,network_source)
	if result.has("error"):return result
	if not rules_snapshot.get("ready",false):
		return {"error":str(rules_snapshot.get("error","Character preview rules are unavailable."))} if require_rules else result
	var derived: Dictionary=Derived.project(document,rules_snapshot)
	if not derived.get("ready",false):return {"error":str(derived.get("error","Character preview combat rules are invalid."))}
	for field in ["abilities","abilityModifiers","hitPoints","currentHitPoints","nextExperience","armorClass","saves","baseAttackBonus"]:
		result[field]=derived[field]
	result.derived_combat_ready=true
	return result
