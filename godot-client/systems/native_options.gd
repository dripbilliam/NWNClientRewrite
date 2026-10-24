extends "res://systems/draggable_panel.gd"

signal inventory_preference(value: bool)
signal debug_preference(value: bool)
signal fps_preference(value: bool)
signal feedback_preference(values: Dictionary)
signal camera_preference(mode: int)
signal request(message: Dictionary)
var preference_path := "user://native-options.cfg"
var creature: CheckBox
var show_creature_slots := false
var debug_enabled := false
var show_fps := true
var debug_toggle: CheckBox
var fps_toggle: CheckBox
var installation
var tabs: TabContainer
var floating_feedback := true
var damage_totals_only := false
var floating_toggle: CheckBox
var totals_toggle: CheckBox
var camera_mode := 1
var camera_choice: OptionButton

func setup(storage: String = "user://native-menu-layout.cfg", preferences: String = "user://native-options.cfg") -> void:
	preference_path = preferences
	configure("Options", "options", Vector2(550, 120), storage)
	var config := ConfigFile.new()
	if config.load(preference_path) == OK: show_creature_slots = bool(config.get_value("inventory", "show_creature_slots", false))
	debug_enabled = bool(config.get_value("presentation", "debug_window", false)); show_fps = bool(config.get_value("presentation", "show_fps", true))
	var floating_value: Variant = config.get_value("feedback", "floating", true)
	var totals_value: Variant = config.get_value("feedback", "total_damage", false)
	floating_feedback = floating_value if floating_value is bool else true
	damage_totals_only = totals_value if totals_value is bool else false
	var camera_value: Variant = config.get_value("camera","mode",1)
	camera_mode = int(camera_value) if camera_value is int and camera_value in [0,1,2] else 1
	tabs = TabContainer.new(); tabs.custom_minimum_size = Vector2(510, 500); content.add_child(tabs)
	var game := VBoxContainer.new(); game.name = "Game"; tabs.add_child(game)
	creature = CheckBox.new()
	creature.text = "Show creature equipment slots"
	creature.focus_mode = Control.FOCUS_NONE
	creature.button_pressed = show_creature_slots
	creature.toggled.connect(func(value):
		show_creature_slots = value
		persist("inventory", "show_creature_slots", value)
		inventory_preference.emit(value))
	game.add_child(creature)
	fps_toggle = CheckBox.new(); fps_toggle.text = "Show FPS counter"; fps_toggle.focus_mode = Control.FOCUS_NONE; fps_toggle.button_pressed = show_fps; game.add_child(fps_toggle)
	fps_toggle.toggled.connect(func(value): show_fps = value; persist("presentation", "show_fps", value); fps_preference.emit(value))
	debug_toggle = CheckBox.new(); debug_toggle.text = "Show debug window"; debug_toggle.focus_mode = Control.FOCUS_NONE; debug_toggle.button_pressed = debug_enabled; game.add_child(debug_toggle)
	debug_toggle.toggled.connect(func(value): debug_enabled = value; persist("presentation", "debug_window", value); debug_preference.emit(value))
	floating_toggle = CheckBox.new(); floating_toggle.text = "Floating combat feedback"; floating_toggle.focus_mode = Control.FOCUS_NONE; floating_toggle.button_pressed = floating_feedback; game.add_child(floating_toggle)
	floating_toggle.toggled.connect(func(value): floating_feedback = value; persist("feedback", "floating", value); feedback_preference.emit(feedback_values()))
	totals_toggle = CheckBox.new(); totals_toggle.text = "Show total damage only"; totals_toggle.focus_mode = Control.FOCUS_NONE; totals_toggle.button_pressed = damage_totals_only; game.add_child(totals_toggle)
	totals_toggle.toggled.connect(func(value): damage_totals_only = value; persist("feedback", "total_damage", value); feedback_preference.emit(feedback_values()))
	var camera_row := HBoxContainer.new(); game.add_child(camera_row)
	var camera_label := Label.new(); camera_label.text = "Camera"; camera_row.add_child(camera_label)
	camera_choice = OptionButton.new(); camera_choice.focus_mode = Control.FOCUS_NONE; camera_row.add_child(camera_choice)
	for value in [[1,"Top-down"],[0,"Chase"],[2,"Stiff chase"]]: camera_choice.add_item(value[1],value[0])
	show_camera_mode(camera_mode)
	camera_choice.item_selected.connect(func(index): camera_mode = camera_choice.get_item_id(index); persist("camera","mode",camera_mode); camera_preference.emit(camera_mode))
	installation = preload("res://systems/client_setup.gd").new(); installation.name = "Mods and CD key"; tabs.add_child(installation); installation.setup(); installation.request.connect(func(value): request.emit(value))
	visibility_changed.connect(func():
		if visible: installation.open()
		else: installation.close())
	hide()

func persist(section: String, key: String, value: Variant) -> void:
	if preference_path.is_empty(): return
	var saved := ConfigFile.new(); saved.load(preference_path); saved.set_value(section, key, value); saved.save(preference_path)

func debug_closed() -> void:
	debug_enabled = false; debug_toggle.set_pressed_no_signal(false); persist("presentation", "debug_window", false)

func feedback_values() -> Dictionary:
	return {"floatingFeedback":floating_feedback,"damageTotalsOnly":damage_totals_only}

func show_camera_mode(mode: int) -> void:
	if mode in [0,1,2]: camera_choice.select(camera_choice.get_item_index(mode))
