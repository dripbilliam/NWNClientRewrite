extends RefCounted
# Native draft and controls. Only the original server commits a level-up.
var desktop
var ui
var rules
var snapshot: Dictionary={}
var available: Array=[]
var token:=-1
var draft: Dictionary={}
var feat_kinds: Dictionary={}
var feat_kind:="bonus"
var show_unavailable:=false
var feat_search:=""
var feat_group:=-1
var step:=0
var controls: Dictionary={}
var serial:=0
var status:=""
var submitting:=false
var reopen_required:=false
var source_runtime
var source_configured:=false
var pending_open: Array=[]
var requesting_ticket: Array=[]
var protocol_features: Dictionary={}
var prepared_scope: Array=[]
var preparation_error:=""
var preparation_failed: Array=[]
var preparation_started_us:=0
var preparation_ready_us:=0
var preparation_class_names: Array=[]
var preparation_class_next:=0
var preparation_class_active: Dictionary={}
var preparation_class_limit:=12
var open_started_us:=0
var open_identity: Array=[]
var open_failure:=""
var open_server_ms:=-1.0
var open_resources_ms:=-1.0
var open_cached:=false
var open_reported:=false
const REQUIRED_TABLES=["racialtypes","classes","skills","feat","spells","ruleset","exptable","masterfeats","hen_familiar","hen_companion","spellschools","domains"]
const CLASS_TABLE_FIELDS=["StatGainTable","SpellGainTable","SpellKnownTable","AttackBonusTable","SavingThrowTable","SkillsTable","FeatsTable","BonusFeatsTable"]
var class_publication=preload("res://systems/native_data/level_up_class_publication.gd").new()
const ReplyScope=preload("res://systems/native_data/level_up_reply_scope.gd")
var reply_scope:=ReplyScope.new()
const ABILITIES=["Str","Dex","Con","Int","Wis","Cha"]
const ABILITY_NAMES=["Strength","Dexterity","Constitution","Intelligence","Wisdom","Charisma"]
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
	warm()
	if is_instance_valid(source_runtime):source_runtime.observe_received()
func record_level_diagnostic(code: String,message: String,detail: Dictionary) -> void:
	if not is_instance_valid(desktop) or not is_instance_valid(desktop.owner_ui):return
	var scene: SceneTree=desktop.owner_ui.get_tree()
	if scene==null:return
	for property in scene.get_property_list():
		if str(property.get("name",""))!="direct_diagnostics":continue
		var journal: Variant=scene.get("direct_diagnostics")
		if journal is RefCounted and journal.has_method("record"):journal.record(code,message,detail,"info")
		return
func prepare(retry: bool=false) -> Dictionary:
	if not is_instance_valid(desktop) or not is_instance_valid(desktop.owner_ui) or reply_context().is_empty():return {"ready":false,"pending":true}
	var scope: Array=[desktop.generation,desktop.actor_id]
	if scope!=prepared_scope:
		prepared_scope=scope;preparation_error="";preparation_failed=[]
		preparation_started_us=0;preparation_ready_us=0
		preparation_class_names.clear();preparation_class_next=0;preparation_class_active.clear();preparation_class_limit=12
	if preparation_started_us==0:preparation_started_us=Time.get_ticks_usec()
	var owner=desktop.owner_ui;var active_text=owner.text
	if retry and not preparation_failed.is_empty():
		for name in preparation_failed:
			active_text.network_table_errors.erase(name);active_text.network_table_pending.erase(name);active_text.tables.erase(name)
		preparation_failed=[];preparation_error="";preparation_started_us=Time.get_ticks_usec();preparation_ready_us=0
		preparation_class_names.clear();preparation_class_next=0;preparation_class_active.clear();preparation_class_limit=12
	var classes: Dictionary=active_text.tables.get("classes",{})
	var pending:=false
	# character_level_up.js:12 requests every base table together; the two
	# optional school/domain failures are tolerated after their reads finish.
	for name in REQUIRED_TABLES:
		var entry: Dictionary=active_text.network_table(name)
		if entry.get("ready",false):continue
		if entry.get("pending",false):pending=true;continue
		if name in ["spellschools","domains"]:continue
		if not preparation_failed.has(name):preparation_failed.append(name)
		if preparation_error.is_empty():preparation_error=str(entry.get("error","Level-up resource unavailable: "+name))
	if not pending and (preparation_error.is_empty() or not preparation_class_active.is_empty()) and classes.get("orderedRows") is Array:
		if preparation_class_names.is_empty():
			# Source de-duplicates in class-row/field order before launching workers.
			for cls in classes.orderedRows:
				if not cls is Dictionary:continue
				for field in CLASS_TABLE_FIELDS:
					var name:=str(rules.cell(cls,field,"****")).to_lower()
					if not name.is_empty() and name!="****" and not preparation_class_names.has(name):preparation_class_names.append(name)
		for name in preparation_class_active.keys():
			var entry: Dictionary=active_text.network_table(str(name))
			if entry.get("pending",false):continue
			preparation_class_active.erase(name)
			if entry.get("ready",false):continue
			preparation_class_limit=maxi(0,preparation_class_limit-1)
			if not preparation_failed.has(name):preparation_failed.append(name)
			if preparation_error.is_empty():preparation_error=str(entry.get("error","Level-up resource unavailable: "+str(name)))
		# A rejected source worker stops; its peers keep issuing later reads.
		while preparation_class_active.size()<preparation_class_limit and preparation_class_next<preparation_class_names.size():
			var name: String=str(preparation_class_names[preparation_class_next]);preparation_class_next+=1
			var entry: Dictionary=active_text.network_table(name)
			if entry.get("ready",false):continue
			if entry.get("pending",false):preparation_class_active[name]=true;continue
			preparation_class_limit=maxi(0,preparation_class_limit-1)
			if not preparation_failed.has(name):preparation_failed.append(name)
			if preparation_error.is_empty():preparation_error=str(entry.get("error","Level-up resource unavailable: "+name))
	if preparation_class_active.size()>0 or preparation_class_next<preparation_class_names.size():pending=true
	# Promise.all rejects immediately on the first required failure even while
	# its other workers continue reading. Report that settled error to the view.
	if not preparation_error.is_empty():pending=false
	var ready: bool=not pending and preparation_error.is_empty() and classes.get("orderedRows") is Array
	if ready:
		if preparation_ready_us==0:
			preparation_ready_us=Time.get_ticks_usec()
			record_level_diagnostic("network.level-up-resources-ready","Level-up progression resources prepared",{"durationMs":(preparation_ready_us-preparation_started_us)/1000.0})
		if open_started_us>0 and open_resources_ms<0.0 and open_identity==source_identity()+[ui.request_serial]:open_resources_ms=(Time.get_ticks_usec()-open_started_us)/1000.0
	return {"ready":ready,"pending":pending,"error":preparation_error}
