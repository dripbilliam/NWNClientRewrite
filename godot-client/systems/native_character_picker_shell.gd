extends Control
const Builder=preload("res://systems/native_menu_builder.gd")
const Style=preload("res://systems/native_client_menu_style.gd")
# Immediate native composition: no archive/model/font/texture request is needed
# to construct it. The connection owner supplies resolved authoritative data.
signal character_selected(key: String,activate: bool)
signal action_requested(tag: String)
signal pregenerated_changed(enabled: bool)
var built:=false
var scope: Array=[]
var revision:=0
var selected:=""
var navigation_key:=""
var row_keys: Array=[]
var rows: Dictionary={}
var row_portraits: Dictionary={}
var row_names: Dictionary={}
var row_classes: Dictionary={}
var row_sources: Dictionary={}
var captures: Dictionary={}
var server: Label
var status: Label
var title: Label
var summary: Label
var stage_status: Label
var roster: VBoxContainer
var list: ScrollContainer
var empty: Label
var portrait: TextureRect
var stage: PanelContainer
var preview_mount: Control
var columns: HBoxContainer
var footer: HBoxContainer
var pregen: CheckBox
var play: Button
var buttons: Dictionary={}
var details: VBoxContainer
var margin: MarginContainer
var left: VBoxContainer
var started_us:=0
var built_us:=0
const GOLD=Style.PICKER_GOLD
const IVORY=Style.PICKER_IVORY
func label(parent: Control,value: String,points: int=16,color: Color=IVORY) -> Label:
	var target: Label=Builder.create("label",parent,{"text":value}); target.add_theme_font_size_override("font_size",points); target.add_theme_color_override("font_color",color); return target
func button(parent: Control,caption: String,tag: String,primary: bool=false) -> Button:
	var target: Button=Builder.create("button",parent,{"text":caption,"custom_minimum_size":Vector2(0,42)})
	target.theme_type_variation="PickerPrimary" if primary else "PickerButton"
	buttons[tag]=target; target.button_down.connect(func():captures[tag]=[scope.duplicate(true),revision]); target.pressed.connect(func():
		var capture: Array=captures.get(tag,[]); captures.erase(tag)
		if capture==[scope,revision] and not target.disabled: action_requested.emit(tag))
	return target
func _ready() -> void:
	theme=Style.picker_theme()
	started_us=Time.get_ticks_usec(); set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP; focus_mode=Control.FOCUS_ALL
	var background:=ColorRect.new(); background.color=Color("0b121a"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); background.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(background)
	margin=MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(margin)
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,40)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,28)
	var layout:=VBoxContainer.new(); layout.add_theme_constant_override("separation",22); margin.add_child(layout)
	var header:=HBoxContainer.new(); header.add_theme_constant_override("separation",20); layout.add_child(header)
	var heading:=VBoxContainer.new(); heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(heading); label(heading,"CHOOSE YOUR CHARACTER",12,GOLD); label(heading,"Your next adventure",30)
	var connection:=VBoxContainer.new(); connection.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(connection); server=label(connection,"Connecting to server",16); server.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; status=label(connection,"Waiting for the character list…",13,Color("94a4af")); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	columns=HBoxContainer.new(); columns.add_theme_constant_override("separation",24); columns.size_flags_vertical=Control.SIZE_EXPAND_FILL; layout.add_child(columns)
	left=VBoxContainer.new(); left.custom_minimum_size.x=300; left.add_theme_constant_override("separation",12); columns.add_child(left)
	label(left,"CHARACTERS",12,GOLD)
	list=ScrollContainer.new(); list.size_flags_vertical=Control.SIZE_EXPAND_FILL; list.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; left.add_child(list)
	roster=VBoxContainer.new(); roster.size_flags_horizontal=Control.SIZE_EXPAND_FILL; roster.add_theme_constant_override("separation",7); list.add_child(roster)
	empty=label(roster,"Waiting for the server's characters…",15,Color("94a4af")); empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	pregen=Builder.create("check",left,{"text":"Show pregenerated characters"}); pregen.toggled.connect(pregenerated_changed.emit)
	stage=PanelContainer.new(); stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL; stage.add_theme_stylebox_override("panel",Style.picker_box(Color("12232c"),Color("354149"),12)); columns.add_child(stage)
	var stage_layout:=VBoxContainer.new(); stage_layout.add_theme_constant_override("separation",12); stage.add_child(stage_layout); label(stage_layout,"CHARACTER PREVIEW",12,GOLD)
	preview_mount=Control.new(); preview_mount.size_flags_vertical=Control.SIZE_EXPAND_FILL; preview_mount.custom_minimum_size=Vector2(200,220); stage_layout.add_child(preview_mount)
	portrait=TextureRect.new(); portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE; preview_mount.add_child(portrait)
	stage_status=label(stage_layout,"Select a character to see their appearance",14,Color("9aadb7")); stage_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	details=VBoxContainer.new(); details.custom_minimum_size.x=250; details.add_theme_constant_override("separation",14); columns.add_child(details)
	label(details,"SELECTED CHARACTER",12,GOLD); title=label(details,"Choose your adventurer",26); title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	summary=label(details,"Character details appear here when received from the server.",16,Color("b1c0c8")); summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; summary.size_flags_vertical=Control.SIZE_EXPAND_FILL
	play=button(details,"Enter World","play",true); play.disabled=true; button(details,"Character Details","details").disabled=true
	var mutations:=HBoxContainer.new(); details.add_child(mutations); mutations.add_theme_constant_override("separation",8)
	button(mutations,"Delete","delete").disabled=true; button(mutations,"Customize","customize").disabled=true
	var divider:=HSeparator.new(); layout.add_child(divider)
	footer=HBoxContainer.new(); footer.add_theme_constant_override("separation",12); layout.add_child(footer)
	button(footer,"Back","back"); button(footer,"New Character","create").disabled=true
	var spacer:=Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; footer.add_child(spacer); button(footer,"Server Info","server-info"); button(footer,"Players","players")
	visibility_changed.connect(restore_focus); resized.connect(resize_layout)
	built=true; resize_layout(); restore_focus(); built_us=Time.get_ticks_usec()-started_us
