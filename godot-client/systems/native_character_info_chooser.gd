extends Control
# Original CG_CHAR_INFO: one source screen for name/age/biography, soundset
# rows and Deity edit. Active data and final draft writes remain owner-held.
signal prepared
signal finished(accepted:bool,value:Dictionary,scope:Array)
signal voice_requested(id:int,resref:String,sample:int,scope:Array)
signal random_requested(request_id:int,scope:Array)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Layout=preload("res://systems/native_data/creation_character_info_layout.gd")
const State=preload("res://systems/native_data/creation_character_info_state.gd")
const Generic=preload("res://systems/native_generic_edit.gd")
var state:=State.new()
var frame
var text_owner
var assets
var models:Dictionary={}
var source:Dictionary={}
var plan:Dictionary={}
var jobs:Dictionary={}
var requested:Dictionary={}
var buttons:Dictionary={}
var edits:Dictionary={}
var rows:Array=[]
var scope:Array=[]
var held:Dictionary={}
var revision:=0
var random_serial:=0
var pending_random:=-1
var pending_name_fields:Array=[]
var voice_initialized_scope:Array=[]
var names_initialized_scope:Array=[]
var random_ready:=false
var scroll:ScrollContainer
var column:Control
var biography:TextEdit
var biography_scroll:ScrollContainer
var voice_bar
var biography_bar
var deity
var deity_ticket:Array=[]
var started:=false
var layout_ready:=false
var wanted:=false
var closed:=false
var failure:=""
var loading_fields:=false
var modal_lease=preload("res://systems/native_data/modal_lease.gd").new()
var modal_kind:=""
func set_modal_owner(order,verified_kind:String="")->void:
	if modal_lease.order==order and modal_kind==verified_kind:return
	modal_lease.retire();modal_kind=verified_kind;modal_lease.configure(self,order);modal_lease.bind_input(self)
	if not modal_lease.admission_changed.is_connected(modal_admission_changed):modal_lease.admission_changed.connect(modal_admission_changed)
	if is_instance_valid(deity):deity.set_modal_owner(order,"other")
	register_modal_owner()
func register_modal_owner()->void:
	if not closed and wanted and layout_ready and is_visible_in_tree() and modal_kind in ["other","unknown"]:modal_lease.activate(scope,modal_kind)
func modal_admission_changed(admitted:bool)->void:
	if not admitted:retire_input()
	else:initialize_names()
func available()->bool:return not closed and wanted and is_visible_in_tree() and modal_lease.admits()
func configure(painter,text,catalog,cache_path:String)->void:
	frame=painter;text_owner=text;mouse_filter=Control.MOUSE_FILTER_STOP;hide()
	assets=Assets.new();add_child(assets);assets.configure(catalog);assets.cache_directory=cache_path;assets.maximum_workers=2;assets.completed.connect(received)
	deity=Generic.new();add_child(deity);deity.configure(painter,text,catalog,cache_path);deity.prepared.connect(func():deity.position=(size-deity.size)*.5);deity.finished.connect(deity_result)
	if is_instance_valid(modal_lease.order):deity.set_modal_owner(modal_lease.order,"other")
func start()->void:
	if closed or started:return
	started=true;jobs[assets.request("cg_char_info",2047,"gff")]="@layout";deity.start()
	for resource in Layout.EXTRA:request_model(resource)
func request_model(resource:String)->void:
	resource=resource.to_lower()
	if resource.is_empty() or requested.has(resource):return
	# NativeScrollbar composes the source size/thumbsize hook animations. A
	# static-only layout decode deliberately cannot supply those tracks.
	requested[resource]=true;jobs[assets.request(resource,2002,"actor-model" if resource=="scrollbar_simple" else "mdl-original")]=resource
func request_children(node:Dictionary)->void:
	request_model(str(node.get("Obj_ResRef","")))
	for child in node.get("Obj_ChildList",[]):request_children(child)
func received(id:int,result:Dictionary)->void:
	if closed or not jobs.has(id):return
	var resource:String=jobs[id];jobs.erase(id)
	if not str(result.get("error","")).is_empty():failure=resource+": "+str(result.error);return
	if resource=="@layout":source=result.value.root;request_children(source)
	else:models[resource]=result.value
	if not jobs.is_empty() or source.is_empty() or not failure.is_empty():return
	plan=Layout.parse(source,models)
	if not str(plan.error).is_empty():failure=str(plan.error);return
	build()
