extends RefCounted
# CCharacterInfoPanel8e8df0/8ecc60. Source GFF controls and MDL text hooks.
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const BUTTONS={"okbutton":"0x1408e4230","cancelbutton":"0x1408e1140","randombutton":"0x1408e5be0","deitybutton":"0x1408e2640"}
const LABELS=["title","agelabel","firstnamelabel","lastnamelabel","soundsetlabel"]
const EDITS=["firstnameedit","lastnameedit","ageedit"]
const EXTRA=["ctl_cg_btn_snds","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
static func parse(root:Dictionary,models:Dictionary)->Dictionary:
	var result:=Dialog.panel(root,models,LABELS,EDITS,BUTTONS,["descedit","soundsetedit"])
	if not str(result.error).is_empty():return result
	# Original8e8df0 explicitly enables bounded Title layout. The other
	# claimed labels keep their independently verified source anchor behavior.
	result.entries.title.erase("floating");result.entries.title.erase("anchor")
	for resource in EXTRA:
		if not models.has(resource):return {"error":"Original Character Information attachment is missing: "+resource}
	var row:=Geometry.model(models.ctl_cg_btn_snds)
	if not str(row.error).is_empty():return row
	for hook in ["text0","text1","next"]:
		if not row.hooks.has(hook):return {"error":"Original voice row hook is missing: "+hook}
	#8dcbc0 fixes the native font/vertical alignment;8ecc60 sets horizontal0.
	#8850c0 attaches to 'text' first, otherwise the model's text0/text1 bounds.
	var voice_caption:Dictionary={"caption":{"AurString_Font":"fnt_galahad14","AurString_AlignH":0.0,"AurString_AlignV":0.5}}
	if row.hooks.has("text"):
		voice_caption.anchor=row.hooks.text-row.bounds.position;voice_caption.rect=Rect2(voice_caption.anchor,Vector2.ONE);voice_caption.floating=true
	else:voice_caption.rect=Rect2(row.hooks.text0-row.bounds.position,row.hooks.text1-row.hooks.text0).abs()
	for tag in ["descedit","soundsetedit"]:
		var entry:Dictionary=result.entries[tag]
		for hook in ["text0","text1","scrollmin","scrollmax"]:
			if not entry.model.hooks.has(hook):return {"error":"Original information scroll hook is missing: "+tag+"/"+hook}
		result[tag+"_body"]=Rect2(entry.offset+entry.model.hooks.text0,entry.model.hooks.text1-entry.model.hooks.text0).abs()
	result.voice_row=row
	result.voice_caption=voice_caption
	return result
