extends RefCounted
# CVideoModePanel830160 /832d20. Data and unchanged original float policy;
# this is not yet the visible video-settings owner or a display-mode service.
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
const ACTIONS={"okbutton":"0x14082f8d0","cancelbutton":"0x14082f100","applybutton":"0x14082ef60","xbutton":"0x14082f100","intdownbutton":"0x14082feb0","intupbutton":"0x14082ff20","videomodelist":"0x140832c70"}
const LABELS=["tguilabel","currres","currscale","newres","intlabel","intedit"]
static func elements(root: Dictionary,models: Dictionary,offset: Vector2) -> Dictionary:
	var value:=Gui.elements(root,models,offset)
	if not str(value.error).is_empty(): return value
	for child in root.get("Obj_ChildList",[]):
		if child.get("Obj_ChildList",[]).is_empty(): continue
		var tag:=str(child.get("Obj_Tag","")).to_lower(); var parent: Dictionary=value.entries[tag]
		var nested:=elements(child,models,parent.get("offset",parent.rect.position))
		if not str(nested.error).is_empty(): return nested
		for key in nested.entries:
			if value.entries.has(key): return {"error":"Ambiguous original video control: "+str(key)}
			value.entries[key]=nested.entries[key]
	return value
static func parse(root: Dictionary,models: Dictionary) -> Dictionary:
	var resource:=str(root.get("Obj_ResRef","")).to_lower()
	if resource.is_empty() or not models.has(resource): return {"error":"Original video panel model is missing"}
	var frame:=Geometry.model(models[resource])
	if not str(frame.error).is_empty() or not frame.drawn: return {"error":"Original video panel bounds are unavailable"}
	var controls:=elements(root,models,-frame.bounds.position)
	if not str(controls.error).is_empty(): return controls
	for tag in ACTIONS.keys()+LABELS:
		if not controls.entries.has(tag): return {"error":"Missing original video control: "+str(tag)}
	for tag in ACTIONS: controls.entries[tag].callback=ACTIONS[tag]
	controls.entries.videomodelist.initial_enabled=false
	for tag in ["currres","currscale","newres","intlabel","intedit"]: controls.entries[tag].runtime_class="CGuiCharGenLabel"
	# Despite its name IntEdit is an original label, not a text-entry field.
	# The initializer gives callbacks only to the adjacent timer arrows.
	controls.entries.intedit.editable=false
	for tag in ["tguilabel","currres","currscale","newres","intedit"]:
		var entry: Dictionary=controls.entries[tag]; entry.floating=true; entry.anchor=entry.rect.position
	return {"error":"","resource":resource,"size":frame.bounds.size,"main":{"resource":resource,"rect":Rect2(Vector2.ZERO,frame.bounds.size)},"entries":controls.entries,"native_data_only":true,"visible_video_accepted":false,"display_mode_changes_accepted":false,"full_video_parity":false}
static func f(value: float) -> float: return Vector2(value,0).x
static func display_modes(source: Array) -> Array:
	# Original GetVideoModes0f6e30 skips dimensions below800x600 and removes
	# duplicate formatted strings. SDL supplies dimensions/depth/refresh in
	# descending order; Windows enumeration itself does not have that order.
	var sorted: Array=source.duplicate(); sorted.sort_custom(func(a,b):
		for key in ["width","height","depth","refresh"]:
			if int(a.get(key,0))!=int(b.get(key,0)): return int(a.get(key,0))>int(b.get(key,0))
		return false)
	var result: Array=[]; var seen: Dictionary={}
	for row in sorted:
		if int(row.width)<800 or int(row.height)<600: continue
		var label:="%dx%d %dhz"%[row.width,row.height,row.refresh]
		if seen.has(label): continue
		var value: Dictionary=row.duplicate(); value.label=label; result.append(value); seen[label]=true
	return result
static func desired_scale(width: int,height: int,unconstrained: bool=false) -> float:
	if unconstrained: return 4.0
	var available:=minf(f(f(width)/900.0),f(f(height)/700.0))
	# The binary executes fmodf with its stored0.1f, then SUBSS. Replacing
	# this with floor(value*10)/10 changes exact multiples and boundary pixels.
	return maxf(1.0,f(available-f(fmod(available,f(0.1)))))
static func scale_step(value: float,increase: bool,minimum: float,maximum: float) -> float:
	var result:=f(f(value)+f(0.1)) if increase else f(f(value)-f(0.1))
	if f(maximum)<result: return f(maximum)
	return f(minimum) if result<f(minimum) else result
static func fixed_override(value: float,maximum: float) -> float:
	return 0.0 if absf(f(f(value)-f(maximum)))<0.09 else f(value)
static func scale_update(width: int,height: int,fixed: float,previous: float,unconstrained: bool=false) -> Dictionary:
	var maximum:=desired_scale(width,height,unconstrained)
	var value:=maximum if f(fixed)==0.0 else minf(f(fixed),maximum)
	value=maxf(1.0,value)
	return {"maximum":maximum,"scale":value,"gui_to_pixel":f(f(0.01)/value),"refresh_fonts":absf(f(f(previous)-value))>=0.09}
