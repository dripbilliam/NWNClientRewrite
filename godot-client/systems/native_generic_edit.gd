extends "res://systems/native_source_modal.gd"
# Original UTIL_EDITPOPUP, shared by Subrace and later familiar/name helpers.
signal finished(accepted: bool,value: String,ticket: Array)
const Layout=preload("res://systems/native_data/connection_dialog_layout.gd")
var edit: LineEdit
var message: Label
var title_ref:=0
var maximum:=-1
var initial_text:=""
func _init() -> void:resource="util_editpopup"
func parse_layout() -> Dictionary:
	var result: Dictionary=Layout.panel(source,models,["messagelabel"],["editbox"],{"okbutton":"0x140201830","cancelbutton":"0x140201380"})
	if not str(result.error).is_empty():return result
	# Original201960 sets MessageLabel's bounds flag4 before layout import.
	# Word-wrap belongs to that source rectangle, not a one-pixel text anchor.
	result.entries.messagelabel.erase("floating");result.entries.messagelabel.erase("anchor")
	return result
func assemble() -> void:
	frame.image(plan.resource,plan.main,self);message=frame.create_label(plan.entries.messagelabel,self);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	edit=frame.create_edit(plan.entries.editbox,self)
	# A callback may immediately reopen this same source edit for the next
	# original dialog stage. Keep Godot's submit handler from ending that new
	# editing session after the callback; submit()/dismiss() still retire the
	# current stage and its focus normally. Native text/IME handling is retained.
	edit.keep_editing_on_text_submit=true;edit.text_submitted.connect(func(_value):submit(true))
	for tag in ["okbutton","cancelbutton"]:make_button(tag,plan.entries[tag])
func set_context(value: String,value_title: int,limit: int,value_scope: Array) -> void:
	if closed:return
	dismiss();scope=value_scope.duplicate();initial_text=value;title_ref=value_title;maximum=limit if limit>0 else -1;refresh()
func refresh() -> void:
	if not layout_ready and not is_instance_valid(edit):return
	# Original SetEditText does not truncate an existing string to the typing
	# limit; the derived edit checks length only when receiving a key press.
	edit.max_length=0;edit.text=initial_text;message.text=text_owner.raw({"strRef":title_ref})
func open() -> void:
	super.open()
	if layout_ready:edit.grab_focus()
func blocked_key(event: InputEventKey) -> bool:
	if maximum<=0 or not is_instance_valid(edit) or edit.text.length()<maximum:return false
	return event.keycode not in [KEY_LEFT,KEY_RIGHT,KEY_DELETE,KEY_BACKSPACE,KEY_ENTER,KEY_KP_ENTER,KEY_ESCAPE]
func _input(event: InputEvent) -> void:
	if not available() or not event is InputEventKey or not event.pressed:return
	if event.keycode==KEY_ESCAPE:
		submit(false);get_viewport().set_input_as_handled()
	elif edit.has_focus() and blocked_key(event):get_viewport().set_input_as_handled()
func invoke(tag: String) -> void:
	if valid_press(tag):submit(tag=="okbutton")
func submit(accepted: bool) -> void:
	if not available():return
	var value:=edit.text;var ticket:=scope.duplicate();dismiss();finished.emit(accepted,value,ticket)
func dismiss() -> void:
	if is_instance_valid(edit) and edit.has_focus():edit.release_focus()
	super.dismiss()
