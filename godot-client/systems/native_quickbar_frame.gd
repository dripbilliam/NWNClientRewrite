extends Node
# Original model geometry over existing typed quickbar actions and private drops.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/quickbar_layout.gd")
var panel
var frame
var text_owner
var assets
var models: Dictionary={}
var jobs: Dictionary={}
var definition: Dictionary={}
var stage: Control
var endcaps: TextureRect
var requested:=false
var layout_ready:=false
var closed:=false
var failure:=""
var keys: Dictionary={}
var art_keys: Array=[]
var art_prewarm_sealed:=false
var resident_icons: Dictionary={}
var current_icons: Dictionary={}
func configure(target,catalog,cache_path: String,text,painter) -> void:
	panel=target; panel.native_skin=self; frame=painter; text_owner=text
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	panel.rendered.connect(render); frame.art.loaded.connect(art_loaded)
	frame.fonts.loaded.connect(font_loaded)
func _process(_delta: float) -> void:
	if closed or requested: return
	requested=true
	set_process(false)
	for name in Plan.RESOURCES:
		var id: int=assets.request(name,2002,"mdl-original")
		if id<0: failure=str(assets.failure); return
		jobs[id]=name
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	models[name]=result.value
	if not jobs.is_empty() or not failure.is_empty(): return
	definition=Plan.parse(models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	prewarm_frame_art()
func prewarm_frame_art() -> void:
	# The five layout models are prepared before the quickbar has a world. Their
	# original static images, slot poses and font must also exist before admission.
	for name in ["pnl_quick_bar","gui_qbar_ends"]:
		var key: String=frame.art.request_model(name,"")
		if key.is_empty(): failure="Original quickbar image unavailable: "+name; return
		art_keys.append(key)
	for name in ["qb_but66","qb_but67","qb_but67end"]:
		for pose in ["up","hilite","down"]:
			var key: String=frame.art.request_model(name,pose)
			if key.is_empty(): failure="Original quickbar slot pose unavailable: "+name+"/"+pose; return
			art_keys.append(key)
	frame.fonts.request(Plan.FONT)
	art_prewarm_sealed=true
	try_activate()
func prewarm_rows(rows: Array) -> void:
	current_icons.clear()
	for row in rows:
		var resource:=str(row.get("icon","")).to_lower()
		if resource in ["","****"]: continue
		current_icons[resource]=true
		if resident_icons.has(resource): continue
		var target:=TextureRect.new(); target.name="QuickbarIconSource"; target.hide(); add_child(target)
		resident_icons[resource]=target
		frame.art.bind(target,resource)
func frame_art_ready() -> bool:
	if not requested or not jobs.is_empty() or definition.is_empty() or not art_prewarm_sealed or not failure.is_empty(): return false
	for key in art_keys:
		if frame.art.failed.has(key): failure="Original quickbar art unavailable: "+key; return false
		if not frame.art.textures.has(key): return false
	if frame.fonts.failed.has(Plan.FONT): failure="Original quickbar font unavailable: "+str(frame.fonts.failed[Plan.FONT]); return false
	return frame.fonts.fonts.has(Plan.FONT)
func row_art_ready() -> bool:
	for resource in current_icons:
		if frame.art.failed.has(resource): failure="Original quickbar icon unavailable: "+resource; return false
		if not frame.art.textures.has(resource): return false
	return true
func admission_ready() -> bool:
	return layout_ready and row_art_ready() and panel.extra_art_ready() and failure.is_empty()
func try_activate() -> void:
	if closed or layout_ready or not frame_art_ready(): return
	activate()
func try_admit() -> void:
	if closed or not admission_ready() or panel.quickbar_id<0: return
	panel.show(); place()
func font_loaded(_name: String) -> void:
	try_activate(); try_admit()
func image(resource: String) -> TextureRect:
	var target:=TextureRect.new(); stage.add_child(target); target.mouse_filter=Control.MOUSE_FILTER_IGNORE; target.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; target.stretch_mode=TextureRect.STRETCH_SCALE
	var rect: Rect2=definition.models[resource].bounds; target.position=definition.origin+rect.position; target.size=rect.size
	frame.art.bind(target,resource,"texture",true,""); return target
func activate() -> void:
	layout_ready=true; panel.get_child(0).hide(); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size=Vector2(definition.width,definition.bounds.size.y); panel.size=panel.custom_minimum_size
	stage=Control.new(); panel.add_child(stage); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	image("pnl_quick_bar"); endcaps=image("gui_qbar_ends")
	var previous: Control=panel.cells; panel.cells=Control.new(); stage.add_child(panel.cells); panel.cells.mouse_filter=Control.MOUSE_FILTER_IGNORE; previous.queue_free()
	# Keep the action owner and its private handles; replace only presentation.
	panel.render(panel.shown_page); place(); try_admit()
func place() -> void:
	if not layout_ready or closed: return
	var inverse: Transform2D=panel.get_parent().get_global_transform_with_canvas().affine_inverse()
	var viewport: Rect2=panel.get_viewport_rect(); var bottom: Vector2=inverse*viewport.end; var top: Vector2=inverse*viewport.position; var width: float=bottom.x-top.x
	panel.position=Vector2(top.x+floorf((width-definition.width)/2.0),bottom.y+definition.bounds.position.y)
	endcaps.visible=width>800
func render() -> void:
	if closed or not layout_ready: return
	keys.clear()
	for index in panel.buttons:
		var button: Button=panel.buttons[index]; var entry: Dictionary=definition.slots[int(index)%12].duplicate(); entry.offset+=definition.origin; entry.rect.position+=definition.origin
		# Generic slot children retain drag/action ownership, not their old sizes.
		for child in button.get_children(): if child is Label and child!=button.counter and child!=button.caption: child.queue_free()
		frame.button(button,entry,panel.cells,models,false)
		button.caption.hide(); button.image.size=Vector2(32,32); button.secondary_image.size=Vector2(16,16)
		var key:=Label.new(); button.add_child(key); keys[int(index)]=key; key.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var prefix: String="" if panel.shown_page==0 else text_owner.raw({"strRef":Plan.PREFIX_REFS[panel.shown_page]})
		key.text=prefix+"F%d"%(int(index)%12+1); frame.font_style(key,{"AurString_Font":Plan.FONT}); key.add_theme_color_override("font_shadow_color",Color.BLACK); key.add_theme_constant_override("shadow_offset_x",1); key.add_theme_constant_override("shadow_offset_y",1)
		if is_instance_valid(panel.key_bindings) and panel.key_bindings.bindings_ready and panel.key_bindings.active.hotbar[int(index)]!=panel.key_bindings.hotbar_defaults()[int(index)]:
			key.text=panel.key_bindings.caption(panel.key_bindings.active.hotbar[int(index)],func(ref):return text_owner.raw({"strRef":ref})); key.clip_text=true
			button.tooltip_text+="\n"+(key.text if not key.text.is_empty() else "Unbound")
		button.counter.remove_theme_color_override("font_color"); button.counter.remove_theme_constant_override("outline_size"); frame.font_style(button.counter,{"AurString_Font":Plan.FONT}); button.counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; button.counter.vertical_alignment=VERTICAL_ALIGNMENT_TOP; button.counter.clip_text=true
		layout_children(int(index))
	place()
func layout_children(index: int) -> void:
	if not panel.buttons.has(index) or not keys.has(index): return
	var button: Button=panel.buttons[index]; var entry: Dictionary=definition.slots[index%12]; var local: Vector2=entry.offset+definition.origin-button.position; var hooks: Dictionary=entry.model.hooks
	button.image.position=local+hooks.icon-Vector2(16,16)
	button.secondary_image.position=button.image.position+Vector2(16,16)
	var key: Label=keys[index]; key.position=local+hooks.text-Vector2(0,14.0*0.7857143); key.size=Vector2(60,14); key.add_theme_color_override("font_color",Color.WHITE)
	button.counter.position=local+hooks.count0; button.counter.size=(hooks.count1-hooks.count0).abs()
func art_loaded(_key: String,_texture: Texture2D,_bounds: Dictionary) -> void:
	if closed: return
	try_activate()
	if layout_ready:
		for index in keys: layout_children(int(index))
	try_admit()
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"admitted":panel.visible,"failure":failure,"requested":requested,"pending":jobs.size(),"frame_art":art_keys.size(),"resident_icons":resident_icons.size(),"current_icons":current_icons.size(),"keys":keys.size(),"native_only":true,"full_quickbar_parity":false}
func close() -> void:
	if closed: return
	closed=true; keys.clear(); jobs.clear(); models.clear(); art_keys.clear(); current_icons.clear(); resident_icons.clear()
	if is_instance_valid(frame) and is_instance_valid(frame.art) and frame.art.loaded.is_connected(art_loaded): frame.art.loaded.disconnect(art_loaded)
	if is_instance_valid(frame) and is_instance_valid(frame.fonts) and frame.fonts.loaded.is_connected(font_loaded): frame.fonts.loaded.disconnect(font_loaded)
	if is_instance_valid(assets): assets.close()
func _exit_tree() -> void: close()
