extends RefCounted
# Staged owner for original mode1 controls/private values. The real Session
# remains the sole network transaction owner. This class emits intents only;
# no actor mutation, optimistic server result or first-level draft is used.
signal child_requested(stage: String,model: Dictionary,ticket: Array)
signal summary_requested(private_draft: Dictionary,ticket: Array)
signal submission_requested(proposal: Dictionary,token: int,identity: Array)
signal cancellation_requested(token: int,identity: Array,submission_pending: bool)
signal state_changed(stage: String,ready: bool,reason: String)
signal recommendation_requested(stage: String,ticket: Array)
signal class_rules_requested(ticket: Array)
const Navigation=preload("res://systems/native_data/level_up_navigation.gd")
const Classes=preload("res://systems/native_data/level_up_class_state.gd")
const Attributes=preload("res://systems/native_data/level_up_attributes_state.gd")
const Vitals=preload("res://systems/native_data/level_up_vitals.gd")
const Skills=preload("res://systems/native_data/level_up_skill_state.gd")
const Feats=preload("res://systems/native_data/level_up_feat_state.gd")
const Snapshot=preload("res://systems/native_data/level_up_feat_snapshot.gd")
const Children=preload("res://systems/native_data/level_up_child_models.gd")
const Spells=preload("res://systems/native_data/level_up_spells_state.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Associate=preload("res://systems/native_data/creation_associate_state.gd")
const AssociateJobs=preload("res://systems/native_level_up_associate_work.gd")
const ClassPublication=preload("res://systems/native_data/level_up_class_publication.gd")
const ClassDependencies=preload("res://systems/native_data/level_up_class_dependencies.gd")
var class_publication:=ClassPublication.new()
var frontend
var navigation:=Navigation.new()
var attributes:=Attributes.new()
var skills:=Skills.new()
var feats:=Feats.new()
var spells:=Spells.new()
var known_delta: Dictionary={}
var removed_delta: Dictionary={}
var selected_domains: Array=[]
var selected_school:=-1
var domain_grants: Array=[]
var associate_value: Dictionary={}
var active_catalog
var asset_cache_path:=""
var associate_jobs
var received: Dictionary={}
var context: Dictionary={}
var class_context: Dictionary={}
var tables: Dictionary={}
var text
var art
var identity: Array=[]
var token:=-1
var class_id:=-1
var wanted:=false
var reason:=""
var finalization: Dictionary={}
var initial_tables: Dictionary={}
var recommendation_pending:=false
var recommendation_diagnostics: Dictionary={}
var class_preparing:=false
var pending_class_id:=-1
var pending_class_ticket: Array=[]
var class_inputs: Dictionary={}
var class_focus_id:=-1
var class_error:=""
var class_diagnostics: Dictionary={}
var definitions_reader: Callable
func configure(front) -> void:
	if frontend!=null:return
	frontend=front;frontend.action_requested.connect(action);frontend.accepted.connect(accepted);frontend.child_accepted.connect(accepted_child);frontend.child_action_requested.connect(child_action);frontend.cancelled.connect(cancelled);frontend.submit_requested.connect(submit)
func configure_jobs(catalog,cache_path: String="") -> void:
	active_catalog=catalog;asset_cache_path=cache_path
func configure_definitions(reader: Callable) -> void:definitions_reader=reader
func feat_definitions() -> Dictionary:
	var value: Variant=definitions_reader.call() if definitions_reader.is_valid() else null
	if not value is Dictionary:return {"ready":false,"pending":true,"reason":"Private feat definitions are not yet prepared."}
	if value.get("ready",false) and not value.get("definitions") is Array:return {"ready":false,"reason":"Private feat definitions are malformed."}
	return value
func snapshot(chosen: Array=[]) -> Dictionary:
	var decoded:=feat_definitions()
	if not decoded.get("ready",false):return decoded
	return Snapshot.compose(received,class_id,attributes.selected,skills.ranks,tables,context,chosen,decoded)
func ensure_associate_jobs(ticket: Array) -> bool:
	if active_catalog==null or frontend==null:return false
	if not is_instance_valid(associate_jobs):
		associate_jobs=AssociateJobs.new();frontend.add_child(associate_jobs);associate_jobs.preview_ready.connect(associate_preview);associate_jobs.name_ready.connect(associate_name)
	if not associate_jobs.current(ticket):associate_jobs.configure(active_catalog,tables,text,ticket,asset_cache_path)
	return associate_jobs.current(ticket) and is_instance_valid(associate_jobs.assets)
func begin(value: Dictionary,owner_identity: Array,active_tables: Dictionary,active_text,active_art) -> Dictionary:
	close();reason="Private level-up begin context is unavailable."
	if frontend==null or owner_identity.is_empty() or not Classes.integer(value.get("token"),0,9007199254740991) or not value.get("snapshot") is Dictionary or not value.get("available") is Array or not value.get("protocolFeatures") is Dictionary:return {"ready":false,"reason":reason}
	if not value.protocolFeatures.get("multiclassRuleset") is bool:return {"ready":false,"reason":reason}
	if not Classes.integer(value.snapshot.get("actorId"),0,4294967295):return {"ready":false,"reason":reason}
	if active_text==null or not active_text.has_method("raw"):return {"ready":false,"reason":reason}
	received=value.snapshot.duplicate(true);context=value.get("draftContext",{}).duplicate(true) if value.get("draftContext") is Dictionary else {}
	identity=owner_identity.duplicate();token=int(value.token);tables=active_tables;text=active_text;art=active_art
	class_context={"classes":received.get("classes"),"available":value.available.duplicate(),"currentClassIndex":received.get("fieldC0"),"multiclassRulesetFeature":value.protocolFeatures.multiclassRuleset}
	wanted=true;attributes.selected=-1;navigation.begin(identity+[token]);show_class();return {"ready":class_model().get("ready",false),"reason":reason,"scope":navigation.scope.duplicate()}
func class_model() -> Dictionary:return class_publication.read(tables,text,class_context)
func show_class() -> void:
	if class_preparing:return
	var selected: int=frontend.class_selection_id()
	if selected>=0:
		if selected!=class_focus_id:class_error=""
		class_focus_id=selected
	var model:=class_model();reason=class_error if model.get("ready",false) else "Active mode1 class data is unavailable."
	frontend.present_class(model,Values.cfg(tables,"CHARGEN_ENABLE_RECOMMENDED_BUTTON",1)!=0,text,art,navigation.ticket);state_changed.emit("class",model.get("ready",false),reason)
	if class_focus_id>=0:frontend.class_selection(class_focus_id)
	if not class_error.is_empty():frontend.class_problem(class_error,navigation.ticket)
func current(ticket: Array) -> bool:return wanted and frontend!=null and frontend.owns(ticket) and frontend.scope==navigation.ticket and frontend.stage==navigation.stage
func same_rules() -> bool:
	for name in initial_tables:
		if not tables.has(name) or not is_same(initial_tables[name],tables[name]):return false
	return true
func attribute_model() -> Dictionary:
	var model:=Vitals.project(received,class_id,attributes.selected,tables)
	return model if same_rules() else {"ready":false,"reason":"Active level-up rules changed."}
func enter_skills() -> void:
	var ready:=skills.configure(received,class_id,attributes.selected,tables)
	var model:=skills.compose(tables,text);reason=str(model.get("reason",""))
	frontend.present_middle("skills",model,recommendation_enabled(),text,art,navigation.ticket);state_changed.emit("skills",ready,reason)
func recommendation_enabled() -> bool:return Values.cfg(tables,"CHARGEN_ENABLE_RECOMMENDED_BUTTON",1)!=0
func class_rules_current() -> bool:
	for name in class_inputs:
		if not tables.has(name) or not is_same(class_inputs[name],tables[name]):return false
	return true
func class_problem(message: String) -> void:
	class_preparing=false;pending_class_id=-1;pending_class_ticket=[];class_inputs={};class_error=message;reason=message;show_class()
func prepare_class(id: int,ticket: Array) -> void:
	class_focus_id=id;class_error="";var plan:=ClassDependencies.compose(received,id,tables)
	if not plan.get("ready",false) and not plan.get("pending",false):class_problem(str(plan.get("reason","Class choices are unavailable.")));return
	var decoded:=feat_definitions()
	if not decoded.get("ready",false) and not decoded.get("pending",false):class_problem(str(decoded.get("reason","Class choices are unavailable.")));return
	if plan.get("ready",false) and decoded.get("ready",false):commit_class(id);return
	class_preparing=true;pending_class_id=id;pending_class_ticket=ticket.duplicate();class_inputs={}
	for name in ["classes","racialtypes","ruleset","skills","feat"]+plan.get("required",[]):
		if tables.has(name):class_inputs[name]=tables[name]
	frontend.prepare_class("Preparing class choices…",navigation.ticket)
	if class_rules_requested.get_connections().is_empty():class_problem("Class choices are not yet available.");return
	class_rules_requested.emit(ticket.duplicate())
func class_rules_result(value: Dictionary,ticket: Array) -> void:
	if not class_preparing or ticket!=pending_class_ticket or not current(ticket) or navigation.stage!="class":return
	if not class_rules_current():
		var old_token:=token;var old_identity:=identity.duplicate();close();cancellation_requested.emit(old_token,old_identity,false);return
	var id:=pending_class_id;class_diagnostics={"elapsedUsec":value.get("elapsedUsec",0),"work":value.get("diagnostics",{})}
	class_preparing=false;pending_class_id=-1;pending_class_ticket=[];class_inputs={}
	if not value.get("ready",false):class_problem(str(value.get("reason","Class choices are unavailable.")));return
	var plan:=ClassDependencies.compose(received,id,tables)
	if not plan.get("ready",false):class_problem(str(plan.get("reason","Class choices are unavailable.")));return
	commit_class(id)
func commit_class(id: int) -> void:
	var decoded:=feat_definitions()
	if not decoded.get("ready",false):class_problem(str(decoded.get("reason","Class choices are unavailable.")));return
	var advanced:=Vitals.project(received,id,-1,tables);var probe:=Skills.new()
	if not advanced.get("ready",false):class_problem(str(advanced.get("reason","Class choices are unavailable.")));return
	if not probe.configure(received,id,-1,tables):class_problem(str(probe.failure));return
	class_id=id;attributes.selected=-1;initial_tables=tables.duplicate();class_error="";var next:=navigation.after_class(navigation.ticket,advanced)
	if not next.ready:return
	if next.stage=="attributes":frontend.present_attributes(attribute_model(),recommendation_enabled(),text,navigation.ticket)
	else:enter_skills()
func recommendation_context(stage: String) -> Dictionary:
	if stage=="spells" and spells.current(tables):return {"memorizes":spells.state.source.memorizes,"school":spells.state.source.school}
	return {}
func reset_recommended_choices(stage: String,ticket: Array) -> void:
	if not recommendation_pending or not current(ticket) or navigation.stage!=stage or not same_rules():return
	if stage=="skills":skills.reset_recommendation();frontend.update_middle(stage,skills.compose(tables,text),navigation.ticket)
	elif stage=="feats":feats.reset_selection();frontend.update_middle(stage,feats.model(tables,text),navigation.ticket)
	elif stage=="spells":spells.act("reset",-1,tables);frontend.update_middle(stage,spells.model(tables),navigation.ticket)
	frontend.recommendation_busy(stage,true,"Reading recommended choices…")
func recommendation_result(stage: String,value: Dictionary,ticket: Array) -> void:
	if not recommendation_pending or not current(ticket) or stage!=navigation.stage or not same_rules():return
	var began:=Time.get_ticks_usec();var message:=""
	if stage=="attributes":
		if value.get("ready",false):attributes.recommend(str(value.get("attribute","")),bool(value.get("loaded",false)))
		frontend.update_attributes(attribute_model(),navigation.ticket)
		if not value.get("ready",false) or not value.get("loaded",false):message=str(value.get("reason","Recommended choices are unavailable."))
	elif stage=="skills":
		if value.get("ready",false) and value.get("invoked",false) and value.get("loaded",false):
			var result:=skills.recommend(value.get("ids",[]),tables)
			if not result.ready:message=str(result.reason)
		elif not value.get("ready",false) or value.get("invoked",false) and not value.get("loaded",false):message=str(value.get("reason","Recommended choices are unavailable."))
		frontend.update_middle(stage,skills.compose(tables,text),navigation.ticket)
	elif stage=="feats":
		if value.get("ready",false) and value.get("invoked",false):
			var result:=feats.recommend(tables.get(str(value.get("name","")),{}),bool(value.get("loaded",false)),tables,text)
			if not result.get("ready",false):message=str(result.get("reason","Native feat recommendations are unavailable."))
		elif not value.get("ready",false):message=str(value.get("reason","Native feat recommendations are unavailable."))
		frontend.update_middle(stage,feats.model(tables,text),navigation.ticket)
	elif stage=="spells":
		if value.get("ready",false):
			var result:=spells.recommend(value,tables)
			if not result.get("ready",false):message=str(result.get("reason","Native spell recommendations are unavailable."))
		else:message=str(value.get("reason","Native spell recommendations are unavailable."))
		frontend.update_middle(stage,spells.model(tables),navigation.ticket)
	elif stage in ["domains","school"]:
		var result: Dictionary=frontend.apply_post_recommendation(stage,value,ticket)
		if not result.get("ready",false) or not value.get("loaded",false):message=str(result.get("reason",value.get("reason","Recommended choices are unavailable.")))
	reason=message
	recommendation_pending=false;recommendation_diagnostics[stage]={"applyUsec":Time.get_ticks_usec()-began,"elapsedUsec":value.get("elapsedUsec",0),"work":value.get("diagnostics",{})};frontend.recommendation_busy(stage,false,message)
func enter_feats() -> void:
	feats.configure(received,class_id,attributes.selected,skills.ranks,context)
	var model:=feats.model(tables,text);reason=str(model.get("reason",""))
	frontend.present_middle("feats",model,recommendation_enabled(),text,art,navigation.ticket);state_changed.emit("feats",model.get("ready",false),reason)
func accepted(stage: String,id: int,ticket: Array) -> void:
	if not current(ticket) or stage!=navigation.stage:return
	if recommendation_pending or class_preparing:return
	if stage=="class":
		var model:=class_model();var admitted: bool=model.get("ready",false) and model.entries.any(func(row):return int(row.id)==id and row.enabled)
		if not admitted:return
		prepare_class(id,ticket)
	elif stage=="attributes":
		var next:=navigation.after_attributes(navigation.ticket,attributes.selected)
		if next.ready:enter_skills()
	elif stage=="skills":
		if not same_rules() or not skills.current_tables(tables):return
		var prepared:=snapshot()
		if not prepared.get("ready",false):
			reason=str(prepared.get("reason",""));frontend.present_middle("skills",{"ready":false,"reason":reason},false,text,art,navigation.ticket);state_changed.emit("skills",false,reason);return
		var next:=navigation.after_skills(navigation.ticket,{"normal":prepared.source.normal,"bonus":prepared.source.bonus},tables)
		if next.ready and next.stage=="feats":enter_feats()
		elif next.ready:show_post()
	elif stage=="feats":
		if not same_rules():return
		var next:=navigation.after_feats(navigation.ticket,feats.validate(tables,text),tables)
		if next.ready:show_post()
	elif stage=="spells":
		var changes:=spells.changes(tables)
		if not same_rules() or not changes.ready:return
		known_delta=changes.known;removed_delta=changes.removed
		var next:=navigation.after_child(navigation.ticket,tables)
		if next.ready:show_post()
func action(stage: String,operation: String,id: int,ticket: Array) -> void:
	if not current(ticket) or stage!=navigation.stage or not same_rules():return
	if recommendation_pending or class_preparing:return
	if operation=="recommend" and stage in ["attributes","skills","feats","spells","domains","school"]:
		if not recommendation_enabled():return
		if stage in ["domains","school"] and not frontend.begin_post_recommendation(stage,ticket):return
		if stage=="attributes":attributes.recommend("",false);frontend.update_attributes(attribute_model(),navigation.ticket)
		elif stage=="spells":spells.act("reset",-1,tables);frontend.update_middle(stage,spells.model(tables),navigation.ticket)
		recommendation_pending=true;frontend.recommendation_busy(stage,true,"Reading recommended choices…");recommendation_requested.emit(stage,ticket.duplicate());return
	if stage=="attributes":
		if operation in ["up","down"]:attributes.move(id,1 if operation=="up" else -1)
		frontend.update_attributes(attribute_model(),navigation.ticket)
	elif stage=="skills":
		if operation in ["up","down"]:skills.move(id,1 if operation=="up" else -1,tables)
		frontend.update_middle(stage,skills.compose(tables,text),navigation.ticket)
	elif stage=="feats":frontend.update_middle(stage,feats.act(operation,id,tables,text),navigation.ticket)
	elif stage=="spells":frontend.update_middle(stage,spells.act(operation,id,tables),navigation.ticket)
func accepted_child(stage: String,value: Variant,ticket: Array) -> void:
	if not current(ticket) or stage!=navigation.stage or not same_rules():return
	if recommendation_pending or class_preparing:return
	if stage=="domains":
		var model:=Children.domains(received,tables,text,class_id)
		if not model.get("ready",false) or not value is Array or value.size()!=2:return
		var ids: Array=[];var grants: Array=[]
		for id in value:
			if not Classes.integer(id,0,255) or ids.has(int(id)):return
			var matches: Array=model.entries.filter(func(row):return int(row.id)==int(id))
			if matches.size()!=1:return
			ids.append(int(id));var feat:=int(matches[0].grantedFeat)&65535
			if feat!=65535 and not grants.has(feat):grants.append(feat)
		selected_domains=ids;domain_grants=grants
	elif stage=="school":
		if not Classes.integer(value,0,8) or not Children.school(received,tables,class_id).get("ready",false):return
		#9c8c60 clears private spell books/slots before changing the school.
		# This route is new-class1 only; its selected book is constructor-empty.
		# Other-class slot-cache presentation is an explicit remaining gate.
		selected_school=int(value)
	elif stage=="associate":
		if not value is Dictionary or not value.get("name") is String or not Classes.integer(value.get("id"),0,2147483647):return
		var model:=Children.associate(received,class_id,tables,text)
		if not model.ready or value.get("field")!=model.field:return
		var choices:=Associate.new();choices.configure(model.choices,model.storedType,model.name)
		var ids: Array=choices.entries.map(func(row):return int(row.id));var index:=ids.find(int(value.id))
		if not choices.select_index(index):return
		choices.set_name(value.name);var committed:=choices.commit()
		if not committed.ready:return
		associate_value=committed.duplicate(true)
		if is_instance_valid(associate_jobs):associate_jobs.retire()
	else:return
	var next:=navigation.after_child(navigation.ticket,tables)
	if next.ready:show_post()
func child_action(stage: String,operation: String,value: Dictionary,ticket: Array) -> void:
	if stage!="associate" or not current(ticket) or not same_rules() or not ensure_associate_jobs(ticket):return
	if operation=="preview":associate_jobs.preview(value,ticket)
	elif operation=="generate":associate_jobs.generate(value,ticket)
	elif operation=="name":associate_jobs.cancel_pending_name(ticket)
func associate_preview(value: Dictionary,ticket: Array,selection: int) -> void:
	if current(ticket) and same_rules() and navigation.stage=="associate":frontend.panes.associate.present_preview(value,ticket,selection)
func associate_name(value: Dictionary,ticket: Array,revision: int,accept_after: bool) -> void:
	if current(ticket) and same_rules() and navigation.stage=="associate":frontend.panes.associate.name_result(value,ticket,revision,accept_after)
func show_post() -> void:
	frontend.dismiss()
	var stage:=navigation.stage
	if stage=="summary":
		finalization={};frontend.present_summary("",false,navigation.ticket);summary_requested.emit(private_draft(),navigation.ticket.duplicate());return
	if stage=="spells":
		var prepared_source:=snapshot()
		var prepared:=spells.configure(received,prepared_source,tables,text,selected_school)
		var model:=spells.model(tables);reason=str(prepared.get("reason",""));frontend.present_middle(stage,model,recommendation_enabled(),text,art,navigation.ticket);state_changed.emit(stage,prepared.get("ready",false),reason);return
	var model: Dictionary={"ready":false,"reason":"Original mode1 child adapter is unavailable."}
	if stage=="domains":model=Children.domains(received,tables,text,class_id)
	elif stage=="school":model=Children.school(received,tables,class_id)
	elif stage=="associate":model=Children.associate(received,class_id,tables,text)
	if stage in ["domains","school"] or stage=="associate" and active_catalog!=null:
		frontend.present_child(stage,model,recommendation_enabled(),text,art,navigation.ticket);state_changed.emit(stage,model.get("ready",false),str(model.get("reason","")));return
	# Associate preview/name jobs remain an explicit integration boundary.
	child_requested.emit(stage,model,navigation.ticket.duplicate());state_changed.emit(stage,false,str(model.get("reason","Mode1 child controls are not bound.")))
func private_draft() -> Dictionary:
	var original_fields: Dictionary={}
	for key in ["fieldE34","fieldE48","fieldE30","fieldE38"]:
		if received.has(key):original_fields[key]=received[key]
	if associate_value.get("ready",false):
		if associate_value.field=="familiar":original_fields.fieldE34=int(associate_value.id);original_fields.fieldE48=str(associate_value.name)
		else:original_fields.fieldE30=int(associate_value.id);original_fields.fieldE38=str(associate_value.name)
	return {"classId":class_id,"ability":attributes.selected if attributes.selected>=0 else 6,"skills":skills.changes(),"skillPoints":skills.points&65535,"selectedFeats":feats.selected.duplicate(),"domainGrants":domain_grants.duplicate(),"domains":selected_domains.duplicate(),"school":selected_school,"known":known_delta.duplicate(true),"removed":removed_delta.duplicate(true),"receivedFields":original_fields,"scope":navigation.scope.duplicate()}
func finalization_snapshot(summary_ticket: Array) -> Dictionary:
	if not wanted or not navigation.owns(summary_ticket,"summary") or not same_rules():return {"ready":false}
	var source:=snapshot(feats.selected)
	if source.get("ready",false):
		for feat in domain_grants:
			if not source.source.owned.has(feat) and not source.source.selected.has(feat):source.source.owned.append(feat)
	return source
func set_summary(value: Dictionary,summary_ticket: Array) -> bool:
	if not wanted or not navigation.owns(summary_ticket,"summary") or navigation.submitted or not same_rules():return false
	#838950 owns hit-die rules/randomness. Missing preparation may not become
	# max hit die1 or a fabricated roll. This boundary will receive that owner.
	if not value.get("ready",false) or not value.get("summary") is String or not Classes.integer(value.get("hitDie"),1,255):return false
	finalization=value.duplicate(true);frontend.present_summary(str(value.summary),true,navigation.ticket);return true
func proposal() -> Dictionary:
	if not wanted or navigation.stage!="summary" or not same_rules() or not skills.current_tables(tables) or not finalization.get("ready",false):return {"ready":false}
	var current:=snapshot()
	if not current.get("ready",false):return {"ready":false}
	var valid:=feats.validate(tables,text) if navigation.stage=="summary" and feats.selected_class==class_id else {"ready":true,"valid":int(current.source.normal)==0 and int(current.source.bonus)==0}
	if not valid.get("ready",false) or not valid.get("valid",false):return {"ready":false}
	var changes:=skills.changes()
	if changes.any(func(value):return not Classes.integer(value,0,127)):return {"ready":false}
	var acquired: Array=current.source.owned.slice(received.feats.size())+feats.selected
	for feat in domain_grants:
		if not current.source.owned.has(feat) and not acquired.has(feat):acquired.append(feat)
	if acquired.size()>255:return {"ready":false}
	var domains:=selected_domains.duplicate();var school:=selected_school if selected_school>=0 else 0
	var cls: Dictionary=current.source.classes[int(current.source.current)]
	for flag in ["PickDomains","PickSchool"]:
		var read:=Tables.integer(tables.classes,class_id,flag)
		if not read.ready or not read.ok:return {"ready":false}
		if int(read.value)==0:continue
		if flag=="PickDomains" and domains.is_empty():
			if not cls.get("domains") is Array or cls.domains.size()!=2 or cls.domains.any(func(id):return not Classes.integer(id,0,255)):return {"ready":false}
			domains=cls.domains.duplicate()
		if flag=="PickSchool" and selected_school<0:
			if not Classes.integer(cls.get("school"),0,255):return {"ready":false}
			school=int(cls.school)
	var result:=private_draft();result.erase("scope");result.erase("selectedFeats");result.erase("domainGrants");var copied: Dictionary=result.receivedFields;result.erase("receivedFields")
	if not Classes.integer(copied.get("fieldE34"),-2147483648,2147483647) or not Classes.integer(copied.get("fieldE30"),-2147483648,2147483647) or not copied.get("fieldE48") is String or not copied.get("fieldE38") is String:return {"ready":false}
	result.merge(copied);result.merge({"hitDie":int(finalization.hitDie),"feats":acquired,"domains":domains,"school":school},true)
	# This proposal is reachable only when no unbound class-dependent child
	# interrupted the route; source child commits will extend it separately.
	return {"ready":true,"proposal":result}
func submit(ticket: Array) -> void:
	if not current(ticket) or navigation.stage!="summary":return
	var value:=proposal()
	if not value.ready:return
	var send:=navigation.submit(navigation.ticket)
	if send.send:submission_requested.emit(value.proposal,token,identity.duplicate())
func cancelled(ticket: Array) -> void:
	if not current(ticket):return
	var value:=navigation.cancel(navigation.ticket)
	if not value.get("cancel",false):return
	var old_token:=token;var old_identity:=identity.duplicate();var pending: bool=value.submissionPending;close();cancellation_requested.emit(old_token,old_identity,pending)
func cancel_preparation(ticket: Array) -> bool:
	# A future bound child/preparation surface uses the navigation ticket;
	# it cannot borrow a now-dismissed preceding pane's frontend ticket.
	if not wanted or navigation.stage not in ["post","domains","school","spells","associate"] or navigation.ticket!=ticket:return false
	var value:=navigation.cancel(ticket)
	if not value.get("cancel",false):return false
	var old_token:=token;var old_identity:=identity.duplicate();close();cancellation_requested.emit(old_token,old_identity,false);return true
func close() -> void:
	class_publication.reset()
	if frontend!=null:frontend.dismiss()
	if is_instance_valid(associate_jobs):associate_jobs.retire()
	wanted=false;navigation.close();received={};context={};class_context={};tables={};text=null;art=null;identity=[];token=-1;class_id=-1;attributes.selected=-1;skills=Skills.new();feats=Feats.new();spells=Spells.new();known_delta={};removed_delta={};selected_domains=[];selected_school=-1;domain_grants=[];associate_value={};finalization={};initial_tables={}
	recommendation_pending=false;recommendation_diagnostics={}
	class_preparing=false;pending_class_id=-1;pending_class_ticket=[];class_inputs={};class_focus_id=-1;class_error="";class_diagnostics={}
