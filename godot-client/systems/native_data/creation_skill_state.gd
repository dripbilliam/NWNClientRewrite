extends RefCounted
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Rules=preload("res://systems/native_data/creation_skill_rules.gd")
const Summary=preload("res://systems/native_data/creation_skill_summary.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
static func compare(left: String,right: String) -> int:
	# Original _stricmp orders legacy bytes, folding ASCII in the C locale.
	for at in mini(left.length(),right.length()):
		var a:=Rich.byte_value(left.unicode_at(at));var b:=Rich.byte_value(right.unicode_at(at))
		if a>=65 and a<=90:a+=32
		if b>=65 and b<=90:b+=32
		if a!=b:return -1 if a<b else 1
	return signi(left.length()-right.length())
static func compose(rules,text) -> Dictionary:
	var calculated:=Summary.calculate(Summary.source(rules),rules.tables)
	if not calculated.ready:return {"ready":false,"entries":[],"details":{}}
	var entries: Array=[];var details: Dictionary={}
	for id in (rules.rows("skills").size()&255):
		var data: Dictionary=rules.row("skills",id)
		if rules.num(data,"HideFromLevelUp")!=0:continue
		var rule:=Rules.rule(rules.tables,int(rules.draft.classId),id);var title: int=rules.num(data,"Name",4294967295)&0xffffffff;var description: int=rules.num(data,"Description",4294967295)&0xffffffff
		var name: String=text.raw({"strRef":title})
		if rule.classSkill:name+=" "+text.raw({"strRef":52951})
		var entry:={"id":id,"name":name,"enabled":rule.allowed,"classSkill":rule.classSkill,"title":title,"description":description,"icon":str(Game.cell(data,"Icon","")).to_lower()}
		if entry.icon=="****":entry.icon=""
		var index:=0
		while index<entries.size() and compare(str(entries[index].name),name)<0:index+=1
		entries.insert(index,entry)
		var ability:=maxi(0,["STR","DEX","CON","INT","WIS","CHA"].find(str(Game.cell(data,"KeyAbility",""))))
		var modifier: Variant=Values.modifier(int(calculated.scores[ability]),rules.tables)
		if modifier==null:return {"ready":false,"entries":[],"details":{}}
		details[id]={"rank":Values.signed8(int(rules.draft.skills.get(id,0))),"modifier":int(modifier),"value":int(calculated["values"][id]),"cost":int(rule.cost),"maximum":int(rule.max)}
	return {"ready":true,"entries":entries,"details":details,"points":rules.skill_balance(),"classId":int(rules.draft.classId),"packageId":int(rules.draft.packageId)}
