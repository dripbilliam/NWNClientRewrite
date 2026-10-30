extends RefCounted
const Shared=preload("res://systems/native_data/connection_dialog_layout.gd")
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const BUTTONS={"closebutton":"0x1408ce020","connectbutton":"0x1408ce150","nextbutton":"0x1408d0a50","prevbutton":"0x1408d15f0"}
const FIELDS={"servernameedit":"serverName","moduleedit":"moduleName","numplayersedit":"playerCount","maxplayersedit":"maximumPlayers","minleveledit":"minimumLevel","maxleveledit":"maximumLevel","ipedit":"endpoint","pvpedit":"pvpSetting","serverversionedit":"serverVersion","syncedit":"syncAvailable","gametypeedit":"gameType"}
const CHECKS={"pausecheckbox":"pauseAndPlay","passwordcheckbox":"passwordRequired","onepartycheckbox":"onePartyOnly","itemcheckbox":"itemLevelRestrictions","legalcharcheck":"enforceLegalCharacters","allowlocalbox":"allowLocalVaultCharacters"}
static func flatten(root: Dictionary,models: Dictionary,offset: Vector2,entries: Dictionary,labels: Array,path: String="root") -> String:
	var parsed:=Gui.elements(root,models,offset)
	if not str(parsed.error).is_empty(): return str(parsed.error)
	for index in root.get("Obj_ChildList",[]).size():
		var child: Dictionary=root.Obj_ChildList[index]; var tag:=str(child.get("Obj_Tag","")).to_lower(); var entry: Dictionary=parsed.entries[tag]
		# SRV_SRVDETAILS reuses LegalCharCheck for the checkbox and its nested
		# label. Preserve both source identities; do not silently drop either.
		if int(child.get("Obj_Type",-1))==5:
			entry.tag=tag; entry.path=path+"/"+str(index)
			#8d4090 explicitly sets the bounded flag only on Title. PasswordLabel
			# is imported without it; the remaining labels are emitted by
			# CloseLayoutFile1fdbb0 with unbounded strings. Preserve source anchors.
			entry.floating=tag!="title"; entry.anchor=entry.rect.position; labels.append(entry)
		else:
			if entries.has(tag): return "Ambiguous original server-detail action: "+tag
			entries[tag]=entry
		var error:=flatten(child,models,entry.get("offset",entry.rect.position),entries,labels,path+"/"+str(index))
		if not error.is_empty(): return error
	return ""
static func parse(root: Dictionary,models: Dictionary) -> Dictionary:
	var resource:=str(root.get("Obj_ResRef","")).to_lower()
	if not models.has(resource): return {"error":"Missing original server-details frame"}
	var main:=Geometry.model(models[resource])
	if not str(main.error).is_empty() or not main.drawn: return {"error":"Invalid original server-details frame geometry"}
	var entries: Dictionary={}; var labels: Array=[]; var error:=flatten(root,models,-main.bounds.position,entries,labels)
	if not error.is_empty(): return {"error":error}
	for tag in BUTTONS.keys()+FIELDS.keys()+CHECKS.keys()+["desceditbox"]:
		if not entries.has(tag): return {"error":"Missing original server-details control: "+tag}
		var entry: Dictionary=entries[tag]
		if BUTTONS.has(tag): entry.callback=BUTTONS[tag]
		if CHECKS.has(tag): entry.disabled_checked_state=true
		if FIELDS.has(tag) or tag=="desceditbox":
			if not entry.model.hooks.has("text0") or not entry.model.hooks.has("text1"): return {"error":"Missing original server-detail text hooks: "+tag}
			entry.text_rect=Rect2(entry.offset+entry.model.hooks.text0,entry.model.hooks.text1-entry.model.hooks.text0).abs()
	return {"error":"","resource":resource,"size":main.bounds.size,"main":Rect2(Vector2.ZERO,main.bounds.size),"entries":entries,"labels":labels,"native_only":true,"full_details_parity":false}
