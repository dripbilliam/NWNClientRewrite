extends RefCounted
# CG_APPEARANCE8eb480: rows come from GFF; arrows/color selectors are
# native programmatic attachments to their MDL button1/button2 hooks.
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const ROWS={"bodybutton":"body","headbutton":"head","tattoobutton":"tattoo","clothingbutton":"clothes","skinbutton":"skin","hairbutton":"hair","tattoocolbutton":"tattoo"}
const BUTTONS={"okbutton":"0x1408e3690","cancelbutton":"0x1408e1080"}
const EXTRA=["ctl_cg_btn_left","ctl_cg_btn_right","ctl_cg_btn_colw","ctl_cg_btn_col","ctl_cg_colr_skin","ctl_cg_colr_hair","ctl_cg_colr_tatt"]
static func attachment(resource:String,offset:Vector2,models:Dictionary)->Dictionary:
	if not models.has(resource):return {"error":"Missing native Appearance attachment: "+resource}
	var shape:=Geometry.model(models[resource])
	if not str(shape.error).is_empty():return shape
	return {"error":"","resource":resource,"model":shape,"offset":offset,"rect":Rect2(offset+shape.bounds.position,shape.bounds.size),"caption":{}}
static func parse(root:Dictionary,models:Dictionary)->Dictionary:
	var result:=Dialog.panel(root,models,["title"],[],BUTTONS,ROWS.keys()+["modelviewer"])
	if not str(result.error).is_empty():return result
	# The shipped file retains a blank, unclaimed TGuiLabel4 far outside the
	# panel. Its editor rectangle must not enlarge/move the actual MDL frame.
	# Keep every source entry, using the native panel model's coordinate owner.
	var main:=Geometry.model(models[result.resource]);var origin:Vector2=-main.bounds.position;var delta:Vector2=origin-result.origin
	for entry in result.entries.values():
		entry.rect.position+=delta
		for key in ["offset","anchor"]:
			if entry.has(key):entry[key]+=delta
		if entry.has("text_rect"):entry.text_rect.position+=delta
	result.size=main.bounds.size;result.origin=origin;result.main=Rect2(main.bounds.position+origin,main.bounds.size)
	# Original8eb480 sets the claimed Title CGuiLabel's bounds flag4 before
	# ImportLayoutData. Its740x30 GFF region owns alignment, not a text anchor.
	result.entries.title.erase("floating");result.entries.title.erase("anchor")
	var controls:Dictionary={}
	for row_tag in ROWS:
		var row:Dictionary=result.entries[row_tag]
		for hook in ["text","button1","button2"]:
			if not row.model.hooks.has(hook):return {"error":"Missing native Appearance row hook: "+row_tag+"/"+hook}
		row.floating=true;row.anchor=row.offset+row.model.hooks.text
		if row_tag in ["bodybutton","headbutton","tattoobutton","clothingbutton"]:
			for side in ["left","right"]:
				var key:String=ROWS[row_tag]+"_"+side;var hook:String="button1" if side=="left" else "button2"
				controls[key]=attachment("ctl_cg_btn_"+side,row.offset+row.model.hooks[hook],models)
		elif row_tag in ["skinbutton","hairbutton"]:
			controls[ROWS[row_tag]]=attachment("ctl_cg_btn_colw",row.offset+row.model.hooks.button1,models)
		else:
			for index in 2:controls["tattoo"+str(index+1)]=attachment("ctl_cg_btn_col",row.offset+row.model.hooks[["button1","button2"][index]],models)
	for entry in controls.values():
		if not str(entry.error).is_empty():return entry
	var boards:Dictionary={}
	for kind in ["skin","hair","tatt"]:
		boards[kind]=attachment("ctl_cg_colr_"+kind,Vector2.ZERO,models)
		if not str(boards[kind].error).is_empty():return boards[kind]
	var viewer:Dictionary=result.entries.modelviewer
	for hook in ["charmodel","charmodeltop"]:
		if not viewer.model.hooks.has(hook):return {"error":"Missing native Appearance preview hook: "+hook}
	result.preview=Rect2(viewer.offset+viewer.model.hooks.charmodel,viewer.model.hooks.charmodeltop-viewer.model.hooks.charmodel).abs()
	result.controls=controls;result.boards=boards
	return result
