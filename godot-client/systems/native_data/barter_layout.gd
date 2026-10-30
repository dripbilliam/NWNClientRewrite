extends RefCounted
const Layout=preload("res://systems/native_data/inventory_frame_layout.gd")
static func parse(gui: Dictionary,models: Dictionary) -> Dictionary:
	var resource:=str(gui.get("Obj_ResRef","")).to_lower()
	if not models.has(resource): return {"error":"Original barter panel model is unavailable"}
	var panel:=Layout.Model.model(models[resource])
	if not str(panel.error).is_empty() or not panel.drawn: return {"error":"Original barter panel geometry is unavailable"}
	var plan:=Layout.elements(gui,models,-panel.bounds.position)
	if not str(plan.error).is_empty(): return plan
	var entries: Dictionary=plan.entries
	for tag in ["titletext","playeritems","barteritems","leftacceptbut","rightacceptbut","leftdeclinebut","rightdeclinebut","leftcancelbut","playerportrait","barratorportrait","examinebutton","goldbutton","xbutton"]:
		if not entries.has(tag): return {"error":"Original barter control is missing: "+tag}
	var own:=Layout.grid(entries.playeritems.model,entries.playeritems.offset,3,10)
	var other:=Layout.grid(entries.barteritems.model,entries.barteritems.offset,3,10)
	if not str(own.error).is_empty(): return own
	if not str(other.error).is_empty(): return other
	return {"error":"","resource":resource,"size":panel.bounds.size,"entries":entries,"own":own,"other":other}
