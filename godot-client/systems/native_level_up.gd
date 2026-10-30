extends RefCounted
# Native draft and controls. Only the original server commits a level-up.
var desktop
var ui
var rules
var snapshot: Dictionary={}
var available: Array=[]
var token:=-1
var draft: Dictionary={}
var step:=0
var controls: Dictionary={}
var serial:=0
var status:=""
var submitting:=false
const ABILITIES=["Str","Dex","Con","Int","Wis","Cha"]
func configure(owner,view) -> void: desktop=owner; ui=view; rules=desktop.rules
func total() -> int:
	var result:=0
	for cls in snapshot.get("classes",[]): result+=int(cls.level)
	return result
func class_level(id: int) -> int:
	for cls in snapshot.get("classes",[]):
		if int(cls.id)==id: return int(cls.level)
	return 0
func num(row: Dictionary,key: String,fallback: int=0) -> int: return rules.number(rules.cell(row,key),fallback)
func table(key: String) -> Dictionary:
	var name:=str(rules.cell(rules.row("classes",int(draft.get("classId",-1))),key,"")).to_lower()
	return desktop.owner_ui.text.tables.get(name,{})
func rows(key: String) -> Array: return table(key).get("orderedRows",[])
func class_row(key: String,level: int) -> Dictionary:
	var list:=rows(key); return list[level] if level>=0 and level<list.size() else {}
func begin(result: Dictionary) -> void:
	snapshot=result.snapshot.duplicate(true); available=result.available.duplicate(); token=int(result.token); step=0; status=""; submitting=false
	var selected:=-1
	for cls in snapshot.classes:
		if int(cls.id)<available.size() and available[int(cls.id)]: selected=int(cls.id); break
	if selected<0: selected=available.find(true)
	select_class(selected)
func select_class(id: int) -> void:
	if id<0 or id>=available.size() or not available[id]: return
	var ranks: Array=[]; ranks.resize(snapshot.skills.size()); ranks.fill(0)
	draft={"classId":id,"ability":6,"hitDie":maxi(1,num(rules.row("classes",id),"HitDie",1)),"skills":ranks,"feats":[],"known":{},"removed":{},"domains":[],"school":0,"fieldE34":snapshot.fieldE34,"fieldE48":snapshot.fieldE48,"fieldE30":snapshot.fieldE30,"fieldE38":snapshot.fieldE38}
	for cls in snapshot.classes:
		if int(cls.id)==id: draft.domains=cls.get("domains",[]).duplicate(); draft.school=int(cls.get("school",0))
	if not desktop.class_tables_ready(id): status="Loading native class rules…"
	render()
func abilities(chosen: Variant=null) -> Array:
	if chosen==null: chosen=draft.get("feats",[])
	var result: Array=snapshot.get("baseAbilities",[]).duplicate(); var race: Dictionary=rules.row("racialtypes",int(snapshot.get("race",-1)))
	var levels: Array=snapshot.get("classes",[]).duplicate(true); var found:=false
	for cls in levels:
		if int(cls.id)==int(draft.classId): cls.level=int(cls.level)+1; found=true
	if not found: levels.append({"id":int(draft.classId),"level":1})
	var bonus:=1
	for row in desktop.owner_ui.text.tables.get("ruleset",{}).get("orderedRows",[]):
		if str(rules.cell(row,"Label","")).to_upper()=="EPIC_GREAT_STAT_BONUS": bonus=num(row,"Value",1)
	for index in mini(6,result.size()):
		result[index]=int(result[index])+num(race,ABILITIES[index]+"Adjust")+(1 if int(draft.get("ability",6))==index else 0)
		for cls in levels:
			var name:=str(rules.cell(rules.row("classes",int(cls.id)),"StatGainTable","")).to_lower(); var gains: Array=desktop.owner_ui.text.tables.get(name,{}).get("orderedRows",[])
			for level in mini(int(cls.level),gains.size()): result[index]+=num(gains[level],ABILITIES[index])
		for feat in chosen:
			if int(feat)>=[814,784,774,794,804,764][index] and int(feat)<[814,784,774,794,804,764][index]+10: result[index]+=bonus
	return result
