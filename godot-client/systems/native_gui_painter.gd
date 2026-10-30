extends Node
# Common source-GUI controls. No inventory, game state, protocol or menu actions.
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Builder=preload("res://systems/native_menu_builder.gd")
var art
var fonts
var models: Dictionary={}
var closed:=false
var decorated: Array=[]
var button_geometry: Dictionary={}
var owns_art:=false
func configure_source(catalog,cache_path: String) -> void:
	art=preload("res://systems/native_ui_art.gd").new(); add_child(art); art.configure(catalog,cache_path); owns_art=true
	configure_fonts(catalog,cache_path)
func configure_fonts(catalog,cache_path: String) -> void:
	fonts=preload("res://systems/native_bitmap_fonts.gd").new(); add_child(fonts); fonts.configure(catalog,cache_path)
	art.loaded.connect(art_loaded); set_process(false)
func shift(rect: Rect2) -> Rect2: return rect
func create_button(entry: Dictionary,parent: Control,source_models: Dictionary,checkbox: bool=false) -> Button:
	return Builder.source_button(self,parent,entry,source_models,checkbox)
func create_label(entry: Dictionary,parent: Control,value: String="") -> Label:
	return Builder.source_label(self,parent,entry,value)
func create_edit(entry: Dictionary,parent: Control) -> LineEdit:
	return Builder.source_edit(self,parent,entry)
func relocate(control: Control,parent: Control,rect: Rect2) -> void:
	if control.get_parent()!=parent: control.reparent(parent,false)
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); control.custom_minimum_size=Vector2.ZERO
	control.position=rect.position; control.size=rect.size
func image(resource: String,rect: Rect2,parent: Control) -> TextureRect:
	var control:=TextureRect.new(); control.mouse_filter=Control.MOUSE_FILTER_IGNORE; control.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; control.stretch_mode=TextureRect.STRETCH_SCALE; parent.add_child(control)
	control.set_meta("native_gui_static_image",true)
	control.position=rect.position; control.size=rect.size; art.bind(control,resource,"texture",true,"")
	return control
func button(control: Button,entry: Dictionary,parent: Control,source_models: Dictionary={},follow_footer: bool=true,checkbox: bool=false) -> void:
	relocate(control,parent,entry.rect); control.text=""; control.focus_mode=Control.FOCUS_NONE
	control.add_theme_font_size_override("font_size",1) # Icon-only buttons must not inherit a font's minimum height.
	var static_model:=Geometry.model((models if source_models.is_empty() else source_models)[str(entry.resource)])
	button_geometry[control.get_instance_id()]={"control":control,"resource":str(entry.resource),"offset":entry.get("offset",entry.rect.position-static_model.bounds.position),"rect":entry.rect,"styles":{},"caption":entry.get("caption",{}),"follow_footer":follow_footer,"checkbox":checkbox,"disabled_checked_state":entry.get("disabled_checked_state",false),"overrides":entry.get("overrides",{}).duplicate(true)}
	var poses: Array=[["uncheckedup","normal"],["uncheckedup","hover"],["uncheckeddown","pressed"],["disabled","disabled"],["checkedup","normal_checked"],["checkedup","hover_checked"],["checkeddown","pressed_checked"]] if checkbox else [["up","normal"],["hilite","hover"],["down","pressed"],["down","disabled"]]
	for pair in poses:
		var style:=StyleBoxTexture.new(); style.set_content_margin_all(0); style.draw_center=false
		if not str(pair[1]).ends_with("_checked"): control.add_theme_stylebox_override(pair[1],style)
		button_geometry[control.get_instance_id()].styles[str(pair[1])]=[style,str(pair[0])]
		art.bind(style,str(entry.resource),"texture",true,str(pair[0]),false,entry.get("overrides",{}))
	decorated.append(control)
	control.tree_exiting.connect(func():button_geometry.erase(control.get_instance_id()); decorated.erase(control),CONNECT_ONE_SHOT)
	if checkbox:
		var data: Dictionary=button_geometry[control.get_instance_id()]; data.held=false
		control.button_down.connect(func():data.held=true; control.queue_redraw())
		control.button_up.connect(func():data.held=false; control.queue_redraw())
	control.draw.connect(func():draw_button(control.get_instance_id()))
	update_button(control.get_instance_id())
func draw_button(id: int) -> void:
	if closed or not button_geometry.has(id): return
	var data: Dictionary=button_geometry[id]; var control: Button=data.control
	var mode:=control.get_draw_mode(); var name: String="disabled" if mode==BaseButton.DRAW_DISABLED else "pressed" if mode in [BaseButton.DRAW_PRESSED,BaseButton.DRAW_HOVER_PRESSED] else "hover" if mode==BaseButton.DRAW_HOVER else "normal"
	if data.checkbox:
		if control.disabled: data.held=false
		name="disabled" if control.disabled else "pressed" if bool(data.get("held",false)) else "hover" if control.is_hovered() else "normal"
		# Original SetChecked overrides SetEnabled's pose, while leaving input
		# disabled. Details explicitly uses that order for its received flags.
		if control.disabled and data.disabled_checked_state: name="normal"
	if data.checkbox and control.button_pressed and name!="disabled": name+="_checked"
	var pair: Array=data.styles[name]; var style: StyleBoxTexture=pair[0]
	if style.texture==null: return
	var state: Variant=rendered_rect(data.resource,str(pair[1]),data.offset,data.overrides)
	if state==null: return
	var rect:=Rect2(state.position-data.rect.position,state.size)
	control.draw_texture_rect(style.texture,rect,false)
	data.drawn={"state":name,"rect":rect,"texture_size":style.texture.get_size()}
