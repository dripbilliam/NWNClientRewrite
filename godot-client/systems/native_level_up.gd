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
var source_runtime
var source_configured:=false
var pending_open: Array=[]
var requesting_ticket: Array=[]
var protocol_features: Dictionary={}
var class_publication=preload("res://systems/native_data/level_up_class_publication.gd").new()
const ReplyScope=preload("res://systems/native_data/level_up_reply_scope.gd")
var reply_scope:=ReplyScope.new()
const ABILITIES=["Str","Dex","Con","Int","Wis","Cha"]
const SkillRules=preload("res://systems/native_data/creation_skill_rules.gd")
const FeatSlots=preload("res://systems/native_data/creation_feat_slots.gd")
const NativeRandom=preload("res://systems/native_data/native_client_random.gd")
func configure(owner,view) -> void:
	desktop=owner; ui=view; rules=desktop.rules
	NativeRandom.acquire()
	ui.presentation_reset.connect(retire_source);ui.source_reopen.connect(reopen_source)
func source_identity() -> Array:return [desktop.generation,desktop.area_id,desktop.actor_id]
func source_catalog() -> Object:
	if not is_instance_valid(desktop) or desktop.get("closed")==true:return null
	var owner: Variant=desktop.get("owner_ui")
	if owner is Dictionary:
		var catalog: Variant=owner.get("catalog")
		return catalog if typeof(catalog)==TYPE_OBJECT and is_instance_valid(catalog) else null
	if typeof(owner)==TYPE_OBJECT and is_instance_valid(owner) and owner.get("closed")!=true:
		var catalog: Variant=owner.get("catalog")
		if typeof(catalog)==TYPE_OBJECT and is_instance_valid(catalog):return catalog
	return null
func source_module() -> Dictionary:
	if source_catalog()==null:return {}
	var current_state: Variant=desktop.get("state")
	var module: Variant=current_state.get("module") if current_state is Dictionary else null
	return module if module is Dictionary else {}
func source_actor() -> Dictionary:
	if not is_instance_valid(desktop) or desktop.get("closed")==true or not desktop.has_method("actor"):return {}
	var current: Variant=desktop.actor()
	return current if current is Dictionary else {}
func observe_received() -> void:
	if reply_scope.is_open() and not reply_scope.current(reply_context(),int(ui.request_serial)):
		ui.reset();return
	if is_instance_valid(source_runtime):source_runtime.observe_received()
func reply_context() -> Dictionary:
	var actor:=source_actor()
	if actor.get("id")!=desktop.actor_id or actor.get("areaId")!=desktop.area_id or actor.get("objectType")!=5 or actor.get("replicationRemoved",false)!=false:return {}
	return ReplyScope.context({"generation":desktop.generation,"areaId":desktop.area_id,"actorId":desktop.actor_id,"nativeLifetime":actor.get("nativeLifetime"),"knownLifetime":actor.get("clientKnownLifetime")})
func send_level_request(message: Dictionary) -> bool:
	if not ui.wanted or not reply_scope.current(reply_context(),int(ui.request_serial)):return false
	var issued:=reply_scope.issue(str(message.get("operation","")),int(message.get("token",-1)))
	if not issued.ready:return false
	var outgoing:=message.duplicate(true);outgoing.levelRequest=issued.value
	if outgoing.operation=="begin":present_requesting(issued.value)
	desktop.command(outgoing);return true