func budget() -> int:
	var race: Dictionary=rules.row("racialtypes",int(snapshot.race)); var ability:=str(rules.cell(race,"SkillPointModifierAbility","Int")).to_upper(); var index:= ["STR","DEX","CON","INT","WIS","CHA"].find(ability)
	if index<0: index=rules.number(ability,3)
	var scores:=abilities(); var score:=int(scores[index]) if index>=0 and index<scores.size() else 10
	return int(snapshot.fieldDC6)+maxi(1,num(rules.row("classes",int(draft.classId)),"SkillPointBase")+floori((score-10)/2.0))+num(race,"ExtraSkillPointsPerLevel")
func skill_rule(id: int) -> Dictionary:
	var entry: Dictionary={}
	for row in rows("SkillsTable"):
		if num(row,"SkillIndex",-1)==id: entry=row; break
	var class_skill:=num(entry,"ClassSkill")!=0
	return {"allowed":not entry.is_empty() or num(rules.row("skills",id),"AllClassesCanUse")!=0,"cost":1 if class_skill else 2,"maximum":floori((total()+4)/(1.0 if class_skill else 2.0))}
func balance() -> int:
	var result:=budget()
	for index in draft.get("skills",[]).size(): result-=int(draft.skills[index])*int(skill_rule(index).cost)
	return result
func granted() -> Array:
	var result: Array=[]
	for row in rows("FeatsTable"):
		var id:=num(row,"FeatIndex",-1)
		if num(row,"List",-1)==3 and num(row,"GrantedOnLevel",-1)==class_level(int(draft.classId))+1 and id>=0 and not snapshot.feats.has(id) and not result.has(id): result.append(id)
	if total()==20 and not snapshot.feats.has(1001): result.append(1001)
	if class_level(int(draft.classId))==0 and num(rules.row("classes",int(draft.classId)),"PickDomains")!=0:
		for domain in draft.domains:
			var id:=num(rules.row("domains",int(domain)),"GrantedFeat",-1)
			if id>=0 and not snapshot.feats.has(id) and not result.has(id): result.append(id)
	return result
func feat_slots() -> Dictionary:
	var race: Dictionary=rules.row("racialtypes",int(snapshot.race)); var every:=num(race,"NormalFeatEveryNthLevel",3)
	return {"normal":num(race,"NumberNormalFeatsEveryNthLevel",1) if every>0 and (total()+1)%every==0 else 0,"bonus":num(class_row("BonusFeatsTable",class_level(int(draft.classId))),"Bonus")}
func feat_allowed(id: int,kind: String) -> bool:
	var feat: Dictionary=rules.row("feat",id)
	if feat.is_empty() or num(feat,"HideFromLevelUp")!=0 or str(rules.cell(feat,"FEAT","****"))=="****": return false
	var list_entry: Dictionary={}
	for row in rows("FeatsTable"):
		if num(row,"FeatIndex",-1)==id: list_entry=row; break
	if kind=="bonus": return num(list_entry,"List",-1) in [1,2]
	return num(list_entry,"List",-1) in [0,1] or num(feat,"AllClassesCanUse")!=0 and num(list_entry,"List",-1)!=2
