extends RefCounted
# First-level choices derive from this connection's resolved physical 2DA rows.
# No stock spell/feat/class lists or recommendations are embedded here.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const ABILITIES=["Str","Dex","Con","Int","Wis","Cha"]
const ALIGNMENTS=["Lawful Good","Neutral Good","Chaotic Good","Lawful Neutral","True Neutral","Chaotic Neutral","Lawful Evil","Neutral Evil","Chaotic Evil"]
var tables: Dictionary={}
var catalog
var draft: Dictionary={}
var model_names: Array=[]
var palette_sizes: Dictionary={}
var portrait_cache: Dictionary={}
func rows(name: String) -> Array: return tables.get(name.to_lower(),{}).get("orderedRows",[])
func row(name: String,id: int) -> Dictionary:
	var list:=rows(name); return list[id] if id>=0 and id<list.size() else {}
func cell(data: Dictionary,key: String,default: Variant=null) -> Variant: return Game.cell(data,key,default)
func num(data: Dictionary,key: String,default: int=0) -> int: return Game.number(cell(data,key),default)
func present(value: Variant) -> bool: return value is String and not value.is_empty() and value!="****"
func cls() -> Dictionary: return row("classes",int(draft.classId))
func race() -> Dictionary: return row("racialtypes",int(draft.raceId))
func class_rows(field: String) -> Array: return rows(str(cell(cls(),field,"")))
func first(field: String) -> Dictionary:
	var list:=class_rows(field); return list[0] if not list.is_empty() else {}
func cfg(key: String,default: int) -> int:
	var result:=default
	for data in rows("ruleset"):
		if str(cell(data,"Label","")).to_upper()=="CHARGEN_"+key: result=num(data,"Value",default)
	return result
func alignment(index: int) -> Dictionary: return {"goodEvil":[85,50,15][index/3],"lawChaos":[85,50,15][index%3]}
func alignment_allowed(data: Dictionary,ge: int,lc: int) -> bool:
	var axes:=num(data,"AlignRstrctType"); var mask:=num(data,"AlignRestrict")
	var matches:=((axes&2)!=0 and (mask&(16 if ge<31 else 8 if ge>69 else 1))!=0) or ((axes&1)!=0 and (mask&(2 if lc>69 else 4 if lc<31 else 1))!=0)
	return matches if num(data,"InvertRestrict")!=0 else not matches
func class_requirement(id: int) -> String:
	var data:=row("classes",id)
	if data.is_empty() or num(data,"PlayerClass")==0: return "Not a player class."
	if num(data,"EpicLevel",255)==0: return "Requires epic levels."
	var name: String=str(cell(data,"PreReqTable",""))
	if not present(name): return ""
	if not tables.has(name.to_lower()): return "Class prerequisites have not loaded."
	var racial: Array=[]
	for feat in rows(str(cell(race(),"FeatsTable",""))): racial.append(num(feat,"FeatIndex",-1))
	var groups: Dictionary={}
	for requirement in rows(name):
		var kind:=str(cell(requirement,"ReqType","")); var a:=num(requirement,"ReqParam1"); var b:=num(requirement,"ReqParam2"); var valid:=true
		match kind:
			"RACE": groups.race=bool(groups.get("race",false)) or int(draft.raceId)==a
			"FEATOR": groups.feat=bool(groups.get("feat",false)) or racial.has(a&65535)
			"CLASSOR": groups.classes=false
			"FEAT": valid=racial.has(a&65535)
			"BAB": valid=a<=0
			"SKILL","SAVE": valid=b<=0
			"SPELL","ARCSPELL": valid=false
			"VAR": valid=present(cell(requirement,"ReqParam1")) and b==0
		if not valid: return "First-level class prerequisites are not met."
	for valid in groups.values():
		if not valid: return "First-level class prerequisites are not met."
	return ""
func packages() -> Array:
	var result: Array=[]
	for id in rows("packages").size():
		var data:=row("packages",id)
		if num(data,"ClassID",-1)==int(draft.classId) and num(data,"PlayerClass")!=0: result.append(id)
	return result
func default_package() -> int:
	var options:=packages(); var configured:=num(cls(),"Package",-1); return configured if options.has(configured) else int(options[0]) if not options.is_empty() else -1
