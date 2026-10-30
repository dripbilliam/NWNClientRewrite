extends RefCounted
const Connection=preload("res://systems/native_data/connection_dialog_layout.gd")
const BUTTONS={"okbutton":"0x1408d0b10","cancelbutton":"0x1408cdda0","xbutton":"0x1408cdda0"}
const CHECKS=["havepeoplebox","notfullbox"]
const LABELS=["tguilabel2","tguilabel32","tguilabel321","tguilabel1"]
static func parse(root: Dictionary,models: Dictionary) -> Dictionary:
	return Connection.panel(root,models,LABELS,["moduleedit"],BUTTONS,CHECKS)
