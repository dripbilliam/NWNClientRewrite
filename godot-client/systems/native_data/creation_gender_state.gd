extends RefCounted
# CCharacterSexPanel: choices remain local until OK, which reads the then-current
# draft gender. Changed/unchanged results have distinct CG_MAIN callback codes.
var selected:=-1
var help_title:=203
var help_description:=447
func reset(gender: int,present: bool=true) -> void:
	selected=-1;help_title=203;help_description=447
	# Programmatic original SelectTab sets radio poses, not its click callback.
	if present and (gender&255) in [0,1]: selected=gender&255
func select(index: int) -> bool:
	if index not in [0,1]: return false
	selected=index;help_title=[445,446][index];help_description=[199,200][index];return true
func result(gender: int,present: bool=true,cancelled: bool=false) -> Dictionary:
	gender&=255
	if cancelled:return {"gender":gender,"code":2}
	if not present or selected not in [0,1]:return {"gender":gender,"code":0x800d}
	return {"gender":selected,"code":0x800d if selected==gender else 0x8017}