func initialize() -> void:
	draft={"gender":0,"raceId":-1,"classId":-1,"goodEvil":50,"lawChaos":50,"abilities":{},"skills":{},"feats":[],"known":{},"memorized":{},"domains":[],"school":0,"packageId":-1,"firstName":"","lastName":"","subrace":"","deity":"","biography":"","age":18,"phenotype":0,"head":1,"clothes":0,"skin":0,"hair":0,"tattoo1":0,"tattoo2":0,"portrait":"","soundset":0,"familiar":0,"familiarName":"Familiar","companion":0,"companionName":"Companion"}
	for id in rows("racialtypes").size():
		if num(row("racialtypes",id),"PlayerRace")!=0: draft.raceId=id; break
	for id in rows("classes").size():
		if class_requirement(id).is_empty(): draft.classId=id; break
	select_class(int(draft.classId)); draft.age=num(race(),"AGE",18)
func reset_choices() -> void: draft.skills={}; draft.feats=[]; draft.known={}; draft.memorized={}
func select_class(id: int) -> void:
	draft.classId=id; draft.packageId=default_package(); reset_choices(); initialize_abilities()
	for index in 9:
		var a:=alignment(index)
		if alignment_allowed(cls(),a.goodEvil,a.lawChaos): draft.goodEvil=a.goodEvil; draft.lawChaos=a.lawChaos; break
func abilities() -> Dictionary:
	var result: Dictionary={}
	for key in ABILITIES: result[key]=int(draft.abilities.get(key,cfg("BASE_ABILITY_MIN",8)))+num(race(),key+"Adjust")+num(first("StatGainTable"),key)
	return result
func primary() -> String:
	for key in ABILITIES:
		if str(cell(cls(),"SpellcastingAbil","")).to_upper()==key.to_upper(): return key
	return ""
func initialize_abilities() -> void:
	for key in ABILITIES: draft.abilities[key]=cfg("BASE_ABILITY_MIN",8)
	var key:=primary()
	if num(cls(),"SpellCaster")!=0 and not key.is_empty(): draft.abilities[key]+=maxi(0,cfg("BASE_ABILITY_MIN_PRIMARY",11)-int(abilities()[key]))
func point_cost(score: int) -> int:
	if score<cfg("BASE_ABILITY_MIN",8) or score>cfg("BASE_ABILITY_MAX",18): return 1000000
	var cost:=0
	for value in range(cfg("BASE_ABILITY_MIN",8)+1,score+1): cost+=4 if value>cfg("ABILITY_COST_INCREMENT4",255) else 3 if value>cfg("ABILITY_COST_INCREMENT3",16) else 2 if value>cfg("ABILITY_COST_INCREMENT2",14) else 1
	return cost
func point_balance() -> int:
	var result:=num(race(),"AbilitiesPointBuyNumber",30)
	for key in ABILITIES: result-=point_cost(int(draft.abilities[key]))
	return result
func can_decrease(key: String) -> bool: return int(draft.abilities[key])>cfg("BASE_ABILITY_MIN",8) and (num(cls(),"SpellCaster")==0 or primary()!=key or int(abilities()[key])>cfg("BASE_ABILITY_MIN_PRIMARY",11))
func modifier(score: int) -> int: return floori((score-10)/2.0)
func skill_budget() -> int:
	var ability:=str(cell(race(),"SkillPointModifierAbility","")); var key:=""
	for candidate in ABILITIES:
		if candidate.to_upper()==ability.to_upper(): key=candidate
	if key.is_empty() and ability.is_valid_int() and int(ability)>=0 and int(ability)<6: key=ABILITIES[int(ability)]
	return (maxi(1,num(cls(),"SkillPointBase")+modifier(int(abilities()[key]) if not key.is_empty() else cfg("ABILITY_NEUTRAL_VALUE",10)))+num(race(),"ExtraSkillPointsPerLevel"))*num(race(),"FirstLevelSkillPointsMultiplier",4)
