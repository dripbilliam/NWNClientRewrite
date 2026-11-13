extends RefCounted
const Choice=preload("res://systems/native_data/creation_choice_layout.gd")
const BUTTONS={"okbutton":"0x1408e36d0","cancelbutton":"0x1408e10c0","recommendbutton":"0x1408e6390"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:return Choice.parse(source,models,BUTTONS,"classlistbox")
