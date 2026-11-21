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
var palette_bytes: Dictionary={}
var palette_swatches: Dictionary={}
var portrait_cache: Dictionary={}
var portrait_prepared:=false
var custom_portraits: Array=[]
var creation_available_portraits: Dictionary={}
var portrait_error:=""
var skill_summary_mask:=0
const SkillRules=preload("res://systems/native_data/creation_skill_rules.gd")
var creation_skill_points: Variant=null
var skill_points_snapshot: Dictionary={}
const Vitals=preload("res://systems/native_data/creation_vitals.gd")
var creation_base_hp: Variant=null
var creation_spell_slots: Dictionary={}
var creation_spell_selection: Dictionary={}
var creation_spell_text
var creation_point_budget: Variant=null
var creation_class_points: Variant=null
var ability_points_snapshot: Dictionary={}
const AbilityRules=preload("res://systems/native_data/creation_ability_rules.gd")
const ClassRules=preload("res://systems/native_data/creation_class_rules.gd")
const SkillSummary=preload("res://systems/native_data/creation_skill_summary.gd")
func commit_skill_summary() -> bool:
	var values:=SkillSummary.calculate(SkillSummary.source(self),tables)
	if not values.ready: return false
	skill_summary_mask=int(values.mask); return true
func rows(name: String) -> Array: return tables.get(name.to_lower(),{}).get("orderedRows",[])
func row(name: String,id: int) -> Dictionary:
	var list:=rows(name); return list[id] if id>=0 and id<list.size() else {}
func cell(data: Dictionary,key: String,default: Variant=null) -> Variant:
	for column in data:
		if str(column).to_lower()==key.to_lower():return data[column]
	return default
func num(data: Dictionary,key: String,default: int=0) -> int:
	var value: Variant=cell(data,key)
	if value==null or value is String and value in ["","****"]:return default
	if value is bool:return 1 if value else 0
	if value is int:return value
	if value is float:return int(value) if is_finite(value) and value==floorf(value) and value>=-9223372036854775808.0 and value<9223372036854775808.0 else default
	if not value is String:return default
	var source: String=value.strip_edges()
	# JavaScript Number accepts surrounding whitespace and integral decimal
	# spellings such as 1.0 or 1e2, which String.to_int discards or truncates.
	if source.is_empty():return 0
	if source.begins_with("0x") or source.begins_with("0X"):
		return source.hex_to_int() if source.is_valid_hex_number(true) else default
	if source.is_valid_float():
		var parsed: float=float(source)
		if is_finite(parsed) and parsed==floorf(parsed) and parsed>=-9223372036854775808.0 and parsed<9223372036854775808.0:return int(parsed)
	return default
func source_num(data: Dictionary,key: String,default: int=0) -> float:
	# character_creation.js::num keeps fractional and NaN Number results.
	# Keep the public integer num() for typed packet and BIC fields.
	var value: Variant=cell(data,key)
	if value==null or value is String and value in ["","****"]:return float(default)
	return ClassRules.js_number(value)
func source_truthy(value: float) -> bool:
	return not is_nan(value) and value!=0.0
func source_age_value(value: float)->Variant:
	# The source draft stores Number(...) until validation. Preserve invalid
	# fractional/NaN values while keeping valid integer ages typed for the BIC.
	return int(value) if is_finite(value) and floorf(value)==value and value>=-2147483648.0 and value<=2147483647.0 else value
func source_age(data: Dictionary)->Variant:return source_age_value(source_num(data,"AGE",18))
func input_age(value: Variant)->Variant:return source_age_value(ClassRules.js_number(str(value)))
func present(value: Variant) -> bool: return value is String and not value.is_empty() and value!="****"
func cls() -> Dictionary: return row("classes",int(draft.classId))
func race() -> Dictionary: return row("racialtypes",int(draft.raceId))
func class_rows(field: String) -> Array: return rows(str(cell(cls(),field,"")))
func first(field: String) -> Dictionary:
	var list:=class_rows(field); return list[0] if not list.is_empty() else {}
func cfg(key: String,default: int) -> int:
	return preload("res://systems/native_data/character_record_values.gd").cfg(tables,"CHARGEN_"+key,default)
func alignment(index: int) -> Dictionary: return {"goodEvil":[85,50,15][index/3],"lawChaos":[85,50,15][index%3]}
func alignment_allowed(data: Dictionary,ge: int,lc: int) -> bool:
	return preload("res://systems/native_data/alignment_rules.gd").allowed_scores(data,ge,lc)
func class_requirement(id: int) -> String:
	return ClassRules.requirement(self,id)
func packages() -> Array:
	var result: Array=[]
	for id in rows("packages").size():
		var data:=row("packages",id)
		if source_num(data,"ClassID",-1)==float(draft.classId) and source_truthy(source_num(data,"PlayerClass")): result.append(id)
	return result
func default_package() -> int:
	var options:=packages(); var configured:=num(cls(),"Package",-1); return configured if options.has(configured) else int(options[0]) if not options.is_empty() else -1
