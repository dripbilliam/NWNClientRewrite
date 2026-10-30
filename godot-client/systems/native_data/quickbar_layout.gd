extends RefCounted
# CPanelQuickBar1408584a0: original bank model table and Slot01..Slot12 hooks.
const Model=preload("res://systems/native_data/inventory_equipment_layout.gd")
const RESOURCES=["pnl_quick_bar","qb_but66","qb_but67","qb_but67end","gui_qbar_ends"]
const SLOTS=["qb_but67","qb_but66","qb_but67","qb_but67","qb_but67","qb_but66","qb_but66","qb_but67","qb_but67","qb_but67","qb_but66","qb_but67end"]
const FONT="ttf fnt_default 14"
const PREFIX_REFS=[-1,0x10c50,0x10c51]
static func parse(source: Dictionary) -> Dictionary:
	var models: Dictionary={}
	for name in RESOURCES:
		if not source.has(name): return {"error":"Original quickbar model missing: "+name}
		models[name]=Model.model(source[name])
		if not str(models[name].error).is_empty(): return {"error":str(models[name].error)}
	var slots: Array=[]; var bounds:=Rect2(); var first:=true
	for index in 12:
		var hook:="slot%02d"%(index+1); var resource: String=SLOTS[index]; var model: Dictionary=models[resource]
		if not models.pnl_quick_bar.hooks.has(hook): return {"error":"Original quickbar attachment missing: "+hook}
		for name in ["text","icon","count0","count1"]:
			if not model.hooks.has(name): return {"error":"Original quickbar slot attachment missing: "+resource+"/"+name}
		var offset: Vector2=models.pnl_quick_bar.hooks[hook]; var rect: Rect2=model.bounds; rect.position+=offset
		slots.append({"resource":resource,"model":model,"offset":offset,"rect":rect})
		bounds=rect if first else bounds.merge(rect); first=false
	if bounds.size.x<1 or bounds.size.y<1: return {"error":"Original quickbar has no drawable slots"}
	return {"error":"","models":models,"slots":slots,"bounds":bounds,"origin":-bounds.position,"width":800.0}