func skill_rule(id: int) -> Dictionary:
	var entry: Dictionary={}
	for data in class_rows("SkillsTable"):
		if num(data,"SkillIndex",-1)==id: entry=data; break
	var class_skill:=num(entry,"ClassSkill")!=0
	return {"allowed":not row("skills",id).is_empty() and (num(row("skills",id),"AllClassesCanUse")!=0 or not entry.is_empty()),"classSkill":class_skill,"cost":1 if class_skill else 2,"max":floori((1+cfg("SKILL_MAX_LEVEL_1_BONUS",3))/(1.0 if class_skill else 2.0))}
func skill_balance() -> int:
	var result:=skill_budget()
	for id in draft.skills: result-=int(draft.skills[id])*int(skill_rule(int(id)).cost)
	return result
func granted_feats() -> Array:
	var result: Array=[]; var candidates: Array=[]
	for data in rows(str(cell(race(),"FeatsTable",""))): candidates.append(num(data,"FeatIndex",-1))
	for data in class_rows("FeatsTable"):
		if num(data,"List",-1)==3 and num(data,"GrantedOnLevel",-1)==1: candidates.append(num(data,"FeatIndex",-1))
	if num(cls(),"PickDomains")!=0:
		for id in draft.domains: candidates.append(num(row("domains",int(id)),"GrantedFeat",-1))
	for id in candidates:
		if id>=0 and present(cell(row("feat",id),"FEAT")) and not result.has(id): result.append(id)
	return result
func feat_slots() -> Dictionary: return {"normal":num(race(),"NumberNormalFeatsEveryNthLevel",1)+num(race(),"ExtraFeatsAtFirstLevel"),"bonus":num(first("BonusFeatsTable"),"Bonus")}
func feat_allowed(id: int,kind: String) -> bool:
	var feat:=row("feat",id); var list:=-1
	if not present(cell(feat,"FEAT")): return false
	for data in class_rows("FeatsTable"):
		if num(data,"FeatIndex",-1)==id: list=num(data,"List",-1); break
	return list in [1,2] if kind=="bonus" else list in [0,1] or num(feat,"AllClassesCanUse")!=0 and list!=2
func feat_requirement(id: int,owned: Array) -> String:
	var feat:=row("feat",id); var scores:=abilities()
	if not present(cell(feat,"FEAT")): return "Invalid feat."
	if owned.has(id) and num(feat,"GainMultiple")==0: return "Already acquired."
	for key in ABILITIES:
		if int(scores[key])<num(feat,"MIN"+key.to_upper()): return "Ability requirement."
	if num(first("AttackBonusTable"),"BAB")<num(feat,"MINATTACKBONUS"): return "Base attack requirement."
	if present(cell(feat,"MinFortSave")) and num(first("SavingThrowTable"),"FortSave")+modifier(scores.Con)<num(feat,"MinFortSave"): return "Fortitude requirement."
	if num(feat,"MinLevel")>1 or num(feat,"MaxLevel")>0 and num(feat,"MaxLevel")<1: return "Level requirement."
	if num(feat,"MinLevel")>0 and num(feat,"MinLevelClass",255)!=255 and num(feat,"MinLevelClass")!=int(draft.classId): return "Class requirement."
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
		if skill>=0 and skill!=65535 and (not skill_rule(skill).allowed or int(draft.skills.get(skill,0))<num(feat,"ReqSkillMinRanks"+suffix)): return "Skill ranks required."
	var level:=num(feat,"MINSPELLLVL"); var key:=primary()
	if level>0 and (num(cls(),"SpellCaster")==0 or key.is_empty() or int(scores[key])<10+level or num(first("SpellGainTable"),"SpellLevel"+str(level),-1)<0): return "Spellcasting level required."
	return ""
func spell_options(level: int) -> Array:
	var result: Array=[]; var column:=str(cell(cls(),"SpellTableColumn","")); var opposition:=num(row("spellschools",int(draft.school)),"Opposition",-1); var opposed:=str(cell(row("spellschools",opposition),"Letter",""))
	if num(cls(),"SpellCaster")==0 or not present(column): return result
	for id in rows("spells").size():
		var data:=row("spells",id); var master:=num(data,"Master",-1)
		if num(data,column,255)==level and present(cell(data,"Name")) and num(data,"UserType",1)==1 and (master<0 or master==id) and (num(cls(),"PickSchool")==0 or not present(opposed) or cell(data,"School")!=opposed): result.append(id)
	return result
