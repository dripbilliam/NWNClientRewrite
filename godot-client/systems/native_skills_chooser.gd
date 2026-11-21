extends "res://systems/native_source_modal.gd"
signal action_requested(operation: String,id: int,ticket: Array)
signal finished(accepted: bool,ticket: Array)
const Layout=preload("res://systems/native_data/creation_skills_layout.gd")
const Repeat=preload("res://systems/native_data/gui_repeat.gd")
var model: Dictionary={}
var data_text
var data_art
var can_recommend:=true
var busy:=false
var selected:=-1
var signature: Array=[]
var list: ScrollContainer
var body: Control
var bar
var help
var points: Label
var cost: Label
var row_buttons: Array=[]
var ranks: Array=[]
var icons: Array=[]
var help_icon_resource:=""
var repeat_clock:=Repeat.new()
var repeat_tag:=""
var repeat_identity: Array=[]
func _init() -> void:
	resource="cg_skills";extra_models=["ctl_cg_btn_skill","ctl_cg_btn_skup","ctl_cg_btn_skdn","ctl_cg_numbox3","scrollbar_simple","pb_scrl_up","pb_scrl_down"];set_process(false)
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func assemble() -> void:
	frame.image(plan.resource,plan.main,self);frame.image(plan.entries.skillsbuttonbox.resource,plan.entries.skillsbuttonbox.rect,self)
	for tag in ["title","tguilabel","tguilabel2","tguilabel3"]:frame.create_label(plan.entries[tag],self,caption(plan.entries[tag]))
	points=frame.create_label(plan.entries.ptsremainingbox,self);cost=frame.create_label(plan.entries.costbox,self)
	help=preload("res://systems/native_source_help.gd").new();add_child(help);help.configure(frame,models,plan.entries.helpbox)
	if not help.failure.is_empty():failure=help.failure;return
	help.title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER # Original CGuiCGHelpBox constructor9cf8c0.
	list=ScrollContainer.new();add_child(list);list.position=plan.list.position;list.size=plan.list.size;list.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;list.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body=Control.new();list.add_child(body);body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar=preload("res://systems/native_scrollbar.gd").new();add_child(bar);bar.configure(frame,models,plan.entries.skillsbuttonbox,list,absf(plan.row.hooks.next.y));failure=bar.failure
	for tag in Layout.BUTTONS:make_button(tag,plan.entries[tag])
func set_context(value: Dictionary,recommended: bool,active_text,art,value_scope: Array) -> void:
	if closed:return
	var replaced_scope:=scope!=value_scope
	if replaced_scope:retire_modal_owner()
	retire_input();scope=value_scope.duplicate();model=value.duplicate(true);can_recommend=recommended;data_text=active_text;data_art=art;busy=false;selected=-1;help_icon_resource="";signature=[]
	if is_instance_valid(help):help.invalidate()
	if is_instance_valid(cost):cost.text=""
	refresh()
	if replaced_scope:register_modal_owner()
func update_model(value: Dictionary) -> void:model=value.duplicate(true);refresh()
func set_busy(value: bool) -> void:
	if value:retire_input()
	busy=value;refresh()
func refresh() -> void:
	if closed or not layout_ready:return
	var ready: bool=model.get("ready",false)
	if not ready:
		retire_input();clear_rows();selected=-1;help_icon_resource=""
		for button in buttons.values():button.disabled=true
		points.text="";cost.text="";help.invalidate();help.title.text="";help.body.clear();return
	if signature!=model.entries:rebuild_rows()
	for tag in buttons:buttons[tag].disabled=not ready or busy
	for index in row_buttons.size():
		var entry: Dictionary=model.entries[index];var enabled: bool=ready and not busy and entry.enabled
		row_buttons[index].disabled=not enabled;row_buttons[index].set_pressed_no_signal(index==selected)
		for prefix in ["up:","down:"]:buttons[prefix+str(entry.id)].disabled=not enabled
		var label: Label=row_buttons[index].get_child(0);label.modulate=Color.WHITE if entry.enabled else Color(.5,.5,.5,1)
		ranks[index].text=str(int(model.details[entry.id].rank))
	points.text=str(int(model.points));buttons.recommendbutton.disabled=busy or not can_recommend;buttons.recommendbutton.get_child(0).modulate=Color.WHITE if can_recommend else Color(.5,.5,.5,1)
	if selected<0 and help.current.is_empty():help.present(data_text,58250,58251)
func clear_rows() -> void:
	stop_repeat();held.clear();signature=[]
	if is_instance_valid(data_art):
		for icon in icons:data_art.unbind(icon)
	icons.clear();ranks.clear();row_buttons.clear()
	for tag in buttons.keys():
		if str(tag).begins_with("row:") or str(tag).begins_with("up:") or str(tag).begins_with("down:"):
			if is_instance_valid(frame) and is_instance_valid(buttons[tag]):frame.button_geometry.erase(buttons[tag].get_instance_id())
			buttons.erase(tag)
	for node in body.get_children():node.free()
	body.custom_minimum_size=Vector2(plan.list.size.x,1);body.size=body.custom_minimum_size;list.scroll_vertical=0
