extends Node
# Native connection-owned creator; JavaScript receives only a finished BIC.
signal request(message: Dictionary)
signal closed
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Builder=preload("res://systems/native_data/creation_bic.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const ClassMetadata=preload("res://systems/native_data/creation_class_metadata.gd")
const STEPS=["Gender","Race","Portrait","Class","Alignment","Package","Abilities","Domains & school","Skills","Feats","Spells","Appearance","Voice","Name","Review"]
var rules:=Rules.new()
var ui
var view
var assets
var connection:=-1
var phase:="closed"
var step:=0
var serial:=0
var controls: Dictionary={}
var resource_queue: Array=[]
var jobs: Dictionary={}
var requested: Dictionary={}
var resource_errors: Array=[]
var dependencies:=false
var status:=""
var feat_kind:="bonus"
var filter:=""
var show_unavailable:=false
var portrait_page:=0
var build_task:=-1
var build_result: Dictionary={}
var build_timings: Dictionary={}
var draft_scope:=0
var dead:=false
var preview
var voice
var tail
var source_frontend
var source_entered: Array=[]
var source_fallback:=false
var source_portrait_signature: Array=[]
var source_text_revision:=-1
var summary_projection_key: Array=[]
var summary_projection: Dictionary={}
var source_projection_stats: Dictionary={"bindings":{},"summaryBuilds":0,"summaryHits":0,"lastRefreshMs":0.0}
var package_request:=0
var package_names
var source_classes_raw: Dictionary={}
var source_class_compiles:=0
var source_class_error:=""
var source_table_sources: Dictionary={}
var source_table_views: Dictionary={}
var source_tables_revision:=-1
var skills_request:=0
var feats_request:=0
var source_feats:=preload("res://systems/native_data/creation_feat_state.gd").new()
var source_post:=preload("res://systems/native_data/creation_post_feats.gd").new()
var source_spells:=preload("res://systems/native_data/creation_spell_selection.gd").new()
var spells_request:=0
var spells_status: Dictionary={"ready":false}
var associate_names
var associate_name_request: Dictionary={}
var associate_name_jobs: Dictionary={}
var associate_templates: Dictionary={}
var associate_preview: Dictionary={}
var associate_work
var associate_table_revision:=0
const SummaryValues=preload("res://systems/native_data/creation_summary_values.gd")
func summary_identity() -> Array: return [connection,draft_scope]
func configure_source(painter,text,base_catalog,cache_path: String) -> void:
	if dead or is_instance_valid(source_frontend): return
	source_frontend=preload("res://systems/native_creation_frontend.gd").new(); add_child(source_frontend); source_frontend.configure(painter,text,base_catalog,cache_path)
	source_frontend.finished.connect(source_finished)
	source_frontend.command_requested.connect(source_command)
	source_frontend.status_dismissed.connect(source_status_dismissed)
	source_frontend.child_requested.connect(source_child_requested)
	source_frontend.main.prepared.connect(try_enter_source)
	tail=preload("res://systems/native_creation_tail.gd").new();add_child(tail);tail.configure(self,painter,text,base_catalog,cache_path)
	source_frontend.gender.set_modal_owner(ui.modal_order,"other")
	ui.modal_surfaces.bind_layer(source_frontend.gender,source_frontend)
	source_frontend.portrait.set_modal_owner(ui.modal_order,"other")
	ui.modal_surfaces.bind_layer(source_frontend.portrait,source_frontend)
	source_frontend.race.set_modal_owner(ui.modal_order,"other")
	ui.modal_surfaces.bind_layer(source_frontend.race,source_frontend)
	source_frontend.race.subrace.set_modal_owner(ui.modal_order,"other")
	ui.modal_surfaces.bind_layer(source_frontend.race.subrace,source_frontend)
	source_frontend.class_chooser.set_modal_owner(ui.modal_order,"other")
	ui.modal_surfaces.bind_layer(source_frontend.class_chooser,source_frontend)
	source_frontend.alignment.set_modal_owner(ui.modal_order,"other")
	ui.modal_surfaces.bind_layer(source_frontend.alignment,source_frontend)
	source_frontend.packages.set_modal_owner(ui.modal_order,"other")
	ui.modal_surfaces.bind_layer(source_frontend.packages,source_frontend)
	source_frontend.skills.set_modal_owner(ui.modal_order,"other")
	ui.modal_surfaces.bind_layer(source_frontend.skills,source_frontend)
	source_frontend.feats.set_modal_owner(ui.modal_order,"other")
	ui.modal_surfaces.bind_layer(source_frontend.feats,source_frontend)
	source_frontend.feats.info_popup.set_modal_order(ui.modal_order);source_frontend.feats.group_popup.set_modal_order(ui.modal_order)
	ui.modal_surfaces.bind_layer(source_frontend.feats.info_popup,source_frontend);ui.modal_surfaces.bind_layer(source_frontend.feats.group_popup,source_frontend)
	source_frontend.spells.info_popup.set_modal_order(ui.modal_order)
	ui.modal_surfaces.bind_layer(source_frontend.spells.info_popup,source_frontend)
	source_frontend.associate.info_popup.set_modal_order(ui.modal_order)
	ui.modal_surfaces.bind_layer(source_frontend.associate.info_popup,source_frontend)
	if phase!="closed": stage_source(); refresh_source()
func try_enter_source() -> void:
	if dead or phase!="editing" or not is_instance_valid(source_frontend) or source_entered==summary_identity() or not source_frontend.main.layout_ready:return
	var identity:=summary_identity();source_entered=identity.duplicate();source_fallback=false
	# The generic wizard supplied placeholder names. The original chooser
	# generates an actual active-LTR name when an unedited new name is empty.
	if rules.draft.get("familiarName")=="Familiar":rules.draft.familiarName=""
	if rules.draft.get("companionName")=="Companion":rules.draft.companionName=""
	refresh_source();view.reset()
	source_frontend.begin(identity,{"classBase":int(rules.draft.get("classId",-1))},rules.rows("classes"))
func source_finished(cancelled: bool,identity: Array) -> void:
	if dead or phase=="closed" or identity!=summary_identity() or source_entered!=identity:return
	if cancelled and phase!="waiting":cancel()
func source_status_dismissed(value: String,identity: Array) -> void:
	if dead or phase!="editing" or identity!=summary_identity() or source_entered!=identity or value!=status:return
	status="";render()
func source_command(operation: String,identity: Array) -> void:
	if dead or phase!="editing" or identity!=summary_identity() or source_entered!=identity:return
	match operation:
		"refresh":render()
		"reset_derived":rules.reset_choices();source_post.reset();source_spells.close();spells_status={"ready":false}
		"retire_draft":source_spells.close();source_post.reset();spells_status={"ready":false}
		"initialize_draft":rules.initialize()
		"finish":
			# The detached BIC worker is the validation owner. Its current-scope
			# result restores editing with the exact failure; input never repeats it.
			phase="preparing";status="Preparing your character…";package_tables();begin_build();render()
func source_child_requested(tag: String,value_ticket: Array) -> void:
	if dead or phase!="editing" or not source_frontend.owns(value_ticket) or source_entered!=summary_identity():return
	if tag not in ["appearance","customizebutton"]:return
	if is_instance_valid(tail):tail.open(value_ticket)
func stage_source() -> void:
	if not is_instance_valid(source_frontend): return
	source_portrait_signature=[]
	source_frontend.stage_draft(summary_identity(),{"classBase":int(rules.draft.get("classId",-1))},rules.rows("classes"))
	source_frontend.bind_summary(summary_identity(),summary_source,ui.desktop.art)
func summary_source(identity: Array,mask: int,prefix: String) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity() or rules.draft.is_empty(): return {}
	var projection_key:=identity+[mask,prefix,serial,int(ui.text.revision),associate_table_revision]
	if projection_key==summary_projection_key:source_projection_stats.summaryHits+=1;return summary_projection.duplicate(true)
	source_projection_stats.summaryBuilds+=1
	var d: Dictionary=rules.draft; var source:={"prefix":prefix,"name":SummaryValues.full_name(str(d.firstName),str(d.lastName)),"race":str(d.subrace),"scores":[],"adjustments":[0,0,0,0,0,0]}
	if source.race.is_empty(): source.race=ui.text.raw({"strRef":rules.num(rules.race(),"Name",4294967295)})
	var ge:=int(d.goodEvil); var lc:=int(d.lawChaos); var good:=2 if ge<31 else 0 if ge>69 else 1; var law:=2 if lc<31 else 0 if lc>69 else 1
	source.alignment=ui.text.raw({"strRef":112+law*3+good})
	source["class"]=ui.text.raw({"strRef":rules.num(rules.cls(),"Name",4294967295)})+" (1)"
	var scores:=rules.abilities()
	for key in Rules.ABILITIES: source.scores.append(int(scores[key])&255)
	var vitals:=Rules.Vitals.project({"classId":int(d.classId),"race":int(d.raceId),"abilities":d.abilities,"dexterityAdjustment":0},rules.tables,rules.creation_base_hp)
	if vitals.ready: source.merge(vitals.fields)
	var result:=SummaryValues.compose(source,mask,rules.tables)
	result.scope=identity.duplicate(); result.draft_revision=serial; result.portrait=str(d.portrait)+"l" if not str(d.portrait).is_empty() else ""
	result.lists=preload("res://systems/native_data/creation_summary_lists.gd").compose(rules,ui.desktop.rules)
	result.text_revision=int(ui.text.revision)
	result.pending.append_array(["details","experience"])
	for page in ["1","2","3"]:
		if not result.lists[page].ready: result.pending.append({"1":"skills","2":"feats","3":"spells"}[page])
	summary_projection_key=projection_key;summary_projection=result.duplicate(true);return result
func commit_source_portrait(base: String,identity: Array) -> bool:
	if dead or phase!="editing" or identity!=summary_identity() or not rules.portraits().has(base): return false
	rules.draft.portrait=base; render(); return true
func commit_source_gender(selected: int,identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity() or selected not in [-1,0,1]:return {}
	var choice:=preload("res://systems/native_data/creation_gender_state.gd").new();choice.selected=selected
	var result:=choice.result(int(rules.draft.gender));rules.draft.gender=int(result.gender);render()
	result.accepted=true;return result
func commit_source_race(selected: int,subrace_value: Variant,identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity() or not (subrace_value==null or subrace_value is String):return {}
	# Subrace's original accepted callback writes text before calling Race OK;
	# an invalid list selection can therefore retain text without finishing.
	if subrace_value is String:rules.draft.subrace=subrace_value
	if not rules.select_race(selected,ui.text,subrace_value):render();return {"accepted":false,"subrace":str(rules.draft.subrace)}
	if is_instance_valid(source_frontend) and source_frontend.flow.enabled.packages:rules.reset_choices()
	render();return {"accepted":true,"race":selected,"subrace":str(rules.draft.subrace),"code":0x800a}
func source_binding_needed(tag: String,active: String) -> bool:
	if not active.is_empty() and active!=tag:return false
	source_projection_stats.bindings[tag]=int(source_projection_stats.bindings.get(tag,0))+1;return true
func refresh_source() -> void:
	if not is_instance_valid(source_frontend): return
	var began:=Time.get_ticks_usec();var active: String=source_frontend.child
	if phase=="editing":
		# Fine-grained child edits do not change every other screen's model.
		# Parent activation still republishes all contexts before another child
		# can open. No inactive menu scans the active feat/spell tables per click.
		if source_binding_needed("genderbutton",active):source_frontend.bind_gender(summary_identity(),int(rules.draft.gender),commit_source_gender)
		if source_binding_needed("racebutton",active):source_frontend.bind_races(summary_identity(),preload("res://systems/native_data/creation_race_state.gd").choices(rules.rows("racialtypes"),ui.text),int(rules.draft.raceId),str(rules.draft.subrace),rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)!=0,ui.text,ui.desktop.art,commit_source_race)
		if source_binding_needed("classbutton",active):source_frontend.bind_classes(summary_identity(),preload("res://systems/native_data/creation_class_state.gd").choices(rules,ui.text),rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)!=0,ui.text,ui.desktop.art,commit_source_class)
		if source_binding_needed("alignbutton",active):source_frontend.bind_alignment(summary_identity(),{"data":rules.cls().duplicate(true),"classId":int(rules.draft.classId),"goodEvil":int(rules.draft.goodEvil),"lawChaos":int(rules.draft.lawChaos)},rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)!=0,ui.text,commit_source_alignment)
		if source_binding_needed("abilitiesbutton",active):source_frontend.bind_attributes(summary_identity(),attribute_source_model(summary_identity()),rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)!=0,ui.text,edit_source_attributes,commit_source_attributes)
		if source_binding_needed("packagesbutton",active):source_frontend.bind_packages(summary_identity(),preload("res://systems/native_data/creation_package_state.gd").choices(rules,ui.text),rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)!=0,ui.text,ui.desktop.art,enter_source_packages,commit_source_package)
		if source_binding_needed("package-configuration",active):source_frontend.bind_skills(summary_identity(),skill_source_model(summary_identity()),rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)!=0,ui.text,ui.desktop.art,edit_source_skills,commit_source_skills)
		if source_binding_needed("package-feats",active):source_frontend.bind_feats(summary_identity(),feat_source_model(summary_identity()),rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)!=0,ui.text,ui.desktop.art,edit_source_feats,commit_source_feats)
		if source_binding_needed("package-school",active):source_frontend.bind_school(summary_identity(),preload("res://systems/native_data/creation_school_state.gd").choices(rules),rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)!=0,ui.text,commit_source_school)
		if source_binding_needed("package-domains",active):source_frontend.bind_domains(summary_identity(),preload("res://systems/native_data/creation_domains_state.gd").choices(rules,ui.text),rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)!=0,ui.text,ui.desktop.art,commit_source_domains)
		if source_binding_needed("package-spells",active):source_frontend.bind_spells(summary_identity(),spell_source_model(summary_identity()),rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)!=0,ui.text,ui.desktop.art,enter_source_spells,edit_source_spells,commit_source_spells)
		source_frontend.bind_post(summary_identity(),continue_source_creation)
		if source_binding_needed("package-associate",active):source_frontend.bind_associate(summary_identity(),associate_source_model(summary_identity()),ui.text,ui.desktop.art,associate_source_action,commit_source_associate)
		source_text_revision=int(ui.text.revision); source_frontend.classes=rules.rows("classes"); source_frontend.context.classBase=int(rules.draft.classId)
		var signature:=summary_identity()+[int(rules.draft.gender),int(rules.draft.raceId)]
		if source_binding_needed("portraitbutton",active) and signature!=source_portrait_signature:
			source_portrait_signature=signature; source_frontend.bind_portraits(summary_identity(),rules.portraits(),str(rules.draft.portrait),ui.desktop.art,ui.catalog,commit_source_portrait)
		else: source_frontend.current_portrait=str(rules.draft.portrait)
	source_frontend.refresh()
	source_projection_stats.lastRefreshMs=(Time.get_ticks_usec()-began)/1000.0
