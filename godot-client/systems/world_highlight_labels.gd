extends Control
# Separate counterpart of WorldHighlightView's DOM label host. Native popup
# speech and hover captions retain their own presentation owner.
const PlateState=preload("res://systems/native_data/nameplate_state.gd")
var registry
var camera: Camera3D
var hud
var art
var font_owner
const TEXT_FONT := "ttf fnt_maintext 16"
var labels: Dictionary={}
var signatures: Dictionary={}
var state: Dictionary={"hovered":null,"tab":false,"objects":[],"parts":0,"draws":0}

func configure(value,view: Camera3D,owner) -> void:
	registry=value
	camera=view
	hud=owner
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

func set_art(value) -> void:
	art=value
	signatures.clear()

func set_fonts(value) -> void:
	if is_instance_valid(font_owner):
		if font_owner.loaded.is_connected(_font_loaded):font_owner.loaded.disconnect(_font_loaded)
		for row in labels.values():
			font_owner.unbind(row.name)
			font_owner.unbind(row.condition)
	font_owner=value
	if is_instance_valid(font_owner):
		font_owner.loaded.connect(_font_loaded)
		font_owner.request(TEXT_FONT)
		for row in labels.values():
			font_owner.bind(row.name,TEXT_FONT)
			font_owner.bind(row.condition,TEXT_FONT)
	signatures.clear()

func _font_loaded(name: String) -> void:
	if name==TEXT_FONT:signatures.clear()

func _make_label(id: int) -> Dictionary:
	var panel:=PanelContainer.new()
	panel.name="world_highlight_"+str(id)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var background:=StyleBoxFlat.new()
	background.bg_color=Color(0,0,0,0.667)
	background.set_corner_radius_all(5)
	background.content_margin_left=3.0
	background.content_margin_right=12.0
	background.content_margin_top=2.0
	background.content_margin_bottom=2.0
	panel.add_theme_stylebox_override("panel",background)
	panel.custom_minimum_size=Vector2(115,0)
	add_child(panel)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	# The source grid always reserves a 24px portrait column. Only its 20px
	# image is hidden for noncreatures; the name stays in column two.
	var portrait_column:=Control.new()
	portrait_column.custom_minimum_size=Vector2(24,0)
	portrait_column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait_column)
	var portrait_frame:=Panel.new()
	portrait_frame.custom_minimum_size=Vector2(20,32)
	portrait_frame.size=Vector2(20,32)
	portrait_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var portrait_style:=StyleBoxFlat.new()
	portrait_style.bg_color=Color("#101010")
	portrait_style.border_color=Color("#dddddd")
	portrait_style.set_border_width_all(1)
	portrait_frame.add_theme_stylebox_override("panel",portrait_style)
	portrait_column.add_child(portrait_frame)
	portrait_column.resized.connect(func(): portrait_frame.position.y=maxf(0.0,(portrait_column.size.y-32.0)*0.5))
	var portrait:=TextureRect.new()
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_frame.add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left=1;portrait.offset_top=1;portrait.offset_right=-1;portrait.offset_bottom=-1
	var words:=VBoxContainer.new()
	words.mouse_filter=Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation",0)
	row.add_child(words)
	var name_label:=Label.new()
	name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size",16)
	name_label.add_theme_constant_override("line_spacing",2)
	name_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	name_label.add_theme_constant_override("shadow_offset_x",1)
	name_label.add_theme_constant_override("shadow_offset_y",1)
	words.add_child(name_label)
	var condition:=Label.new()
	condition.mouse_filter=Control.MOUSE_FILTER_IGNORE
	condition.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	condition.add_theme_font_size_override("font_size",16)
	condition.add_theme_constant_override("line_spacing",2)
	condition.add_theme_color_override("font_shadow_color",Color.BLACK)
	condition.add_theme_constant_override("shadow_offset_x",1)
	condition.add_theme_constant_override("shadow_offset_y",1)
	words.add_child(condition)
	if is_instance_valid(font_owner):
		font_owner.bind(name_label,TEXT_FONT)
		font_owner.bind(condition,TEXT_FONT)
	return {"panel":panel,"portrait_column":portrait_column,"portrait_frame":portrait_frame,"portrait":portrait,"name":name_label,"condition":condition}

