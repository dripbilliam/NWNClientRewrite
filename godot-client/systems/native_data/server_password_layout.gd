extends RefCounted
const Shared=preload("res://systems/native_data/connection_dialog_layout.gd")
const BUTTONS={"okbutton":"0x1408d0c80","cancelbutton":"0x1408cde40"}
static func parse(root: Dictionary,models: Dictionary) -> Dictionary:
	return Shared.panel(root,models,["tguilabel"],["passwordeditbox"],BUTTONS)