func warm() -> void:
	if reply_context().is_empty():return
	var prepared:=prepare()
	if not str(prepared.get("error","")).is_empty():show_open_error(str(prepared.error))
func show_open_error(reason: String) -> void:
	if reason.is_empty() or not ui.wanted or not open_failure.is_empty() or open_identity!=source_identity()+[ui.request_serial]:return
	# Old NetworkLevelUpView.open catches the first rejected Begin/resource
	# Promise, clears the loading status, and shows an error without a draft.
	open_failure=reason;status="";snapshot.clear();draft.clear()
	ui.receive({"kind":"level-error","text":reason})
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
	# The converted seven-tab view owns the normal multiplayer route, including
	# the server begin wait. The original mode1 runtime remains dormant here.
	retire_requesting()
	if not reply_scope.current(reply_context(),int(ui.request_serial)):return
	ui.status.text="Requesting available classes from the server…"
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
		if private_draft.get("selectedFeats") is Array:
			draft.feats=private_draft.selectedFeats.duplicate();restore_feat_kinds()
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
	snapshot={};available=[];draft={};token=-1;pending_open=[];submitting=false;reopen_required=false;protocol_features={};class_publication.reset()
	open_started_us=0;open_identity=[];open_failure="";open_server_ms=-1.0;open_resources_ms=-1.0;open_cached=false;open_reported=false
func reopen_source() -> void:
	if requesting_current(requesting_ticket):source_runtime.frontend.surface.show();return
	if is_instance_valid(source_runtime):source_runtime.reopen()
func receive_result(message: Dictionary) -> void:
	if not reply_scope.consume(message.get("levelRequest"),reply_context(),int(ui.request_serial),str(message.get("operation",""))):return
	if not message.get("accepted",false):
		submitting=false;status=str(message.get("text","The action was not accepted."))
		if requesting_current(requesting_ticket):source_runtime.frontend.panes["class"].set_waiting(status)
		elif is_instance_valid(source_runtime) and source_runtime.owns():source_runtime.notice(status)
		elif str(message.get("operation",""))=="begin":show_open_error(status)
		else:render();ui.status.text=status
		return
	match str(message.get("operation","")):
		"begin":
			if ui.wanted and (pending_open.is_empty() or pending_open==source_identity()+[ui.request_serial]):
				if open_started_us>0 and open_identity==source_identity()+[ui.request_serial]:open_server_ms=(Time.get_ticks_usec()-open_started_us)/1000.0
				begin(message.result)
		"submit":
			if message.result.get("accepted",false):ui.reset()
			elif is_instance_valid(source_runtime) and source_runtime.owns():source_runtime.rejected("The server rejected these choices. Cancel and reopen Level Up.")
			else:submitting=false;reopen_required=true;status="The server rejected these choices; reopen Level Up and check chat.";render()
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
	if not open_failure.is_empty():return
	if not result.get("snapshot") is Dictionary or result.snapshot.get("actorId")!=desktop.actor_id:return
	retire_requesting()
	if is_instance_valid(source_runtime):source_runtime.retire()
	snapshot=result.snapshot.duplicate(true); available=result.available.duplicate(); token=int(result.token);protocol_features=result.get("protocolFeatures",{}).duplicate();class_publication.reset(); step=0; status=""; submitting=false;reopen_required=false;feat_kinds.clear();feat_kind="bonus";show_unavailable=false;feat_search="";feat_group=-1
	# The converted NetworkLevelUpView route is the normal multiplayer editor.
	# Keep the mode1 runtime object available for a later, separately reviewed
	# cleanup, but never select it while opening this character's level-up.
	ui.activate_source(false)
	var selected:=initial_class()
	if selected<0:show_open_error("The server has no available classes");return
	select_class(selected)