func initialize() -> void:
	creation_skill_points=null;skill_points_snapshot={}
	creation_base_hp=null
	creation_spell_slots={}
	creation_spell_selection={};creation_spell_text=null
	creation_point_budget=null
	creation_class_points=null
	ability_points_snapshot={}
	draft={"gender":0,"raceId":-1,"classId":-1,"goodEvil":50,"lawChaos":50,"abilities":{},"skills":{},"feats":[],"known":{},"memorized":{},"domains":[],"school":0,"packageId":-1,"firstName":"","lastName":"","subrace":"","deity":"","biography":"","age":18,"phenotype":0,"head":1,"clothes":0,"skin":0,"hair":0,"tattoo1":0,"tattoo2":0,"portrait":"","soundset":0,"familiar":0,"familiarName":"","companion":0,"companionName":""}
	for id in rows("racialtypes").size():
		var player_race:=source_num(row("racialtypes",id),"PlayerRace")
		# JS uses num(row, "PlayerRace") !== 0 here; NaN is also !== 0.
		if is_nan(player_race) or player_race!=0.0: draft.raceId=id; break
	for id in rows("classes").size():
		if class_requirement(id).is_empty(): draft.classId=id; break
	select_class(int(draft.classId)); draft.age=source_age(race())
	# The old initial draft starts at the base minimum. Class selection later
	# applies its primary-score threshold adjustment.
	for key in ABILITIES:draft.abilities[key]=cfg("BASE_ABILITY_MIN",8)
	creation_point_budget=null;creation_class_points=null;ability_points_snapshot={}
func reset_choices() -> void:
	# CG_MAIN 1407edcc0 clears selected skills/feats/spells and both domains.
	# Granted racial/class feats and budgets are derived from the active rules.
	# School, appearance, names and associate choices are not part of this reset.
	draft.skills={}; draft.feats=[]; draft.known={}; draft.memorized={}; draft.domains=[]
	draft.erase("sourceFeatChoices")
	draft.erase("sourceAutomaticFeats")
	draft.erase("sourceAutomaticSpells")
	draft.erase("sourceSpellSlots");creation_spell_slots={}
	draft.erase("sourceSpellChoices");creation_spell_selection={};creation_spell_text=null
	if draft.has("packageEquipment"):draft.packageEquipment=[]
	skill_summary_mask=0
	creation_skill_points=null;skill_points_snapshot={}
func reset_js_choices() -> void:
	draft.skills={};draft.feats=[];draft.known={};draft.memorized={}
	for field in ["sourceFeatChoices","sourceAutomaticFeats","sourceAutomaticSpells","sourceSpellSlots","sourceSpellChoices"]:draft.erase(field)
	creation_spell_slots={};creation_spell_selection={};creation_spell_text=null
	creation_skill_points=null;skill_points_snapshot={}
func source_skill_budget(dexterity_adjustment: int=0) -> Variant:
	var values:=Vitals.effective({"classId":int(draft.classId),"race":int(draft.raceId),"abilities":draft.abilities},tables)
	return SkillRules.budget(tables,int(draft.classId),int(draft.raceId),values.scores,dexterity_adjustment) if values.ready else null
func record_skill_points(points: int) -> void:creation_skill_points=SkillRules.word(points);skill_points_snapshot=draft.skills.duplicate()
func reset_source_choices() -> bool:
	reset_choices();var points: Variant=source_skill_budget()
	if points==null:return false
	record_skill_points(int(points));return true
func change_skill(id: int,direction: int,baseline: int=0) -> bool:
	var result:=SkillRules.move(tables,int(draft.classId),id,int(draft.skills.get(id,0)),skill_balance(),baseline,direction)
	if result.changed:
		draft.skills[id]=int(result.rank);record_skill_points(int(result.points))
	return result.changed
func select_race(id: int,_text_owner,subrace_value: Variant=null) -> bool:
	if id<0 or id>=rows("racialtypes").size() or not source_truthy(source_num(row("racialtypes",id),"PlayerRace")):return false
	if subrace_value is String:draft.subrace=subrace_value
	draft.raceId=id;draft.age=source_age(race());draft.appearanceType=num(race(),"Appearance")&65535
	creation_point_budget=num(race(),"AbilitiesPointBuyNumber",30)&255
	initialize_abilities();reset_js_choices()
	var choices:=heads();draft.head=int(choices[0]) if not choices.is_empty() else 1
	return true
func select_class(id: int) -> void:
	var previous:=int(draft.classId); var owned:=granted_feats()
	for choice in draft.feats: owned.append(int(choice.id))
	if previous!=id or creation_base_hp==null or int(creation_base_hp)==0: creation_base_hp=Vitals.starting_hitdie(id,owned,tables)
	draft.classId=id; draft.packageId=default_package(); reset_js_choices(); initialize_abilities()
	for index in 9:
		var a:=alignment(index)
		if alignment_allowed(cls(),a.goodEvil,a.lawChaos): draft.goodEvil=a.goodEvil; draft.lawChaos=a.lawChaos; break