func configure_source(painter,base_text,base_catalog,cache_path: String) -> void:
	if source_configured or painter==null or base_text==null or base_catalog==null or desktop.owner_ui.catalog==null:return
	source_runtime=preload("res://systems/native_level_up_runtime.gd").new();ui.add_child(source_runtime)
	source_runtime.configure(painter,base_text,base_catalog,desktop.owner_ui.catalog,cache_path,desktop.owner_ui.modal_order,desktop.owner_ui.modal_surfaces,source_identity,source_catalog,source_module,source_actor)
	source_runtime.watch_tables(desktop.owner_ui.get("assets"))
	source_runtime.command_requested.connect(source_command);source_runtime.fallback_requested.connect(source_fallback);source_runtime.cancelled.connect(ui.reset)
	source_runtime.frontend.cancelled.connect(requesting_cancelled);source_runtime.frontend.unavailable.connect(requesting_unavailable)
	# Prepare only the original Class frame offscreen, before the first click.
	# Choices still require the real server begin result and active rules.
	source_runtime.frontend.ensure_pane("class")
	source_configured=true
func requesting_current(ticket: Array) -> bool:
	return ui.wanted and not requesting_ticket.is_empty() and ticket==requesting_ticket and is_instance_valid(source_runtime) and is_instance_valid(source_runtime.frontend) and source_runtime.frontend.owns(ticket) and reply_scope.current(reply_context(),int(ui.request_serial))
func present_requesting(metadata: Dictionary) -> void:
	if not source_configured or not is_instance_valid(source_runtime) or not is_instance_valid(source_runtime.frontend) or source_runtime.frontend.closed:return
	retire_requesting()
	var front=source_runtime.frontend
	# This is a LOCAL presentation identity, not a fabricated server token.
	var identity: Array=[metadata.owner,metadata.entry,metadata.request,"requesting-begin"]
	front.present_waiting(front.text,desktop.art,identity,"Requesting server level-up choices…")
	requesting_ticket=front.ticket.duplicate();ui.activate_source(true)
	if front.panes.has("class") and not str(front.panes["class"].failure).is_empty():requesting_unavailable("class",str(front.panes["class"].failure),requesting_ticket)
func retire_requesting() -> void:
	var previous:=requesting_ticket.duplicate();requesting_ticket=[]
	if not previous.is_empty() and is_instance_valid(source_runtime) and is_instance_valid(source_runtime.frontend) and source_runtime.frontend.owns(previous):source_runtime.frontend.dismiss()
func requesting_cancelled(ticket: Array) -> void:
	if requesting_current(ticket):input({"kind":"level-cancel"})
func requesting_unavailable(_stage: String,reason: String,ticket: Array) -> void:
	if not requesting_current(ticket):return
	retire_requesting();ui.activate_source(false);status=reason;ui.status.text=reason
func source_command(message: Dictionary,identity: Array) -> void:
	if identity!=source_identity() or not ui.wanted:return
	if send_level_request(message):submitting=message.operation=="submit"
func source_fallback(_result: Dictionary,private_draft: Dictionary,stage: String,reason: String) -> void:
	if not ui.wanted:return
	ui.activate_source(false)
	if draft.is_empty():select_class(initial_class())
	if not private_draft.is_empty():
		var id:=int(private_draft.get("classId",-1))
		if id>=0 and id<available.size() and available[id]:select_class(id)
		for key in ["ability","domains"]:
			if private_draft.has(key):draft[key]=private_draft[key].duplicate(true) if private_draft[key] is Array else private_draft[key]
		if private_draft.get("skills") is Array and private_draft.skills.size()==snapshot.skills.size():draft.skills=private_draft.skills.duplicate()
		if private_draft.get("selectedFeats") is Array:draft.feats=private_draft.selectedFeats.duplicate()
		if int(private_draft.get("school",-1))>=0:draft.school=int(private_draft.school)
		for key in ["known","removed"]:
			if private_draft.get(key) is Dictionary:
				draft[key]={}
				for level in private_draft[key]:draft[key][str(level)]=private_draft[key][level].duplicate()
		for key in ["fieldE34","fieldE48","fieldE30","fieldE38"]:
			if private_draft.get("receivedFields",{}).has(key):draft[key]=private_draft.receivedFields[key]
		step=int({"class":0,"attributes":1,"skills":2,"feats":3,"spells":4,"domains":5,"school":5,"associate":5,"post":5,"summary":6}.get(stage,0))
	status="Using standard level-up controls. "+reason;render()
