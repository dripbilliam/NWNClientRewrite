extends RefCounted
const Shared=preload("res://systems/native_data/connection_dialog_layout.gd")
const BUTTONS={"okbutton":"0x1408d0c90","cancelbutton":"0x1408cde80","xbutton":"0x1408cde80","passwordcheck":"0x1408d1690"}
const LABELS=["tguilabel1","tguilabel","tguireason","tguilabel3"]
const EDITS=["pnameeditbox"]
static func parse(root: Dictionary,models: Dictionary) -> Dictionary:
	return Shared.panel(root,models,LABELS,EDITS,BUTTONS)
static func notice(root: Dictionary,models: Dictionary) -> Dictionary:
	return Shared.panel(root,models,[],[],{},["okbutton","messagelabel"])
