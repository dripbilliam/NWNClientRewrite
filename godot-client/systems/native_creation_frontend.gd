extends CanvasLayer
# CG_MAIN child coordinator, with no BIC writer or network side effects.
# Draft owners validate/commit choices; unported modal owners use child_requested.
signal child_requested(tag: String,ticket: Array)
signal command_requested(operation: String,scope: Array)
signal finished(cancelled: bool,scope: Array)
signal status_dismissed(status: String,scope: Array)
const Flow=preload("res://systems/native_data/creation_main_state.gd")
var flow:=Flow.new()
var main
var portrait
var gender
var gender_scope: Array=[]
var current_gender:=0
var gender_commit:=Callable()
var gender_applying:=false
var race
var race_scope: Array=[]
var race_values: Array=[]
var current_race:=-1
var current_subrace:=""
var race_recommended:=true
var race_text
var race_text_revision:=-1
var race_art
var race_commit:=Callable()
var race_applying:=false
var class_chooser
var class_scope: Array=[]
var class_values: Dictionary={}
var class_recommended:=true
var class_text
var class_text_revision:=-1
var class_art
var class_commit:=Callable()
var class_applying:=false
var alignment
var alignment_scope: Array=[]
var alignment_context: Dictionary={}
var alignment_recommended:=true
var alignment_text
var alignment_text_revision:=-1
var alignment_commit:=Callable()
var alignment_applying:=false
var attributes
var attributes_scope: Array=[]
var attributes_context: Dictionary={}
var attributes_recommended:=true
var attributes_text
var attributes_text_revision:=-1
var attributes_edit:=Callable()
var attributes_commit:=Callable()
var attributes_applying:=false
var packages
var packages_scope: Array=[]
var packages_context: Dictionary={}
var packages_recommended:=true
var packages_text
var packages_text_revision:=-1
var packages_art
var packages_enter:=Callable()
var packages_commit:=Callable()
var packages_applying:=false
var skills
var skills_scope: Array=[]
var skills_context: Dictionary={}
var skills_recommended:=true
var skills_text
var skills_text_revision:=-1
var skills_art
var skills_edit:=Callable()
var skills_commit:=Callable()
var skills_applying:=false
var feats
var feats_scope: Array=[]
var feats_context: Dictionary={}
var feats_recommended:=true
var feats_text
var feats_text_revision:=-1
var feats_art
var feats_edit:=Callable()
var feats_commit:=Callable()
var feats_applying:=false
var school
var school_scope: Array=[]
var school_context: Dictionary={}
var school_recommended:=true
var school_text
var school_text_revision:=-1
var school_commit:=Callable()
var school_applying:=false
var domains
var domains_scope: Array=[]
var domains_context: Dictionary={}
var domains_signature: Array=[]
var domains_recommended:=true
var domains_text
var domains_text_revision:=-1
var domains_art
var domains_commit:=Callable()
var domains_applying:=false
var spells
var spells_scope: Array=[]
var spells_context: Dictionary={}
var spells_recommended:=true
var spells_text
var spells_text_revision:=-1
var spells_art
var spells_enter:=Callable()
var spells_edit:=Callable()
var spells_commit:=Callable()
var spells_applying:=false
var associate
var associate_scope: Array=[]
var associate_context: Dictionary={}
var associate_text
var associate_art
var associate_action:=Callable()
var associate_commit:=Callable()
var associate_applying:=false
var post_scope: Array=[]
var post_continue:=Callable()
var post_applying:=false
var post_code:=0x8010
var post_pending_emitted:=false
var surface: Control
var scope: Array=[]
var context: Dictionary={}
var classes: Array=[]
var portrait_values: Array=[]
var portrait_scope: Array=[]
var current_portrait:=""
var portrait_art
var portrait_catalog
var portrait_commit:=Callable()
var child:=""
var ticket: Array=[]
var serial:=0
var generation:=0
var wanted:=false
var closed:=false
var summary_scope: Array=[]
var summary_provider:=Callable()
var summary_art
var summary_model: Dictionary={}
var summary_portrait_key: Array=[]
var summary_lists: Dictionary={}
var status_view
var phase:="editing"
var phase_status:=""
var phase_revision:=0
func set_phase(value: String,message: String) -> void:
	if closed or phase==value and phase_status==message:return
	phase=value;phase_status=message;phase_revision+=1
	if is_instance_valid(main):main.retire_input()
	if is_instance_valid(status_view):status_view.dismiss()
	refresh()
func phase_available(tag: String) -> bool:
	if phase=="waiting":return false
	return phase!="preparing" or tag=="cancelbutton"
func refresh_status() -> void:
	if not is_instance_valid(status_view):return
	if not wanted or not child.is_empty() or phase_status.is_empty() or phase not in ["editing","preparing","waiting"]:
		status_view.dismiss();return
	status_view.present(phase_status,scope+[generation,phase_revision],phase!="editing")
func dismiss_status(value_scope: Array) -> void:
	if closed or not wanted or not child.is_empty() or phase!="editing" or value_scope!=scope+[generation,phase_revision]:return
	var message:=phase_status;var identity:=scope.duplicate()
	phase_status="";phase_revision+=1
	status_dismissed.emit(message,identity)
func stage_draft(value_scope: Array,rule_context: Dictionary,active_classes: Array) -> void:
	# The shipping fifteen-page owner can bind/prewarm its real draft before
	# the remaining original children are ready to replace its presentation.
	if closed: return
	dismiss(); scope=value_scope.duplicate(); context=rule_context.duplicate(); classes=active_classes; flow.initialize(); refresh()
