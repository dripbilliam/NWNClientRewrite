extends RefCounted
const Layout=preload("res://systems/native_data/inventory_frame_layout.gd")
static func parse(layouts: Dictionary,models: Dictionary) -> Dictionary:
	for name in ["ingame_store","buysell_confirm"]:
		if not layouts.has(name): return {"error":"Missing original merchant GUI: "+name}
	var root: Dictionary=layouts.ingame_store; var resource:=str(root.get("Obj_ResRef","")).to_lower()
	if not models.has(resource): return {"error":"Missing original merchant panel model"}
	var panel:=Layout.Model.model(models[resource])
	if not str(panel.error).is_empty() or not panel.drawn or not panel.hooks.has("tabs"): return {"error":"Invalid original merchant panel geometry/tab hook"}
	var origin: Vector2=-panel.bounds.position; var entries:=Layout.elements(root,models,origin)
	if not str(entries.error).is_empty(): return entries
	for tag in ["scrollpagelabel","examinebutton","invbox","iteminfo","scrollup","scrolldown","title","xbutton"]:
		if not entries.entries.has(tag): return {"error":"Missing original merchant control: "+tag}
	var grid:=Layout.grid(entries.entries.invbox.model,entries.entries.invbox.offset,10,10)
	if not str(grid.error).is_empty(): return grid
	var tabs: Array=[]; var point: Vector2=origin+panel.hooks.tabs
	for index in 5:
		var name:="ctl_inv_sto_tab"+str(index+1)
		if not models.has(name): return {"error":"Missing original merchant tab: "+name}
		var tab:=Layout.Model.model(models[name])
		if not str(tab.error).is_empty() or not tab.drawn or not tab.hooks.has("next"): return {"error":"Invalid original linked merchant tab"}
		var rect: Rect2=tab.bounds; rect.position+=point
		tabs.append({"resource":name,"rect":rect,"offset":point}); point+=tab.hooks.next
	var dialog: Dictionary=layouts.buysell_confirm; var dialog_resource:=str(dialog.get("Obj_ResRef","")).to_lower()
	if not models.has(dialog_resource): return {"error":"Missing original buy/sell panel model"}
	var box:=Layout.Model.model(models[dialog_resource])
	if not str(box.error).is_empty() or not box.drawn: return {"error":"Invalid original buy/sell panel geometry"}
	var confirm:=Layout.elements(dialog,models,-box.bounds.position)
	if not str(confirm.error).is_empty(): return confirm
	for tag in ["itemdesc","okbutton","cancelbutton"]:
		if not confirm.entries.has(tag): return {"error":"Missing original confirmation control: "+tag}
	return {"error":"","resource":resource,"size":panel.bounds.size,"entries":entries.entries,"grid":grid,"tabs":tabs,"confirm":{"resource":dialog_resource,"size":box.bounds.size,"entries":confirm.entries}}
