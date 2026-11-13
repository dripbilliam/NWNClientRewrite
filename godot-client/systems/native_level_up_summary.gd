extends "res://systems/native_source_modal.gd"
signal submit_requested(ticket: Array)
signal cancelled(ticket: Array)
const Layout=preload("res://systems/native_data/level_up_summary_layout.gd")
const Text=preload("res://systems/server_text.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
var body: RichTextLabel
var scroll: ScrollContainer
var bar
var summary:=""
var submitted:=false
var content_ready:=false
var displayed:=false
var displayed_summary:=""
func _init() -> void:resource="cg_lvlup_summary";extra_models=["scrollbar_simple","pb_scrl_up","pb_scrl_down"]
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func assemble() -> void:
	frame.image(plan.resource,plan.main,self);frame.create_label(plan.entries.title,self,caption(plan.entries.title))
	var entry: Dictionary=plan.entries.editbox
	scroll=ScrollContainer.new();add_child(scroll);scroll.position=entry.text_rect.position;scroll.size=entry.text_rect.size;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body=Text.label({},entry.text_rect.size.x);scroll.add_child(body);body.custom_minimum_size.x=entry.text_rect.size.x;frame.font_style(body,entry.caption)
	bar=preload("res://systems/native_scrollbar.gd").new();add_child(bar);bar.configure(frame,models,entry,scroll);failure=bar.failure
	for tag in Layout.BUTTONS:make_button(tag,plan.entries[tag])
func set_context(content: String,value_scope: Array,available: bool=true) -> void:
	if closed:return
	retire_modal_owner();retire_input();scope=value_scope.duplicate();summary=content;submitted=false;content_ready=available;displayed=false;refresh()
	if is_instance_valid(scroll):scroll.scroll_vertical=0
	if wanted:register_modal_owner()
func refresh() -> void:
	if closed or not layout_ready:return
	if not displayed or displayed_summary!=summary:Text.set_text(body,Rich.parse(summary));displayed_summary=summary;displayed=true
	buttons.okbutton.disabled=not content_ready or submitted
	buttons.okbutton.get_child(buttons.okbutton.get_child_count()-1).modulate=Color(.5,.5,.5,1) if buttons.okbutton.disabled else Color.WHITE
func invoke(tag: String) -> void:
	if not valid_press(tag):return
	if tag=="okbutton" and content_ready and not submitted:
		submitted=true;refresh();submit_requested.emit(scope.duplicate())
	elif tag=="cancelbutton":
		var identity:=scope.duplicate();dismiss();cancelled.emit(identity)
func _input(event: InputEvent) -> void:
	if available() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		var identity:=scope.duplicate();dismiss();cancelled.emit(identity);get_viewport().set_input_as_handled()
func retire_input() -> void:
	super.retire_input()
	if is_instance_valid(bar):bar.cancel_drag();bar.stop_repeat()
func close() -> void:
	if closed:return
	if is_instance_valid(bar):bar.close()
	summary="";super.close()