func feat_requirement(id: int,chosen: Array) -> String:
	var feat: Dictionary=rules.row("feat",id); var owned: Array=snapshot.feats+granted()+chosen; var scores:=abilities(chosen)
	if feat.is_empty(): return "Invalid feat."
	if owned.has(id): return "Already acquired."
	var next_level:=class_level(int(draft.classId))+1
	for row in rows("FeatsTable"):
		if num(row,"FeatIndex",-1)==id and num(row,"GrantedOnLevel",255)!=255 and num(row,"GrantedOnLevel",255)>next_level: return "Class level requirement."
	for index in mini(scores.size(),6):
		if int(scores[index])<num(feat,"MIN"+ABILITIES[index].to_upper()): return "Ability requirement."
	var levels: Array=snapshot.classes.duplicate(true); var found:=false
	for cls in levels:
		if int(cls.id)==int(draft.classId): cls.level=int(cls.level)+1; found=true
	if not found: levels.append({"id":int(draft.classId),"level":1})
	var bab:=0; var fort:=floori((int(scores[2])-10)/2.0)
	for cls in levels:
		for field in ["AttackBonusTable","SavingThrowTable"]:
			var name:=str(rules.cell(rules.row("classes",int(cls.id)),field,"")).to_lower(); var list: Array=desktop.owner_ui.text.tables.get(name,{}).get("orderedRows",[]); var index:=mini(int(cls.level),20)-1
			if index>=0 and index<list.size():
				if field=="AttackBonusTable": bab+=num(list[index],"BAB")
				else: fort+=num(list[index],"FortSave")
	if bab<num(feat,"MINATTACKBONUS"): return "Base attack requirement."
	if fort<num(feat,"MinFortSave"): return "Fortitude requirement."
	if total()+1<num(feat,"MinLevel") or num(feat,"MaxLevel")>0 and total()+1>num(feat,"MaxLevel"): return "Level requirement."
	var required_class:=num(feat,"MinLevelClass",255)
	if num(feat,"MinLevel")>0 and required_class!=255:
		var required_level:=0
		for cls in levels:
			if int(cls.id)==required_class: required_level=int(cls.level)
		if required_level<num(feat,"MinLevel"): return "Class level requirement."
	if num(feat,"PreReqEpic")!=0 and not owned.has(1001): return "Epic character required."
	for key in ["PREREQFEAT1","PREREQFEAT2"]:
		var required:=num(feat,key,-1)
		if required>=0 and required!=65535 and not owned.has(required): return "Prerequisite feat required."
	var alternatives: Array=[]
	for index in 5:
		var required:=num(feat,"OrReqFeat"+str(index),-1)
		if required>=0 and required!=65535: alternatives.append(required)
	if not alternatives.is_empty() and not alternatives.any(func(required):return owned.has(required)): return "Prerequisite feat required."
	for suffix in ["","2"]:
		var skill:=num(feat,"REQSKILL"+suffix,-1)
		if skill>=0 and skill!=65535 and (skill>=snapshot.skills.size() or not skill_rule(skill).allowed or int(snapshot.skills[skill])+int(draft.skills[skill])<num(feat,"ReqSkillMinRanks"+suffix)): return "Skill ranks required."
	var spell:=num(feat,"MINSPELLLVL")
	if spell>0:
		var meets:=false
		for cls in levels:
			var row: Dictionary=rules.row("classes",int(cls.id)); var ability:= ["STR","DEX","CON","INT","WIS","CHA"].find(str(rules.cell(row,"SpellcastingAbil","")).to_upper()); var name:=str(rules.cell(row,"SpellGainTable","")).to_lower(); var gains: Array=desktop.owner_ui.text.tables.get(name,{}).get("orderedRows",[]); var index:=int(cls.level)-1
			if num(row,"SpellCaster")!=0 and ability>=0 and int(scores[ability])>=10+spell and index>=0 and index<gains.size() and num(gains[index],"SpellLevel"+str(spell),255)<255: meets=true
		if not meets: return "Spellcasting level required."
	return ""
func feat_distribution_valid() -> bool:
	var slots:=feat_slots(); var only_normal:=0; var only_bonus:=0; var both:=0
	for id in draft.feats:
		var normal:=feat_allowed(int(id),"normal"); var bonus:=feat_allowed(int(id),"bonus")
		if normal and bonus: both+=1
		elif normal: only_normal+=1
		elif bonus: only_bonus+=1
		else: return false
	return only_normal<=int(slots.normal) and only_bonus<=int(slots.bonus) and only_normal+only_bonus+both==int(slots.normal)+int(slots.bonus)
