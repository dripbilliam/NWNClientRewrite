extends Node
# Runtime presentation adapter. Session remains the only network transaction
# source_owner; this node emits typed intents with the captured area/actor identity.
signal command_requested(message: Dictionary,identity: Array)
signal fallback_requested(result: Dictionary,private_draft: Dictionary,stage: String,reason: String)
signal cancelled
signal changed
const Front=preload("res://systems/native_level_up_frontend.gd")
const Owner=preload("res://systems/native_data/level_up_source_owner.gd")
const HitDieOwner=preload("res://systems/native_data/level_up_hit_die_owner.gd")
const NativeRandom=preload("res://systems/native_data/native_client_random.gd")
const ContextWait=preload("res://systems/native_data/level_up_context_wait.gd")
const Summary=preload("res://systems/native_data/level_up_summary_model.gd")
const Flags=preload("res://systems/native_data/level_up_module_context.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Scalars=preload("res://systems/native_data/level_up_class_state.gd")
const RulePublication=preload("res://systems/native_data/level_up_rule_publication.gd")
const RecommendationWork=preload("res://systems/native_level_up_recommendation_work.gd")
const TitleContext=preload("res://systems/native_data/level_up_title_context.gd")
const TitleVitals=preload("res://systems/native_data/level_up_vitals.gd")
const SourceWitness=preload("res://systems/native_data/level_up_finalization_witness.gd")
const DefinitionsWork=preload("res://systems/native_level_up_definitions_work.gd")
var frontend
var source_owner:=Owner.new()
var active:=false
var closed:=false
var result: Dictionary={}
var identity: Array=[]
var module_context: Dictionary={}
var text
var art
var tables: Dictionary={}
var current_identity: Callable
var fallback_pending:=false
var rule_publication:=RulePublication.new()
var rules_scope: Array=[]
var rules_version:=-1
var raw_tables: Dictionary={}
var publication_assets
var publication_text_revision:=-1
var active_catalog
var current_catalog_reader: Callable
var current_module_reader: Callable
var current_actor_reader: Callable
var diagnostic_scope: Array=[]
var finalization_diagnostics: Dictionary={}
var context_wait:=ContextWait.new()
var context_ticket: Array=[]
var hit_die_owner:=HitDieOwner.new()
var catalog_cache
var catalog_generation:=-1
var cache_directory:=""
var recommendation_work
var source_title_context:=TitleContext.new()
var definitions_work
var pending_class_completion: Dictionary={}
func configure(painter,base_text,base_catalog,active_catalog,cache_path: String,order,surfaces,scope_reader: Callable,catalog_reader: Callable=Callable(),module_reader: Callable=Callable(),actor_reader: Callable=Callable()) -> void:
	if closed or is_instance_valid(frontend):return
	current_identity=scope_reader;frontend=Front.new();add_child(frontend);frontend.configure(painter,base_text,base_catalog,cache_path);frontend.configure_owners(order,surfaces);source_owner.configure(frontend);source_owner.configure_jobs(active_catalog,cache_path)
	self.active_catalog=active_catalog;current_catalog_reader=catalog_reader;current_module_reader=module_reader;cache_directory=cache_path
	current_actor_reader=actor_reader;frontend.cancelled.connect(cancel_waiting)
	frontend.configure_title_reader(source_title_payload)
	source_owner.submission_requested.connect(submit);source_owner.cancellation_requested.connect(cancel);source_owner.summary_requested.connect(finalize)
	source_owner.state_changed.connect(state_changed);source_owner.child_requested.connect(unbound_child);frontend.unavailable.connect(unavailable)
	source_owner.recommendation_requested.connect(recommend)
	source_owner.class_rules_requested.connect(prepare_class)
	definitions_work=DefinitionsWork.new();add_child(definitions_work);definitions_work.completed.connect(definitions_prepared);source_owner.configure_definitions(read_definitions)
func read_catalog() -> Object:
	var value: Variant=current_catalog_reader.call() if current_catalog_reader.is_valid() else active_catalog
	return value if typeof(value)==TYPE_OBJECT and is_instance_valid(value) else null
func read_module_context() -> Dictionary:
	return Flags.compose(current_module_reader.call()) if current_module_reader.is_valid() else module_context.duplicate()
func read_actor() -> Dictionary:
	var value: Variant=current_actor_reader.call() if current_actor_reader.is_valid() else null
	return value if value is Dictionary else {}
func enable_source_probe_diagnostics(scope: Array) -> bool:
	if not owns() or not current_catalog() or scope!=rules_scope:return false
	if diagnostic_scope!=scope:diagnostic_scope=scope.duplicate();finalization_diagnostics={}
	return true
func finalization_diagnostic(ticket: Array) -> Dictionary:
	if not owns() or not current_catalog() or diagnostic_scope!=rules_scope or ticket!=source_owner.navigation.ticket or finalization_diagnostics.get("scope")!=rules_scope or finalization_diagnostics.get("ticket")!=ticket:return {"ready":false,"reason":"Retired source diagnostic witness."}
	return finalization_diagnostics.duplicate(true)
func source_title_payload(ticket: Array) -> Dictionary:
	if not owns() or not current_catalog() or not is_instance_valid(frontend) or not frontend.owns(ticket) or not source_owner.wanted or not Scalars.integer(source_owner.class_id,0,254):return TitleContext.pending("The private source-title scope is unavailable.")
	var names: Dictionary=source_title_context.resolve(read_actor(),identity,int(result.token),text)
	if not names.ready:return names
	var advanced: Dictionary=TitleVitals.next_classes(source_owner.received,source_owner.class_id)
	if not advanced.ready:return advanced
	return {"ready":true,"parts":names.parts,"classes":advanced.classes,"tables":tables,"text":text}
func capture_catalog() -> bool:
	active_catalog=read_catalog();catalog_cache=null;catalog_generation=-1
	if active_catalog==null:return false
	if active_catalog.has_method("preparation_cache"):
		catalog_cache=active_catalog.preparation_cache()
		if is_instance_valid(catalog_cache) and catalog_cache.has_method("generation"):catalog_generation=int(catalog_cache.generation())
	return true
func current_catalog() -> bool:
	if active_catalog==null or read_catalog()!=active_catalog:return false
	if active_catalog.has_method("preparation_cache"):
		var cache=active_catalog.preparation_cache()
		if cache!=catalog_cache:return false
		if catalog_generation>=0 and (not is_instance_valid(cache) or not cache.has_method("generation") or int(cache.generation())!=catalog_generation):return false
	return true
func warm_definitions() -> void:
	if owns() and current_catalog() and not rules_scope.is_empty() and is_instance_valid(definitions_work):definitions_work.warm(rules_scope,active_catalog,catalog_generation,tables.get("feat"))
func read_definitions() -> Dictionary:
	if not owns() or not current_catalog() or not is_instance_valid(definitions_work):return {"ready":false,"pending":true,"reason":"Private feat definitions have no current level-up owner."}
	return definitions_work.view(rules_scope,active_catalog,catalog_generation,tables.get("feat"))
func complete_class_rules(value: Dictionary,request: int,ticket: Array) -> void:
	if not value.get("ready",false):source_owner.class_rules_result(value,ticket);return
	var decoded:=read_definitions()
	if decoded.get("ready",false):source_owner.class_rules_result(value,ticket);return
	if not decoded.get("pending",false):source_owner.class_rules_result(decoded,ticket);return
	# Resource loading and plain definitions are independent data jobs. Holding
	# this compact admission result neither publishes tables nor commits Class.
	pending_class_completion={"scope":rules_scope.duplicate(),"ticket":ticket.duplicate(),"classId":source_owner.pending_class_id,"request":request,"catalog":active_catalog,"generation":catalog_generation,"feat":tables.get("feat"),"value":{"ready":true,"elapsedUsec":value.get("elapsedUsec",0),"diagnostics":value.get("diagnostics",{}).duplicate(true)}}
func definitions_prepared(_request: int) -> void:
	if pending_class_completion.is_empty() or not owns() or not current_catalog() or not refresh_rule_view():return
	var held:=pending_class_completion
	# A genuinely absent table may arrive after the class resources. A captured
	# present publication may never be replaced. read_definitions still checks
	# the exact current physical table and accepted worker key in either case.
	if held.scope!=rules_scope or held.catalog!=active_catalog or int(held.generation)!=catalog_generation or held.feat!=null and not is_same(held.feat,tables.get("feat")) or not source_owner.class_preparing or int(held.classId)!=source_owner.pending_class_id or not source_owner.current(held.ticket) or not is_instance_valid(recommendation_work) or int(held.request)!=recommendation_work.serial:return
	pending_class_completion={};complete_class_rules(held.value,int(held.request),held.ticket)
func recommend(stage: String,ticket: Array) -> void:
	if not owns() or not refresh_rule_view() or not source_owner.current(ticket):return
	if not is_instance_valid(recommendation_work):
		recommendation_work=RecommendationWork.new();add_child(recommendation_work);recommendation_work.configure(active_catalog,cache_directory,publish_recommendation_dependency);recommendation_work.reset_choices.connect(reset_recommended_choices);recommendation_work.completed.connect(recommended)
	var selected_class: int=source_owner.pending_class_id if stage=="class" else source_owner.class_id
	var request: int=recommendation_work.start(stage,source_owner.received,selected_class,tables,rules_scope,ticket,source_owner.recommendation_context(stage))
	if not rule_publication.open_private_request(rules_scope,active_catalog,request):
		recommendation_work.cancel()
		if stage=="class":source_owner.class_rules_result({"ready":false,"reason":"Class choices are unavailable."},ticket)
		else:source_owner.recommendation_result(stage,{"ready":false,"reason":"Recommended choices are unavailable."},ticket)
func prepare_class(ticket: Array) -> void:
	pending_class_completion={};warm_definitions();recommend("class",ticket)
func publish_recommendation_dependency(name: String,value: Dictionary,request: int,scope: Array,catalog: Object) -> Dictionary:
	if not owns() or scope!=rules_scope or catalog!=active_catalog or not is_instance_valid(recommendation_work) or request!=recommendation_work.serial or not recommendation_work.wanted or not source_owner.current(recommendation_work.ticket) or not refresh_rule_view():return {"ready":false}
	# An authoritative publication that won the race always keeps ownership.
	if raw_tables.has(name):return {"ready":true,"tables":tables}
	var published:=rule_publication.publish_private(name,value,scope,catalog,request)
	if not published.ready or not refresh_rule_view():return {"ready":false}
	return {"ready":true,"tables":tables}
func reset_recommended_choices(stage: String,request: int,ticket: Array) -> void:
	if owns() and is_instance_valid(recommendation_work) and request==recommendation_work.serial and source_owner.current(ticket) and refresh_rule_view():source_owner.reset_recommended_choices(stage,ticket)
func recommended(stage: String,value: Dictionary,request: int,ticket: Array) -> void:
	if not owns() or not is_instance_valid(recommendation_work) or request!=recommendation_work.serial or not source_owner.current(ticket):return
	rule_publication.finish_private_request(rules_scope,active_catalog,request)
	if refresh_rule_view():
		if stage=="class":complete_class_rules(value,request,ticket)
		else:source_owner.recommendation_result(stage,value,ticket)
func watch_tables(publisher: Object) -> void:
	if is_instance_valid(publication_assets) and publication_assets.completed.is_connected(table_published):publication_assets.completed.disconnect(table_published)
	publication_assets=publisher if is_instance_valid(publisher) and publisher.has_signal("completed") else null
	if is_instance_valid(publication_assets):publication_assets.completed.connect(table_published)
func table_published(_id: int,_value: Dictionary) -> void:
	# Gameplay connects its accepted-table publisher before the late source
	# configure hook connects this observer. No renderer-frame polling is used.
	if not owns():return
	var before:=rules_version;var revision: int=int(text.revision)
	var names_changed: bool=revision!=publication_text_revision;publication_text_revision=revision
	if refresh_rule_view() and before==rules_version and names_changed and source_owner.wanted and source_owner.class_id<0:source_owner.show_class()
func refresh_rule_view() -> bool:
	if not owns() or rules_scope.is_empty():return false
	if not current_catalog():
		if source_owner.class_preparing:cancel(int(result.token),identity,false)
		else:defer_fallback("Active level-up resources changed. Reopen Level Up to use them.")
		return false
	var value:=rule_publication.publish(raw_tables,rules_scope)
	if not value.ready:defer_fallback(str(value.reason));return false
	if rules_version!=int(value.publication):
		rules_version=int(value.publication);tables=value.tables;source_owner.tables=tables
		warm_definitions()
		if source_owner.wanted:
			if source_owner.class_id<0:source_owner.show_class()
	if source_owner.class_preparing and not source_owner.class_rules_current():cancel(int(result.token),identity,false);return false
	if source_owner.wanted and source_owner.class_id>=0 and not source_owner.same_rules():defer_fallback("Active level-up rules changed. Reopen Level Up to use them.");return false
	return rule_publication.current(raw_tables,rules_scope,rules_version)
func owns() -> bool:return not closed and active and not identity.is_empty() and current_identity.is_valid() and current_identity.call()==identity
func begin(value: Dictionary,scope: Array,active_tables: Dictionary,active_text,active_art,module: Dictionary) -> bool:
	retire()
	if not is_instance_valid(frontend) or scope.size()!=3 or not current_identity.is_valid() or current_identity.call()!=scope or value.get("snapshot",{}).get("actorId")!=scope[2] or not Scalars.integer(value.get("token"),0,9007199254740991):return false
	result=value.duplicate(true);identity=scope.duplicate();raw_tables=active_tables;tables=active_tables;text=active_text;art=active_art;module_context=Flags.compose(module);active=true;fallback_pending=false
	if not capture_catalog():fallback("Active level-up resources are unavailable.");return false
	source_owner.configure_jobs(active_catalog,cache_directory)
	if is_instance_valid(recommendation_work):recommendation_work.configure(active_catalog,cache_directory,publish_recommendation_dependency)
	if not module_context.hideHitPointGain is bool:fallback("Received level-up display rules are still being prepared.");return false
	for cls in value.get("snapshot",{}).get("classes",[]):
		if not cls is Dictionary or not Scalars.integer(cls.get("level"),1,254):fallback("Received class data is unavailable.");return false
	rules_scope=identity+[int(value.token)];var published:=rule_publication.begin(raw_tables,rules_scope,active_catalog)
	if not published.ready:fallback(str(published.reason));return false
	tables=published.tables;rules_version=int(published.publication);publication_text_revision=int(text.revision);warm_definitions()
	var context: Variant=value.get("draftContext")
	if not context is Dictionary or not Scalars.integer(context.get("baseFortitude"),-128,127):
		frontend.present_waiting(text,art,rules_scope+["received-context"],"Waiting for character data…");context_ticket=frontend.ticket.duplicate()
		var waiting:=context_wait.capture(result,identity,frontend.serial,read_actor())
		if not context_wait.armed:fallback(str(waiting.reason));return false
		observe_received();changed.emit();return owns()
	return start_source()
func start_source() -> bool:
	if not owns() or not current_catalog():return false
	module_context=read_module_context()
	if not module_context.hideHitPointGain is bool:fallback("Received level-up display rules are still being prepared.");return false
	if not hit_die_owner.begin(rules_scope,NativeRandom.acquire()):fallback("Native level-up random state is unavailable.");return false
	#837f60 copies the three private name strings. Their received projection is
	# detached here; missing presentation fields never block source navigation.
	source_title_context.capture(read_actor(),identity,int(result.token),text)
	var started:=source_owner.begin(result,identity,tables,text,art)
	if not started.ready:fallback(str(started.get("reason","Level-up choices are being prepared.")));return false
	changed.emit();return true
func observe_received() -> void:
	# Called at accepted object-publication boundaries, never a frame scan.
	if not owns() or not context_wait.armed:return
	if not current_catalog() or not frontend.owns(context_ticket):cancel(int(result.token),identity,false);return
	if not refresh_rule_view():return
	var observed:=context_wait.consume(identity,int(result.token),frontend.serial,read_actor())
	if observed.ready:
		result=observed.result;context_ticket=[];start_source()
	elif not observed.waiting:cancel(int(result.token),identity,false)
func cancel_waiting(ticket: Array) -> void:
	if owns() and context_wait.armed and ticket==context_ticket and frontend.owns(ticket):cancel(int(result.token),identity,false)
func state_changed(_stage: String,ready: bool,reason: String) -> void:
	if owns() and not ready:defer_fallback(reason)
	changed.emit()
func unbound_child(_stage: String,_model: Dictionary,_ticket: Array) -> void:defer_fallback("This class needs the standard level-up editor.")
func unavailable(_stage: String,reason: String,_ticket: Array) -> void:defer_fallback(reason)
func defer_fallback(reason: String) -> void:
	if not owns() or fallback_pending:return
	fallback_pending=true;var captured:=rules_scope.duplicate();apply_fallback.call_deferred(captured,reason)
func apply_fallback(captured: Array,reason: String) -> void:
	if owns() and rules_scope==captured:fallback(reason)
func fallback(reason: String) -> void:
	if not owns():retire();return
	var old_result:=result.duplicate(true);var draft:=source_owner.private_draft() if source_owner.wanted and source_owner.class_id>=0 else {};var stage:=source_owner.navigation.stage
	retire();fallback_requested.emit(old_result,draft,stage,reason)
func primary_feats() -> Array:
	var prepared: Dictionary=source_owner.snapshot(source_owner.feats.selected)
	if not prepared.ready:return []
	var values: Array=prepared.source.owned+source_owner.feats.selected
	for id in source_owner.domain_grants:
		if not values.has(id):values.append(id)
	return values
func finalize(_draft: Dictionary,ticket: Array) -> void:
	if not owns() or not refresh_rule_view() or source_owner.navigation.submitted:return
	var private:=source_owner.finalization_snapshot(ticket);var application:=read_module_context();var rolled:=hit_die_owner.roll(ticket,private,tables,application)
	if not rolled.ready:defer_fallback(str(rolled.get("reason","Level-up final rules are unavailable.")));return
	if not Scalars.integer(rolled.get("hitDie"),1,255):defer_fallback("Active native hit-die result cannot be submitted.");return
	var known: Variant=null
	if source_owner.spells.current(tables):known=source_owner.spells.state.known
	elif private.get("ready",false):
		var index:=int(private.source.current);var cls: Dictionary=private.source.classes[index]
		var before: Dictionary=Summary.known(source_owner.received,index,int(cls.id),tables)
		if before.ready:known=before.value
	var primary: Array=primary_feats()
	var review: Dictionary=Summary.compose(source_owner.received,private,source_owner.skills.ranks,primary,known,int(rolled.hitDie),application.hideHitPointGain,tables,text)
	if not review.ready:defer_fallback(str(review.get("reason","Level-up review rules are unavailable.")));return
	if not source_owner.set_summary(review,ticket):return
	if diagnostic_scope==rules_scope:finalization_diagnostics=SourceWitness.capture(rules_scope,ticket,private,primary,application,review,Values.cfg(tables,"FEAT_TOUGHNESS_HP_BONUS",1))
	changed.emit()
func submit(proposal: Dictionary,token: int,scope: Array) -> void:
	if not owns() or scope!=identity or token!=int(result.token) or not refresh_rule_view():return
	var ticket: Array=source_owner.navigation.ticket;var private:=source_owner.finalization_snapshot(ticket)
	if not hit_die_owner.current(ticket,private,tables,read_module_context()):defer_fallback("Active level-up die/display rules changed. Reopen Level Up to use them.");return
	command_requested.emit({"kind":"native-level-up","operation":"submit","token":token,"proposal":proposal.duplicate(true)},identity.duplicate());changed.emit()
func cancel(token: int,scope: Array,_pending: bool) -> void:
	if not owns() or scope!=identity or token!=int(result.token):return
	var captured:=identity.duplicate();retire();command_requested.emit({"kind":"native-level-up","operation":"cancel","token":token},captured);cancelled.emit()
func notice(message: String) -> void:
	if not owns():return
	if frontend.stage=="summary" and frontend.panes.has("summary"):
		var pane=frontend.panes.summary;pane.summary+="\n\n"+message;pane.submitted=true;pane.refresh()
func rejected(message: String) -> void:
	if not owns() or not source_owner.navigation.submitted:return
	source_owner.navigation.result_received=true;notice(message)
func reopen() -> void:
	if owns() and is_instance_valid(frontend.surface):frontend.surface.show()
func retire() -> void:
	diagnostic_scope=[];finalization_diagnostics={}
	pending_class_completion={}
	if is_instance_valid(recommendation_work):recommendation_work.cancel()
	hit_die_owner.retire()
	source_title_context.close()
	context_wait.close();context_ticket=[]
	active=false;fallback_pending=false;identity=[];rules_scope=[];rules_version=-1;publication_text_revision=-1;rule_publication.retire();raw_tables={};result={};module_context={};tables={};text=null;art=null;catalog_cache=null;catalog_generation=-1;source_owner.close()
	if is_instance_valid(definitions_work):definitions_work.retire()
	changed.emit()
func close() -> void:
	if closed:return
	retire();closed=true
	watch_tables(null)
	if is_instance_valid(recommendation_work):recommendation_work.close()
	if is_instance_valid(definitions_work):definitions_work.close()
	source_owner.configure_definitions(Callable())
	if is_instance_valid(frontend):frontend.close()
	current_catalog_reader=Callable();current_module_reader=Callable();current_actor_reader=Callable();current_identity=Callable();active_catalog=null
func _exit_tree() -> void:close()
