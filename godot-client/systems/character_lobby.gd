extends CanvasLayer
const Numbers=preload("res://systems/native_data/game_numbers.gd")
const IconPreloader=preload("res://systems/native_data/ui_icon_texture_preloader.gd")
const SharedRasters=preload("res://systems/native_data/shared_ui_rasters.gd")

signal request(message: Dictionary)
signal creation_requested
signal resource_progress(value: Dictionary)
var connection := 0
var state: Dictionary = {}
var panel: PanelContainer
var choices: ItemList
var preview: Label
var message: Label
var download_label: Label
var download_bar: ProgressBar
var join_button: Button
var play_button: Button
var create_button: Button
var cancel_button: Button
var disconnect_button: Button
var export_button: Button
var save_on_disconnect: CheckBox
var keys: Array[String] = []
var displayed_choice_rows: Array=[]
var last_auto_join := -1
var last_auto_choose := -1
var last_auto_play := -1
var preferred_auto_key := "installed:wizard.bic"
var window_column: VBoxContainer
var native_chooser
var native_catalog
var native_base_only:=false
var native_frontend:=false
var native_wait: VBoxContainer
var native_wait_text: Label
var native_wait_cancel: Button
var native_sync_bar: ProgressBar
var native_prepared_at:=-1
var native_selection: Dictionary={}
var native_serial:=0
var native_preview
var preferences=preload("res://systems/native_data/character_lobby_preferences.gd").new()
var local_catalog
var picker
var appearance_cache=preload("res://systems/native_data/character_appearance_cache.gd").new()
var appearance_identity: Array=[]
var appearance_connection:=-1
var confirmation
var confirmation_catalog
var delete_lease: Dictionary={}
var delete_serial:=0
var post_delete_index:=-1
var local_notice:=""
var server_icon_preloader
var server_icon_catalog
var server_icon_generation:=0
var server_icon_timer: Timer
var server_icon_progress: Dictionary={}

func _ready() -> void:
	local_catalog=preload("res://systems/native_local_character_catalog.gd").new(); add_child(local_catalog); local_catalog.completed.connect(func():
		if is_instance_valid(native_chooser): native_chooser.sync()
		if is_instance_valid(picker): picker.sync()
		settle_local_delete())
	server_icon_timer=Timer.new(); server_icon_timer.wait_time=0.2; add_child(server_icon_timer); server_icon_timer.timeout.connect(update_server_icon_wait)
	native_preview=preload("res://systems/native_character_preview.gd").new(); add_child(native_preview); native_preview.completed.connect(func():
		preview.text=_preview(record_preview())
		if is_instance_valid(native_chooser): native_chooser.preview_signature=""; native_chooser.sync()
		if is_instance_valid(picker): picker.sync())
	layer = 20
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 550)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.04, 0.98)
	style.border_color = Color(0.65, 0.56, 0.32)
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var column := VBoxContainer.new(); window_column=column
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "Multiplayer · Characters"
	heading.add_theme_font_size_override("font_size", 24)
	column.add_child(heading)
	message = Label.new()
	message.text = "127.0.0.1:5121 · Existing protected login\nConnect, choose a local or server character, then Play."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(700, 65)
	column.add_child(message)
	download_label = Label.new(); download_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(download_label)
	download_bar = ProgressBar.new(); download_bar.custom_minimum_size = Vector2(700,20); download_bar.show_percentage = false
	column.add_child(download_bar)
	var row := HBoxContainer.new()
	column.add_child(row)
	choices = ItemList.new()
	choices.custom_minimum_size = Vector2(310, 310)
	choices.item_selected.connect(_choose)
	row.add_child(choices)
	preview = Label.new()
	preview.custom_minimum_size = Vector2(375, 310)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(preview)
	save_on_disconnect = CheckBox.new()
	save_on_disconnect.text = "Save character when disconnecting"
	save_on_disconnect.button_pressed = true
	save_on_disconnect.focus_mode = Control.FOCUS_NONE
	column.add_child(save_on_disconnect)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	join_button = _button("Connect to local server", func(): _send({"kind": "lobby-join"}))
	buttons.add_child(join_button)
	play_button = _button("Play selected", _play)
	buttons.add_child(play_button)
	create_button = _button("Create character", func(): if state.get("canCreate", false): panel.hide(); creation_requested.emit())
	buttons.add_child(create_button)
	export_button = _button("Export character", func(): _send({"kind": "lobby-export"}))
	buttons.add_child(export_button)
	disconnect_button = _button("Disconnect", func(): _send({"kind": "lobby-disconnect", "saveCharacter": save_on_disconnect.button_pressed and can_save()}))
	buttons.add_child(disconnect_button)
	cancel_button = _button("Cancel connection", func(): _send({"kind":"lobby-cancel-join"}))
	column.add_child(cancel_button)
	column.add_child(_button("Return to game", func(): panel.hide()))
	get_viewport().size_changed.connect(_place)
	_place()
	apply_state({"connection": 0, "state": {"phase": "menu", "canJoin": false}})

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button

