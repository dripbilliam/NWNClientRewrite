extends "res://systems/native_gui_painter.gd"
const Assets=preload("res://systems/native_data/asset_service.gd")
const Layout=preload("res://systems/native_data/inventory_frame_layout.gd")
var inventory
var text_owner
var equipment
var assets
var jobs: Dictionary={}
var layouts: Dictionary={}
var definition: Dictionary={}
var models_requested:=false
var layout_ready:=false
var failure:=""
var stage: Control
var container_stage: Control
var container_drag: Control
var full: TextureRect
var top: TextureRect
var bottom: TextureRect
var gap: ColorRect
var gold_button: Button
var repository_image: TextureRect
var labels: Dictionary={}
var split_texture: Texture2D
var extra:=0.0
var last_notice:=""
func configure(owner,catalog,cache_path: String,text,skin) -> void:
	inventory=owner; text_owner=text; equipment=skin; art=skin.art
	configure_fonts(catalog,cache_path); set_process(true)
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	for name in ["inv_panel","inv_container"]: jobs[assets.request(name,2047,"gff")]={"kind":"layout","name":name}
func fail(reason: String) -> void:
	if failure.is_empty(): failure=reason
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var job: Dictionary=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): fail(str(result.error)); return
	if job.kind=="layout":
		if str(result.value.get("type",""))!="GUI ": fail("Original inventory layout has an invalid GFF signature"); return
		layouts[job.name]=result.value.root
	else: models[job.name]=result.value
	if layouts.size()==2 and not models_requested:
		models_requested=true
		var names: Dictionary={"inv_box_10x6":true,"ctl_inv_btn_tab":true}
		for layout in layouts.values():
			names[str(layout.Obj_ResRef).to_lower()]=true
			for child in layout.get("Obj_ChildList",[]):
				if child.has("Obj_ResRef"): names[str(child.Obj_ResRef).to_lower()]=true
		for name in names:
			var requested: int=assets.request(name,2002,"mdl-original")
			if requested<0: fail(assets.failure); return
			jobs[requested]={"kind":"model","name":name}
	if not jobs.is_empty() or layouts.size()!=2 or not failure.is_empty(): return
	definition=Layout.parse(layouts,models)
	if not str(definition.error).is_empty(): fail(str(definition.error)); return
	activate()
func _process(_delta: float) -> void:
	if closed: return
	if not layout_ready:
		if not definition.is_empty() and failure.is_empty() and equipment.layout_ready: activate()
		return
	if full.texture!=null and full.texture!=split_texture: split_background()
	if not inventory.visible: return
	if inventory.notice.text!=last_notice: update_notice()
