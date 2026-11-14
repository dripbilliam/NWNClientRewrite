extends Node
# Presentation over the existing server-backed record owner. No record requests,
# local level changes or rule definitions are invented by this frame.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/character_sheet_layout.gd")
const Text=preload("res://systems/server_text.gd")
const Entry=preload("res://systems/record_entry.gd")
const Bar=preload("res://systems/native_scrollbar.gd")
const PAGE_FOOTER_INSET:=11.0 # In-game CPanelCharSheet resize callback14088aa90.
var panel
var frame
var text_owner
var assets
var models: Dictionary={}
var jobs: Dictionary={}
var definition: Dictionary={}
var stage: Control
var page_root: Control
var bars: Array=[]
var requested:=false
var layout_ready:=false
var closed:=false
var failure:=""
var labels: Dictionary={}
var footer: Button
var window_height:=468.0
var resizing:=false
var resize_start:=Vector2.ZERO
var resizable_scrolls: Dictionary={}
var background_height:=2048.0
var selected_entry:=-1
var image_requests: Dictionary={}
var icon_catalog
var ui_assets
var icon_warm_targets: Array=[]
var prewarmed_page_keys: Array=[]
func configure(target,catalog,cache_path: String,text,painter) -> void:
	panel=target; panel.native_skin=self; frame=painter; text_owner=text; icon_catalog=catalog; ui_assets=catalog.ui_asset_owner()
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	panel.visibility_changed.connect(func():if not panel.visible: stop_resize())
	for name in Plan.RESOURCES:
		var id: int=assets.request(name,2002,"actor-model" if name=="scrollbar_simple" else "mdl-original")
		if id<0: failure=str(assets.failure); return
		jobs[id]=name
	if frame.fonts.has_method("request"):
		for font in ["fnt_galahad14","ttf fnt_default 14"]: frame.fonts.request(font)
	for ability in ["str","dex","con","int","wis","cha"]:
		var icon:=TextureRect.new(); add_child(icon); icon.hide(); icon_warm_targets.append(icon); frame.art.bind(icon,"gui_chrsht_"+ability)
