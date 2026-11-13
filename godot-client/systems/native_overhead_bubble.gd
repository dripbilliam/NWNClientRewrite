extends Control
# Passive ordinary-speech popup. Shared owners provide original popup meshes,
# font assets and textures. No allocation/layout/resource work in place().
const Fitting=preload("res://systems/native_data/nameplate_text.gd")
const MeshView=preload("res://systems/native_nameplate_mesh.gd")
const Text=preload("res://systems/server_text.gd")
const GuiProjection=preload("res://systems/native_data/gui_projection.gd")
var art
var fonts
var source
var backdrop
var portrait_frame
var caption: RichTextLabel
var model: Dictionary={}
var witness: Array=[]
var portrait_key:=""
var bubble_resource:=""
var font_resource:=""
var wanted:=false
var closed:=false
var layout_ready:=false
var layouts:=0
var source_error:=""
var displayed_rich: Dictionary={}
var shape_dirty:=true
var text_indent:=0.0
var active_wanted:=true
var display_refreshes:=0
func configure(images,typefaces,popup_source) -> void:
	if caption!=null:return
	art=images;fonts=typefaces;source=popup_source;mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_mode=Control.FOCUS_NONE
	backdrop=MeshView.new();add_child(backdrop);backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait_frame=MeshView.new();add_child(portrait_frame);portrait_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption=RichTextLabel.new();add_child(caption);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.focus_mode=Control.FOCUS_NONE;caption.bbcode_enabled=false;caption.fit_content=false;caption.scroll_active=false;caption.selection_enabled=false;caption.context_menu_enabled=false;caption.autowrap_mode=TextServer.AUTOWRAP_OFF;caption.clip_contents=true
	caption.add_theme_color_override("default_color",Color.WHITE);caption.add_theme_color_override("font_shadow_color",Color(0,0,0,0));caption.add_theme_color_override("font_outline_color",Color(0,0,0,0));caption.add_theme_constant_override("outline_size",0);caption.add_theme_constant_override("shadow_offset_x",0);caption.add_theme_constant_override("shadow_offset_y",0);caption.add_theme_constant_override("line_separation",0)
	if is_instance_valid(fonts):fonts.loaded.connect(font_loaded)
	if is_instance_valid(source):source.loaded.connect(source_loaded)
	hide()
func set_content(value: Dictionary,portrait: String,identity: Array) -> void:
	if closed:return
	model=value;witness=identity.duplicate();portrait_key=portrait;wanted=bool(value.get("ready",false)) and bool(value.get("eligible",false));active_wanted=int(value.get("mode",0))!=0;shape_dirty=true;layout_ready=false;source_error=""
	if not wanted:hide();return
	var requested:=str(value.get("font",""))
	if requested not in ["ttf fnt_default 14","ttf fnt_default_hr 16"]:source_error="Native dialog font is unavailable.";hide();return
	font_resource=requested
	if is_instance_valid(fonts):fonts.bind(caption,font_resource)
	relayout()
func apply_popup_state(record: Dictionary,mode_changed: bool,font_changed: bool)->void:
	if closed:return
	if not record.get("currentRawKnown",true):wanted=false;model={};displayed_rich={};layout_ready=false;caption.clear();hide();return
	if mode_changed or model.get("rich",{})!=record.currentRich:
		var next: Dictionary=model.duplicate(true);next.merge({"ready":true,"eligible":true,"text":preload("res://systems/native_data/popup_caption_state.gd").decoded(record.currentRaw),"rich":record.currentRich,"mode":record.mode,"font":record.font},true)
		set_content(next,str(record.portrait),witness)
	elif font_changed:
		model.font=record.font;font_resource=str(record.font);layout_ready=false;hide()
		if is_instance_valid(fonts):fonts.bind(caption,font_resource)
		relayout()
	active_wanted=record.sceneActive and not record.hidden and int(record.mode)!=0
	if not active_wanted:hide()
func font_loaded(name: String) -> void:
	if not closed and wanted and name==font_resource:relayout()