func _place() -> void:
	var dimensions := get_viewport().get_visible_rect().size
	panel.position = ((dimensions - panel.get_combined_minimum_size()) * 0.5).max(Vector2.ZERO if is_instance_valid(native_chooser) and native_chooser.visible else Vector2(0,70))

func _send(value: Dictionary) -> void:
	value["connection"] = connection
	request.emit(value)

func _choose(index: int) -> void:
	if index >= 0 and index < keys.size() and can_select():
		_send({"kind": "lobby-choose", "key": keys[index]})

func _play() -> void:
	if not native_selection.is_empty(): return
	var selected: Variant = state.get("selected")
	var visible_keys: Array=picker.row_keys if is_instance_valid(picker) else native_chooser.row_keys if is_instance_valid(native_chooser) else keys
	if selected != null and can_select() and visible_keys.has(selected):
		_send({"kind": "lobby-play", "key": str(selected)})

func apply_state(value: Dictionary) -> void:
	var previous_phase := str(state.get("phase", ""))
	if connection!=int(value.connection):
		retire_server_icons()
		native_selection.clear(); delete_lease={}; post_delete_index=-1
		if is_instance_valid(confirmation): confirmation.dismiss()
	connection = int(value.connection)
	state = value.state
	if value.get("localCharacterRoots") is Array: local_catalog.configure(value.localCharacterRoots)
	local_catalog.observe(connection,state.get("choices",[]))
	var phase := str(state.get("phase", "menu"))
	if phase=="playing":
		var scope:=appearance_cache.identity(state)
		if not scope.is_empty(): appearance_identity=scope; appearance_connection=connection
	var endpoint = state.get("endpoint")
	var address := "%s:%s" % [endpoint.host, int(endpoint.port)] if endpoint is Dictionary else "127.0.0.1:5121"
	message.text = "%s · %s%s\n%s" % [address, phase, " · Working…" if state.get("busy", false) else "", state.get("error", "")]
	var progress: Variant = state.get("resourceProgress")
	var loading: bool = phase == "resources" and progress is Dictionary
	download_label.visible = loading; download_bar.visible = loading
	if loading:
		var total := int(progress.get("total",0)); var completed := int(progress.get("completed",0)); var bytes := int(progress.get("downloadedBytes",0))
		download_bar.indeterminate = progress.get("phase") == "server-manifest" or total == 0
		download_bar.max_value = maxi(1,total); download_bar.value = completed
		download_label.text = "Reading server content manifest…" if progress.get("phase") == "server-manifest" else "%s · %s / %s resources · %.1f MiB received" % ["Downloading server content" if bytes > 0 else "Checking cached server content",completed,total,bytes/1048576.0]
		resource_progress.emit({"connection":connection,"phase":progress.get("phase"),"completed":completed,"total":total,"downloadedBytes":bytes,"canCancel":state.get("canCancelJoin",false),"canPlay":state.get("canSelect",false)})
	var visible_rows: Array=[]
	var next_keys: Array[String]=[]
	var selected_index: int=-1
	var selected_key: Variant=state.get("selected")
	for row in state.get("choices", []):
		next_keys.append(str(row.key))
		visible_rows.append([next_keys[-1],str(row.label)])
		if row.key==selected_key: selected_index=next_keys.size()-1
	if visible_rows!=displayed_choice_rows:
		displayed_choice_rows=visible_rows
		keys=next_keys
		choices.clear()
		for row in visible_rows: choices.add_item(row[1])
	var selected_items:=choices.get_selected_items()
	if selected_index>=0:
		if selected_items.size()!=1 or selected_items[0]!=selected_index: choices.select(selected_index)
	elif not selected_items.is_empty(): choices.deselect_all()
	choices.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_button.visible = state.get("canCancelJoin", false)
	cancel_button.disabled = not state.get("canCancelJoin", false)
	join_button.disabled = not state.get("canJoin", false)
	play_button.disabled = not state.get("canSelect", false) or state.get("selected") == null
	create_button.disabled = not state.get("canCreate", false)
	disconnect_button.disabled = not state.get("connected", false) or phase == "disconnecting"
	save_on_disconnect.visible = can_save()
	export_button.disabled = phase not in ["playing", "area-loading"] or state.get("busy", false)
	native_preview.observe(connection,state.get("selected"),state.get("preview"),phase in ["character-selection","character-rejected"])
	preview.text = _preview(record_preview())
	call_deferred("_place")
	if state.get("creating", false) or native_frontend and phase in ["menu","disconnecting","closed"]: panel.hide()
	elif phase not in ["playing", "area-loading", "character"]:
		panel.show()
	elif phase != previous_phase:
		panel.hide()
	sync_native()
	finish_native_selection()
	if value.get("auto", false):
		_auto()

