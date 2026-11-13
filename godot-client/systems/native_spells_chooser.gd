extends "res://systems/native_source_modal.gd"
# CG_SPELLS source controls. Draft/getter owners supply detached state and
# validate every action. Each list keeps only its visible row controls alive.
signal action_requested(operation: String,id: int,ticket: Array)
signal finished(accepted: bool,ticket: Array)
const Layout=preload("res://systems/native_data/creation_spells_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
var model: Dictionary={}
var can_recommend:=false
var busy:=false
var data_text
var data_art
var content: Control
var remaining: Label
var empty_label: Label
var cannot_label: Label
var lists: Dictionary={}
var bodies: Dictionary={}
var bars: Dictionary={}
var rows: Dictionary={"available":[],"known":[]}
var selected: Dictionary={"available":-1,"known":-1}
var info_popup
var modal_active:=false
var popup_serial:=0
var popup_identity: Array=[]
func _init() -> void:
	resource="cg_spells";extra_models=["ctl_cg_btn_feat","ctl_cg_btn_left","ctl_cg_btn_right","ctl_cg_btn_help","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
func configure(painter,text,catalog,cache_path: String) -> void:
	super.configure(painter,text,catalog,cache_path)
	info_popup=preload("res://systems/native_spell_information.gd").new();add_child(info_popup);info_popup.configure(painter,text,catalog,cache_path);info_popup.prepared.connect(place_popup);info_popup.finished.connect(popup_result)
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func assemble() -> void:
	content=Control.new();add_child(content);content.size=size;content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.image(plan.resource,plan.main,content)
	var foreground_labels: Array=[]
	for tag in ["title","tguilabel1","availtitle","knowntitle"]:foreground_labels.append(frame.create_label(plan.entries[tag],content,caption(plan.entries[tag])))
	remaining=frame.create_label(plan.entries.remainlabel,content)
	foreground_labels.append(remaining)
	empty_label=frame.create_label(plan.entries.emptyspelllistlabel,content,caption(plan.entries.emptyspelllistlabel));cannot_label=frame.create_label(plan.entries.cannotlearn,content,caption(plan.entries.cannotlearn))
	for kind in ["available","known"]:
		var tag:="availbox" if kind=="available" else "knownbox";var rect: Rect2=plan.lists[tag]
		frame.image(plan.entries[tag].resource,plan.entries[tag].rect,content)
		var list:=ScrollContainer.new();content.add_child(list);list.position=rect.position;list.size=rect.size;list.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;list.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;lists[kind]=list
		var body:=Control.new();list.add_child(body);body.mouse_filter=Control.MOUSE_FILTER_IGNORE;bodies[kind]=body
		var bar=preload("res://systems/native_scrollbar.gd").new();content.add_child(bar);bar.configure(frame,models,plan.entries[tag],list,absf(plan.row.hooks.next.y));bars[kind]=bar
		if not bar.failure.is_empty():failure=bar.failure;return
		build_pool(kind);list.get_v_scroll_bar().value_changed.connect(scrolled.bind(kind))
	var group:=ButtonGroup.new()
	for level in 10:
		var tag:="spelllevel"+str(level);var entry: Dictionary=plan.entries[tag].duplicate(true);entry.overrides={"gui_replace01":Layout.ICONS[level]};var button:=make_button(tag,entry,content,true);button.button_group=group
	for tag in Layout.BUTTONS:make_button(tag,plan.entries[tag],content)
	# These claimed labels are above their list artwork and never intercept input.
	# The claimed text is a foreground layer. List-window images added above
	# used to cover both headers and the remaining-spell counter completely.
	for label in foreground_labels+[empty_label,cannot_label]:content.move_child(label,content.get_child_count()-1)
	place_popup()
func place_popup() -> void:
	if is_instance_valid(info_popup):
		move_child(info_popup,get_child_count()-1)
		if info_popup.layout_ready:info_popup.position=(size-info_popup.size)*.5
func build_pool(kind: String) -> void:
	var tag:="availbox" if kind=="available" else "knownbox";var row: Dictionary=plan.row;var count:=ceili(plan.lists[tag].size.y/absf(row.hooks.next.y))+2;var group:=ButtonGroup.new()
	for slot in count:
		var prefix:=kind+":"+str(slot);var button:=make_button(prefix,{"resource":"ctl_cg_btn_feat","rect":row.bounds,"offset":Vector2.ZERO,"caption":plan.entries[tag].caption},bodies[kind],true);button.button_group=group
		var label: Label=button.get_child(0);label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);label.position=row.hooks.text0-row.bounds.position;label.size=(row.hooks.text1-row.hooks.text0).abs();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		var icon:=TextureRect.new();button.add_child(icon);icon.position=row.hooks.icon-row.bounds.position-Vector2(16,16);icon.size=Vector2(32,32);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var cell:={"button":button,"label":label,"icon":icon,"index":-1,"id":-1};rows[kind].append(cell)
		for helper in ["arrow","info"]:
			var name:="ctl_cg_btn_help" if helper=="info" else "ctl_cg_btn_right" if kind=="available" else "ctl_cg_btn_left";var geometry:=Geometry.model(models[name]);var point: Vector2=row.hooks["helpbutton" if helper=="info" else "addremovebutton"]-row.bounds.position;var rect: Rect2=geometry.bounds;rect.position+=point
			var child:=make_button(prefix+":"+helper,{"resource":name,"rect":rect,"offset":point,"caption":{}},button);child.button_down.connect(select_slot.bind(kind,slot))
			if helper=="info":
				child.hide();button.mouse_entered.connect(info_visible.bind(kind,slot,true));button.mouse_exited.connect(info_visible.bind(kind,slot,false));child.mouse_exited.connect(info_visible.bind(kind,slot,false))
func set_context(value: Dictionary,recommended: bool,active_text,art,value_scope: Array) -> void:
	if closed:return
	var replaced:=scope!=value_scope
	if replaced:retire_modal_owner()
	retire_input();dismiss_popup();unbind_rows();scope=value_scope.duplicate();model=value.duplicate(true);can_recommend=recommended;data_text=active_text;data_art=art;busy=false;selected={"available":-1,"known":-1}
	for list in lists.values():list.scroll_vertical=0
	refresh()
	if replaced and wanted and layout_ready:register_modal_owner()
func update_model(value: Dictionary) -> void:
	retire_input();dismiss_popup();var prior_level:=int(model.get("level",-1));model=value.duplicate(true)
	if prior_level!=int(model.get("level",-1)):
		selected={"available":-1,"known":-1}
		for list in lists.values():list.scroll_vertical=0
	refresh()
func set_busy(value: bool) -> void:
	if value:retire_input()
	busy=value;refresh()
func refresh() -> void:
	if closed or not layout_ready:return
	var ready: bool=model.get("ready",false)
	content.mouse_behavior_recursive=Control.MOUSE_BEHAVIOR_DISABLED if modal_active else Control.MOUSE_BEHAVIOR_INHERITED
	for kind in ["available","known"]:
		var tag:="availbox" if kind=="available" else "knownbox";var offset: Vector2=plan.entries[tag].offset+plan.entries[tag].model.hooks.listitem-plan.lists[tag].position
		var count: int=model.get(kind,[]).size() if ready else 0
		bodies[kind].custom_minimum_size=Vector2(plan.lists[tag].size.x,maxf(1,offset.y+plan.row.bounds.position.y+absf(plan.row.hooks.next.y)*count));bodies[kind].size=bodies[kind].custom_minimum_size;refresh_pool(kind,false)
	for level in 10:
		var button: Button=buttons["spelllevel"+str(level)];button.disabled=not ready or busy or modal_active or level>=model.get("tabs",[]).size() or not model.tabs[level];button.set_pressed_no_signal(ready and int(model.get("level",-1))==level)
	remaining.text=str(int(model.remaining)) if ready else "";empty_label.visible=ready and model.get("empty",false);cannot_label.visible=ready and model.get("cannotLearn",false)
	for tag in Layout.BUTTONS:buttons[tag].disabled=not ready or busy or modal_active
	buttons.okbutton.disabled=not ready or busy or modal_active or not model.get("canAccept",false);buttons.recommendbutton.disabled=not ready or busy or modal_active or not can_recommend
	buttons.cancelbutton.disabled=modal_active
	for tag in Layout.BUTTONS:buttons[tag].get_child(0).modulate=Color(.5,.5,.5,1) if buttons[tag].disabled else Color.WHITE
func refresh_pool(kind: String,retire_on_rebind: bool=true) -> void:
	var ready: bool=model.get("ready",false);var entries: Array=model.get(kind,[]) if ready else [];var first:=maxi(0,floori(float(lists[kind].scroll_vertical)/absf(plan.row.hooks.next.y))-1)
	var tag:="availbox" if kind=="available" else "knownbox";var origin: Vector2=plan.entries[tag].offset+plan.entries[tag].model.hooks.listitem-plan.lists[tag].position
	var retired:=not retire_on_rebind
	for slot in rows[kind].size():
		var cell: Dictionary=rows[kind][slot];var index: int=first+int(slot);var exists: bool=index<entries.size();var id:=int(entries[index].id) if exists else -1;var prefix:=kind+":"+str(slot)
		if cell.id!=id or cell.index!=index:
			# Owner-model replacement already retires held input once. A scroll
			# rebind needs one additional retirement for the whole pool, not one
			# full control-tree reset for every row whose physical ID changed.
			if not retired:retire_input();retired=true
			cell.index=index;cell.id=id;buttons[prefix+":info"].hide()
			if is_instance_valid(data_art):data_art.unbind(cell.icon)
			cell.icon.texture=null;cell.label.text=str(entries[index].name) if exists else ""
			if exists and is_instance_valid(data_art) and entries[index].get("icon") is String and not entries[index].icon.is_empty():data_art.bind(cell.icon,entries[index].icon)
		cell.button.visible=exists
		if not exists:continue
		var offset: Vector2=origin+plan.row.hooks.next*index;var rect: Rect2=plan.row.bounds;rect.position+=offset
		cell.button.position=rect.position
		var data: Dictionary=frame.button_geometry[cell.button.get_instance_id()];data.offset=offset;data.rect=rect
		var enabled: bool=entries[index].get("enabled",true);cell.button.disabled=busy or modal_active or not enabled;cell.button.set_pressed_no_signal(int(selected[kind])==id);cell.label.modulate=Color.WHITE if enabled else Color(.5,.5,.5,1)
		buttons[prefix+":arrow"].disabled=busy or modal_active or not enabled;buttons[prefix+":info"].disabled=busy or modal_active;frame.update_button(cell.button.get_instance_id())
func scrolled(_value: float,kind: String) -> void:
	if not closed and layout_ready:refresh_pool(kind)
func select_slot(kind: String,slot: int) -> void:
	if slot<0 or slot>=rows[kind].size() or int(rows[kind][slot].id)<0:return
	selected[kind]=int(rows[kind][slot].id)
	for cell in rows[kind]:cell.button.set_pressed_no_signal(int(cell.id)==int(selected[kind]))
func info_visible(kind: String,slot: int,value: bool) -> void:
	var button: Button=rows[kind][slot].button
	if value or not button.get_global_rect().has_point(button.get_global_mouse_position()):buttons[kind+":"+str(slot)+":info"].visible=value
func invoke(tag: String) -> void:
	if not valid_press(tag) or modal_active or (busy or not model.get("ready",false)) and tag!="cancelbutton" or not buttons.has(tag) or buttons[tag].disabled:return
	if tag.begins_with("spelllevel"):
		action_requested.emit("level",int(tag.trim_prefix("spelllevel")),scope.duplicate());return
	if tag.contains(":"):
		var pair:=tag.split(":");var kind: String=pair[0];var slot:=int(pair[1]);var cell: Dictionary=rows[kind][slot]
		if int(cell.id)<0:return
		select_slot(kind,slot)
		if pair.size()==2:return
		if pair[2]=="info":show_info(model[kind][int(cell.index)]);return
		action_requested.emit("add" if kind=="available" else "remove",int(cell.id),scope.duplicate());return
	if tag in ["recommendbutton","resetbutton"]:action_requested.emit("recommend" if tag=="recommendbutton" else "reset",-1,scope.duplicate())
	elif tag in ["okbutton","cancelbutton"]:
		var identity:=scope.duplicate();dismiss();finished.emit(tag=="okbutton",identity)
func show_info(entry: Dictionary) -> void:
	if popup_serial>=9007199254740991:return
	retire_input();modal_active=true;popup_serial+=1;popup_identity=scope+["spell-information",popup_serial];refresh();var description: Variant=entry.get("description","")
	if description is int or description is float:description=data_text.raw({"strRef":int(description)&0xffffffff})
	info_popup.set_context({"ready":true,"name":str(entry.name),"description":str(description),"icon":str(entry.icon) if entry.get("icon") is String else ""},data_text,data_art,popup_identity);info_popup.open();info_popup.start();place_popup()
func popup_result(_accepted: bool,_id: int,identity: Array) -> void:
	if closed or not modal_active or identity!=popup_identity:return
	popup_identity=[];modal_active=false;refresh()
func dismiss_popup() -> void:
	modal_active=false;popup_identity=[]
	if is_instance_valid(info_popup):info_popup.dismiss()
func unbind_rows() -> void:
	for kind in rows:
		for cell in rows[kind]:
			if is_instance_valid(data_art):data_art.unbind(cell.icon)
			cell.id=-1;cell.index=-1;cell.icon.texture=null
func _input(event: InputEvent) -> void:
	if available() and not modal_active and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		var identity:=scope.duplicate();dismiss();finished.emit(false,identity);get_viewport().set_input_as_handled()
func retire_input() -> void:
	super.retire_input()
	for bar in bars.values():bar.cancel_drag();bar.stop_repeat()
func dismiss() -> void:
	dismiss_popup();super.dismiss()
func close() -> void:
	if closed:return
	if is_instance_valid(info_popup):info_popup.close()
	for bar in bars.values():bar.close()
	unbind_rows();data_text=null;data_art=null;super.close()