func _process(_delta: float) -> void:
	if closed: return
	if panel.wanted and not requested: requested=true
	if panel.wanted and not panel.visible:
		if failure.is_empty(): failure=art_failure()
		panel.present_if_ready()
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	models[name]=result.value
	if not jobs.is_empty() or not failure.is_empty(): return
	definition=Plan.parse(models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	activate()
func sheet_buttons() -> Array:
	var result: Array=[panel.close_button,panel.level_button,footer]+panel.tabs+panel.entry_nodes.values()
	for bar in bars:
		if is_instance_valid(bar): result.append_array([bar.up,bar.down])
	return result
func current_icon_bindings() -> Dictionary:
	var bindings: Dictionary={}
	if panel.state.is_empty(): return bindings
	if panel.page==0:
		for row in panel.state.model.get("abilities",[]): bindings["ability:"+str(row.key)]="gui_chrsht_"+str(row.key).to_lower()
	else:
		for row in panel.state.get("entries",[]):
			var name:=str(row.get("icon","")).to_lower()
			if not name.is_empty() and name!="****": bindings["entry:"+str(int(row.entryId))]=name
	return bindings
func current_icon_names() -> Array: return current_icon_bindings().values()
func art_failure() -> String:
	var font_failures: Variant=frame.fonts.get("failed")
	if font_failures is Dictionary:
		for name in ["fnt_galahad14","ttf fnt_default 14"]:
			if font_failures.has(name): return "Original character-sheet font could not be prepared: "+name
	for key in prewarmed_page_keys:
		if frame.art.failed.has(key): return "Original character-sheet page could not be prepared: "+str(key)
	for data in image_requests.values():
		var target: Object=data.target.get_ref()
		if is_instance_valid(target) and not target.is_queued_for_deletion() and frame.art.failed.has(data.key): return "Original character-sheet artwork could not be prepared: "+str(data.key)
	for button in sheet_buttons():
		if not is_instance_valid(button) or button.is_queued_for_deletion(): continue
		var geometry: Dictionary=frame.button_geometry.get(button.get_instance_id(),{})
		for style in geometry.get("styles",{}).values():
			var key: String=frame.art.models.model_key(str(geometry.resource),str(style[1]),geometry.overrides)
			if frame.art.failed.has(key): return "Original character-sheet control could not be prepared: "+key
	for bar in bars:
		if is_instance_valid(bar) and not bar.failure.is_empty(): return "Original character-sheet scrollbar could not be prepared: "+bar.failure
	if frame.art.get("ui_assets")!=null:
		for name in current_icon_bindings().values():
			if icon_catalog.raster_location(name).is_empty(): return "Original character-sheet icon is missing: "+name
			var reason: String=ui_assets.failure("raster",name)
			if not reason.is_empty(): return "Original character-sheet icon could not be prepared: "+name+": "+reason
	return ""
func display_ready() -> bool:
	if closed or not failure.is_empty() or not layout_ready or panel.state.is_empty(): return false
	if frame.fonts.has_method("request"):
		for name in ["fnt_galahad14","ttf fnt_default 14"]:
			if not frame.fonts.fonts.has(name): return false
	for key in prewarmed_page_keys:
		if not frame.art.textures.has(key): return false
	for data in image_requests.values():
		var target: Object=data.target.get_ref()
		if is_instance_valid(target) and not target.is_queued_for_deletion() and not frame.art.textures.has(data.key): return false
	for button in sheet_buttons():
		if not is_instance_valid(button) or button.is_queued_for_deletion(): continue
		var geometry: Dictionary=frame.button_geometry.get(button.get_instance_id(),{})
		if geometry.is_empty(): return false
		for style in geometry.styles.values():
			if not frame.art.textures.has(frame.art.models.model_key(str(geometry.resource),str(style[1]),geometry.overrides)): return false
	for bar in bars:
		if not is_instance_valid(bar) or not bar.art_ready: return false
	if frame.art.get("ui_assets")!=null:
		var icon_bindings:=current_icon_bindings()
		for target_key in icon_bindings:
			var name: String=icon_bindings[target_key]
			var target: Object=panel.image_nodes.get(target_key)
			if not is_instance_valid(target): return false
			var retained: Dictionary=ui_assets.lookup("raster",name)
			if retained.is_empty() or target.texture!=retained.texture: return false
	return true
func control(parent: Control,rect: Rect2=Rect2()) -> Control:
	var target:=Control.new(); parent.add_child(target); target.mouse_filter=Control.MOUSE_FILTER_IGNORE; target.position=rect.position; target.size=rect.size; return target
func image(name: String,parent: Control,rect: Rect2,layer: String="",region: Rect2=Rect2()) -> TextureRect:
	var target:=TextureRect.new(); parent.add_child(target); target.mouse_filter=Control.MOUSE_FILTER_IGNORE; target.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; target.stretch_mode=TextureRect.STRETCH_SCALE; target.position=rect.position; target.size=rect.size
	var key: String=frame.art.models.model_key(name,"",{},0,layer,[],region)
	image_requests[target.get_instance_id()]={"target":weakref(target),"key":key}
	var id:=target.get_instance_id(); target.tree_exiting.connect(func():image_requests.erase(id),CONNECT_ONE_SHOT)
	if layer.is_empty(): frame.art.bind(target,name,"texture",true,"",false,{},region)
	else:
		key=frame.art.request_model(name,"",{},0,layer,[],region)
		if frame.art.textures.has(key): target.texture=frame.art.textures[key]
		else:
			var weak: WeakRef=weakref(target)
			var callback: Callable=func(loaded_key: String,texture: Texture2D,_bounds: Dictionary):
				var live: Object=weak.get_ref()
				if loaded_key==key and is_instance_valid(live) and not live.is_queued_for_deletion(): live.texture=texture
			frame.art.loaded.connect(callback)
			target.tree_exiting.connect(func():if is_instance_valid(frame) and is_instance_valid(frame.art) and frame.art.loaded.is_connected(callback): frame.art.loaded.disconnect(callback),CONNECT_ONE_SHOT)
	return target
func activate() -> void:
	for name in ["pnl_chrsht_char","pnl_chrsht_skils"]:
		prewarmed_page_keys.append(frame.art.request_model(name,"",{},0,"gui_boxes_ingame",[],Rect2(0,0,definition.size.x,background_height)))
	prewarmed_page_keys.append(frame.art.request_model("pnl_chrsht_char","",{},0,"gui_shield",[],Rect2(3,211,32,32)))
	layout_ready=true; panel.window_column.hide(); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); panel.custom_minimum_size=definition.size; panel.size=definition.size
	window_height=definition.size.y
	stage=control(panel,Rect2(Vector2.ZERO,definition.size)); stage.clip_contents=true
	image("pnl_chrsht",stage,definition.models.pnl_chrsht.bounds)
	frame.label(panel.heading,{"rect":definition.title,"caption":Plan.CAPTION},stage); panel.heading.mouse_filter=Control.MOUSE_FILTER_STOP
	frame.button(panel.close_button,definition.close,stage,models,false)
	var group:=ButtonGroup.new()
	for index in 3:
		var button: Button=panel.tabs[index]; frame.button(button,definition.tabs[index],stage,models,false,true); button.toggle_mode=true
		button.button_group=group
		button.tooltip_text=text_owner.raw({"strRef":[0x2940,0x147,0x146][index]})
	footer=frame.create_button(definition.footer,stage,models); footer.gui_input.connect(footer_input)
	var level_entry:=Plan.entry(definition.models,"ctl_chrsht_lvlup",definition.page_origin+definition.models.pnl_chrsht_char.hooks.levelupbutton)
	frame.button(panel.level_button,level_entry,stage,models,false); frame.button_caption(panel.level_button,text_owner.raw({"strRef":0x209a}))
	page_root=control(stage,Rect2(definition.page_origin,definition.page_size)); page_root.clip_contents=true
	# Header/tab artwork remains above the page, which starts below their hooks.
	stage.move_child(page_root,0)
	panel.notice.hide()
	panel.custom_minimum_size.y=definition.page_origin.y+definition.footer.rect.size.y
	if not panel.settings_path.is_empty():
		var config:=ConfigFile.new()
		if config.load(panel.settings_path)==OK and config.has_section_key("sizes",panel.layout_key):
			var stored: Variant=config.get_value("sizes",panel.layout_key,null)
			if stored is Vector2 and stored.is_finite(): window_height=stored.y
	set_height(window_height)
	if not panel.state.is_empty(): panel.render()
