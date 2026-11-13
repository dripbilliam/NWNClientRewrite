extends RefCounted
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const State=preload("res://systems/native_data/creation_alignment_state.gd")
const BUTTONS={"okbutton":"0x1408e3560","cancelbutton":"0x1408e1040","recommendbutton":"0x1408e5e20"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:
	var buttons:=BUTTONS.duplicate()
	for tag in State.TAGS:buttons[tag]="0x1408e1310"
	var plan:=Dialog.panel(source,models,["title"],[],buttons,["helpedit"])
	if not str(plan.error).is_empty():return plan
	# Original8eade0 sets the claimed Title object's bounds flag4.
	plan.entries.title.erase("floating");plan.entries.title.erase("anchor")
	for hook in ["text0","text1","title0","title1","scrollmin","scrollmax"]:
		if not plan.entries.helpedit.model.hooks.has(hook):return {"error":"Original Alignment help attachment missing: "+hook}
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original Alignment help scrollbar missing: "+name}
	return plan
