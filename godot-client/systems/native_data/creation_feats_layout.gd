extends RefCounted
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Choice=preload("res://systems/native_data/creation_choice_layout.gd")
const BUTTONS={"okbutton":"0x1409c8a90","cancelbutton":"0x1409c7ca0","recommendbutton":"0x1409c9600","resetbutton":"0x1409ca6a0"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:
	var resource:=str(source.get("Obj_ResRef","")).to_lower()
	if not models.has(resource):return {"error":"Original Feats frame is missing"}
	var main:=Geometry.model(models[resource]);var entries: Dictionary={};var error:=Dialog.flatten(source,models,Vector2.ZERO,entries)
	if not error.is_empty():return {"error":error}
	if not str(main.error).is_empty() or not main.drawn:return {"error":"Original Feats frame geometry is unavailable"}
	for tag in BUTTONS.keys()+["title","remainlabel","tguilabel","availbox","knownbox","availtitle","knowntitle"]:
		if not entries.has(tag):return {"error":"Original Feats control is missing: "+tag}
	var origin: Vector2=-main.bounds.position
	for tag in entries:
		var entry: Dictionary=entries[tag];entry.rect.position+=origin
		if entry.has("offset"):entry.offset+=origin
		if BUTTONS.has(tag):entry.callback=BUTTONS[tag]
		if tag in ["availtitle","knowntitle","remainlabel","tguilabel"]:entry.floating=true;entry.anchor=entry.rect.position
	var lists: Dictionary={}
	for tag in ["availbox","knownbox"]:
		for hook in ["top","bottom","listitem","scrollmin","scrollmax"]:
			if not entries[tag].model.hooks.has(hook):return {"error":"Original Feats list hook is missing: "+tag+"/"+hook}
		lists[tag]=Choice.box(entries[tag],"top","bottom")
	for name in ["ctl_cg_btn_feat","ctl_cg_btn_left","ctl_cg_btn_right","ctl_cg_btn_help","scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original Feats helper is missing: "+name}
	var row:=Geometry.model(models.ctl_cg_btn_feat)
	for hook in ["text0","text1","icon","next","addremovebutton","helpbutton"]:
		if not row.hooks.has(hook):return {"error":"Original Feats row hook is missing: "+hook}
	return {"error":"","resource":resource,"main":Rect2(Vector2.ZERO,main.bounds.size),"size":main.bounds.size,"origin":origin,"entries":entries,"row":row,"lists":lists}
static func popup(source: Dictionary,models: Dictionary,information: bool) -> Dictionary:
	var callbacks: Dictionary={"closebutton":"0x1409c8050"} if information else {"okbutton":"0x1409c8c50","cancelbutton":"0x1409c7d00"}
	var tag:="editbox" if information else "featslist"
	var plan:=Dialog.panel(source,models,[],[],callbacks,[tag,"title" if information else "tguilabel"])
	if not str(plan.error).is_empty():return plan
	var entry: Dictionary=plan.entries[tag]
	for hook in ["text0","text1","scrollmin","scrollmax"]:
		if not entry.model.hooks.has(hook):return {"error":"Original Feats popup hook is missing: "+hook}
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original Feats popup helper is missing: "+name}
	plan.content=Choice.box(entry,"text0","text1");plan.content_tag=tag;plan.popup_buttons=callbacks.keys()
	if not information:
		#9cbfd0 claims FeatsList and buttons only; CloseLayoutFile creates
		# this unclaimed caption through the unbounded text-label path.
		plan.entries.tguilabel.floating=true;plan.entries.tguilabel.anchor=plan.entries.tguilabel.rect.position
	if information:
		var main:=Geometry.model(models[plan.resource])
		if not main.hooks.has("icon"):return {"error":"Original Feats information icon hook is missing"}
		plan.icon=plan.origin+main.hooks.icon
	return plan
