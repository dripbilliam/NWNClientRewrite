extends Control
# Original fixed popup models and passive source portrait, with shared native
# data/raster/font owners. No model rasterization in the position loop.
const Text=preload("res://systems/server_text.gd")
const Fitting=preload("res://systems/native_data/nameplate_text.gd")
const MeshView=preload("res://systems/native_nameplate_mesh.gd")
const GuiProjection=preload("res://systems/native_data/gui_projection.gd")
const FONT="ttf fnt_default 14"
var art
var fonts
var source
var backdrop
var portrait_frame
var portrait:
	get: return portrait_frame.photo() if is_instance_valid(portrait_frame) else null
var placeholder: Panel
var bubble_resource:=""
var caption: RichTextLabel
var data: Dictionary={}
var portrait_key:=""
var closed:=false
var layouts:=0
var layout_ready:=false
var font_resource:=FONT
var presentation_mode:=2
var presentation_active:=true
var popup_bound:=false
var shape_dirty:=true
var displayed_rich: Dictionary={}
var text_indent:=0.0
var display_refreshes:=0
var reuse_presentation:=not OS.get_cmdline_user_args().has("--nameplate-presentation=reference")
var shape_inputs: Array=[]
var display_inputs: Array=[]
var display_reuses:=0
var shaped_size:=Vector2.ZERO
var shaped_resource:=""
var caption_output_position:=Vector2.ZERO
var caption_output_size:=Vector2.ZERO
var caption_output_text:=""
func configure(images=null,typefaces=null,shared_source=null,dialog_font: String=FONT) -> void:
	art=images;fonts=typefaces;source=shared_source;font_resource=dialog_font;mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_mode=Control.FOCUS_NONE
	placeholder=Panel.new(); add_child(placeholder); placeholder.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var background:=StyleBoxFlat.new(); background.bg_color=Color(0,0,0,0.65); placeholder.add_theme_stylebox_override("panel",background)
	backdrop=MeshView.new(); add_child(backdrop); backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	backdrop.textures_changed.connect(update_placeholder)
	portrait_frame=MeshView.new(); add_child(portrait_frame); portrait_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption=make_text()
	if is_instance_valid(fonts):
		fonts.loaded.connect(font_loaded);fonts.bind(caption,font_resource)
	if is_instance_valid(source): source.loaded.connect(source_loaded)
	hide()
func make_text() -> RichTextLabel:
	var label:=Text.label({},0); add_child(label); label.fit_content=false; label.focus_mode=Control.FOCUS_NONE; label.selection_enabled=false; label.context_menu_enabled=false; label.autowrap_mode=TextServer.AUTOWRAP_OFF; label.clip_contents=true
	# Original StringGob popups use the font raster itself. ServerText's
	# generic outline/shadow belongs to other UI surfaces, not these captions.
	label.add_theme_constant_override("outline_size",0); label.add_theme_constant_override("shadow_offset_x",0); label.add_theme_constant_override("shadow_offset_y",0); label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT); label.add_theme_color_override("font_outline_color",Color.TRANSPARENT)
	label.add_theme_constant_override("line_separation",0); return label
func set_content(value: Dictionary) -> void:
	if closed: return
	data=value;shape_dirty=true;layout_ready=false
	if not bool(value.get("available",false)):
		caption.clear();display_inputs.clear()
		hide()
		if not portrait_frame.plan.is_empty(): portrait_frame.configure(portrait_frame.plan,art,"")
		return
	portrait_key=str(value.portrait)
	portrait_frame.visible=presentation_mode==2 and bool(value.creature) and not portrait_key.is_empty()
	if is_instance_valid(fonts) and str(caption.get_meta("native_font_applied",""))!=font_resource:caption.clear();display_inputs.clear()
	relayout()
func set_popup_preferences(mode: int,font: String)->void:
	popup_bound=true;presentation_mode=mode
	if font_resource!=font:
		font_resource=font;layout_ready=false
		if is_instance_valid(fonts):fonts.bind(caption,font_resource)