func caption(entry:Dictionary)->String:
	var value:Dictionary=entry.get("caption",{});var ref:=int(value.get("Obj_StrRef",4294967295))
	return text_owner.raw({"strRef":ref}) if ref!=4294967295 else str(value.get("AurString_Text",""))
func build()->void:
	if closed or layout_ready:return
	size=plan.size;custom_minimum_size=size;frame.image(plan.resource,plan.main,self)
	for tag in ["descedit","soundsetedit"]:frame.image(plan.entries[tag].resource,plan.entries[tag].rect,self)
	for tag in Layout.LABELS:frame.create_label(plan.entries[tag],self,caption(plan.entries[tag]))
	for tag in Layout.EDITS:
		var edit:LineEdit=frame.create_edit(plan.entries[tag],self);edits[tag]=edit;edit.keep_editing_on_text_submit=true;edit.text_changed.connect(field_changed.bind(tag));edit.gui_input.connect(edit_input.bind(tag))
	biography_scroll=ScrollContainer.new();add_child(biography_scroll);biography_scroll.position=plan.descedit_body.position;biography_scroll.size=plan.descedit_body.size;biography_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	biography=TextEdit.new();biography_scroll.add_child(biography);biography.custom_minimum_size=Vector2(plan.descedit_body.size.x,plan.descedit_body.size.y);biography.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;biography.scroll_fit_content_height=true;biography.mouse_filter=Control.MOUSE_FILTER_STOP
	biography.add_theme_stylebox_override("normal",StyleBoxEmpty.new());biography.add_theme_stylebox_override("focus",StyleBoxEmpty.new());biography.add_theme_stylebox_override("read_only",StyleBoxEmpty.new());frame.font_style(biography,plan.entries.descedit.caption);biography.text_changed.connect(biography_changed);biography.gui_input.connect(edit_input.bind("description"))
	scroll=ScrollContainer.new();add_child(scroll);scroll.position=plan.soundsetedit_body.position;scroll.size=plan.soundsetedit_body.size;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column=Control.new();scroll.add_child(column);column.custom_minimum_size.x=scroll.size.x;scroll.get_v_scroll_bar().value_changed.connect(scrolled)
	var group:=ButtonGroup.new();var count:=ceili(scroll.size.y/maxf(1,plan.voice_row.hooks.next.y))+2
	for index in count:
		var offset:Vector2=-plan.voice_row.bounds.position;var entry:={"resource":"ctl_cg_btn_snds","offset":offset,"rect":Rect2(Vector2.ZERO,plan.voice_row.bounds.size),"caption":plan.entries.soundsetedit.caption.duplicate(true)}
		var button:Button=frame.create_button(entry,column,models,true);button.button_group=group
		var label:Label=frame.create_label(plan.voice_caption,button,"");label.clip_text=not plan.voice_caption.get("floating",false)
		rows.append({"button":button,"label":label,"entry":entry,"index":-1,"id":null});button.button_down.connect(capture_row.bind(index));button.pressed.connect(invoke_row.bind(index))
	for tag in Layout.BUTTONS:
		var button:Button=frame.create_button(plan.entries[tag],self,models);buttons[tag]=button;frame.button_caption(button,caption(plan.entries[tag]));button.button_down.connect(capture.bind(tag));button.pressed.connect(invoke.bind(tag))
	for pair in [["soundsetedit",scroll],["descedit",biography_scroll]]:
		var bar=preload("res://systems/native_scrollbar.gd").new();add_child(bar);bar.configure(frame,models,plan.entries[pair[0]],pair[1],44 if pair[0]=="soundsetedit" else 14)
		if not bar.failure.is_empty():failure=bar.failure;return
		if pair[0]=="soundsetedit":voice_bar=bar
		else:biography_bar=bar
	move_child(deity,get_child_count()-1);deity.position=(size-deity.size)*.5
	layout_ready=true;refresh();prepared.emit()
	if wanted:show();register_modal_owner();edits.firstnameedit.grab_focus();initialize_voice();initialize_names()
