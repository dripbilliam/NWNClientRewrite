extends "res://systems/native_source_modal.gd"
# Source CG_FEATS presentation. Active draft owners supply the two lists and
# validate add/remove/recommend/reset/OK; pixels and clicks do not grant feats.
signal action_requested(operation: String,id: int,ticket: Array)
signal finished(accepted: bool,ticket: Array)
const Layout=preload("res://systems/native_data/creation_feats_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
var model: Dictionary={}
var can_recommend:=true
var busy:=false
var data_text
var data_art
var remaining: Label
var lists: Dictionary={}
var bodies: Dictionary={}
var bars: Dictionary={}
var rows: Dictionary={"available":[],"known":[]}
var signatures: Dictionary={"available":[],"known":[]}
var selected: Dictionary={"available":-1,"known":-1}
var icons: Array=[]
var info_popup
var group_popup
var modal_active:=false
var popup_serial:=0
var popup_identity: Array=[]
var foreground_labels: Array=[]
func _init() -> void:
	resource="cg_feats";extra_models=["ctl_cg_btn_feat","ctl_cg_btn_left","ctl_cg_btn_right","ctl_cg_btn_help","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
func configure(painter,text,catalog,cache_path: String) -> void:
	super.configure(painter,text,catalog,cache_path)
	for information in [false,true]:
		var popup=preload("res://systems/native_feat_popup.gd").new();add_child(popup);popup.configure_mode(information);popup.configure(painter,text,catalog,cache_path);popup.z_index=10;popup.prepared.connect(place_popups);popup.finished.connect(popup_result.bind(information));popup.start()
		if information:info_popup=popup
		else:group_popup=popup
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func assemble() -> void:
	frame.image(plan.resource,plan.main,self)
	for tag in ["title","tguilabel","availtitle","knowntitle"]:foreground_labels.append(frame.create_label(plan.entries[tag],self,caption(plan.entries[tag])))
	remaining=frame.create_label(plan.entries.remainlabel,self);foreground_labels.append(remaining)
	for kind in ["available","known"]:
		var tag:="availbox" if kind=="available" else "knownbox";var rect: Rect2=plan.lists[tag]
		frame.image(plan.entries[tag].resource,plan.entries[tag].rect,self)
		var list:=ScrollContainer.new();add_child(list);list.position=rect.position;list.size=rect.size;list.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;list.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;lists[kind]=list
		var body:=Control.new();list.add_child(body);body.mouse_filter=Control.MOUSE_FILTER_IGNORE;bodies[kind]=body
		var bar=preload("res://systems/native_scrollbar.gd").new();add_child(bar);bar.configure(frame,models,plan.entries[tag],list,absf(plan.row.hooks.next.y));bars[kind]=bar
		if not bar.failure.is_empty():failure=bar.failure;return
	for tag in Layout.BUTTONS:make_button(tag,plan.entries[tag])
	# Original source labels have higher layers than the list backgrounds.
	# Godot sibling order must retain that foreground order after assembling art.
	for label in foreground_labels:move_child(label,get_child_count()-1)
	place_popups()
func place_popups() -> void:
	for popup in [info_popup,group_popup]:
		if is_instance_valid(popup):
			# Canvas z_index changes drawing, not Control hit-test order. These
			# children prepare before the parent list/footer controls are built.
			move_child(popup,get_child_count()-1)
			if popup.layout_ready:popup.position=(size-popup.size)*.5
func set_context(value: Dictionary,recommended: bool,active_text,art,value_scope: Array) -> void:
	if closed:return
	var replaced_scope:=scope!=value_scope
	if replaced_scope:retire_modal_owner()
	retire_input();dismiss_popups();clear_rows();scope=value_scope.duplicate();model=value.duplicate(true);can_recommend=recommended;data_text=active_text;data_art=art;busy=false;selected={"available":-1,"known":-1};refresh()
	if replaced_scope:register_modal_owner()
func update_model(value: Dictionary) -> void:
	retire_input();dismiss_popups();model=value.duplicate(true);refresh()
func set_busy(value: bool) -> void:
	if value:retire_input()
	busy=value;refresh()
func refresh() -> void:
	if closed or not layout_ready:return
	var ready: bool=model.get("ready",false)
	if not ready:retire_input();dismiss_popups();clear_rows();selected={"available":-1,"known":-1}
	for kind in ["available","known"]:
		var entries: Array=model.get(kind,[]) if ready else []
		if signatures[kind]!=entries:rebuild_rows(kind,entries)
	for tag in buttons:buttons[tag].disabled=not ready or busy or modal_active
	for kind in ["available","known"]:
		for index in rows[kind].size():
			var entry: Dictionary=model[kind][index];var enabled: bool=entry.get("enabled",true);var row: Button=rows[kind][index];var prefix: String=kind+":"+str(index)
			row.disabled=not ready or busy or modal_active or not enabled;row.set_pressed_no_signal(index==int(selected[kind]));row.get_child(0).modulate=Color.WHITE if enabled else Color(.5,.5,.5,1)
			buttons[prefix+":arrow"].disabled=not ready or busy or modal_active or not enabled
	remaining.text=str(int(model.get("remaining",0))) if ready else ""
	buttons.okbutton.disabled=not ready or busy or modal_active or not model.get("canAccept",false)
	buttons.recommendbutton.disabled=not ready or busy or modal_active or not can_recommend;buttons.recommendbutton.get_child(0).modulate=Color.WHITE if can_recommend else Color(.5,.5,.5,1)
	for tag in Layout.BUTTONS:buttons[tag].get_child(0).modulate=Color(.5,.5,.5,1) if buttons[tag].disabled else Color.WHITE
func clear_rows(kind: String="") -> void:
	if not kind.is_empty():
		for tag in buttons.keys():
			if str(tag).begins_with(kind+":"):
				if is_instance_valid(frame) and is_instance_valid(buttons[tag]):frame.button_geometry.erase(buttons[tag].get_instance_id())
				buttons.erase(tag)
		for icon in icons.duplicate():
			if is_instance_valid(icon) and str(icon.get_meta("feat_list",""))==kind:
				if is_instance_valid(data_art):data_art.unbind(icon)
				icons.erase(icon)
		rows[kind]=[];signatures[kind]=[]
		if bodies.has(kind):
			for node in bodies[kind].get_children():node.free()
			bodies[kind].custom_minimum_size=Vector2(1,1);lists[kind].scroll_vertical=0
		return
	for name in ["available","known"]:clear_rows(name)
func rebuild_rows(kind: String,entries: Array) -> void:
	clear_rows(kind);signatures[kind]=entries.duplicate(true);var tag:="availbox" if kind=="available" else "knownbox";var row: Dictionary=plan.row;var list_rect: Rect2=plan.lists[tag]
	var offset: Vector2=plan.entries[tag].offset+plan.entries[tag].model.hooks.listitem-list_rect.position;var group:=ButtonGroup.new()
	for index in entries.size():
		var entry: Dictionary=entries[index];var rect: Rect2=row.bounds;rect.position+=offset;var prefix:=kind+":"+str(index)
		var button:=make_button(prefix,{"resource":"ctl_cg_btn_feat","rect":rect,"offset":offset,"caption":plan.entries[tag].caption},bodies[kind],true);button.button_group=group;rows[kind].append(button)
		var label: Label=button.get_child(0);label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);label.position=row.hooks.text0-row.bounds.position;label.size=(row.hooks.text1-row.hooks.text0).abs();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;label.text=str(entry.name)
		if is_instance_valid(data_art) and not str(entry.get("icon","")).is_empty():
			var icon:=TextureRect.new();button.add_child(icon);icon.position=row.hooks.icon-row.bounds.position-Vector2(16,16);icon.size=Vector2(32,32);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;icon.set_meta("feat_list",kind);data_art.bind(icon,str(entry.icon));icons.append(icon)
		for helper in ["arrow","info"]:
			var name:="ctl_cg_btn_help" if helper=="info" else "ctl_cg_btn_right" if kind=="available" else "ctl_cg_btn_left";var geometry:=Geometry.model(models[name]);var point: Vector2=row.hooks["helpbutton" if helper=="info" else "addremovebutton"]-row.bounds.position;var helper_rect: Rect2=geometry.bounds;helper_rect.position+=point
			var child:=make_button(prefix+":"+helper,{"resource":name,"rect":helper_rect,"offset":point,"caption":{}},button);child.button_down.connect(select_row.bind(kind,index))
			if helper=="info":
				child.hide();button.mouse_entered.connect(set_info_visible.bind(kind,index,true));button.mouse_exited.connect(set_info_visible.bind(kind,index,false));child.mouse_exited.connect(set_info_visible.bind(kind,index,false))
		offset+=row.hooks.next
	bodies[kind].custom_minimum_size=Vector2(list_rect.size.x,maxf(1,offset.y+row.bounds.position.y));bodies[kind].size=bodies[kind].custom_minimum_size
	if int(selected[kind])>=entries.size():selected[kind]=-1
func select_row(kind: String,index: int) -> void:
	if not model.get("ready",false) or index<0 or index>=model.get(kind,[]).size():return
	selected[kind]=index
	for at in rows[kind].size():rows[kind][at].set_pressed_no_signal(at==index)
func set_info_visible(kind: String,index: int,visible_value: bool) -> void:
	if index>=rows[kind].size():return
	var button: Button=rows[kind][index];var info: Button=buttons[kind+":"+str(index)+":info"]
	if visible_value or not button.get_global_rect().has_point(button.get_global_mouse_position()):info.visible=visible_value
func invoke(tag: String) -> void:
	if not valid_press(tag) or busy or modal_active or not model.get("ready",false) or not buttons.has(tag) or buttons[tag].disabled:return
	if tag.contains(":"):
		var pair:=tag.split(":");var kind: String=pair[0];var index:=int(pair[1])
		if index<0 or index>=model.get(kind,[]).size():return
		select_row(kind,index)
		if pair.size()==2:return
		var entry: Dictionary=model[kind][index]
		if pair[2]=="info":show_info(entry);return
		if not entry.get("enabled",true):return
		if kind=="available" and entry.has("children"):show_group(entry.children);return
		action_requested.emit("add" if kind=="available" else "remove",int(entry.id),scope.duplicate());return
	if tag in ["recommendbutton","resetbutton"]:action_requested.emit("recommend" if tag=="recommendbutton" else "reset",-1,scope.duplicate())
	elif tag in ["okbutton","cancelbutton"]:
		var identity:=scope.duplicate();dismiss();finished.emit(tag=="okbutton",identity)
func show_info(entry: Dictionary) -> void:
	if not info_popup.layout_ready or not begin_popup_request(true):return
	retire_input();move_child(info_popup,get_child_count()-1);modal_active=true;refresh();var description_value: Variant=entry.get("description","")
	if description_value is int or description_value is float:description_value=data_text.raw({"strRef":int(description_value)&0xffffffff})
	info_popup.set_context({"ready":true,"name":str(entry.get("infoName",entry.name)),"description":str(description_value),"icon":str(entry.get("icon",""))},data_text,data_art,popup_identity);info_popup.open()
func show_group(entries: Array) -> void:
	if not group_popup.layout_ready or not begin_popup_request(false):return
	retire_input();move_child(group_popup,get_child_count()-1);modal_active=true;refresh();group_popup.set_context({"ready":true,"entries":entries},data_text,data_art,popup_identity);group_popup.open()
func begin_popup_request(information: bool) -> bool:
	if closed or popup_serial>=9007199254740991:return false
	popup_serial+=1;popup_identity=scope+["information" if information else "group",popup_serial];return true
func popup_result(accepted: bool,id: int,identity: Array,information: bool) -> void:
	if closed or not modal_active or identity!=popup_identity or identity[-2]!=("information" if information else "group"):return
	popup_identity.clear();modal_active=false;refresh()
	if accepted and not information and model.get("ready",false):action_requested.emit("add",id,scope.duplicate())
func dismiss_popups() -> void:
	popup_identity.clear();modal_active=false
	for popup in [info_popup,group_popup]:
		if is_instance_valid(popup):popup.dismiss()
func _input(event: InputEvent) -> void:
	if available() and not busy and not modal_active and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		var identity:=scope.duplicate();dismiss();finished.emit(false,identity);get_viewport().set_input_as_handled()
func retire_input() -> void:
	super.retire_input()
	for bar in bars.values():bar.cancel_drag();bar.stop_repeat()
func dismiss() -> void:
	dismiss_popups();super.dismiss()
func close() -> void:
	if closed:return
	for popup in [info_popup,group_popup]:
		if is_instance_valid(popup):popup.close()
	for bar in bars.values():bar.close()
	clear_rows();data_text=null;super.close();data_art=null
