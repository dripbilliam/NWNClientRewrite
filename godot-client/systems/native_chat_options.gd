extends "res://systems/draggable_panel.gd"
signal settings_changed(value: Dictionary)
signal latest_requested
signal original_requested
const Preferences=preload("res://systems/native_data/chat_preferences.gd")
const D=preload("res://systems/native_data/menu_definition.gd")
var values: Dictionary={}
var fields: Dictionary={}
var updating:=false
static func acquire(viewport: Viewport,path: String):
	var key:="native_chat_settings_"+path.sha256_text()
	if viewport.has_meta(key):
		var prior: Object=viewport.get_meta(key).get_ref()
		if is_instance_valid(prior): return prior
	var layer:=CanvasLayer.new(); layer.layer=95; layer.name="ChatSettingsLayer"; viewport.add_child(layer)
	var window=load("res://systems/native_chat_options.gd").new(); layer.add_child(window); window.setup(path); window.hide(); viewport.set_meta(key,weakref(window)); return window
func setup(path: String) -> void:
	configure("Chat settings","chat-settings",Vector2(100,100),path)
	var specs: Array=[]
	for row in [["width","Chat width",320,2040,20],["x","Horizontal position",0,4096,10],["bottom","Bottom offset",0,4096,10],["font_size","Message text size",10,28,1],["opacity","Background opacity (%)",0,100,5],["history","History per pane",50,2000,50]]:
		specs.append(D.control("row","",{},[D.label(row[1]),D.control("number",row[0],{"min_value":row[2],"max_value":row[3],"step":row[4],"size_flags_horizontal":Control.SIZE_EXPAND_FILL})]))
	for row in [["split","Separate chat and combat/server feedback"],["compact_prompt","Fit the input strip to chat width"],["timestamps","Show local timestamps"],["seconds","Include seconds"],["autoscroll","Follow new messages when already at the bottom"],["locked","Lock chat position and size"]]: specs.append(D.check(row[0],row[1]))
	specs.append(D.control("row","",{},[D.label("Speech popups"),D.choice("ui.text-bubble-mode",[["Off",0],["Text only",1],["Full background",2]],{"size_flags_horizontal":Control.SIZE_EXPAND_FILL})]))
	specs.append(D.check("ui.large-font","Large dialog font"))
	specs.append(D.label("Visible messages"))
	var filters: Array=[]
	for row in [["show_talk","Talk"],["show_shout","Shout"],["show_whisper","Whisper"],["show_tell","Tell"],["show_party","Party"],["show_dm","DM"],["show_system","Combat / server"]]: filters.append(D.check(row[0],row[1]))
	specs.append(D.control("row","",{},filters.slice(0,4))); specs.append(D.control("row","",{},filters.slice(4)))
	specs.append(D.label("Drag the top bar for height; Alt-drag it to move.\nDrag its top-right edge for width. Right-click for chat filters;\nShift-right-click for these settings.",true))
	specs.append(D.control("row","",{},[D.button("original","Original-style preset"),D.button("latest","Jump to latest")]))
	var built:=MenuBuilder.build(content,specs); assert(str(built.error).is_empty(),str(built.error)); fields=built.nodes
	for key in Preferences.DEFAULTS:
		if not fields.has(key): continue
		if fields[key] is OptionButton: fields[key].item_selected.connect(func(index):change(key,fields[key].get_item_id(index)))
		elif fields[key] is CheckBox: fields[key].toggled.connect(func(value):change(key,value))
		else: fields[key].value_changed.connect(func(value):change(key,float(value)/100.0 if key=="opacity" else int(value)))
	fields.original.pressed.connect(func():
		values=Preferences.DEFAULTS.duplicate(); publish(); original_requested.emit()
		if not settings_path.is_empty():
			var config:=ConfigFile.new(); config.load(settings_path); config.set_value("chat-hud","height0",134.0); config.set_value("chat-hud","height1",134.0); config.save(settings_path)
		refresh())
	fields.latest.pressed.connect(func():latest_requested.emit())
	open_settings(); hide()
func refresh() -> void:
	updating=true
	for key in Preferences.DEFAULTS:
		if not fields.has(key): continue
		if fields[key] is OptionButton: fields[key].select(fields[key].get_item_index(int(values[key])))
		elif fields[key] is CheckBox: fields[key].set_pressed_no_signal(bool(values[key]))
		else: fields[key].set_value_no_signal(float(values[key])*100.0 if key=="opacity" else float(values[key]))
	updating=false
func open_settings() -> void:
	values=Preferences.load_settings(settings_path); refresh(); show(); move_to_front(); _clamp()
func change(key: String,value: Variant) -> void:
	if updating: return
	values[key]=value; values=Preferences.clean(values); publish()
func publish() -> void:
	Preferences.save_settings(settings_path,values); settings_changed.emit(values.duplicate(true))
func reflect(value: Dictionary) -> void:
	values=Preferences.clean(value); refresh()
func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: hide(); get_viewport().set_input_as_handled()