func spell_options(level: int) -> Array:
	var result: Array=[]; var class_id:=int(draft.classId); var gain:=class_row("SpellGainTable",class_level(class_id)); var max_level:=num(gain,"NumSpellLevels")
	if level>=max_level: return result
	var known: Array=[]
	for index in snapshot.classes.size():
		if int(snapshot.classes[index].id)==class_id: known=snapshot.spellbooks.get(str(index),{}).get("known",[])
	for id in desktop.owner_ui.text.tables.get("spells",{}).get("orderedRows",[]).size():
		var spell: Dictionary=rules.row("spells",id); var school: Dictionary=rules.row("spellschools",int(draft.school)); var opposed: Dictionary=rules.row("spellschools",num(school,"Opposition",-1)); var master:=num(spell,"Master",-1)
		if rules.spell_level(id,class_id)==level and not known.has(id) and num(spell,"UserType",1)==1 and (master<0 or master==id) and str(rules.cell(spell,"Name","****"))!="****" and (num(rules.row("classes",class_id),"PickSchool")==0 or str(rules.cell(opposed,"Letter","****"))=="****" or rules.cell(spell,"School")!=rules.cell(opposed,"Letter")): result.append(id)
	return result
func spell_count(level: int) -> int:
	var cls: Dictionary=rules.row("classes",int(draft.classId)); var current:=class_level(int(draft.classId)); var gain:=class_row("SpellGainTable",current)
	if num(cls,"SpellCaster")==0 or num(cls,"SkipSpellSelection")!=0 or num(cls,"SpellbookRestricted")==0 or level>=num(gain,"NumSpellLevels"): return 0
	if num(cls,"LearnScroll")!=0:
		if current>0: return 0 if level==0 else 2
		return spell_options(0).size() if level==0 else 3+maxi(0,floori((int(abilities()[3])-10)/2.0)) if level==1 else 0
	var known_count:=0
	for index in snapshot.classes.size():
		if int(snapshot.classes[index].id)==int(draft.classId):
			for id in snapshot.spellbooks.get(str(index),{}).get("known",[]):
				if rules.spell_level(int(id),int(draft.classId))==level: known_count+=1
	return maxi(0,num(class_row("SpellKnownTable",current),"SpellLevel"+str(level))-known_count)
func errors() -> Array:
	var result: Array=[]
	if (total()+1)%4==0 and int(draft.ability)==6: result.append("Choose an ability increase.")
	if balance()<0: result.append("Too many skill points spent.")
	var slots:=feat_slots()
	if not feat_distribution_valid(): result.append("Choose all general and class bonus feats.")
	var prior: Array=[]
	for id in draft.feats:
		var reason:=feat_requirement(int(id),prior)
		if not reason.is_empty(): result.append(rules.title("feat",int(id),"FEAT")+": "+reason)
		prior.append(id)
	for index in draft.skills.size():
		if int(draft.skills[index])<0 or int(draft.skills[index])>127 or int(draft.skills[index])>0 and (not skill_rule(index).allowed or int(snapshot.skills[index])+int(draft.skills[index])>int(skill_rule(index).maximum)): result.append("Invalid skill ranks.")
	var cls: Dictionary=rules.row("classes",int(draft.classId)); var learned:=0
	for list in draft.known.values(): learned+=list.size()
	if num(cls,"LearnScroll")!=0 and class_level(int(draft.classId))>0:
		if learned!=2: result.append("Choose two new spells.")
	else:
		for level in 10:
			if draft.known.get(str(level),[]).size()!=spell_count(level): result.append("Choose level "+str(level)+" spells.")
	if num(cls,"PickDomains")!=0 and (draft.domains.size()!=2 or draft.domains[0]==draft.domains[1]): result.append("Choose two domains.")
	for level in 10:
		var allowed:=spell_options(level)
		for id in draft.known.get(str(level),[]):
			if not allowed.has(id): result.append("Invalid spell selection.")
	return result