func commit_class(id: int) -> bool:
	# Original Class OK creation branch. Package/reset gates belong to CG_MAIN,
	# not this modal. Same-class OK still resets allocation and default alignment.
	if not class_requirement(id).is_empty():return false
	var initial:=Vitals.initial_abilities(id,int(draft.raceId),tables)
	if not initial.ready:return false
	var owned:=granted_feats()
	for choice in draft.feats:owned.append(int(choice.id))
	if int(draft.classId)!=id or creation_base_hp==null or int(creation_base_hp)==0:creation_base_hp=Vitals.starting_hitdie(id,owned,tables)
	if creation_base_hp==null:return false
	draft.classId=id;draft.abilities=initial.abilities;creation_point_budget=num(race(),"AbilitiesPointBuyNumber",30)&255;creation_class_points=creation_point_budget
	var key:=primary()
	if num(cls(),"SpellCaster")!=0 and not key.is_empty():
		var values:=Vitals.effective({"classId":id,"race":int(draft.raceId),"abilities":draft.abilities},tables)
		var adjustment:=preload("res://systems/native_data/character_record_values.gd").signed8(num(race(),key+"Adjust"))+int(values.gains[ABILITIES.find(key)])
		creation_class_points=(int(creation_point_budget)+cfg("BASE_ABILITY_MIN",8)-cfg("BASE_ABILITY_MIN_PRIMARY",11)+adjustment)&255
	# The first-level creator's raw draft uses creationAbilities Number math.
	# Keep the native point/cache calculation above at its original byte boundary.
	source_initial_abilities()
	for index in ALIGNMENTS.size():
		var candidate:=alignment(index)
		if alignment_allowed(cls(),int(candidate.goodEvil),int(candidate.lawChaos)):
			draft.goodEvil=int(candidate.goodEvil);draft.lawChaos=int(candidate.lawChaos);break
	record_ability_points(int(creation_class_points))
	return true
func abilities() -> Dictionary:
	var result: Dictionary={}
	for key in ABILITIES:
		# character_creation.js::creationAbilities adds JS Number results, not
		# integer 2DA cells. Keep invalid/fractional totals in the creator's
		# draft and visible projection; BIC ability fields narrow to BYTE later.
		var score: float=float(draft.abilities.get(key,cfg("BASE_ABILITY_MIN",8)))+source_num(race(),key+"Adjust")+source_num(first("StatGainTable"),key)
		result[key]=int(score) if is_finite(score) and score==floorf(score) and score>=-9223372036854775808.0 and score<9223372036854775808.0 else score
	return result
func typed_ability_score(score: Variant) -> int:
	# combat_stats.js::abilityModifier and the BIC-facing BYTE projections use
	# ToInt32 before masking. Truncate the finite Number, then wrap its low bits.
	var value:=float(score)
	if not is_finite(value):return 0
	var truncated:=floorf(value) if value>=0.0 else ceilf(value)
	var bits:=int(fposmod(truncated,4294967296.0))
	return bits-4294967296 if bits>=2147483648 else bits
static func source_number_text(value: Variant) -> String:
	if value is float:
		if is_nan(value):return "NaN"
		if is_inf(value):return "Infinity" if value>0 else "-Infinity"
	return str(value)
func primary() -> String:
	for key in ABILITIES:
		if str(cell(cls(),"SpellcastingAbil","")).to_upper()==key.to_upper(): return key
	return ""
func source_initial_abilities() -> void:
	var minimum:=cfg("BASE_ABILITY_MIN",8)
	for key in ABILITIES:draft.abilities[key]=minimum
	var key:=primary()
	if num(cls(),"SpellCaster")==0 or key.is_empty():return
	var delta:=float(cfg("BASE_ABILITY_MIN_PRIMARY",11))-float(abilities()[key])
	var result:=float(minimum)+(NAN if is_nan(delta) else maxf(0.0,delta))
	draft.abilities[key]=int(result) if is_finite(result) and result==floorf(result) and result>=-9223372036854775808.0 and result<9223372036854775808.0 else result
func initialize_abilities() -> void:
	var initial:=Vitals.initial_abilities(int(draft.classId),int(draft.raceId),tables)
	if initial.ready:
		draft.abilities=initial.abilities
		var points:=num(race(),"AbilitiesPointBuyNumber",30)&255;var key:=primary()
		if num(cls(),"SpellCaster")!=0 and not key.is_empty():
			var values:=Vitals.effective({"classId":int(draft.classId),"race":int(draft.raceId),"abilities":draft.abilities},tables)
			points=(points+cfg("BASE_ABILITY_MIN",8)-cfg("BASE_ABILITY_MIN_PRIMARY",11)+preload("res://systems/native_data/character_record_values.gd").signed8(num(race(),key+"Adjust"))+int(values.gains[ABILITIES.find(key)]))&255
		source_initial_abilities();record_ability_points(points);return
	source_initial_abilities()
func point_cost(score: Variant) -> float:
	if not (score is int or score is float) or not is_finite(float(score)) or float(score)!=floorf(float(score)) or float(score)<cfg("BASE_ABILITY_MIN",8) or float(score)>cfg("BASE_ABILITY_MAX",18): return INF
	var cost:=0
	for value in range(cfg("BASE_ABILITY_MIN",8)+1,int(score)+1): cost+=4 if value>cfg("ABILITY_COST_INCREMENT4",255) else 3 if value>cfg("ABILITY_COST_INCREMENT3",16) else 2 if value>cfg("ABILITY_COST_INCREMENT2",14) else 1
	return float(cost)