func button_caption(control: Button,text: String,font_size: int=14) -> Label:
	# Button.draw is emitted after the built-in caption. Child labels stay above
	# the original animated artwork without changing the icon button's minimum.
	control.text=""
	var caption:=Label.new(); control.add_child(caption); caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; caption.text=text; caption.add_theme_font_size_override("font_size",font_size)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK); caption.add_theme_constant_override("shadow_offset_x",1); caption.add_theme_constant_override("shadow_offset_y",1)
	font_style(caption,button_geometry.get(control.get_instance_id(),{}).get("caption",{}))
	return caption
func font_style(control: Control,caption: Dictionary) -> void:
	var name:=str(caption.get("AurString_Font",""))
	if name.is_empty() or not is_instance_valid(fonts): return
	var color:=Color(float(caption.get("AurString_ColorR",1)),float(caption.get("AurString_ColorG",1)),float(caption.get("AurString_ColorB",1)),float(caption.get("AurString_ColorA",1)))
	if control is RichTextLabel:
		control.set_meta("native_text_color",color); control.add_theme_color_override("default_color",color)
	else: control.add_theme_color_override("font_color",color)
	fonts.bind(control,name)
func rendered_rect(resource: String,clip: String,offset: Vector2,overrides: Dictionary={}) -> Variant:
	var key: String=art.models.model_key(resource,clip,overrides)
	if not art.bounds.has(key): return null
	var bounds: Dictionary=art.bounds[key]; var lo: Array=bounds.get("min",[]); var hi: Array=bounds.get("max",[])
	if lo.size()!=2 or hi.size()!=2: return null
	return Rect2(offset+Vector2(lo[0],-hi[1])*100.0,Vector2(float(hi[0])-float(lo[0]),float(hi[1])-float(lo[1]))*100.0)
func update_button(id: int) -> void:
	if closed or not button_geometry.has(id): return
	var data: Dictionary=button_geometry[id]; var control: Button=data.control
	var normal: Variant=rendered_rect(data.resource,"uncheckedup" if data.checkbox else "up",data.offset,data.overrides)
	if normal==null: return
	data.rect=normal
	control.position=(shift(normal) if data.follow_footer else normal).position; control.size=normal.size
	control.queue_redraw()
func art_loaded(key: String,_texture: Texture2D,_bounds: Dictionary) -> void:
	if closed: return
	for id in button_geometry:
		if key.begins_with("gui:"+str(button_geometry[id].resource)+":"): update_button(id)
func label(control: Label,entry: Dictionary,parent: Control) -> void:
	control.clip_text=true; control.autowrap_mode=TextServer.AUTOWRAP_OFF; control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	relocate(control,parent,entry.rect); control.add_theme_font_size_override("font_size",14)
	var caption: Dictionary=entry.get("caption",{}); var align:=float(caption.get("AurString_AlignH",0)); var vertical:=float(caption.get("AurString_AlignV",0))
	control.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT if align>=0.75 else HORIZONTAL_ALIGNMENT_CENTER if align>=0.25 else HORIZONTAL_ALIGNMENT_LEFT
	control.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM if vertical>=0.75 else VERTICAL_ALIGNMENT_CENTER if vertical>=0.25 else VERTICAL_ALIGNMENT_TOP
	control.add_theme_color_override("font_shadow_color",Color.BLACK); control.add_theme_constant_override("shadow_offset_x",1); control.add_theme_constant_override("shadow_offset_y",1)
	font_style(control,caption)
	if entry.get("floating",false):
		# CloseLayoutFile1fdbb0 creates unclaimed labels through
		# LoadGffTextData, bypassing CGuiLabel::LoadGffData's bounds flag.
		# Their source Width/Height are editor metadata, not a clipping box.
		control.clip_text=false
		control.minimum_size_changed.connect(place_floating_label.bind(control,entry))
		place_floating_label(control,entry)
func place_floating_label(control: Label,entry: Dictionary) -> void:
	if not is_instance_valid(control) or control.is_queued_for_deletion(): return
	var caption: Dictionary=entry.get("caption",{}); var extent:=control.get_combined_minimum_size()
	control.size=extent
	control.position=entry.get("anchor",entry.rect.position)-extent*Vector2(float(caption.get("AurString_AlignH",0)),float(caption.get("AurString_AlignV",0)))
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(art) and art.loaded.is_connected(art_loaded): art.loaded.disconnect(art_loaded)
	if is_instance_valid(fonts): fonts.close()
	if owns_art and is_instance_valid(art): art.close()
	models.clear(); button_geometry.clear(); decorated.clear(); art=null
func _exit_tree() -> void: close()