func clear_page() -> void:
	selected_entry=-1
	for bar in bars: if is_instance_valid(bar): bar.close()
	bars.clear(); labels.clear(); resizable_scrolls.clear()
	if is_instance_valid(page_root):
		for child in page_root.get_children(): page_root.remove_child(child); child.queue_free()
func label(key: String,value: String,rect: Rect2,parent: Control,caption: Dictionary=Plan.CAPTION) -> Label:
	var target: Label=frame.create_label({"rect":rect,"caption":caption},parent); target.text=value; labels[key]=target; return target
func picture(key: String,rect: Rect2,parent: Control) -> TextureRect:
	var target:=TextureRect.new(); parent.add_child(target); target.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; target.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; target.mouse_filter=Control.MOUSE_FILTER_IGNORE; target.position=rect.position; target.size=rect.size; panel.image_nodes[key]=target; return target
func scroll(key: String,resource: String,parent: Control,offset: Vector2,font: String,height: float=-1) -> ScrollContainer:
	var model: Dictionary=definition.models[resource].duplicate(true)
	if height>0:
		model.hooks.text1.y=height; model.hooks.scrollmax.y=height-14
	var rect:=Plan.box(model,"text0","text1",offset)
	var target: ScrollContainer=panel.scroll_box(key,Vector2.ZERO); parent.add_child(target); target.position=rect.position; target.size=rect.size; target.size_flags_horizontal=Control.SIZE_FILL; target.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	var bar:=Bar.new(); parent.add_child(bar); bar.configure(frame,models,{"offset":offset,"model":model,"caption":{"AurString_Font":font}},target,20); bars.append(bar)
	if height>=0: resizable_scrolls[key]={"scroll":target,"bar":bar,"entry":{"offset":offset,"model":model,"caption":{"AurString_Font":font}},"bottom":"text1"}
	return target