func select_class(id: int) -> void:
	if id<0 or id>=available.size() or not available[id]: return
	feat_kinds.clear();feat_group=-1
	var ranks: Array=[]; ranks.resize(snapshot.skills.size()); ranks.fill(0)
	draft={"classId":id,"ability":6,"hitDie":num(rules.row("classes",id),"HitDie",1),"skills":ranks,"feats":[],"known":{},"removed":{},"domains":[],"school":0,"fieldE34":snapshot.fieldE34,"fieldE48":snapshot.fieldE48,"fieldE30":snapshot.fieldE30,"fieldE38":snapshot.fieldE38}
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
		var first: int=[814,784,774,794,804,764][index]
		for feat in range(first+9,first-1,-1):
			if chosen.has(feat):result[index]+=bonus
	return result
func skill_budget_value() -> Variant:
	var race: Dictionary=rules.row("racialtypes",int(snapshot.race))
	var key:=str(rules.cell(race,"SkillPointModifierAbility",""))
	var ability:=ABILITIES.map(func(value):return value.to_upper()).find(key.to_upper())
	if ability<0 and key.is_valid_int():ability=int(key)
	var scores:=abilities()
	var score:=int(scores[ability]) if ability>=0 and ability<scores.size() else 10
	var modifier: Variant=preload("res://systems/native_data/character_record_values.gd").modifier(score,desktop.owner_ui.text.tables)
	if modifier==null:return null
	return int(snapshot.fieldDC6)+maxi(1,num(rules.row("classes",int(draft.classId)),"SkillPointBase")+int(modifier))+num(race,"ExtraSkillPointsPerLevel")
func budget() -> int:
	var value: Variant=skill_budget_value();return int(value) if value!=null else 0
func skill_rule(id: int) -> Dictionary:
	var skill: Dictionary=rules.row("skills",id);var found:=false;var class_skill:=false
	for entry in rows("SkillsTable"):
		if num(entry,"SkillIndex",-1)==id:found=true;class_skill=num(entry,"ClassSkill")!=0;break
	var cost:=1 if class_skill else 2
	return {"allowed":not skill.is_empty() and (found or num(skill,"AllClassesCanUse")!=0),"classSkill":class_skill,"cost":cost,"maximum":floori(float(total()+4)/float(cost))}
func balance() -> int:
	var result:=budget()
	for index in draft.get("skills",[]).size(): result-=int(draft.skills[index])*int(skill_rule(index).cost)
	return result
func granted() -> Array:
	var result: Array=[]
	for row in rows("FeatsTable"):
		var id:=num(row,"FeatIndex",-1)
		if num(row,"List",-1)==3 and num(row,"GrantedOnLevel",-1)==class_level(int(draft.classId))+1 and id>=0 and not rules.row("feat",id).is_empty() and not snapshot.feats.has(id) and not result.has(id): result.append(id)
	if total()==20 and not rules.row("feat",1001).is_empty() and not snapshot.feats.has(1001) and not result.has(1001): result.append(1001)
	if class_level(int(draft.classId))==0 and num(rules.row("classes",int(draft.classId)),"PickDomains")!=0:
		for domain in draft.domains:
			var id:=num(rules.row("domains",int(domain)),"GrantedFeat",-1)
			if id>=0 and not rules.row("feat",id).is_empty() and not snapshot.feats.has(id) and not result.has(id): result.append(id)
	return result
func feat_slots() -> Dictionary:
	var race: Dictionary=rules.row("racialtypes",int(snapshot.race))
	var every:=num(race,"NormalFeatEveryNthLevel",3);var next:=total()+1
	var bonus_rows:=rows("BonusFeatsTable");var index:=class_level(int(draft.classId))
	var bonus: Dictionary=bonus_rows[index] if index>=0 and index<bonus_rows.size() else {}
	return {"normal":num(race,"NumberNormalFeatsEveryNthLevel",1) if every!=0 and next%every==0 else 0,"bonus":num(bonus,"Bonus")}
func restore_feat_kinds() -> void:
	feat_kinds.clear()
	var slots: Dictionary=feat_slots();var remaining:={"normal":int(slots.normal),"bonus":int(slots.bonus)}
	for id in draft.feats:
		var normal:=feat_allowed(int(id),"normal");var bonus:=feat_allowed(int(id),"bonus")
		if normal==bonus:continue
		var kind:="normal" if normal else "bonus"
		feat_kinds[int(id)]=kind;remaining[kind]=maxi(0,int(remaining[kind])-1)
	for id in draft.feats:
		if feat_kinds.has(int(id)):continue
		var kind:="bonus" if int(remaining.bonus)>0 else "normal"
		if feat_allowed(int(id),kind):feat_kinds[int(id)]=kind;remaining[kind]=maxi(0,int(remaining[kind])-1)
