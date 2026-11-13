extends RefCounted
# Original CG_SPELLS9cd040. The two claimed CGuiLabels use a blank model's
# text attachment rather than a mesh rectangle; no generic control is changed.
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Choice=preload("res://systems/native_data/creation_choice_layout.gd")
const BUTTONS={"okbutton":"0x1409c90d0","cancelbutton":"0x1409c7de0","recommendbutton":"0x1409c9df0","resetbutton":"0x1409ca770"}
const ICONS=["ir_cantrips","ir_level1","ir_level2","ir_level3","ir_level4","ir_level5","ir_level6","ir_level789","ir_level789","ir_level789"]
static func flatten(root: Dictionary,models: Dictionary,offset: Vector2,entries: Dictionary) -> String:
	for child in root.get("Obj_ChildList",[]):
		var tag:=str(child.get("Obj_Tag","")).to_lower()
		if entries.has(tag):return "Ambiguous original Spells control: "+tag
		if tag in ["emptyspelllistlabel","cannotlearn"]:
			var name:=str(child.get("Obj_ResRef","")).to_lower()
			if not models.has(name):return "Missing original spell label model: "+name
			var model:=Geometry.model(models[name])
			if not model.hooks.has("text"):return "Missing original spell label text hook: "+tag
			var point: Vector2=offset+Vector2(float(child.get("Obj_X",0)),-float(child.get("Obj_Y",0)))*100.0+model.hooks.text
			entries[tag]={"rect":Rect2(point,Vector2.ZERO),"anchor":point,"floating":true,"caption":child.get("Obj_Caption",{})}
		else:
			var parsed:=Gui.elements({"Obj_ChildList":[child]},models,offset)
			if not str(parsed.error).is_empty():return str(parsed.error)
			entries[tag]=parsed.entries[tag]
		if not child.get("Obj_ChildList",[]).is_empty():
			var error:=flatten(child,models,entries[tag].get("offset",entries[tag].rect.position),entries)
			if not error.is_empty():return error
	return ""
static func parse(source: Dictionary,models: Dictionary) -> Dictionary:
	var resource:=str(source.get("Obj_ResRef","")).to_lower()
	if not models.has(resource):return {"error":"Original Spells frame is missing"}
	var main:=Geometry.model(models[resource]);var entries: Dictionary={};var error:=flatten(source,models,Vector2.ZERO,entries)
	if not error.is_empty():return {"error":error}
	if not str(main.error).is_empty() or not main.drawn:return {"error":"Original Spells frame geometry is unavailable"}
	var required:=BUTTONS.keys()+["title","remainlabel","tguilabel1","availbox","knownbox","availtitle","knowntitle","emptyspelllistlabel","cannotlearn"]
	for level in 10:required.append("spelllevel"+str(level))
	for tag in required:
		if not entries.has(tag):return {"error":"Original Spells control is missing: "+tag}
	var origin: Vector2=-main.bounds.position
	for tag in entries:
		var entry: Dictionary=entries[tag];entry.rect.position+=origin
		if entry.has("offset"):entry.offset+=origin
		if entry.has("anchor"):entry.anchor+=origin
		if BUTTONS.has(tag):entry.callback=BUTTONS[tag]
		if str(tag).begins_with("spelllevel"):entry.callback="0x1409caae0"
		if tag=="tguilabel1":entry.floating=true;entry.anchor=entry.rect.position
	var lists: Dictionary={}
	for tag in ["availbox","knownbox"]:
		for hook in ["top","bottom","listitem","scrollmin","scrollmax"]:
			if not entries[tag].model.hooks.has(hook):return {"error":"Original Spells list hook is missing: "+tag+"/"+hook}
		lists[tag]=Choice.box(entries[tag],"top","bottom")
	for name in ["ctl_cg_btn_feat","ctl_cg_btn_left","ctl_cg_btn_right","ctl_cg_btn_help","scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name):return {"error":"Original Spells helper is missing: "+name}
	var row:=Geometry.model(models.ctl_cg_btn_feat)
	for hook in ["text0","text1","icon","next","addremovebutton","helpbutton"]:
		if not row.hooks.has(hook):return {"error":"Original Spells row hook is missing: "+hook}
	return {"error":"","resource":resource,"main":Rect2(Vector2.ZERO,main.bounds.size),"size":main.bounds.size,"origin":origin,"entries":entries,"row":row,"lists":lists}
