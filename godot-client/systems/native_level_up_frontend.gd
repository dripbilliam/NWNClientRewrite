extends CanvasLayer
# Original mode1 children over a private level-up draft. Creation's CG_MAIN
# coordinator and first-level models are deliberately separate owners.
signal action_requested(stage: String,operation: String,id: int,ticket: Array)
signal accepted(stage: String,id: int,ticket: Array)
signal cancelled(ticket: Array)
signal submit_requested(ticket: Array)
signal unavailable(stage: String,reason: String,ticket: Array)
signal child_accepted(stage: String,value: Variant,ticket: Array)
signal child_action_requested(stage: String,operation: String,value: Dictionary,ticket: Array)
const Classes=preload("res://systems/native_level_up_class.gd")
const Attributes=preload("res://systems/native_level_up_attributes.gd")
const Summary=preload("res://systems/native_level_up_summary.gd")
const Skills=preload("res://systems/native_level_up_skills.gd")
const Feats=preload("res://systems/native_level_up_feats.gd")
const Spells=preload("res://systems/native_spells_chooser.gd")
const Domains=preload("res://systems/native_level_up_domains.gd")
const School=preload("res://systems/native_level_up_school.gd")
const Associate=preload("res://systems/native_associate_chooser.gd")
const SourceTitle=preload("res://systems/native_data/level_up_title_presentation.gd")
var painter
var text
var catalog
var cache_directory:=""
var modal_order
var modal_surfaces
var surface: Control
var panes: Dictionary={}
var scope: Array=[]
var ticket: Array=[]
var stage:=""
var serial:=0
var wanted:=false
var closed:=false
var preparation_failed: Array=[]
var source_title_reader: Callable
var source_title_binding:=SourceTitle.new()
func configure(frame,base_text,base_catalog,cache_path: String) -> void:
	if surface!=null:return
	painter=frame;text=base_text;catalog=base_catalog;cache_directory=cache_path;layer=45
	surface=Control.new();add_child(surface);surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.mouse_filter=Control.MOUSE_FILTER_IGNORE;surface.hide()
	get_viewport().size_changed.connect(place)
	if is_instance_valid(painter.fonts) and painter.fonts.has_signal("loaded"):painter.fonts.loaded.connect(source_title_font_loaded)
func configure_title_reader(reader: Callable) -> void:
	source_title_reader=reader
func source_title_font_loaded(_resource: String) -> void:
	if not closed:refresh_source_title(ticket.duplicate())
func source_title_prepared(key: String,pane) -> void:
	if not closed and key==stage and is_instance_valid(pane):refresh_source_title(pane.scope.duplicate())
func refresh_source_title(value: Array) -> void:
	if not owns(value) or not SourceTitle.CALLERS.has(stage) or not panes.has(stage) or not source_title_reader.is_valid():return
	var pane=panes[stage]
	if not pane.layout_ready or pane.scope!=value:return
	if not source_title_binding.current(value):
		var begun: Dictionary=source_title_binding.begin(pane,stage,pane.caption(pane.plan.entries.title),value)
		if not begun.ready:return
	var payload: Variant=source_title_reader.call(value)
	if not payload is Dictionary or not payload.get("ready",false):
		source_title_binding.present(null,[],{},null,value);return
	source_title_binding.present(payload.parts,payload.classes,payload.tables,payload.text,value)
func configure_owners(order,surfaces) -> void:
	modal_order=order;modal_surfaces=surfaces
	for key in panes:bind_modal(str(key),panes[key])
func bind_modal(key: String,pane) -> void:
	#837dc0:Class ModalActivate;838950:Summary ModalActivate.
	#8e36d0:Attributes uses CGuiPanel::Activate, not the modal array.
	#9c3040 and SkillsOK9c8d10's Feats handoff activate these modally too.
	if key not in ["class","skills","feats","summary"]:return
	pane.set_modal_owner(modal_order,"other")
	if is_instance_valid(modal_surfaces):modal_surfaces.bind_layer(pane,self)
	if key=="feats":
		pane.info_popup.set_modal_order(modal_order);pane.group_popup.set_modal_order(modal_order)
		if is_instance_valid(modal_surfaces):modal_surfaces.bind_layer(pane.info_popup,self);modal_surfaces.bind_layer(pane.group_popup,self)