func feat_allowed(id: int,kind: String) -> bool:
	var feat: Dictionary=rules.row("feat",id)
	var title: Variant=rules.cell(feat,"FEAT")
	if feat.is_empty() or num(feat,"HideFromLevelUp")!=0 or title==null or str(title) in ["","****"]: return false
	var list_entry: Dictionary={}
	for row in rows("FeatsTable"):
		if num(row,"FeatIndex",-1)==id: list_entry=row; break
	if kind=="bonus": return num(list_entry,"List",-1) in [1,2]
	return num(list_entry,"List",-1) in [0,1] or num(feat,"AllClassesCanUse")!=0 and num(list_entry,"List",-1)!=2
func feat_requirement(id: int,chosen: Array) -> String:
	var feat: Dictionary=rules.row("feat",id); var owned: Array=snapshot.feats+granted()+chosen; var scores:=abilities(chosen)
	var title: Variant=rules.cell(feat,"FEAT")
	if feat.is_empty() or title==null or str(title) in ["","****"]: return "Invalid feat"
	if owned.has(id): return "Already acquired"
	var next_level:=class_level(int(draft.classId))+1
	for row in rows("FeatsTable"):
		if num(row,"FeatIndex",-1)==id and num(row,"GrantedOnLevel",255)!=255 and num(row,"GrantedOnLevel",255)>next_level: return "Class level requirement"
	for index in mini(scores.size(),6):
		var threshold:=num(feat,"MIN"+ABILITIES[index].to_upper())
		if int(scores[index])<threshold: return ABILITIES[index]+" "+str(threshold)+" required"
	var levels: Array=snapshot.classes.duplicate(true); var found:=false
	for cls in levels:
		if int(cls.id)==int(draft.classId): cls.level=int(cls.level)+1; found=true
	if not found: levels.append({"id":int(draft.classId),"level":1})
	var fort_value: Variant=preload("res://systems/native_data/character_record_values.gd").modifier(int(scores[2]),desktop.owner_ui.text.tables)
	if fort_value==null:return "Fortitude requirement"
	var bab:=0; var fort:=int(fort_value)
	for cls in levels:
		for field in ["AttackBonusTable","SavingThrowTable"]:
			var name:=str(rules.cell(rules.row("classes",int(cls.id)),field,"")).to_lower(); var list: Array=desktop.owner_ui.text.tables.get(name,{}).get("orderedRows",[]); var index:=mini(int(cls.level),20)-1
			if index>=0 and index<list.size():
				if field=="AttackBonusTable": bab+=num(list[index],"BAB")
				else: fort+=num(list[index],"FortSave")
	if bab<num(feat,"MINATTACKBONUS"): return "Base attack requirement"
	if total()+1<num(feat,"MinLevel") or num(feat,"MaxLevel")>0 and total()+1>num(feat,"MaxLevel"): return "Level requirement"
	var required_class:=num(feat,"MinLevelClass",255)
	if num(feat,"MinLevel")>0 and required_class!=255:
		var required_level:=0
		for cls in levels:
			if int(cls.id)==required_class: required_level=int(cls.level)
		if required_level<num(feat,"MinLevel"): return "Level requirement"
	if fort<num(feat,"MinFortSave"): return "Fortitude requirement"
	if num(feat,"PreReqEpic")!=0 and not owned.has(1001): return "Epic character required"
	for key in ["PREREQFEAT1","PREREQFEAT2"]:
		var required:=num(feat,key,-1)
		if required>=0 and required!=65535 and not owned.has(required): return "Prerequisite feat required"
	var alternatives: Array=[]
	for index in 5:
		var required:=num(feat,"OrReqFeat"+str(index),-1)
		if required>=0 and required!=65535: alternatives.append(required)
	if not alternatives.is_empty() and not alternatives.any(func(required):return owned.has(required)): return "Prerequisite feat required"
	for suffix in ["","2"]:
		var skill:=num(feat,"REQSKILL"+suffix,-1)
		if skill>=0 and skill!=65535 and (skill>=snapshot.skills.size() or not skill_rule(skill).allowed or int(snapshot.skills[skill])+int(draft.skills[skill])<num(feat,"ReqSkillMinRanks"+suffix)): return "Skill ranks required"
	var spell:=num(feat,"MINSPELLLVL")
	if spell>0:
		var meets:=false
		for cls in levels:
			var row: Dictionary=rules.row("classes",int(cls.id)); var ability:= ["STR","DEX","CON","INT","WIS","CHA"].find(str(rules.cell(row,"SpellcastingAbil","")).to_upper()); var name:=str(rules.cell(row,"SpellGainTable","")).to_lower(); var gains: Array=desktop.owner_ui.text.tables.get(name,{}).get("orderedRows",[]); var index:=int(cls.level)-1
			if num(row,"SpellCaster")!=0 and ability>=0 and int(scores[ability])>=10+spell and index>=0 and index<gains.size() and num(gains[index],"SpellLevel"+str(spell),255)<255: meets=true
		if not meets: return "Spellcasting level required"
	return ""