func prepare_native_frontend(painter,text,catalog,cache_path: String) -> void:
	native_frontend=true
	if not is_instance_valid(native_chooser): configure_native(painter,text,catalog,cache_path,true)
func configure_native(painter,text,catalog,cache_path: String,base_only: bool=false,icon_names: Array=[]) -> void:
	if is_instance_valid(native_chooser) and native_catalog==catalog and native_base_only==base_only:
		if native_frontend and not base_only and not is_instance_valid(server_icon_preloader): begin_server_icons(catalog,cache_path,icon_names)
		return
	native_preview.language=int(text.base.language)
	native_preview.observe(connection,state.get("selected"),state.get("preview"),str(state.get("phase","")) in ["character-selection","character-rejected"])
	if is_instance_valid(native_chooser):
		if native_catalog!=catalog or native_base_only!=base_only:
			native_catalog=catalog; native_base_only=base_only
			if native_frontend and not base_only:
				native_chooser.hide(); begin_server_icons(catalog,cache_path,icon_names)
			else: retire_server_icons()
			native_chooser.bind_data(text,catalog,cache_path,painter.art)
			print("NATIVE_CHOOSER_DATA_BOUND base_only=",base_only," ticks_ms=",Time.get_ticks_msec())
			sync_native()
		return
	configure_confirmation(painter,text,catalog,cache_path)
	native_catalog=catalog; native_base_only=base_only
	if native_frontend and not base_only: begin_server_icons(catalog,cache_path,icon_names)
	native_chooser=preload("res://systems/native_character_lobby.gd").new(); panel.add_child(native_chooser)
	native_chooser.configure(self,painter,text,catalog,cache_path); native_chooser.prepared.connect(sync_native); native_chooser.artwork_ready.connect(native_art_ready)
	if is_instance_valid(server_icon_preloader) and server_icon_preloader.finished: native_chooser.icon_preload_notice=server_icon_notice()
	print("NATIVE_CHOOSER_PREPARE base_only=",base_only," ticks_ms=",Time.get_ticks_msec())
	if not panel.visibility_changed.is_connected(native_panel_visibility): panel.visibility_changed.connect(native_panel_visibility)
	sync_native()
func native_panel_visibility() -> void:
	if not panel.visible: native_selection.clear()
func native_art_ready() -> void:
	native_prepared_at=Time.get_ticks_msec(); print("NATIVE_CHOOSER_READY base_only=",native_base_only," ticks_ms=",native_prepared_at); sync_native()
func retire_server_icons() -> void:
	server_icon_generation+=1
	if is_instance_valid(server_icon_timer): server_icon_timer.stop()
	if is_instance_valid(server_icon_preloader): server_icon_preloader.close(); server_icon_preloader.queue_free()
	server_icon_preloader=null; server_icon_catalog=null; server_icon_progress={}
	if is_instance_valid(native_chooser): native_chooser.icon_preload_notice=""
