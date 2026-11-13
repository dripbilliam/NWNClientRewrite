extends "res://systems/native_source_modal.gd"
# Actual CG_DOMAIN controls. A row is moved between the list and the original
# two domain attachment points, retaining its widgets and prepared icon.
signal finished(accepted: bool,selected: Array,ticket: Array)
const State=preload("res://systems/native_data/creation_domains_state.gd")
const Layout=preload("res://systems/native_data/creation_domains_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Text=preload("res://systems/server_text.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
var state:=State.new()
var data_text
var data_art
var can_recommend:=true
var row_nodes: Dictionary={}
var icons: Array=[]
var list: ScrollContainer
var list_body: Control
var chosen_body: Control
var list_bar
var help_title: Label
var help_body: RichTextLabel
var help_scroll: ScrollContainer
var help_bar
var signature: Array=[]
func _init() -> void:
	resource="cg_domain";extra_models=["ctl_cg_btn_dom","ctl_cg_btn_left","ctl_cg_btn_right","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func assemble() -> void:
	frame.image(plan.resource,plan.main,self);frame.create_label(plan.entries.title,self,caption(plan.entries.title))
	for tag in ["domainlistbox","domaindesc"]:frame.image(plan.entries[tag].resource,plan.entries[tag].rect,self)
	help_title=frame.create_label(plan.entries.domainname,self)
	list=ScrollContainer.new();add_child(list);list.position=plan.list.position;list.size=plan.list.size;list.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;list.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	list_body=Control.new();list.add_child(list_body);list_body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	chosen_body=Control.new();add_child(chosen_body);chosen_body.size=size;chosen_body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	list_bar=preload("res://systems/native_scrollbar.gd").new();add_child(list_bar);list_bar.configure(frame,models,plan.entries.domainlistbox,list,absf(plan.row.hooks.next.y))
	help_scroll=ScrollContainer.new();add_child(help_scroll);help_scroll.position=plan.help_body.position;help_scroll.size=plan.help_body.size;help_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;help_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	help_body=Text.label({},plan.help_body.size.x);help_scroll.add_child(help_body);help_body.custom_minimum_size.x=plan.help_body.size.x;frame.font_style(help_body,plan.entries.domaindesc.caption)
	help_bar=preload("res://systems/native_scrollbar.gd").new();add_child(help_bar);help_bar.configure(frame,models,plan.entries.domaindesc,help_scroll)
	for bar in [list_bar,help_bar]:
		if not bar.failure.is_empty():failure=bar.failure;return
	for tag in Layout.BUTTONS:make_button(tag,plan.entries[tag])
func set_context(model: Dictionary,recommended: bool,active_text,art,value_scope: Array,retain_selection: bool=false) -> void:
	if closed:return
	var old_chosen:=state.chosen.duplicate();var old_available:=state.available_ids.duplicate();var old_help:=[state.help_title,state.help_description];var old_focus:=[state.selected_available,state.selected_chosen]
	retire_input();clear_rows();scope=value_scope.duplicate();state.reset(model);can_recommend=recommended;data_text=active_text;data_art=art
	var old_ids:=old_chosen+old_available;var current_ids:=state.available_ids.duplicate();old_ids.sort();current_ids.sort()
	if retain_selection and old_ids==current_ids:
		state.chosen=old_chosen;state.available_ids=old_available;state.help_title=int(old_help[0]);state.help_description=int(old_help[1]);state.selected_available=int(old_focus[0]);state.selected_chosen=int(old_focus[1])
	refresh()
func clear_rows() -> void:
	for icon in icons:
		if is_instance_valid(data_art):data_art.unbind(icon)
	icons.clear()
	for row in row_nodes.values():row.free()
	row_nodes.clear();signature=[]
	for tag in buttons.keys():
		if str(tag).begins_with("domain:"):buttons.erase(tag)
func build_rows() -> void:
	clear_rows();signature=state.model.get("entries",[]).duplicate(true)
	for entry in signature:
		var id:=int(entry.id);var prefix:="domain:"+str(id);var row: Dictionary=plan.row;var button:=make_button(prefix,{"resource":"ctl_cg_btn_dom","rect":row.bounds,"offset":Vector2.ZERO,"caption":plan.entries.domainlistbox.caption},list_body,true);row_nodes[id]=button
		var label: Label=button.get_child(0);label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);label.position=Vector2(row.hooks.text.x-row.bounds.position.x,0);label.size=Vector2(row.hooks.addremovebutton.x-row.hooks.text.x,row.bounds.size.y);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;label.text=str(entry.get("name",""))
		var icon:=TextureRect.new();button.add_child(icon);icon.position=row.hooks.icon-row.bounds.position-Vector2(16,16);icon.size=Vector2(32,32);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;icons.append(icon)
		if is_instance_valid(data_art) and not str(entry.get("icon","")).is_empty():data_art.bind(icon,str(entry.icon))
		# Both arrow controls are created once; moving a choice only swaps which
		# original helper is visible, avoiding model/icon re-preparation per click.
		for direction in ["add","remove"]:
			var name:="ctl_cg_btn_right" if direction=="add" else "ctl_cg_btn_left";var geometry:=Geometry.model(models[name]);var point: Vector2=row.hooks.addremovebutton-row.bounds.position;var rect: Rect2=geometry.bounds;rect.position+=point
			make_button(prefix+":"+direction,{"resource":name,"rect":rect,"offset":point,"caption":{}},button)
func place_row(id: int,parent: Control,offset: Vector2,chosen: bool,index: int) -> void:
	var row: Button=row_nodes[id];var rect: Rect2=plan.row.bounds;rect.position+=offset
	frame.relocate(row,parent,rect)
	var geometry: Dictionary=frame.button_geometry[row.get_instance_id()];geometry.offset=offset;geometry.rect=rect;frame.update_button(row.get_instance_id())
	row.disabled=false;row.set_pressed_no_signal((state.selected_chosen if chosen else state.selected_available)==index)
	buttons["domain:"+str(id)+":add"].visible=not chosen;buttons["domain:"+str(id)+":add"].disabled=state.chosen.size()==2
	buttons["domain:"+str(id)+":remove"].visible=chosen
func refresh() -> void:
	if closed or not layout_ready:return
	var ready: bool=state.model.get("ready",false)
	if signature!=state.model.get("entries",[]):build_rows()
	if ready:
		var offset: Vector2=plan.entries.domainlistbox.offset+plan.entries.domainlistbox.model.hooks.listitem-plan.list.position
		for index in state.available_ids.size():place_row(int(state.available_ids[index]),list_body,offset+plan.row.hooks.next*index,false,index)
		list_body.custom_minimum_size=Vector2(plan.list.size.x,maxf(1,offset.y+plan.row.bounds.position.y+plan.row.hooks.next.y*state.available_ids.size()));list_body.size=list_body.custom_minimum_size
		for index in state.chosen.size():place_row(int(state.chosen[index]),chosen_body,plan.entries.domaindesc.offset+plan.entries.domaindesc.model.hooks["domain"+str(index+1)],true,index)
	var text=data_text if data_text!=null else text_owner
	help_title.text=text.raw({"strRef":state.help_title}) if ready else "";Text.set_text(help_body,Rich.parse(text.raw({"strRef":state.help_description}) if ready else ""));help_scroll.scroll_vertical=0
	buttons.okbutton.disabled=not state.can_accept();buttons.recommendbutton.disabled=not ready or not can_recommend or not state.can_recommend()
	for tag in Layout.BUTTONS:buttons[tag].get_child(0).modulate=Color(.5,.5,.5,1) if buttons[tag].disabled else Color.WHITE
func invoke(tag: String) -> void:
	if not valid_press(tag) or not state.model.get("ready",false) or not buttons.has(tag) or buttons[tag].disabled:return
	if tag.begins_with("domain:"):
		var pair:=tag.split(":");var id:=int(pair[1]);var chosen_index:=state.chosen.find(id);var index:=chosen_index if chosen_index>=0 else state.available_ids.find(id)
		if pair.size()==2:
			if chosen_index>=0:state.select_chosen(index)
			else:state.select_available(index)
		elif pair[2]=="add":state.add(index)
		elif pair[2]=="remove":state.remove(index)
		refresh();return
	if tag=="recommendbutton":state.recommend();refresh()
	elif tag in ["okbutton","cancelbutton"]:complete(tag=="okbutton")
func complete(accepted: bool) -> void:
	var identity:=scope.duplicate();var choices:=state.chosen.duplicate();dismiss();finished.emit(accepted,choices,identity)
func _input(event: InputEvent) -> void:
	if available() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:complete(false);get_viewport().set_input_as_handled()
func retire_input() -> void:
	super.retire_input()
	for bar in [list_bar,help_bar]:
		if is_instance_valid(bar):bar.cancel_drag();bar.stop_repeat()
func close() -> void:
	if closed:return
	for bar in [list_bar,help_bar]:
		if is_instance_valid(bar):bar.close()
	clear_rows();data_text=null;data_art=null;super.close()