func spell_options(level: int) -> Array:
	var result: Array=[]; var class_id:=int(draft.classId); var cls: Dictionary=rules.row("classes",class_id)
	var column: Variant=rules.cell(cls,"SpellTableColumn")
	if num(cls,"SpellCaster")==0 or column==null or str(column) in ["","****"]:return result
	var known: Array=[]
	for index in snapshot.classes.size():
		if int(snapshot.classes[index].id)==class_id: known=snapshot.spellbooks.get(str(index),{}).get("known",[])
	for id in desktop.owner_ui.text.tables.get("spells",{}).get("orderedRows",[]).size():
		var spell: Dictionary=rules.row("spells",id); var school: Dictionary=rules.row("spellschools",int(draft.school)); var opposed: Dictionary=rules.row("spellschools",num(school,"Opposition",-1)); var master:=num(spell,"Master",-1)
		var title: Variant=rules.cell(spell,"Name")
		var opposed_letter: Variant=rules.cell(opposed,"Letter")
		if num(spell,str(column),255)==level and (not known.has(id) or draft.removed.get(str(level),[]).has(id)) and num(spell,"UserType",1)==1 and (master<0 or master==id) and title!=null and str(title) not in ["","****"] and (num(cls,"PickSchool")==0 or opposed_letter==null or str(opposed_letter) in ["","****"] or rules.cell(spell,"School")!=opposed_letter): result.append(id)
	return result
func spell_count(level: int) -> int:
	var cls: Dictionary=rules.row("classes",int(draft.classId)); var current:=class_level(int(draft.classId)); var gain:=class_row("SpellGainTable",current)
	if num(cls,"SpellCaster")==0 or num(cls,"SkipSpellSelection")!=0 or num(cls,"SpellbookRestricted")==0 or level>=num(gain,"NumSpellLevels"): return 0
	if num(cls,"LearnScroll")!=0:
		if current>0: return 0 if level==0 else 2
		var modifier: Variant=preload("res://systems/native_data/character_record_values.gd").modifier(int(abilities()[3]),desktop.owner_ui.text.tables)
		return spell_options(0).size() if level==0 else 3+maxi(0,int(modifier)) if level==1 and modifier!=null else 0
	var known_count:=0
	var column: String=str(rules.cell(cls,"SpellTableColumn",""))
	for index in snapshot.classes.size():
		if int(snapshot.classes[index].id)==int(draft.classId):
			for id in snapshot.spellbooks.get(str(index),{}).get("known",[]):
				if num(rules.row("spells",int(id)),column,255)==level: known_count+=1
			break
	return maxi(0,num(class_row("SpellKnownTable",current),"SpellLevel"+str(level))-known_count)+draft.removed.get(str(level),[]).size()
func errors() -> Array:
	var result: Array=[]
	if (total()+1)%4==0 and int(draft.ability)==6: result.append("Choose an ability increase")
	if balance()<0: result.append("Too many skill points spent")
	for index in draft.skills.size():
		var change: Variant=draft.skills[index]
		# JS Number.isInteger also accepts an integral numeric value decoded as
		# a float; reject fractions and non-finite values before the rank gates.
		if not (change is int or change is float and is_finite(change) and floorf(change)==change) or int(change)<0 or int(change)>127 or int(change)>0 and (not skill_rule(index).allowed or int(snapshot.skills[index])+int(change)>int(skill_rule(index).maximum)): result.append("Invalid skill ranks")
	var slots:=feat_slots();var prior: Array=[]
	for id in draft.feats:
		var kind:=str(feat_kinds.get(int(id),""))
		if not feat_allowed(int(id),kind) or not feat_requirement(int(id),prior).is_empty():result.append("Invalid feat selection")
		prior.append(id)
	for kind in ["normal","bonus"]:
		var count:=0
		for id in draft.feats:
			if str(feat_kinds.get(int(id),""))==kind:count+=1
		if count!=int(slots.get(kind,0)):result.append("Choose every available feat")
	var cls: Dictionary=rules.row("classes",int(draft.classId)); var learned:=0
	if num(cls,"PickDomains")!=0 and (draft.domains.size()!=2 or draft.domains[0]==draft.domains[1]): result.append("Choose two different domains")
	for list in draft.known.values(): learned+=list.size()
	if num(cls,"LearnScroll")!=0 and class_level(int(draft.classId))>0:
		if learned!=2: result.append("Choose two new spells")
	else:
		for level in 10:
			if draft.known.get(str(level),[]).size()!=spell_count(level): result.append("Choose level "+str(level)+" spells")
	for level in 10:
		var allowed:=spell_options(level)
		var selected: Dictionary={}
		for id in draft.known.get(str(level),[]):
			if selected.has(id) or not allowed.has(id): result.append("Invalid spell selection")
			selected[id]=true
	var unique: Array=[]
	for issue in result:
		if not unique.has(issue):unique.append(issue)
	return unique
