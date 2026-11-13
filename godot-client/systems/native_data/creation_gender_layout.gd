extends RefCounted
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const BUTTONS={"malebutton":"0x1408e14a0","femalebutton":"0x1408e14a0","okbutton":"0x1408e56e0","cancelbutton":"0x1408e1290"}
static func parse(root: Dictionary,models: Dictionary) -> Dictionary:
	var result:=Dialog.panel(root,models,["title"],[],BUTTONS,["helpbox"])
	if not str(result.error).is_empty():return result
	# Original8ede10 sets the claimed Title object's bounds flag4.
	result.entries.title.erase("floating");result.entries.title.erase("anchor")
	var help: Dictionary=result.entries.helpbox
	for hook in ["text0","text1","title0","title1","scrollmin","scrollmax"]:
		if not help.model.hooks.has(hook):return {"error":"Original creation help attachment is missing: "+hook}
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original creation help scrollbar is missing: "+name}
	result.help_body=Rect2(help.offset+help.model.hooks.text0,help.model.hooks.text1-help.model.hooks.text0).abs()
	result.help_title=Rect2(help.offset+help.model.hooks.title0,help.model.hooks.title1-help.model.hooks.title0).abs()
	return result
