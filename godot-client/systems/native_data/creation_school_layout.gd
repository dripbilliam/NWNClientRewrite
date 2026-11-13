extends RefCounted
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const State=preload("res://systems/native_data/creation_school_state.gd")
const BUTTONS={"okbutton":"0x1409c8c60","cancelbutton":"0x1409c7d10","recommendbutton":"0x1409c9860"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:
	var callbacks:=BUTTONS.duplicate()
	for tag in State.TAGS:callbacks[tag]="0x1409c7e40"
	var plan:=Dialog.panel(source,models,["title"],[],callbacks,["helpbox"])
	if not str(plan.error).is_empty():return plan
	# Original9ccb40 sets the claimed Title object's bounds flag4.
	plan.entries.title.erase("floating");plan.entries.title.erase("anchor")
	for hook in ["text0","text1","title0","title1","scrollmin","scrollmax"]:
		if not plan.entries.helpbox.model.hooks.has(hook):return {"error":"Original School help attachment missing: "+hook}
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original School help scrollbar missing: "+name}
	return plan