func render() -> void:
	if closed or not layout_ready: return
	panel.set_caption(str(panel.state.model.get("name","—"))); panel.notice.hide()
	for index in 3: panel.tabs[index].disabled=false; panel.tabs[index].set_pressed_no_signal(index==panel.page)
	var background: String="pnl_chrsht_char" if panel.page==0 else "pnl_chrsht_skils"
	image(background,page_root,Rect2(0,0,definition.size.x,background_height),"gui_boxes_ingame",Rect2(0,0,definition.size.x,background_height))
	if panel.page==0: statistics()
	else: entries()
	panel.level_button.visible=panel.page==0 and panel.wanted and bool(panel.state.get("canLevelUp",false))
func statistics() -> void:
	var model: Dictionary=panel.state.model; var layout: Dictionary=definition.models.pnl_chrsht_char
	picture("portrait",Rect2(1,0,128,200),page_root)
	# The shield is a separate original texture layer; never stretch the tall page.
	image("pnl_chrsht_char",page_root,Rect2(3,211,32,32),"gui_shield",Rect2(3,211,32,32))
	var lines: String=str(model.get("race",""))+", "+str(model.get("alignment",""))+"\n"
	for item in model.get("classes",[]): lines+=str(item)+"\n"
	label("race",lines,Plan.box(layout,"racealignclass0","racealignclass1"),page_root)
	var names: Dictionary={"STR":["strength",0x87],"DEX":["dexterity",0x85],"CON":["constitution",0x84],"INT":["intelligence",0x86],"WIS":["wisdom",0x88],"CHA":["charisma",0x83]}
	for row in model.get("abilities",[]):
		var key:=str(row.key).to_upper()
		if not names.has(key): continue
		var prefix:=key.to_lower(); var long_name: String=names[key][0]
		label(prefix+"label",text_owner.raw({"strRef":names[key][1]}),Plan.box(layout,"l"+long_name+"0","l"+long_name+"1"),page_root)
		for field in ["score","modifier"]:
			var hook: String=prefix+("stat" if field=="score" else "mod")
			var target:=label(prefix+field,panel.value(row.get(field)),Plan.box(layout,hook+"0",hook+"1"),page_root)
			var adjustment: int=int(row.get("adjustment" if field=="score" else "modifierAdjustment",0))
			if adjustment!=0: target.add_theme_color_override("font_color",preload("res://systems/native_data/character_record_values.gd").tone(adjustment))
		picture("ability:"+str(row.key),Rect2(layout.hooks[prefix+"icon"]-Vector2(8,8),Vector2(16,16)),page_root)
	for pair in [["armorclass",panel.value(model.get("armorClass"))],["hitpoints",panel.value(model.get("currentHP"))+"/"+panel.value(model.get("maximumHP"))],["lac",text_owner.raw({"strRef":0x141})],["lhp",text_owner.raw({"strRef":0x140})],["experience",str(model.get("labels",{}).get("experience","Experience"))+": "+panel.value(model.get("experience"))],["nextlevel",str(model.get("labels",{}).get("nextLevel","Next level"))+": "+panel.value(model.get("nextExperience"))]]:
		label(pair[0],pair[1],Plan.box(layout,pair[0]+"0",pair[0]+"1"),page_root)
	var details:=scroll("details","ctl_chrsht_lstbx",page_root,layout.hooks.list,"ttf fnt_default 14",maxf(1,page_root.size.y-layout.hooks.list.y-PAGE_FOOTER_INSET))
	var text:=Text.label({},details.size.x); details.add_child(text); text.custom_minimum_size.x=details.size.x; text.size_flags_horizontal=Control.SIZE_EXPAND_FILL; frame.font_style(text,{"AurString_Font":"ttf fnt_default 14"})
	var spans: Array=[]
	for row in model.get("details",[]):
		if not spans.is_empty(): spans.append({"text":"\n"})
		if str(row.get("label","")).length()>0: spans.append({"text":str(row.label).strip_edges().trim_suffix(":")+": "})
		spans.append_array(row.get("parts",[{"text":panel.value(row.get("value"))}]))
	Text.set_text(text,{"spans":spans})