func spell_count(level: int) -> int:
	if num(cls(),"SpellCaster")==0 or num(cls(),"SkipSpellSelection")!=0 or num(cls(),"SpellbookRestricted")==0 or level>=num(first("SpellGainTable"),"NumSpellLevels"): return 0
	if num(cls(),"LearnScroll")!=0: return spell_options(0).size() if level==0 else 3+maxi(0,modifier(int(abilities().Int))) if level==1 else 0
	return num(first("SpellKnownTable"),"SpellLevel"+str(level))
func spell_slots(level: int) -> int:
	var key:=primary()
	if num(cls(),"SpellCaster")==0 or key.is_empty() or int(abilities()[key])<level-1+cfg("BASE_ABILITY_MIN_PRIMARY",11): return 0
	var gain:=first("SpellGainTable"); var count:=num(gain,"SpellLevel"+str(level),255) if level<num(gain,"NumSpellLevels") else 255
	if count==255: return 0
	var bonus:=modifier(int(abilities()[key]))
	count+=floori((bonus-level+4)/4.0) if level!=0 and bonus>0 and bonus>=level else 0
	if level!=0 and num(cls(),"PickSchool")!=0 and int(draft.school)!=0: count+=1
	return count&255
func prepared_options(level: int,domain: bool=false) -> Array:
	var result: Array=[]
	if domain:
		for id in draft.domains:
			var spell:=num(row("domains",int(id)),"Level_"+str(level),-1)
			if spell>=0 and not row("spells",spell).is_empty() and not result.has(spell): result.append(spell)
	else:
		for id in spell_options(level):
			if num(cls(),"SpellbookRestricted")==0 or draft.known.get(level,[]).has(id): result.append(id)
	return result
func portraits() -> Array:
	var key:=str(draft.gender)+":"+str(draft.raceId)
	if portrait_cache.has(key): return portrait_cache[key]
	var matching: Array=[]; var others: Array=[]; var seen: Dictionary={}
	for data in rows("portraits"):
		var base:="po_"+str(cell(data,"BaseResRef","")).to_lower()
		seen[base]=true
		if not present(cell(data,"BaseResRef")) or num(data,"Plot")!=0 or num(data,"Sex",-1)!=int(draft.gender) or not portrait_available(base): continue
		if num(data,"Race",-1)==int(draft.raceId): matching.append(base)
		else: others.append(base)
	if cfg("ALLOW_CUSTOM_PORTRAITS",1)!=0 and catalog!=null:
		for type in [3,2033]:
			for name in catalog.resource_names(type):
				if not str(name).ends_with("m"): continue
				var base:=str(name).left(-1)
				if not seen.has(base) and portrait_available(base): others.append(base); seen[base]=true
	matching.append_array(others); portrait_cache[key]=matching; return matching
func portrait_available(base: String) -> bool:
	if catalog==null: return true
	for suffix in ["m","s","l","t","h",""]:
		if catalog.has_resource(base+suffix,3) or catalog.has_resource(base+suffix,2033): return true
	return false
func voices() -> Array:
	var result: Array=[]
	for id in rows("soundset").size():
		if num(row("soundset",id),"TYPE",-1)==0 and num(row("soundset",id),"GENDER",-1)==int(draft.gender): result.append(id)
	return result
func phenotypes() -> Array:
	var result: Array=[]
	for id in rows("phenotype").size():
		if cfg("ENABLED_PHENOTYPES",5)&(1<<id): result.append(id)
	return result
func heads() -> Array:
	var appearance:=row("appearance",num(race(),"Appearance")); var prefix:="p"+str(cell(row("gender",int(draft.gender)),"GENDER",""))+str(cell(appearance,"RACE",""))+str(draft.phenotype)+"_head"; prefix=prefix.to_lower(); var result: Array=[]
	for name in model_names:
		if str(name).begins_with(prefix):
			var id:=str(name).substr(prefix.length())
			if id.is_valid_int() and int(id)>0 and int(id)<=255 and not result.has(int(id)): result.append(int(id))
	result.sort(); return result