func add(items: Array,type: String,label: String,operation: String="",value: Variant=null,extra: Dictionary={}) -> void:
	var id:=controls.size(); controls[id]={"operation":operation,"value":value}; var item:={"type":type,"label":label,"controlId":id,"disabled":submitting}; item.merge(extra,true);item.disabled=submitting or bool(item.get("disabled",false));items.append(item)
func render_feats(items: Array) -> void:
	var slots: Dictionary=feat_slots()
	for selected in draft.feats:
		var kind:=str(feat_kinds.get(int(selected),"normal"))
		add(items,"button",("Class bonus" if kind=="bonus" else "General")+": "+rules.title("feat",int(selected),"FEAT")+" · Remove","feat-remove",int(selected))
	var automatic: Array=[]
	for id in granted():automatic.append(rules.title("feat",int(id),"FEAT"))
	add(items,"text","Automatic feats: "+(", ".join(automatic) if not automatic.is_empty() else "None"))
	var kinds: Array=[]
	for kind in ["bonus","normal"]:
		var selected_count:=0
		for selected in draft.feats:
			if str(feat_kinds.get(int(selected),""))==kind:selected_count+=1
		if selected_count<int(slots.get(kind,0)):kinds.append(kind)
	if kinds.is_empty():add(items,"text","All feat choices complete.");return
	if not kinds.has(feat_kind):feat_kind=str(kinds[0])
	var labels: Array=[]
	for kind in kinds:labels.append("Class bonus" if kind=="bonus" else "General")
	add(items,"select","Feat slot","feat-kind",kinds,{"options":labels,"value":kinds.find(feat_kind)})
	add(items,"toggle","Show unavailable feats","feat-available",null,{"value":show_unavailable})
	add(items,"input","Filter feats","feat-search",null,{"value":feat_search,"maxLength":256,"tag":"feat-search"})
	var entries: Array=[];var groups: Dictionary={}
	for id in desktop.owner_ui.text.tables.get("feat",{}).get("orderedRows",[]).size():
		if not feat_allowed(id,feat_kind):continue
		var reason:=feat_requirement(id,draft.feats)
		if not reason.is_empty() and not show_unavailable:continue
		var name: String=str(rules.title("feat",id,"FEAT"))
		var group_id:=num(rules.row("feat",id),"MASTERFEAT",-1)
		var group: Dictionary=rules.row("masterfeats",group_id) if group_id>=0 else {}
		var group_name: String=str(rules.title("masterfeats",group_id,"STRREF")) if not group.is_empty() else ""
		if not feat_search.is_empty() and not (name+" "+group_name).to_lower().contains(feat_search.to_lower()):continue
		var entry:={"id":id,"name":name,"reason":reason}
		if group.is_empty():entries.append(entry)
		else:
			if not groups.has(group_id):groups[group_id]={"id":group_id,"name":group_name,"entries":[]}
			groups[group_id].entries.append(entry)
	if groups.has(feat_group):
		add(items,"button","‹ All feats","feat-all")
		entries=groups[feat_group].entries
	else:
		for group in groups.values():entries.append({"id":group.id,"name":group.name,"group":true})
	entries.sort_custom(func(a,b):return str(a.name).nocasecmp_to(str(b.name))<0)
	for entry in entries:
		if entry.get("group",false):add(items,"button",str(entry.name)+" ›","feat-group",int(entry.id))
		else:add(items,"button",str(entry.name)+(" · "+str(entry.reason) if not str(entry.reason).is_empty() else ""),"feat-add",int(entry.id),{"disabled":not str(entry.reason).is_empty()})
