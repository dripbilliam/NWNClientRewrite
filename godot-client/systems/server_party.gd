extends Control
signal request(message: Dictionary)
signal panel_requested(id: String)
signal portrait_selected(entry_id: int, point: Vector2)
signal portrait_menu(entry_id: int, point: Vector2)
const Images = preload("res://systems/runtime_image.gd")
var view_id := -1
var actor_id := -1
var rows: Array = []
var cards: Dictionary = {}
var actions: Array = []
var action_buttons: Dictionary = {}
var art: Dictionary = {}
var scroll: ScrollContainer
var column: VBoxContainer
var retired: Array = []
var native_skin
var art_pending:=false
var art_error:=""
var art_notice: Label

func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll = ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(scroll)
	column = VBoxContainer.new(); column.add_theme_constant_override("separation", 5); column.mouse_filter = Control.MOUSE_FILTER_IGNORE; scroll.add_child(column)
	art_notice=Label.new();add_child(art_notice);art_notice.position=Vector2(-230,0);art_notice.size=Vector2(300,48);art_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;art_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE;art_notice.hide()
	get_viewport().size_changed.connect(place); reset()
func _process(_delta: float) -> void:
	if not art_pending or not is_instance_valid(native_skin):set_process(false);return
	var cohort: Dictionary=native_skin.cohort_snapshot()
	if cohort.ready:
		art_pending=false;art_error="";art_notice.hide();scroll.show()
		if is_instance_valid(native_skin.stage):native_skin.stage.show()
		visible=not rows.is_empty();set_process(false)
	elif not cohort.failures.is_empty():
		art_pending=false;art_error=str(cohort.failures[0]);art_notice.text="Party art unavailable: "+art_error;art_notice.show();scroll.hide()
		if is_instance_valid(native_skin.stage):native_skin.stage.hide()
		visible=true;set_process(false)
func request_art_admission() -> void:
	if rows.is_empty():hide();art_pending=false;set_process(false);return
	art_pending=true;art_error="";art_notice.hide();hide();set_process(true)

func reset() -> void:
	art_pending=false;art_error="";set_process(false)
	if is_instance_valid(art_notice):art_notice.hide()
	if is_instance_valid(native_skin) and native_skin.layout_ready: native_skin.reset_view()
	if not cards.is_empty(): retired = cards.values().map(func(card): return weakref(card))
	for card in cards.values():
		if is_instance_valid(native_skin) and native_skin.layout_ready: native_skin.retire_card(card)
		card.get_parent().remove_child(card); card.queue_free()
	cards.clear(); action_buttons.clear(); art.clear(); rows.clear(); actions.clear(); view_id = -1; actor_id = -1; hide()

func retired_alive() -> int: return retired.filter(func(value): return value.get_ref() != null).size()