func set_context(context:Dictionary,value_scope:Array)->void:
	if closed:return
	var changed:bool=scope!=value_scope
	if changed:modal_lease.retire()
	retire_input();deity_ticket.clear()
	if is_instance_valid(deity):deity.dismiss()
	scope=value_scope.duplicate();state.reset(context);random_ready=context.get("randomReady")==true;voice_initialized_scope.clear();names_initialized_scope.clear();pending_random=-1;pending_name_fields.clear();refresh()
	if wanted and layout_ready:initialize_voice();initialize_names()
	if changed:register_modal_owner()
func refresh()->void:
	if not layout_ready:return
	loading_fields=true
	for pair in [["firstnameedit","firstName"],["lastnameedit","lastName"],["ageedit","ageText"]]:edits[pair[0]].text=str(state.fields.get(pair[1],""));edits[pair[0]].editable=state.ready
	biography.text=str(state.fields.get("description",""));biography.editable=state.ready;loading_fields=false
	column.custom_minimum_size.y=state.voices.size()*maxf(1,plan.voice_row.hooks.next.y);refresh_rows()
	buttons.okbutton.disabled=not state.ready;buttons.deitybutton.disabled=not state.ready;buttons.randombutton.disabled=not state.ready or not random_ready or pending_random>=0
func field_changed(value:String,tag:String)->void:
	if loading_fields or not available():return
	var field:String={"firstnameedit":"firstName","lastnameedit":"lastName","ageedit":"ageText"}[tag];state.edit(field,value)
func biography_changed()->void:
	if not loading_fields and available():state.edit("description",biography.text)
func _input(event:InputEvent)->void:
	if not available() or is_instance_valid(deity) and deity.wanted:return
	# CCharacterInfoPanel vtable+140 ->8e3380: cancel only the admitted pane.
	# A top Deity edit handles its own Escape/Enter before its parent.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		capture("cancelbutton");invoke("cancelbutton");get_viewport().set_input_as_handled()
func edit_input(event:InputEvent,tag:String)->void:
	if not available() or not event is InputEventKey or not event.pressed or event.keycode!=KEY_TAB:return
	var order:Array=["firstnameedit","ageedit","lastnameedit","description"];var next:int=(order.find(tag)+(3 if event.shift_pressed else 1))%4
	var control:Control=biography if order[next]=="description" else edits[order[next]];control.grab_focus();control.accept_event()
func refresh_rows()->void:
	if not layout_ready:return
	var stride:float=maxf(1,plan.voice_row.hooks.next.y);var first:=maxi(0,floori(scroll.scroll_vertical/stride))
	for slot in rows.size():
		var row:Dictionary=rows[slot];var index:=first+slot
		row.index=index;row.id=null
		if index>=state.voices.size():row.button.hide();continue
		var value:Dictionary=state.voices[index];row.id=value.id;row.button.show();row.label.text=value.name;row.button.set_pressed_no_signal(state.selected==value.id)
		var offset:Vector2=-plan.voice_row.bounds.position+Vector2(0,index*stride);var entry:Dictionary=row.entry.duplicate(true);entry.offset=offset;entry.rect.position=Vector2(0,index*stride);frame.relocate(row.button,column,entry.rect)
		var geometry:Dictionary=frame.button_geometry.get(row.button.get_instance_id(),{});geometry.offset=offset;geometry.rect=entry.rect
func scrolled(_value:float)->void:
	# A native arrow repeat owns this range write. Retire pooled row presses,
	# preserving the scrollbar's separate held-arrow/drag lifetime.
	revision+=1;held.clear();refresh_rows()
func capture(tag:String)->void:
	if available():held[tag]={"scope":scope.duplicate(),"revision":revision}
func valid_press(tag:String)->bool:
	var press:Dictionary=held.get(tag,{});held.erase(tag)
	return available() and not press.is_empty() and press.scope==scope and int(press.revision)==revision
func capture_row(slot:int)->void:
	if not available() or rows[slot].id==null:return
	held["voice"]={"scope":scope.duplicate(),"revision":revision,"slot":slot,"id":rows[slot].id}
func invoke_row(slot:int)->void:
	var press:Dictionary=held.get("voice",{});held.erase("voice")
	if not available() or press.is_empty() or press.scope!=scope or int(press.revision)!=revision or press.slot!=slot or press.id!=rows[slot].id:return
	var result:=state.voice(int(press.id));refresh_rows()
	if result.available:voice_requested.emit(int(result.id),str(result.resRef),int(result.sample),scope.duplicate())