func activate() -> void:
	if layout_ready or closed or definition.is_empty() or not equipment.layout_ready: return
	layout_ready=true; inventory.window_column.hide(); inventory.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	stage=Control.new(); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; inventory.add_child(stage)
	full=image(str(definition.resource),Rect2(Vector2.ZERO,definition.size),stage)
	gap=ColorRect.new(); gap.color=Color.BLACK; gap.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(gap)
	top=TextureRect.new(); bottom=TextureRect.new()
	for control in [top,bottom]: control.mouse_filter=Control.MOUSE_FILTER_IGNORE; control.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; stage.add_child(control); control.hide()
	var title: Dictionary=equipment.definition.labels.get("tguilabel",{})
	if not title.is_empty():
		var rect: Rect2=title.rect; rect.position+=definition.equipment; label(inventory.heading,{"rect":rect,"caption":title.caption},stage)
	else: label(inventory.heading,{"rect":Rect2(8,0,320,17)},stage)
	inventory.heading.mouse_filter=Control.MOUSE_FILTER_STOP
	button(inventory.close_button,definition.entries.xbutton,stage); inventory.close_button.tooltip_text="Close inventory"
	button(inventory.item_controls.examine,definition.entries.inspectbutton,stage); inventory.item_controls.examine.toggle_mode=true; inventory.item_controls.examine.tooltip_text="Examine an item"
	gold_button=Button.new(); stage.add_child(gold_button); button(gold_button,definition.entries.goldbutton,stage)
	gold_button.tooltip_text="Transfer gold"; gold_button.pressed.connect(func(): inventory.gold_owner.open())
	for name in ["gplabel","weightlabel","maxweightlabel","tguilabel"]:
		if not definition.entries.has(name): continue
		var control:=Label.new(); stage.add_child(control); label(control,definition.entries[name],stage); labels[name]=control
		var caption: Dictionary=definition.entries[name].get("caption",{})
		control.text=text_owner.raw({"strRef":int(caption.get("Obj_StrRef",4294967295))})
	for index in 6:
		button(inventory.pages[index],{"resource":"ctl_inv_btn_tab","rect":definition.tabs[index]},stage); inventory.pages[index].tooltip_text="Backpack page "+str(index+1)
	inventory.equipment.reparent(stage,false); inventory.equipment.custom_minimum_size.x=0
	repository_image=image("inv_box_10x6",definition.repository.art,stage)
	configure_repository(inventory.repository,definition.repository,stage)
	container_stage=Control.new(); container_stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(container_stage)
	image(str(definition.container.resource),definition.container.rect,container_stage)
	var controls: Dictionary=definition.container.entries
	image(str(controls.itemgrid.resource),controls.itemgrid.rect,container_stage)
	image(str(controls.label.resource),controls.label.rect,container_stage)
	configure_repository(inventory.container_repository,definition.container.grid,container_stage)
	label(inventory.container_title,controls.title,container_stage); label(inventory.container_page,controls.label,container_stage)
	button(inventory.container_controls.previous,controls.leftbutton,container_stage); inventory.container_controls.previous.tooltip_text="Previous container page"
	button(inventory.container_controls.next,controls.rightbutton,container_stage); inventory.container_controls.next.tooltip_text="Next container page"
	button(inventory.container_controls.close,controls.closebutton,container_stage); button_caption(inventory.container_controls.close,text_owner.raw({"strRef":71}))
	var close:=Button.new(); container_stage.add_child(close); button(close,controls.xbutton,container_stage); close.tooltip_text="Close inventory"; close.pressed.connect(inventory.close_inventory)
	container_drag=Control.new(); container_stage.add_child(container_drag); container_drag.mouse_filter=Control.MOUSE_FILTER_STOP
	container_drag.position=controls.title.rect.position; container_drag.size=Vector2(maxf(controls.title.rect.size.x,controls.xbutton.rect.position.x-controls.title.rect.position.x),controls.title.rect.size.y)
	container_drag.gui_input.connect(inventory._title_input)
	inventory.notice.reparent(stage,false); inventory.notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	inventory.notice.add_theme_color_override("font_shadow_color",Color.BLACK); inventory.notice.add_theme_constant_override("shadow_offset_x",1); inventory.notice.add_theme_constant_override("shadow_offset_y",1)
	if not inventory.state.is_empty(): inventory.render()
func configure_repository(repository,data: Dictionary,parent: Control) -> void:
	relocate(repository,parent,data.rect); repository.cell_size=Layout.CELL; repository.bottom_origin=true; repository.native_art=true; repository.clip_contents=true; repository.queue_redraw()
func split_background() -> void:
	split_texture=full.texture
	var cut:=roundi(float(definition.split)/float(definition.size.y)*split_texture.get_height())
	var upper:=AtlasTexture.new(); upper.atlas=split_texture; upper.region=Rect2(0,0,split_texture.get_width(),cut); top.texture=upper
	var lower:=AtlasTexture.new(); lower.atlas=split_texture; lower.region=Rect2(0,cut,split_texture.get_width(),split_texture.get_height()-cut); bottom.texture=lower
func shift(rect: Rect2) -> Rect2:
	if rect.position.y>=float(definition.split)-0.01: rect.position.y+=extra
	return rect