func receive(message: Dictionary) -> void:
	if message.kind == "party-view":
		if int(message.viewId) <= view_id: return
		var new_rows: Array=message.rows
		var needs_art: bool=is_instance_valid(native_skin) and (not native_skin.layout_ready or art_pending or not visible or not art_error.is_empty() or new_rows.size()!=rows.size())
		if is_instance_valid(native_skin) and not needs_art:
			for row in new_rows:
				var id:=int(row.entryId)
				if not cards.has(id) or str(cards[id].get_meta("portrait_key",""))!=str(row.get("portraitKey","")) or int(cards[id].get_meta("object_id",-1))!=int(row.id):needs_art=true;break
				if id<rows.size() and not bool(row.self) and str(rows[id].get("indicators",{}).get("state",""))!=str(row.get("indicators",{}).get("state","")) and not str(row.get("indicators",{}).get("state","")).is_empty():needs_art=true;break
		if needs_art:hide()
		view_id = int(message.viewId); actor_id = int(message.actorId); rows = message.rows; actions = message.actions
		for entry_id in cards.keys():
			if entry_id >= rows.size() or int(cards[entry_id].get_meta("object_id")) != int(rows[entry_id].id) or bool(cards[entry_id].get_meta("self")) != bool(rows[entry_id].self):
				if is_instance_valid(native_skin) and native_skin.layout_ready: native_skin.retire_card(cards[entry_id])
				cards[entry_id].get_parent().remove_child(cards[entry_id]); cards[entry_id].queue_free(); cards.erase(entry_id)
		action_buttons.clear()
		for row in rows:
			var index := int(row.entryId)
			if not cards.has(index):
				cards[index] = make_card(row)
				var parent: Node=native_skin.card_parent(row) if is_instance_valid(native_skin) and native_skin.layout_ready else column
				parent.add_child(cards[index])
			if cards[index].get_parent()==column: column.move_child(cards[index], column.get_child_count() - 1)
			update_card(row)
		if needs_art:request_art_admission()
		else:visible=not rows.is_empty()
		call_deferred("place")
	elif int(message.get("viewId", -2)) == view_id:
		if message.kind == "party-state":
			var first_health_art:=false
			for state in message.rows:
				var index := int(state.entryId)
				if index >= 0 and index < rows.size():
					if is_instance_valid(native_skin) and not rows[index].health is Dictionary and state.health is Dictionary:first_health_art=true
					rows[index].health = state.health; rows[index].canLevelUp = state.canLevelUp; update_card(rows[index])
			if first_health_art:request_art_admission()
			call_deferred("place")
		elif message.kind == "party-art":
			var texture := Images.png(str(message.skin.url), 512)
			if texture != null:
				art["%s:%s" % [int(message.index), message.state]] = texture
				apply_art(int(message.index))
		else:
			var index := int(message.get("entryId", -1))
			if not cards.has(index): return
			if message.kind == "party-label":
				rows[index].label = str(message.label); update_card(rows[index])
			elif message.kind == "party-portrait":
				var texture := Images.png(str(message.image), 512)
				if texture != null: cards[index].get_node("Box/Portrait/Image").texture = texture; cards[index].get_node("Box/Portrait").text = ""

func make_card(row: Dictionary) -> PanelContainer:
	var card := PanelContainer.new(); card.name = "Member%s" % int(row.entryId); card.custom_minimum_size.x = 78; card.set_meta("object_id", int(row.id)); card.set_meta("self", bool(row.self))
	var style := StyleBoxFlat.new(); style.bg_color = Color("111912f0"); style.border_color = Color("b6a16a"); style.set_border_width_all(1); style.set_content_margin_all(3); card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new(); box.name = "Box"; box.add_theme_constant_override("separation", 2); box.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(box)
	var button := Button.new(); button.name = "Portrait"; button.custom_minimum_size = Vector2(64, 100 if row.self else 64); button.focus_mode = Control.FOCUS_NONE; button.text = "?"; box.add_child(button)
	var image := TextureRect.new(); image.name = "Image"; image.mouse_filter = Control.MOUSE_FILTER_IGNORE; image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; button.add_child(image); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var index := int(row.entryId)
	button.pressed.connect(func(): if cards.get(index)==card and index < rows.size() and rows[index].available: portrait_selected.emit(index, button.get_global_rect().get_center()))
	button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if cards.get(index)==card and index < rows.size() and rows[index].available: portrait_menu.emit(index, button.get_global_transform_with_canvas()*event.position)
			button.accept_event())
	var health := ProgressBar.new(); health.name = "Health"; health.custom_minimum_size = Vector2(64, 15); health.mouse_filter = Control.MOUSE_FILTER_IGNORE; health.show_percentage = false; box.add_child(health)
	var fill := StyleBoxFlat.new(); fill.bg_color = Color("9f302d"); health.add_theme_stylebox_override("fill", fill)
	var hp := Label.new(); hp.name = "Text"; hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; hp.add_theme_font_size_override("font_size", 11); hp.add_theme_color_override("font_shadow_color", Color.BLACK); hp.add_theme_constant_override("shadow_offset_x", 1); hp.add_theme_constant_override("shadow_offset_y", 1); hp.mouse_filter = Control.MOUSE_FILTER_IGNORE; health.add_child(hp); hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if row.self:
		var grid := GridContainer.new(); grid.name = "Actions"; grid.columns = 2; grid.add_theme_constant_override("h_separation", 1); grid.add_theme_constant_override("v_separation", 1); box.add_child(grid)
		for action in actions:
			var control := Button.new(); control.name = "Action%s" % int(action.index); control.custom_minimum_size = Vector2(34, 22); control.text = str(action.label).left(1); control.tooltip_text = str(action.label) + (" (%s)" % str(action.key).to_upper() if action.key != null else ""); control.focus_mode = Control.FOCUS_NONE
			control.pressed.connect(func():
				if cards.get(index)!=card or index>=rows.size() or not rows[index].available: return
				if str(action.id) == "rest": request.emit({"kind":"party-rest","viewId":view_id})
				else: panel_requested.emit(str(action.id)))
			grid.add_child(control)
		var level := Button.new(); level.name = "Level"; level.text = "Level Up"; level.add_theme_font_size_override("font_size", 11); level.focus_mode = Control.FOCUS_NONE; level.pressed.connect(func(): if cards.get(index)==card and index<rows.size() and rows[index].available and rows[index].canLevelUp: panel_requested.emit("level-up")); box.add_child(level)
	var label := Label.new(); label.name = "Name"; label.custom_minimum_size.x = 64; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", 11); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; box.add_child(label)
	return card