func point_balance() -> float:
	var result: float=float(num(race(),"AbilitiesPointBuyNumber",30))
	for key in ABILITIES: result-=point_cost(draft.abilities[key])
	return result
func record_ability_points(points: int) -> void:creation_class_points=points&255;ability_points_snapshot=draft.abilities.duplicate()
func change_ability(index: int,direction: int) -> bool:
	if index<0 or index>=6 or direction not in [-1,1]:return false
	var values:=Vitals.effective({"classId":int(draft.classId),"race":int(draft.raceId),"abilities":draft.abilities},tables)
	var points:=point_balance()
	if not values.ready or points<0 or points>255:return false
	var key: String=ABILITIES[index];var result:=AbilityRules.move(tables,cls(),index,int(draft.abilities[key]),int(values.scores[index]),int(points),direction)
	if result.changed:draft.abilities[key]=result.value;record_ability_points(int(result.points))
	return result.changed
func recommend_abilities() -> void:
	var ordered: Array=ABILITIES.duplicate()
	ordered.sort_custom(func(a,b):return num(cls(),a)>num(cls(),b) if num(cls(),a)!=num(cls(),b) else ABILITIES.find(a)<ABILITIES.find(b))
	for key in ABILITIES:draft.abilities[key]=cfg("BASE_ABILITY_MIN",8)
	while true:
		var changed:=false
		for key in ordered:
			var score:=int(draft.abilities[key]);var delta:=point_cost(score+1)-point_cost(score)
			if score<num(cls(),key,cfg("BASE_ABILITY_MIN",8)) and delta<=point_balance():draft.abilities[key]=score+1;changed=true
		if not changed:break
	while true:
		var changed:=false
		for key in ordered:
			var score:=int(draft.abilities[key])
			if point_cost(score+1)-point_cost(score)<=point_balance():draft.abilities[key]=score+1;changed=true;break
		if not changed:break
	record_ability_points(int(point_balance()))
func can_decrease(key: String) -> bool: return float(draft.abilities[key])>cfg("BASE_ABILITY_MIN",8) and (num(cls(),"SpellCaster")==0 or primary()!=key or float(abilities()[key])>cfg("BASE_ABILITY_MIN_PRIMARY",11))
func modifier(score: int) -> Variant: return preload("res://systems/native_data/character_record_values.gd").modifier(score,tables)
func skill_budget() -> int:
	var ability:=str(cell(race(),"SkillPointModifierAbility","")); var key:=""
	for candidate in ABILITIES:
		if candidate.to_upper()==ability.to_upper(): key=candidate
	if key.is_empty() and ability.is_valid_int() and int(ability)>=0 and int(ability)<6: key=ABILITIES[int(ability)]
	var value: Variant=modifier(typed_ability_score(abilities()[key]) if not key.is_empty() else cfg("ABILITY_NEUTRAL_VALUE",10))
	if value==null:return 0
	return (maxi(1,num(cls(),"SkillPointBase")+int(value))+num(race(),"ExtraSkillPointsPerLevel"))*num(race(),"FirstLevelSkillPointsMultiplier",4)
func skill_rule(id: int) -> Dictionary:
	var entry: Dictionary={}
	for data in class_rows("SkillsTable"):
		if source_num(data,"SkillIndex",-1)==float(id): entry=data; break
	var class_skill:=num(entry,"ClassSkill")!=0
	return {"allowed":not row("skills",id).is_empty() and (num(row("skills",id),"AllClassesCanUse")!=0 or not entry.is_empty()),"classSkill":class_skill,"cost":1 if class_skill else 2,"max":floori((1+cfg("SKILL_MAX_LEVEL_1_BONUS",3))/(1.0 if class_skill else 2.0))}
func skill_balance() -> int:
	var result:=skill_budget()
	for id in draft.skills: result-=int(draft.skills[id])*int(skill_rule(int(id)).cost)
	return result
func granted_feats() -> Array:
	var result: Array=[]; var candidates: Array=[]
	for data in rows(str(cell(race(),"FeatsTable",""))): candidates.append(source_num(data,"FeatIndex",-1))
	for data in class_rows("FeatsTable"):
		if source_num(data,"List",-1)==3.0 and source_num(data,"GrantedOnLevel",-1)==1.0: candidates.append(source_num(data,"FeatIndex",-1))
	if num(cls(),"PickDomains")!=0:
		for id in draft.domains: candidates.append(num(row("domains",int(id)),"GrantedFeat",-1))
	for id in candidates:
		# JS at(table,id) has no fractional, NaN or infinite array index.
		if is_finite(float(id)) and float(id)>=0.0 and floorf(float(id))==float(id) and float(id)<float(rows("feat").size()) and present(cell(row("feat",int(id)),"FEAT")) and not result.has(int(id)): result.append(int(id))
	return result
