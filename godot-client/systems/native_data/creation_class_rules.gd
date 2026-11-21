extends RefCounted
# First-level creation counterpart of class_prerequisites.js. The provider
# describes the creature before it acquires the candidate class.
const Values=preload("res://systems/native_data/character_record_values.gd")

static func cell(row: Dictionary,column: String) -> Variant:
	for key in row:
		if str(key).to_lower()==column.to_lower():return row[key]
	return null

static func js_number(value: Variant) -> float:
	# Undefined/missing 2DA cells become NaN under Number(undefined).
	if value==null:return NAN
	if value is bool:return 1.0 if value else 0.0
	if value is int or value is float:return float(value)
	var raw:=str(value).strip_edges()
	if raw.is_empty():return 0.0
	if raw in ["Infinity","+Infinity"]:return INF
	if raw=="-Infinity":return -INF
	if (raw.begins_with("0x") or raw.begins_with("0X")) and raw.is_valid_hex_number(true):return float(raw.hex_to_int())
	return float(raw) if raw.is_valid_float() else NAN

static func word16(value: float) -> int:
	return int(value)&65535 if is_finite(value) and absf(value)<9223372036854775808.0 else 0

static func source(rules) -> Dictionary:
	var racial_feats: Array=[]
	var race: Dictionary=rules.race()
	for row in rules.rows(str(rules.cell(race,"FeatsTable",""))):
		var value: Variant=cell(row,"FeatIndex")
		racial_feats.append(-1.0 if value==null or value is String and value in ["","****"] else js_number(value))
	return {"race":int(rules.draft.get("raceId",-1)),"ranks":[],"feats":racial_feats,"bonusFeats":[],"saves":[0,0,0],"bab":0,"classes":[]}

static func requirement(rules,id: int) -> String:
	var data: Dictionary=rules.row("classes",id)
	if data.is_empty() or not rules.source_truthy(rules.source_num(data,"PlayerClass")):return "This class is not player-selectable"
	if rules.num(data,"EpicLevel",255)==0:return "This class requires epic levels"
	var name:=str(rules.cell(data,"PreReqTable",""))
	if not rules.present(name):return ""
	if not rules.tables.has(name.to_lower()):return "Class prerequisite table is unavailable"
	return "" if eligible(rules.rows(name),source(rules)) else "First-level class prerequisites are not met"

static func eligible(requirements: Array,provider: Dictionary) -> bool:
	var races: Variant=null;var feats: Variant=null;var classes: Variant=null
	var owned: Array=[]
	for id in provider.get("feats",[])+provider.get("bonusFeats",[]):owned.append(float(id))
	for row in requirements:
		var kind: Variant=cell(row,"ReqType")
		var raw_a: Variant=cell(row,"ReqParam1")
		var a: float=js_number(raw_a);var b: float=js_number(cell(row,"ReqParam2"))
		match kind:
			"SKILL":
				var index:=word16(a)&255
				var ranks: Array=provider.get("ranks",[])
				var rank:=Values.signed8(int(ranks[index])) if index<ranks.size() else 0
				if not (float(rank)>=b):return false
			"FEAT":
				if not owned.has(float(word16(a))):return false
			"RACE":races=races==true or float(provider.get("race",0))==a
			"FEATOR":feats=feats==true or owned.has(float(word16(a)))
			"BAB":
				if not (float(provider.get("bab",0))>=a):return false
			"SPELL","ARCSPELL":
				var found:=false
				for entry in provider.get("classes",[]):
					if int(entry.get("caster",0) if kind=="SPELL" else entry.get("arcane",0))!=0 and float(entry.get("level",0))>=a:found=true;break
				if not found:return false
			"VAR":
				if not raw_a is String or str(raw_a) in ["","****"] or b!=0.0:return false
			"CLASSNOT":
				for entry in provider.get("classes",[]):
					if float(entry.get("id",-1))==a:return false
			"CLASSOR":
				if classes==null:classes=false
				for entry in provider.get("classes",[]):
					if float(entry.get("id",-1))==a:classes=true;break
			"SAVE":
				if a in [1.0,2.0,3.0]:
					var saves: Array=provider.get("saves",[0,0,0])
					if not (float(Values.signed8(int(saves[int(a)-1])))>=b):return false
	return races!=false and feats!=false and classes!=false
