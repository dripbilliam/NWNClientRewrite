extends RefCounted
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Choice=preload("res://systems/native_data/creation_choice_layout.gd")
const BUTTONS={"okbutton":"0x1409c8d10","cancelbutton":"0x1409c7d70","recommendbutton":"0x1409c9a30"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:
	var resource:=str(source.get("Obj_ResRef","")).to_lower()
	if not models.has(resource):return {"error":"Original Skills frame is missing"}
	var main:=Geometry.model(models[resource]);var entries: Dictionary={};var error:=Dialog.flatten(source,models,Vector2.ZERO,entries)
	if not error.is_empty():return {"error":error}
	if not str(main.error).is_empty() or not main.drawn:return {"error":"Original Skills frame geometry is unavailable"}
	for tag in BUTTONS.keys()+["title","ptsremainingbox","costbox","tguilabel","tguilabel2","tguilabel3","skillsbuttonbox","helpbox"]:
		if not entries.has(tag):return {"error":"Original Skills control missing: "+tag}
	# CG_SKILLS has an unused empty off-frame label. The original panel size
	# comes from its frame, not a union including that invisible editor label.
	var origin: Vector2=-main.bounds.position
	for tag in entries:
		var entry: Dictionary=entries[tag];entry.rect.position+=origin
		if entry.has("offset"):entry.offset+=origin
		else:
			# Claimed Cost/Points labels use bounded CGuiLabel::LoadGffData.
			if tag not in ["costbox","ptsremainingbox"]:entry.floating=true;entry.anchor=entry.rect.position
		if BUTTONS.has(tag):entry.callback=BUTTONS[tag]
	# Original9cce50 sets the claimed Title object's bounds flag4, including
	# mode1; keep its GFF center alignment inside the actual rectangle.
	entries.title.erase("floating");entries.title.erase("anchor")
	for tag in ["helpbox","skillsbuttonbox"]:
		for hook in ["scrollmin","scrollmax"]+(["text0","text1","title0","title1"] if tag=="helpbox" else ["top","bottom","listitem"]):
			if not entries[tag].model.hooks.has(hook):return {"error":"Original Skills attachment missing: "+tag+"/"+hook}
	for name in ["ctl_cg_btn_skill","ctl_cg_btn_skup","ctl_cg_btn_skdn","ctl_cg_numbox3","scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original Skills helper missing: "+name}
	var row:=Geometry.model(models.ctl_cg_btn_skill);var number:=Geometry.model(models.ctl_cg_numbox3)
	for hook in ["text0","text1","icon","skillup","skilldown","skillrank","next"]:
		if not row.hooks.has(hook):return {"error":"Original skill row attachment missing: "+hook}
	if not number.hooks.has("text"):return {"error":"Original skill rank text attachment missing"}
	return {"error":"","resource":resource,"main":Rect2(Vector2.ZERO,main.bounds.size),"origin":origin,"size":main.bounds.size,"entries":entries,"row":row,"number":number,"up":Geometry.model(models.ctl_cg_btn_skup),"down":Geometry.model(models.ctl_cg_btn_skdn),"list":Choice.box(entries.skillsbuttonbox,"top","bottom")}