func render() -> void:
	if is_instance_valid(source_runtime) and source_runtime.owns():return
	if not ui.wanted or snapshot.is_empty() or draft.is_empty(): return
	if reopen_required:
		serial+=1;controls.clear()
		ui.receive({"kind":"level-view","viewId":serial,"step":step,"level":total()+1,"items":[],"status":status,"errors":[],"canEdit":false,"canBack":false,"canNext":false,"canFinish":false,"canCancel":true})
		return
	var prepared:=prepare()
	if not prepared.ready:
		if not str(prepared.error).is_empty():show_open_error(str(prepared.error))
		else:status="Preparing level-up rules…";ui.status.text=status
		return
	if status in ["Loading native class rules…","Preparing level-up rules…"]:status=""
	if num(rules.row("classes",int(draft.classId)),"LearnScroll")!=0 and class_level(int(draft.classId))==0 and not draft.known.has("0"): draft.known["0"]=spell_options(0)
	serial+=1; controls.clear(); var items: Array=[]; var cls: Dictionary=rules.row("classes",int(draft.classId))
	match step:
		0:
			for id in desktop.owner_ui.text.tables.get("classes",{}).get("orderedRows",[]).size():
				if id<available.size() and available[id]:add(items,"button",rules.title("classes",id)+" ("+str(class_level(id)+1)+")","class",id,{"selected":id==int(draft.classId)})
		1:
			var ability_due: bool=(total()+1)%4==0
			add(items,"text","Choose one ability to increase." if ability_due else "No ability increase at this level.")
			for index in 6:
				add(items,"button",ABILITY_NAMES[index]+": "+str(abilities()[index]),"ability",index,{"selected":int(draft.ability)==index,"disabled":not ability_due})
		2:
			add(items,"text","Skill points remaining: "+str(balance()))
			for index in snapshot.skills.size():
				var rule:=skill_rule(index)
				if not rule.allowed: continue
				add(items,"text",rules.title("skills",index)+("" if rule.classSkill else " (cross-class)")+" · "+str(int(snapshot.skills[index])+int(draft.skills[index]))+" / "+str(rule.maximum),"",null,{"tag":"skill"})
				add(items,"button","−","skill-minus",index,{"tag":"skill-minus","disabled":int(draft.skills[index])<=0})
				add(items,"button","+","skill-plus",index,{"tag":"skill-plus","disabled":balance()<int(rule.cost) or int(snapshot.skills[index])+int(draft.skills[index])>=int(rule.maximum)})
		3:
			render_feats(items)
		4:
			var shared:=num(cls,"LearnScroll")!=0 and class_level(int(draft.classId))>0
			var any_spells:=false
			var chosen_total:=0
			for selection in draft.known.values():chosen_total+=selection.size()
			for level in 10:
				var count:=spell_count(level)
				if count<=0: continue
				any_spells=true
				var chosen: Array=draft.known.get(str(level),[])
				add(items,"text","Level "+str(level)+" spells · "+str(chosen.size())+("" if shared else " / "+str(count)))
				for id in spell_options(level):
					var selected:=chosen.has(id)
					add(items,"toggle",rules.title("spells",id),"spell",[level,id],{"value":selected,"disabled":not selected and (chosen_total if shared else chosen.size())>=count})
			if not any_spells:add(items,"text","This level has no new spell choices.")
			if num(cls,"PickDomains")!=0 and class_level(int(draft.classId))==0:
				var options: Array=[];var ids: Array=[]
				for id in desktop.owner_ui.text.tables.get("domains",{}).get("orderedRows",[]).size():options.append(rules.title("domains",id));ids.append(id)
				for index in 2:add(items,"select","Domain "+str(index+1),"domain-select",{"index":index,"ids":ids},{"options":options,"value":ids.find(int(draft.domains[index])) if index<draft.domains.size() else -1})
			if num(cls,"PickSchool")!=0 and class_level(int(draft.classId))==0:
				var options: Array=[]
				for id in desktop.owner_ui.text.tables.get("spellschools",{}).get("orderedRows",[]).size(): options.append(rules.title("spellschools",id))
				add(items,"select","School","school",null,{"options":options,"value":int(draft.school)})
		5:
			var any_companions:=false
			for specification in [["Familiar","hen_familiar","fieldE34",303],["Animal companion","hen_companion","fieldE30",199]]:
				if not (snapshot.feats+granted()+draft.feats).has(specification[3]): continue
				any_companions=true
				var options: Array=["None"]; var ids: Array=[255]
				for id in desktop.owner_ui.text.tables.get(specification[1],{}).get("orderedRows",[]).size():
					if num(rules.row(specification[1],id),"PLAYER",1)==0: continue
					options.append(rules.title(specification[1],id,"STRREF")); ids.append(id)
				if not options.is_empty(): add(items,"select",specification[0],"companion",{"field":specification[2],"ids":ids},{"options":options,"value":ids.find(int(draft[specification[2]]))})
			for pair in [["Familiar name","fieldE48",303],["Companion name","fieldE38",199]]:
				if (snapshot.feats+granted()+draft.feats).has(pair[2]): add(items,"input",pair[0],"name",pair[1],{"value":str(draft[pair[1]]),"maxLength":63,"tag":"name"})
			if not any_companions:add(items,"text","No familiar or animal-companion choices at this level.")
		6:
			var new_feats: Array=[]
			for feat in granted()+draft.feats:new_feats.append(rules.title("feat",int(feat),"FEAT"))
			add(items,"text",rules.title("classes",int(draft.classId))+" "+str(class_level(int(draft.classId))+1))
			add(items,"text","Hit die: "+str(draft.hitDie)+" · Skill points saved: "+str(balance()))
			add(items,"text","New feats: "+(", ".join(new_feats) if not new_feats.is_empty() else "None"))
			add(items,"text","Server Authorative.")
	var problems:=errors(); ui.receive({"kind":"level-view","viewId":serial,"step":step,"level":total()+1,"items":items,"status":status,"errors":problems,"canEdit":not submitting,"canBack":step>0 and not submitting,"canNext":step<6 and not submitting,"canFinish":problems.is_empty() and not submitting})
	if not open_reported and open_started_us>0 and open_server_ms>=0.0 and open_resources_ms>=0.0 and open_identity==source_identity()+[ui.request_serial]:
		open_reported=true
		record_level_diagnostic("network.level-up-open-ready","Level-up class choices are ready",{"serverMs":open_server_ms,"resourcesMs":open_resources_ms,"totalMs":(Time.get_ticks_usec()-open_started_us)/1000.0,"cached":open_cached})