func feat_slots() -> Dictionary:return {"normal":num(race(),"NumberNormalFeatsEveryNthLevel",1)+num(race(),"ExtraFeatsAtFirstLevel"),"bonus":num(first("BonusFeatsTable"),"Bonus")}
func feat_allowed(id: int,kind: String) -> bool:
	var feat:=row("feat",id); var list:=-1.0
	if not present(cell(feat,"FEAT")): return false
	for data in class_rows("FeatsTable"):
		if source_num(data,"FeatIndex",-1)==float(id): list=source_num(data,"List",-1); break
	return list in [1.0,2.0] if kind=="bonus" else list in [0.0,1.0] or source_truthy(source_num(feat,"AllClassesCanUse")) and list!=2.0
func feat_requirement(id: int,owned: Array) -> String:
	var feat:=row("feat",id); var scores:=abilities()
	if not present(cell(feat,"FEAT")): return "Invalid feat"
	if owned.has(id) and num(feat,"GainMultiple")==0: return "Already acquired"
	for key in ABILITIES:
		var minimum:=num(feat,"MIN"+key.to_upper())
		if float(scores[key])<minimum: return key+" "+str(minimum)+" required"
	var minimum_attack:=num(feat,"MINATTACKBONUS")
	if num(first("AttackBonusTable"),"BAB")<minimum_attack: return "Base attack "+str(minimum_attack)+" required"
	if num(feat,"MinLevel")>1 or num(feat,"MaxLevel")>0 and num(feat,"MaxLevel")<1: return "Level requirement"
	if num(feat,"MinLevel")>0 and num(feat,"MinLevelClass",255)!=255 and num(feat,"MinLevelClass")!=int(draft.classId): return "Class requirement"
	var fort_modifier: Variant=modifier(typed_ability_score(scores.Con))
	if fort_modifier==null:return "Ability modifier rules cause a native integer division fault"
	if num(first("SavingThrowTable"),"FortSave")+int(fort_modifier)<num(feat,"MinFortSave"): return "Fortitude requirement"
	if num(feat,"PreReqEpic")!=0 and not owned.has(1001): return "Epic character required"
	for key in ["PREREQFEAT1","PREREQFEAT2"]:
		var required:=num(feat,key,-1)
		if required>=0 and required!=65535 and not owned.has(required): return "Feat "+str(required)+" required"
	var alternatives: Array=[]
	for index in 5:
		var required:=source_num(feat,"OrReqFeat"+str(index),-1)
		if required>=0.0 and required!=65535.0: alternatives.append(required)
	if not alternatives.is_empty() and not alternatives.any(func(required):return owned.has(required)): return "Prerequisite feat required"
	for suffix in ["","2"]:
		var skill:=num(feat,"REQSKILL"+suffix,-1)
		if skill>=0 and skill!=65535 and (not skill_rule(skill).allowed or int(draft.skills.get(skill,0))<num(feat,"ReqSkillMinRanks"+suffix)): return "Skill ranks required"
	var level:=num(feat,"MINSPELLLVL"); var key:=""
	for candidate in ABILITIES:
		if candidate.to_upper()==str(cell(cls(),"SpellcastingAbil","")):key=candidate;break
	if level>0 and (num(cls(),"SpellCaster")==0 or key.is_empty() or float(scores[key])<10+level or num(first("SpellGainTable"),"SpellLevel"+str(level),-1)<0): return "Spellcasting level required"
	return ""
func spell_options(level: int) -> Array:
	var result: Array=[]; var column:=str(cell(cls(),"SpellTableColumn",""))
	var opposition_raw: Variant=cell(row("spellschools",int(draft.school)),"Opposition")
	var opposition: float=ClassRules.js_number(opposition_raw) if present(opposition_raw) else NAN
	var opposed: Variant=cell(row("spellschools",int(opposition)),"Letter") if is_finite(opposition) and opposition>=0.0 and floorf(opposition)==opposition and opposition<float(rows("spellschools").size()) else null
	if not source_truthy(source_num(cls(),"SpellCaster")) or not present(column): return result
	for id in rows("spells").size():
		var data:=row("spells",id)
		if source_num(data,column,255)==float(level) and present(cell(data,"Name")) and source_num(data,"UserType",1)==1.0 and (not present(cell(data,"Master")) or source_num(data,"Master",-1)==float(id)) and (not source_truthy(source_num(cls(),"PickSchool")) or not present(opposed) or cell(data,"School")!=opposed): result.append(id)
	return result
func spell_count(level: int) -> int:
	if num(cls(),"SpellCaster")==0 or num(cls(),"SkipSpellSelection")!=0 or num(cls(),"SpellbookRestricted")==0 or level>=num(first("SpellGainTable"),"NumSpellLevels"): return 0
	if num(cls(),"LearnScroll")!=0:
		if level==0:return spell_options(0).size()
		if level==1:
			var value: Variant=modifier(typed_ability_score(abilities().Int))
			return 3+maxi(0,int(value)) if value!=null else 0
		return 0
	return num(first("SpellKnownTable"),"SpellLevel"+str(level))
