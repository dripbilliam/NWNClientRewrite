extends RefCounted
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Choice=preload("res://systems/native_data/creation_choice_layout.gd")
const BUTTONS={"okbutton":"0x1409c8730","cancelbutton":"0x1409c7be0","recommendbutton":"0x1409c9230"}
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:
	var plan:=Dialog.panel(source,models,["title"],[],BUTTONS,["domainname","domaindesc","domainlistbox"])
	if not str(plan.error).is_empty():return plan
	# Original9cc0f0 sets the claimed Title object's bounds flag4.
	plan.entries.title.erase("floating");plan.entries.title.erase("anchor")
	for tag in ["domainlistbox","domaindesc"]:
		var hooks: Dictionary=plan.entries[tag].model.hooks
		for hook in ["scrollmin","scrollmax"]+(["top","bottom","listitem"] if tag=="domainlistbox" else ["text0","text1","domain1","domain2"]):
			if not hooks.has(hook):return {"error":"Original Domain hook missing: "+tag+"/"+hook}
	for name in ["ctl_cg_btn_dom","ctl_cg_btn_left","ctl_cg_btn_right","scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original Domain helper missing: "+name}
	plan.row=Geometry.model(models.ctl_cg_btn_dom)
	for hook in ["text","icon","next","addremovebutton"]:
		if not plan.row.hooks.has(hook):return {"error":"Original Domain row hook missing: "+hook}
	plan.list=Choice.box(plan.entries.domainlistbox,"top","bottom");plan.help_body=Choice.box(plan.entries.domaindesc,"text0","text1")
	return plan
