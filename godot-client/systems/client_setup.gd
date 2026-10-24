extends VBoxContainer
signal request(message: Dictionary)
var wanted := false
var request_id := 0
var view_id := -1
var status: Dictionary = {}
var staged: Dictionary = {}
var rows: Array = []
var folder: LineEdit
var browse: Button
var defaults: Button
var mods: Tree
var key: LineEdit
var remove_key: CheckBox
var key_status: Label
var notice: Label
var save_button: Button
var reload_button: Button
var busy := false
var picker: FileDialog

func setup() -> void:
	add_child(label("Mods folder"))
	folder = LineEdit.new(); folder.editable = false; folder.focus_mode = Control.FOCUS_NONE; folder.placeholder_text = "Select the NWN Workshop content folder"; add_child(folder)
	var actions := HBoxContainer.new(); add_child(actions)
	browse = button(actions, "Browse…", func(): picker.popup_centered_ratio(0.7))
	defaults = button(actions, "Use default", func(): scan(str(status.get("defaultModsDirectory", ""))))
	mods = Tree.new(); mods.hide_root = true; mods.columns = 2; mods.set_column_expand(0, true); mods.set_column_expand(1, false); mods.set_column_custom_minimum_width(1, 110); mods.custom_minimum_size = Vector2(480, 160); mods.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(mods)
	add_child(label("Enabled mods apply globally, including their HAKs. Changes apply to the next connection."))
	key_status = label(""); add_child(key_status)
	key = LineEdit.new(); key.secret = true; key.max_length = 41; key.context_menu_enabled = false; key.placeholder_text = "Enter a CD key to save or replace"; add_child(key)
	add_child(label("Saved keys use Windows-protected storage for this Windows user."))
	remove_key = CheckBox.new(); remove_key.text = "Remove saved CD key"; remove_key.focus_mode = Control.FOCUS_NONE
	remove_key.toggled.connect(func(value):
		key.editable = not value and not busy and status.get("protectedStorageAvailable", false)
		if value: key.clear())
	add_child(remove_key)
	var footer := HBoxContainer.new(); add_child(footer)
	save_button = button(footer, "Save", save_settings)
	reload_button = button(footer, "Reload", open)
	notice = label(""); add_child(notice)
	picker = FileDialog.new(); picker.title = "NWN Workshop mods folder"; picker.access = FileDialog.ACCESS_FILESYSTEM; picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR; picker.use_native_dialog = true; picker.dir_selected.connect(scan); add_child(picker)
	reset()

func label(text: String) -> Label:
	var item := Label.new(); item.text = text; item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; item.custom_minimum_size.x = 470; return item
func button(parent: Node, caption: String, action: Callable) -> Button:
	var item := Button.new(); item.text = caption; item.focus_mode = Control.FOCUS_NONE; item.pressed.connect(action); parent.add_child(item); return item
func scrub() -> void:
	key.clear(); remove_key.set_pressed_no_signal(false); key.editable = true
func reset() -> void:
	wanted = false; request_id += 1; view_id = -1; staged.clear(); status.clear(); rows.clear(); mods.clear(); scrub(); notice.text = ""
func open() -> void:
	wanted = true; request_id += 1; scrub(); notice.text = "Reading saved settings…"; set_busy(true)
	request.emit({"kind":"client-settings","operation":"open","requestId":request_id})
func close() -> void:
	if wanted: request.emit({"kind":"client-settings","operation":"close","requestId":request_id})
	reset()
func scan(directory: String) -> void:
	if not wanted or status.get("resourcesLocked", true): return
	request_id += 1; scrub(); set_busy(true); notice.text = "Reading installed mods…"
	request.emit({"kind":"client-settings","operation":"scan","requestId":request_id,"directory":directory})
func save_settings() -> void:
	if view_id < 0 or save_button.disabled: return
	var values: Dictionary = {}
	if not status.get("resourcesLocked", true):
		values.disabled = []
		for item in mods.get_root().get_children():
			if item.get_metadata(0) != null and not item.is_checked(0): values.disabled.append(int(item.get_metadata(0)))
	if not key.text.is_empty(): values.cdKey = key.text
	if remove_key.button_pressed: values.removeCdKey = true
	scrub(); set_busy(true); notice.text = "Saving…"; request_id += 1
	request.emit({"kind":"client-settings","operation":"save","requestId":request_id,"viewId":view_id,"values":values})
	if values.has("cdKey"): values.cdKey = ""
func receive(message: Dictionary) -> void:
	if not wanted or int(message.get("requestId", -1)) != request_id: return
	if message.kind == "settings-begin": staged = {"id":int(message.viewId),"status":message.status,"count":int(message.count),"rows":[]}
	elif message.kind == "settings-mods" and int(message.viewId) == int(staged.get("id", -1)): staged.rows.append_array(message.rows)
	elif message.kind == "settings-commit" and int(message.viewId) == int(staged.get("id", -1)) and staged.rows.size() == int(staged.count):
		view_id = int(staged.id); status = staged.status; rows = staged.rows; staged.clear(); render(); notice.text = "Disconnect to change mods." if status.resourcesLocked else "Settings ready."
	elif message.kind == "settings-notice": notice.text = str(message.text); set_busy(false)
func set_busy(value: bool) -> void:
	busy = value; save_button.disabled = busy or view_id < 0; reload_button.disabled = busy
	browse.disabled = busy or status.get("resourcesLocked", true); defaults.disabled = browse.disabled or str(status.get("defaultModsDirectory", "")).is_empty()
	key.editable = not busy and status.get("protectedStorageAvailable", false) and not remove_key.button_pressed; remove_key.disabled = busy or not status.get("hasSavedCdKey", false)
	if mods.get_root() != null:
		for item in mods.get_root().get_children():
			if item.get_metadata(0) != null: item.set_editable(0, not busy and not status.get("resourcesLocked", true))
func render() -> void:
	folder.text = str(status.modsDirectory); folder.tooltip_text = folder.text; browse.disabled = bool(status.resourcesLocked); defaults.disabled = browse.disabled or str(status.defaultModsDirectory).is_empty()
	key_status.text = "CD key saved for this Windows user." if status.hasSavedCdKey else "No CD key saved."; remove_key.disabled = not status.hasSavedCdKey; scrub()
	key.editable = bool(status.protectedStorageAvailable); key.placeholder_text = "Enter a replacement to change the saved key" if status.hasSavedCdKey else "Enter a CD key to save"
	if not status.protectedStorageAvailable: key_status.text += " Windows-protected storage is unavailable."
	mods.clear(); var root := mods.create_item()
	for row in rows:
		var item := mods.create_item(root); item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK); item.set_checked(0, bool(row.enabled)); item.set_editable(0, not status.resourcesLocked); item.set_text(0, str(row.label)); item.set_text(1, str(row.id)); item.set_metadata(0, int(row.entryId)); item.set_tooltip_text(0, str(row.directory))
	if rows.is_empty():
		var empty := mods.create_item(root); empty.set_text(0, "No mods found in this folder.")
	set_busy(false)