func update_card(row: Dictionary) -> void:
	var card: PanelContainer = cards[int(row.entryId)]; var box: Control = card.get_node("Box"); var button: Button = box.get_node("Portrait")
	button.disabled = not row.available; button.tooltip_text = str(row.label) + ("" if row.available else " · not currently available"); card.modulate.a = 1.0 if row.available else 0.5; box.get_node("Name").text = str(row.label)
	if card.get_meta("portrait_key", "") != str(row.portraitKey): card.set_meta("portrait_key", str(row.portraitKey)); button.get_node("Image").texture = null; button.text = "?"
	var health: ProgressBar = box.get_node("Health"); var hp: Label = health.get_node("Text")
	if row.health == null: health.value = 0; hp.text = "—"; health.tooltip_text = "Hit points have not been received"
	else:
		health.max_value = maxf(1, float(row.health.maximum)); health.value = clampf(float(row.health.current), 0, health.max_value); hp.text = "%d/%d" % [row.health.current, row.health.maximum]; health.tooltip_text = hp.text
	if row.self:
		box.get_node("Level").visible = bool(row.canLevelUp) and bool(row.available)
		for action in actions:
			var control: Button = box.get_node("Actions/Action%s" % int(action.index)); control.disabled = not row.available; action_buttons[int(action.index)] = control; apply_art(int(action.index))
	if is_instance_valid(native_skin) and native_skin.layout_ready: native_skin.update_card(row)

func apply_art(index: int) -> void:
	if not action_buttons.has(index): return
	var button: Button = action_buttons[index]
	for pair in [["up", "normal"], ["hilite", "hover"], ["down", "pressed"]]:
		if art.has("%s:%s" % [index, pair[0]]):
			var style := StyleBoxTexture.new(); style.texture = art["%s:%s" % [index, pair[0]]]; button.add_theme_stylebox_override(pair[1], style)
	if art.has("%s:up" % index): button.text = ""

func place() -> void:
	if is_instance_valid(native_skin) and native_skin.layout_ready: native_skin.place(); return
	if scroll == null: return
	var extent := get_viewport_rect().size
	size = Vector2(94, maxf(0, extent.y - 64)); scroll.size = size; position = Vector2(maxf(0, extent.x - size.x), 8)

func blocks_pointer(point: Vector2) -> bool:
	if is_instance_valid(native_skin) and native_skin.layout_ready: return native_skin.blocks_pointer(point)
	if not visible or not scroll.get_global_rect().has_point(point): return false
	if scroll.get_v_scroll_bar().visible and scroll.get_v_scroll_bar().get_global_rect().has_point(point): return true
	return cards.values().any(func(card): return card.get_global_rect().has_point(point))