func invoke(tag:String)->void:
	if not valid_press(tag):return
	if tag=="deitybutton":
		deity_ticket=scope.duplicate();deity_ticket.append(revision);deity.set_context(str(state.fields.deity),8156,-1,deity_ticket);deity.open();return
	if tag=="randombutton":
		request_names();return
	if tag not in ["okbutton","cancelbutton"]:return
	var result:=state.result()
	if tag=="okbutton" and not result.available:return
	var ticket:=scope.duplicate();var value:Dictionary=result.get("value",{}).duplicate(true);dismiss();finished.emit(tag=="okbutton",value,ticket)
func deity_result(accepted:bool,value:String,ticket:Array)->void:
	if closed or not wanted or ticket!=deity_ticket or ticket.slice(0,ticket.size()-1)!=scope:return
	deity_ticket.clear()
	if accepted:state.edit("deity",value)
func generated_names(id:int,first:String,last:String,ticket:Array)->bool:
	if closed or not wanted or ticket!=scope or id!=pending_random:return false
	pending_random=-1
	var unchanged:bool=pending_name_fields==[state.fields.firstName,state.fields.lastName];pending_name_fields.clear()
	if not unchanged:refresh();return false
	state.edit("firstName",first);state.edit("lastName",last);refresh();edits.firstnameedit.grab_focus();return true
func generation_failed(id:int,ticket:Array)->void:
	if closed or not wanted or ticket!=scope or id!=pending_random:return
	pending_random=-1;pending_name_fields.clear();refresh()
func set_random_ready(value:bool,ticket:Array)->bool:
	if closed or ticket!=scope:return false
	random_ready=value
	if not value:pending_random=-1;pending_name_fields.clear()
	if layout_ready:
		buttons.randombutton.disabled=not state.ready or not random_ready or pending_random>=0
		initialize_names()
	return true
func request_names()->void:
	if not available() or not state.ready or not random_ready or pending_random>=0 or random_serial>=9007199254740991:return
	random_serial+=1;pending_random=random_serial;pending_name_fields=[state.fields.firstName,state.fields.lastName];buttons.randombutton.disabled=true;random_requested.emit(pending_random,scope.duplicate())
func initialize_names()->void:
	if not wanted or not layout_ready or not state.ready or not random_ready or not available() or names_initialized_scope==scope:return
	names_initialized_scope=scope.duplicate()
	#8ecc60 calls the native Random callback only when BOTH fields are empty.
	# Late preparation must preserve names already typed while assets loaded.
	if str(state.fields.firstName).is_empty() and str(state.fields.lastName).is_empty():request_names()
func open()->void:
	if closed:return
	wanted=true
	if layout_ready:show();register_modal_owner();edits.firstnameedit.grab_focus();initialize_voice();initialize_names()
func initialize_voice()->void:
	if not wanted or not layout_ready or voice_initialized_scope==scope:return
	voice_initialized_scope=scope.duplicate()
	if state.selected==null:return
	var result:=state.voice(int(state.selected))
	if result.available:voice_requested.emit(int(result.id),str(result.resRef),int(result.sample),scope.duplicate())
func retire_input()->void:
	revision+=1;held.clear()
	for row in rows:
		var disabled:bool=row.button.disabled;row.button.disabled=true;row.button.disabled=disabled
	for bar in [voice_bar,biography_bar]:
		if is_instance_valid(bar):bar.cancel_drag();bar.stop_repeat()
func dismiss()->void:
	if is_instance_valid(deity):deity.dismiss()
	modal_lease.retire();wanted=false;pending_random=-1;pending_name_fields.clear();deity_ticket.clear();voice_initialized_scope.clear();names_initialized_scope.clear();retire_input();hide()
func snapshot()->Dictionary:return {"ready":layout_ready,"failure":failure,"scope":scope.duplicate(),"value":state.snapshot(),"selected":state.selected,"voices":state.voices.size(),"pendingRandom":pending_random,"full_creation_parity":false}
func close()->void:
	if closed:return
	dismiss();closed=true
	if is_instance_valid(deity):deity.close()
	for bar in [voice_bar,biography_bar]:
		if is_instance_valid(bar):bar.close()
	if is_instance_valid(assets):assets.close()
	jobs.clear();models.clear();text_owner=null;frame=null;modal_lease.close()
func _exit_tree()->void:close()