func begin_server_icons(catalog,cache_path: String,names: Array=[]) -> void:
	# Worker forks cannot own GPU images. Only the active main-thread server
	# catalog can prepare and retain a chooser's raster set.
	if catalog==null or not catalog.has_method("ui_asset_owner") or catalog.ui_asset_owner()==null:
		retire_server_icons(); return
	if server_icon_catalog==catalog and is_instance_valid(server_icon_preloader): return
	retire_server_icons()
	server_icon_catalog=catalog
	var lease: int=server_icon_generation
	server_icon_preloader=IconPreloader.new(); add_child(server_icon_preloader)
	server_icon_preloader.configure(catalog,cache_path,names)
	server_icon_preloader.texture_ready.connect(func(name: String,texture: Texture2D):
		if lease==server_icon_generation: SharedRasters.retain(catalog,name,texture))
	server_icon_preloader.completed.connect(func(stats: Dictionary):
		if lease!=server_icon_generation: return
		server_icon_progress=stats.duplicate(true); server_icon_timer.stop()
		if is_instance_valid(native_chooser): native_chooser.icon_preload_notice=server_icon_notice()
		sync_native())
	server_icon_preloader.start(); server_icon_progress=server_icon_preloader.progress()
	if not server_icon_preloader.finished: server_icon_timer.start()
func server_icon_notice() -> String:
	var failed:=int(server_icon_progress.get("failed",0)); var missing:=int(server_icon_progress.get("missing",0)); var notes: Array=[]
	if failed>0: notes.append("%d server icons could not be prepared: %s"%[failed,str(server_icon_preloader.failure).left(160)])
	if missing>0: notes.append("%d original icon references have no raster in this server catalog."%missing)
	return " ".join(notes)
func server_icon_fatal() -> bool:
	return is_instance_valid(server_icon_preloader) and server_icon_preloader.finished and int(server_icon_progress.get("failed",0))>0
func update_server_icon_wait() -> void:
	if not is_instance_valid(server_icon_preloader) or server_icon_preloader.finished: return
	server_icon_progress=server_icon_preloader.progress()
	if not is_instance_valid(native_wait) or not native_wait.visible: return
	var total:=int(server_icon_progress.get("total",0)); var done:=int(server_icon_progress.get("completed",0))
	native_wait_text.text="Preparing server item and spell icons: %d / %d"%[done,total]
	native_sync_bar.indeterminate=total==0; native_sync_bar.max_value=maxi(1,total); native_sync_bar.value=done; native_sync_bar.show()
	resource_progress.emit({"connection":connection,"phase":"server-item-spell-icons","completed":done,"total":total,"missing":int(server_icon_progress.get("missing",0)),"failed":int(server_icon_progress.get("failed",0)),"canCancel":state.get("canCancelJoin",false),"canPlay":false})
func show_native_wait() -> void:
	if is_instance_valid(native_chooser): native_chooser.hide()
	if is_instance_valid(picker): picker.hide()
	if not is_instance_valid(native_wait):
		var built=preload("res://systems/native_menu_builder.gd").build(panel,[{"kind":"column","id":"wait","children":[{"kind":"label","id":"text","properties":{"text":"Preparing character selection…"}},{"kind":"button","id":"cancel","properties":{"text":"Cancel"}}]}])
		native_wait=built.nodes.wait; native_wait_text=built.nodes.text; native_wait_cancel=built.nodes.cancel
		native_sync_bar=ProgressBar.new(); native_sync_bar.show_percentage=false; native_sync_bar.custom_minimum_size=Vector2(420,20); native_wait.add_child(native_sync_bar); native_wait.move_child(native_sync_bar,native_wait_cancel.get_index())
		native_wait_cancel.pressed.connect(func():
			if state.get("canCancelJoin",false): cancel_button.pressed.emit()
			elif state.get("connected",false) and (not state.get("busy",false) or server_icon_fatal()): _send({"kind":"lobby-disconnect","saveCharacter":false}))
	window_column.hide(); native_wait.show(); native_wait.theme=preload("res://systems/native_client_menu_style.gd").for_tree(get_tree())
	panel.remove_theme_stylebox_override("panel"); panel.custom_minimum_size=Vector2(766,527); panel.size=panel.custom_minimum_size
	native_wait_cancel.disabled=not state.get("canCancelJoin",false) and (not state.get("connected",false) or state.get("busy",false))
	native_wait_text.text="Preparing character selection…"
	if is_instance_valid(native_sync_bar): native_sync_bar.hide()
	if is_instance_valid(native_chooser) and not native_chooser.failure.is_empty(): native_wait_text.text="Character selection unavailable: "+native_chooser.failure