func add(items: Array,type: String,label: String,operation: String="",value: Variant=null,extra: Dictionary={}) -> void:
	var id:=controls.size(); controls[id]={"operation":operation,"value":value}; var item:={"type":type,"label":label,"controlId":id,"disabled":submitting}; item.merge(extra); items.append(item)
func render() -> void:
	if not ui.wanted or snapshot.is_empty() or draft.is_empty(): return
	var ready: bool=desktop.class_tables_ready(int(draft.classId))
	for cls in snapshot.classes: ready=desktop.class_tables_ready(int(cls.id)) and ready
	if not ready: return
	if status=="Loading native class rules…": status=""
	if num(rules.row("classes",int(draft.classId)),"LearnScroll")!=0 and class_level(int(draft.classId))==0: draft.known["0"]=spell_options(0)
	serial+=1; controls.clear(); var items: Array=[]; var cls: Dictionary=rules.row("classes",int(draft.classId))
	match step:
		0:
			for id in available.size():
				if available[id]: add(items,"button",rules.title("classes",id),"class",id,{"selected":id==int(draft.classId)})
		1:
			if (total()+1)%4!=0: add(items,"text","No ability increase at this level.")
			else:
				for index in 6: add(items,"button",rules.ABILITIES[index]+" "+str(abilities()[index]),"ability",index,{"selected":int(draft.ability)==index})
		2:
			add(items,"text","Skill points remaining: "+str(balance()))
			for index in snapshot.skills.size():
				var rule:=skill_rule(index)
				if not rule.allowed: continue
				add(items,"text",rules.title("skills",index)+" · "+str(int(snapshot.skills[index])+int(draft.skills[index]))+" / "+str(rule.maximum),"",null,{"tag":"skill"})
				add(items,"button","−","skill-minus",index,{"tag":"skill-minus","disabled":int(draft.skills[index])<=0})
				add(items,"button","+","skill-plus",index,{"tag":"skill-plus","disabled":balance()<int(rule.cost) or int(snapshot.skills[index])+int(draft.skills[index])>=int(rule.maximum)})
		3:
			var slots:=feat_slots(); add(items,"text","Choose "+str(slots.normal)+" general and "+str(slots.bonus)+" class bonus feats.")
			for id in desktop.owner_ui.text.tables.get("feat",{}).get("orderedRows",[]).size():
				if draft.feats.has(id) or (feat_allowed(id,"normal") or feat_allowed(id,"bonus")) and feat_requirement(id,draft.feats).is_empty(): add(items,"toggle",rules.title("feat",id,"FEAT"),"feat",id,{"value":draft.feats.has(id)})
		4:
			for level in 10:
				var count:=spell_count(level)
				if count<=0: continue
				add(items,"text","Level "+str(level)+" · choose "+str(count)+" spell(s).")
				for id in spell_options(level): add(items,"toggle",rules.title("spells",id),"spell",[level,id],{"value":draft.known.get(str(level),[]).has(id),"disabled":num(cls,"LearnScroll")!=0 and class_level(int(draft.classId))==0 and level==0})
		5:
			if num(cls,"PickDomains")!=0:
				add(items,"text","Choose two different domains.")
				for id in desktop.owner_ui.text.tables.get("domains",{}).get("orderedRows",[]).size():
					if num(rules.row("domains",id),"PlayerClass",1)!=0: add(items,"toggle",rules.title("domains",id),"domain",id,{"value":draft.domains.has(id),"disabled":class_level(int(draft.classId))>0 or not draft.domains.has(id) and draft.domains.size()>=2})
			if num(cls,"PickSchool")!=0:
				var options: Array=[]
				for id in desktop.owner_ui.text.tables.get("spellschools",{}).get("orderedRows",[]).size(): options.append(rules.title("spellschools",id))
				add(items,"select","Spell school","school",null,{"options":options,"value":int(draft.school),"disabled":class_level(int(draft.classId))>0})
			for specification in [["Familiar","hen_familiar","fieldE34",303],["Animal companion","hen_companion","fieldE30",199]]:
				if not (snapshot.feats+granted()+draft.feats).has(specification[3]): continue
				var options: Array=["None"]; var ids: Array=[255]
				for id in desktop.owner_ui.text.tables.get(specification[1],{}).get("orderedRows",[]).size():
					if num(rules.row(specification[1],id),"PLAYER",1)==0: continue
					options.append(rules.title(specification[1],id,"STRREF")); ids.append(id)
				if not options.is_empty(): add(items,"select",specification[0],"companion",{"field":specification[2],"ids":ids},{"options":options,"value":ids.find(int(draft[specification[2]]))})
			for pair in [["Familiar name","fieldE48",303],["Companion name","fieldE38",199]]:
				if (snapshot.feats+granted()+draft.feats).has(pair[2]): add(items,"input",pair[0],"name",pair[1],{"value":str(draft[pair[1]]),"maxLength":63})
		6:
			add(items,"text",rules.title("classes",int(draft.classId))+" level "+str(class_level(int(draft.classId))+1)+"\nHit die: "+str(draft.hitDie)+"\nUnspent skill points: "+str(balance())+"\nFeats selected: "+str(draft.feats.size())+"\nThe server validates and applies these choices.")
	var problems:=errors(); ui.receive({"kind":"level-view","viewId":serial,"step":step,"items":items,"status":status,"errors":problems,"canEdit":not submitting,"canBack":step>0 and not submitting,"canNext":step<6 and not submitting,"canFinish":problems.is_empty() and not submitting,"canCancel":not submitting})
