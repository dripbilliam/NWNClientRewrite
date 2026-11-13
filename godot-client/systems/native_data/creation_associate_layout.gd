extends RefCounted
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const BUTTONS={"okbutton":"0x1409c88f0","cancelbutton":"0x1409c7c40","gennamebutton":"0x1409c8110"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:
	var plan:=Dialog.panel(source,models,["title","tguilabel"],["nameeditbox"],BUTTONS,["famlistbox"])
	if not str(plan.get("error","")).is_empty():return plan
	if not models.has("ctl_cg_btn_famil"):return {"error":"Original associate row model is missing."}
	var row:=Geometry.model(models.ctl_cg_btn_famil)
	for hook in ["text0","text1","next","helpbutton","icon"]:
		if not row.hooks.has(hook):return {"error":"Original associate row hook is missing: "+hook}
	for hook in ["text0","text1","listitem","scrollmin","scrollmax"]:
		if not plan.entries.famlistbox.model.hooks.has(hook):return {"error":"Original associate list hook is missing: "+hook}
	var main:=Geometry.model(models[plan.resource])
	if not main.hooks.has("charactersheet"):return {"error":"Original associate character-sheet attachment is missing."}
	plan.row=row;plan.summary_origin=plan.origin+main.hooks.charactersheet
	var entry: Dictionary=plan.entries.famlistbox
	var first: Vector2=entry.offset+entry.model.hooks.text0
	var last: Vector2=entry.offset+entry.model.hooks.text1
	plan.list=Rect2(first.min(last),(last-first).abs())
	return plan