func retire_source() -> void:
	retire_requesting()
	if is_instance_valid(source_runtime):source_runtime.retire()
	reply_scope.retire()
	snapshot={};available=[];draft={};token=-1;pending_open=[];submitting=false;protocol_features={};class_publication.reset()
func reopen_source() -> void:
	if requesting_current(requesting_ticket):source_runtime.frontend.surface.show();return
	if is_instance_valid(source_runtime):source_runtime.reopen()
func receive_result(message: Dictionary) -> void:
	if not reply_scope.consume(message.get("levelRequest"),reply_context(),int(ui.request_serial),str(message.get("operation",""))):return
	if not message.get("accepted",false):
		submitting=false;status=str(message.get("text","The action was not accepted."))
		if requesting_current(requesting_ticket):source_runtime.frontend.panes["class"].set_waiting(status)
		elif is_instance_valid(source_runtime) and source_runtime.owns():source_runtime.notice(status)
		else:render();ui.status.text=status
		return
	match str(message.get("operation","")):
		"begin":
			if ui.wanted and (pending_open.is_empty() or pending_open==source_identity()+[ui.request_serial]):begin(message.result)
		"submit":
			if message.result.get("accepted",false):ui.reset()
			elif is_instance_valid(source_runtime) and source_runtime.owns():source_runtime.rejected("The server rejected these choices. Cancel and reopen Level Up.")
			else:submitting=false;status="The server rejected these choices; reopen Level Up and check chat.";render()
func close() -> void:
	retire_source()
	if is_instance_valid(source_runtime):source_runtime.close()
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
func initial_class() -> int:
	for cls in snapshot.get("classes",[]):
		if int(cls.id)<available.size() and available[int(cls.id)]:return int(cls.id)
	return available.find(true)
func class_row(key: String,level: int) -> Dictionary:
	var list:=rows(key); return list[level] if level>=0 and level<list.size() else {}
func begin(result: Dictionary) -> void:
	if not result.get("snapshot") is Dictionary or result.snapshot.get("actorId")!=desktop.actor_id:return
	retire_requesting()
	if is_instance_valid(source_runtime):source_runtime.retire()
	snapshot=result.snapshot.duplicate(true); available=result.available.duplicate(); token=int(result.token);protocol_features=result.get("protocolFeatures",{}).duplicate();class_publication.reset(); step=0; status=""; submitting=false
	# The native Class pane owns its own asynchronous dependencies. Building
	# the older editor first delays this pane and exposes a visible UI swap.
	if source_configured:
		var started: bool=source_runtime.begin(result,source_identity(),desktop.owner_ui.text.tables,desktop.owner_ui.text,desktop.art,desktop.state.get("module",{}))
		ui.activate_source(started)
		if started:return
	select_class(initial_class())
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
	var bonus: int=rules.rule_value("EPIC_GREAT_STAT_BONUS",1)
	for index in mini(6,result.size()):
		result[index]=int(result[index])+num(race,ABILITIES[index]+"Adjust")+(1 if int(draft.get("ability",6))==index else 0)
		for cls in levels:
			var name:=str(rules.cell(rules.row("classes",int(cls.id)),"StatGainTable","")).to_lower(); var gains: Array=desktop.owner_ui.text.tables.get(name,{}).get("orderedRows",[])
			for level in mini(int(cls.level),gains.size()): result[index]+=num(gains[level],ABILITIES[index])
		for feat in chosen:
			if int(feat)>=[814,784,774,794,804,764][index] and int(feat)<[814,784,774,794,804,764][index]+10: result[index]+=bonus
	return result