func entries() -> void:
	var layout: Dictionary=definition.models.pnl_chrsht_skils
	var description:=scroll("description","ctl_chrsht_desc",page_root,layout.hooks.description,"fnt_galahad14")
	panel.description=Text.label({},description.size.x); description.add_child(panel.description); panel.description.custom_minimum_size.x=description.size.x; panel.description.size_flags_horizontal=Control.SIZE_EXPAND_FILL; frame.font_style(panel.description,Plan.CAPTION)
	# List item positions are supplied by the original list and linked icon model.
	var list_model: Dictionary=definition.models.ctl_chr_btnlstbx
	var viewport_rect:=Plan.box(list_model,"top","bottom")
	var list: ScrollContainer=panel.scroll_box("entries",Vector2.ZERO); page_root.add_child(list); list.position=layout.hooks.list+viewport_rect.position; list.size=Vector2(viewport_rect.size.x,maxf(1,page_root.size.y-layout.hooks.list.y-PAGE_FOOTER_INSET)); list.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	var resource: String="ctl_chr_btn_skil" if panel.page==1 else "ctl_chr_btn_feat"; var row_model: Dictionary=definition.models[resource]
	var bar:=Bar.new(); page_root.add_child(bar); var bar_model: Dictionary=list_model.duplicate(true); bar_model.hooks.bottom.y=list.size.y; bar_model.hooks.scrollmax.y=list.size.y-14; var bar_entry:={"offset":layout.hooks.list,"model":bar_model,"caption":{}}; bar.configure(frame,models,bar_entry,list,row_model.hooks.next.y); bars.append(bar)
	resizable_scrolls.entries={"scroll":list,"bar":bar,"entry":bar_entry,"bottom":"bottom"}
	var rows:=Control.new(); list.add_child(rows); var origin: Vector2=list_model.hooks.listitem; var group:=ButtonGroup.new()
	rows.custom_minimum_size=Vector2(list.size.x,maxf(0,origin.y+row_model.bounds.position.y+panel.state.get("entries",[]).size()*row_model.hooks.next.y))
	for row in panel.state.get("entries",[]):
		var button:=Entry.new(); button.setup(panel,row); rows.add_child(button)
		for child in button.get_children(): child.hide()
		frame.button(button,Plan.entry(definition.models,resource,origin),rows,models,false,true); button.toggle_mode=true; button.button_group=group
		var local: Vector2=-row_model.bounds.position
		var icon:=picture("entry:"+str(int(row.entryId)),Rect2(local+row_model.hooks.icon-Vector2(16,16),Vector2(32,32)),button); button.image=icon
		label("entry:"+str(row.entryId),str(row.name),Rect2(local+row_model.hooks.text-Vector2(0,17),Vector2(250 if panel.page==1 else 280,34)),button,{"AurString_Font":"fnt_galahad14","AurString_AlignH":0.0,"AurString_AlignV":0.5})
		if row.has("value"): label("value:"+str(row.entryId),str(int(row.value)),Rect2(local+row_model.hooks.value-Vector2(16,17),Vector2(33,34)),button)
		panel.entry_nodes[int(row.entryId)]=button
		if int(row.id)==int(panel.selected.get(str(panel.page),-1)): panel.select_entry(int(row.entryId))
		origin+=row_model.hooks.next
