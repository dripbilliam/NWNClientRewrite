extends Control
# Shared original readonly help region. Parent views own descriptions and input.
const Text=preload("res://systems/server_text.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
var title: Label
var body: RichTextLabel
var scroll: ScrollContainer
var bar
var current: Array=[]
var failure:=""
func configure(frame,models: Dictionary,entry: Dictionary) -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hooks: Dictionary=entry.model.hooks;var body_rect:=Rect2(entry.offset+hooks.text0,hooks.text1-hooks.text0).abs();var title_rect:=Rect2(entry.offset+hooks.title0,hooks.title1-hooks.title0).abs()
	frame.image(entry.resource,entry.rect,self);title=frame.create_label({"rect":title_rect,"caption":entry.caption},self)
	scroll=ScrollContainer.new();add_child(scroll);scroll.position=body_rect.position;scroll.size=body_rect.size;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body=Text.label({},body_rect.size.x);scroll.add_child(body);body.custom_minimum_size.x=body_rect.size.x;frame.font_style(body,entry.caption)
	bar=preload("res://systems/native_scrollbar.gd").new();add_child(bar);bar.configure(frame,models,entry,scroll);failure=bar.failure
func invalidate() -> void:current=[]
func present(text,title_ref: int,description_ref: int) -> void:
	present_content(text,title_ref,description_ref,"")
func present_content(text,title_ref: int,description_ref: int,prefix: String) -> void:
	var key: Array=[text.get_instance_id(),title_ref,description_ref]
	if not prefix.is_empty():key.append(prefix)
	if key==current:return
	current=key;title.text=text.raw({"strRef":title_ref}) if title_ref>=0 else "";Text.set_text(body,Rich.parse(prefix+(text.raw({"strRef":description_ref}) if description_ref>=0 else "")));scroll.scroll_vertical=0
func retire_input() -> void:
	if is_instance_valid(bar):bar.cancel_drag();bar.stop_repeat()
func close() -> void:
	if is_instance_valid(bar):bar.close()
	current=[]
func _exit_tree() -> void:close()