func apply_popup_state(record: Dictionary,mode_changed: bool,font_changed: bool)->void:
	if closed:return
	popup_bound=true;presentation_mode=int(record.mode);presentation_active=record.sceneActive and not record.hidden
	if not record.get("currentRawKnown",true):layout_ready=false;data={};displayed_rich={};shape_inputs.clear();display_inputs.clear();caption.clear();hide();return
	if mode_changed or data.get("caption",{})!=record.currentRich:
		data=data.duplicate(true);data.merge({"available":true,"caption":record.currentRich,"name":record.currentRich,"color":Color.WHITE,"caption_color":Color.WHITE,"portrait":str(record.portrait),"creature":not str(record.portrait).is_empty()},true);portrait_key=str(record.portrait);shape_dirty=true;layout_ready=false
	if font_changed or font_resource!=str(record.font):set_popup_preferences(int(record.mode),str(record.font))
	if is_instance_valid(portrait_frame):portrait_frame.visible=presentation_mode==2 and not portrait_key.is_empty()
	relayout()
	if presentation_mode==0 or not presentation_active:hide()
func text_extent(label: RichTextLabel,plain: String,width: float) -> Vector2:
	var font:=label.get_theme_font("normal_font"); var height:=label.get_theme_font_size("normal_font_size")
	return font.get_multiline_string_size(plain,HORIZONTAL_ALIGNMENT_CENTER,-1,height)
func relayout() -> void:
	if closed or data.is_empty() or not bool(data.get("available",false)): return
	if is_instance_valid(fonts) and (not caption.has_meta("native_font_applied") or str(caption.get_meta("native_font_applied"))!=font_resource):layout_ready=false;hide();return
	var font:=caption.get_theme_font("normal_font"); var font_size:=caption.get_theme_font_size("normal_font_size")
	if shape_dirty:
		text_indent=(23.0 if popup_bound else 24.0) if presentation_mode==2 and portrait_frame.visible else 0.0
		var rich: Dictionary=data.get("caption",data.get("name",{}))
		var next_shape: Array=[rich,font,font_size,text_indent]
		if not reuse_presentation or shape_inputs!=next_shape:
			var content:=Fitting.plain(rich);var metrics:=Fitting.font_metrics(font,font_size,content)
			var fitted:=Fitting.choose(content,metrics,font.get_height(font_size),2,text_indent);var choice: Array=fitted.bubble
			displayed_rich=Fitting.display(rich,fitted.layout,float(fitted.width),metrics)
			bubble_resource=str(choice[2]);size=Vector2(float(choice[0]),float(choice[1]));backdrop.size=size;placeholder.size=size;layouts+=1
			shaped_size=size;shaped_resource=bubble_resource
			shape_inputs=next_shape.duplicate(true)
		elif size!=shaped_size or bubble_resource!=shaped_resource or backdrop.size!=shaped_size or placeholder.size!=shaped_size:
			size=shaped_size;bubble_resource=shaped_resource;backdrop.size=size;placeholder.size=size
		shape_dirty=false
	var width:=size.x-text_indent
	var origin:=Vector2(23,0) if portrait_frame.visible else Vector2.ZERO
	if portrait_frame.visible and is_instance_valid(source) and source.plans.has("but_popup_prtrt"): origin=source.plans.but_popup_prtrt.hooks.get("textindent",origin)
	var color: Color=caption.get_meta("native_text_color",data.get("caption_color",data.get("color",Color.WHITE)))
	var next_display: Array=[displayed_rich,color,font,font_size,size,text_indent,origin]
	if reuse_presentation and not display_inputs.is_empty() and display_inputs==next_display and caption.position==caption_output_position and caption.size==caption_output_size and caption.get_parsed_text()==caption_output_text:
		layout_ready=true;display_reuses+=1;refresh_source();return
	caption.clear();caption.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER);Text.append(caption,displayed_rich,color);caption.pop()
	var content_size:=text_extent(caption,displayed_rich.get("text",""),width)
	var shown_height:=minf(size.y,ceilf(content_size.y))
	caption.position=origin+Vector2(0,(size.y-shown_height)*0.5);caption.size=Vector2(width,shown_height);layout_ready=true;display_refreshes+=1
	caption_output_position=caption.position;caption_output_size=caption.size;caption_output_text=caption.get_parsed_text()
	display_inputs=next_display.duplicate(true)
	refresh_source()