func select_entry(id: int) -> void:
	if selected_entry!=id and panel.entry_nodes.has(selected_entry):
		var prior: Button=panel.entry_nodes[selected_entry]; prior.modulate=Color.WHITE
		if prior.button_pressed: prior.set_pressed_no_signal(false)
	if panel.entry_nodes.has(id):
		var button: Button=panel.entry_nodes[id]; button.modulate=Color.WHITE
		if not button.button_pressed: button.set_pressed_no_signal(true)
		selected_entry=id
func footer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			resizing=true; resize_start=Vector2(local_pointer(event.global_position).y,window_height); panel.move_to_front()
		else: stop_resize()
		footer.accept_event()
func local_pointer(point: Vector2) -> Vector2:
	return panel.get_global_transform_with_canvas().affine_inverse()*point
func _input(event: InputEvent) -> void:
	if not resizing or closed: return
	if event is InputEventMouseMotion:
		if not event.button_mask&MOUSE_BUTTON_MASK_LEFT: stop_resize(); return
		set_height(resize_start.y+local_pointer(event.position).y-resize_start.x); get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		# Let the captured Button receive its release and retire its pressed state.
		stop_resize()
func set_height(value: float) -> void:
	if closed or not layout_ready or not is_finite(value): return
	var minimum: float=definition.page_origin.y+definition.footer.rect.size.y
	var unit_scale:=maxf(0.001,panel.get_global_transform_with_canvas().get_scale().y)
	var maximum:=maxf(minimum,(panel.get_viewport_rect().size.y-panel.global_position.y)/unit_scale)
	window_height=clampf(roundf(value),minimum,maximum); panel.size=Vector2(definition.size.x,window_height); stage.size=panel.size; page_root.size=Vector2(definition.size.x,maxf(0,window_height-definition.page_origin.y))
	var data: Dictionary=frame.button_geometry[footer.get_instance_id()]; data.offset=definition.footer.offset+Vector2(0,window_height-definition.size.y); data.rect=definition.footer.rect; data.rect.position.y+=window_height-definition.size.y; frame.update_button(footer.get_instance_id())
	for key in resizable_scrolls:
		var view: Dictionary=resizable_scrolls[key]; var entry: Dictionary=view.entry; var bottom: float=window_height-definition.page_origin.y-entry.offset.y-PAGE_FOOTER_INSET
		entry.model.hooks[view.bottom].y=bottom; entry.model.hooks.scrollmax.y=bottom-14
		view.scroll.size.y=maxf(1,window_height-definition.page_origin.y-view.scroll.position.y-PAGE_FOOTER_INSET); view.bar.relayout(entry)
	panel._clamp()
func stop_resize() -> void:
	if not resizing: return
	resizing=false
	if is_instance_valid(panel) and not panel.settings_path.is_empty():
		var config:=ConfigFile.new(); config.load(panel.settings_path); config.set_value("sizes",panel.layout_key,Vector2(definition.size.x,window_height)); config.save(panel.settings_path)
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: stop_resize()
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"requested":requested,"failure":failure,"pending":jobs.size(),"native_only":true,"original_frame":layout_ready,"size":[panel.size.x,panel.size.y] if is_instance_valid(panel) else [],"resizing":resizing,"bars":bars.map(func(bar):return bar.snapshot()),"full_character_sheet_parity":false}
func close() -> void:
	if closed: return
	stop_resize(); closed=true; clear_page()
	for target in icon_warm_targets:
		if is_instance_valid(frame) and is_instance_valid(frame.art): frame.art.unbind(target)
		if is_instance_valid(target): target.queue_free()
	icon_warm_targets.clear(); image_requests.clear()
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(panel): panel.native_skin=null
	jobs.clear(); models.clear(); panel=null; frame=null; text_owner=null
func _exit_tree() -> void: close()