func restore_focus() -> void:
	if is_visible_in_tree() and get_viewport().gui_get_focus_owner()==null: grab_focus()
func _process(_delta: float) -> void: restore_focus()
func resize_layout() -> void:
	if not built: return
	var narrow:=size.x<1100; var inset:=20 if narrow else 40
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,inset)
	left.custom_minimum_size.x=240 if narrow else 300; details.custom_minimum_size.x=210 if narrow else 250
	columns.add_theme_constant_override("separation",16 if narrow else 24)
	stage.visible=size.x>=1000
func make_row(item_key: String) -> Button:
	var item: Button=Builder.create("button",roster,{"custom_minimum_size":Vector2(0,88)}); rows[item_key]=item
	var image:=TextureRect.new(); item.add_child(image); image.position=Vector2(10,9); image.size=Vector2(44,69); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.mouse_filter=Control.MOUSE_FILTER_IGNORE; row_portraits[item_key]=image
	var copy:=VBoxContainer.new(); item.add_child(copy); copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); copy.offset_left=66; copy.offset_right=-10; copy.offset_top=10; copy.offset_bottom=-8; copy.add_theme_constant_override("separation",2); copy.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row_names[item_key]=label(copy,"",16); row_classes[item_key]=label(copy,"",13,Color("c8d0d4")); row_sources[item_key]=label(copy,"",12,Color("9aadb7"))
	for target in [row_names[item_key],row_classes[item_key],row_sources[item_key]]: target.mouse_filter=Control.MOUSE_FILTER_IGNORE; target.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	item.button_down.connect(func():grab_focus(); captures["row:"+item_key]=[scope.duplicate(true),revision]); item.pressed.connect(func():
		var press: Array=captures.get("row:"+item_key,[]); captures.erase("row:"+item_key)
		if press==[scope,revision] and not item.disabled: character_selected.emit(item_key,false))
	item.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.double_click and event.button_index==MOUSE_BUTTON_LEFT and row_keys.has(item_key) and not item.disabled: grab_focus(); character_selected.emit(item_key,true))
	return item
func present(context: Array,characters: Array,key: String,capabilities: Dictionary,server_name: String,feedback: String="",pending_key: String="") -> void:
	var next_navigation:=pending_key if not pending_key.is_empty() else key
	var reveal: bool=context!=scope or next_navigation!=navigation_key
	if context!=scope:
		for image in row_portraits.values(): image.texture=null
	if context!=scope or key!=selected: scope=context.duplicate(true); revision+=1; captures.clear()
	selected=key; navigation_key=next_navigation; server.text=server_name; status.text=feedback
	var keys: Array=characters.map(func(row):return str(row.key)); var changed:=keys!=row_keys
	if changed:
		revision+=1; captures.clear()
		for row in rows.values(): row.hide(); row.queue_free()
		rows.clear(); row_portraits.clear(); row_names.clear(); row_classes.clear(); row_sources.clear(); row_keys=keys
		for data in characters:
			make_row(str(data.key))
	empty.visible=characters.is_empty()
	for data in characters:
		var item_key:=str(data.key); var row: Button=rows[item_key]; row.disabled=not capabilities.get("select",false)
		row_names[item_key].text=str(data.get("name","")); row_classes[item_key].text=str(data.get("classes","")); row_sources[item_key].text=str(data.get("source","")); row.tooltip_text=str(data.get("name",""))+"\n"+str(data.get("classes",""))+"\n"+str(data.get("source",""))
		row.modulate=Color("8c969e") if row.disabled else Color.WHITE
		row.theme_type_variation="PickerSelectedRow" if str(data.key)==key else "PickerRow"
		if str(data.key)==key: title.text=str(data.get("name","")); summary.text=str(data.get("summary",data.get("classes","")))
	if not row_keys.has(key): title.text="Choose your adventurer"; summary.text="Select a character to inspect their details."
	for tag in buttons: buttons[tag].disabled=not bool(capabilities.get(tag,false))
	play.disabled=play.disabled or not row_keys.has(key)
	if reveal or changed: reveal_selection.call_deferred(scope.duplicate(true),navigation_key)
	restore_focus()
func reveal_selection(context: Array,key: String) -> void:
	if context==scope and key==navigation_key and rows.has(key) and is_visible_in_tree(): list.ensure_control_visible(rows[key])
func set_portrait(texture: Texture2D) -> void: portrait.texture=texture
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not has_focus() or not is_visible_in_tree(): return
	# The original focused chooser edit owns all pressed keys; Enter/Escape/Tab
	# have no bound submit/cancel/traversal action. Cursor keys only select rows.
	accept_event()
	if row_keys.is_empty() or event.keycode not in [KEY_LEFT,KEY_UP,KEY_RIGHT,KEY_DOWN]: return
	var index:=row_keys.find(navigation_key); index=clampi(index+(-1 if event.keycode in [KEY_LEFT,KEY_UP] else 1),0,row_keys.size()-1)
	var row: Button=rows[row_keys[index]]
	if not row.disabled: character_selected.emit(str(row_keys[index]),false)