func refresh() -> void:
	if not layout_ready or inventory.state.is_empty(): return
	var opened:=int(inventory.state.get("container",{}).get("ownerId",2130706432))!=2130706432
	extra=80.0 if inventory.creature_slots and not opened else 0.0
	var size: Vector2=definition.size+Vector2(0,extra); stage.custom_minimum_size=size; inventory.custom_minimum_size=size; inventory.size=size
	inventory.equipment.position=definition.equipment-equipment.origin(); inventory.equipment.size=equipment.definition.bounds.size+Vector2(0,extra); inventory.equipment.visible=not opened
	inventory.heading.visible=not opened; inventory.container_box.hide(); container_stage.visible=opened
	var rect:=shift(definition.repository.rect); inventory.repository.position=rect.position; inventory.repository.size=rect.size
	repository_image.position=shift(definition.repository.art).position
	for index in 6:
		var control: Button=inventory.pages[index]; control.position=shift(button_geometry[control.get_instance_id()].rect).position
	for name in labels: labels[name].position=shift(definition.entries[name].rect).position
	for control in [inventory.item_controls.examine,gold_button]: control.position=shift(button_geometry[control.get_instance_id()].rect).position
	var summary: Dictionary=inventory.state.summary
	gold_button.disabled=not is_instance_valid(inventory.gold_owner) or not inventory.gold_owner.layout_ready or summary.gold==null or int(summary.gold)<=0
	var container: Dictionary=inventory.state.get("container",{})
	inventory.container_page.text="%02d/%02d"%[int(container.get("page",0))+1,maxi(1,int(container.get("pageCount",1)))]
	var caption: Dictionary=definition.container.entries.title.get("caption",{}); var ref:=int(caption.get("Obj_StrRef",4294967295))
	if ref>=0 and ref!=4294967295: inventory.container_title.text=text_owner.raw({"strRef":ref})
	container_drag.tooltip_text=str(container.get("title",""))
	labels.gplabel.text="GP: "+(str(int(summary.gold)) if summary.gold!=null else "—")
	labels.weightlabel.text=str(int(summary.weight)) if summary.weight!=null else "—"; labels.maxweightlabel.text=str(int(summary.capacity)) if summary.capacity!=null else "—"
	full.visible=extra==0; top.visible=extra>0; bottom.visible=extra>0; gap.visible=extra>0
	top.position=Vector2.ZERO; top.size=Vector2(size.x,float(definition.split)); bottom.position=Vector2(0,float(definition.split)+extra); bottom.size=Vector2(size.x,float(definition.size.y)-float(definition.split))
	gap.position=Vector2(0,float(definition.split)); gap.size=Vector2(size.x,extra)
	inventory.notice.position=Vector2(0,size.y+4); inventory.notice.custom_minimum_size=Vector2(size.x,0); inventory.notice.size=Vector2(size.x,30); update_notice()
	inventory.item_controls.examine.set_pressed_no_signal(inventory.examine_mode)
func update_notice() -> void:
	last_notice=inventory.notice.text
	inventory.notice.visible=not last_notice.is_empty() and not last_notice.begins_with("Double-click:") and not last_notice.begins_with("Click or drag")
func decorate_item(button,repository,item: Dictionary) -> void:
	if not layout_ready or not repository.bottom_origin: return
	var width:=maxi(1,int(item.width)); var height:=maxi(1,int(item.height)); var center:=Layout.icon_center(0,0,width,height)
	button.native_icon_center=Vector2(center.x,height*Layout.CELL-center.y); button.add_theme_stylebox_override("normal",StyleBoxEmpty.new()); button.add_theme_stylebox_override("pressed",StyleBoxEmpty.new()); button.refresh_icon()
func snapshot() -> Dictionary:
	var buttons: Array=[]
	for data in button_geometry.values():
		var control: Button=data.control
		buttons.append({"resource":data.resource,"rect":str(data.rect),"actual_size":str(control.size),"normal_texture_size":str(control.get_theme_stylebox("normal").texture.get_size()) if control.get_theme_stylebox("normal").texture!=null else "pending","drawn":data.get("drawn",{})})
	return {"ready":layout_ready,"failure":failure,"fonts":fonts.snapshot() if is_instance_valid(fonts) else {},"size":[inventory.size.x,inventory.size.y] if is_instance_valid(inventory) else [],"buttons":buttons,"grid_cell":Layout.CELL,"bottom_origin":true,"gold_transfer_connected":true,"scope":"Original inventory/container frames, hooks, tabs, labels,33px bottom-origin item placement and typed actions. Exact fonts/hover/counts and full mixed-client UI parity remain pending"}
func close() -> void:
	if closed: return
	layout_ready=false
	if is_instance_valid(assets): assets.close()
	jobs.clear(); inventory=null; equipment=null; text_owner=null
	super.close()
