extends Node
# Presentation only. Original GUI/MDL geometry and server-owned inventory state.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/store_layout.gd")
const Text=preload("res://systems/server_text.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
var owner_inventory
var assets
var layouts: Dictionary={}
var models: Dictionary={}
var jobs: Dictionary={}
var definition: Dictionary={}
var failure:=""
var layout_ready:=false
var requested:=false
var closed:=false
var panel
var stage: Control
var modal: Control
var confirmation_scroll: ScrollContainer
var confirmation_bar
var identify_caption: Label
var frame
var hovered_item:=-1
func configure(owner,catalog,cache_path: String) -> void:
	owner_inventory=owner; frame=owner.frame_skin; owner.ui.native_store=self
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	for name in ["ingame_store","buysell_confirm"]: jobs[assets.request(name,2047,"gff")]={"kind":"gui","name":name}
func collect(root: Dictionary) -> void:
	if root.has("Obj_ResRef"): models[str(root.Obj_ResRef).to_lower()]={}
	for child in root.get("Obj_ChildList",[]): collect(child)
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var job: Dictionary=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=str(result.error); return
	if job.kind=="gui":
		if result.value.get("type","")!="GUI ": failure="Invalid original merchant GUI signature"; return
		layouts[job.name]=result.value.root
	else: models[job.name]=result.value
	if layouts.size()==2 and not requested:
		requested=true
		for root in layouts.values(): collect(root)
		for index in 5: models["ctl_inv_sto_tab"+str(index+1)]={}
		for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]: models[name]={}
		for name in models: jobs[assets.request(name,2002,"actor-model" if name=="scrollbar_simple" else "mdl-original")]={"kind":"model","name":name}
	if not jobs.is_empty() or layouts.size()!=2 or not failure.is_empty(): return
	definition=Plan.parse(layouts,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	layout_ready=true
	if is_instance_valid(owner_inventory.ui.store_panel): attach(owner_inventory.ui.store_panel)
func attach(target) -> void:
	if closed: return
	panel=target; panel.native_skin=self
	if not layout_ready or is_instance_valid(stage): return
	panel.window_column.hide(); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); panel.custom_minimum_size=definition.size; panel.size=definition.size
	stage=Control.new(); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.add_child(stage); stage.size=definition.size
	frame.image(definition.resource,Rect2(Vector2.ZERO,definition.size),stage)
	var entries: Dictionary=definition.entries
	frame.label(panel.heading,entries.title,stage); panel.heading.mouse_filter=Control.MOUSE_FILTER_STOP
	panel.heading.text=owner_inventory.text_owner.raw({"strRef":int(entries.title.caption.Obj_StrRef)})
	frame.button(panel.close_button,entries.xbutton,stage,models,false)
	frame.image(entries.scrollpagelabel.resource,entries.scrollpagelabel.rect,stage); frame.label(panel.pager,entries.scrollpagelabel,stage)
	frame.button(panel.previous,entries.scrollup,stage,models,false); panel.previous.tooltip_text="Previous merchant page"
	frame.button(panel.next,entries.scrolldown,stage,models,false); panel.next.tooltip_text="Next merchant page"
	frame.button(panel.examine,entries.examinebutton,stage,models,false); panel.examine.toggle_mode=true; panel.examine.tooltip_text="Examine an item"
	for index in 5:
		frame.button(panel.tabs[index],definition.tabs[index],stage,models,false,true); panel.tabs[index].toggle_mode=true
	frame.image(entries.invbox.resource,entries.invbox.rect,stage); frame.configure_repository(panel.repository,definition.grid,stage)
	# Empty labels retain hover information without adding modern framing.
	frame.label(panel.gold,entries.iteminfo,stage); panel.gold.text=""
	panel.selection.reparent(panel.get_parent(),false); panel.selection.mouse_filter=Control.MOUSE_FILTER_STOP
	modal=Control.new(); panel.selection.add_child(modal); modal.mouse_filter=Control.MOUSE_FILTER_IGNORE; modal.custom_minimum_size=definition.confirm.size
	frame.image(definition.confirm.resource,Rect2(Vector2.ZERO,definition.confirm.size),modal)
	var controls: Dictionary=definition.confirm.entries
	if controls.itemdesc.model.drawn: frame.image(controls.itemdesc.resource,controls.itemdesc.rect,modal)
	confirmation_scroll=ScrollContainer.new(); modal.add_child(confirmation_scroll); frame.relocate(confirmation_scroll,modal,controls.itemdesc.rect)
	confirmation_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; confirmation_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	panel.prompt.reparent(confirmation_scroll,false); panel.prompt.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); panel.prompt.custom_minimum_size=Vector2(controls.itemdesc.rect.size.x,0)
	panel.prompt.fit_content=true; panel.prompt.scroll_active=false; panel.prompt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; panel.prompt.add_theme_font_size_override("normal_font_size",14)
	confirmation_bar=preload("res://systems/native_scrollbar.gd").new(); modal.add_child(confirmation_bar); confirmation_bar.configure(frame,models,controls.itemdesc,confirmation_scroll,14)
	panel.prompt.add_theme_color_override("font_shadow_color",Color.BLACK); panel.prompt.add_theme_constant_override("shadow_offset_x",1); panel.prompt.add_theme_constant_override("shadow_offset_y",1); panel.prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.font_style(panel.prompt,controls.itemdesc.caption)
	frame.button(panel.confirm,controls.okbutton,modal,models,false); frame.button_caption(panel.confirm,owner_inventory.text_owner.raw({"strRef":int(controls.okbutton.caption.Obj_StrRef)}))
	frame.button(panel.cancel_button,controls.cancelbutton,modal,models,false); frame.button_caption(panel.cancel_button,owner_inventory.text_owner.raw({"strRef":int(controls.cancelbutton.caption.Obj_StrRef)}))
	# Identify remains available until the native examine window owns its action.
	var identify_entry: Dictionary=controls.okbutton.duplicate(); var old_position: Vector2=identify_entry.rect.position
	identify_entry.rect.position=Vector2((definition.confirm.size.x-identify_entry.rect.size.x)*0.5,definition.confirm.size.y+4); identify_entry.offset+=identify_entry.rect.position-old_position
	frame.button(panel.identify,identify_entry,modal,models,false); identify_caption=frame.button_caption(panel.identify,"")
	for child in panel.selection.get_children():
		if child!=modal: child.hide()
	panel.selection.custom_minimum_size=definition.confirm.size; panel.selection.reset_size(); panel.selection.size=definition.confirm.size; panel.selection.hide()
	panel.render(owner_inventory.store_view())