func bind_summary(value_scope: Array,provider: Callable,art) -> bool:
	if closed or not scope.is_empty() and value_scope!=scope: return false
	if summary_art!=art:
		for page in summary_lists.values(): page.close(); page.queue_free()
		summary_lists.clear()
	clear_summary(); summary_scope=value_scope.duplicate(); summary_provider=provider; summary_art=art; refresh(); return true
func clear_summary() -> void:
	if is_instance_valid(summary_art) and is_instance_valid(main) and is_instance_valid(main.summary_view): summary_art.unbind(main.summary_view.portrait)
	summary_scope=[]; summary_provider=Callable(); summary_art=null; summary_model={}; summary_portrait_key=[]
	if is_instance_valid(main) and is_instance_valid(main.summary_view): main.summary_view.clear_values(main.text_owner.raw({"strRef":61826})); main.summary_view.portrait.texture=null
	for page in summary_lists.values(): page.present_entries([])
func list_identity() -> Array: return scope+[generation]
func list_available() -> bool: return not closed and wanted and child.is_empty() and summary_scope==scope
func ensure_lists() -> void:
	if not summary_lists.is_empty() or not is_instance_valid(summary_art) or not is_instance_valid(main.summary_view): return
	for index in range(1,4):
		var page=preload("res://systems/native_lobby_record_feats.gd").new(); main.summary_view.pages[index].add_child(page)
		page.configure_view(main.frame,main.summary_view.definition.models,main.models,main.summary_view.pages[index].size,index,summary_art,list_identity,list_available)
		summary_lists[str(index)]=page; page.show()
func pull_summary() -> void:
	if closed or not is_instance_valid(main.summary_view) or summary_scope!=scope or not summary_provider.is_valid(): return
	var identity:=scope.duplicate(); var epoch:=generation; var provider:=summary_provider
	var value: Variant=provider.call(identity,flow.summary_mask,main.text_owner.raw({"strRef":61826}))
	if closed or epoch!=generation or scope!=identity or summary_scope!=identity or provider!=summary_provider: return
	if not value is Dictionary or value.get("scope",[])!=identity:
		summary_model={}; summary_portrait_key=[]; main.summary_view.clear_values(main.text_owner.raw({"strRef":61826})); main.summary_view.portrait.texture=null
		if is_instance_valid(summary_art): summary_art.unbind(main.summary_view.portrait)
		for page in summary_lists.values(): page.present_entries([])
		return
	summary_model=value.duplicate(true); main.summary_view.present_values(value.get("labels",{}))
	ensure_lists()
	for index in summary_lists:
		var model: Dictionary=value.get("lists",{}).get(index,{})
		summary_lists[index].present_entries(model.get("entries",[]) if model.get("ready",false) else [],int(value.get("text_revision",0)))
	var key:=identity+[str(value.get("portrait",""))]
	if key!=summary_portrait_key and is_instance_valid(summary_art):
		summary_portrait_key=key; summary_art.unbind(main.summary_view.portrait); main.summary_view.portrait.texture=null
		if not str(value.get("portrait","")).is_empty(): summary_art.bind_portrait(main.summary_view.portrait,str(value.portrait))
func configure(painter,text,base_catalog,cache_path: String) -> void:
	layer=40; surface=Control.new(); add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); surface.mouse_filter=Control.MOUSE_FILTER_STOP; surface.hide()
	main=preload("res://systems/native_creation_main_frame.gd").new(); surface.add_child(main); main.configure(painter,text,base_catalog,cache_path); main.prepared.connect(refresh); main.action_requested.connect(main_action); main.start()
	gender=preload("res://systems/native_gender_chooser.gd").new();surface.add_child(gender);gender.configure(painter,text,base_catalog,cache_path);gender.prepared.connect(place);gender.finished.connect(gender_result);gender.start()
	race=preload("res://systems/native_race_chooser.gd").new();surface.add_child(race);race.configure(painter,text,base_catalog,cache_path);race.prepared.connect(place);race.finished.connect(race_result);race.start()
	class_chooser=preload("res://systems/native_class_chooser.gd").new();surface.add_child(class_chooser);class_chooser.configure(painter,text,base_catalog,cache_path);class_chooser.prepared.connect(place);class_chooser.finished.connect(class_result);class_chooser.start()
	alignment=preload("res://systems/native_alignment_chooser.gd").new();surface.add_child(alignment);alignment.configure(painter,text,base_catalog,cache_path);alignment.prepared.connect(place);alignment.finished.connect(alignment_result);alignment.start()
	attributes=preload("res://systems/native_attributes_chooser.gd").new();surface.add_child(attributes);attributes.configure(painter,text,base_catalog,cache_path);attributes.prepared.connect(place);attributes.action_requested.connect(attributes_action);attributes.finished.connect(attributes_result);attributes.start()
	packages=preload("res://systems/native_package_chooser.gd").new();surface.add_child(packages);packages.configure(painter,text,base_catalog,cache_path);packages.prepared.connect(place);packages.finished.connect(packages_result);packages.start()
	skills=preload("res://systems/native_skills_chooser.gd").new();surface.add_child(skills);skills.configure(painter,text,base_catalog,cache_path);skills.prepared.connect(place);skills.action_requested.connect(skills_action);skills.finished.connect(skills_result);skills.start()
	feats=preload("res://systems/native_feats_chooser.gd").new();surface.add_child(feats);feats.configure(painter,text,base_catalog,cache_path);feats.prepared.connect(place);feats.action_requested.connect(feats_action);feats.finished.connect(feats_result);feats.start()
	school=preload("res://systems/native_school_chooser.gd").new();surface.add_child(school);school.configure(painter,text,base_catalog,cache_path);school.prepared.connect(place);school.finished.connect(school_result);school.start()
	# Original9c69a0 constructs this class-dependent child on demand. Keep
	# its preparation off the ordinary pregame/character-picker startup path.
	domains=preload("res://systems/native_domains_chooser.gd").new();surface.add_child(domains);domains.configure(painter,text,base_catalog,cache_path);domains.prepared.connect(place);domains.finished.connect(domains_result)
	spells=preload("res://systems/native_spells_chooser.gd").new();surface.add_child(spells);spells.configure(painter,text,base_catalog,cache_path);spells.prepared.connect(place);spells.action_requested.connect(spells_action);spells.finished.connect(spells_result)
	associate=preload("res://systems/native_associate_chooser.gd").new();surface.add_child(associate);associate.configure(painter,text,base_catalog,cache_path);associate.prepared.connect(place);associate.action_requested.connect(associate_action_requested);associate.finished.connect(associate_result)
	portrait=preload("res://systems/native_portrait_chooser.gd").new(); surface.add_child(portrait); portrait.configure(painter,text,base_catalog,cache_path); portrait.prepared.connect(place); portrait.finished.connect(portrait_result); portrait.start()
	status_view=preload("res://systems/native_creation_status.gd").new();surface.add_child(status_view);status_view.configure(painter,text,base_catalog,cache_path);status_view.prepared.connect(place);status_view.finished.connect(dismiss_status)
	get_viewport().size_changed.connect(place)
