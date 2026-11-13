extends RefCounted
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const KEYS=["str","dex","con","int","wis","cha"]
const DOWN=["0x1408e74e0","0x1408e28a0","0x1408e2360","0x1408e2f10","0x1408e8030","0x1408e1780"]
const UP=["0x1408e76b0","0x1408e2a80","0x1408e2540","0x1408e30f0","0x1408e8310","0x1408e1a60"]
const BUTTONS={"okbutton":"0x1408e4530","cancelbutton":"0x1408e1180","recommendbutton":"0x1408e5f60"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:
	var buttons:=BUTTONS.duplicate();var labels: Array=["title","tguilabel1"]
	for index in KEYS.size():
		var key: String=KEYS[index];buttons[key+"label"]="0x1408e2b90";buttons[key+"upbutton"]=UP[index];buttons[key+"downbutton"]=DOWN[index];labels.append(key+"edit")
	var plan:=Dialog.panel(source,models,labels,[],buttons,["helpedit","pointsedit","ctl_cg_lstbxat"])
	if not str(plan.error).is_empty():return plan
	# Binder8ed110 sets the claimed Title's bounds flag4 before import.
	plan.entries.title.erase("floating");plan.entries.title.erase("anchor")
	for key in KEYS:
		var row: Dictionary=plan.entries[key+"label"]
		if not row.model.hooks.has("text"):return {"error":"Original level-up ability name attachment missing: "+key}
		row.caption_anchor=row.offset+row.model.hooks.text
	for hook in ["text0","text1","title0","title1","scrollmin","scrollmax"]:
		if not plan.entries.helpedit.model.hooks.has(hook):return {"error":"Original level-up ability help attachment missing: "+hook}
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original level-up ability scrollbar missing: "+name}
	return plan
