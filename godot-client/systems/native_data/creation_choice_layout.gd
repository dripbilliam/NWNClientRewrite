extends RefCounted
# CG_RACE and CG_CLASS use the same original list/help and radio row models.
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
static func box(entry: Dictionary,a: String,b: String) -> Rect2:return Rect2(entry.offset+entry.model.hooks[a],entry.model.hooks[b]-entry.model.hooks[a]).abs()
static func parse(source: Dictionary,models: Dictionary,buttons: Dictionary,list_tag: String) -> Dictionary:
	var plan:=Dialog.panel(source,models,["title"],[],buttons,["helpbox",list_tag])
	if not str(plan.error).is_empty():return plan
	# Race8e8fe0/Class8ec4b0/Package8ed900 set Title's bounds flag4.
	# Its centered GFF rectangle is not an unclaimed-label text anchor.
	plan.entries.title.erase("floating");plan.entries.title.erase("anchor")
	for tag in ["helpbox",list_tag]:
		for hook in ["scrollmin","scrollmax"]+(["text0","text1","title0","title1"] if tag=="helpbox" else ["top","bottom","listitem"]):
			if not plan.entries[tag].model.hooks.has(hook):return {"error":"Original creation choice attachment missing: "+tag+"/"+hook}
	for name in ["ctl_cg_btn_class","scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original creation choice helper model missing: "+name}
	plan.row=Geometry.model(models.ctl_cg_btn_class)
	for hook in ["text0","text1","icon","next"]:
		if not plan.row.hooks.has(hook):return {"error":"Original creation choice row attachment missing: "+hook}
	plan.help_body=box(plan.entries.helpbox,"text0","text1");plan.help_title=box(plan.entries.helpbox,"title0","title1");plan.list=box(plan.entries[list_tag],"top","bottom")
	plan.choice_buttons=buttons.keys()
	return plan
