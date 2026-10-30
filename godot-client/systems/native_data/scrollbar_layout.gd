extends RefCounted
const Model=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Pose=preload("res://systems/native_data/gui_pose.gd")
static func parse(model: Dictionary,entry: Dictionary,up_model: Dictionary,down_model: Dictionary,thumb_pixels: float=20) -> Dictionary:
	for hook in ["scrollmin","scrollmax"]:
		if not entry.get("model",{}).get("hooks",{}).has(hook): return {"error":"Original edit scrollbar attachment is missing: "+hook}
	var attachment: Vector2=entry.offset+entry.model.hooks.scrollmin
	var target: Vector2=entry.offset+entry.model.hooks.scrollmax
	var size_pixels:=maxf(3.01,float(int(attachment.distance_to(target)+0.5)))
	thumb_pixels=maxf(3.01,float(int(thumb_pixels+0.5)))
	var poses: Array=[{"clip":"size","time":(size_pixels-3.0)/30.0},{"clip":"thumbsize","time":(thumb_pixels-3.0)/30.0}]
	var posed:=Pose.nodes(model,poses)
	if not str(posed.error).is_empty(): return posed
	var geometry:=Model.model(posed.model); var rest:=Model.model(model); var up:=Model.model(up_model); var down:=Model.model(down_model)
	for value in [geometry,rest,up,down]:
		if not str(value.error).is_empty(): return value
	for hook in ["up","down","min","max","thumb"]:
		if not geometry.hooks.has(hook): return {"error":"Original scrollbar hook is missing: "+hook}
	var start: Vector2=geometry.hooks.min; var end: Vector2=geometry.hooks.max
	if absf(start.x-end.x)>0.001 or end.y<=start.y: return {"error":"Original vertical scrollbar endpoints are invalid"}
	var upper: Rect2=up.bounds; upper.position+=geometry.hooks.up
	var lower: Rect2=down.bounds; lower.position+=geometry.hooks.down
	var bounds: Rect2=upper.merge(lower)
	return {"error":"","attachment":attachment,"bounds":bounds,"poses":poses,"hooks":geometry.hooks,"rest_thumb":rest.hooks.thumb,"up":upper,"down":lower,"length":end.y-start.y,"thumb_pixels":thumb_pixels,"travel":maxf(0,end.y-start.y-thumb_pixels),"size_pixels":size_pixels}
static func thumb_offset(plan: Dictionary,value: float,maximum: float) -> Vector2:
	var ratio:=clampf(value/maximum,0.0,1.0) if maximum>0 else 0.0
	return plan.hooks.min-plan.rest_thumb+Vector2(0,float(int(float(plan.travel)*ratio+0.5)))
