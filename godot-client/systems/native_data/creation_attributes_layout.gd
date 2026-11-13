extends RefCounted
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const KEYS=["str","dex","con","int","wis","cha"]
const DOWN=["0x1408e73c0","0x1408e2780","0x1408e2240","0x1408e2df0","0x1408e7e10","0x1408e1560"]
const UP=["0x1408e7570","0x1408e2930","0x1408e23f0","0x1408e2fa0","0x1408e80c0","0x1408e1810"]
const BUTTONS={"okbutton":"0x1408e3520","cancelbutton":"0x1408e1000","recommendbutton":"0x1408e5cf0"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:
	var buttons:=BUTTONS.duplicate();var labels: Array=["title","tguilabel11","tguilabel1"]
	for index in KEYS.size():
		var key: String=KEYS[index];buttons[key+"label"]="0x1408e2b00";buttons[key+"upbutton"]=UP[index];buttons[key+"downbutton"]=DOWN[index];labels.append(key+"edit")
	var plan:=Dialog.panel(source,models,labels,[],buttons,["helpedit","pointsedit","costedit","ctl_cg_lstbxat"])
	if not str(plan.error).is_empty():return plan
	#8ea6a0 claims Title as a CGuiLabel and explicitly sets its bounds flag4.
	# Its GFF rectangle is the alignment region, not an unbounded text anchor.
	plan.entries.title.erase("floating");plan.entries.title.erase("anchor")
	for key in KEYS:
		var row:Dictionary=plan.entries[key+"label"]
		if not row.model.hooks.has("text"):return {"error":"Original Abilities name attachment missing: "+key+"/text"}
		row.caption_anchor=row.offset+row.model.hooks.text
	for hook in ["text0","text1","title0","title1","scrollmin","scrollmax"]:
		if not plan.entries.helpedit.model.hooks.has(hook):return {"error":"Original Abilities help attachment missing: "+hook}
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original Abilities scrollbar missing: "+name}
	return plan