func spell_slots(level: int,use_source_cache: bool=true) -> int:
	if use_source_cache and draft.get("sourceSpellSlots",false):return int(creation_spell_slots.get(level,0))
	# character_creation.js:creationSpellSlots passes a single first-level class
	# into spell_book.js:spellGainWithBonus. There are no rival classes in that
	# provider, so its prestige loop contributes zero.
	level&=255
	var key:=primary()
	if num(cls(),"SpellCaster")==0 or key.is_empty():return 0
	var score:=typed_ability_score(abilities()[key])&255
	if score<level-1+cfg("BASE_ABILITY_MIN_PRIMARY",11):return 0
	var gain:=first("SpellGainTable"); var count:=num(gain,"SpellLevel"+str(level),255) if level<num(gain,"NumSpellLevels") else 255
	if count==255: return 0
	var value: Variant=modifier(typed_ability_score(abilities()[key]))
	if value==null:return 0
	var cached_modifier:=int(value)&255
	var bonus:=cached_modifier-256 if cached_modifier>=128 else cached_modifier
	count+=int((bonus-level+4)/4.0) if level!=0 and bonus>0 and bonus>=level else 0
	if level!=0 and num(cls(),"PickSchool")!=0 and int(draft.school)!=0: count+=1
	return count&255
func prepared_options(level: int,domain: bool=false) -> Array:
	var result: Array=[]
	if domain:
		for id in draft.domains:
			var spell:=source_num(row("domains",int(id)),"Level_"+str(level),-1)
			if is_finite(spell) and spell>=0.0 and floorf(spell)==spell and spell<float(rows("spells").size()) and not row("spells",int(spell)).is_empty() and not result.has(int(spell)): result.append(int(spell))
	else:
		for id in spell_options(level):
			if num(cls(),"SpellbookRestricted")==0 or draft.known.get(level,[]).has(id): result.append(id)
	return result
func portraits() -> Array:
	if not portrait_prepared and not prepare_portraits().is_empty():return []
	var key:=str(draft.gender)+":"+str(draft.raceId)
	if portrait_cache.has(key): return portrait_cache[key]
	var result: Array=preload("res://systems/native_data/portrait_choices.gd").ordered(rows("portraits"),int(draft.gender),int(draft.raceId),portrait_resource_exists,custom_portraits,cfg("ALLOW_CUSTOM_PORTRAITS",1)!=0,true).filter(func(base):return creation_available_portraits.has(base))
	portrait_cache[key]=result; return result
func prepare_portraits() -> String:
	if portrait_prepared:return portrait_error
	portrait_prepared=true
	if catalog==null or not catalog.has_method("has_resource"):
		portrait_error="Character creation portrait catalog is unavailable";return portrait_error
	var source_names: Array=[]
	if catalog.has_method("creation_portrait_names"):source_names=catalog.creation_portrait_names()
	elif catalog.has_method("portrait_files"):
		for file in catalog.portrait_files():source_names.append(str(file).get_basename())
	var choices=preload("res://systems/native_data/portrait_choices.gd")
	custom_portraits=choices.custom_creation_portraits(source_names)
	var refs: Array=[];var seen: Dictionary={}
	for data in rows("portraits"):
		var value: Variant=cell(data,"BaseResRef")
		if value==null or str(value) in ["","****"]:continue
		var ref:=("po_"+str(value)).to_lower()
		if not seen.has(ref):seen[ref]=true;refs.append(ref)
	for ref in custom_portraits:
		if not seen.has(ref):seen[ref]=true;refs.append(ref)
	var result: Dictionary=choices.available_creation_portraits(refs,portrait_resource_exists)
	if not result.get("ready",false):portrait_error=str(result.get("error","Character creation portrait catalog is unavailable"));return portrait_error
	creation_available_portraits.clear()
	for ref in result.available:creation_available_portraits[str(ref)]=true
	return ""
func portrait_resource_exists(name: String,type: int) -> bool: return catalog==null or catalog.has_resource(name,type)
func portrait_available(base: String) -> bool:
	return preload("res://systems/native_data/portrait_resources.gd").available(base,portrait_resource_exists)
func voices() -> Array:
	var result: Array=[]
	for id in rows("soundset").size():
		if source_num(row("soundset",id),"TYPE",-1)==0.0 and source_num(row("soundset",id),"GENDER",-1)==float(draft.gender): result.append(id)
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
		var id:=source_num(data,column,-1)
		if id>=0 and not result.has(id): result.append(id)
	return result
