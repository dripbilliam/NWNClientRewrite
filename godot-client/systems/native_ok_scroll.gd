extends "res://systems/native_source_modal.gd"
# CPanelOkScroll: the familiar help owner, distinct from CSpellInfoPanel.
signal finished(ticket: Array)
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const Text=preload("res://systems/server_text.gd")
var description: RichTextLabel
var scroll: ScrollContainer
var bar
var message:=""
func _init() -> void:
	resource="okscrollpanel";extra_models=["scrollbar_simple","pb_scrl_up","pb_scrl_down"]
func set_modal_order(order) -> void:super.set_modal_owner(order,"other")
func parse_layout() -> Dictionary:
	var result:=Dialog.panel(source,models,[],[],{"okbutton":"0x140201f30"},["editscroll"])
	if not str(result.get("error","")).is_empty():return result
	var entry: Dictionary=result.entries.editscroll
	for hook in ["text0","text1","scrollmin","scrollmax"]:
		if not entry.model.hooks.has(hook):return {"error":"Original OK scroll attachment missing: "+hook}
	var first: Vector2=entry.offset+entry.model.hooks.text0;var last: Vector2=entry.offset+entry.model.hooks.text1
	result.content=Rect2(first.min(last),(last-first).abs());return result
func assemble() -> void:
	frame.image(plan.resource,plan.main,self);frame.image(plan.entries.editscroll.resource,plan.entries.editscroll.rect,self)
	scroll=ScrollContainer.new();add_child(scroll);scroll.position=plan.content.position;scroll.size=plan.content.size;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	description=Text.label({},plan.content.size.x);scroll.add_child(description);description.custom_minimum_size.x=plan.content.size.x;frame.font_style(description,plan.entries.editscroll.caption)
	bar=preload("res://systems/native_scrollbar.gd").new();add_child(bar);bar.configure(frame,models,plan.entries.editscroll,scroll);failure=bar.failure
	make_button("okbutton",plan.entries.okbutton)
func set_context(value: String,value_scope: Array) -> void:
	if closed:return
	retire_modal_owner();retire_input();scope=value_scope.duplicate();message=value;refresh()
func refresh() -> void:
	if closed or not layout_ready:return
	Text.set_text(description,preload("res://systems/native_data/rich_text.gd").parse(message));scroll.scroll_vertical=0
func complete() -> void:
	if not available():return
	var identity:=scope.duplicate();dismiss();finished.emit(identity)
func invoke(tag: String) -> void:
	if tag=="okbutton" and valid_press(tag):complete()
func _input(event: InputEvent) -> void:
	if available() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:complete();get_viewport().set_input_as_handled()
func retire_input() -> void:
	super.retire_input()
	if is_instance_valid(bar):bar.cancel_drag();bar.stop_repeat()
func close() -> void:
	if closed:return
	if is_instance_valid(bar):bar.close()
	super.close()