func input(message: Dictionary) -> void:
	if ui.source_active and str(message.get("kind","")) in ["level-page","level-control","level-submit","level-name-edit"]:return
	if reopen_required and str(message.get("kind","")) in ["level-page","level-control","level-submit","level-name-edit"]:return
	if message.has("viewId") and int(message.viewId)!=serial: return
	if str(message.get("kind",""))=="level-name-edit":
		var edited: Dictionary=controls.get(int(message.get("controlId",-1)),{})
		if str(edited.get("operation",""))=="name":draft[str(edited.value)]=str(message.get("value","")).left(63)
		return
	for entry in message.get("texts",[]):
		var control: Dictionary=controls.get(int(entry.controlId),{})
		if str(control.get("operation",""))=="name": draft[str(control.value)]=str(entry.value).left(63)
		elif str(control.get("operation",""))=="feat-search":feat_search=str(entry.value).left(256)
	status=""
	match str(message.kind):
		"level-open":
			if reply_scope.is_open() and reply_scope.current(reply_context(),int(ui.request_serial)):
				reopen_source();return
			open_started_us=Time.get_ticks_usec();open_identity=source_identity()+[ui.request_serial];open_failure=""
			open_server_ms=-1.0;open_resources_ms=-1.0;open_reported=false
			open_cached=prepared_scope==[desktop.generation,desktop.actor_id] and preparation_started_us>0
			var prepared:=prepare(true)
			pending_open=source_identity()+[ui.request_serial]
			if not str(prepared.get("error","")).is_empty():show_open_error(str(prepared.error))
			if not reply_scope.open(reply_context(),int(ui.request_serial)) or not send_level_request({"kind":"native-level-up","operation":"begin"}):
				status="Waiting for the current controlled character.";ui.status.text=status
		"level-cancel":
			if submitting:return
			send_level_request({"kind":"native-level-up","operation":"cancel","token":token}); snapshot.clear(); draft.clear(); ui.reset()
		"level-page":
			if int(message.viewId)==serial: step=clampi(int(message.step),0,6); render()
		"level-control":
			if int(message.viewId)!=serial or not controls.has(int(message.controlId)): return
			var control: Dictionary=controls[int(message.controlId)]; var id:=int(control.value) if control.value is int else -1
			match str(control.operation):
				"class": select_class(id); return
				"ability": draft.ability=id
				"feat-kind":
					var kinds: Variant=control.value
					if kinds is Array and int(message.value)>=0 and int(message.value)<kinds.size():feat_kind=str(kinds[int(message.value)]);feat_group=-1
				"feat-available":show_unavailable=bool(message.value)
				"feat-search":feat_search=str(message.value).left(256)
				"feat-group":feat_group=id
				"feat-all":feat_group=-1
				"feat-remove":draft.feats.erase(id);feat_kinds.erase(id)
				"feat-add":
					var selected_count:=0
					for selected in draft.feats:
						if str(feat_kinds.get(int(selected),""))==feat_kind:selected_count+=1
					if not draft.feats.has(id) and feat_allowed(id,feat_kind) and feat_requirement(id,draft.feats).is_empty() and selected_count<int(feat_slots().get(feat_kind,0)):
						draft.feats.append(id);feat_kinds[id]=feat_kind
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
					if message.value and not draft.known[level].has(spell):
						var shared:=num(rules.row("classes",int(draft.classId)),"LearnScroll")!=0 and class_level(int(draft.classId))>0
						var chosen_total:=0
						for selection in draft.known.values():chosen_total+=selection.size()
						if (chosen_total if shared else draft.known[level].size())<spell_count(int(level)):draft.known[level].append(spell)
					elif not message.value: draft.known[level].erase(spell)
				"domain-select":
					var slot:=int(control.value.index);var ids: Array=control.value.ids;var choice:=int(message.value)
					if slot>=0 and slot<2 and choice>=0 and choice<ids.size():
						while draft.domains.size()<=slot:draft.domains.append(-1)
						draft.domains[slot]=int(ids[choice])
				"school": draft.school=int(message.value); draft.known.clear()
				"companion":
					if int(message.value)>=0 and int(message.value)<control.value.ids.size(): draft[str(control.value.field)]=int(control.value.ids[int(message.value)])
				"name": draft[str(control.value)]=str(message.value)
			render()
		"level-submit":
			if int(message.viewId)!=serial or not errors().is_empty(): return
			var proposal:=draft.duplicate(true); proposal.skillPoints=balance(); proposal.feats=granted()+draft.feats
			if send_level_request({"kind":"native-level-up","operation":"submit","token":token,"proposal":proposal}):submitting=true;render()
