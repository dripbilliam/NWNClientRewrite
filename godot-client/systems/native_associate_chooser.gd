extends "res://systems/native_source_modal.gd"
# CCharacterFamiliarPanel. Private controls and detached draft views only.
# The owning creator validates edits and owns UTC/name jobs and continuation.
signal action_requested(operation: String,value: Dictionary,ticket: Array)
signal finished(accepted: bool,value: Dictionary,ticket: Array)
const State=preload("res://systems/native_data/creation_associate_state.gd")
const Layout=preload("res://systems/native_data/creation_associate_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Summary=preload("res://systems/native_data/character_summary_layout.gd")
var state:=State.new()
var data_text
var data_art
var content: Control
var list: ScrollContainer
var body: Control
var bar
var rows: Array=[]
var name_edit: LineEdit
var name_revision:=0
var generating:=false
var summary_view
var summary_lists: Dictionary={}
var summary_held:= -1
var summary_identity: Array=[]
var preview_serial:=0
var pending_preview: Dictionary={}
var info_popup
var popup_serial:=0
var popup_identity: Array=[]
var modal_active:=false
var foreground_labels: Array=[]
var entry_scope: Array=[]
func _init() -> void:
	resource="cg_familiar";extra_models=["ctl_cg_btn_famil","ctl_cg_btn_help","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
	extra_models.append_array(Summary.RESOURCES)
func configure(painter,text,catalog,cache_path: String) -> void:
	super.configure(painter,text,catalog,cache_path)
	prepared.connect(source_prepared)
	info_popup=preload("res://systems/native_ok_scroll.gd").new();add_child(info_popup);info_popup.configure(painter,text,catalog,cache_path);info_popup.prepared.connect(place_popup);info_popup.finished.connect(popup_result)
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func assemble() -> void:
	content=Control.new();add_child(content);content.size=size;content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.image(plan.resource,plan.main,content)
	for tag in ["title","tguilabel"]:foreground_labels.append(frame.create_label(plan.entries[tag],content,caption(plan.entries[tag])))
	for tag in ["famlistbox","nameeditbox"]:frame.image(plan.entries[tag].resource,plan.entries[tag].rect,content)
	list=ScrollContainer.new();content.add_child(list);list.position=plan.list.position;list.size=plan.list.size;list.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;list.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body=Control.new();list.add_child(body);body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar=preload("res://systems/native_scrollbar.gd").new();content.add_child(bar);bar.configure(frame,models,plan.entries.famlistbox,list,absf(plan.row.hooks.next.y));failure=bar.failure
	if not failure.is_empty():return
	list.get_v_scroll_bar().value_changed.connect(scrolled);build_pool()
	var edit_rect: Rect2=plan.entries.nameeditbox.text_rect
	name_edit=LineEdit.new();content.add_child(name_edit);name_edit.position=edit_rect.position;name_edit.size=edit_rect.size;name_edit.custom_minimum_size=Vector2.ZERO
	for kind in ["normal","focus","read_only"]:name_edit.add_theme_stylebox_override(kind,StyleBoxEmpty.new())
	frame.font_style(name_edit,plan.entries.nameeditbox.caption);name_edit.text_changed.connect(name_changed)
	for tag in Layout.BUTTONS:make_button(tag,plan.entries[tag],content)
	summary_view=preload("res://systems/native_character_summary_view.gd").new();content.add_child(summary_view)
	var sheet_size: Vector2=Geometry.model(models.pnl_chrsht2).bounds.size
	summary_view.configure(frame,text_owner,models,Vector2(sheet_size.x,420));summary_view.position=plan.summary_origin;failure=summary_view.failure
	if not failure.is_empty():return
	summary_view.page_down.connect(summary_down);summary_view.page_pressed.connect(summary_pressed)
	for index in range(1,4):
		var page=preload("res://systems/native_lobby_record_feats.gd").new();summary_view.pages[index].add_child(page);page.configure_view(frame,summary_view.definition.models,models,summary_view.pages[index].size,index,data_art,list_identity,list_available);summary_lists[str(index)]=page;page.show()
	# The original Title/Name text stays above later opaque list/edit artwork.
	for label in foreground_labels:content.move_child(label,content.get_child_count()-1)
	clear_preview();place_popup()
func place_popup() -> void:
	if is_instance_valid(info_popup):
		move_child(info_popup,get_child_count()-1)
		if info_popup.layout_ready:info_popup.position=(size-info_popup.size)*.5
func build_pool() -> void:
	var row: Dictionary=plan.row;var group:=ButtonGroup.new();var count:=ceili(plan.list.size.y/absf(row.hooks.next.y))+2
	for slot in count:
		var prefix:="row:"+str(slot);var button:=make_button(prefix,{"resource":"ctl_cg_btn_famil","rect":row.bounds,"offset":Vector2.ZERO,"caption":plan.entries.famlistbox.caption},body,true);button.button_group=group
		var label: Label=button.get_child(0);label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);label.position=row.hooks.text0-row.bounds.position;label.size=(row.hooks.text1-row.hooks.text0).abs();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		var geometry:=Geometry.model(models.ctl_cg_btn_help);var point: Vector2=row.hooks.helpbutton-row.bounds.position;var rect: Rect2=geometry.bounds;rect.position+=point
		var helper:=make_button(prefix+":help",{"resource":"ctl_cg_btn_help","rect":rect,"offset":point,"caption":{}},button);helper.hide()
		rows.append({"button":button,"label":label,"helper":helper,"index":-1,"id":-1})
		button.mouse_entered.connect(help_visible.bind(slot,true));button.mouse_exited.connect(help_visible.bind(slot,false));helper.mouse_exited.connect(help_visible.bind(slot,false))
func set_context(value: Dictionary,active_text,art,value_scope: Array) -> void:
	if closed:return
	dismiss_popup();retire_input();scope=value_scope.duplicate();data_text=active_text;data_art=art;name_revision+=1;generating=false
	state.configure(value.get("choices",{}),value.get("storedType"),value.get("name"));preview_serial+=1;clear_preview()
	if layout_ready:list.scroll_vertical=0;summary_view.set_page(0)
	refresh()
	if state.ready and state.selected_id()!=null:request_preview()
func refresh() -> void:
	if closed or not layout_ready:return
	content.mouse_behavior_recursive=Control.MOUSE_BEHAVIOR_DISABLED if modal_active else Control.MOUSE_BEHAVIOR_INHERITED
	name_edit.editable=state.ready and not modal_active
	if name_edit.text!=state.current_name:name_edit.text=state.current_name
	var offset: Vector2=plan.entries.famlistbox.offset+plan.entries.famlistbox.model.hooks.listitem-plan.list.position
	body.custom_minimum_size=Vector2(plan.list.size.x,maxf(1,offset.y+plan.row.bounds.position.y+absf(plan.row.hooks.next.y)*state.entries.size()));body.size=body.custom_minimum_size
	refresh_pool(false)
	buttons.okbutton.disabled=not state.ready or state.selected_id()==null or generating or modal_active;buttons.gennamebutton.disabled=not state.ready or generating or modal_active;buttons.cancelbutton.disabled=modal_active
	for tag in Layout.BUTTONS:buttons[tag].get_child(0).modulate=Color(.5,.5,.5,1) if buttons[tag].disabled else Color.WHITE
	if not pending_preview.is_empty():
		var pending: Dictionary=pending_preview;pending_preview={};present_preview(pending.value,pending.scope,int(pending.selection))
func refresh_pool(retire_on_rebind: bool=true) -> void:
	if not layout_ready:return
	var first:=maxi(0,floori(float(list.scroll_vertical)/absf(plan.row.hooks.next.y))-1);var retired:=not retire_on_rebind
	var origin: Vector2=plan.entries.famlistbox.offset+plan.entries.famlistbox.model.hooks.listitem-plan.list.position
	for slot in rows.size():
		var cell: Dictionary=rows[slot];var index: int=first+int(slot);var exists:=state.ready and index<state.entries.size();var id: int=int(state.entries[index].id) if exists else -1
		if cell.index!=index or cell.id!=id:
			if not retired:retire_choice_input();retired=true
			cell.index=index;cell.id=id;cell.label.text=str(state.entries[index].name) if exists else "";cell.helper.hide()
		cell.button.visible=exists
		if not exists:continue
		var offset: Vector2=origin+plan.row.hooks.next*index;var rect: Rect2=plan.row.bounds;rect.position+=offset;frame.relocate(cell.button,body,rect)
		var geometry: Dictionary=frame.button_geometry[cell.button.get_instance_id()];geometry.offset=offset;geometry.rect=rect;frame.update_button(cell.button.get_instance_id())
		cell.button.disabled=modal_active;cell.button.set_pressed_no_signal(index==state.selected)
func scrolled(_value: float) -> void:refresh_pool()
func help_visible(slot: int,value: bool) -> void:
	if slot>=0 and slot<rows.size():rows[slot].helper.visible=value and rows[slot].id>=0 and not modal_active
func name_changed(value: String) -> void:
	if not available() or modal_active or not state.ready:return
	name_revision+=1;state.set_name(value);generating=false;refresh();action_requested.emit("name",{"name":value,"revision":name_revision},scope.duplicate())
func request_name(accept_after: bool=false) -> void:
	if not state.ready or generating:return
	name_revision+=1;generating=true;refresh();action_requested.emit("generate",{"revision":name_revision,"acceptAfter":accept_after},scope.duplicate())
func name_result(value: Dictionary,value_scope: Array,request_revision: int,accept_after: bool=false) -> bool:
	if closed or not wanted or value_scope!=scope or request_revision!=name_revision or not generating:return false
	generating=false
	if value.get("ready",false) and value.get("name") is String and not value.name.is_empty():state.set_name(value.name)
	refresh()
	if accept_after and value.get("ready",false):complete(true)
	return true
func request_preview() -> void:
	preview_serial+=1;pending_preview={};clear_preview();var value:=state.preview()
	if value.get("ready",false):action_requested.emit("preview",{"selection":preview_serial,"resource":value.resource,"type":value.type,"physicalId":value.physicalId},scope.duplicate())
func list_identity() -> Array:return scope+[preview_serial]
func list_available() -> bool:return available() and not modal_active and summary_identity==list_identity()
func clear_preview() -> void:
	summary_identity=[]
	if is_instance_valid(summary_view):
		summary_view.clear_values();summary_view.portrait.texture=null
		if is_instance_valid(data_art):data_art.unbind(summary_view.portrait)
	for page in summary_lists.values():page.present_entries([])
func present_preview(value: Dictionary,value_scope: Array,selection: int) -> bool:
	if closed or value_scope!=scope or selection!=preview_serial:return false
	if not layout_ready:
		pending_preview={"value":value.duplicate(true),"scope":value_scope.duplicate(),"selection":selection};return true
	clear_preview()
	if not value.get("ready",false):return false
	summary_identity=list_identity();summary_view.present_values(value.get("labels",{}))
	if is_instance_valid(data_art) and not str(value.get("portrait","")).is_empty():data_art.bind_portrait(summary_view.portrait,str(value.portrait))
	for key in summary_lists:
		var page=summary_lists[key];page.data_art=data_art;page.present_entries(value.get("lists",{}).get(key,{}).get("entries",[]),int(value.get("revision",0)))
	return true
func summary_down(index: int) -> void:
	if list_available():summary_held=index
func summary_pressed(index: int) -> void:
	var accepted:=summary_held==index and list_available();summary_held=-1
	if accepted:summary_view.set_page(index)
func invoke(tag: String) -> void:
	if not valid_press(tag) or modal_active or not buttons.has(tag) or buttons[tag].disabled:return
	if tag=="cancelbutton":complete(false);return
	if not state.ready:return
	if tag.begins_with("row:"):
		var parts:=tag.split(":");var slot:=int(parts[1]);var cell: Dictionary=rows[slot]
		if cell.id<0:return
		state.select_index(cell.index);retire_choice_input();refresh();request_preview()
		if parts.size()==3:show_help(cell.index)
	elif tag=="gennamebutton":request_name()
	elif tag=="okbutton":
		if state.current_name.is_empty():request_name(true)
		else:complete(true)
func show_help(index: int) -> void:
	if index<0 or index>=state.entries.size():return
	var text=data_text if data_text!=null else text_owner;var message: String=text.raw({"strRef":int(state.entries[index].get("description",0))})
	dismiss_popup();retire_input();popup_serial+=1;popup_identity=scope+[popup_serial];modal_active=true;refresh();info_popup.set_context(message,popup_identity);info_popup.open();info_popup.start();place_popup()
func popup_result(value_scope: Array) -> void:
	if value_scope==popup_identity and modal_active:dismiss_popup();refresh()
func dismiss_popup() -> void:
	popup_serial+=1;popup_identity=[];modal_active=false
	if is_instance_valid(info_popup):info_popup.dismiss()
func complete(accepted: bool) -> void:
	var value:=state.commit() if accepted else {"ready":true};var identity:=scope.duplicate()
	if accepted and not value.get("ready",false):return
	dismiss();finished.emit(accepted,value,identity)
func open() -> void:
	super.open()
	prepare_entry()
func source_prepared() -> void:
	# Base received() publishes readiness before it shows the wanted pane.
	# Defer focus/entry until that same preparation has finished showing it.
	prepare_entry.call_deferred()
func prepare_entry() -> void:
	if closed or not wanted or not layout_ready or not is_visible_in_tree() or not state.ready:return
	var identity:=scope.duplicate()
	if entry_scope!=identity:
		entry_scope=identity.duplicate();action_requested.emit("enter",{"arcane":state.arcane,"level":state.class_level},identity)
	if closed or not wanted or scope!=identity or not is_visible_in_tree() or not state.ready:return
	name_edit.grab_focus()
	if state.current_name.is_empty() and not generating:request_name()
func _input(event: InputEvent) -> void:
	if available() and not modal_active and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:complete(false);get_viewport().set_input_as_handled()
func retire_choice_input() -> void:super.retire_input();summary_held=-1
func retire_input() -> void:
	retire_choice_input()
	if is_instance_valid(bar):bar.cancel_drag();bar.stop_repeat()
func dismiss() -> void:
	dismiss_popup();entry_scope=[];generating=false;name_revision+=1;preview_serial+=1;pending_preview={};clear_preview();super.dismiss()
func close() -> void:
	if closed:return
	for page in summary_lists.values():page.close()
	if is_instance_valid(summary_view):summary_view.close()
	if is_instance_valid(info_popup):info_popup.close()
	if is_instance_valid(bar):bar.close()
	clear_preview();data_text=null;super.close();data_art=null
