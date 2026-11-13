extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Model=preload("res://systems/native_data/actor_model.gd")
const TwoDa=preload("res://systems/native_data/two_da.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Doubles=preload("res://tests/native_portrait_chooser_test.gd")
const Attributes=preload("res://systems/native_level_up_attributes.gd")
const Summary=preload("res://systems/native_level_up_summary.gd")
const Classes=preload("res://systems/native_level_up_class.gd")
const AbilityState=preload("res://systems/native_data/level_up_attributes_state.gd")
const ClassState=preload("res://systems/native_data/level_up_class_state.gd")
class Art extends Doubles.HeadlessArt:
	func close() -> void:bindings.clear()
var surface: SubViewport
var painter
var base_text
var active_text
var catalog
var checks:=0
var failures: Array=[]
var choice:=AbilityState.new()
var refresh_us: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func frames(count: int=3) -> void:
	for index in count:await process_frame
func mouse(button: Button,pressed: bool) -> void:
	var point: Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;surface.push_input(motion,true);await process_frame
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;surface.push_input(event,true);await process_frame
func click(button: Button) -> void:await mouse(button,true);await mouse(button,false);await frames()
func collect(node: Dictionary,resources: Dictionary) -> void:
	var name:=str(node.get("Obj_ResRef","")).to_lower()
	if not name.is_empty():resources[name]=true
	for child in node.get("Obj_ChildList",[]):collect(child,resources)
func publish_source(pane) -> void:
	surface.add_child(pane);pane.configure(painter,base_text,catalog,"");pane.position=Vector2(100,70)
	var parser:=Gff.new();var document:=parser.parse(catalog.get_resource(pane.resource,2047));pane.source=document.get("root",{})
	check(parser.failure.is_empty(),"Actual installed GUI decodes: "+str(pane.resource))
	var resources: Dictionary={};collect(pane.source,resources)
	for name in pane.extra_models:resources[name]=true
	for name in resources:
		var decoder:=Model.new();pane.models[name]=decoder.parse(catalog.get_resource(name,2002));check(decoder.failure.is_empty(),"Actual installed source model decodes: "+str(name))
	pane.plan=pane.parse_layout();check(str(pane.plan.get("error","")).is_empty(),"Level-up source hooks/layout are complete: "+str(pane.resource))
	if not str(pane.plan.get("error","")).is_empty():return
	pane.size=pane.plan.size;pane.custom_minimum_size=pane.size;pane.assemble();pane.layout_ready=true;pane.refresh()
	check(pane.failure.is_empty(),"Real native source controls assemble: "+str(pane.resource))
func attribute_model() -> Dictionary:
	var raw: Array=[12,14,16,18,10,8]
	if choice.selected>=0:raw[choice.selected]+=1
	return {"ready":true,"raw":raw,"scores":raw.duplicate(),"racial":[0,0,0,0,0,0],"gains":[0,0,0,0,0,0],"modifiers":raw.map(func(value):return floori((int(value)-10)/2.0)),"points":choice.points(),"selectedAbility":choice.selected}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	catalog=Catalog.new();check(catalog.mount_install(args.install),"Original source catalog mounts read-only")
	base_text=preload("res://systems/native_data/talk_text.gd").new();active_text=preload("res://systems/native_data/talk_text.gd").new();check(base_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")) and active_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Source captions and active descriptions have independent TLK owners")
	surface=SubViewport.new();surface.size=Vector2i(1200,850);surface.disable_3d=true;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	painter=Painter.new();painter.art=Art.new();painter.fonts=Doubles.HeadlessFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);painter.art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var tables: Dictionary={};var parser:=TwoDa.new();tables.classes=parser.parse(catalog.get_resource("classes",2017).get_string_from_ascii());tables.ruleset={"orderedRows":[{"Label":"MULTICLASS_LIMIT","Value":"1"}]}
	var available: Array=[];available.resize(tables.classes.orderedRows.size()&255);available.fill(true)
	var context:={"classes":[{"id":10,"level":15},{"id":4,"level":1}],"available":available,"currentClassIndex":1,"multiclassRulesetFeature":true}
	var class_ref: int=int(tables.classes.orderedRows[4].Name);active_text.overrides[class_ref]="Active server class"
	var values: Dictionary=ClassState.compose(tables,active_text,context)
	check(values.ready and values.recommendedId==4 and values.classLimit==1 and values.entries.filter(func(row):return row.enabled).all(func(row):return int(row.id) in [4,10]),"Active physical classes, received slots/bitmap and ruleset limit drive original level-up rows")
	context.multiclassRulesetFeature=false;var legacy: Dictionary=ClassState.compose(tables,active_text,context)
	check(legacy.classLimit==3 and legacy.entries.filter(func(row):return row.enabled).size()>2,"Original old-protocol class limit does not use a later ruleset feature")
	var class_pane:=Classes.new();publish_source(class_pane);var class_results: Array=[];class_pane.finished.connect(func(accepted,id,ticket):class_results.append([accepted,id,ticket]))
	class_pane.set_context(values,true,active_text,painter.art,["level",1]);class_pane.open();await frames()
	if not is_instance_valid(class_pane.title) or not is_instance_valid(class_pane.help_title):
		print(JSON.stringify({"classification":"class-publication","resource":class_pane.resource,"listTag":class_pane.list_tag,"layoutReady":class_pane.layout_ready,"failure":class_pane.failure,"planError":class_pane.plan.get("error",""),"models":class_pane.models.keys(),"stateClass":str(class_pane.state.get_script().resource_path),"priorFailures":failures}))
		class_pane.close();class_pane.queue_free();painter.art.close();painter.close();painter.queue_free();base_text.close();active_text.close();await frames(5);surface.queue_free();await frames();quit(1);return
	check(class_pane.state.selected_class()==4 and class_pane.title.text==class_pane.caption(class_pane.plan.entries.title) and class_pane.help_title.text=="Active server class","Level-up keeps original resource title while row/help text uses the active TLK")
	var initial_ids: Array=class_pane.row_buttons.map(func(button):return button.get_instance_id())
	for sample in 200:
		var began:=Time.get_ticks_usec();class_pane.refresh();refresh_us.append(Time.get_ticks_usec()-began)
	check(initial_ids==class_pane.row_buttons.map(func(button):return button.get_instance_id()),"Warm original class refresh reuses the real row controls")
	await click(class_pane.buttons.okbutton);check(class_results==[[true,4,["level",1]]] and not class_pane.wanted,"Physical original class OK returns the selected physical ID/scope once")
	class_pane.set_context(values,true,active_text,painter.art,["level",2]);class_pane.open();await frames();await mouse(class_pane.buttons.okbutton,true);class_pane.set_context(values,true,active_text,painter.art,["level",3]);await mouse(class_pane.buttons.okbutton,false);await frames()
	check(class_results.size()==1,"Held class OK cannot commit a replacement level-up owner")
	class_pane.dismiss()
	var attributes:=Attributes.new();publish_source(attributes);var results: Array=[];attributes.finished.connect(func(accepted,ticket):results.append([accepted,ticket]))
	attributes.action_requested.connect(func(operation,index,_ticket):
		if operation=="recommend":choice.recommend("WIS")
		else:choice.move(index,1 if operation=="up" else -1)
		attributes.update_model(attribute_model()))
	attributes.set_context(attribute_model(),true,active_text,["level",4]);attributes.open();await frames()
	check(attributes.size.is_equal_approx(Vector2(742,526)) and attributes.buttons.size()==21 and attributes.title.text==base_text.raw({"strRef":66177}) and attributes.cost==null and attributes.points.text=="1","Original level-up-specific artwork/title/point box and twelve arrows are present, without creation's cost box")
	await click(attributes.buttons.strupbutton);check(choice.selected==0 and attributes.points.text=="0" and not attributes.buttons.okbutton.disabled,"Physical original arrow spends exactly the one increase")
	var help_before: String=attributes.help.body.get_parsed_text();await click(attributes.buttons.dexupbutton);await click(attributes.buttons.dexdownbutton)
	check(choice.selected==0 and attributes.help.body.get_parsed_text()==help_before,"Original no-op arrows neither move the increase nor change help")
	await click(attributes.buttons.strdownbutton);check(choice.selected==-1 and attributes.points.text=="1" and attributes.buttons.okbutton.disabled,"Only the selected ability's physical decrement refunds the point")
	help_before=attributes.help.body.get_parsed_text();await click(attributes.buttons.recommendbutton)
	check(choice.selected==4 and attributes.points.text=="0" and attributes.help.body.get_parsed_text()==help_before,"Recommended uses its supplied active package attribute and preserves displayed help")
	await click(attributes.buttons.wisdownbutton);await mouse(attributes.buttons.strupbutton,true);attributes.update_model({"ready":false});await mouse(attributes.buttons.strupbutton,false);await frames()
	check(attributes.values.all(func(value):return value.text.is_empty()) and attributes.points.text.is_empty() and attributes.repeat_tag.is_empty() and not attributes.buttons.cancelbutton.disabled,"Dependency loss clears old scores and retires held repeat while keeping Cancel usable")
	await click(attributes.buttons.cancelbutton);check(results==[[false,["level",4]]] and not attributes.wanted,"Physical original Cancel retires the pending level-up pane")
	attributes.set_context(attribute_model(),true,active_text,["level",5]);attributes.open();await frames();await click(attributes.buttons.okbutton)
	check(results.size()==2 and results[1]==[true,["level",5]],"Physical original ability OK returns only the current scoped result")
	var summary:=Summary.new();publish_source(summary);var submitted: Array=[];var cancelled: Array=[];summary.submit_requested.connect(func(ticket):submitted.append(ticket));summary.cancelled.connect(func(ticket):cancelled.append(ticket))
	summary.set_context("Original level-up review\n".repeat(40),["level",6]);summary.open();await frames();await click(summary.buttons.okbutton)
	check(submitted==[["level",6]] and summary.wanted and summary.submitted and summary.buttons.okbutton.disabled,"Original summary OK submits once and stays open awaiting the real server result")
	await click(summary.buttons.okbutton);check(submitted.size()==1,"Repeated physical Summary OK cannot send a second proposal")
	await click(summary.buttons.cancelbutton);check(cancelled==[["level",6]] and not summary.wanted,"Original summary Cancel closes even after its one-shot submission latch")
	class_pane.close();attributes.close();summary.close();class_pane.queue_free();attributes.queue_free();summary.queue_free();painter.art.close();painter.close();painter.queue_free();base_text.close();active_text.close();await frames(5);surface.queue_free();await frames()
	refresh_us.sort();var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"classRefreshCpuUs":{"samples":refresh_us.size(),"median":refresh_us[100],"p95":refresh_us[190],"max":refresh_us[-1]},"gpu":false,"serverConnections":0,"originalPixelsAccepted":false,"fullLevelUpAccepted":false,"scope":"Actual installed Class/level-up Attributes/Summary GFF+MDL controls under controlled nonrendering publication, physical input and isolated draft callbacks. Active-table projection/source ownership, pending/rebind and one-shot semantics; no integrated controller/server/pixel acceptance."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