func built() -> bool: return not closed and layout_ready and is_instance_valid(stage)
func render(store: Dictionary) -> void:
	if not built(): return
	panel.size=definition.size; stage.size=definition.size
	for index in 5:
		panel.tabs[index].text=""; panel.tabs[index].tooltip_text=owner_inventory.text_owner.raw({"strRef":0xf85c+index})
		panel.tabs[index].set_pressed_no_signal(int(store.get("panel",0))==index); panel.tabs[index].disabled=store.get("navigationPending",false)
	panel.pager.text="%s %d/%d"%[owner_inventory.text_owner.raw({"strRef":0xf85c+int(store.get("panel",0))}),int(store.get("page",0))+1,maxi(1,int(store.get("pageCount",1)))]
	if hovered_item>=0 and panel.inventory.items.has(hovered_item): hover_item(hovered_item)
	else: panel.gold.text=""
	panel.examine.text=""; panel.examine.set_pressed_no_signal(panel.inventory.examine_mode)
	if panel.selection.visible: selection_changed(false)
func hover_item(id: int) -> void:
	if not built() or not panel.inventory.items.has(id): return
	hovered_item=id; var row: Dictionary=panel.inventory.items[id]; var name:=str(row.name)
	if name.length()>33: name=name.left(33)+"..."
	panel.gold.text=Rich.parse(owner_inventory.text_owner.resolve({"strRef":0xf0b4},owner_inventory.controlled_id,{"localCustomTokens":{0:name,1:str(int(row.price))}})).text
	panel.gold.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func clear_hover(id: int) -> void:
	if built() and hovered_item==id: hovered_item=-1; panel.gold.text=""
func selection_changed(center: bool=true) -> void:
	if not built(): return
	var id: int=panel.entry()
	if id>=0:
		var row: Dictionary=panel.inventory.items[id]
		var original: String=owner_inventory.text_owner.resolve({"strRef":0xf0b4 if row.channel=="M" else 0xf0b3},owner_inventory.controlled_id,{"localCustomTokens":{0:str(row.name),1:str(int(row.price))}})
		Text.set_text(panel.prompt,Rich.parse(original))
		confirmation_scroll.scroll_vertical=0
	if not panel.identify.text.is_empty(): identify_caption.text=panel.identify.text
	panel.identify.text=""; panel.confirm.text=""
	if is_instance_valid(owner_inventory.examine_owner) and owner_inventory.examine_owner.layout_ready: panel.identify.hide()
	if center: panel.selection.position=(panel.get_viewport_rect().size-definition.confirm.size)*0.5
	panel.selection.move_to_front()
func selection_blocks(point: Vector2) -> bool:
	return built() and panel.selection.visible and (panel.selection.get_global_rect().has_point(point) or panel.identify.visible and panel.identify.get_global_rect().has_point(point))
func snapshot() -> Dictionary: return {"ready":layout_ready,"active":built(),"failure":failure,"native_only":true,"grid":[10,10],"cell":33,"confirmation_scrollbar":confirmation_bar.snapshot() if is_instance_valid(confirmation_bar) else {},"confirmation_text_parity":true,"full_store_parity":false}
func close() -> void:
	if closed: return
	closed=true; assets.close(); owner_inventory.ui.native_store=null
	if is_instance_valid(confirmation_bar): confirmation_bar.close()
	if is_instance_valid(panel): panel.native_skin=null
	jobs.clear(); layouts.clear(); models.clear()
func _exit_tree() -> void: close()