func show_sync_wait() -> void:
	if is_instance_valid(picker): picker.hide()
	panel.show(); show_native_wait()
	var phase:=str(state.get("phase","")); var progress: Variant=state.get("resourceProgress")
	if phase=="resources-unavailable": native_wait_text.text=str(state.get("error","Required server content could not be loaded."))
	elif phase=="resources" and progress is Dictionary:
		var total:=int(progress.get("total",0)); var completed:=int(progress.get("completed",0)); var bytes:=int(progress.get("downloadedBytes",0))
		native_sync_bar.show(); native_sync_bar.indeterminate=progress.get("phase")=="server-manifest" or total==0; native_sync_bar.max_value=maxi(1,total); native_sync_bar.value=completed
		native_wait_text.text="Reading server content manifest…" if progress.get("phase")=="server-manifest" else "%s · %s / %s resources · %.1f MiB received" % ["Downloading server content" if bytes>0 else "Checking cached server content",completed,total,bytes/1048576.0]
	elif phase=="resources": native_wait_text.text="Checking required server content…"
	else: native_wait_text.text="Connecting to server…"
func enable_picker() -> void:
	if is_instance_valid(picker): return
	picker=preload("res://systems/native_character_picker.gd").new(); add_child(picker); picker.configure(self)
	panel.visibility_changed.connect(sync_native); sync_native()
func sync_native() -> void:
	if is_instance_valid(native_wait): native_wait.hide()
	if native_frontend and panel.visible and str(state.get("phase","")) in ["connecting","resources","resources-unavailable"]:
		show_sync_wait(); _place(); return
	var selecting: bool=str(state.get("phase","")) in ["character-selection","character-rejected"] and not state.get("creating",false)
	if native_frontend and selecting and not native_base_only and server_icon_fatal():
		show_native_wait(); native_wait_text.text="Character selection unavailable: "+server_icon_notice(); native_sync_bar.hide(); native_wait_cancel.disabled=false; _place(); return
	if native_frontend and selecting and not native_base_only and is_instance_valid(server_icon_preloader) and not server_icon_preloader.finished:
		show_native_wait(); update_server_icon_wait(); _place(); return
	if is_instance_valid(picker):
		picker.sync()
		var detailed: bool=picker.visible and picker.details_page>=0 and is_instance_valid(native_chooser) and native_chooser.layout_ready
		window_column.visible=not picker.visible
		panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new() if picker.visible else fallback_style())
		if is_instance_valid(native_chooser):
			native_chooser.automatic_selection={}; native_chooser.visible=detailed
			if detailed:
				native_chooser.sync(); native_chooser.automatic_selection={}
				if native_chooser.page_index!=picker.details_page: native_chooser.select_page(picker.details_page)
		if detailed: panel.custom_minimum_size=native_chooser.definition.size; panel.size=panel.custom_minimum_size
		_place(); settle_local_delete(); return
	if is_instance_valid(native_wait): native_wait.hide()
	var portrait_warm: Dictionary={}
	if native_frontend and selecting and is_instance_valid(native_chooser) and native_chooser.has_method("warm_portraits"): portrait_warm=native_chooser.warm_portraits()
	if native_frontend and selecting and (not is_instance_valid(native_chooser) or not native_chooser.art_announced and not native_chooser.art_ready()): show_native_wait(); _place(); return
	if native_frontend and selecting and not portrait_warm.is_empty() and not portrait_warm.get("ready",false):
		show_native_wait()
		if not str(portrait_warm.get("failure","")).is_empty(): native_wait_text.text=str(portrait_warm.failure)
		else:
			native_wait_text.text="Preparing character portraits: %d / %d"%[int(portrait_warm.completed),int(portrait_warm.total)]
			native_sync_bar.max_value=maxi(1,int(portrait_warm.total)); native_sync_bar.value=int(portrait_warm.completed); native_sync_bar.show()
		_place(); return
	if not is_instance_valid(native_chooser) or not native_chooser.layout_ready: window_column.show(); return
	var show_native: bool=str(state.get("phase","")) in ["character-selection","character-rejected"] and not state.get("creating",false)
	native_chooser.visible=show_native; window_column.visible=not show_native
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new() if show_native else fallback_style())
	panel.custom_minimum_size=native_chooser.definition.size if show_native else Vector2(760,550); panel.size=panel.custom_minimum_size
	if show_native: native_chooser.sync()
	else: native_selection.clear()
	_place()
