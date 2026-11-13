extends RefCounted
# Original creation-mode7f5150, including independent OR groups, signed ranks
# and saves, unsigned BAB and exact case-sensitive recognized ReqType strings.
const Values=preload("res://systems/native_data/character_record_values.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
static func source(rules) -> Dictionary:
	var data: Dictionary=rules.cls();var current:=int(rules.draft.get("classId",-1));var classes: Array=[];var ranks: Array=[]
	if current>=0 and current<(rules.rows("classes").size()&255):classes.append({"id":current,"level":1,"caster":rules.num(data,"SpellCaster"),"arcane":rules.num(data,"Arcane")})
	for id in range(rules.rows("skills").size()&255):ranks.append(int(rules.draft.get("skills",{}).get(id,0))&255)
	var feats: Array=rules.granted_feats()
	for choice in rules.draft.get("feats",[]):feats.append(int(choice.id)&65535)
	# Creation stat initializer7ea230 sets the base saves to0 and BAB to the
	# invalid cache byte255.7f0900 then queries the current class's level1 BAB.
	return {"race":int(rules.draft.get("raceId",6)),"ranks":ranks,"feats":feats,"bonusFeats":[],"saves":[0,0,0],"bab":rules.num(rules.first("AttackBonusTable"),"BAB"),"classes":classes}
static func requirement(rules,id: int) -> String:
	if id<0 or id>=(rules.rows("classes").size()&255):return "Not a player class."
	var data: Dictionary=rules.row("classes",id)
	if rules.num(data,"PlayerClass")==0:return "Not a player class."
	var name:=str(rules.cell(data,"PreReqTable",""))
	if not rules.present(name):return ""
	if not rules.tables.has(name.to_lower()):return "Class prerequisites have not loaded."
	return "" if eligible(rules.rows(name),source(rules)) else "First-level class prerequisites are not met."
static func eligible(requirements: Array,source: Dictionary) -> bool:
	var groups: Dictionary={};var owned: Array=[]
	for id in source.get("feats",[])+source.get("bonusFeats",[]):owned.append(int(id)&65535)
	for row in requirements:
		var kind:=str(Game.cell(row,"ReqType",""));var a:=Game.number(Game.cell(row,"ReqParam1"),0);var b:=Game.number(Game.cell(row,"ReqParam2"),0)
		match kind:
			"SKILL":
				var index:=a&65535;var rank:=Values.signed8(int(source.ranks[index])) if index<(source.get("ranks",[]).size()&255) else 0
				if rank<b:return false
			"FEAT":
				if not owned.has(a&65535):return false
			"RACE":groups.race=bool(groups.get("race",false)) or int(source.get("race",0))&65535==a
			"FEATOR":groups.feat=bool(groups.get("feat",false)) or owned.has(a&65535)
			"BAB":
				if int(source.get("bab",0))&255<a:return false
			"SPELL","ARCSPELL":
				var found:=false
				for entry in source.get("classes",[]).slice(0,8):
					if int(entry.get("caster",0) if kind=="SPELL" else entry.get("arcane",0))!=0 and int(entry.level)&255>=a:found=true
				if not found:return false
			"CLASSNOT":
				for entry in source.get("classes",[]).slice(0,8):
					if int(entry.id)&255==a:return false
			"CLASSOR":
				if not groups.has("classes"):groups.classes=false
				for entry in source.get("classes",[]).slice(0,8):
					if int(entry.id)&255==a:groups.classes=true
			"SAVE":
				if a in [1,2,3] and Values.signed8(int(source.get("saves",[0,0,0])[a-1]))<b:return false
	return groups.values().all(func(value):return bool(value))
