extends "res://systems/native_source_modal.gd"
# Shared source layout/input presentation. Each chooser owns its selection,
# availability and commit rules; neither artwork nor clicks grant draft choices.
var state
var list_tag:=""
var row_prefix:=""
var can_recommend:=true
var data_text
var data_art
var list: ScrollContainer
var body: Control
var help_scroll: ScrollContainer
var help_body: RichTextLabel
var help_title: Label
var help_region
var bars: Array=[]
var row_buttons: Array=[]
var signature:=""
var help_refs: Array=[]
var title: Label
func configure(painter,text,catalog,cache_path: String) -> void:
	extra_models=["ctl_cg_btn_class","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
	super.configure(painter,text,catalog,cache_path)
func scroll(rect: Rect2) -> ScrollContainer:
	var control:=ScrollContainer.new();add_child(control);control.position=rect.position;control.size=rect.size;control.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;control.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;return control
func add_bar(entry: Dictionary,target: ScrollContainer,step: float=14) -> void:
	var bar=preload("res://systems/native_scrollbar.gd").new();add_child(bar);bar.configure(frame,models,entry,target,step);bars.append(bar)
	if not bar.failure.is_empty():failure=bar.failure
func assemble() -> void:
	frame.image(plan.resource,plan.main,self);title=frame.create_label(plan.entries.title,self,title_caption());title.mouse_filter=Control.MOUSE_FILTER_STOP
	title.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:capture("general-help")
			elif valid_press("general-help"):state.general_help();refresh())
	frame.image(plan.entries[list_tag].resource,plan.entries[list_tag].rect,self)
	help_region=preload("res://systems/native_source_help.gd").new();add_child(help_region);help_region.configure(frame,models,plan.entries.helpbox)
	if not help_region.failure.is_empty():failure=help_region.failure;return
	help_title=help_region.title;help_scroll=help_region.scroll;help_body=help_region.body;bars.append(help_region.bar)
	list=scroll(plan.list);body=Control.new();list.add_child(body);body.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_bar(plan.entries[list_tag],list,absf(plan.row.hooks.next.y))
	for tag in plan.choice_buttons:make_button(tag,plan.entries[tag])
func title_caption() -> String:return caption(plan.entries.title)
func bind_data(recommended: bool,active_text,art,value_scope: Array) -> void:
	retire_input();scope=value_scope.duplicate();can_recommend=recommended;data_text=active_text;data_art=art;help_refs=[];signature=""
	if is_instance_valid(help_region):help_region.invalidate()
func refresh() -> void:
	if closed or not layout_ready:return
	if signature!=JSON.stringify(state.entries):rebuild_rows()
	for index in row_buttons.size():row_buttons[index].set_pressed_no_signal(index==state.selected)
	set_button_available("recommendbutton",can_recommend)
	var next: Array=[state.help_title,state.help_description]
	if next!=help_refs:
		help_refs=next;var text=data_text if data_text!=null else text_owner
		help_region.present(text,state.help_title,state.help_description)
func set_button_available(tag: String,enabled: bool) -> void:
	var button: Button=buttons[tag];button.disabled=not enabled
	var label: Label=button.get_child(button.get_child_count()-1);label.modulate=Color.WHITE if enabled else Color(.5,.5,.5,1)
func rebuild_rows() -> void:
	signature=JSON.stringify(state.entries);held.clear()
	for tag in buttons.keys():
		if str(tag).begins_with(row_prefix):buttons[tag].free();buttons.erase(tag)
	row_buttons.clear();var group:=ButtonGroup.new();var row: Dictionary=plan.row
	var offset: Vector2=plan.entries[list_tag].offset+plan.entries[list_tag].model.hooks.listitem-plan.list.position
	for index in state.entries.size():
		var entry: Dictionary=state.entries[index];var rect: Rect2=row.bounds;rect.position+=offset
		var button:=make_button(row_prefix+str(index),{"resource":"ctl_cg_btn_class","rect":rect,"offset":offset,"caption":plan.entries[list_tag].caption},body,true);button.button_group=group;row_buttons.append(button)
		var label: Label=button.get_child(button.get_child_count()-1);label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);label.position=row.hooks.text0-row.bounds.position;label.size=(row.hooks.text1-row.hooks.text0).abs();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;label.text=str(entry.name);label.modulate=Color.WHITE if entry.get("enabled",true) else Color(.5,.5,.5,1)
		if data_art!=null and not str(entry.icon).is_empty():
			var icon:=TextureRect.new();button.add_child(icon);icon.position=row.hooks.icon-row.bounds.position-Vector2(16,16);icon.size=Vector2(32,32);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;data_art.bind(icon,str(entry.icon))
		offset+=row.hooks.next
	body.custom_minimum_size=Vector2(plan.list.size.x,maxf(1,offset.y+row.bounds.position.y));body.size=body.custom_minimum_size
func retire_input() -> void:
	super.retire_input()
	for bar in bars:bar.cancel_drag();bar.stop_repeat()
func close() -> void:
	if closed:return
	for bar in bars:bar.close()
	data_text=null;data_art=null;super.close()
