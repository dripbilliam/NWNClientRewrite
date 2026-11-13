extends RefCounted
const Choice=preload("res://systems/native_data/creation_choice_layout.gd")
const BUTTONS={"okbutton":"0x1408e4620","cancelbutton":"0x1408e11d0","configurepckg":"0x1408e1ec0","recommendbutton":"0x1408e66f0"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:return Choice.parse(source,models,BUTTONS,"classlistbox")