func _retire(id: int) -> void:
	if not labels.has(id):return
	var row: Dictionary=labels[id]
	if is_instance_valid(art):art.unbind(row.portrait)
	if is_instance_valid(font_owner):
		font_owner.unbind(row.name)
		font_owner.unbind(row.condition)
	if is_instance_valid(row.panel):row.panel.queue_free()
	labels.erase(id)
	signatures.erase(id)

func clear() -> void:
	for id in labels.keys():_retire(int(id))
	hide()
	state={"hovered":null,"tab":false,"objects":[],"parts":0,"draws":0}

func _content(id: int,data: Dictionary) -> void:
	if not labels.has(id):labels[id]=_make_label(id)
	if signatures.get(id)==data.signature:return
	signatures[id]=data.signature
	var row: Dictionary=labels[id]
	row.name.text=str(data.name)
	row.name.add_theme_color_override("font_color",data.name_color)
	row.condition.text=str(data.condition)
	row.condition.visible=not str(data.condition).is_empty()
	row.condition.add_theme_color_override("font_color",data.condition_color)
	row.portrait_column.custom_minimum_size.y=32.0 if bool(data.creature) else 0.0
	row.portrait_frame.visible=bool(data.creature)
	row.portrait.texture=null
	if is_instance_valid(art):art.bind_portrait(row.portrait,str(data.portrait),false)
	var font: Font=row.name.get_theme_font("font")
	var width:=font.get_string_size(str(data.name),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x if font!=null else 115.0
	row.name.custom_minimum_size.x=clampf(width,0.0,310.0)
	var minimum: Vector2=row.panel.get_combined_minimum_size()
	row.panel.size=Vector2(clampf(minimum.x,115.0,360.0),minimum.y)

func update(ids: Array,hovered: int,tab: bool) -> void:
	if registry==null or not is_instance_valid(camera) or not is_instance_valid(hud):clear();return
	var renderer=registry.world_highlight_renderer
	if not is_instance_valid(renderer):clear();return
	var active: Dictionary={}
	var visible_objects: Array=[]
	for id in ids:
		if not id is int or not renderer.entry_bounds.has(id):continue
		var box: Variant=renderer.entry_bounds[id]
		if not box is AABB:continue
		visible_objects.append(id)
		var entity: Dictionary=registry.entities.get(id,{})
		if PlateState.owns_highlight_caption(entity,id==hovered):continue
		var object_type:=int(entity.get("type",0))
		if object_type!=5 and id!=hovered:continue
		var data: Dictionary=hud.world_highlight_label_data(id)
		if data.is_empty():continue
		_content(id,data)
		active[id]=true
		var anchor: Vector3=box.get_center()
		anchor.y=box.end.y+0.15
		var eye: Vector3=camera.global_transform.affine_inverse()*anchor
		var screen: Vector2=camera.unproject_position(anchor)
		var viewport: Rect2=get_viewport_rect()
		var shown: bool=screen.is_finite() and -eye.z>=camera.near and -eye.z<=camera.far and screen.x>=viewport.position.x and screen.x<=viewport.end.x and screen.y>=viewport.position.y and screen.y<=viewport.end.y
		var panel: Control=labels[id].panel
		panel.visible=shown
		if shown:panel.position=screen-Vector2(panel.size.x*0.5,panel.size.y)
	for id in labels.keys():
		if not active.has(id):_retire(int(id))
	visible=not visible_objects.is_empty()
	state={"hovered":hovered if hovered>=0 else null,"tab":tab,"objects":visible_objects,"parts":renderer.parts,"draws":1 if renderer.parts>0 else 0}

func snapshot() -> Dictionary:return state.duplicate(true)

func _exit_tree() -> void:
	clear()
	if is_instance_valid(font_owner) and font_owner.loaded.is_connected(_font_loaded):font_owner.loaded.disconnect(_font_loaded)
	art=null
	font_owner=null
	registry=null
	camera=null
	hud=null