func refresh_source() -> void:
	if closed or not is_instance_valid(source) or source.closed: return
	if presentation_mode!=2:placeholder.hide();backdrop.hide();portrait_frame.hide();return
	source.request(bubble_resource)
	if source.plans.has(bubble_resource): backdrop.configure(source.plans[bubble_resource],art)
	update_placeholder()
	if portrait_frame.visible:
		source.request("but_popup_prtrt")
		if source.plans.has("but_popup_prtrt"): portrait_frame.configure(source.plans.but_popup_prtrt,art,portrait_key)
	elif not portrait_frame.plan.is_empty(): portrait_frame.configure(portrait_frame.plan,art,"")
func update_placeholder() -> void:
	if not closed:
		if presentation_mode!=2:placeholder.hide();backdrop.hide();return
		placeholder.visible=backdrop.resource!=bubble_resource or not backdrop.raster_ready()
		backdrop.visible=not placeholder.visible
func source_loaded(name: String) -> void:
	if closed: return
	if name=="but_popup_prtrt": relayout()
	elif name==bubble_resource: refresh_source()
func font_loaded(name: String) -> void:
	# Native SetFont recalculates display data without choosing a new bubble or
	# rewriting wrapped lines. A later SetText still keys shaping by the new font.
	if not closed and name==font_resource:shape_inputs.clear();display_inputs.clear();relayout()
func place(anchor: Vector2,viewport: Rect2,native_projection: bool=false) -> void:
	if native_projection:
		# Native766ea0 ->6e9820 has no viewport/behind/footprint clamp. Round
		# GUI-up exactly once, then adapt to the current Godot downwards Y.
		var mapped:=GuiProjection.screen_down(anchor,get_viewport_rect().size.y)
		visible=not closed and presentation_mode!=0 and presentation_active and layout_ready and bool(data.get("available",false)) and mapped.get("ready",false)
		if visible:position=mapped.screen-Vector2(size.x*0.5,size.y)
		return
	# Existing explicit offline/debug/tooltip caller contract, not the native
	# model-head placement path. These callers retain their inspection bounds.
	visible=not closed and presentation_mode!=0 and presentation_active and layout_ready and bool(data.get("available",false)) and viewport.has_point(anchor)
	if not visible: return
	position=anchor-Vector2(size.x*0.5,size.y)
	var footprint: Rect2=backdrop.plan.get("bounds",Rect2(Vector2.ZERO,size)) if backdrop.resource==bubble_resource else Rect2(Vector2.ZERO,size)
	position.x=clampf(position.x,viewport.position.x-footprint.position.x,maxf(viewport.position.x-footprint.position.x,viewport.end.x-footprint.end.x))
	position.y=clampf(position.y,viewport.position.y-footprint.position.y,maxf(viewport.position.y-footprint.position.y,viewport.end.y-footprint.end.y))
func close() -> void:
	if closed: return
	closed=true; hide(); data.clear()
	shape_inputs.clear();display_inputs.clear()
	if backdrop.textures_changed.is_connected(update_placeholder): backdrop.textures_changed.disconnect(update_placeholder)
	backdrop.close(); portrait_frame.close()
	if is_instance_valid(source) and source.loaded.is_connected(source_loaded): source.loaded.disconnect(source_loaded)
	if is_instance_valid(fonts):
		if fonts.loaded.is_connected(font_loaded): fonts.loaded.disconnect(font_loaded)
		fonts.unbind(caption)
	art=null; fonts=null; source=null
func _exit_tree() -> void: close()
