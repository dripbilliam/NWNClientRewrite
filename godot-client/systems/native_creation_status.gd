extends "res://systems/native_ok_scroll.gd"
# A readonly creation notice using CPanelOkScroll's installed art, caption and
# scroll attachments. Embedded in CG_MAIN's summary footprint, not a new modal
# owner: progress must leave the parent's Cancel reachable.
var progress:=true
func present(value: String,identity: Array,readonly: bool) -> void:
	if closed:return
	if not started:start()
	if message!=value or scope!=identity or progress!=readonly:
		progress=readonly;super.set_context(value,identity)
	synchronize_input();open()
func assemble() -> void:
	super.assemble();synchronize_input()
func synchronize_input() -> void:
	# Godot's recursive disabled mode applies to scroll descendants as well.
	mouse_behavior_recursive=Control.MOUSE_BEHAVIOR_DISABLED if progress else Control.MOUSE_BEHAVIOR_INHERITED
	focus_behavior_recursive=Control.FOCUS_BEHAVIOR_DISABLED if progress else Control.FOCUS_BEHAVIOR_INHERITED
	if buttons.has("okbutton"):
		buttons.okbutton.disabled=progress;buttons.okbutton.visible=not progress
func _input(event: InputEvent) -> void:
	if not progress:super._input(event)
func invoke(tag: String) -> void:
	if not progress:super.invoke(tag)
