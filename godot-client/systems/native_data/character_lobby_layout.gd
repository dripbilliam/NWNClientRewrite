extends RefCounted
# CPlayModulePanel7143f0 / row70cd20; programmatic attachments augment PRE_PLAYMOD.
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Gui=preload("res://systems/native_data/connection_dialog_layout.gd")
const Record=preload("res://systems/native_data/character_sheet_layout.gd")
const CAPTION={"AurString_Font":"fnt_galahad14"}
const BUTTONS={"newcharbutton":"0x140711660","customcharbutton":"0x140710130","deletecharbutton":"0x1407103a0","playbutton":"0x140711d40","cancelbutton":"0x14070f8d0"}
const RESOURCES=["ctl_pre_btn_char","ctl_pre_btn_plyr","ctl_playmod_page","ctl_pre_btn_tab","ctl_pre_btn_tab2","pmod_details800","ctl_pre_plyrlist"]+preload("res://systems/native_data/character_summary_layout.gd").RESOURCES
static func texture_bounds(source: Dictionary,texture: String) -> Dictionary:
	var masked:=source.duplicate(); masked.nodes=[]
	for item in source.get("nodes",[]):
		var node: Dictionary=item.duplicate(); var mesh: Dictionary=item.get("mesh",{}).duplicate()
		mesh.render=mesh.get("render",false) and str(mesh.get("textures",[])).to_lower().contains(texture.to_lower()); node.mesh=mesh; masked.nodes.append(node)
	return Geometry.model(masked)
static func parse(root: Dictionary,source: Dictionary) -> Dictionary:
	var models: Dictionary={}
	for name in source:
		models[name]=Geometry.model(source[name])
		if not str(models[name].error).is_empty(): return models[name]
	var resource:=str(root.get("Obj_ResRef","")).to_lower()
	for name in RESOURCES+[resource]:
		if not models.has(name): return {"error":"Original character chooser model missing: "+name}
	var main: Dictionary=models[resource]; var origin: Vector2=-main.bounds.position; var entries: Dictionary={}
	var error:=Gui.flatten(root,source,origin,entries)
	if not error.is_empty(): return {"error":error}
	for name in BUTTONS.keys()+["buttonlist","savegamebox","savelabel","title"]:
		if not entries.has(name): return {"error":"Original character chooser control missing: "+name}
	for name in BUTTONS: entries[name].callback=BUTTONS[name]
	var required:={resource:["chartab","tabs"],"ctl_pre_btn_char":["text0","text1","label0","label1","next"],"ctl_playmod_page":["pages"],"ctl_pre_btn_tab":["next","text"],"ctl_pre_btn_tab2":["next","text"],"pnl_chrsht2":["pages","title0","title1"],"pnl_chrsht_char2":["racealignclass0","racealignclass1"]}
	for name in required:
		for hook in required[name]:
			if not models[name].hooks.has(hook): return {"error":"Original chooser hook missing: "+name+"/"+hook}
	var list: Dictionary=entries.buttonlist
	for hook in ["top","bottom","listitem","scrollmin","scrollmax"]:
		if not list.model.hooks.has(hook): return {"error":"Original chooser list hook missing: "+hook}
	var viewport:=Rect2(list.offset+list.model.hooks.top,list.model.hooks.bottom-list.model.hooks.top).abs()
	var first: Vector2=list.offset+list.model.hooks.listitem-viewport.position
	var portrait:=texture_bounds(source.ctl_pre_btn_char,"gui_replace01")
	if not portrait.drawn: return {"error":"Original character row portrait mesh missing"}
	var page_origin: Vector2=origin+main.hooks.chartab+models.ctl_playmod_page.hooks.pages
	var point: Vector2=origin+main.hooks.tabs; var tabs: Array=[]
	for index in 3:
		var name: String="ctl_pre_btn_tab" if index==0 else "ctl_pre_btn_tab2"
		tabs.append(Record.entry(models,name,point)); point+=models[name].hooks.next
	return {"error":"","resource":resource,"size":main.bounds.size,"main":Rect2(Vector2.ZERO,main.bounds.size),"entries":entries,"models":models,"list_rect":viewport,"first":first,"row_next":models.ctl_pre_btn_char.hooks.next,"portrait":portrait.bounds,"page_origin":page_origin,"tabs":tabs,"full_character_lobby_parity":false}
