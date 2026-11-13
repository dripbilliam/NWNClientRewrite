extends "res://systems/native_source_modal.gd"
# Original group picker CG_FEATS_POPUP and distinct read-only CG_SPELLINFO.
# The caller supplies active names/descriptions and physical IDs; this view
# never changes a creature, a draft, slot counts or the server.
signal finished(accepted: bool,id: int,ticket: Array)
const Layout=preload("res://systems/native_data/creation_feats_layout.gd")
const Text=preload("res://systems/server_text.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
# Original CGuiListBox ctor1e8160 installs opaque yellow in palette1;
# SetCurrentSelection1eb650 clears the old line to0 and selects new line1.
# The group popup uses that default text palette, not a selected-row texture.
const SELECTED_TEXT=Color(1,1,0,1)
var information:=false
var model: Dictionary={}
var busy:=false
var selected:=-1
var signature: Array=[]
var title: Label
var scroll: ScrollContainer
var body: Control
var description: RichTextLabel
var bar
var icon: TextureRect
var row_buttons: Array=[]
var data_art
var data_text
func _init() -> void:
	resource="cg_feats_popup";extra_models=["scrollbar_simple","pb_scrl_up","pb_scrl_down"]
func configure_mode(value: bool) -> void:
	if started:return
	information=value;resource="cg_spellinfo" if information else "cg_feats_popup"
func set_modal_order(order) -> void:
	# Original9c71b0 and9c7830 explicitly invoke modal Activate1fbe40 for
	# these two leaf owners. This does not classify the parent CG_FEATS page.
	if resource in ["cg_feats_popup","cg_spellinfo"]:super.set_modal_owner(order,"other")
func parse_layout() -> Dictionary:return Layout.popup(source,models,information)
func assemble() -> void:
	frame.image(plan.resource,plan.main,self);title=frame.create_label(plan.entries["title" if information else "tguilabel"],self,caption(plan.entries["title" if information else "tguilabel"]))
	scroll=ScrollContainer.new();add_child(scroll);scroll.position=plan.content.position;scroll.size=plan.content.size;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if information:
		description=Text.label({},plan.content.size.x);scroll.add_child(description);description.custom_minimum_size.x=plan.content.size.x;frame.font_style(description,plan.entries.editbox.caption)
		icon=TextureRect.new();add_child(icon);icon.position=plan.icon-Vector2(16,16);icon.size=Vector2(32,32);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	else:
		body=Control.new();scroll.add_child(body);body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar=preload("res://systems/native_scrollbar.gd").new();add_child(bar);bar.configure(frame,models,plan.entries[plan.content_tag],scroll);failure=bar.failure
	for tag in plan.popup_buttons:make_button(tag,plan.entries[tag])
	if not information and is_instance_valid(frame.fonts):frame.fonts.loaded.connect(font_loaded)
func set_context(value: Dictionary,active_text,art,value_scope: Array) -> void:
	if closed:return
	retire_modal_owner()
	if is_instance_valid(data_art) and is_instance_valid(icon):data_art.unbind(icon)
	retire_input();scope=value_scope.duplicate();model=value.duplicate(true);data_text=active_text;data_art=art;selected=0 if not information and model.get("entries",[]).size()==1 else -1;busy=false;signature=[];refresh()
func set_busy(value: bool) -> void:
	if value:retire_input()
	busy=value;refresh()
func refresh() -> void:
	if closed or not layout_ready:return
	var ready: bool=model.get("ready",false)
	for button in buttons.values():button.disabled=not ready or busy
	if information:
		if is_instance_valid(data_art):data_art.unbind(icon)
		icon.texture=null;title.text=str(model.get("name","")) if ready else ""
		Text.set_text(description,Rich.parse(str(model.get("description","")) if ready else ""));scroll.scroll_vertical=0
		if ready and is_instance_valid(data_art) and not str(model.get("icon","")).is_empty():data_art.bind(icon,str(model.icon))
		return
	var entries: Array=model.get("entries",[]) if ready else []
	if not ready:selected=-1
	if not ready or signature!=entries:rebuild_rows(entries)
	for index in row_buttons.size():
		var chosen: bool=index==selected;var button: Button=row_buttons[index]
		button.set_pressed_no_signal(chosen);button.disabled=not ready or busy
		var caption: Dictionary=plan.entries.featslist.caption
		var color:=SELECTED_TEXT if chosen else Color(float(caption.get("AurString_ColorR",1)),float(caption.get("AurString_ColorG",1)),float(caption.get("AurString_ColorB",1)),float(caption.get("AurString_ColorA",1)))
		# Godot's hover/pressed theme defaults must not replace the original
		# persistent selected-line color when the pointer moves or releases.
		for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:button.add_theme_color_override(state,color)
	buttons.okbutton.disabled=not ready or busy or selected<0 or selected>=entries.size()
	for tag in plan.popup_buttons:buttons[tag].get_child(0).modulate=Color(.5,.5,.5,1) if buttons[tag].disabled else Color.WHITE
func rebuild_rows(entries: Array) -> void:
	retire_input();signature=entries.duplicate(true)
	for tag in buttons.keys():
		if str(tag).begins_with("row:"):buttons.erase(tag)
	row_buttons.clear()
	for node in body.get_children():node.free()
	var group:=ButtonGroup.new();var font_name:=str(plan.entries.featslist.caption.get("AurString_Font",""));var height:=14.0
	if is_instance_valid(frame.fonts) and frame.fonts.metrics.has(font_name):height=maxf(1,roundf(float(frame.fonts.metrics[font_name].height)))
	for index in entries.size():
		var entry: Dictionary=entries[index];var button:=Button.new();body.add_child(button);button.position=Vector2(0,index*height);button.size=Vector2(plan.content.size.x,height);button.toggle_mode=true;button.button_group=group;button.focus_mode=Control.FOCUS_NONE;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.text=str(entry.name)
		for state in ["normal","hover","pressed","focus","disabled"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		frame.font_style(button,plan.entries.featslist.caption);buttons["row:"+str(index)]=button;row_buttons.append(button);button.button_down.connect(capture.bind("row:"+str(index)));button.pressed.connect(invoke.bind("row:"+str(index)))
	body.custom_minimum_size=Vector2(plan.content.size.x,maxf(1,entries.size()*height));body.size=body.custom_minimum_size;scroll.scroll_vertical=0
func font_loaded(name: String) -> void:
	if not closed and layout_ready and not information and name==str(plan.entries.featslist.caption.get("AurString_Font","")):
		rebuild_rows(model.get("entries",[]) if model.get("ready",false) else []);refresh()
func invoke(tag: String) -> void:
	if not valid_press(tag) or busy or not model.get("ready",false) or not buttons.has(tag) or buttons[tag].disabled:return
	if tag.begins_with("row:"):
		selected=int(tag.trim_prefix("row:"));refresh();return
	if tag=="okbutton" and (selected<0 or selected>=model.get("entries",[]).size()):return
	var accepted: bool=tag=="okbutton";var id: int=int(model.entries[selected].id) if accepted else -1;var identity:=scope.duplicate();dismiss();finished.emit(accepted,id,identity)
func _input(event: InputEvent) -> void:
	if available() and not busy and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		var identity:=scope.duplicate();dismiss();finished.emit(false,-1,identity);get_viewport().set_input_as_handled()
func retire_input() -> void:
	super.retire_input()
	if is_instance_valid(bar):bar.cancel_drag();bar.stop_repeat()
func dismiss() -> void:
	super.dismiss()
	if is_instance_valid(data_art) and is_instance_valid(icon):data_art.unbind(icon)
func close() -> void:
	if closed:return
	if is_instance_valid(bar):bar.close()
	if not information and is_instance_valid(frame) and is_instance_valid(frame.fonts) and frame.fonts.loaded.is_connected(font_loaded):frame.fonts.loaded.disconnect(font_loaded)
	data_text=null;super.close();data_art=null