func skill_budget_value() -> Variant:
	# Shared original7ec0c0 uses this session's resolved tables and adds its
	# point WORD at the new total level. Unknown ability strings mean no
	# modifier; the ruleset owns modifier arithmetic and rank-cap bonuses.
	return SkillRules.budget(desktop.owner_ui.text.tables,int(draft.classId),int(snapshot.race),abilities(),0,int(snapshot.fieldDC6),total()+1)
func budget() -> int:
	var value: Variant=skill_budget_value();return int(value) if value!=null else 0
func skill_rule(id: int) -> Dictionary:
	var value:=SkillRules.rule(desktop.owner_ui.text.tables,int(draft.classId),id,total()+1)
	return {"allowed":value.allowed,"cost":value.cost,"maximum":value.max}
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
	return FeatSlots.calculate(desktop.owner_ui.text.tables,int(snapshot.race),int(draft.classId),total()+1,class_level(int(draft.classId))+1)
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
	if skill_budget_value()==null:result.append("The active skill point rules are unavailable.")
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
	var id:=controls.size(); controls[id]={"operation":operation,"value":value}; var item:={"type":type,"label":label,"controlId":id,"disabled":submitting}; item.merge(extra,true);item.disabled=submitting or bool(item.get("disabled",false));items.append(item)
func render() -> void:
	if is_instance_valid(source_runtime) and source_runtime.owns():return
	if not ui.wanted or snapshot.is_empty() or draft.is_empty(): return
	var ready: bool=desktop.class_tables_ready(int(draft.classId))
	for cls in snapshot.classes: ready=desktop.class_tables_ready(int(cls.id)) and ready
	if not ready: return
	if status=="Loading native class rules…": status=""
	if num(rules.row("classes",int(draft.classId)),"LearnScroll")!=0 and class_level(int(draft.classId))==0: draft.known["0"]=spell_options(0)
	serial+=1; controls.clear(); var items: Array=[]; var cls: Dictionary=rules.row("classes",int(draft.classId))
	match step:
		0:
			var class_model: Dictionary=class_publication.read(desktop.owner_ui.text.tables,desktop.owner_ui.text,{"available":available,"classes":snapshot.classes,"currentClassIndex":snapshot.get("fieldC0"),"multiclassRulesetFeature":protocol_features.get("multiclassRuleset")})
			for entry in class_model.get("entries",[]):add(items,"button",entry.name,"class",int(entry.id),{"selected":int(entry.id)==int(draft.classId),"disabled":not entry.enabled})
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
	# Original Summary can close while its proposal awaits the server. The
	# Session's cancel path preserves that pending submission and its draft.
	var problems:=errors(); ui.receive({"kind":"level-view","viewId":serial,"step":step,"items":items,"status":status,"errors":problems,"canEdit":not submitting,"canBack":step>0 and not submitting,"canNext":step<6 and not submitting,"canFinish":problems.is_empty() and not submitting,"canCancel":true})
func input(message: Dictionary) -> void:
	if ui.source_active and str(message.get("kind","")) in ["level-page","level-control","level-submit"]:return
	if message.has("viewId") and int(message.viewId)!=serial: return
	for entry in message.get("texts",[]):
		var control: Dictionary=controls.get(int(entry.controlId),{})
		if str(control.get("operation",""))=="name": draft[str(control.value)]=str(entry.value).left(63)
	status=""
	match str(message.kind):
		"level-open":
			if reply_scope.is_open() and reply_scope.current(reply_context(),int(ui.request_serial)):
				reopen_source();return
			pending_open=source_identity()+[ui.request_serial]
			if not reply_scope.open(reply_context(),int(ui.request_serial)) or not send_level_request({"kind":"native-level-up","operation":"begin"}):
				status="Waiting for the current controlled character.";ui.status.text=status
		"level-cancel": send_level_request({"kind":"native-level-up","operation":"cancel","token":token}); snapshot.clear(); draft.clear(); ui.reset()
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
			if send_level_request({"kind":"native-level-up","operation":"submit","token":token,"proposal":proposal}):submitting=true;render()