func rebuild_rows() -> void:
	clear_rows();signature=model.entries.duplicate(true)
	var group:=ButtonGroup.new();var offset: Vector2=plan.entries.skillsbuttonbox.offset+plan.entries.skillsbuttonbox.model.hooks.listitem-plan.list.position;var row: Dictionary=plan.row
	for index in model.entries.size():
		var entry: Dictionary=model.entries[index];var rect: Rect2=row.bounds;rect.position+=offset
		var button:=make_button("row:"+str(index),{"resource":"ctl_cg_btn_skill","rect":rect,"offset":offset,"caption":plan.entries.skillsbuttonbox.caption},body,true);button.button_group=group;row_buttons.append(button)
		var label: Label=button.get_child(0);label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);label.position=row.hooks.text0-row.bounds.position;label.size=(row.hooks.text1-row.hooks.text0).abs();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;label.text=str(entry.name)
		if is_instance_valid(data_art) and not str(entry.icon).is_empty():
			var icon:=TextureRect.new();button.add_child(icon);icon.position=row.hooks.icon-row.bounds.position-Vector2(16,16);icon.size=Vector2(32,32);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;data_art.bind(icon,str(entry.icon));icons.append(icon)
		for operation in ["up","down"]:
			var geometry: Dictionary=plan[operation];var point: Vector2=row.hooks["skill"+operation]-row.bounds.position;var arrow_rect: Rect2=geometry.bounds;arrow_rect.position+=point
			var tag: String=operation+":"+str(entry.id);var arrow:=make_button(tag,{"resource":"ctl_cg_btn_sk"+("up" if operation=="up" else "dn"),"rect":arrow_rect,"offset":point,"caption":{}},button);arrow.button_down.connect(begin_repeat.bind(tag,index));arrow.button_up.connect(stop_repeat)
		var rank_origin: Vector2=row.hooks.skillrank-row.bounds.position;var rank_rect: Rect2=plan.number.bounds;rank_rect.position+=rank_origin;frame.image("ctl_cg_numbox3",rank_rect,button)
		var rank: Label=frame.create_label({"rect":rank_rect,"floating":true,"anchor":rank_origin+plan.number.hooks.text,"caption":{"AurString_Font":"fnt_galahad14","AurString_AlignH":0.5,"AurString_AlignV":0.5}},button);ranks.append(rank);rank.mouse_filter=Control.MOUSE_FILTER_STOP
		rank.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
				if event.pressed:capture("row:"+str(index))
				else:invoke("row:"+str(index)))
		offset+=row.hooks.next
	body.custom_minimum_size=Vector2(plan.list.size.x,maxf(1,offset.y+row.bounds.position.y));body.size=body.custom_minimum_size
func select_index(index: int) -> void:
	if index<0 or index>=model.get("entries",[]).size():return
	selected=index;refresh();show_help()
func show_help() -> void:
	if not model.get("ready",false) or selected<0:return
	var entry: Dictionary=model.entries[selected]
	if not entry.enabled:help.present(data_text,5847,5848);return
	var value: Dictionary=model.details[entry.id];var prefix:=""
	for part in [[6597,value.rank],[6596,value.modifier],[6598,value.value]]:prefix+=data_text.raw({"strRef":part[0]})+": "+str(int(part[1]))+"\n"
	cost.text=str(int(value.cost));help.present_content(data_text,int(entry.title),int(entry.description),prefix);help_icon_resource=str(entry.icon)
	#9d2a90 requests attachment to "Icon"; Gob::AttachToObject8c540 returns
	# no attachment when absent. The shipped CTL_CG_HELP has no such node.
func invoke(tag: String) -> void:
	if not valid_press(tag) or busy or not model.get("ready",false):return
	if tag.begins_with("row:"):select_index(int(tag.trim_prefix("row:")));return
	if tag.begins_with("up:") or tag.begins_with("down:"):
		var pair:=tag.split(":");var identity:=scope.duplicate();var input_revision:=revision;action_requested.emit(pair[0],int(pair[1]),identity)
		if available() and scope==identity and revision==input_revision:show_help()
	elif tag=="recommendbutton" and can_recommend:action_requested.emit("recommend",-1,scope.duplicate())
	elif tag in ["okbutton","cancelbutton"]:
		var identity:=scope.duplicate();dismiss();finished.emit(tag=="okbutton",identity)
func begin_repeat(tag: String,index: int) -> void:
	if not available() or busy or buttons[tag].disabled:return
	stop_repeat();select_index(index);repeat_tag=tag;repeat_identity=scope+[revision];repeat_clock.begin();set_process(true);invoke(tag)
func stop_repeat() -> void:repeat_clock.stop();repeat_tag="";repeat_identity=[];set_process(false)
func advance_repeat(microseconds: int) -> void:
	if repeat_tag.is_empty():return
	var button: Button=buttons[repeat_tag]
	if not available() or repeat_identity!=scope+[revision] or button.disabled or not button.is_pressed():stop_repeat();return
	if repeat_clock.tick(microseconds,button.get_global_rect().has_point(button.get_global_mouse_position())):capture(repeat_tag);invoke(repeat_tag)
func _process(delta: float) -> void:advance_repeat(roundi(delta*1000000.0))
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:stop_repeat()
func _input(event: InputEvent) -> void:
	if available() and not busy and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		var identity:=scope.duplicate();dismiss();finished.emit(false,identity);get_viewport().set_input_as_handled()
func retire_input() -> void:
	super.retire_input();stop_repeat()
	if is_instance_valid(bar):bar.cancel_drag();bar.stop_repeat()
	if is_instance_valid(help):help.retire_input()
func close() -> void:
	if closed:return
	if is_instance_valid(bar):bar.close()
	if is_instance_valid(help):help.close()
	if is_instance_valid(data_art):
		for icon in icons:
			if is_instance_valid(icon):data_art.unbind(icon)
	icons.clear();data_art=null;data_text=null;model={};super.close()
