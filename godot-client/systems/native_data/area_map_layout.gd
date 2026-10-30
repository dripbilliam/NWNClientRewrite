extends RefCounted
# Original CPanelAreaMap894720/893030/892010. Data plan only; no UI/protocol owner.
const Model=preload("res://systems/native_data/inventory_equipment_layout.gd")
const M=preload("res://systems/native_render/particle_math.gd")
const PIXELS=[8,16,32]
const ICONS=["ctl_icon_minimap","ctl_icon_areamap","gui_icon_0x0l"]
const TOOLS={"pinbutton":"ctl_map_pinsrc","upbutton":"ctl_map_zoomin","downbutton":"ctl_map_zoomout","xbutton":"ctl_btn_x"}
const TOOLTIPS={"pinbutton":0x10807,"upbutton":0x10808,"downbutton":0x10809}
static func frame(width: int,height: int,level: int,caps: Vector2i) -> Dictionary:
	if width<1 or height<1 or width>1024 or height>1024 or level<0 or level>=PIXELS.size() or caps.x<1 or caps.y<1: return {"error":"Invalid original map frame input"}
	var pixels: int=PIXELS[level]
	var columns:=maxi(4,mini(caps.x,(width*pixels+8)/16)); var rows:=maxi(2,mini(caps.y,(height*pixels+8)/16))
	return {"error":"","resource":"pnl_mapgen_%dx%d"%[columns,rows],"columns":columns,"rows":rows,"pixels":pixels,"icon":ICONS[level],"zoom_in":level<2,"zoom_out":level>0}
static func local_to_world(width: int,height: int,pixels: int,local: Array) -> Array:
	if width<1 or height<1 or pixels not in PIXELS or local.size()!=3: return []
	for value in local:
		if not is_finite(float(value)): return []
	var unit:=M.f(M.f(float(pixels))*M.f(0.01))
	var x:=M.f(M.f(M.f(M.f(float(width))*unit)*M.f(0.5))+M.f(local[0]))
	var y:=M.f(M.f(M.f(M.f(float(height))*unit)*M.f(0.5))+M.f(local[1]))
	x=M.f(x*M.f(10)); y=M.f(y*M.f(10)); var z:=M.f(M.f(local[2])*M.f(10)); var inverse:=M.f(M.f(1)/unit)
	return [M.f(x*inverse),M.f(y*inverse),M.f(z*inverse)]
static func parse(definition: Dictionary,source: Dictionary) -> Dictionary:
	if not str(definition.get("error","")).is_empty(): return definition
	var name:=str(definition.get("resource","")); var models: Dictionary={}
	for resource in [name]+TOOLS.values():
		if not source.has(resource): return {"error":"Missing original area map model: "+resource}
		models[resource]=Model.model(source[resource])
		if not str(models[resource].error).is_empty(): return models[resource]
	var main: Dictionary=models[name]
	if not main.drawn: return {"error":"Original map frame has no artwork bounds"}
	for hook in TOOLS.keys()+["mapcenter","viewport0","viewport1","horizontalindicator","verticalindicator"]:
		if not main.hooks.has(hook): return {"error":"Missing original area map attachment: "+hook}
	var origin: Vector2=-main.bounds.position; var entries: Dictionary={}
	for hook in TOOLS:
		var resource: String=TOOLS[hook]; var model: Dictionary=models[resource]; var offset: Vector2=origin+main.hooks[hook]
		entries[hook]={"resource":resource,"model":model,"offset":offset,"rect":Rect2(offset+model.bounds.position,model.bounds.size),"tooltip":int(TOOLTIPS.get(hook,-1))}
	var viewport:=Rect2(origin+main.hooks.viewport0,main.hooks.viewport1-main.hooks.viewport0).abs()
	if viewport.size.x<=0 or viewport.size.y<=0: return {"error":"Invalid original map viewport"}
	return {"error":"","resource":name,"model":main,"origin":origin,"size":main.bounds.size,"viewport":viewport,"center":origin+main.hooks.mapcenter,"controls":entries,"horizontal":origin+main.hooks.horizontalindicator,"vertical":origin+main.hooks.verticalindicator,"full_map_parity":false}
