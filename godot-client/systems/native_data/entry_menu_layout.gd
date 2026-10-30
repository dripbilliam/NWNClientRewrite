extends RefCounted
# Original CMainMenuPanel714140, COptionsPanel830b50 and
# CPregameOptionsPanel8be9f0. Layout/action metadata, not a visible menu owner.
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
const MENUS={
	"pre_main":{"buttons":{"newbutton":"0x140711400","loadbutton":"0x140710b40","multibutton":"0x140710fd0","moviesbutton":"0x140710e40","optionsbutton":"0x140711c50","exitbutton":"0x1407105b0","reponewsbutton":"0x140712200"},"labels":[],"caption_refs":{}},
	"pre_multiplayer":{"buttons":{"newbutton":"0x140711570","loadbutton":"0x140710c30","intjoinbutton":"0x1407107e0","lanjoinbutton":"0x140710840","dirconnectbutton":"0x140710480","cancelbutton":"0x14070f740"},"labels":[],"caption_refs":{}},
	"options_main":{"buttons":{"exitbutton":"0x14082f330","videooptionsbutton":"0x14082ff90","soundoptionsbutton":"0x14082fe80","controlsbutton":"0x14082f2b0","gamebutton":"0x14082f4b0","resumegamebutton":"0x14082fb00","xbutton":"0x140830150","loadbutton":"0x14082f7e0","savebutton":"0x14082fb10","savecharbutton":"0x14082fb60"},"labels":["tguilabel","buildnumber"],"caption_refs":{"videooptionsbutton":0x1baf,"controlsbutton":0x28ad,"savecharbutton":0x19a0}},
	"options_pregame":{"buttons":{"videooptsbutton":"0x1408bd240","gamebutton":"0x1408bc710","soundbutton":"0x1408bd230","controlbutton":"0x1408bc670","nwsyncbutton":"0x1408bca70","closebutton":"0x1408bc640","xbutton":"0x1408bc640"},"labels":["tguilabel","buildnumber"],"caption_refs":{"videooptsbutton":0x1baf,"controlbutton":0x28ad}}
}
static func parse(kind: String,root: Dictionary,models: Dictionary) -> Dictionary:
	if not MENUS.has(kind): return {"error":"Unknown original entry-menu layout: "+kind}
	var resource:=str(root.get("Obj_ResRef","")).to_lower()
	if resource.is_empty() or not models.has(resource): return {"error":"Missing original entry-menu frame: "+resource}
	var main:=Geometry.model(models[resource])
	if not str(main.error).is_empty(): return main
	if not main.drawn or main.bounds.size.x<=0 or main.bounds.size.y<=0: return {"error":"Original entry-menu frame has no usable artwork bounds"}
	var controls:=Gui.elements(root,models,Vector2.ZERO)
	if not str(controls.error).is_empty(): return controls
	# PRE_MAIN's model bounds cover its decorative logo, not the button
	# column below it. A container sized only to that mesh clips real controls.
	var total: Rect2=main.bounds
	for tag in controls.entries:
		var entry: Dictionary=controls.entries[tag]
		if tag in MENUS[kind].labels:
			# These CGuiLabels have no bounded-text flag4. LoadGffData ignores
			# their stored Width/Height; alignment is relative to Label_X/Y.
			entry.floating=true; entry.anchor=entry.rect.position; total=total.expand(entry.anchor)
		else: total=total.merge(entry.rect)
	var origin: Vector2=-total.position
	for entry in controls.entries.values():
		entry.rect.position+=origin
		if entry.has("offset"): entry.offset+=origin
		if entry.has("anchor"): entry.anchor+=origin
	var source: Dictionary=MENUS[kind]
	for tag in source.buttons:
		if not controls.entries.has(tag): return {"error":"Missing original entry-menu action: "+tag}
		var entry: Dictionary=controls.entries[tag]
		if not entry.has("resource"): return {"error":"Original entry-menu action has no button model: "+tag}
		entry.callback=source.buttons[tag]
		# Keep the stored GUI caption and runtime replacement separate. The
		# current client changes these after ImportLayoutData; GUI-only is wrong.
		entry.source_caption=entry.caption.duplicate(true)
		if source.caption_refs.has(tag):
			entry.caption=entry.caption.duplicate(true); entry.caption.Obj_StrRef=source.caption_refs[tag]
	for tag in source.labels:
		if not controls.entries.has(tag): return {"error":"Missing original entry-menu label: "+tag}
	if kind=="options_pregame": controls.entries.nwsyncbutton.runtime_text="Storage"
	if kind in ["options_main","options_pregame"]:
		var sound: String="soundoptionsbutton" if kind=="options_main" else "soundbutton"
		controls.entries[sound].model_deleted_after_init=true
		# DeleteModel is observed; exact remaining caption/hit presentation
		# requires original-client comparison. Do not infer hidden/disabled.
		controls.entries.buildnumber.runtime_text_kind="build-version"
		controls.entries.buildnumber.runtime_color=Color(0.4,0.4,0.4,1)
	var root_point:=Vector2(float(root.get("Obj_X",0)),-float(root.get("Obj_Y",0)))*100.0
	if not root_point.is_finite(): return {"error":"Invalid original entry-menu root placement"}
	return {"error":"","kind":kind,"resource":resource,"size":total.size,"origin":origin,"source_bounds":total,"root_point":root_point,"main":{"resource":resource,"rect":Rect2(main.bounds.position+origin,main.bounds.size),"offset":origin,"model":main},"entries":controls.entries,"native_data_only":true,"visible_menu_accepted":false,"full_entry_menu_parity":false}

static func main_enabled(nwsync_ready: bool,dm: bool,client_server_mode: bool) -> Dictionary:
	#714140 initially disables all seven.717b00 waits for NWSync, then
	#70e7f0 enables them and applies the original DM/client-server gates.
	var result: Dictionary={}
	for tag in MENUS.pre_main.buttons: result[tag]=nwsync_ready
	for tag in ["newbutton","loadbutton"]: result[tag]=nwsync_ready and not dm and not client_server_mode
	return result

static func main_state(nwsync_ready: bool,dm: bool,client_server_mode: bool) -> Dictionary:
	var enabled:=main_enabled(nwsync_ready,dm,client_server_mode); var colors: Dictionary={}
	for tag in enabled: colors[tag]=Color.WHITE if enabled[tag] else Color(0.5,0.5,0.5,1)
	var replacements: Array=[]
	if nwsync_ready and dm: replacements=[["gui_pre_bknd1","DM_Load1"],["gui_pre_bknd2","DM_Load2"]]
	return {"enabled":enabled,"colors":colors,"replacements":replacements}

static func local_save_load_allowed(client_server_mode: bool,connected: bool,app_server_present: bool,localhost: bool,client_field5a4: bool) -> bool:
	#6ac430 ->6daa40. A loopback address alone does not grant host Save/Load.
	return not client_server_mode and connected and app_server_present and localhost and client_field5a4

static func options_enabled(kind: String,sound_disabled: bool,local_save_load: bool) -> Dictionary:
	if kind not in ["options_main","options_pregame"]: return {}
	var result: Dictionary={}
	for tag in MENUS[kind].buttons: result[tag]=true
	result["soundoptionsbutton" if kind=="options_main" else "soundbutton"]=not sound_disabled
	if kind=="options_main":
		result.loadbutton=local_save_load; result.savebutton=local_save_load
	return result
