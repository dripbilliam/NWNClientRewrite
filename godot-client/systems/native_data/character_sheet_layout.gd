extends RefCounted
# CPanelCharSheet14088a0a0 / CCharPageChar1409b3440 and Skills1409bf0f0.
# Programmatic bindings use active original models, not a captured screenshot.
const Model=preload("res://systems/native_data/inventory_equipment_layout.gd")
const RESOURCES=["pnl_chrsht","pnl_chrsht_char","pnl_chrsht_skils","ctl_chrsht_resiz","ctl_btn_x","ctl_chrsht_lstbx","ctl_chrsht_lvlup","ctl_chrsht_desc","ctl_chr_btnlstbx","ctl_chr_btn_skil","ctl_chr_btn_feat","ctl_chr_btn_tab1","ctl_chr_btn_tab2","ctl_chr_btn_tab3","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
const CAPTION={"AurString_Font":"fnt_galahad14","AurString_AlignH":0.5,"AurString_AlignV":0.5}
static func box(model: Dictionary,first: String,last: String,offset: Vector2=Vector2.ZERO) -> Rect2:
	return Rect2(offset+model.hooks[first],model.hooks[last]-model.hooks[first]).abs()
static func entry(models: Dictionary,name: String,offset: Vector2) -> Dictionary:
	var rect: Rect2=models[name].bounds; rect.position+=offset
	return {"resource":name,"rect":rect,"offset":offset,"model":models[name],"caption":CAPTION.duplicate()}
static func parse(source: Dictionary) -> Dictionary:
	var models: Dictionary={}
	for name in RESOURCES:
		if not source.has(name): return {"error":"Original character-sheet model is missing: "+name}
		models[name]=Model.model(source[name])
		if not str(models[name].error).is_empty(): return {"error":str(models[name].error)}
	var required:={"pnl_chrsht":["title0","title1","xbutton","pages","tabs","resizebar"],"pnl_chrsht_char":["racealignclass0","racealignclass1","list","levelupbutton","armorclass0","armorclass1","hitpoints0","hitpoints1","experience0","experience1","nextlevel0","nextlevel1","lac0","lac1","lhp0","lhp1"],"pnl_chrsht_skils":["description","list"],"ctl_chrsht_lstbx":["text0","text1","scrollmin","scrollmax"],"ctl_chrsht_desc":["text0","text1","scrollmin","scrollmax"],"ctl_chr_btnlstbx":["scrollmin","scrollmax","top","bottom","listitem"],"ctl_chrsht_lvlup":["text"],"ctl_chr_btn_skil":["icon","text","value","next"],"ctl_chr_btn_feat":["icon","text","next"]}
	for name in required:
		for hook in required[name]:
			if not models[name].hooks.has(hook): return {"error":"Original character-sheet attachment is missing: "+name+"/"+hook}
	for pair in [["str","strength"],["dex","dexterity"],["con","constitution"],["int","intelligence"],["wis","wisdom"],["cha","charisma"]]:
		for hook in [pair[0]+"stat0",pair[0]+"stat1",pair[0]+"mod0",pair[0]+"mod1",pair[0]+"icon","l"+pair[1]+"0","l"+pair[1]+"1"]:
			if not models.pnl_chrsht_char.hooks.has(hook): return {"error":"Original ability attachment is missing: "+hook}
	var main: Dictionary=models.pnl_chrsht; var size:=Vector2(main.bounds.size.x,main.hooks.resizebar.y)
	if size.x<=0 or size.y<=main.hooks.pages.y+258: return {"error":"Invalid original character-sheet viewport extent"}
	var tabs: Array=[]; var point: Vector2=main.hooks.tabs
	for index in 3:
		var name: String="ctl_chr_btn_tab"+str(index+1)
		if not models[name].hooks.has("next"): return {"error":"Original character tab has no next attachment"}
		tabs.append(entry(models,name,point)); point+=models[name].hooks.next
	return {"error":"","models":models,"size":size,"page_origin":main.hooks.pages,"page_size":Vector2(size.x,size.y-main.hooks.pages.y),"title":box(main,"title0","title1"),"close":entry(models,"ctl_btn_x",main.hooks.xbutton),"tabs":tabs,"footer":entry(models,"ctl_chrsht_resiz",main.hooks.resizebar)}