func clothes() -> Array:
	var result: Array=[]; var alignment_code:=("L" if int(draft.lawChaos)>69 else "C" if int(draft.lawChaos)<31 else "N")+("G" if int(draft.goodEvil)>69 else "E" if int(draft.goodEvil)<31 else "N")
	if alignment_code=="NN": alignment_code="TN"
	for id in rows("chargenclothes").size():
		var data:=row("chargenclothes",id)
		if present(cell(data,"ItemResRef")) and (not present(cell(data,"ClassRestrict")) or num(data,"ClassRestrict")==int(draft.classId)) and (not present(cell(data,"RaceRestrict")) or num(data,"RaceRestrict")==int(draft.raceId)) and (not present(cell(data,"GenderRestrict")) or num(data,"GenderRestrict")==int(draft.gender)) and (not present(cell(data,"AlignmentRestrict")) or cell(data,"AlignmentRestrict")==alignment_code): result.append(id)
	return result
func preference(field: String,column: String) -> Array:
	var result: Array=[]
	for data in rows(str(cell(row("packages",int(draft.packageId)),field,""))):
		var id:=num(data,column,-1)
		if id>=0 and not result.has(id): result.append(id)
	return result
func recommend() -> String:
	if not packages().has(int(draft.packageId)): draft.packageId=default_package()
	if int(draft.packageId)<0: return "No selectable starting package is available for this class."
	var package:=row("packages",int(draft.packageId)); var ordered: Array=ABILITIES.duplicate()
	ordered.sort_custom(func(a,b):return num(cls(),a)>num(cls(),b))
	for key in ABILITIES: draft.abilities[key]=cfg("BASE_ABILITY_MIN",8)
	for pass_index in 100:
		var changed:=false
		for key in ordered:
			var score:=int(draft.abilities[key]); var delta:=point_cost(score+1)-point_cost(score)
			if score<num(cls(),key,cfg("BASE_ABILITY_MIN",8)) and delta<=point_balance(): draft.abilities[key]=score+1; changed=true
		if not changed: break
	for pass_index in 100:
		var changed:=false
		for key in ordered:
			var score:=int(draft.abilities[key])
			if point_cost(score+1)-point_cost(score)<=point_balance(): draft.abilities[key]=score+1; changed=true; break
		if not changed: break
	if num(cls(),"PickDomains")!=0: draft.domains=[num(package,"Domain1",0),num(package,"Domain2",1)]
	if num(cls(),"PickSchool")!=0: draft.school=num(package,"School")
	var skills:=preference("SkillPref2DA","SkillIndex")
	for id in rows("skills").size():
		if not skills.has(id): skills.append(id)
	draft.skills={}
	for id in skills:
		var rule:=skill_rule(id)
		if rule.allowed and num(row("skills",id),"HideFromLevelUp")==0: draft.skills[id]=mini(int(rule.max),floori(skill_balance()/float(rule.cost)))
	var feats:=preference("FeatPref2DA","FeatIndex")
	for id in rows("feat").size():
		if not feats.has(id): feats.append(id)
	draft.feats=[]; var slots:=feat_slots()
	for kind in ["bonus","normal"]:
		for slot in int(slots[kind]):
			var owned:=granted_feats()
			for choice in draft.feats: owned.append(choice.id)
			for id in feats:
				if feat_allowed(id,kind) and feat_requirement(id,owned).is_empty(): draft.feats.append({"id":id,"kind":kind}); break
	var spells:=preference("SpellPref2DA","SpellIndex"); draft.known={}; draft.memorized={}
	for level in 10:
		var options:=spell_options(level); var order: Array=[]
		for id in spells+options:
			if options.has(id) and not order.has(id): order.append(id)
		draft.known[level]=order.slice(0,spell_count(level))
		if num(cls(),"MemorizesSpells")==0: continue
		draft.memorized[level]=[]
		for slot in spell_slots(level):
			options=prepared_options(level,num(cls(),"PickDomains")!=0 and level>0 and slot==spell_slots(level)-1); order=[]
			for id in spells+options:
				if options.has(id) and not order.has(id): order.append(id)
			draft.memorized[level].append(order[slot%order.size()] if not order.is_empty() else null)
	var images:=portraits(); draft.portrait=images[0] if not images.is_empty() else ""
	var voices_list:=voices(); draft.soundset=int(voices_list[0]) if not voices_list.is_empty() else 0
	var head_list:=heads(); draft.head=int(head_list[0]) if not head_list.is_empty() else 1
	var clothing:=clothes(); draft.clothes=int(clothing[0]) if not clothing.is_empty() else 0
	draft.familiar=num(package,"Associate"); draft.companion=num(package,"Associate")
	return ""