func bind_gender(value_scope: Array,current: int,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var changed: bool=gender_scope!=value_scope or current_gender!=current or gender_commit!=commit
	gender_scope=value_scope.duplicate();current_gender=current;gender_commit=commit
	if changed and not gender_applying and child=="genderbutton" and scope==gender_scope:
		serial+=1;ticket=scope+[serial,child];gender.set_context(current_gender,ticket);gender.open()
	return true
func bind_races(value_scope: Array,values: Array,current: int,subrace_value: String,recommended: bool,active_text,art,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var text_revision: int=int(active_text.revision) if active_text!=null else -1
	var changed: bool=race_scope!=value_scope or race_values!=values or current_race!=current or current_subrace!=subrace_value or race_recommended!=recommended or race_commit!=commit or race_text!=active_text or race_text_revision!=text_revision or race_art!=art
	race_scope=value_scope.duplicate();race_values=values.duplicate(true);current_race=current;current_subrace=subrace_value;race_recommended=recommended;race_text=active_text;race_text_revision=text_revision;race_art=art;race_commit=commit
	if changed and not race_applying and child=="racebutton" and scope==race_scope:
		serial+=1;ticket=scope+[serial,child];race.set_context(race_values,current_race,current_subrace,race_recommended,race_text,race_art,ticket);race.open()
	return true
func bind_portraits(value_scope: Array,values: Array,current: String,art,catalog,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope: return false
	portrait_scope=value_scope.duplicate(); portrait_values=values.duplicate(); current_portrait=current; portrait_art=art; portrait_catalog=catalog; portrait_commit=commit
	if child=="portraitbutton" and scope==portrait_scope:
		# Keep the same logical child open, but invalidate all held clicks and
		# previous result tickets when its active catalog/choices are replaced.
		serial+=1; ticket=scope+[serial,child]; portrait.set_context(portrait_values,current_portrait,ticket,portrait_art,portrait_catalog); portrait.open()
	return true
func bind_classes(value_scope: Array,values: Dictionary,recommended: bool,active_text,art,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var text_revision: int=int(active_text.revision) if active_text!=null else -1
	var changed: bool=class_scope!=value_scope or class_values!=values or class_recommended!=recommended or class_commit!=commit or class_text!=active_text or class_text_revision!=text_revision or class_art!=art
	class_scope=value_scope.duplicate();class_values=values.duplicate(true);class_recommended=recommended;class_text=active_text;class_text_revision=text_revision;class_art=art;class_commit=commit
	if changed and not class_applying and child=="classbutton" and scope==class_scope:
		serial+=1;ticket=scope+[serial,child];class_chooser.set_context(class_values,class_recommended,class_text,class_art,ticket);class_chooser.open()
	return true
func begin(value_scope: Array,rule_context: Dictionary,active_classes: Array) -> void:
	if closed: return
	if value_scope!=scope: clear_summary()
	generation+=1; retire_child(); scope=value_scope.duplicate(); context=rule_context.duplicate(); classes=active_classes; phase="editing";phase_status="";phase_revision+=1;flow.initialize(); wanted=true; surface.show(); refresh()
	if int(context.get("customizeMode",0))!=0: open_child("portraitbutton")
func bind_alignment(value_scope: Array,values: Dictionary,recommended: bool,active_text,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var text_revision: int=int(active_text.revision) if active_text!=null else -1
	var changed: bool=alignment_scope!=value_scope or alignment_context!=values or alignment_recommended!=recommended or alignment_commit!=commit or alignment_text!=active_text or alignment_text_revision!=text_revision
	alignment_scope=value_scope.duplicate();alignment_context=values.duplicate(true);alignment_recommended=recommended;alignment_text=active_text;alignment_text_revision=text_revision;alignment_commit=commit
	if changed and not alignment_applying and child=="alignbutton" and scope==alignment_scope:
		serial+=1;ticket=scope+[serial,child];open_alignment()
	return true
func open_alignment() -> void:
	alignment.set_context(alignment_context.data,int(alignment_context.classId),int(alignment_context.goodEvil),int(alignment_context.lawChaos),alignment_recommended,alignment_text,ticket);alignment.open()
func main_action(tag: String,value_scope: Array) -> void:
	if closed or not wanted or not child.is_empty() or value_scope!=scope or not phase_available(tag): return
	if tag=="cancelbutton": finish(true); return
	if tag=="resetbutton":
		serial+=1; flow.reset(); dispatch(); refresh(); return
	if tag=="playbutton": command_requested.emit("finish",scope.duplicate()); return
	open_child(tag)
func bind_attributes(value_scope: Array,values: Dictionary,recommended: bool,active_text,edit: Callable,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var text_revision: int=int(active_text.revision) if active_text!=null else -1
	var changed: bool=attributes_scope!=value_scope or attributes_context!=values or attributes_recommended!=recommended or attributes_text!=active_text or attributes_text_revision!=text_revision or attributes_edit!=edit or attributes_commit!=commit
	attributes_scope=value_scope.duplicate();attributes_context=values.duplicate(true);attributes_recommended=recommended;attributes_text=active_text;attributes_text_revision=text_revision;attributes_edit=edit;attributes_commit=commit
	if changed and not attributes_applying and child=="abilitiesbutton" and scope==attributes_scope:
		serial+=1;ticket=scope+[serial,child];open_attributes()
	return true
func open_attributes() -> void:attributes.set_context(attributes_context,attributes_recommended,attributes_text,ticket);attributes.open()
func bind_packages(value_scope: Array,values: Dictionary,recommended: bool,active_text,art,enter: Callable,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var text_revision: int=int(active_text.revision) if active_text!=null else -1
	var changed: bool=packages_scope!=value_scope or packages_context!=values or packages_recommended!=recommended or packages_text!=active_text or packages_text_revision!=text_revision or packages_art!=art or packages_enter!=enter or packages_commit!=commit
	packages_scope=value_scope.duplicate();packages_context=values.duplicate(true);packages_recommended=recommended;packages_text=active_text;packages_text_revision=text_revision;packages_art=art;packages_enter=enter;packages_commit=commit
	if changed and not packages_applying and child=="packagesbutton" and scope==packages_scope:
		serial+=1;ticket=scope+[serial,child];open_packages()
	return true
func open_packages() -> void:packages.set_context(packages_context,packages_recommended,packages_text,packages_art,ticket);packages.open()
func bind_skills(value_scope: Array,values: Dictionary,recommended: bool,active_text,art,edit: Callable,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var text_revision: int=int(active_text.revision) if active_text!=null else -1
	var changed: bool=skills_scope!=value_scope or skills_context!=values or skills_recommended!=recommended or skills_text!=active_text or skills_text_revision!=text_revision or skills_art!=art or skills_edit!=edit or skills_commit!=commit
	skills_scope=value_scope.duplicate();skills_context=values.duplicate(true);skills_recommended=recommended;skills_text=active_text;skills_text_revision=text_revision;skills_art=art;skills_edit=edit;skills_commit=commit
	if changed and not skills_applying and child=="package-configuration" and scope==skills_scope:
		serial+=1;ticket=scope+[serial,child];open_skills()
	return true
func open_skills() -> void:skills.set_context(skills_context,skills_recommended,skills_text,skills_art,ticket);skills.open()
func bind_feats(value_scope: Array,values: Dictionary,recommended: bool,active_text,art,edit: Callable,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var text_revision: int=int(active_text.revision) if active_text!=null else -1
	var changed: bool=feats_scope!=value_scope or feats_context!=values or feats_recommended!=recommended or feats_text!=active_text or feats_text_revision!=text_revision or feats_art!=art or feats_edit!=edit or feats_commit!=commit
	feats_scope=value_scope.duplicate();feats_context=values.duplicate(true);feats_recommended=recommended;feats_text=active_text;feats_text_revision=text_revision;feats_art=art;feats_edit=edit;feats_commit=commit
	if changed and not feats_applying and child=="package-feats" and scope==feats_scope:
		serial+=1;ticket=scope+[serial,child];open_feats()
	return true
func open_feats() -> void:feats.set_context(feats_context,feats_recommended,feats_text,feats_art,ticket);feats.open()
func bind_school(value_scope: Array,values: Dictionary,recommended: bool,active_text,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var text_revision: int=int(active_text.revision) if active_text!=null else -1
	var preserve: bool=school_scope==value_scope and school_context==values
	var changed: bool=not preserve or school_recommended!=recommended or school_text!=active_text or school_text_revision!=text_revision or school_commit!=commit
	school_scope=value_scope.duplicate();school_context=values.duplicate(true);school_recommended=recommended;school_text=active_text;school_text_revision=text_revision;school_commit=commit
	if changed and not school_applying and child=="package-school" and scope==school_scope:
		serial+=1;ticket=scope+[serial,child];open_school(preserve)
	return true
func open_school(preserve: bool=false) -> void:school.set_context(school_context,school_recommended,school_text,ticket,preserve);school.open()
func bind_domains(value_scope: Array,values: Dictionary,recommended: bool,active_text,art,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var text_revision: int=int(active_text.revision) if active_text!=null else -1
	var signature: Array=[values.get("ready",false),values.get("recommended",[])]
	for entry in values.get("entries",[]):signature.append([entry.id,entry.title,entry.description,entry.icon,entry.grantedFeat])
	var preserve: bool=domains_scope==value_scope and domains_signature==signature
	var changed: bool=not preserve or domains_context!=values or domains_recommended!=recommended or domains_text!=active_text or domains_text_revision!=text_revision or domains_art!=art or domains_commit!=commit
	domains_scope=value_scope.duplicate();domains_signature=signature;domains_context=values.duplicate(true);domains_recommended=recommended;domains_text=active_text;domains_text_revision=text_revision;domains_art=art;domains_commit=commit
	if changed and not domains_applying and child=="package-domains" and scope==domains_scope:
		serial+=1;ticket=scope+[serial,child];open_domains(preserve)
	return true
func open_domains(preserve: bool=false) -> void:domains.set_context(domains_context,domains_recommended,domains_text,domains_art,ticket,preserve);domains.open();domains.start()
func bind_spells(value_scope: Array,values: Dictionary,recommended: bool,active_text,art,enter: Callable,edit: Callable,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var text_revision: int=int(active_text.revision) if active_text!=null else -1
	var changed: bool=spells_scope!=value_scope or spells_context!=values or spells_recommended!=recommended or spells_text!=active_text or spells_text_revision!=text_revision or spells_art!=art or spells_enter!=enter or spells_edit!=edit or spells_commit!=commit
	spells_scope=value_scope.duplicate();spells_context=values.duplicate(true);spells_recommended=recommended;spells_text=active_text;spells_text_revision=text_revision;spells_art=art;spells_enter=enter;spells_edit=edit;spells_commit=commit
	if changed and not spells_applying and child=="package-spells" and scope==spells_scope:
		serial+=1;ticket=scope+[serial,child];show_spells()
	return true
func show_spells() -> void:
	spells.set_context(spells_context,spells_recommended,spells_text,spells_art,ticket);spells.open();spells.start()
func open_spells() -> void:
	var identity:=ticket.duplicate();spells_context={"ready":false};show_spells()
	spells_applying=true;var result: Variant=await spells_enter.call(scope.duplicate(),identity);spells_applying=false
	if not owns(identity):return
	if result is Dictionary:spells_context=result.duplicate(true)
	show_spells()
func bind_post(value_scope: Array,callback: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	post_scope=value_scope.duplicate();post_continue=callback
	if child=="package-post-skills" and scope==post_scope and not post_applying:route_post(ticket.duplicate())
	return true
func route_post(value_ticket: Array) -> void:
	# Dispatch can refresh the owning draft, whose binding publishes back into
	# this frontend. Keep the continuation held through dispatch/child transfer,
	# not just through the source getter, so that publication cannot re-enter it.
	if post_applying:return
	post_applying=true
	route_post_step(value_ticket)
	post_applying=false
func route_post_step(value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="package-post-skills" or not post_continue.is_valid():return
	var result: Variant=post_continue.call(scope.duplicate(),post_code)
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("ready",false):
		if not post_pending_emitted:post_pending_emitted=true;child_requested.emit("package-post-skills",value_ticket.duplicate())
		return
	# Original9c69a0 deactivates the current child (delivering its callback)
	# before transferring the same callback pair to the next modal. Thus800e
	# marks Package complete behind School; Cancel3 later reverses that state.
	if result.get("code")!=null:
		context.paladinRuleDefault=Flow.paladin_rule_default(classes);flow.result(int(result.code),context);dispatch()
		if not owns(value_ticket):return
	var next: String=str(result.get("next",""));retire_child()
	if not next.is_empty():open_child(next)
	refresh()
func bind_associate(value_scope: Array,value: Dictionary,active_text,art,action: Callable,commit: Callable) -> bool:
	if closed or (wanted or not summary_scope.is_empty()) and value_scope!=scope:return false
	var changed: bool=associate_scope!=value_scope or associate_context!=value or associate_text!=active_text or associate_art!=art
	if child=="package-associate" and associate_scope==value_scope and associate_context.get("choices")==value.get("choices") and associate_context.get("storedType")==value.get("storedType") and associate.state.current_name==value.get("name") and associate_text==active_text and associate_art==art:changed=false
	associate_scope=value_scope.duplicate();associate_context=value.duplicate(true);associate_text=active_text;associate_art=art;associate_action=action;associate_commit=commit
	if changed and not associate_applying and child=="package-associate" and scope==associate_scope:open_associate()
	return true
func open_associate() -> void:
	associate.set_context(associate_context,associate_text,associate_art,ticket);associate.open();associate.start()
func associate_action_requested(operation: String,value: Dictionary,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="package-associate" or not associate_action.is_valid():return
	associate_applying=true;associate_action.call(operation,value,scope.duplicate(),value_ticket.duplicate());associate_applying=false
func associate_result(accepted: bool,value: Dictionary,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="package-associate" or not associate_commit.is_valid():return
	associate_applying=true;var result: Variant=associate_commit.call(accepted,value,scope.duplicate());associate_applying=false
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("accepted",false):associate.open();return
	if not accepted:accept_child(value_ticket,3)
	else:retire_child();open_child(str(result.next),int(result.code))
func open_child(tag: String,code: int=0x8010) -> void:
	if closed or not wanted: return
	serial+=1; child=tag; ticket=scope+[serial,tag]; main.dismiss()
	if is_instance_valid(status_view):status_view.dismiss()
	if tag=="portraitbutton" and scope==portrait_scope and is_instance_valid(portrait_art) and portrait_catalog!=null:
		portrait.set_context(portrait_values,current_portrait,ticket,portrait_art,portrait_catalog); portrait.open()
	elif tag=="genderbutton" and scope==gender_scope and gender_commit.is_valid():
		gender.set_context(current_gender,ticket);gender.open()
	elif tag=="racebutton" and scope==race_scope and race_commit.is_valid():
		race.set_context(race_values,current_race,current_subrace,race_recommended,race_text,race_art,ticket);race.open()
	elif tag=="classbutton" and scope==class_scope and class_commit.is_valid():
		class_chooser.set_context(class_values,class_recommended,class_text,class_art,ticket);class_chooser.open()
	elif tag=="alignbutton" and scope==alignment_scope and alignment_commit.is_valid():open_alignment()
	elif tag=="abilitiesbutton" and scope==attributes_scope and attributes_commit.is_valid() and attributes_edit.is_valid():open_attributes()
	elif tag=="packagesbutton" and scope==packages_scope and packages_enter.is_valid() and packages_commit.is_valid():
		var identity:=ticket.duplicate();packages_applying=true;var entered: Variant=packages_enter.call(scope.duplicate());packages_applying=false
		if not owns(identity):return
		if not bool(entered):accept_child(identity,3);return
		open_packages()
	elif tag=="package-configuration" and scope==skills_scope and skills_edit.is_valid() and skills_commit.is_valid():open_skills()
	elif tag=="package-feats" and scope==feats_scope and feats_edit.is_valid() and feats_commit.is_valid():open_feats()
	elif tag=="package-school" and scope==school_scope and school_commit.is_valid():open_school()
	elif tag=="package-domains" and scope==domains_scope and domains_commit.is_valid():open_domains()
	elif tag=="package-spells" and scope==spells_scope and spells_enter.is_valid() and spells_edit.is_valid() and spells_commit.is_valid():open_spells()
	elif tag=="package-associate" and scope==associate_scope and associate_action.is_valid() and associate_commit.is_valid():open_associate()
	elif tag=="package-post-skills" and scope==post_scope and post_continue.is_valid():post_code=code;post_pending_emitted=false;route_post(ticket.duplicate())
	else: child_requested.emit(tag,ticket.duplicate())
	place()
func owns(value_ticket: Array) -> bool: return not closed and wanted and not child.is_empty() and ticket==value_ticket
func accept_child(value_ticket: Array,code: int) -> bool:
	if not owns(value_ticket): return false
	retire_child()
	context.paladinRuleDefault=Flow.paladin_rule_default(classes)
	flow.result(code,context); dispatch(); refresh(); return true
func portrait_result(accepted: bool,base: String,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="portraitbutton": return
	if accepted:
		if not portrait_values.has(base) or not portrait_commit.is_valid() or not bool(portrait_commit.call(base,scope.duplicate())):
			if owns(value_ticket): portrait.open()
			return
		# A commit callback can retire/rebind this frontend. Its return alone
		# must never validate a result belonging to the replacement draft.
		if not owns(value_ticket): return
		current_portrait=base
	accept_child(value_ticket,0x8009 if accepted else 2)
func gender_result(accepted: bool,selected: int,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="genderbutton":return
	if not accepted:accept_child(value_ticket,2);return
	if not gender_commit.is_valid():gender.open();return
	# A real commit refreshes this same draft. Its changed gender must not
	# reticket its own in-flight OK; independent replacements still retire it.
	gender_applying=true;var result: Variant=gender_commit.call(selected,scope.duplicate());gender_applying=false
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("accepted",false) or int(result.get("code",0)) not in [0x800d,0x8017]:gender.open();return
	current_gender=int(result.gender);accept_child(value_ticket,int(result.code))
func race_result(accepted: bool,selected: int,subrace_value: Variant,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="racebutton":return
	if not accepted:accept_child(value_ticket,2);return
	if not race_commit.is_valid():race.open();return
	race_applying=true;var result: Variant=race_commit.call(selected,subrace_value,scope.duplicate());race_applying=false
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("accepted",false) or int(result.get("code",0))!=0x800a:
		race.current_subrace=current_subrace;race.open();return
	current_race=int(result.race);current_subrace=str(result.subrace);accept_child(value_ticket,0x800a)
func dispatch() -> void:
	var value_scope:=scope.duplicate(); var source_generation:=generation
	for operation in flow.calls.duplicate():
		if closed or not wanted or scope!=value_scope or generation!=source_generation: return
		match str(operation):
			"portrait": open_child("portraitbutton")
			"appearance": open_child("appearance")
			"deactivate:2": finish(true)
			"delete": pass # Reusable native resources survive; scoped UI ownership does not.
			_: command_requested.emit(str(operation),value_scope.duplicate())
func class_result(accepted: bool,selected: int,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="classbutton":return
	if not accepted:accept_child(value_ticket,2);return
	if not class_commit.is_valid():class_chooser.open();return
	class_applying=true;var result: Variant=class_commit.call(selected,scope.duplicate());class_applying=false
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("accepted",false) or int(result.get("code",0))!=0x8004:class_chooser.open();return
	context.classBase=int(result.classId);accept_child(value_ticket,0x8004)
func alignment_result(accepted: bool,selected: int,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="alignbutton":return
	if not accepted:accept_child(value_ticket,2);return
	if not alignment_commit.is_valid():alignment.open();return
	alignment_applying=true;var result: Variant=alignment_commit.call(selected,scope.duplicate());alignment_applying=false
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("accepted",false) or int(result.get("code",0))!=0x8001:alignment.open();return
	accept_child(value_ticket,0x8001)
func refresh() -> void:
	if closed or not is_instance_valid(main): return
	var enabled:=flow.enabled.duplicate(); enabled.cancel=true; enabled.reset=true
	if phase in ["preparing","waiting"]:
		for key in enabled:enabled[key]=false
		enabled.cancel=phase=="preparing"
	main.set_context(scope,enabled,flow.completed,flow.encouraged)
	if is_instance_valid(main.summary_view):
		for tab in main.summary_view.tabs:tab.disabled=phase in ["preparing","waiting"]
	pull_summary()
	main.visible=wanted and child.is_empty() and main.layout_ready
	refresh_status()
	if not wanted: surface.hide()
	place()
func attributes_action(operation: String,index: int,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="abilitiesbutton" or not attributes_edit.is_valid():return
	attributes_applying=true;var result: Variant=attributes_edit.call(operation,index,scope.duplicate());attributes_applying=false
	if not owns(value_ticket):return
	if result is Dictionary and result.get("ready",false):attributes.update_model(result)
func attributes_result(accepted: bool,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="abilitiesbutton":return
	if not accepted:accept_child(value_ticket,2);return
	if not attributes_commit.is_valid():attributes.open();return
	attributes_applying=true;var result: Variant=attributes_commit.call(scope.duplicate());attributes_applying=false
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("accepted",false) or int(result.get("code",0))!=0x8003:attributes.open();return
	accept_child(value_ticket,0x8003)
func packages_result(operation: String,selected: int,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="packagesbutton":return
	if operation=="cancel":
		if packages_commit.is_valid():await packages_commit.call("cancel",selected,scope.duplicate(),value_ticket.duplicate())
		if owns(value_ticket):accept_child(value_ticket,3)
		return
	if not packages_commit.is_valid():packages.set_busy(false);return
	packages_applying=true;var result: Variant=await packages_commit.call(operation,selected,scope.duplicate(),value_ticket.duplicate())
	if not owns(value_ticket):return
	packages_applying=false
	if not result is Dictionary or not result.get("accepted",false):
		serial+=1;ticket=scope+[serial,child];open_packages()
		if result is Dictionary:packages.set_operation_status(str(result.get("error",result.get("reason",""))))
		return
	if operation=="configure" and result.get("configure",false):
		# Original8e1ec0 transfers CG_MAIN's callback to the configuration modal
		# without marking Package complete. Skills owns this transferred child;
		# its remaining Feats/class-dependent continuations are still staged.
		retire_child();open_child("package-configuration")
	elif operation=="automatic" and int(result.get("code",0))==0x8008:accept_child(value_ticket,0x8008)
	else:packages.set_busy(false)
func skills_action(operation: String,id: int,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="package-configuration" or not skills_edit.is_valid():return
	var text_revision:=skills_text_revision
	if operation=="recommend":skills.set_busy(true)
	skills_applying=true;var result: Variant=await skills_edit.call(operation,id,scope.duplicate(),value_ticket.duplicate());skills_applying=false
	if not owns(value_ticket):return
	if text_revision!=skills_text_revision:
		serial+=1;ticket=scope+[serial,child];open_skills();return
	skills.set_busy(false)
	if result is Dictionary and result.get("ready",false):skills.update_model(result)
func skills_result(accepted: bool,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="package-configuration" or not skills_commit.is_valid():return
	skills_applying=true;var result: Variant=skills_commit.call(accepted,scope.duplicate());skills_applying=false
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("accepted",false):skills.open();return
	if not accepted:accept_child(value_ticket,3)
	else:
		# Transfer the existing Package chain callback. Unported Feats/next
		# screens remain explicit child requests, not false Package completion.
		retire_child();open_child(str(result.next),int(result.get("code",0x8010)))
func feats_action(operation: String,id: int,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="package-feats" or not feats_edit.is_valid():return
	var text_revision:=feats_text_revision
	if operation=="recommend":feats.set_busy(true)
	feats_applying=true;var result: Variant=await feats_edit.call(operation,id,scope.duplicate(),value_ticket.duplicate());feats_applying=false
	if not owns(value_ticket):return
	if text_revision!=feats_text_revision:
		serial+=1;ticket=scope+[serial,child];open_feats();return
	feats.set_busy(false)
	if result is Dictionary:feats.update_model(result)
func feats_result(accepted: bool,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="package-feats" or not feats_commit.is_valid():return
	feats_applying=true;var result: Variant=feats_commit.call(accepted,scope.duplicate());feats_applying=false
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("accepted",false):feats.open();return
	if not accepted:accept_child(value_ticket,3)
	else:
		retire_child();open_child(str(result.next),int(result.code))
func school_result(accepted: bool,selected: int,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="package-school" or not school_commit.is_valid():return
	school_applying=true;var result: Variant=school_commit.call(accepted,selected,scope.duplicate());school_applying=false
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("accepted",false):school.open();return
	if not accepted:accept_child(value_ticket,3)
	else:retire_child();open_child(str(result.next),int(result.code))
func domains_result(accepted: bool,selected: Array,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="package-domains" or not domains_commit.is_valid():return
	domains_applying=true;var result: Variant=domains_commit.call(accepted,selected,scope.duplicate());domains_applying=false
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("accepted",false):domains.open();return
	if not accepted:accept_child(value_ticket,3)
	else:retire_child();open_child(str(result.next),int(result.code))
func spells_action(operation: String,id: int,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="package-spells" or not spells_edit.is_valid():return
	var text_revision:=spells_text_revision
	if operation=="recommend":spells.set_busy(true)
	spells_applying=true;var result: Variant=await spells_edit.call(operation,id,scope.duplicate(),value_ticket.duplicate());spells_applying=false
	if not owns(value_ticket):return
	if result is Dictionary:spells_context=result.duplicate(true)
	if text_revision!=spells_text_revision:
		serial+=1;ticket=scope+[serial,child];show_spells();return
	spells.set_busy(false)
	if result is Dictionary:spells.update_model(result)
func spells_result(accepted: bool,value_ticket: Array) -> void:
	if not owns(value_ticket) or child!="package-spells" or not spells_commit.is_valid():return
	spells_applying=true;var result: Variant=spells_commit.call(accepted,scope.duplicate());spells_applying=false
	if not owns(value_ticket):return
	if not result is Dictionary or not result.get("accepted",false):spells.open();return
	if not accepted:accept_child(value_ticket,3)
	else:retire_child();open_child(str(result.next),int(result.code))
func place() -> void:
	if closed or not is_instance_valid(surface): return
	var extent:=get_viewport().get_visible_rect().size
	for panel in [main,portrait,gender,race,class_chooser,alignment,attributes,packages,skills,feats,school,domains,spells,associate]:
		if not is_instance_valid(panel) or panel.size.x<=0 or panel.size.y<=0: continue
		var factor:=minf(1.0,minf(extent.x/panel.size.x,extent.y/panel.size.y)); panel.scale=Vector2.ONE*factor; panel.position=(extent-panel.size*factor)*0.5
	# Keep the source notice entirely within the embedded summary footprint;
	# CG_MAIN's left-hand buttons remain visible even at smaller viewports.
	if is_instance_valid(status_view) and status_view.layout_ready and is_instance_valid(main.summary_view):
		var area:=Rect2(main.position+main.summary_host.position*main.scale,main.summary_view.size*main.scale)
		var factor:=minf(1.0,minf(area.size.x/status_view.size.x,area.size.y/status_view.size.y))
		status_view.scale=Vector2.ONE*factor;status_view.position=area.position+(area.size-status_view.size*factor)*0.5
func _input(event: InputEvent) -> void:
	if not closed and wanted and child.is_empty() and phase in ["preparing","waiting"] and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if phase=="preparing":finish(true)
		get_viewport().set_input_as_handled()
func retire_child() -> void:
	serial+=1; child=""; ticket=[]
	packages_applying=false
	if is_instance_valid(portrait): portrait.dismiss()
	if is_instance_valid(gender):gender.dismiss()
	if is_instance_valid(race):race.dismiss()
	if is_instance_valid(class_chooser):class_chooser.dismiss()
	if is_instance_valid(alignment):alignment.dismiss()
	if is_instance_valid(attributes):attributes.dismiss()
	if is_instance_valid(packages):packages.dismiss()
	if is_instance_valid(skills):skills.dismiss()
	if is_instance_valid(feats):feats.dismiss()
	if is_instance_valid(school):school.dismiss()
	if is_instance_valid(domains):domains.dismiss()
	if is_instance_valid(spells):spells.dismiss()
	if is_instance_valid(associate):associate.dismiss()
	if is_instance_valid(main): main.retire_input()
func finish(cancelled: bool) -> void:
	var old_scope:=scope.duplicate(); dismiss(); finished.emit(cancelled,old_scope)
func dismiss() -> void:
	generation+=1; wanted=false; retire_child()
	phase_status="";phase_revision+=1
	if is_instance_valid(status_view):status_view.dismiss()
	clear_summary()
	if is_instance_valid(main): main.dismiss()
	if is_instance_valid(surface): surface.hide()
func close() -> void:
	if closed: return
	dismiss(); closed=true
	if is_instance_valid(main): main.close()
	if is_instance_valid(status_view):status_view.close()
	for page in summary_lists.values(): page.close()
	summary_lists.clear()
	if is_instance_valid(portrait): portrait.close()
	if is_instance_valid(gender):gender.close()
	if is_instance_valid(race):race.close()
	if is_instance_valid(class_chooser):class_chooser.close()
	if is_instance_valid(alignment):alignment.close()
	if is_instance_valid(attributes):attributes.close()
	if is_instance_valid(packages):packages.close()
	if is_instance_valid(skills):skills.close()
	if is_instance_valid(feats):feats.close()
	if is_instance_valid(school):school.close()
	if is_instance_valid(domains):domains.close()
	if is_instance_valid(spells):spells.close()
	if is_instance_valid(associate):associate.close()
	associate_action=Callable();associate_commit=Callable();associate_scope=[];associate_context={};associate_text=null;associate_art=null
	spells_enter=Callable();spells_edit=Callable();spells_commit=Callable();spells_scope=[];spells_context={};spells_text=null;spells_art=null
	domains_commit=Callable();domains_scope=[];domains_context={};domains_signature=[];domains_text=null;domains_art=null
	school_commit=Callable();school_scope=[];school_context={};school_text=null;post_continue=Callable();post_scope=[]
	feats_edit=Callable();feats_commit=Callable();feats_scope=[];feats_context={};feats_text=null;feats_art=null
	skills_edit=Callable();skills_commit=Callable();skills_scope=[];skills_context={};skills_text=null;skills_art=null
	packages_enter=Callable();packages_commit=Callable();packages_scope=[];packages_context={};packages_text=null;packages_art=null
	attributes_edit=Callable();attributes_commit=Callable();attributes_scope=[];attributes_context={};attributes_text=null
	alignment_commit=Callable();alignment_scope=[];alignment_context={};alignment_text=null
	class_commit=Callable();class_scope=[];class_values={};class_text=null;class_art=null
	race_commit=Callable();race_scope=[];race_values=[];race_text=null;race_art=null
	gender_commit=Callable();gender_scope=[]
	portrait_commit=Callable(); portrait_art=null; portrait_catalog=null; classes=[]
func _exit_tree() -> void: close()
