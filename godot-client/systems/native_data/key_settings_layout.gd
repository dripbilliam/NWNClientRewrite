extends RefCounted
# Original CKeyMappingPanel and CGuiKeyRadioButton source geometry. This data
# plan is not an installed input router or a visible working settings window.
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
const PANEL_ACTIONS={"xbutton":"0x1408bcce0","tab0":"0x1408bc960","tab1":"0x1408bc960","tab2":"0x1408bc960","tab3":"0x1408bc960"}
const PAGE_ACTIONS={"closebutton":"0x1408bcce0","cancelbutton":"0x1408bc4e0","defaultbutton":"0x1408bc6d0","buttonlist":"0x1408bd0d0"}
static func parse(sources: Dictionary,models: Dictionary) -> Dictionary:
	for name in ["options_key_pnl","options_key_page"]:
		if not sources.has(name): return {"error":"Missing original key-settings GUI: "+name}
	var root: Dictionary=sources.options_key_pnl; var page: Dictionary=sources.options_key_page
	var resource:=str(root.get("Obj_ResRef","")).to_lower(); var page_resource:=str(page.get("Obj_ResRef","")).to_lower()
	for name in [resource,page_resource,"ctl_opt_btn_key"]:
		if name.is_empty() or not models.has(name): return {"error":"Missing original key-settings model: "+name}
	var main:=Geometry.model(models[resource]); var page_model:=Geometry.model(models[page_resource]); var row_model:=Geometry.model(models.ctl_opt_btn_key)
	for value in [main,page_model,row_model]:
		if not str(value.error).is_empty() or not value.drawn: return {"error":"Invalid original key-settings model geometry"}
	if not main.hooks.has("pages"): return {"error":"Missing original key-panel pages attachment"}
	var origin: Vector2=-main.bounds.position; var attachment: Vector2=origin+main.hooks.pages
	var panel_rect: Rect2=main.bounds; panel_rect.position+=origin
	var page_rect: Rect2=page_model.bounds; page_rect.position+=attachment
	var bounds:=panel_rect.merge(page_rect)
	if bounds.position.distance_to(Vector2.ZERO)>0.001: return {"error":"Unsupported negative key-settings page extent"}
	var header:=Gui.elements(root,models,origin); var content:=Gui.elements(page,models,attachment)
	for value in [header,content]:
		if not str(value.error).is_empty(): return value
	for tag in PANEL_ACTIONS.keys()+["tguilabel"]:
		if not header.entries.has(tag): return {"error":"Missing original key-panel control: "+str(tag)}
	for tag in PAGE_ACTIONS:
		if not content.entries.has(tag): return {"error":"Missing original key-page control: "+str(tag)}
	for tag in PANEL_ACTIONS: header.entries[tag].callback=PANEL_ACTIONS[tag]
	for tag in PAGE_ACTIONS: content.entries[tag].callback=PAGE_ACTIONS[tag]
	header.entries.tguilabel.anchor=header.entries.tguilabel.rect.position
	var list: Dictionary=content.entries.buttonlist
	for hook in ["top","bottom","listitem","scrollmin","scrollmax"]:
		if not list.model.hooks.has(hook): return {"error":"Missing original key list hook: "+hook}
	for hook in ["text","label","next"]:
		if not row_model.hooks.has(hook): return {"error":"Missing original key-row hook: "+hook}
	var clip:=Rect2(list.offset+list.model.hooks.top,list.model.hooks.bottom-list.model.hooks.top).abs()
	var first: Vector2=list.offset+list.model.hooks.listitem
	var step: Vector2=row_model.hooks.next
	if clip.size.x<=0 or clip.size.y<=0 or absf(step.x)>0.001 or step.y<=0: return {"error":"Invalid original key-list clip or row progression"}
	# Original label constructor gives vertical1; key InitializeModel sets its
	# horizontal alignment1. Main action text is left/middle from row8bb0c0.
	var row:={"resource":"ctl_opt_btn_key","model":row_model,"rect":row_model.bounds,"step":step,"first":first,"callback":"0x1408bd0d0","text":{"anchor":row_model.hooks.text,"align":Vector2(0,0.5),"font":"fnt_galahad14"},"binding":{"anchor":row_model.hooks.label,"align":Vector2(1,1),"font":"fnt_galahad14"}}
	return {"error":"","size":bounds.size,"resource":resource,"main":{"resource":resource,"rect":panel_rect},"entries":header.entries,"page":{"resource":page_resource,"rect":page_rect,"attachment":attachment,"entries":content.entries},"clip":clip,"row":row,"escape_callback":"0x1408bc9f0","native_data_only":true,"visible_keys_accepted":false,"input_remapping_accepted":false,"full_key_settings_parity":false}
