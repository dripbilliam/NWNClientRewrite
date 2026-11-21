extends "res://systems/native_source_modal.gd"
signal action_requested(operation: String,index: int,ticket: Array)
signal finished(accepted: bool,ticket: Array)
const Layout=preload("res://systems/native_data/creation_attributes_layout.gd")
const Repeat=preload("res://systems/native_data/gui_repeat.gd")
const HELP=[[473,459],[474,460],[475,461],[477,463],[476,462],[479,478],[261,457]]
var model: Dictionary={}
var data_text
var can_recommend:=true
var help
var title: Label
var values: Array=[]
var points: Label
var cost: Label
var help_index:=-1
var help_prefix:=""
var repeat_clock:=Repeat.new()
var repeat_tag:=""
var repeat_identity: Array=[]
func _init() -> void:resource="cg_attributes";extra_models=["scrollbar_simple","pb_scrl_up","pb_scrl_down"];set_process(false)
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func help_label(entry: Dictionary,index: int,value: String="") -> Label:
	var control: Label=frame.create_label(entry,self,value);control.mouse_filter=Control.MOUSE_FILTER_STOP
	control.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:capture("help:"+str(index))
			elif valid_press("help:"+str(index)):show_help(index))
	return control
func ability_row(tag:String,entry:Dictionary)->Button:
	#8db730 constructs these as CGuiCharGenLabel (822b60), not buttons.
	# Their original mesh stays in its static atlas pose. The MDL's unused
	# button 'up' UVs straddle two CTL_ATT rows, making text appear too high.
	var artwork:TextureRect=frame.image(entry.resource,entry.rect,self)
	var row:=Button.new();add_child(row);frame.relocate(row,self,entry.rect);row.focus_mode=Control.FOCUS_NONE;row.text="";row.add_theme_font_size_override("font_size",1)
	for state in ["normal","hover","pressed","disabled","focus"]:row.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	row.set_meta("native_attributes_static_row",artwork)
	buttons[tag]=row;row.button_down.connect(capture.bind(tag));row.pressed.connect(invoke.bind(tag))
	var name_label:=Label.new();row.add_child(name_label);name_label.text=caption(entry)
	return row
func assemble() -> void:
	frame.image(plan.resource,plan.main,self);frame.image(plan.entries.ctl_cg_lstbxat.resource,plan.entries.ctl_cg_lstbxat.rect,self)
	title=help_label(plan.entries.title,6,caption(plan.entries.title))
	for tag in ["tguilabel11","tguilabel1"]:frame.create_label(plan.entries[tag],self,caption(plan.entries[tag]))
	help=preload("res://systems/native_source_help.gd").new();add_child(help);help.configure(frame,models,plan.entries.helpedit)
	if not help.failure.is_empty():failure=help.failure;return
	for tag in ["pointsedit","costedit"]:frame.image(plan.entries[tag].resource,plan.entries[tag].rect,self)
	points=frame.create_label(plan.entries.pointsedit,self);cost=frame.create_label(plan.entries.costedit,self)
	for index in Layout.KEYS.size():
		var key: String=Layout.KEYS[index];var entry:Dictionary=plan.entries[key+"label"];var row:Button=ability_row(key+"label",entry)
		# The source name is attached to the MDL text hook. Generic footer
		# captions center across the entire button, including its numeric box.
		var name_label:Label=row.get_child(0);var anchor:Vector2=entry.caption_anchor-entry.rect.position
		frame.label(name_label,{"rect":Rect2(anchor,Vector2.ONE),"floating":true,"anchor":anchor,"caption":entry.caption},row)
		for suffix in ["downbutton","upbutton"]:
			var tag: String=key+suffix;var button:=make_button(tag,plan.entries[tag]);button.button_down.connect(begin_repeat.bind(tag));button.button_up.connect(stop_repeat)
		# The opaque row artwork includes the number-box background. Publish
		# its numeric label afterward, matching the source child's higher layer.
		values.append(help_label(plan.entries[key+"edit"],index))
	for tag in Layout.BUTTONS:make_button(tag,plan.entries[tag])
func set_context(value: Dictionary,recommended: bool,active_text,value_scope: Array) -> void:
	if closed:return
	retire_input();scope=value_scope.duplicate();model=value.duplicate(true);can_recommend=recommended;data_text=active_text;help_index=-1;help_prefix=""
	if is_instance_valid(help):help.invalidate()
	if is_instance_valid(cost):cost.text=""
	refresh()
func update_model(value: Dictionary) -> void:model=value.duplicate(true);refresh()
func refresh() -> void:
	if closed or not layout_ready:return
	var ready: bool=model.get("ready",false)
	for button in buttons.values():button.disabled=not ready
	if not ready:return
	for index in 6:
		var modifier: int=model.modifiers[index];values[index].text=str(int(model.scores[index]))+" ("+("+" if modifier>=0 else "")+str(modifier)+")"
	points.text=str(int(model.points));buttons.okbutton.disabled=int(model.points)!=0;buttons.okbutton.get_child(0).modulate=Color.WHITE if int(model.points)==0 else Color(.5,.5,.5,1)
	buttons.recommendbutton.disabled=not can_recommend;buttons.recommendbutton.get_child(0).modulate=Color.WHITE if can_recommend else Color(.5,.5,.5,1)
	var index:=6 if help_index<0 else help_index;help.present_content(data_text if data_text!=null else text_owner,HELP[index][0],HELP[index][1],help_prefix)
func show_help(index: int) -> void:
	if index<0 or index>6 or not model.get("ready",false):return
	help_index=index;help_prefix="";var text=data_text if data_text!=null else text_owner
	if index<6:
		var raw: int=model.raw[index];var racial: int=model.racial[index];var gain: int=model.gains[index];var score: int=model.scores[index];var modifier: int=model.modifiers[index]
		var parts: Array=[[61919,str(raw)],[6273,("+" if racial>=0 else "")+str(racial)],[144,str(gain)],[6275,str(score)],[6274,("+" if modifier>=0 else "")+str(modifier)]]
		for item in parts:help_prefix+=text.raw({"strRef":item[0]})+": "+str(item[1])+"\n"
		help_prefix+="\n";cost.text=str(int(model.costs[index]))
	else:cost.text="0"
	refresh()
func invoke(tag: String) -> void:
	if not valid_press(tag):return
	for index in Layout.KEYS.size():
		var key: String=Layout.KEYS[index]
		if tag==key+"label":show_help(index);return
		if tag in [key+"upbutton",key+"downbutton"]:
			var identity:=scope.duplicate();var input_revision:=revision;action_requested.emit("up" if tag.ends_with("upbutton") else "down",index,identity)
			if available() and scope==identity and revision==input_revision:show_help(index)
			return
	if tag=="recommendbutton" and can_recommend:action_requested.emit("recommend",-1,scope.duplicate())
	elif tag=="cancelbutton" or tag=="okbutton" and int(model.get("points",-1))==0:
		var identity:=scope.duplicate();dismiss();finished.emit(tag=="okbutton",identity)
func begin_repeat(tag: String) -> void:
	if not available() or buttons[tag].disabled:return
	stop_repeat();repeat_tag=tag;repeat_identity=scope+[revision];repeat_clock.begin();set_process(true);invoke(tag)
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
	if available() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		var identity:=scope.duplicate();dismiss();finished.emit(false,identity);get_viewport().set_input_as_handled()
func retire_input() -> void:
	super.retire_input();stop_repeat()
	if is_instance_valid(help):help.retire_input()
func close() -> void:
	if closed:return
	if is_instance_valid(help):help.close()
	data_text=null;model={};super.close()
