extends RefCounted
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const BUTTONS={"okbutton":"0x1408e45d0","cancelbutton":"0x1408e11c0"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:
	var plan:=Dialog.panel(source,models,["title"],["editbox"],BUTTONS)
	if not str(plan.error).is_empty():return plan
	for hook in ["scrollmin","scrollmax"]:
		if not plan.entries.editbox.model.hooks.has(hook):return {"error":"Original level-up summary scroll attachment missing: "+hook}
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original level-up summary scrollbar missing: "+name}
	return plan
