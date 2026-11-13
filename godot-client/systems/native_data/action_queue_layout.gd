extends RefCounted
# CPanelActionQueue873a90/873df0: Current, Queue, then NextLink.
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const RESOURCES=["pnl_actionqueue","ctl_actionqueue","gui_icon_1x1l"]
static func parse(source: Dictionary) -> Dictionary:
	var models: Dictionary={}
	for name in RESOURCES:
		if not source.has(name): return {"error":"Original action queue model missing: "+name}
		models[name]=Geometry.model(source[name])
		if not str(models[name].error).is_empty(): return {"error":str(models[name].error)}
	for name in ["current","queue"]:
		if not models.pnl_actionqueue.hooks.has(name): return {"error":"Original action queue attachment missing: "+name}
	for name in ["icon","nextlink"]:
		if not models.ctl_actionqueue.hooks.has(name): return {"error":"Original queued action attachment missing: "+name}
	return {"error":"","models":models}
static func slot(plan: Dictionary,index: int) -> Dictionary:
	var models: Dictionary=plan.models
	var offset: Vector2=models.pnl_actionqueue.hooks.current if index==0 else models.pnl_actionqueue.hooks.queue+models.ctl_actionqueue.hooks.nextlink*float(index-1)
	var rect: Rect2=models.ctl_actionqueue.bounds; rect.position+=offset
	var icon: Rect2=models.gui_icon_1x1l.bounds; icon.position+=offset+models.ctl_actionqueue.hooks.icon
	return {"resource":"ctl_actionqueue","offset":offset,"rect":rect,"icon":icon}
