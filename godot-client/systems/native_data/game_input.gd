extends RefCounted
# src/game_input.js: fixed world movement codes and focused-control gates.
static func is_world_move_key(code: int) -> bool:
	return code in [KEY_W,KEY_UP,KEY_S,KEY_DOWN,KEY_A,KEY_LEFT,KEY_D,KEY_RIGHT,KEY_Q,KEY_E]
static func is_control_arrow(code: int,focus: Control) -> bool:
	if code not in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:return false
	var current:=focus
	while is_instance_valid(current):
		if current is LineEdit or current is TextEdit or current is BaseButton or current is Range or current is ItemList or current is Tree or current is TabBar:return true
		current=current.get_parent() as Control
	return false
static func is_text_entry(focus: Control) -> bool:
	var current:=focus
	while is_instance_valid(current):
		if current is LineEdit or current is TextEdit or current is OptionButton:return true
		current=current.get_parent() as Control
	return false
