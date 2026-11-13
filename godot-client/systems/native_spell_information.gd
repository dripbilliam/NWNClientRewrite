extends "res://systems/native_feat_popup.gd"
# The shared original CG_SPELLINFO artwork has a distinct CSpellInfoPanel
# owner/callback.9c7b80/9c7fe0 explicitly activate this spell information leaf.
func _init() -> void:
	super._init()
	configure_mode(true)
func parse_layout() -> Dictionary:
	var result:=super.parse_layout()
	if str(result.get("error","")).is_empty():result.entries.closebutton.callback="0x1409c8080"
	return result