func ensure_pane(key: String):
	if panes.has(key):return panes[key]
	var pane
	match key:
		"class":pane=Classes.new();pane.finished.connect(class_result)
		"attributes":pane=Attributes.new();pane.finished.connect(attributes_result);pane.action_requested.connect(attributes_action)
		"skills":pane=Skills.new();pane.finished.connect(middle_result.bind("skills"));pane.action_requested.connect(middle_action.bind("skills"))
		"feats":pane=Feats.new();pane.finished.connect(middle_result.bind("feats"));pane.action_requested.connect(middle_action.bind("feats"))
		"spells":pane=Spells.new();pane.finished.connect(middle_result.bind("spells"));pane.action_requested.connect(middle_action.bind("spells"))
		"domains":pane=Domains.new();pane.finished.connect(child_result.bind("domains"));pane.recommendation_requested.connect(post_recommendation.bind("domains"))
		"school":pane=School.new();pane.finished.connect(child_result.bind("school"));pane.recommendation_requested.connect(post_recommendation.bind("school"))
		"associate":pane=Associate.new();pane.finished.connect(child_result.bind("associate"));pane.action_requested.connect(associate_action)
		"summary":pane=Summary.new();pane.submit_requested.connect(summary_submit);pane.cancelled.connect(summary_cancel)
		_:return null
	surface.add_child(pane);panes[key]=pane;pane.configure(painter,text,catalog,cache_directory);pane.prepared.connect(place);bind_modal(key,pane)
	pane.prepared.connect(source_title_prepared.bind(key,pane))
	pane.assets.completed.connect(func(_id,_result):check_preparation(key,pane))
	return pane
func check_preparation(key: String,pane) -> void:
	if closed or not wanted or stage!=key or str(pane.failure).is_empty() or preparation_failed==ticket:return
	preparation_failed=ticket.duplicate();unavailable.emit(stage,str(pane.failure),ticket.duplicate())
func start_stage(key: String,identity: Array):
	if closed or surface==null:return null
	dismiss_children();scope=identity.duplicate();serial+=1;ticket=scope+[serial,key];stage=key;wanted=true;preparation_failed=[];surface.show()
	return ensure_pane(key)
func present_class(model: Dictionary,recommended: bool,active_text,art,identity: Array) -> void:
	var pane=start_stage("class",identity)
	if pane==null:return
	pane.set_context(model,recommended,active_text,art,ticket);pane.open();pane.start();place();check_preparation("class",pane)
func present_waiting(active_text,art,identity: Array,message: String) -> void:
	present_class({"ready":false,"entries":[],"recommended":{}},false,active_text,art,identity)
	if panes.has("class"):panes["class"].set_waiting(message)
func class_selection(id: int) -> void:
	if closed or not wanted or stage!="class" or not panes.has("class"):return
	var pane=panes["class"]
	for index in pane.state.entries.size():
		if int(pane.state.entries[index].id)==id:pane.state.select_index(index);pane.refresh();return
func class_selection_id() -> int:
	return int(panes["class"].state.selected_class()) if not closed and wanted and stage=="class" and panes.has("class") and panes["class"].wanted else -1
func prepare_class(message: String,identity: Array) -> void:
	if closed or not wanted or stage!="class" or scope!=identity or not panes.has("class"):return
	var pane=panes["class"];pane.set_waiting(message)
	if not pane.wanted:pane.open()
	place()
func class_problem(message: String,identity: Array) -> void:
	if closed or not wanted or stage!="class" or scope!=identity or not panes.has("class"):return
	var pane=panes["class"]
	if is_instance_valid(pane.help_region):pane.help_region.present_content(pane.data_text if pane.data_text!=null else text,4294967295,4294967295,message)
func present_attributes(model: Dictionary,recommended: bool,active_text,identity: Array) -> void:
	var pane=start_stage("attributes",identity)
	if pane==null:return
	pane.set_context(model,recommended,active_text,ticket);pane.open();pane.start();place();check_preparation("attributes",pane)
func update_attributes(model: Dictionary,identity: Array) -> void:
	if closed or not wanted or stage!="attributes" or scope!=identity:return
	panes.attributes.update_model(model)
func recommendation_busy(key: String,value: bool,message: String="") -> void:
	if closed or not wanted or stage!=key or key not in ["attributes","skills","feats","spells","domains","school"] or not panes.has(key):return
	var pane=panes[key];pane.set_busy(value)
	if key in ["attributes","skills"] and not message.is_empty() and is_instance_valid(pane.help):
		var active_text=pane.data_text if pane.data_text!=null else text
		pane.help.present_content(active_text,4294967295,4294967295,message)
func present_middle(key: String,model: Dictionary,recommended: bool,active_text,art,identity: Array) -> void:
	if key not in ["skills","feats","spells"]:return
	var pane=start_stage(key,identity)
	if pane==null:return
	pane.set_context(model,recommended,active_text,art,ticket);pane.open();pane.start();place();check_preparation(key,pane)
	refresh_source_title(ticket.duplicate())
