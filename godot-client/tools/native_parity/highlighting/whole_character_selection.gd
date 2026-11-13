extends "res://systems/native_render/selection_highlight.gd"
# User-requested whole-character glow candidate. Existing target channels,
# appearance alpha, hover/Tab precedence and lifecycle stay in the controller.
func make_bounds():return preload("res://tools/native_parity/highlighting/whole_character_glow.gd").new()