func configure_confirmation(painter,text,catalog,cache_path: String) -> void:
	if confirmation_catalog==catalog and is_instance_valid(confirmation): return
	if is_instance_valid(confirmation): confirmation.close(); confirmation.queue_free()
	confirmation_catalog=catalog; confirmation=preload("res://systems/native_confirmation.gd").new(); add_child(confirmation); confirmation.configure(painter,text,catalog,cache_path); confirmation.prepared.connect(sync_native); confirmation.answered.connect(confirm_delete)
func selected_local_row() -> Dictionary:
	for row in state.get("choices",[]):
		if row.key==state.get("selected"):
			var value: Dictionary=row.duplicate(true); value.isDM=local_catalog.values.get(row.key,{}).get("isDM",false); return value
	return {}
func delete_reason() -> String:
	if not can_select() or not native_selection.is_empty(): return "Select an available local character first."
	var visible_keys: Array=picker.row_keys if is_instance_valid(picker) else native_chooser.row_keys if is_instance_valid(native_chooser) else []
	if not visible_keys.has(state.get("selected")): return "Select a visible local character first."
	var reason:=preload("res://systems/native_data/local_character_mutation.gd").reason(selected_local_row(),local_catalog.roots)
	if not reason.is_empty(): return reason
	if is_instance_valid(confirmation) and not confirmation.failure.is_empty(): return "The original confirmation dialog is unavailable: "+confirmation.failure
	if not is_instance_valid(confirmation) or not confirmation.layout_ready: return "Preparing the original confirmation dialog."
	return ""
func begin_delete() -> void:
	if not delete_reason().is_empty(): return
	delete_serial+=1; local_notice=""; var row:=selected_local_row().duplicate(true); var visible_keys: Array=picker.row_keys if is_instance_valid(picker) else native_chooser.row_keys
	delete_lease={"connection":connection,"key":str(row.key),"row":row,"requestId":delete_serial,"index":visible_keys.find(row.key)}
	if not confirmation.ask(0x2910,0x42,0x43,[connection,delete_serial,str(row.key),str(row.nativeFile.sha256)]): delete_lease={}
	sync_native()
func confirm_delete(result: int,capture: Array) -> void:
	if delete_lease.is_empty(): return
	var lease: Dictionary=delete_lease
	if capture!=[lease.connection,lease.requestId,lease.key,str(lease.row.nativeFile.sha256)] or connection!=int(lease.connection) or state.get("selected")!=lease.key or not state.get("canSelect",false) or not panel.visible: delete_lease={}; sync_native(); return
	if not preload("res://systems/native_data/local_character_mutation.gd").accepted(result): delete_lease={}; sync_native(); return
	var removed:=preload("res://systems/native_data/local_character_mutation.gd").remove(lease.row,local_catalog.roots)
	if not removed.success: local_notice=str(removed.error); delete_lease={}; sync_native(); return
	if removed.get("dismissInstalled",false): local_notice="Installed character hidden from this list; original game files were not deleted."
	post_delete_index=int(lease.index); delete_lease.refreshing=true
	_send({"kind":"lobby-local-refresh","key":lease.key,"sha256":str(lease.row.nativeFile.sha256),"requestId":int(lease.requestId),"dismissInstalled":bool(removed.get("dismissInstalled",false))})