func recommend() -> String:
	creation_skill_points=null;skill_points_snapshot={}
	draft.packageSource=false
	if not packages().has(int(draft.packageId)): draft.packageId=default_package()
	if int(draft.packageId)<0: return "No selectable starting package is available for this class."
	var package:=row("packages",int(draft.packageId)); var ordered: Array=ABILITIES.duplicate()
	ordered.sort_custom(func(a,b):
		var left:=source_num(cls(),a); var right:=source_num(cls(),b)
		return ABILITIES.find(a)<ABILITIES.find(b) if is_nan(left) or is_nan(right) or left==right else left>right)
	for key in ABILITIES: draft.abilities[key]=cfg("BASE_ABILITY_MIN",8)
	while true:
		var changed:=false
		for key in ordered:
			var score:=int(draft.abilities[key]); var delta:=point_cost(score+1)-point_cost(score)
			if float(score)<source_num(cls(),key,cfg("BASE_ABILITY_MIN",8)) and delta<=point_balance(): draft.abilities[key]=score+1; changed=true
		if not changed: break
	while true:
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
		# JS array lookup with a fractional or infinite Number has no skill row.
		if not is_finite(float(id)) or floorf(float(id))!=float(id) or float(id)>=float(rows("skills").size()):continue
		var skill_id:=int(id);var rule:=skill_rule(skill_id)
		if rule.allowed and num(row("skills",skill_id),"HideFromLevelUp")==0: draft.skills[skill_id]=mini(int(rule.max),floori(skill_balance()/float(rule.cost)))
	var feats:=preference("FeatPref2DA","FeatIndex")
	for id in rows("feat").size():
		if not feats.has(id): feats.append(id)
	draft.feats=[]; var slots:=feat_slots()
	for kind in ["bonus","normal"]:
		for slot in int(slots[kind]):
			var owned:=granted_feats()
			for choice in draft.feats: owned.append(choice.id)
			for id in feats:
				# A non-index Number cannot resolve a feat row in the old array.
				if not is_finite(float(id)) or floorf(float(id))!=float(id) or float(id)>=float(rows("feat").size()):continue
				var feat_id:=int(id)
				if feat_allowed(feat_id,kind) and feat_requirement(feat_id,owned).is_empty(): draft.feats.append({"id":feat_id,"kind":kind}); break
	var spells:=preference("SpellPref2DA","SpellIndex"); draft.known={}; draft.memorized={}
	for level in 10:
		var options:=spell_options(level); var order: Array=[]
		for id in spells+options:
			if options.has(id) and not order.has(id): order.append(id)
		draft.known[level]=order.slice(0,spell_count(level))
		if num(cls(),"MemorizesSpells")==0: continue
		draft.memorized[level]=[]
		for slot in spell_slots(level):
			options=prepared_options(level,source_truthy(source_num(cls(),"PickDomains")) and level>0 and slot==spell_slots(level)-1); order=[]
			for id in spells+options:
				if options.has(id) and not order.has(id): order.append(id)
			draft.memorized[level].append(order[slot%order.size()] if not order.is_empty() else null)
	var images:=portraits(); draft.portrait=images[0] if not images.is_empty() else ""
	var voices_list:=voices(); draft.soundset=int(voices_list[0]) if not voices_list.is_empty() else 0
	var head_list:=heads(); draft.head=int(head_list[0]) if not head_list.is_empty() else 1
	var clothing:=clothes(); draft.clothes=int(clothing[0]) if not clothing.is_empty() else 0
	draft.familiar=num(package,"Associate"); draft.companion=num(package,"Associate")
	if str(draft.familiarName).is_empty():draft.familiarName="Familiar"
	if str(draft.companionName).is_empty():draft.companionName="Companion"
	commit_skill_summary()
	return ""
