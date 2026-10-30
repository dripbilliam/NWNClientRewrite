extends RefCounted
const Connection=preload("res://systems/native_data/connection_dialog_layout.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const PAGES={"Internet":"serverlist_page1","History":"serverlist_page3","Favorites":"serverlist_page4"}
const TABS={"tab0":"Internet","tab2":"History","tab3":"Favorites"}
const SORTS=["srvnamebutton","modnamebutton","playersbutton","levelsbutton","pvpbutton","syncbutton"]
const COLUMNS=["ctl_serverlist","modulenamelist","playerlist","levellist","pvplist","synclist"]
const ACTIONS=["srvdetailsbutton","dirconnectbutton","connectbutton","cancelbutton"]
const EXTRA=["scrollbar_simple","pb_scrl_up","pb_scrl_down","ctl_srv_hilit","ctl_srv_hilit3"]
const ROW_STEP:=20.0 #8c3990 overrides CGuiListBox's default21 for all six lists.
static func parse(sources: Dictionary,models: Dictionary) -> Dictionary:
	if not sources.has("serverlist_panel"): return {"error":"Missing original server-list panel"}
	var root: Dictionary=sources.serverlist_panel; var resource:=str(root.get("Obj_ResRef","")).to_lower()
	if not models.has(resource): return {"error":"Missing original server-list frame model"}
	var geometry:=Geometry.model(models[resource])
	if not str(geometry.error).is_empty() or not geometry.drawn or not geometry.hooks.has("pages"): return {"error":"Original browser page attachment is missing"}
	var origin: Vector2=-geometry.bounds.position; var entries: Dictionary={}; var error:=Connection.flatten(root,models,origin,entries)
	if not error.is_empty(): return {"error":error}
	for tag in ["tab0","tab1","tab2","tab3","tab4"]:
		if not entries.has(tag): return {"error":"Missing original browser tab: "+tag}
	var attachment: Vector2=origin+geometry.hooks.pages; var total:=Rect2(Vector2.ZERO,geometry.bounds.size); var pages: Dictionary={}
	for tab in PAGES:
		var name: String=PAGES[tab]
		if not sources.has(name): return {"error":"Missing original browser page: "+name}
		var page: Dictionary=sources[name]; var model:=str(page.get("Obj_ResRef","")).to_lower()
		if not models.has(model): return {"error":"Missing original browser page model: "+model}
		var data:=Geometry.model(models[model]); var controls: Dictionary={}; error=Connection.flatten(page,models,attachment,controls)
		if not str(data.error).is_empty() or not data.drawn or not error.is_empty(): return {"error":"Invalid original browser page geometry: "+name+" "+error}
		var favorite: String="rmfavoritebutton" if tab=="Favorites" else "favoritesbutton"
		for tag in COLUMNS+SORTS+ACTIONS+[favorite]:
			if not controls.has(tag): return {"error":"Missing original server-list control: "+name+"/"+tag}
		var list: Dictionary=controls.ctl_serverlist
		for hook in ["viewport0","viewport1","text0","text1","scrollmin","scrollmax"]:
			if not list.model.hooks.has(hook): return {"error":"Missing original list attachment: "+hook}
		var clip:=Rect2(list.offset+list.model.hooks.viewport0,list.model.hooks.viewport1-list.model.hooks.viewport0).abs()
		var columns: Array=[]
		for tag in COLUMNS:
			var entry: Dictionary=controls[tag]
			if not entry.model.hooks.has("text0") or not entry.model.hooks.has("text1"): return {"error":"Missing original column text hooks: "+tag}
			columns.append(Rect2(entry.offset+entry.model.hooks.text0,entry.model.hooks.text1-entry.model.hooks.text0).abs())
		var rect:=Rect2(attachment+data.bounds.position,data.bounds.size); total=total.merge(rect)
		var highlight: String="ctl_srv_hilit" if tab=="Internet" else "ctl_srv_hilit3"
		if not models.has(highlight): return {"error":"Missing original server-row highlight: "+highlight}
		var highlight_geometry:=Geometry.model(models[highlight])
		if not str(highlight_geometry.error).is_empty() or not highlight_geometry.drawn: return {"error":"Invalid original row highlight geometry"}
		pages[tab]={"resource":model,"rect":rect,"entries":controls,"clip":clip,"columns":columns,"favorite":favorite,"highlight":highlight,"highlight_size":highlight_geometry.bounds.size}
	return {"error":"","resource":resource,"main":Rect2(geometry.bounds.position+origin,geometry.bounds.size),"size":total.size,"origin":origin,"attachment":attachment,"entries":entries,"pages":pages,"native_only":true,"full_browser_parity":false}
