extends RefCounted
# Original7ee690 prerequisite core over a decoded native rule/stat snapshot.
# The active-table adapter must supply class grants/skills, actual cached saves
# and BAB, effective scores and raw skill bytes. Positive MINSPELLLVL stays
# unpublished until the original spell-capacity owner supplies that result.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Context=preload("res://systems/native_data/creation_feat_context.gd")
const ABILITIES=["MINSTR","MINDEX","MINCON","MININT","MINWIS","MINCHA"]
static func num(row: Dictionary,key: String,fallback: int=0) -> int:return Game.number(Game.cell(row,key),fallback)
static func signed8(value: int) -> int:return (value&255)-256 if value&128 else value&255
static func result(allowed: bool,reason: String="") -> Dictionary:return {"ready":true,"allowed":allowed,"reason":reason}
static func owns(ids: Array,id: int) -> bool:return ids.any(func(value):return (int(value)&65535)==(id&65535))
static func usable(source: Dictionary,id: int) -> bool:
	var skills: Array=source.get("skills",[])
	if id<0 or id>=(skills.size()&255):return false
	var skill: Dictionary=skills[id]
	if num(skill,"Untrained")==0:return signed8(num(skill,"rank"))>0
	if num(skill,"AllClassesCanUse")!=0:return true
	for entry in source.get("classes",[]).slice(0,8):
		if owns(entry.get("skills",[]),id):return true
	return false
static func evaluate(source: Dictionary,feat: Dictionary) -> Dictionary:
	var classes: Array=source.get("classes",[]);var current:=int(source.get("current",0));var id:=int(source.get("featId",-1))&65535
	if current<0 or current>=mini(8,classes.size()):return {"ready":false,"allowed":false,"reason":"Current native class snapshot is unavailable."}
	var cls: Dictionary=classes[current];var class_level:=num(cls,"level")&255;var granted:=255
	if source.get(Context.KEY) is Dictionary:granted=int(source[Context.KEY].get(id,{}).get("level",255))
	else:
		for entry in cls.get("feats",[]):
			if num(entry,"id")&65535==id:granted=num(entry,"level")&255;break
	if granted!=255 and granted>class_level:return result(false,"Class grant level")
	var owned: Array=source.get("owned",[]);var selected: Array=source.get("selected",[])
	if num(feat,"PreReqEpic")!=0 and not owns(owned,1001):return result(false,"Epic prerequisite")
	var spell:=num(feat,"MINSPELLLVL")&255
	if spell!=0:
		var capacities: Dictionary=source.get("spellLevels",{});var value: Variant=capacities.get(spell,capacities.get(str(spell)))
		if value==null:return {"ready":false,"allowed":false,"reason":"Original spell-capacity result is unavailable."}
		if not bool(value):return result(false,"Spell level")
	var level:=0
	for entry in classes.slice(0,8):level+=num(entry,"level")&255
	level=level&255
	var maximum:=num(feat,"MaxLevel")&255
	if maximum!=0 and level>maximum:return result(false,"Maximum level")
	var minimum:=num(feat,"MinLevel")&255
	if minimum!=0:
		if level<minimum:return result(false,"Minimum level")
		var required_class:=num(feat,"MinLevelClass",255)&255
		if required_class!=255:
			var required_level:=0
			for entry in classes.slice(0,8):
				if num(entry,"id")&255==required_class:required_level=num(entry,"level")&255;break
			if required_level<minimum:return result(false,"Required class level")
	var fortitude:=num(feat,"MinFortSave")&255
	if fortitude!=0 and signed8(int(source.get("fortitude",0)))<fortitude:return result(false,"Fortitude save")
	if (num(feat,"MINATTACKBONUS")&255)>(int(source.get("baseAttack",0))&255):return result(false,"Base attack")
	var scores: Array=source.get("scores",[])
	if scores.size()!=6:return {"ready":false,"allowed":false,"reason":"Native effective ability scores are unavailable."}
	# The original tests CON/CHA last, after feat/skill prerequisites. The
	# accepted/rejected result is identical; retain that original order too.
	for index in [0,1,3,4]:
		if (num(feat,ABILITIES[index])&255)>(int(scores[index])&255):return result(false,"Ability prerequisite")
	for key in ["PREREQFEAT1","PREREQFEAT2"]:
		var required:=num(feat,key,65535)&65535
		if required!=65535 and not owns(owned,required) and not owns(selected,required):return result(false,"Feat prerequisite")
	var alternatives: Array=feat.get("OrReqFeats",[]);var any_required:=false;var any_owned:=false
	for required in alternatives.slice(0,5):
		if int(required)&65535==65535:continue
		any_required=true;any_owned=any_owned or owns(owned,int(required)) or owns(selected,int(required))
	if any_required and not any_owned:return result(false,"Alternative feat prerequisite")
	for suffix in ["","2"]:
		var skill:=num(feat,"REQSKILL"+suffix,65535)&65535
		if skill==65535:continue
		if not usable(source,skill):return result(false,"Skill usability")
		if signed8(num(source.skills[skill],"rank"))<(num(feat,"ReqSkillMinRanks"+suffix)&65535):return result(false,"Skill rank")
	for index in [2,5]:
		if (num(feat,ABILITIES[index])&255)>(int(scores[index])&255):return result(false,"Ability prerequisite")
	return result(true)
