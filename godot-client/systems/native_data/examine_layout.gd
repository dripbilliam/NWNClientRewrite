extends RefCounted
const Layout=preload("res://systems/native_data/inventory_frame_layout.gd")
static func parse(root: Dictionary,models: Dictionary,item: bool) -> Dictionary:
	var resource:=str(root.get("Obj_ResRef","")).to_lower()
	if not models.has(resource): return {"error":"Missing original examine panel model"}
	var panel:=Layout.Model.model(models[resource])
	if not str(panel.error).is_empty() or not panel.drawn or not panel.hooks.has("icon"): return {"error":"Invalid original examine panel geometry/Icon hook"}
	var origin: Vector2=-panel.bounds.position; var controls:=Layout.elements(root,models,origin)
	if not str(controls.error).is_empty(): return controls
	for tag in ["name","description","closebutton","xbutton"]:
		if not controls.entries.has(tag): return {"error":"Missing original examine control: "+tag}
	if item and not controls.entries.has("identifybutton"): return {"error":"Missing original Identify control"}
	return {"error":"","resource":resource,"size":panel.bounds.size,"entries":controls.entries,"icon":origin+panel.hooks.icon,"item":item}