func source_loaded(name: String) -> void:
	if closed or not wanted:return
	if name=="but_popup_prtrt":relayout()
	elif name==bubble_resource:refresh_source()
func relayout() -> void:
	if closed or not wanted or caption==null:return
	# A substitute font/empty metrics cannot fabricate a native bubble size.
	if not caption.has_meta("native_font_applied") or str(caption.get_meta("native_font_applied"))!=font_resource:layout_ready=false;hide();return
	var with_portrait: bool=int(model.mode)==2 and not portrait_key.is_empty();var font:=caption.get_theme_font("normal_font");var font_size:=caption.get_theme_font_size("normal_font_size")
	if shape_dirty:
		text_indent=23.0 if with_portrait else 0.0
		var rich: Dictionary=model.get("rich",{});var plain:=Fitting.plain(rich);var metrics:=Fitting.font_metrics(font,font_size,plain);var fitted:=Fitting.choose(plain,metrics,font.get_height(font_size),2,text_indent)
		displayed_rich=Fitting.display(rich,fitted.layout,float(fitted.width),metrics)
		var choice: Array=fitted.bubble;size=Vector2(float(choice[0]),float(choice[1]));bubble_resource=str(choice[2]);backdrop.size=size;shape_dirty=false;layouts+=1
	caption.clear();caption.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER);Text.append(caption,displayed_rich,Color.WHITE);caption.pop()
	var width:=size.x-text_indent;var content_size:=font.get_multiline_string_size(displayed_rich.get("text",""),HORIZONTAL_ALIGNMENT_CENTER,-1,font_size);var shown_height:=minf(size.y,ceilf(content_size.y));var origin:=Vector2(23,0) if with_portrait else Vector2.ZERO
	if with_portrait and is_instance_valid(source) and source.plans.has("but_popup_prtrt"):origin=source.plans.but_popup_prtrt.hooks.get("textindent",origin)
	caption.position=origin+Vector2(0,(size.y-shown_height)*0.5);caption.size=Vector2(width,shown_height);portrait_frame.visible=with_portrait;layout_ready=true;display_refreshes+=1;refresh_source()
func refresh_source() -> void:
	if closed or not wanted or not layout_ready:return
	backdrop.hide()
	if int(model.mode)!=2:
		portrait_frame.hide();return # Native GUI_EMPTY; fitting remains unchanged.
	if not is_instance_valid(source) or source.closed:source_error="Native popup resource owner is unavailable.";return
	source.request(bubble_resource)
	if source.plans.has(bubble_resource):backdrop.configure(source.plans[bubble_resource],art);backdrop.show()
	if not portrait_key.is_empty():
		source.request("but_popup_prtrt")
		if source.plans.has("but_popup_prtrt"):portrait_frame.configure(source.plans.but_popup_prtrt,art,portrait_key)
	elif not portrait_frame.plan.is_empty():portrait_frame.configure(portrait_frame.plan,art,"")
func place(projected: Vector2) -> void:
	var mapped:=GuiProjection.screen_down(projected,get_viewport_rect().size.y)
	visible=not closed and wanted and active_wanted and layout_ready and mapped.get("ready",false)
	if visible:position=mapped.screen-Vector2(size.x*0.5,size.y)
	# Native766ea0 has no footprint clamp, viewport/behind-camera test or rise.
func release() -> void:
	wanted=false;active_wanted=false;layout_ready=false;shape_dirty=true;displayed_rich={};model={};witness=[];portrait_key="";hide()
	if caption!=null:caption.clear()
	if is_instance_valid(fonts):fonts.unbind(caption)
func close() -> void:
	if closed:return
	release();closed=true
	if is_instance_valid(source) and source.loaded.is_connected(source_loaded):source.loaded.disconnect(source_loaded)
	if is_instance_valid(fonts) and fonts.loaded.is_connected(font_loaded):fonts.loaded.disconnect(font_loaded)
	if is_instance_valid(backdrop):backdrop.close()
	if is_instance_valid(portrait_frame):portrait_frame.close()
	art=null;fonts=null;source=null
func _exit_tree() -> void:close()