func update_middle(key: String,model: Dictionary,identity: Array) -> void:
	if closed or not wanted or stage!=key or scope!=identity or key not in ["skills","feats","spells"]:return
	panes[key].update_model(model)
func middle_action(operation: String,index: int,value: Array,key: String) -> void:
	if owns(value) and stage==key:action_requested.emit(stage,operation,index,value.duplicate())
func middle_result(allow: bool,value: Array,key: String) -> void:
	if not owns(value) or stage!=key:return
	if allow:accepted.emit(stage,-1,value.duplicate())
	else:cancelled.emit(value.duplicate())
func present_child(key: String,model: Dictionary,recommended: bool,active_text,art,identity: Array) -> void:
	if key not in ["domains","school","associate"]:return
	var pane=start_stage(key,identity)
	if pane==null:return
	#9c69a0 activates these post-feat children through CGuiPanel::Activate;
	# they do not receive a fabricated modal-array registration here.
	if key=="domains":pane.set_context(model,recommended,active_text,art,ticket)
	elif key=="school":pane.set_context(model,recommended,active_text,ticket)
	else:pane.set_context(model,active_text,art,ticket)
	pane.open();pane.start();place();check_preparation(key,pane)
	refresh_source_title(ticket.duplicate())
func child_result(allow: bool,result: Variant,value: Array,key: String) -> void:
	if not owns(value) or stage!=key:return
	if allow:child_accepted.emit(key,result,value.duplicate())
	else:cancelled.emit(value.duplicate())
func associate_action(operation: String,value: Dictionary,identity: Array) -> void:
	if owns(identity) and stage=="associate":child_action_requested.emit(stage,operation,value,identity.duplicate())
func post_recommendation(value: Array,key: String) -> void:
	if owns(value) and stage==key:action_requested.emit(key,"recommend",-1,value.duplicate())
func begin_post_recommendation(key: String,value: Array) -> bool:
	if not owns(value) or stage!=key or key not in ["domains","school"] or not panes.has(key):return false
	var pane=panes[key]
	return pane.scope==value and pane.begin_recommendation()
func apply_post_recommendation(key: String,result: Dictionary,value: Array) -> Dictionary:
	if not owns(value) or stage!=key or key not in ["domains","school"] or not panes.has(key):return {"ready":false,"reason":"The recommendation pane retired."}
	var pane=panes[key]
	if pane.scope!=value:return {"ready":false,"reason":"The recommendation pane changed."}
	return pane.apply_recommendation(result)
func present_summary(content: String,ready: bool,identity: Array) -> void:
	var pane=start_stage("summary",identity)
	if pane==null:return
	pane.set_context(content,ticket,ready);pane.open();pane.start();place();check_preparation("summary",pane)
func owns(value: Array) -> bool:return not closed and wanted and not ticket.is_empty() and ticket==value
func class_result(allow: bool,id: int,value: Array) -> void:
	if not owns(value) or stage!="class":return
	if allow:accepted.emit(stage,id,value.duplicate())
	else:cancelled.emit(value.duplicate())
func attributes_action(operation: String,index: int,value: Array) -> void:
	if owns(value) and stage=="attributes":action_requested.emit(stage,operation,index,value.duplicate())
func attributes_result(allow: bool,value: Array) -> void:
	if not owns(value) or stage!="attributes":return
	if allow:accepted.emit(stage,-1,value.duplicate())
	else:cancelled.emit(value.duplicate())
func summary_submit(value: Array) -> void:
	if owns(value) and stage=="summary":submit_requested.emit(value.duplicate())
func summary_cancel(value: Array) -> void:
	if owns(value) and stage=="summary":cancelled.emit(value.duplicate())
func dismiss_children() -> void:
	source_title_binding.retire()
	for pane in panes.values():pane.dismiss()
func dismiss() -> void:
	dismiss_children();wanted=false;ticket=[];scope=[];stage="";serial+=1
	if is_instance_valid(surface):surface.hide()
func place() -> void:
	if closed:return
	var dimensions:=get_viewport().get_visible_rect().size
	for pane in panes.values():
		if pane.layout_ready:pane.position=(dimensions-pane.size)*0.5
func close() -> void:
	if closed:return
	dismiss();closed=true
	for pane in panes.values():pane.close()
	panes.clear();source_title_reader=Callable();painter=null;text=null;catalog=null;modal_order=null;modal_surfaces=null
func _exit_tree() -> void:close()