func settle_local_delete() -> void:
	if not delete_lease.is_empty():
		var ack: Variant=state.get("localRefreshAck")
		if not ack is Dictionary or ack.get("connection")!=connection or ack.get("requestId")!=delete_lease.requestId or ack.get("key")!=delete_lease.key: return
		if ack.get("accepted",true)==false: local_notice=str(state.get("error","The local character list could not be refreshed.")); post_delete_index=-1
		delete_lease={}
		if post_delete_index<0:
			if is_instance_valid(picker): picker.sync()
			if is_instance_valid(native_chooser): native_chooser.sync()
			return
	if post_delete_index<0 or not can_select() or not local_catalog.ready(): return
	var visible_keys: Array=picker.available_rows().map(func(row):return str(row.key)) if is_instance_valid(picker) else native_chooser.row_keys
	var index:=preload("res://systems/native_data/local_character_mutation.gd").next_selection(post_delete_index,visible_keys.size()); post_delete_index=-1
	if is_instance_valid(native_chooser): native_chooser.automatic_selection={}
	if index>=0:
		var notice:=local_notice; choose_native(str(visible_keys[index])); local_notice=notice
		if is_instance_valid(picker): picker.sync()
	elif is_instance_valid(picker): picker.sync()
func fallback_style() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new(); style.bg_color=Color(0.025,0.035,0.04,0.98); style.border_color=Color(0.65,0.56,0.32); style.set_border_width_all(1); style.set_content_margin_all(18); return style
func choose_native(key: String,activate: bool=false) -> void:
	if not can_select() or not keys.has(key) or not panel.visible: return
	local_notice=""
	if not native_selection.is_empty() and native_selection.key==key:
		if activate: native_selection.activate=true
		return
	if activate and state.get("selected")==key and native_selection.is_empty(): _play(); return
	native_serial+=1; native_selection={"connection":connection,"key":key,"requestId":native_serial,"activate":activate}
	_send({"kind":"lobby-choose","key":key,"requestId":native_serial})
	if is_instance_valid(native_chooser): native_chooser.sync()
	if is_instance_valid(picker): picker.sync()
func finish_native_selection() -> void:
	if native_selection.is_empty(): return
	if native_selection.connection!=connection or not panel.visible or not state.get("canSelect",false) or not keys.has(native_selection.key): native_selection.clear(); return
	var ack: Variant=state.get("selectionAck")
	if not ack is Dictionary or ack.get("requestId")!=native_selection.requestId: return
	var activate: bool=native_selection.activate and ack.get("key")==native_selection.key and state.get("selected")==native_selection.key
	native_selection.clear()
	if is_instance_valid(native_chooser): native_chooser.sync()
	if is_instance_valid(picker): picker.sync()
	if activate: _play()
func close_native() -> void:
	delete_lease={}; post_delete_index=-1; local_notice=""
	retire_server_icons()
	if is_instance_valid(confirmation): confirmation.close(); confirmation.queue_free()
	confirmation=null; confirmation_catalog=null
	native_selection.clear()
	if is_instance_valid(picker): picker.clear_source(not is_instance_valid(native_chooser))
	if is_instance_valid(native_preview): native_preview.observe(connection,null,null,false)
	if is_instance_valid(native_chooser):
		native_chooser.close(); panel.remove_child(native_chooser); native_chooser.queue_free()
	native_chooser=null; native_catalog=null; native_base_only=false; window_column.show(); panel.add_theme_stylebox_override("panel",fallback_style()); panel.custom_minimum_size=Vector2(760,550)
	if is_instance_valid(native_wait): native_wait.hide()
func save_last_seen(actor: Dictionary) -> bool:
	if appearance_connection!=connection or appearance_identity.is_empty(): return false
	var saved: bool=appearance_cache.save_seen(appearance_identity,actor); appearance_identity=[]; appearance_connection=-1; return saved
func _exit_tree() -> void:
	close_native()
	if is_instance_valid(picker): picker.close()
	if is_instance_valid(local_catalog): local_catalog.close()
	if is_instance_valid(native_preview): native_preview.close()

func can_save() -> bool:
	return state.get("connected",false) and state.get("localAllowed",false) and str(state.get("phase","")) in ["playing","area-loading"]

