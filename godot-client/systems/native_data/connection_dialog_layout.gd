extends RefCounted
# CServerIPPanel8c3460 ->8d44d0 ->8d1000. Original resource placement,
# CGuiPregameLabel's unbounded anchors and CGuiEditSingleLine text hooks.
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const BUTTONS={"okbutton":"0x1408d1000","cancelbutton":"0x1408cdec0","xbutton":"0x1408cdec0"}
const LABELS=["tguilabel","passwordlabel","tguilabel2"]
const EDITS=["ipeditbox","passwordeditbox"]
static func parse(root: Dictionary,models: Dictionary) -> Dictionary:
	return panel(root,models,LABELS,EDITS,BUTTONS)
static func flatten(root: Dictionary,models: Dictionary,offset: Vector2,entries: Dictionary) -> String:
	var parsed:=Gui.elements(root,models,offset)
	if not str(parsed.error).is_empty(): return str(parsed.error)
	for child in root.get("Obj_ChildList",[]):
		var tag:=str(child.get("Obj_Tag","")).to_lower()
		if entries.has(tag): return "Ambiguous original connection control: "+tag
		entries[tag]=parsed.entries[tag]
		if not child.get("Obj_ChildList",[]).is_empty():
			var error:=flatten(child,models,entries[tag].get("offset",entries[tag].rect.position),entries)
			if not error.is_empty(): return error
	return ""
static func panel(root: Dictionary,models: Dictionary,labels: Array,edits: Array,callbacks: Dictionary,required: Array=[]) -> Dictionary:
	var resource:=str(root.get("Obj_ResRef","")).to_lower()
	if resource.is_empty() or not models.has(resource): return {"error":"Missing original connection frame"}
	var main:=Geometry.model(models[resource])
	if not str(main.error).is_empty(): return main
	if not main.drawn: return {"error":"Original connection frame has no artwork"}
	var entries: Dictionary={}; var error:=flatten(root,models,Vector2.ZERO,entries)
	if not error.is_empty(): return {"error":error}
	for tag in callbacks.keys()+labels+edits+required:
		if not entries.has(tag): return {"error":"Original connection control missing: "+tag}
	var total: Rect2=main.bounds
	for tag in entries:
		var entry: Dictionary=entries[tag]
		if tag in labels:
			entry.floating=true; entry.anchor=entry.rect.position; total=total.expand(entry.anchor)
		else: total=total.merge(entry.rect)
		if tag in edits:
			if not entry.model.hooks.has("text0") or not entry.model.hooks.has("text1"): return {"error":"Original connection edit hooks missing: "+tag}
			entry.text_rect=Rect2(entry.offset+entry.model.hooks.text0,entry.model.hooks.text1-entry.model.hooks.text0).abs()
			if entry.text_rect.size.x<=0 or entry.text_rect.size.y<=0: return {"error":"Invalid original connection edit bounds: "+tag}
		if callbacks.has(tag): entry.callback=callbacks[tag]
	var origin: Vector2=-total.position
	for entry in entries.values():
		entry.rect.position+=origin
		if entry.has("offset"): entry.offset+=origin
		if entry.has("anchor"): entry.anchor+=origin
		if entry.has("text_rect"): entry.text_rect.position+=origin
	return {"error":"","resource":resource,"size":total.size,"origin":origin,"main":Rect2(main.bounds.position+origin,main.bounds.size),"entries":entries,"full_connection_ui_parity":false}

static func endpoint(address: String) -> Dictionary:
	# Original706e40 takes the first colon, parses the suffix with CRT atoi,
	# stores its low16 bits, and uses5121 if the parsed32-bit port is zero.
	# Hostname/IP validation and session authorization remain the service's job.
	var split:=address.find(":"); var host:=address if split<0 else address.left(split)
	var port:=0
	if split>=0:
		var suffix:=address.substr(split+1)
		if suffix.length()>1: port=preload("res://systems/native_data/amount_dialog.gd").decimal(suffix)
	return {"host":host,"port":5121 if port==0 else port&65535}