func commit_source_class(selected: int,identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity() or not rules.commit_class(selected):return {}
	if is_instance_valid(source_frontend) and source_frontend.flow.enabled.packages:rules.reset_choices()
	render();return {"accepted":true,"classId":selected,"code":0x8004}
func enter_source_packages(identity: Array) -> bool:
	if dead or phase!="editing" or identity!=summary_identity():return false
	#8e5770/8dc6d0 clears derived choices on entry, even on later Cancel.
	if not rules.reset_source_choices():return false
	source_post.reset()
	rules.draft.packageSource=true;rules.draft.packageEquipment=[];render();return true
func skill_source_model(identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity():return {"ready":false}
	return preload("res://systems/native_data/creation_skill_state.gd").compose(rules,ui.text)
func edit_source_skills(operation: String,id: int,identity: Array,value_ticket: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity() or not is_instance_valid(source_frontend) or not source_frontend.owns(value_ticket) or not skill_source_model(identity).get("ready",false):return {}
	if operation in ["up","down"]:
		rules.change_skill(id,1 if operation=="up" else -1);render();return skill_source_model(identity)
	if operation!="recommend" or rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)==0:return {}
	var package: Dictionary=rules.row("packages",int(rules.draft.packageId));var preferences:=preload("res://systems/native_data/creation_package_rules.gd").resource(rules,package,"SkillPref2DA")
	if preferences.is_empty():return skill_source_model(identity)
	skills_request+=1;var request_id:=skills_request;var text_revision: int=int(ui.text.revision);phase="skills-preparing";table(preferences)
	while not jobs.is_empty() or not resource_queue.is_empty():
		await get_tree().process_frame
		if dead or identity!=summary_identity() or phase!="skills-preparing" or request_id!=skills_request:return {}
		if not source_frontend.owns(value_ticket) or int(ui.text.revision)!=text_revision:
			phase="editing";render();return {}
	if dead or identity!=summary_identity() or request_id!=skills_request or not source_frontend.owns(value_ticket):return {}
	var points: Variant=rules.source_skill_budget()
	if points!=null:
		rules.draft.skills={};rules.record_skill_points(int(points));preload("res://systems/native_data/creation_package_rules.gd").recommend_skills(rules,package)
	phase="editing";render();return skill_source_model(identity)
func commit_source_skills(accepted: bool,identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity():return {}
	if not accepted:
		if not rules.reset_source_choices():return {}
		render();return {"accepted":true,"code":3}
	if not rules.commit_skill_summary():return {}
	source_feats.reset_selection()
	source_post.reset()
	var slots:=rules.feat_slots()
	if int(slots.normal)!=0 or int(slots.bonus)!=0:
		# Skills changed the next child's prerequisites. Publish the current
		# model before transferring its callback, rather than showing a cached
		# pre-Skills pane while discarding the warm immutable feat definitions.
		var feats_identity:=summary_identity()
		source_frontend.bind_feats(feats_identity,feat_source_model(feats_identity),rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)!=0,ui.text,ui.desktop.art,edit_source_feats,commit_source_feats)
	render()
	return {"accepted":true,"next":"package-feats" if int(slots.normal)!=0 or int(slots.bonus)!=0 else "package-post-skills"}
func feat_source_model(identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity():return {"ready":false}
	return source_feats.compose(rules,ui.text)
func edit_source_feats(operation: String,id: int,identity: Array,value_ticket: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity() or not is_instance_valid(source_frontend) or not source_frontend.owns(value_ticket):return {}
	if operation not in ["add","remove","reset","recommend"]:return {}
	var preferences:=""
	if operation=="recommend":
		if rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)==0:return {}
		preferences=preload("res://systems/native_data/creation_package_rules.gd").resource(rules,rules.row("packages",int(rules.draft.packageId)),"FeatPref2DA")
		if not preferences.is_empty():
			feats_request+=1;var request_id:=feats_request;var text_revision: int=int(ui.text.revision);phase="feats-preparing";table(preferences)
			while not jobs.is_empty() or not resource_queue.is_empty():
				await get_tree().process_frame
				if dead or identity!=summary_identity() or phase!="feats-preparing" or request_id!=feats_request:return {}
				if not source_frontend.owns(value_ticket) or int(ui.text.revision)!=text_revision:
					phase="editing";render();return {}
			if dead or identity!=summary_identity() or request_id!=feats_request or not source_frontend.owns(value_ticket):return {}
			phase="editing"
	var result:=source_feats.apply(operation,id,rules,ui.text,preferences);render();return result
func commit_source_feats(accepted: bool,identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity():return {}
	if not accepted:
		if not rules.reset_source_choices():return {}
		source_feats.reset_selection();render();return {"accepted":true,"code":3}
	var model:=feat_source_model(identity)
	if not model.get("ready",false) or not model.get("canAccept",false):return {}
	# Original9c8a90 commits the physical IDs of the displayed known rows,
	# whose granted duplicates already exist in the primary feat list.
	rules.draft.feats=[]
	for entry in model.known:
		if entry.enabled:rules.draft.feats.append({"id":int(entry.id),"kind":"source"})
	rules.draft.sourceFeatChoices=true;render()
	return {"accepted":true,"code":0x800e,"next":"package-post-skills"}
func continue_source_creation(identity: Array,code: int) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity():return {}
	var source:=preload("res://systems/native_data/creation_post_feats.gd").creation_source(rules)
	var result:=source_post.advance(source,code)
	if not result.get("ready",false):return result
	result.next="package-"+str(result.child) if not str(result.child).is_empty() else ""
	return result
func associate_source_model(identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity():return {}
	var context:=preload("res://systems/native_data/creation_post_feats.gd").creation_source(rules)
	if not context.has_all(["Arcane","MinAssociateLevel"]) or int(context.MinAssociateLevel)>1:return {}
	var state_script=preload("res://systems/native_data/creation_associate_state.gd");var kind:=state_script.kinds(int(context.Arcane));var name: String=kind.table
	table(name)
	var choices:=state_script.choices(rules.tables.get(name),context.Arcane,1,ui.text)
	return {"choices":choices,"storedType":rules.draft[kind.field],"name":rules.draft[kind.field+"Name"]}
func associate_request_current(value: Dictionary) -> bool:
	return not dead and phase=="editing" and not value.is_empty() and value.get("identity",[])==summary_identity() and is_instance_valid(source_frontend) and source_frontend.owns(value.get("ticket",[])) and source_frontend.child=="package-associate"
func associate_source_action(operation: String,value: Dictionary,identity: Array,value_ticket: Array) -> void:
	var capture:={"identity":identity.duplicate(),"ticket":value_ticket.duplicate(),"value":value.duplicate(true)}
	if not associate_request_current(capture):return
	var context:=preload("res://systems/native_data/creation_post_feats.gd").creation_source(rules)
	if not context.has("Arcane"):return
	var kind:=preload("res://systems/native_data/creation_associate_state.gd").kinds(int(context.Arcane))
	if operation=="enter":
		if int(value.get("arcane",-1))!=int(context.Arcane) or int(value.get("level",-1))!=1:return
		# Original9cc4f0 changes only the raw unset field here. The GUI's
		# visible index0 is mapped to its actual physical row for preview/OK.
		if int(rules.draft[kind.field])== -1:rules.draft[kind.field]=0
		source_frontend.associate_context.storedType=rules.draft[kind.field]
	elif operation=="name":rules.draft[kind.field+"Name"]=str(value.name)
	elif operation=="generate":associate_name_request=capture;dispatch_associate_name()
	elif operation=="preview":
		associate_preview=capture;var name:=str(value.resource)
		if associate_templates.has(name):project_associate()
		else:enqueue(name,2027,"associate",name)
func dispatch_associate_name(_prepared_scope: Array=[]) -> void:
	if not associate_request_current(associate_name_request):associate_name_request={};return
	if associate_names.scope!=summary_identity():associate_names.configure(ui.catalog,summary_identity())
	if not associate_names.failure.is_empty():
		var request: Dictionary=associate_name_request;associate_name_request={};source_frontend.associate.name_result({"ready":false,"reason":associate_names.failure},request.ticket,int(request.value.revision),bool(request.value.get("acceptAfter",false)));return
	if not associate_names.resources_ready:return
	var id: int=associate_names.request_name(summary_identity())
	if id>=0:associate_name_jobs[id]=associate_name_request;associate_name_request={}
func associate_name_ready(id: int,value: Dictionary) -> void:
	if not associate_name_jobs.has(id):return
	var request: Dictionary=associate_name_jobs[id];associate_name_jobs.erase(id)
	if not associate_request_current(request):return
	var accepted: bool=source_frontend.associate.name_result(value,request.ticket,int(request.value.revision),bool(request.value.get("acceptAfter",false)))
	if accepted and value.get("ready",false) and associate_request_current(request):
		var context:=preload("res://systems/native_data/creation_post_feats.gd").creation_source(rules)
		if context.has("Arcane"):rules.draft[preload("res://systems/native_data/creation_associate_state.gd").kinds(int(context.Arcane)).field+"Name"]=value.name
	dispatch_associate_name()
func project_associate() -> void:
	if not associate_request_current(associate_preview):associate_work.retire();return
	var name:=str(associate_preview.value.resource)
	if not associate_templates.has(name):return
	var source:=preload("res://systems/native_data/creation_associate_preview.gd").source(associate_templates[name])
	if not source.get("ready",false):return
	associate_work.observe(associate_preview.ticket+[int(associate_preview.value.selection),int(ui.text.revision)],source.value,rules.tables,associate_table_revision)
func associate_projected() -> void:
	if not associate_request_current(associate_preview):return
	var dependencies: Array=associate_work.result.get("dependencies",[])
	for name in dependencies:table(str(name))
	if not dependencies.is_empty():return
	var source:=preload("res://systems/native_data/creation_associate_preview.gd").source(associate_templates.get(str(associate_preview.value.resource),{}))
	if not source.get("ready",false):return
	var value:=preload("res://systems/native_data/creation_associate_preview.gd").compose(source.value,associate_work.result,ui.text,ui.desktop.rules,int(ui.text.revision))
	source_frontend.associate.present_preview(value,associate_preview.ticket,int(associate_preview.value.selection))
func commit_source_associate(accepted: bool,value: Dictionary,identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity():return {}
	if not accepted:
		if not rules.reset_source_choices():return {}
		source_post.reset();render();return {"accepted":true,"code":3}
	var model:=associate_source_model(identity);var state:=preload("res://systems/native_data/creation_associate_state.gd").new();state.configure(model.get("choices",{}),model.get("storedType"),model.get("name"))
	var ids: Array=state.entries.map(func(entry):return int(entry.id));var index:=ids.find(int(value.get("id",-1)))
	if not state.select_index(index) or not value.get("name") is String:return {}
	state.set_name(value.name);var committed:=state.commit()
	if not committed.get("ready",false) or committed.field!=value.get("field"):return {}
	rules.draft[committed.field]=int(committed.id);rules.draft[committed.field+"Name"]=committed.name;render()
	return {"accepted":true,"code":0,"next":"package-post-skills"}
func commit_source_school(accepted: bool,selected: int,identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity():return {}
	if not accepted:
		if not rules.reset_source_choices():return {}
		source_post.reset();source_feats.reset_selection();render();return {"accepted":true,"code":3}
	if selected<0 or selected>=9 or not preload("res://systems/native_data/creation_school_state.gd").choices(rules).get("ready",false):return {}
	var slots:=preload("res://systems/native_data/creation_feat_snapshot.gd").school_slot_reset(rules)
	if not slots.ready:return {}
	rules.draft.known={};rules.draft.memorized={};rules.creation_spell_slots=slots.counts.duplicate();rules.draft.sourceSpellSlots=true
	rules.draft.school=selected;render()
	return {"accepted":true,"code":0x800f,"next":"package-post-skills"}
func commit_source_domains(accepted: bool,selected: Array,identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity():return {}
	if not accepted:
		if not rules.reset_source_choices():return {}
		source_post.reset();source_feats=preload("res://systems/native_data/creation_feat_state.gd").new();render();return {"accepted":true,"code":3}
	var model:=preload("res://systems/native_data/creation_domains_state.gd").choices(rules,ui.text)
	if not model.ready or selected.size()!=2:return {}
	var ids: Array=[]
	for value in selected:
		if not preload("res://systems/native_data/creation_post_feats.gd").numeric(value):return {}
		var id:=int(value)
		if ids.has(id) or not model.entries.any(func(entry):return int(entry.id)==id):return {}
		ids.append(id)
	# Domain grants are projected by the existing feat/character owners from
	# these physical domain IDs, avoiding a duplicate editable feat allocation.
	rules.draft.domains=ids;render()
	return {"accepted":true,"code":0x8013,"next":"package-post-skills"}
func spell_source_model(identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity():return {"ready":false}
	return source_spells.read(rules,ui.text,identity) if source_spells.owner!=null else spells_status.duplicate(true)
func spell_request_current(identity: Array,value_ticket: Array,request_id: int,expected_phase: String) -> bool:
	return not dead and identity==summary_identity() and request_id==spells_request and phase==expected_phase and is_instance_valid(source_frontend) and source_frontend.owns(value_ticket)
func enter_source_spells(identity: Array,value_ticket: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity() or not is_instance_valid(source_frontend) or not source_frontend.owns(value_ticket):return {"ready":false}
	spells_request+=1;var request_id:=spells_request;phase="spells-opening";status="Reading spell choices…"
	var result: Dictionary={"ready":false}
	while true:
		result=source_spells.begin(rules,ui.text,identity)
		if result.get("ready",false) or result.get("dependencies",[]).is_empty():break
		for name in result.dependencies:table(str(name))
		if jobs.is_empty() and resource_queue.is_empty():break
		while not jobs.is_empty() or not resource_queue.is_empty():
			await get_tree().process_frame
			if not spell_request_current(identity,value_ticket,request_id,"spells-opening"):return {"ready":false}
	if not spell_request_current(identity,value_ticket,request_id,"spells-opening"):return {"ready":false}
	phase="editing";spells_status=result.duplicate(true);status="" if result.get("ready",false) else str(result.get("reason","Spell choices are unavailable."));render()
	return result
func edit_source_spells(operation: String,id: int,identity: Array,value_ticket: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity() or not is_instance_valid(source_frontend) or not source_frontend.owns(value_ticket):return {"ready":false}
	if operation not in ["level","add","remove","reset","recommend"]:return {"ready":false}
	if operation=="recommend":
		if rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)==0:return spell_source_model(identity)
		var reset:=source_spells.edit("reset",-1,rules,ui.text,identity)
		if not reset.get("ready",false):return reset
		spells_request+=1;var request_id:=spells_request;phase="spells-preparing";status="Reading recommended spell choices…"
		while true:
			var plan:=preload("res://systems/native_data/creation_spell_recommendation_plan.gd").compose(rules,source_spells.state.source)
			if plan.ready:break
			if plan.get("dependencies",[]).is_empty():phase="editing";status=str(plan.get("reason","Recommended spell choices are unavailable."));render();return plan
			for name in plan.dependencies:table(str(name))
			if jobs.is_empty() and resource_queue.is_empty():phase="editing";status=str(plan.get("reason","Recommended spell choices are unavailable."));render();return plan
			while not jobs.is_empty() or not resource_queue.is_empty():
				await get_tree().process_frame
				if not spell_request_current(identity,value_ticket,request_id,"spells-preparing"):return {"ready":false}
		if not spell_request_current(identity,value_ticket,request_id,"spells-preparing"):return {"ready":false}
		phase="editing";status=""
	# This child's temporary choices do not require rebuilding every hidden
	# creation menu and summary. The scoped frontend applies this result;
	# OK/Cancel refresh the parent through their existing completion boundary.
	var result:=source_spells.edit(operation,id,rules,ui.text,identity);spells_status=result.duplicate(true);return result
func commit_source_spells(accepted: bool,identity: Array) -> Dictionary:
	if dead or identity!=summary_identity() or phase not in ["editing","spells-opening","spells-preparing"]:return {}
	if not accepted:
		spells_request+=1;phase="editing";source_spells.close();source_post.reset();spells_status={"ready":false}
		if not rules.reset_source_choices():return {}
		status="";render();return {"accepted":true,"code":3}
	if phase!="editing":return {}
	var result:=source_spells.commit(rules,ui.text,identity)
	if not result.get("ready",false) or not result.get("accepted",false):status=str(result.get("reason","Finish spell selection."));return result
	render();return {"accepted":true,"code":0x8011,"next":"package-post-skills"}
func commit_source_package(operation: String,selected: int,identity: Array,value_ticket: Array) -> Dictionary:
	if dead or identity!=summary_identity() or not is_instance_valid(source_frontend) or not source_frontend.owns(value_ticket) or source_frontend.child!="packagesbutton":return {}
	if operation=="cancel":
		if phase not in ["editing","package-preparing"]:return {}
		package_request+=1
		if is_instance_valid(package_names):package_names.retire()
		phase="editing";status="";render();return {"accepted":true,"code":3}
	if phase!="editing" or operation not in ["automatic","configure"]:return {}
	var choices: Dictionary=preload("res://systems/native_data/creation_package_state.gd").choices(rules,ui.text)
	if operation=="automatic" and not choices.entries.any(func(entry):return int(entry.id)==selected):return {}
	if operation=="configure" and not choices.entries.any(func(entry):return int(entry.id)==selected) and (not choices.entries.is_empty() or selected!=int(choices.default)):return {}
	if rules.row("packages",selected).is_empty():return {"accepted":false,"error":"The active class default has no package row."}
	rules.draft.packageId=selected;package_request+=1;var request_id:=package_request;var text_revision: int=int(ui.text.revision);phase="package-preparing"
	var catalog=ui.catalog;var class_row: Dictionary=rules.cls().duplicate(true);var package_row: Dictionary=rules.row("packages",selected).duplicate(true)
	var layers: Array=catalog.layers.map(func(row):return [row.get("kind"),row.get("serial"),row.get("binding_identity")])
	var valid:=func():return not dead and phase=="package-preparing" and identity==summary_identity() and request_id==package_request and is_instance_valid(source_frontend) and source_frontend.owns(value_ticket) and source_frontend.child=="packagesbutton" and int(ui.text.revision)==text_revision and ui.catalog==catalog and catalog.layers.map(func(row):return [row.get("kind"),row.get("serial"),row.get("binding_identity")])==layers and rules.cls()==class_row and rules.row("packages",selected)==package_row and int(rules.draft.packageId)==selected
	source_frontend.packages.set_operation_status("Preparing the selected package…")
	package_tables()
	while not jobs.is_empty() or not resource_queue.is_empty():
		await get_tree().process_frame
		if not bool(valid.call()):break
	var name: Dictionary={};var package_rules=preload("res://systems/native_data/creation_package_rules.gd")
	var needs_name: bool=operation=="automatic" and (rules.num(class_row,"MinAssociateLevel")&255)==1 and package_rules.scalar(rules,package_row,"Associate")!=null
	if bool(valid.call()) and needs_name:
		if not is_instance_valid(package_names):package_names=preload("res://systems/native_creation_package_name.gd").new();add_child(package_names)
		source_frontend.packages.set_operation_status("Generating your associate’s name…")
		name=await package_names.generate(catalog,identity,valid)
	if not bool(valid.call()):
		if not dead and identity==summary_identity() and request_id==package_request and phase=="package-preparing":
			phase="editing";status="Package data changed. Choose the package again.";render()
		return {"accepted":false,"error":"Package data changed. Choose the package again."}
	if needs_name and not name.get("ready",false):
		phase="editing";status=str(name.get("error","The associate name is unavailable."));render();return {"accepted":false,"error":status}
	if needs_name:rules.draft[("familiar" if rules.num(class_row,"Arcane")!=0 else "companion")+"Name"]=name.name
	var before_skills: Dictionary=rules.draft.skills.duplicate()
	var automatic_spells=preload("res://systems/native_data/creation_spell_automatic.gd")
	var spell_before: Dictionary=automatic_spells.before(rules) if operation=="automatic" else {}
	if operation=="automatic" and not spell_before.get("ready",false):phase="editing";status=str(spell_before.get("reason","The automatic spell baseline is unavailable."));render();return {"accepted":false,"error":status}
	rules.draft.erase("sourceAutomaticFeats");rules.draft.erase("sourceFeatChoices");rules.draft.erase("sourceAutomaticSpells");rules.draft.erase("sourceSpellChoices")
	var result: Dictionary=package_rules.apply(rules,selected,operation=="automatic")
	if operation=="automatic" and result.get("accepted",false):
		var captured:=preload("res://systems/native_data/creation_feat_automatic.gd").capture(rules,before_skills,identity)
		var spell_captured: Dictionary=automatic_spells.capture(rules,spell_before,identity)
		if captured.get("ready",false) and spell_captured.get("ready",false):rules.draft.sourceAutomaticFeats=captured.receipt;rules.draft.sourceAutomaticSpells=spell_captured.receipt
		else:result={"accepted":false,"error":str(captured.get("reason",spell_captured.get("reason","The automatic package choices are unavailable.")))}
	if needs_name and result.get("accepted",false):rules.draft.erase("packageAssociateNamePending")
	phase="editing";status=str(result.get("error",""));render();return result
func commit_source_alignment(selected: int,identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity() or selected < -1 or selected>8:return {}
	var state:=preload("res://systems/native_data/creation_alignment_state.gd").new();state.selected=selected
	var result:=state.result(int(rules.draft.goodEvil),int(rules.draft.lawChaos));rules.draft.goodEvil=int(result.goodEvil);rules.draft.lawChaos=int(result.lawChaos)
	if is_instance_valid(source_frontend) and source_frontend.flow.enabled.packages:rules.reset_choices()
	render();result.accepted=true;return result
func configure(owner) -> void:
	ui=owner; rules.tables=ui.text.tables.duplicate(); rules.catalog=ui.catalog;synchronize_source_tables()
	view=preload("res://systems/server_creation.gd").new(); add_child(view); view.request.connect(input)
	assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(ui.catalog); assets.cache_directory=ui.assets.cache_directory; assets.completed.connect(prepared)
	preview=preload("res://systems/native_creation_preview.gd").new(); add_child(preview); preview.configure(ui,view.appearance_preview,assets)
	voice=preload("res://systems/native_creation_voice.gd").new(); add_child(voice); voice.configure(ui.catalog,view.voice_audio)
	associate_names=preload("res://systems/native_associate_names.gd").new();add_child(associate_names);associate_names.prepared.connect(dispatch_associate_name);associate_names.name_ready.connect(associate_name_ready)
	associate_work=preload("res://systems/native_data/character_picker_work.gd").new();add_child(associate_work);associate_work.completed.connect(associate_projected)
func publish_source_table(name: String,value: Variant) -> void:
	# This private table map belongs only to this new-character draft. Retain
	# raw classes for provenance and leave the active text/catalog graph intact.
	if name=="classes":
		source_classes_raw=value if value is Dictionary else {}
		var compiled:=ClassMetadata.compile(source_classes_raw);source_class_compiles+=1
		source_class_error=str(compiled.get("reason",""));rules.tables[name]=compiled.table
	else:rules.tables[name]=value
	source_table_views[name]=rules.tables[name]
func synchronize_source_tables() -> void:
	# Existing accepted text/table publication is the boundary. TLK-only
	# changes do not recompile class rows; there is no per-frame table copy.
	if source_tables_revision==int(ui.text.revision):return
	for name in source_table_sources.keys():
		if ui.text.tables.has(name):continue
		if source_table_views.has(name) and is_same(rules.tables.get(name),source_table_views[name]):rules.tables.erase(name)
		source_table_sources.erase(name);source_table_views.erase(name)
		if name=="classes":source_classes_raw={};source_class_error="The active physical class table is unavailable."
	for name in ui.text.tables:
		var value: Variant=ui.text.tables[name]
		if source_table_sources.has(name) and is_same(source_table_sources[name],value):continue
		source_table_sources[name]=value;publish_source_table(str(name),value)
	source_tables_revision=int(ui.text.revision)
func attribute_source_model(identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity():return {"ready":false}
	var values:=Rules.Vitals.effective({"classId":int(rules.draft.classId),"race":int(rules.draft.raceId),"abilities":rules.draft.abilities},rules.tables);var points:=rules.point_balance()
	if not values.ready or points<0 or points>255:return {"ready":false}
	var raw: Array=[];var modifiers: Array=[];var racial: Array=[];var costs: Array=[];var limits: Dictionary={};var numeric=preload("res://systems/native_data/character_record_values.gd")
	for index in 6:
		var key: String=Rules.ABILITIES[index];raw.append(int(rules.draft.abilities[key])&255);racial.append(numeric.signed8(rules.num(rules.race(),key+"Adjust")));costs.append(Rules.AbilityRules.cost(rules.tables,raw[-1]))
		var modifier: Variant=numeric.modifier(int(values.scores[index]),rules.tables)
		if modifier==null:return {"ready":false}
		modifiers.append(numeric.signed8(int(modifier)))
	for pair in [["BASE_ABILITY_MIN",8],["BASE_ABILITY_MAX",18],["BASE_ABILITY_MIN_PRIMARY",11],["ABILITY_COST_INCREMENT2",14],["ABILITY_COST_INCREMENT3",16],["ABILITY_COST_INCREMENT4",255]]:limits[pair[0]]=rules.cfg(pair[0],pair[1])
	return {"ready":true,"classId":int(rules.draft.classId),"raw":raw,"scores":values.scores.duplicate(),"gains":values.gains.duplicate(),"racial":racial,"modifiers":modifiers,"costs":costs,"points":points,"limits":limits,"primary":Rules.AbilityRules.primary(rules.cls()),"recommended":Rules.AbilityRules.recommended(rules.tables,rules.cls())}
func edit_source_attributes(operation: String,index: int,identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity() or not attribute_source_model(identity).get("ready",false):return {}
	if operation=="recommend":
		if rules.cfg("ENABLE_RECOMMENDED_BUTTON",1)==0:return {}
		rules.recommend_abilities()
	elif operation in ["up","down"] and index>=0 and index<6:rules.change_ability(index,1 if operation=="up" else -1)
	else:return {}
	render();return attribute_source_model(identity)
func commit_source_attributes(identity: Array) -> Dictionary:
	if dead or phase!="editing" or identity!=summary_identity() or rules.point_balance()!=0:return {}
	if is_instance_valid(source_frontend) and source_frontend.flow.enabled.packages:rules.reset_choices()
	render();return {"accepted":true,"code":0x8003}
func open(scope: int) -> void:
	if dead or phase!="closed": return
	draft_scope+=1; connection=scope; phase="loading"; step=0; dependencies=false; status="Reading character choices…";source_feats=preload("res://systems/native_data/creation_feat_state.gd").new();source_post.reset();source_spells.close();spells_request+=1;spells_status={"ready":false};source_entered=[];source_fallback=false; view.open()
	stage_source()
	request.emit({"kind":"native-creation-begin","connection":connection,"draft":draft_scope})
	for name in ["packages","appearance","gender","phenotype","soundset","chargenclothes","masterfeats"]: table(name)
	for pair in [["skin","pal_skin01"],["hair","pal_hair01"],["tattoo1","pal_tattoo01"],["tattoo2","pal_tattoo01"]]: enqueue(str(pair[1]),3,"palette",str(pair[0]))
	render()
func table(name: String) -> void:
	if rules.present(name) and not rules.tables.has(name.to_lower()): enqueue(name.to_lower(),2017,"table",name.to_lower())
func enqueue(name: String,type: int,kind: String,key: String) -> void:
	var identity:=kind+":"+key
	if requested.has(identity): return
	requested[identity]=true; resource_queue.append({"name":name,"type":type,"kind":kind,"key":key})
func prepared(id: int,result: Dictionary) -> void:
	if dead or not jobs.has(id): return
	var job: Dictionary=jobs[id]; jobs.erase(id)
	if not str(result.error).is_empty():
		resource_errors.append(str(job.name)+": "+str(result.error))
		if job.kind=="table":
			if job.key=="ruleset":ui.text.publish_table(job.key,{});synchronize_source_tables()
			else:publish_source_table(job.key,{})
		return
	if job.kind=="table":
		associate_table_revision+=1
		if job.key=="ruleset":ui.text.publish_table(job.key,result.value);synchronize_source_tables()
		else:publish_source_table(job.key,result.value)
	elif job.kind=="palette": rules.palette_sizes[job.key]=result.bytes.decode_u16(14) if result.bytes.size()>=18 else 0
	elif job.kind=="associate":associate_templates[job.key]=result.value
	if not associate_preview.is_empty():project_associate()
	if phase=="editing" and job.kind=="table" and is_instance_valid(source_frontend) and source_frontend.child=="package-associate":refresh_source()
func package_tables() -> void:
	var package:=rules.row("packages",int(rules.draft.packageId))
	for key in ["SkillPref2DA","FeatPref2DA","SpellPref2DA","Equip2DA"]: table(str(rules.cell(package,key,"")))
func _process(_delta: float) -> void:
	if dead: return
	synchronize_source_tables()
	try_enter_source()
	if not associate_name_request.is_empty() and not associate_names.failure.is_empty():dispatch_associate_name()
	if phase=="editing" and is_instance_valid(source_frontend) and source_text_revision!=int(ui.text.revision): refresh_source()
	for count in mini(4,resource_queue.size()):
		if assets.pending.size()+assets.running.size()>=32: break
		var job: Dictionary=resource_queue.pop_front(); var id: int=assets.request(job.name,int(job.type),"2da" if job.kind=="table" else "gff" if job.kind=="associate" else "bytes")
		if id>=0: jobs[id]=job
	if build_task>=0 and WorkerThreadPool.is_task_completed(build_task):
		WorkerThreadPool.wait_for_task_completion(build_task); build_task=-1
		if phase=="preparing" and int(build_result.get("scope",-1))==draft_scope:
			build_timings.workerUsec=int(build_result.get("workerUsec",0))
			if not str(build_result.error).is_empty(): phase="editing"; status=str(build_result.error); render()
			else:
				phase="waiting"; status="Waiting for the server to admit your character…"; render()
				request.emit({"kind":"native-creation-submit","connection":connection,"draft":draft_scope,"data":Marshalls.raw_to_base64(build_result.bytes)})
		build_result.clear()
	if phase not in ["loading","recommending"] or not ui.tables_ready or not jobs.is_empty() or not resource_queue.is_empty(): return
	if phase=="loading" and not dependencies:
		dependencies=true
		for data in rules.rows("racialtypes"): table(str(rules.cell(data,"FeatsTable","")))
		for data in rules.rows("classes"):
			if rules.num(data,"PlayerClass")==0: continue
			for field in ["PreReqTable","StatGainTable","SkillsTable","FeatsTable","BonusFeatsTable","SpellGainTable","SpellKnownTable","AttackBonusTable","SavingThrowTable"]: table(str(rules.cell(data,field,"")))
		return
	if phase=="loading":
		rules.model_names=ui.catalog.resource_names(2002); rules.initialize(); phase="editing"; status=""; render()
		try_enter_source()
	else: phase="editing"; status=rules.recommend(); render()
func title(table_name: String,id: int,column: String="Name") -> String:
	var data:=rules.row(table_name,id); var ref:=rules.num(data,column,-1); var label: String=ui.text.raw({"strRef":ref&0xffffffff}) if ref>=0 else ""
	return label if not label.is_empty() else str(rules.cell(data,"Label",rules.cell(data,"NAME",table_name+" "+str(id))))
func add(items: Array,type: String,label: String,operation: String="",value: Variant=null,extra: Dictionary={}) -> void:
	var id:=controls.size(); controls[id]={"operation":operation,"value":value,"type":type}; var entry:={"controlId":id,"type":type,"label":label,"disabled":phase!="editing"}; entry.merge(extra); controls[id].merge(entry); items.append(entry)
func text(items: Array,label: String) -> void: items.append({"type":"text","label":label})
func choices(items: Array,label: String,table_name: String,ids: Array,selected: int,operation: String,column: String="Name") -> void:
	var labels: Array=[]
	for id in ids: labels.append(title(table_name,int(id),column))
	add(items,"select",label,operation,ids,{"options":labels,"value":ids.find(selected),"disabled":ids.is_empty(),"tag":operation})
func input_field(items: Array,label: String,key: String,max_length: int=32,multiline: bool=false) -> void:
	add(items,"input",label,"field",key,{"value":str(rules.draft[key]),"maxLength":max_length,"multiline":multiline,"tag":key})
func render() -> void:
	if phase=="closed" or dead: return
	if source_entered==summary_identity() and not source_fallback:
		controls.clear();serial+=1;refresh_source();source_frontend.set_phase(phase,status);return
	controls.clear(); serial+=1; var items: Array=[]; var d: Dictionary=rules.draft
	if phase=="editing":
		if rules.num(rules.cls(),"LearnScroll")!=0 and not d.get("sourceSpellChoices",false) and not d.get("packageSource",false) and (not is_instance_valid(source_frontend) or not source_frontend.wanted):d.known[0]=rules.spell_options(0)
		match step:
			0:
				for id in mini(2,rules.rows("gender").size()): add(items,"button",title("gender",id,"NAME"),"gender",id,{"selected":int(d.gender)==id,"tag":"gender","value":id})
			1:
				for id in range(rules.rows("racialtypes").size()&255):
					if rules.num(rules.row("racialtypes",id),"PlayerRace")!=0: add(items,"button",title("racialtypes",id),"race",id,{"selected":int(d.raceId)==id,"tag":"race","value":id})
				input_field(items,"Subrace","subrace")
			2:
				var images:=rules.portraits(); var pages:=maxi(1,ceili(images.size()/48.0)); portrait_page=mini(portrait_page,pages-1); text(items,"Portraits · "+str(portrait_page+1)+" / "+str(pages))
				add(items,"button","Previous portraits","portrait-page",-1,{"disabled":portrait_page==0}); add(items,"button","Next portraits","portrait-page",1,{"disabled":portrait_page>=pages-1})
				for name in images.slice(portrait_page*48,(portrait_page+1)*48): add(items,"portrait",name,"portrait",name,{"selected":d.portrait==name,"resource":name,"tag":"portrait"})
			3:
				for id in rules.rows("classes").size():
					if rules.num(rules.row("classes",id),"PlayerClass")==0: continue
					var reason:=rules.class_requirement(id); add(items,"button",title("classes",id),"class",id,{"selected":int(d.classId)==id,"disabled":not reason.is_empty(),"reason":reason,"tag":"class","value":id})
			4:
				for id in 9:
					var a:=rules.alignment(id); add(items,"button",Rules.ALIGNMENTS[id],"alignment",id,{"selected":int(d.goodEvil)==int(a.goodEvil) and int(d.lawChaos)==int(a.lawChaos),"disabled":not rules.alignment_allowed(rules.cls(),int(a.goodEvil),int(a.lawChaos)),"tag":"alignment"})
			5:
				for id in rules.packages(): add(items,"button",title("packages",id),"package",id,{"selected":int(d.packageId)==id,"tag":"package"})
				text(items,"Packages supply starting equipment and recommendations. Every choice can be customized.")
			6:
				text(items,"Ability points remaining: "+str(rules.point_balance())); var scores:=rules.abilities()
				for key in Rules.ABILITIES:
					text(items,key+": "+str(d.abilities[key])+" · total "+str(scores[key]))
					for delta in [-1,1]: add(items,"button","−" if delta<0 else "+","ability",[key,delta],{"disabled":not rules.can_decrease(key) if delta<0 else rules.point_cost(int(d.abilities[key])+1)-rules.point_cost(int(d.abilities[key]))>rules.point_balance(),"tag":"ability","delta":delta})
			7:
				if rules.num(rules.cls(),"PickDomains")!=0:
					for index in 2: choices(items,"Domain "+str(index+1),"domains",range(rules.rows("domains").size()),int(d.domains[index]) if d.domains.size()>index else -1,"domain-"+str(index))
				if rules.num(rules.cls(),"PickSchool")!=0: choices(items,"Spell school","spellschools",range(rules.rows("spellschools").size()),int(d.school),"school","StringRef")
			8:
				text(items,"Skill points remaining: "+str(rules.skill_balance()))
				for id in rules.rows("skills").size():
					var rule:=rules.skill_rule(id)
					if not rule.allowed or rules.num(rules.row("skills",id),"HideFromLevelUp")!=0: continue
					text(items,title("skills",id)+": "+str(d.skills.get(id,0))+" / "+str(rule.max)+" · "+str(rule.cost)+" points/rank")
					for delta in [-1,1]: add(items,"button","−" if delta<0 else "+","skill",[id,delta],{"disabled":int(d.skills.get(id,0))<=0 if delta<0 else int(d.skills.get(id,0))>=int(rule.max) or rules.skill_balance()<int(rule.cost),"tag":"skill","delta":delta})
			9: render_feats(items)
			10:
				for level in 10:
					var count:=rules.spell_count(level)
					if count>0:
						text(items,"Level "+str(level)+" · "+str(d.known.get(level,[]).size())+" / "+str(count)+" known")
						if level!=0 or rules.num(rules.cls(),"LearnScroll")==0:
							for id in rules.spell_options(level):
								var selected: bool=d.known.get(level,[]).has(id); add(items,"button",title("spells",id),"spell",[level,id],{"selected":selected,"disabled":not selected and d.known.get(level,[]).size()>=count,"tag":"spell"})
					if rules.num(rules.cls(),"MemorizesSpells")==0: continue
					for slot in rules.spell_slots(level):
						var domain:=rules.num(rules.cls(),"PickDomains")!=0 and level>0 and slot==rules.spell_slots(level)-1; var ids: Array=[-1]+rules.prepared_options(level,domain); var labels: Array=["Unprepared"]
						for id in ids.slice(1): labels.append(title("spells",id))
						var prepared: Array=d.memorized.get(level,[]); var selected:=int(prepared[slot]) if slot<prepared.size() and prepared[slot]!=null else -1
						add(items,"select","Level "+str(level)+" · "+("Domain" if domain else "Slot "+str(slot+1)),"prepared",[level,slot,ids],{"options":labels,"value":ids.find(selected),"tag":"prepared"})
			11:
				choices(items,"Body type","phenotype",rules.phenotypes(),int(d.phenotype),"phenotype")
				var heads:=rules.heads(); var labels: Array=[]
				for id in heads: labels.append("Head "+str(id))
				add(items,"select","Head","head",heads,{"options":labels,"value":heads.find(int(d.head)),"disabled":heads.is_empty(),"tag":"head"})
				var clothing:=rules.clothes(); labels=[]
				for id in clothing: labels.append("Clothing "+str(id+1))
				add(items,"select","Clothing","clothing",clothing,{"options":labels,"value":clothing.find(int(d.clothes)),"disabled":clothing.is_empty(),"tag":"clothing"})
				for key in ["skin","hair","tattoo1","tattoo2"]:
					labels=[]; var ids: Array=[]
					for id in mini(256,int(rules.palette_sizes.get(key,176))): ids.append(id); labels.append("Colour "+str(id))
					add(items,"select",key.capitalize(),"palette",[key,ids],{"options":labels,"value":int(d[key]),"tag":"palette"})
			12:
				choices(items,"Voice","soundset",rules.voices(),int(d.soundset),"voice","STRREF")
				add(items,"voice-sample","Play sample","voice-sample")
			13:
				for pair in [["First name","firstName"],["Last name","lastName"],["Age","age"],["Deity","deity"],["Biography","biography"]]: input_field(items,pair[0],pair[1],32768 if pair[1]=="biography" else 10 if pair[1]=="age" else 32,pair[1]=="biography")
				for spec in [[303,"hen_familiar","familiar"],[199,"hen_companion","companion"]]:
					if rules.granted_feats().has(spec[0]): choices(items,str(spec[2]).capitalize(),spec[1],range(rules.rows(spec[1]).size()),int(d[spec[2]]),spec[2],"STRREF"); input_field(items,str(spec[2]).capitalize()+" name",spec[2]+"Name")
			14:
				text(items,(str(d.firstName)+" "+str(d.lastName)).strip_edges()); text(items,title("racialtypes",int(d.raceId))+" · "+title("classes",int(d.classId))+" 1"); text(items,str(rules.abilities())); text(items,"Play submits this character to the connected server.")
	var problems: Array=rules.errors() if not d.is_empty() and phase=="editing" else []
	view.receive({"kind":"creation-begin","viewId":serial,"step":step,"steps":STEPS,"phase":phase,"status":status,"errors":problems if step==14 else [],"canEdit":phase=="editing","canFinish":phase=="editing" and problems.is_empty(),"canRecommend":phase=="editing" and rules.default_package()>=0,"canCancel":phase!="waiting","count":items.size()})
	view.receive({"kind":"creation-items","viewId":serial,"items":items}); view.receive({"kind":"creation-commit","viewId":serial})
	view.panel.theme=ui.skin_owner.theme()
	if step==11 and phase=="editing": preview.refresh(rules)
	else: preview.stop()
	if step!=12 or phase!="editing": voice.reset()
	else: view.voice_caption=title("soundset",int(d.soundset),"STRREF")
	for id in controls:
		if controls[id].type=="portrait" and view.controls.has(id):
			var button: Button=view.controls[id]; ui.desktop.art.bind_portrait(button.get_meta("portrait"),str(controls[id].resource)+"m"); button.text=""
	refresh_source()
func render_feats(items: Array) -> void:
	var d: Dictionary=rules.draft; var slots:=rules.feat_slots(); var owned:=rules.granted_feats(); var counts:={"normal":0,"bonus":0}
	for index in d.feats.size():
		var choice: Dictionary=d.feats[index]; owned.append(int(choice.id)); counts[choice.kind]+=1; add(items,"button",title("feat",int(choice.id),"FEAT")+" · Remove","feat-remove",index)
	var kinds: Array=[]
	for kind in ["bonus","normal"]:
		if int(counts[kind])<int(slots[kind]): kinds.append(kind)
	if kinds.is_empty(): text(items,"All feat choices complete."); return
	if not kinds.has(feat_kind): feat_kind=str(kinds[0])
	add(items,"select","Feat slot","feat-kind",kinds,{"options":kinds,"value":kinds.find(feat_kind)})
	add(items,"toggle","Show unavailable feats","feat-unavailable",null,{"value":show_unavailable})
	add(items,"input","Filter feats","feat-filter",null,{"value":filter,"maxLength":128})
	for id in rules.rows("feat").size():
		if not rules.feat_allowed(id,feat_kind): continue
		var reason:=rules.feat_requirement(id,owned); var label:=title("feat",id,"FEAT")
		if not filter.is_empty() and not label.to_lower().contains(filter.to_lower()) or not show_unavailable and not reason.is_empty(): continue
		add(items,"button",label+(" · "+reason if not reason.is_empty() else ""),"feat",id,{"disabled":not reason.is_empty(),"tag":"feat"})
func apply_texts(values: Array) -> void:
	for entry in values:
		var control: Dictionary=controls.get(int(entry.get("controlId",-1)),{})
		if control.get("operation")=="field": rules.draft[str(control.value)]=int(str(entry.value)) if control.value=="age" else str(entry.value)
		elif control.get("operation")=="feat-filter": filter=str(entry.value).left(128)
func input(message: Dictionary) -> void:
	var operation:=str(message.get("operation",""))
	if operation=="cancel" and phase!="waiting": cancel(); return
	if phase!="editing" or int(message.get("viewId",-1))!=serial: return
	if operation=="voice":
		var control: Dictionary=controls.get(int(message.get("controlId",-1)),{})
		if step==12 and control.get("operation")=="voice-sample": voice.play(int(rules.draft.soundset),str(rules.cell(rules.row("soundset",int(rules.draft.soundset)),"RESREF","")))
		return
	apply_texts(message.get("texts",[])); var d: Dictionary=rules.draft; status=""
	if operation=="page":
		# The staged original Skills child will call the same commit on OK.
		# For the shipping sidebar, accept only a finished skill allocation
		# when leaving that page; ordinary rank edits do not rebuild the mask.
		if step==8 and int(message.step)!=8 and rules.skill_balance()==0: rules.commit_skill_summary()
		step=clampi(int(message.step),0,14)
	elif operation=="preview": preview.stop()
	elif operation=="recommend": phase="recommending"; status="Reading package recommendations…"; package_tables()
	elif operation=="submit":
		var problems:=rules.errors()
		if not problems.is_empty(): step=14
		else: phase="preparing"; status="Preparing your character…"; package_tables(); begin_build()
	elif operation=="control":
		var c: Dictionary=controls.get(int(message.get("controlId",-1)),{})
		if c.is_empty() or c.disabled: render(); return
		var value: Variant=message.get("value"); var id:=int(c.value) if c.value is int else -1
		if c.type=="select":
			if not (value is int or value is float) or float(value)!=floor(float(value)) or int(value)<0 or int(value)>=c.options.size(): render(); return
		match str(c.operation):
			"gender": d.gender=id; d.portrait=""
			"race": rules.select_race(id,ui.text); rules.reset_choices()
			"class": rules.select_class(id)
			"alignment": d.merge(rules.alignment(id),true); rules.reset_choices()
			"package": d.packageId=id
			"portrait": d.portrait=c.value
			"portrait-page": portrait_page+=id
			"ability": d.abilities[c.value[0]]=int(d.abilities[c.value[0]])+int(c.value[1]); rules.reset_choices()
			"skill": d.skills[c.value[0]]=int(d.skills.get(c.value[0],0))+int(c.value[1]); d.feats=[]
			"feat-kind": feat_kind=str(c.value[int(value)])
			"feat-unavailable": show_unavailable=bool(value)
			"feat-filter": filter=str(value).left(128)
			"feat": d.feats.append({"id":id,"kind":feat_kind})
			"feat-remove": d.feats.remove_at(id)
			"spell":
				var selected: Array=d.known.get(c.value[0],[]).duplicate(); var spell: int=int(c.value[1])
				if selected.has(spell): selected.erase(spell)
				else: selected.append(spell)
				d.known[c.value[0]]=selected; d.memorized={}
			"prepared":
				var prepared: Array=d.memorized.get(c.value[0],[]).duplicate()
				while prepared.size()<=int(c.value[1]): prepared.append(null)
				var spell: int=int(c.value[2][int(value)]); prepared[int(c.value[1])]=null if spell<0 else spell; d.memorized[c.value[0]]=prepared
			"school": d.school=c.value[int(value)]; d.known={}
			"domain-0","domain-1":
				while d.domains.size()<2: d.domains.append(-1)
				d.domains[int(str(c.operation).right(1))]=c.value[int(value)]; d.feats=[]
			"head": d.head=c.value[int(value)]
			"phenotype": d.phenotype=c.value[int(value)]
			"clothing": d.clothes=c.value[int(value)]
			"voice": d.soundset=c.value[int(value)]; voice.reset()
			"familiar","companion": d[c.operation]=c.value[int(value)]
			"palette": d[c.value[0]]=c.value[1][int(value)]
			"field": d[c.value]=int(str(value)) if c.value=="age" else str(value)
	render()
func begin_build() -> void:
	var requested_at:=Time.get_ticks_usec();var scope:=draft_scope
	while not dead and phase=="preparing" and scope==draft_scope and (build_task>=0 or not jobs.is_empty() or not resource_queue.is_empty()): await get_tree().process_frame
	if dead or phase!="preparing" or scope!=draft_scope: return
	var capture_at:=Time.get_ticks_usec();build_timings={"scope":scope,"waitUsec":capture_at-requested_at}
	var source:=Rules.new(); source.tables=rules.tables.duplicate(); source.catalog=rules.catalog.fork(); source.model_names=rules.model_names; source.palette_sizes=rules.palette_sizes; source.portrait_cache=rules.portrait_cache; source.draft=rules.draft.duplicate(true); source.creation_point_budget=rules.creation_point_budget;source.creation_class_points=rules.creation_class_points;source.ability_points_snapshot=rules.ability_points_snapshot.duplicate()
	source.creation_base_hp=rules.creation_base_hp;source.creation_skill_points=rules.creation_skill_points;source.skill_points_snapshot=rules.skill_points_snapshot.duplicate()
	source.creation_spell_slots=rules.creation_spell_slots.duplicate();source.creation_spell_selection=rules.creation_spell_selection.duplicate(true)
	build_timings.rulesSnapshotUsec=Time.get_ticks_usec()-capture_at
	var text_at:=Time.get_ticks_usec()
	if source.draft.get("sourceSpellChoices",false):
		var frozen:=preload("res://systems/native_data/creation_spell_text_snapshot.gd").capture(rules,ui.text)
		if not frozen.ready:phase="editing";status=str(frozen.reason);render();return
		source.creation_spell_text=frozen.text
	build_timings.spellTextUsec=Time.get_ticks_usec()-text_at;build_timings.captureUsec=Time.get_ticks_usec()-capture_at
	build_task=WorkerThreadPool.add_task(func():
		var worker_at:=Time.get_ticks_usec();var builder:=Builder.new(); var bytes:=builder.build(source); build_result={"bytes":bytes,"error":builder.failure,"scope":scope,"workerUsec":Time.get_ticks_usec()-worker_at},false,"Native character BIC")
func observe(state: Dictionary) -> void:
	if phase=="waiting" and str(state.get("phase",""))=="character-rejected": phase="editing"; step=14; status="The server rejected the character. Review your choices."; render()
	elif phase=="waiting" and str(state.get("phase","")) in ["area-loading","playing"]: finish_view()
func finish_view() -> void:
	if is_instance_valid(tail):tail.retire()
	associate_name_request={};associate_name_jobs.clear();associate_preview={};associate_work.retire()
	draft_scope+=1; phase="closed";spells_request+=1;source_spells.close();spells_status={"ready":false};source_entered=[];source_fallback=false; preview.stop(); voice.reset(); view.reset()
	if is_instance_valid(source_frontend): source_frontend.dismiss()
	closed.emit()
func cancel() -> void:
	request.emit({"kind":"native-creation-cancel","connection":connection,"draft":draft_scope}); finish_view()
func result(message: Dictionary) -> void:
	if dead or phase=="closed" or int(message.get("connection",-1))!=connection or int(message.get("draft",-1))!=draft_scope:return
	var operation:=str(message.get("operation",""))
	if operation not in ["native-creation-begin","native-creation-submit"]:return
	if operation=="native-creation-submit" and phase!="waiting" or operation=="native-creation-begin" and phase not in ["loading","editing"]:return
	if not message.get("accepted",false): phase="editing" if not rules.draft.is_empty() else "loading"; status=str(message.get("text","Character creation failed.")); render()
func close() -> void:
	if dead: return
	dead=true
	if is_instance_valid(tail):tail.close()
	preview.close(); voice.close(); assets.close()
	associate_names.close();associate_work.close();associate_name_jobs.clear();associate_templates.clear();associate_preview={};associate_name_request={}
	if is_instance_valid(package_names):package_names.close()
	spells_request+=1;source_spells.close();spells_status={"ready":false}
	if is_instance_valid(source_frontend): source_frontend.close()
	if build_task>=0: WorkerThreadPool.wait_for_task_completion(build_task); build_task=-1
	build_result.clear(); resource_queue.clear(); jobs.clear(); view.reset()
func _exit_tree() -> void: close()
