extends RefCounted
# CPanelCharSheet(mode0): fixed pregame frame shared by PRE_PLAYMOD and CG_MAIN.
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Sheet=preload("res://systems/native_data/character_sheet_layout.gd")
const RESOURCES=["pnl_chrsht2","pnl_chrsht_char2","pnl_chrsht_skil2","ctl_chrsht_nosiz","ctl_chrsht_lstbx","ctl_chrsht_desc","ctl_chr_btnlstbx","ctl_chr_btn_feat","ctl_chr_btn_skil","ctl_chr_btn_tab5","ctl_chr_btn_tab6","ctl_chr_btn_tab7","ctl_chr_btn_tab8","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
const TAB_REFS=[0x2940,0x147,0x146,0x145f]
const ABILITIES=[["str","strength",135],["dex","dexterity",133],["con","constitution",132],["int","intelligence",134],["wis","wisdom",136],["cha","charisma",131]]
static func parse(source: Dictionary,extent: Vector2=Vector2.ZERO) -> Dictionary:
	var models: Dictionary={}
	for name in RESOURCES:
		if not source.has(name): return {"error":"Original fixed character-summary model missing: "+name}
		models[name]=Geometry.model(source[name])
		if not str(models[name].error).is_empty(): return {"error":str(models[name].error)}
	var required:={"pnl_chrsht2":["title0","title1","pages","tabs","resizebar"],"pnl_chrsht_char2":["racealignclass0","racealignclass1","list"],"pnl_chrsht_skil2":["description","list"],"ctl_chrsht_lstbx":["text0","text1","scrollmin","scrollmax"]}
	for name in required:
		for hook in required[name]:
			if not models[name].hooks.has(hook): return {"error":"Original fixed character-summary hook missing: "+name+"/"+hook}
	for item in ABILITIES:
		for hook in ["l"+item[1]+"0","l"+item[1]+"1",item[0]+"stat0",item[0]+"stat1",item[0]+"mod0",item[0]+"mod1",item[0]+"icon"]:
			if not models.pnl_chrsht_char2.hooks.has(hook): return {"error":"Original summary ability hook missing: "+hook}
	for tag in ["armorclass","hitpoints","experience","nextlevel","lac","lhp"]:
		for suffix in ["0","1"]:
			if not models.pnl_chrsht_char2.hooks.has(tag+suffix): return {"error":"Original summary value hook missing: "+tag+suffix}
	var main: Dictionary=models.pnl_chrsht2
	var size:=Vector2(main.bounds.size.x,main.hooks.resizebar.y) if extent==Vector2.ZERO else extent
	if not size.is_finite() or not is_equal_approx(size.x,main.bounds.size.x) or size.y<=main.hooks.pages.y: return {"error":"Invalid original fixed character-summary extent"}
	var tabs: Array=[]; var point: Vector2=main.hooks.tabs
	for index in 4:
		var name: String="ctl_chr_btn_tab"+str(index+5)
		if not models[name].hooks.has("next"): return {"error":"Original fixed character-summary tab attachment missing: "+name}
		tabs.append(Sheet.entry(models,name,point)); point+=models[name].hooks.next
	return {"error":"","models":models,"size":size,"page_origin":main.hooks.pages,"page_size":Vector2(size.x,size.y-main.hooks.pages.y),"tabs":tabs,"footer":Sheet.entry(models,"ctl_chrsht_nosiz",main.hooks.resizebar)}