func input(message: Dictionary) -> void:
	if message.has("viewId") and int(message.viewId)!=serial: return
	for entry in message.get("texts",[]):
		var control: Dictionary=controls.get(int(entry.controlId),{})
		if str(control.get("operation",""))=="name": draft[str(control.value)]=str(entry.value).left(63)
	status=""
	match str(message.kind):
		"level-open": desktop.command({"kind":"native-level-up","operation":"begin"})
		"level-cancel": desktop.command({"kind":"native-level-up","operation":"cancel"}); snapshot.clear(); draft.clear(); ui.reset()
		"level-page":
			if int(message.viewId)==serial: step=clampi(int(message.step),0,6); render()
		"level-control":
			if int(message.viewId)!=serial or not controls.has(int(message.controlId)): return
			var control: Dictionary=controls[int(message.controlId)]; var id:=int(control.value) if control.value is int else -1
			match str(control.operation):
				"class": select_class(id); return
				"ability": draft.ability=id
				"skill-plus":
					var rule:=skill_rule(id)
					if balance()>=int(rule.cost) and int(snapshot.skills[id])+int(draft.skills[id])<int(rule.maximum): draft.skills[id]=int(draft.skills[id])+1
				"skill-minus": draft.skills[id]=maxi(0,int(draft.skills[id])-1)
				"feat":
					if message.value and not draft.feats.has(id): draft.feats.append(id)
					elif not message.value: draft.feats.erase(id)
				"spell":
					var level:=str(control.value[0]); var spell:=int(control.value[1])
					if not draft.known.has(level): draft.known[level]=[]
					if message.value and not draft.known[level].has(spell): draft.known[level].append(spell)
					elif not message.value: draft.known[level].erase(spell)
				"domain":
					if message.value and not draft.domains.has(id) and draft.domains.size()<2: draft.domains.append(id)
					elif not message.value: draft.domains.erase(id)
				"school": draft.school=int(message.value); draft.known.clear()
				"companion":
					if int(message.value)>=0 and int(message.value)<control.value.ids.size(): draft[str(control.value.field)]=int(control.value.ids[int(message.value)])
				"name": draft[str(control.value)]=str(message.value)
			render()
		"level-submit":
			if int(message.viewId)!=serial or not errors().is_empty(): return
			var proposal:=draft.duplicate(true); proposal.skillPoints=balance(); proposal.feats=granted()+draft.feats
			submitting=true; render(); desktop.command({"kind":"native-level-up","operation":"submit","token":token,"proposal":proposal})
