extends RefCounted
const Choice=preload("res://systems/native_data/creation_choice_layout.gd")
const BUTTONS={"okbutton":"0x1408e53e0","cancelbutton":"0x1408e1250","recommendbutton":"0x1408e6730","subracebutton":"0x1408e7730"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:
	return Choice.parse(source,models,BUTTONS,"racelistbox")