func _auto() -> void:
	# Bounded integration tests use the same native UI requests as a player.
	if server_icon_fatal(): return
	if state.get("canJoin", false) and last_auto_join == -1:
		last_auto_join = connection
		_send({"kind": "lobby-join"})
	elif state.get("canSelect", false) and last_auto_choose != connection:
		var index := keys.find(preferred_auto_key)
		if index >= 0:
			last_auto_choose = connection
			_choose(index)
	elif state.get("canSelect", false) and state.get("selected") == preferred_auto_key and state.get("preview") != null and last_auto_play != connection:
		last_auto_play = connection
		_play()

func configure_preview(directory: String) -> void: native_preview.configure(directory)
func needs_local_metadata() -> bool: return state.get("choices",[]).any(func(row):return row.get("source")!="server" and row.get("nativeFile") is Dictionary)
func failure_text(text_owner=null) -> String:
	var rejection: Variant=state.get("characterRejection")
	if text_owner!=null and rejection is Dictionary and (rejection.get("strRef") is float or rejection.get("strRef") is int):
		var resolved: String=text_owner.raw(rejection)
		if not resolved.is_empty(): return resolved
	return str(state.get("error",""))
func can_select() -> bool:
	if server_icon_fatal(): return false
	if not delete_lease.is_empty(): return false
	if not state.get("canSelect",false) or not local_catalog.ready(): return false
	if needs_local_metadata():
		if native_frontend and native_base_only: return false
		var source_text=picker.text if is_instance_valid(picker) and picker.catalog!=null else native_chooser.text_owner if is_instance_valid(native_chooser) else null
		if source_text==null or not source_text.tables.has("pregen"): return false
	return true
func catalog_choices(text) -> Array:
	var result: Array=[]
	for row in state.get("choices",[]):
		var item: Dictionary=row.duplicate(true)
		if row.get("source")!="server" and row.get("nativeFile") is Dictionary:
			if not local_catalog.ready() or not local_catalog.values.has(row.key): continue
			item.merge(local_catalog.values[row.key],true)
			item.pregenerated=preload("res://systems/native_data/local_character_metadata.gd").pregenerated(str(row.get("catalogStem","")),text.tables.get("pregen",{}))
			for field in ["firstName","lastName"]: item[field]=preload("res://systems/native_data/character_preview.gd").localized(item[field],int(text.base.language),0)
			item.label=text.name(item,-1)
			var ordinal: int=preload("res://systems/native_data/local_character_metadata.gd").ordinal(str(row.get("catalogStem",""))) if row.source!="vault" else 0
			if ordinal>0: item.label+=" ("+str(ordinal)+")"
		elif row.has("firstName") or row.has("lastName"):
			for field in ["firstName","lastName"]:
				if item.get(field) is Dictionary and item[field].has("entries"): item[field]=preload("res://systems/native_data/character_preview.gd").localized(item[field],int(text.base.language),0)
			item.label=text.name(item,-1)
		result.append(item)
	return result
func record_preview() -> Variant:
	var source: Variant=state.get("preview")
	return native_preview.value if source is Dictionary and source.get("format","")=="native-bic-file-v1" else source
func _preview(value: Variant) -> String:
	if not value is Dictionary:
		return "Select a character to inspect its server or local record.\n\nLocal-vault characters appear only when the server permits them."
	var first: Dictionary = value.get("firstName", {})
	var last: Dictionary = value.get("lastName", {})
	var lines: Array[String] = ["%s %s" % [first.get("text", ""), last.get("text", "")], "HP: %s / %s · XP: %s" % [Numbers.text(value.get("currentHitPoints"), "?"), Numbers.text(value.get("hitPoints"), "?"), Numbers.text(value.get("experience"), "?")]]
	for entry in value.get("classes", []):
		lines.append("Class %s · level %s" % [Numbers.text(entry.get("id"), "?"), Numbers.text(entry.get("level"), "?")])
	var abilities: Dictionary = value.get("abilities", {})
	for key in ["Str", "Dex", "Con", "Int", "Wis", "Cha"]:
		if abilities.has(key):
			lines.append("%s: %s" % [key, Numbers.text(abilities[key])])
	lines.append("Feats: %s · Known spells: %s" % [value.get("feats", []).size(), value.get("spells", []).size()])
	return "\n".join(lines)

func blocks_pointer(point: Vector2) -> bool:
	return (is_instance_valid(picker) and picker.visible) or (panel.visible and panel.get_global_rect().has_point(point))
