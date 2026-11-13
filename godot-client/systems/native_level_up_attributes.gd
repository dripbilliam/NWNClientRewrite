extends "res://systems/native_attributes_chooser.gd"
var recommendation_busy:=false
func set_context(value: Dictionary,recommended: bool,active_text,value_scope: Array) -> void:
	recommendation_busy=false;super.set_context(value,recommended,active_text,value_scope)
func set_busy(value: bool) -> void:
	if value:retire_input()
	recommendation_busy=value;refresh()
# Original CG_LEVUP_ATTRIB; this pane is activated through CGuiPanel, not the
# modal-array activation used by creation's subsequent Skills panel.
const LevelLayout=preload("res://systems/native_data/level_up_attributes_layout.gd")
func _init() -> void:super();resource="cg_levup_attrib"
func parse_layout() -> Dictionary:return LevelLayout.parse(source,models)
func assemble() -> void:
	frame.image(plan.resource,plan.main,self);frame.image(plan.entries.ctl_cg_lstbxat.resource,plan.entries.ctl_cg_lstbxat.rect,self)
	title=help_label(plan.entries.title,6,text_owner.raw({"strRef":66177}))
	frame.create_label(plan.entries.tguilabel1,self,caption(plan.entries.tguilabel1))
	help=preload("res://systems/native_source_help.gd").new();add_child(help);help.configure(frame,models,plan.entries.helpedit)
	if not help.failure.is_empty():failure=help.failure;return
	frame.image(plan.entries.pointsedit.resource,plan.entries.pointsedit.rect,self);points=frame.create_label(plan.entries.pointsedit,self)
	for index in LevelLayout.KEYS.size():
		# Mode1 ctor8dc330 uses the same CGuiCharGenLabel as creation.
		# Keep its static atlas pose; arrows alone are animated timer buttons.
		var key: String=LevelLayout.KEYS[index];var entry: Dictionary=plan.entries[key+"label"];var row: Button=ability_row(key+"label",entry)
		var name_label: Label=row.get_child(0);var anchor: Vector2=entry.caption_anchor-entry.rect.position
		frame.label(name_label,{"rect":Rect2(anchor,Vector2.ONE),"floating":true,"anchor":anchor,"caption":entry.caption},row)
		for suffix in ["downbutton","upbutton"]:
			var tag: String=key+suffix;var button:=make_button(tag,plan.entries[tag]);button.button_down.connect(begin_repeat.bind(tag));button.button_up.connect(stop_repeat)
		values.append(help_label(plan.entries[key+"edit"],index))
	for tag in LevelLayout.BUTTONS:make_button(tag,plan.entries[tag])
func refresh() -> void:
	if closed or not layout_ready:return
	if not valid_model():
		retire_input()
		for button in buttons.values():button.disabled=true
		buttons.cancelbutton.disabled=false
		for value in values:value.text=""
		points.text="";help_index=-1;help_prefix=""
		if is_instance_valid(help):help.present(text_owner,261,457)
		return
	super.refresh()
	if recommendation_busy:
		for button in buttons.values():button.disabled=true
		buttons.cancelbutton.disabled=false
func valid_model() -> bool:
	if not model.get("ready",false) or model.get("points") not in [0,1]:return false
	if not (model.get("selectedAbility") is int or model.get("selectedAbility") is float) or float(model.selectedAbility)!=floor(float(model.selectedAbility)) or int(model.selectedAbility)<-1 or int(model.selectedAbility)>5:return false
	if (int(model.points)==1)!=(int(model.selectedAbility)==-1):return false
	for key in ["scores","modifiers","raw","racial","gains"]:
		if not model.get(key) is Array or model[key].size()!=6:return false
		for value in model[key]:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floor(float(value)):return false
	return true
func invoke(tag: String) -> void:
	if recommendation_busy and tag!="cancelbutton":return
	if not valid_press(tag):return
	if tag=="cancelbutton":
		var identity:=scope.duplicate();dismiss();finished.emit(false,identity);return
	if not valid_model():return
	for index in LevelLayout.KEYS.size():
		var key: String=LevelLayout.KEYS[index]
		if tag==key+"label":show_help(index);return
		if tag in [key+"upbutton",key+"downbutton"]:
			var up: bool=tag.ends_with("upbutton")
			if (up and int(model.points)==0) or (not up and (int(model.points)!=0 or int(model.selectedAbility)!=index)):return
			var identity:=scope.duplicate();var input_revision:=revision
			action_requested.emit("up" if up else "down",index,identity)
			if available() and scope==identity and revision==input_revision:show_help(index)
			return
	if tag=="recommendbutton" and can_recommend:action_requested.emit("recommend",-1,scope.duplicate())
	elif tag=="okbutton" and int(model.points)==0:
		var identity:=scope.duplicate();dismiss();finished.emit(true,identity)
func show_help(index: int) -> void:
	if index<0 or index>6 or not valid_model():return
	help_index=index;help_prefix="";var text=data_text if data_text!=null else text_owner
	if index<6:
		var modifier: int=model.modifiers[index];var racial: int=model.racial[index]
		for item in [[61919,str(int(model.raw[index]))],[6273,("+" if racial>=0 else "")+str(racial)],[144,str(int(model.gains[index]))],[6275,str(int(model.scores[index]))],[6274,("+" if modifier>=0 else "")+str(modifier)]]:help_prefix+=text.raw({"strRef":item[0]})+": "+str(item[1])+"\n"
		help_prefix+="\n"
	refresh()