func errors() -> Array:
	var result: Array=[]; var class_error:=class_requirement(int(draft.classId)); var scores:=abilities()
	if modifier(10)==null:result.append("Ability modifier rules cause a native integer division fault")
	if not source_truthy(source_num(race(),"PlayerRace")): result.append("Select a playable race")
	if not class_error.is_empty(): result.append(class_error)
	if num(cls(),"SpellCaster")!=0 and not present(cell(cls(),"SpellTableColumn")):result.append("Casting class has no spell table column")
	var listed_alignment:=false
	for index in ALIGNMENTS.size():
		var choice:=alignment(index)
		if int(draft.goodEvil)==int(choice.goodEvil) and int(draft.lawChaos)==int(choice.lawChaos):listed_alignment=true;break
	if not listed_alignment or not alignment_allowed(cls(),int(draft.goodEvil),int(draft.lawChaos)): result.append("Alignment is not allowed for this class")
	if point_balance()!=0: result.append("Spend all ability points")
	if num(cls(),"SpellCaster")!=0 and not primary().is_empty() and float(scores.get(primary(),0))<cfg("BASE_ABILITY_MIN_PRIMARY",11): result.append(primary()+" must be at least "+str(cfg("BASE_ABILITY_MIN_PRIMARY",11)))
	if skill_balance()<0: result.append("Too many skill points spent")
	for id in draft.skills:
		var rule:=skill_rule(int(id)); var rank:=int(draft.skills[id])
		if not draft.skills[id] is int or rank<0 or rank>int(rule.max) or rank>0 and not rule.allowed: result.append("Invalid skill "+str(id)+" ranks")
	var counts:={"bonus":0,"normal":0}; var owned:=granted_feats()
	if draft.get("sourceFeatChoices",false) and draft.has("sourceAutomaticFeats"):result.append("Conflicting native feat selection receipts.")
	if draft.get("sourceFeatChoices",false):
		var selected: Array=draft.feats.map(func(choice):return int(choice.id))
		var validity: Dictionary=preload("res://systems/native_data/creation_feat_snapshot.gd").validate_choices(self,selected)
		if not validity.get("ready",false) or not validity.get("valid",false):result.append(str(validity.get("reason","Active feat choices are unavailable.")))
		owned.append_array(selected)
	elif draft.has("sourceAutomaticFeats"):
		var validity:=preload("res://systems/native_data/creation_feat_automatic.gd").verify(self,draft.sourceAutomaticFeats)
		if not validity.get("ready",false) or not validity.get("valid",false):result.append(str(validity.get("reason","The accepted automatic feat choices are unavailable.")))
		if validity.get("ready",false) and validity.get("valid",false):owned.append_array(validity.selected)
	else:
		for choice in draft.feats:
			if not counts.has(choice.kind) or not feat_allowed(int(choice.id),str(choice.kind)): result.append("Invalid feat selection"); continue
			counts[choice.kind]+=1; var reason:=feat_requirement(int(choice.id),owned)
			if not reason.is_empty(): result.append("Feat "+str(choice.id)+": "+reason)
			owned.append(int(choice.id))
		if counts!=feat_slots(): result.append("Select every available feat")
	if num(cls(),"PickDomains")!=0:
		var domains_valid: bool=draft.domains.size()==2 and draft.domains[0]!=draft.domains[1]
		if domains_valid:
			for id in draft.domains:
				if row("domains",int(id)).is_empty():domains_valid=false;break
		if not domains_valid:result.append("Choose two different domains")
	if num(cls(),"PickSchool")!=0 and row("spellschools",int(draft.school)).is_empty():result.append("Choose a spell school")
	if draft.get("sourceSpellChoices",false) and draft.has("sourceAutomaticSpells"):result.append("Conflicting native spell selection receipts.")
	if draft.get("sourceSpellChoices",false):
		var validity:=preload("res://systems/native_data/creation_spells_validation.gd").verify(self,creation_spell_text,creation_spell_selection)
		if not validity.get("ready",false) or not validity.get("valid",false):result.append(str(validity.get("reason","Active native spell choices are unavailable.")))
	elif draft.has("sourceAutomaticSpells"):
		var validity:=preload("res://systems/native_data/creation_spell_automatic.gd").verify(self,draft.sourceAutomaticSpells)
		if not validity.get("ready",false) or not validity.get("valid",false):result.append(str(validity.get("reason","The accepted automatic spell choices are unavailable.")))
	else:
		for level in 10:
			var selected: Array=draft.known.get(level,[]); var allowed:=spell_options(level); var seen: Dictionary={}
			if selected.size()!=spell_count(level): result.append("Choose "+str(spell_count(level))+" valid level "+str(level)+" spells")
			for id in selected:
				if not allowed.has(id) or seen.has(id): result.append("Choose "+str(spell_count(level))+" valid level "+str(level)+" spells")
				seen[id]=true
			var prepared: Array=draft.memorized.get(level,[]); var slots:=spell_slots(level)
			if prepared.size()>slots: result.append("Invalid prepared spell slots")
			for index in prepared.size():
				if prepared[index]!=null and not prepared_options(level,num(cls(),"PickDomains")!=0 and level>0 and index==slots-1).has(prepared[index]): result.append("Invalid prepared level "+str(level)+" spell")
		for key in draft.memorized:
			var level:=int(key);var prepared: Variant=draft.memorized[key]
			if num(cls(),"MemorizesSpells")==0 or level<0 or level>9 or not prepared is Array or prepared.size()>spell_slots(level):result.append("Invalid prepared spell slots")
	if str(draft.firstName).strip_edges().is_empty(): result.append("Enter a first name")
	var writer:=Writer.new()
	for key in ["firstName","lastName","subrace","deity","biography","familiarName","companionName"]:
		var bytes:=writer.text(str(draft[key]))
		if not writer.failure.is_empty(): result.append(writer.failure)
		elif key!="biography" and bytes.size()>32: result.append(key+" is too long")
	if not draft.age is int or int(draft.age)<1 or int(draft.age)>2147483647: result.append("Enter a valid age")
	if not portraits().has(draft.portrait): result.append("Choose a portrait")
	if not voices().has(draft.soundset): result.append("Choose a voice")
	if not phenotypes().has(draft.phenotype): result.append("Choose a body type")
	if not heads().has(draft.head): result.append("Choose an available head")
	if not clothes().has(draft.clothes): result.append("Choose available clothing")
	for key in ["skin","hair","tattoo1","tattoo2"]:
		if not draft[key] is int or int(draft[key])<0 or int(draft[key])>=mini(256,int(palette_sizes.get(key,176))): result.append("Invalid "+key+" colour")
	if not packages().has(draft.packageId): result.append("Choose a class package")
	if draft.get("packageSource",false):
		var associate:=preload("res://systems/native_data/creation_associate_validation.gd").verify(self)
		if not associate.ready:result.append(associate.reason)
	else:
		for spec in [[303,"hen_familiar","familiar"],[199,"hen_companion","companion"]]:
			if owned.has(spec[0]) and (row(spec[1],int(draft[spec[2]])).is_empty() or str(draft[spec[2]+"Name"]).strip_edges().is_empty()): result.append("Choose and name a familiar" if spec[0]==303 else "Choose and name an animal companion")
	var unique: Array=[]
	for error in result:
		if not unique.has(error):unique.append(error)
	return unique