func errors() -> Array:
	var result: Array=[]; var class_error:=class_requirement(int(draft.classId)); var scores:=abilities()
	if num(race(),"PlayerRace")==0: result.append("Select a playable race.")
	if not class_error.is_empty(): result.append(class_error)
	if not alignment_allowed(cls(),int(draft.goodEvil),int(draft.lawChaos)): result.append("Choose an allowed alignment.")
	if point_balance()!=0: result.append("Spend all ability points.")
	if num(cls(),"SpellCaster")!=0 and (primary().is_empty() or int(scores.get(primary(),0))<cfg("BASE_ABILITY_MIN_PRIMARY",11)): result.append("Spellcasting ability is too low.")
	if skill_balance()<0: result.append("Too many skill points spent.")
	for id in draft.skills:
		var rule:=skill_rule(int(id)); var rank:=int(draft.skills[id])
		if rank<0 or rank>int(rule.max) or rank>0 and not rule.allowed: result.append("Invalid skill ranks.")
	var counts:={"bonus":0,"normal":0}; var owned:=granted_feats()
	for choice in draft.feats:
		if not counts.has(choice.kind) or not feat_allowed(int(choice.id),str(choice.kind)): result.append("Invalid feat selection."); continue
		counts[choice.kind]+=1; var reason:=feat_requirement(int(choice.id),owned)
		if not reason.is_empty(): result.append(reason)
		owned.append(int(choice.id))
	if counts!=feat_slots(): result.append("Select every available feat.")
	if num(cls(),"PickDomains")!=0 and (draft.domains.size()!=2 or draft.domains[0]==draft.domains[1]): result.append("Choose two different domains.")
	for level in 10:
		var selected: Array=draft.known.get(level,[]); var allowed:=spell_options(level); var seen: Dictionary={}
		if selected.size()!=spell_count(level): result.append("Choose level "+str(level)+" spells.")
		for id in selected:
			if not allowed.has(id) or seen.has(id): result.append("Invalid learned spell.")
			seen[id]=true
		var prepared: Array=draft.memorized.get(level,[]); var slots:=spell_slots(level)
		if prepared.size()>slots: result.append("Invalid preparation slots.")
		for index in prepared.size():
			if prepared[index]!=null and not prepared_options(level,num(cls(),"PickDomains")!=0 and level>0 and index==slots-1).has(prepared[index]): result.append("Invalid prepared spell.")
	if str(draft.firstName).strip_edges().is_empty(): result.append("Enter a first name.")
	var writer:=Writer.new()
	for key in ["firstName","lastName","subrace","deity","biography","familiarName","companionName"]:
		var bytes:=writer.text(str(draft[key]))
		if not writer.failure.is_empty() or key!="biography" and bytes.size()>32: result.append("Invalid or overlong "+key+".")
	if int(draft.age)<1 or int(draft.age)>2147483647: result.append("Enter a valid age.")
	if not portraits().has(draft.portrait): result.append("Choose an available portrait.")
	if not voices().has(draft.soundset): result.append("Choose an available voice.")
	if not heads().has(draft.head) or not phenotypes().has(draft.phenotype): result.append("Choose an available head and body type.")
	if not clothes().has(draft.clothes): result.append("Choose available clothing.")
	if not packages().has(draft.packageId): result.append("Choose an available class package.")
	for key in ["skin","hair","tattoo1","tattoo2"]:
		if int(draft[key])<0 or int(draft[key])>=mini(256,int(palette_sizes.get(key,176))): result.append("Invalid "+key+" colour.")
	for spec in [[303,"hen_familiar","familiar"],[199,"hen_companion","companion"]]:
		if owned.has(spec[0]) and (row(spec[1],int(draft[spec[2]])).is_empty() or str(draft[spec[2]+"Name"]).strip_edges().is_empty()): result.append("Choose and name your "+str(spec[2])+".")
	return result
