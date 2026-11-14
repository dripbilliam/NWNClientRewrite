extends "res://systems/draggable_panel.gd"
signal request(message: Dictionary)
var wanted := false
var view_id := -1
var rows: Array = []
var list: VBoxContainer
var native_skin

func setup(storage: String = "user://native-menu-layout.cfg") -> void:
	configure("Players · PvP Attitude", "players", Vector2(180, 120), storage)
	var note := Label.new(); note.text = "Set your attitude toward another player."; content.add_child(note)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(400, 240); content.add_child(scroll)
	list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(list)
	close_requested.connect(close_players); reset()

func reset() -> void:
	if is_instance_valid(native_skin): native_skin.reset_view()
	wanted = false; view_id = -1; rows.clear(); clear_rows(); hide()
func clear_rows() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
func open() -> void:
	wanted = true
	if is_instance_valid(native_skin):
		if native_skin.layout_ready: native_skin.render()
		else: native_skin.try_admit()
	else: show()
	move_to_front(); request.emit({"kind":"players-open"})
func close_players() -> void:
	if wanted: request.emit({"kind":"players-close"})
	wanted = false; hide()
func receive(message: Dictionary) -> void:
	if message.kind == "players-closed": reset(); return
	if not wanted or message.kind != "players-view": return
	view_id = int(message.viewId); rows = message.rows; clear_rows()
	if is_instance_valid(native_skin) and native_skin.layout_ready: native_skin.render(); return
	if rows.is_empty():
		var empty := Label.new(); empty.text = "No players have been received."; list.add_child(empty)
	for row in rows:
		var box := VBoxContainer.new(); box.name = "Player%s" % int(row.entryId); list.add_child(box)
		var label := Label.new(); label.text = "%s · %s%s" % [row.label, row.account, " · DM" if row.dm else ""]; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x = 380; box.add_child(label)
		if row.self: continue
		var bar := HBoxContainer.new(); box.add_child(bar)
		var owner_view := view_id
		for likes in [true, false]:
			var button := Button.new(); button.text = "Set friendly" if likes else "Set hostile"; button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(func(): if owner_view == view_id and wanted: request.emit({"kind":"players-attitude","viewId":owner_view,"entryId":int(row.entryId),"likes":likes}))
			bar.add_child(button)
	call_deferred("_clamp")
