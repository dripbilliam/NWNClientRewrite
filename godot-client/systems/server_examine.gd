extends "res://systems/draggable_panel.gd"

const Text = preload("res://systems/server_text.gd")
var state: Dictionary = {}
var body: VBoxContainer
var portrait: TextureRect
var title_text: RichTextLabel
var native_skin
var scroll: ScrollContainer
var detail_width:=440.0
var detail_font:=17
var modal_lease=preload("res://systems/native_data/modal_lease.gd").new()
func set_modal_order(order,surfaces=null,canvas: CanvasLayer=null) -> void:
	modal_lease.configure(self,order,surfaces,canvas);modal_lease.bind_input(self)
	if not visibility_changed.is_connected(modal_visibility_changed):visibility_changed.connect(modal_visibility_changed)
	if visible and not state.is_empty():modal_lease.activate([],"other",superseded_modal_owner)
func modal_visibility_changed() -> void:
	if not visible:modal_lease.retire()
func superseded_modal_owner(_ticket: Dictionary) -> void:reset()
func close_modal_owner() -> void:modal_lease.close()
func _exit_tree() -> void:close_modal_owner()

func setup(storage: String = "user://native-menu-layout.cfg") -> void:
	configure("Examine", "local-examine", Vector2(90, 90), storage)
	title_text = Text.label({}, 500)
	content.add_child(title_text)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 400)
	content.add_child(scroll)
	var row := HBoxContainer.new()
	scroll.add_child(row)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(80, 125)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	content.add_child(close)
	reset()

func reset() -> void:
	modal_lease.retire()
	dragging=false
	state.clear()
	portrait.texture = null
	portrait.hide()
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	hide()

func present(message: Dictionary) -> void:
	reset()
	if message.get("close", false):
		return
	state = message.duplicate(true)
	Text.set_text(title_text, message.get("name", {"text": "Examine"}))
	show()
	if native_skin!=null: native_skin.present(message)
	render_details(message)
	show()
	move_to_front()
	modal_lease.activate([],"other",superseded_modal_owner)

func detail(rich: Dictionary) -> RichTextLabel:
	var label:=Text.label({},detail_width); label.add_theme_font_size_override("normal_font_size",detail_font)
	if native_skin!=null: native_skin.style_detail(label)
	Text.set_text(label,rich); return label
func render_details(message: Dictionary) -> void:
	for child in body.get_children():
		body.remove_child(child); child.queue_free()
	var original_body: bool=native_skin!=null and message.has("nativeBody")
	body.add_theme_constant_override("separation",0 if original_body else 4)
	if original_body: body.add_child(detail(message.nativeBody))
	else:
		for key in ["condition", "reaction", "description"]:
			if message.has(key): body.add_child(detail(message[key]))
		for row in message.get("facts", []):
			body.add_child(detail({"text": str(row.name) + ":"}))
			body.add_child(detail(row.rich))
	for key in ["properties", "effects"]:
		var values: Array = message.get(key, [])
		if not values.is_empty() or key=="properties" and int(message.get("propertyCount",0))>0:
			body.add_child(detail(message.get("propertyHeading",{"text":"Item properties"}) if key=="properties" else {"text":"Effects"}))
			for value in values:
				body.add_child(detail(value.rich if key == "properties" else value))
	for warning in message.get("warnings", []):
		body.add_child(detail({"text": str(warning)}))
	if native_skin!=null: native_skin.details_changed()
func refresh_properties(properties: Array,warnings: Array,target_id: int,revision: int) -> bool:
	if not visible or int(state.get("targetId",-1))!=target_id or int(state.get("revision",-1))!=revision: return false
	state.properties=properties.duplicate(true); state.warnings=warnings.duplicate()
	render_details(state); return true

func set_portrait(message: Dictionary) -> bool:
	if not visible or state.is_empty() or int(message.get("revision", -1)) != int(state.get("revision", -2)) or int(message.get("targetId", -1)) != int(state.get("targetId", -2)):
		return false
	var url := str(message.get("image", ""))
	if not url.begins_with("data:image/png;base64,") or url.length() > 350000:
		return false
	var image := Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(url.substr(22))) != OK or image.get_width() > 1024 or image.get_height() > 1024:
		return false
	portrait.texture = ImageTexture.create_from_image(image)
	portrait.show()
	return true

func set_native_portrait(texture: Texture2D,target_id: int,revision: int) -> bool:
	if texture==null or not visible or int(state.get("targetId",-1))!=target_id or int(state.get("revision",-1))!=revision: return false
	portrait.texture=texture; portrait.show(); return true
