extends CanvasLayer
const Numbers=preload("res://systems/native_data/browser_numbers.gd")
var fallback_list_builds:=0

signal request(message: Dictionary)
signal closed
signal login_profiles_requested
var connection := 0
var view_id := -1
var state: Dictionary = {}
var panel: PanelContainer
var host_edit: LineEdit
var port_edit: SpinBox
var name_edit: LineEdit
var password_edit: LineEdit
var key_edit: LineEdit
var filter_edit: LineEdit
var sort_edit: OptionButton
var tab_buttons: Dictionary = {}
var filters: Dictionary = {}
var tree: Tree
var info: Label
var status: Label
var policy_label: Label
var paging: Label
var refresh_button: Button
var inspect_button: Button
var favorite_button: Button
var connect_button: Button
var previous_button: Button
var next_button: Button
var apply_button: Button
var entries: Dictionary = {}
var selected := -1
var wanted := false
var loaded_draft := false
var direct_row: HBoxContainer
var list_box: VBoxContainer
var direct_dialog
var direct_button: Button
var profile_dialog
var profile_button: Button
var profile_capture: Array=[]
var profile_first:=false
var entry_menu
var modal_shield: Control
var entry_context:=false
var entry_stage:="browser"
var direct_return:="browser"
var profile_return:="browser"
var pending_direct:=false
var return_to_main:=false
var filter_dialog
var filter_button: Button
var filter_pending:=false
var native_browser
var details_pending:=false
var details_wanted:=false
var details_dialog
var password_dialog
var password_entry:=-1
var details_shield: Control
var selection_pending: Dictionary={}
var last_list_tab:="Internet"
var login_profile_signature:=""

func _ready() -> void:
	layer = 25
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	panel = PanelContainer.new(); root.add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = Color("0b1110fa"); style.border_color = Color("b9a16b"); style.set_border_width_all(1); style.set_content_margin_all(16); panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 8); scroll.add_child(box)
	var heading := Label.new(); heading.text = "Multiplayer · Servers"; heading.add_theme_font_size_override("font_size", 24); box.add_child(heading)
	policy_label = Label.new(); policy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(policy_label)
	var tabs := HBoxContainer.new(); box.add_child(tabs)
	for tab in ["Direct", "Internet", "History", "Favorites"]:
		var button := _button(tab, _tab.bind(tab)); button.toggle_mode = true; tabs.add_child(button); tab_buttons[tab] = button
	direct_row = HBoxContainer.new(); box.add_child(direct_row)
	_label(direct_row, "Address"); host_edit = _edit(direct_row, 255, "127.0.0.1"); host_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(direct_row, "UDP port"); port_edit = SpinBox.new(); port_edit.min_value = 1; port_edit.max_value = 65535; port_edit.value = 5121; port_edit.allow_greater = false; direct_row.add_child(port_edit)
	list_box = VBoxContainer.new(); box.add_child(list_box)
	var search := HBoxContainer.new(); list_box.add_child(search); _label(search, "Filter"); filter_edit = _edit(search, 128, "Server, module or address"); filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_edit = OptionButton.new(); search.add_child(sort_edit)
	for item in ["Name", "Module", "Players", "Latency"]: sort_edit.add_item(item)
	apply_button = _button("Apply", _filter); search.add_child(apply_button); filter_edit.text_submitted.connect(func(_value): _filter())
	var filter_row := HBoxContainer.new(); list_box.add_child(filter_row)
	for definition in [["local", "Local vault"], ["server", "Server vault"], ["password", "Password protected"]]:
		var toggle := CheckBox.new(); toggle.text = definition[1]; toggle.button_pressed = true; toggle.focus_mode = Control.FOCUS_NONE; filter_row.add_child(toggle); filters[definition[0]] = toggle
	tree = Tree.new(); tree.hide_root = true; tree.columns = 7; tree.column_titles_visible = true; tree.custom_minimum_size.y = 190; tree.size_flags_vertical = Control.SIZE_EXPAND_FILL; list_box.add_child(tree)
	var titles := ["Server / address", "Module", "Players", "Levels", "Vault", "PW", "Ping"]
	for index in titles.size():
		tree.set_column_title(index, titles[index]); tree.set_column_expand(index, index < 2); tree.set_column_custom_minimum_width(index, 52 if index > 1 else 170)
	tree.item_selected.connect(_select); tree.item_activated.connect(_inspect)
	var pages := HBoxContainer.new(); list_box.add_child(pages); previous_button = _button("Previous", _page.bind(-1)); pages.add_child(previous_button); paging = Label.new(); paging.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pages.add_child(paging); next_button = _button("Next", _page.bind(1)); pages.add_child(next_button)
	info = Label.new(); info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.custom_minimum_size.y = 70; box.add_child(info)
	var player := HBoxContainer.new(); box.add_child(player); _label(player, "Player name"); name_edit = _edit(player, 64, "Player name"); name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _label(player, "Server password"); password_edit = _edit(player, 255, "Optional"); password_edit.secret = true; password_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var key_row := HBoxContainer.new(); box.add_child(key_row); _label(key_row, "CD key"); key_edit = _edit(key_row, 41, "Leave blank to use the key saved in Options"); key_edit.secret = true; key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(status)
	var buttons := HBoxContainer.new(); box.add_child(buttons); refresh_button = _button("Refresh", func(): _send("refresh")); buttons.add_child(refresh_button); inspect_button = _button("Server info", _inspect); buttons.add_child(inspect_button); favorite_button = _button("Toggle favorite", _favorite); buttons.add_child(favorite_button); connect_button = _button("Connect", _join); buttons.add_child(connect_button); buttons.add_child(_button("Back", back))
	direct_button=_button("Direct Connect",open_direct); buttons.add_child(direct_button); direct_button.hide()
	profile_button=_button("Player Name",open_profile); buttons.add_child(profile_button); profile_button.hide()
	filter_button=_button("Filters…",open_filters); buttons.add_child(filter_button); filter_button.hide()
	panel.hide(); get_viewport().size_changed.connect(place)

func configure_native(painter,text,catalog,cache_path: String) -> void:
	if is_instance_valid(direct_dialog): return
	direct_dialog=load("res://systems/native_direct_connect.gd").new(); panel.get_parent().add_child(direct_dialog)
	direct_dialog.configure(painter,text,catalog,cache_path); direct_dialog.confirmed.connect(confirm_direct); direct_dialog.canceled.connect(return_direct)
	direct_dialog.prepared.connect(func():
		if wanted and state.get("kind","")=="browser-view": receive(state))
	direct_button.show(); direct_button.disabled=true
	profile_dialog=load("res://systems/native_player_profile.gd").new(); panel.get_parent().add_child(profile_dialog)
	profile_dialog.configure(painter,text,catalog,cache_path); profile_dialog.profile_confirmed.connect(confirm_profile); profile_dialog.login_profiles_requested.connect(func():login_profiles_requested.emit()); profile_dialog.canceled.connect(func():
		if profile_first: close()
		elif wanted: entry_stage=profile_return; refresh_entry())
	profile_dialog.prepared.connect(func():
		if wanted and state.get("kind","")=="browser-view": receive(state))
	profile_dialog.external_notice_closed.connect(refresh_entry)
	profile_button.show(); profile_button.disabled=true
	entry_menu=load("res://systems/native_entry_menu_frame.gd").new(); panel.get_parent().add_child(entry_menu); entry_menu.configure(painter,text,catalog,cache_path,"pre_multiplayer"); entry_menu.action_requested.connect(entry_action); entry_menu.prepared.connect(refresh_entry); entry_menu.artwork_ready.connect(refresh_entry); entry_menu.start()
	filter_dialog=load("res://systems/native_server_filters.gd").new(); panel.get_parent().add_child(filter_dialog); filter_dialog.configure(painter,text,catalog,cache_path)
	filter_dialog.filters_confirmed.connect(confirm_filters); filter_dialog.canceled.connect(refresh_entry); filter_dialog.prepared.connect(func():
		if wanted and state.get("kind","")=="browser-view": receive(state))
	modal_shield=Control.new(); panel.get_parent().add_child(modal_shield); modal_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); modal_shield.mouse_filter=Control.MOUSE_FILTER_STOP; modal_shield.hide()
	var parent:=panel.get_parent(); parent.move_child(entry_menu,1); parent.move_child(modal_shield,2); parent.move_child(direct_dialog,3); parent.move_child(filter_dialog,4); parent.move_child(profile_dialog,5)
	filter_button.show(); filter_button.disabled=true
	native_browser=load("res://systems/native_server_browser.gd").new(); parent.add_child(native_browser); native_browser.configure(painter,text,catalog,cache_path); native_browser.action_requested.connect(native_browser_action); native_browser.prepared.connect(refresh_entry)
	parent.move_child(native_browser,1); parent.move_child(entry_menu,2); parent.move_child(modal_shield,3); parent.move_child(direct_dialog,4); parent.move_child(filter_dialog,5); parent.move_child(profile_dialog,6)
	details_dialog=load("res://systems/native_server_details.gd").new(); parent.add_child(details_dialog); details_dialog.configure(painter,text,catalog,cache_path); details_dialog.action_requested.connect(details_action); details_dialog.prepared.connect(refresh_entry)
	password_dialog=load("res://systems/native_server_password.gd").new(); parent.add_child(password_dialog); password_dialog.configure(painter,text,catalog,cache_path); password_dialog.password_confirmed.connect(confirm_password); password_dialog.canceled.connect(func():password_entry=-1; refresh_entry())
	details_shield=Control.new(); parent.add_child(details_shield); details_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); details_shield.mouse_filter=Control.MOUSE_FILTER_STOP; details_shield.hide()
	parent.move_child(details_dialog,4); parent.move_child(details_shield,5); parent.move_child(direct_dialog,6); parent.move_child(filter_dialog,7); parent.move_child(password_dialog,8); parent.move_child(profile_dialog,9)

func open_details() -> void:
	if not wanted or state.get("busy",false) or selected<0 or not is_instance_valid(details_dialog): return
	details_wanted=true; details_pending=true
	if details_dialog.layout_ready: details_dialog.present(state)
	_inspect(); refresh_entry()

func details_action(operation: String,capture: Array) -> void:
	if not wanted or capture!=[connection,view_id]: return
	if operation=="close":
		details_wanted=false; details_dialog.dismiss()
		if details_pending and state.get("busy",false): _send("cancel-inspect")
		details_pending=false; refresh_entry(); return
	if state.get("busy",false): return
	if operation=="join": _join()
	elif operation in ["next","previous"]: details_pending=true; _send("details-step",{"direction":1 if operation=="next" else -1})
	refresh_entry()

func confirm_password(password: String,capture: Array) -> void:
	if not wanted or capture!=[connection,view_id] or selected!=password_entry or state.get("busy",false): return
	password_entry=-1; submit_selected_join(password)

func native_browser_action(operation: String,fields: Dictionary,capture: Array) -> void:
	if not wanted or capture!=[connection,view_id]: return
	if operation=="back": back(); return
	# A list's retained keyboard focus cannot navigate underneath a modal.
	for dialog in [details_dialog,password_dialog,profile_dialog,direct_dialog,filter_dialog]:
		if is_instance_valid(dialog) and dialog.visible: return
	if operation=="select":
		if not entries.has(int(fields.get("entryId",-1))): return
		var activate: bool=fields.get("activate",false)
		if state.get("busy",false):
			if activate and selection_pending.get("capture",[])==capture and selection_pending.get("entryId",-1)==int(fields.entryId): selection_pending.activate=true
		elif activate and selected==int(fields.entryId): _join()
		else: start_selection("select",{"entryId":int(fields.entryId)},activate)
		refresh_entry(); return
	if operation=="activate-current":
		if state.get("busy",false):
			if selection_pending.get("capture",[])==capture: selection_pending.activate=true
		else: _join()
		refresh_entry(); return
	if state.get("busy",false): return
	match operation:
		"profiles": login_profiles_requested.emit()
		"tab": _tab(str(fields.tab))
		"direct": open_direct()
		"filters": open_filters()
		"selection-step": start_selection(operation,fields,false)
		"page","sort-column","refresh","game-type": _send(operation,fields)
		"visibility": _send("filter",{"filter":state.get("filter",""),"sort":state.get("sort","Players"),"filters":fields.filters})
		"favorite":
			if selected>=0: _send("favorite",{"direct":false,"entryId":selected,"on":fields.on})
		"inspect":
			if selected>=0: open_details()
		"join": _join()
	refresh_entry()

func start_selection(operation: String,fields: Dictionary,activate: bool) -> void:
	selection_pending={"capture":[connection,view_id],"tab":state.get("tab",""),"entryId":int(fields.get("entryId",-1)),"activate":activate,"endpoint":{}}
	if operation=="select":
		var row: Dictionary=entries[int(fields.entryId)]; selection_pending.endpoint={"host":row.host,"port":row.port}
	_send(operation,fields)

func finish_selection(message: Dictionary) -> void:
	if selection_pending.is_empty() or message.get("busy",false) or view_id<=int(selection_pending.capture[1]): return
	var pending:=selection_pending.duplicate(true); selection_pending.clear()
	if not pending.activate or not wanted or not entry_context or entry_stage!="browser" or pending.capture[0]!=connection or pending.tab!=state.get("tab","") or selected<0: return
	var ack: Dictionary=message.get("selectionAck",{}) if message.get("selectionAck") is Dictionary else {}
	var row: Dictionary=entries.get(selected,{})
	if int(ack.get("requestViewId",-1))!=int(pending.capture[1]) or str(ack.get("host",""))!=str(row.get("host","")) or int(ack.get("port",-1))!=int(row.get("port",0)): return
	if not pending.endpoint.is_empty() and (pending.endpoint.host!=row.get("host") or int(pending.endpoint.port)!=int(row.get("port",0))): return
	for dialog in [details_dialog,password_dialog,profile_dialog,direct_dialog,filter_dialog]:
		if is_instance_valid(dialog) and dialog.visible: return
	_join(); refresh_entry()

func browser_visible() -> bool:
	return panel.visible or is_instance_valid(native_browser) and native_browser.visible

func open_filters() -> void:
	if not wanted or view_id<0 or state.get("busy",false) or state.get("tab","")!="Internet" or not is_instance_valid(filter_dialog) or not filter_dialog.layout_ready: return
	if filter_dialog.visible or is_instance_valid(direct_dialog) and direct_dialog.visible or is_instance_valid(profile_dialog) and profile_dialog.visible: return
	if filter_dialog.open_filters(state.get("advancedFilters",{}),[connection,view_id]): refresh_entry()

func confirm_filters(values: Dictionary,capture: Array) -> void:
	if not wanted or capture!=[connection,view_id] or state.get("busy",false): return
	filter_pending=true; _send("advanced-filter",{"values":values}); refresh_entry()

func open_profile(destination: String="") -> void:
	if not wanted or view_id<0 or state.get("busy",false) or not is_instance_valid(profile_dialog) or not profile_dialog.layout_ready: return
	profile_return=entry_stage if destination.is_empty() else destination
	if is_instance_valid(direct_dialog): direct_dialog.dismiss()
	if profile_dialog.open_profile(name_edit.text,[connection,view_id]): panel.hide(); refresh_entry()

func confirm_profile(player_name: String,save_default: bool,capture: Array) -> void:
	if not wanted or capture!=[connection,view_id] or state.get("busy",false): return
	profile_capture=capture.duplicate(); _send("profile",{"values":{"name":player_name,"saveDefault":save_default}})

func profile_result(message: Dictionary) -> void:
	if not wanted or profile_capture!=[connection,int(message.get("requestViewId",-1))] or not is_instance_valid(profile_dialog) or not profile_dialog.pending: return
	profile_capture.clear(); profile_dialog.set_pending(false)
	if message.get("accepted",false):
		name_edit.text=str(message.name); profile_dialog.dismiss(); profile_first=false
		if profile_return=="direct": pending_direct=true
		else: entry_stage=profile_return
		refresh_entry()
	else: profile_dialog.show_notice(0,str(message.get("text","Profile could not be saved")))

func open_direct() -> void:
	if not wanted or view_id<0 or state.get("busy",false) or not state.get("canJoin",false) or not is_instance_valid(direct_dialog): return
	if is_instance_valid(profile_dialog) and profile_dialog.visible: return
	if name_edit.text.is_empty() and is_instance_valid(profile_dialog): open_profile("direct"); return
	if not direct_dialog.layout_ready:
		status.text="Preparing Direct Connect resources…" if direct_dialog.failure.is_empty() else direct_dialog.failure; return
	var address:=host_edit.text+(":"+str(int(port_edit.value)) if int(port_edit.value)!=5121 else "")
	direct_return=entry_stage
	if direct_dialog.open(address,password_edit.text,[connection,view_id]): password_edit.clear(); entry_stage="direct"; refresh_entry()

func return_direct() -> void:
	if wanted: entry_stage=direct_return; refresh_entry()

func entry_action(tag: String) -> void:
	if not wanted or not entry_context or entry_stage!="entry" or state.get("busy",false): return
	match tag:
		"dirconnectbutton": open_direct()
		"intjoinbutton": entry_stage="browser"; entry_menu.dismiss(); _tab("Internet"); refresh_entry()
		"cancelbutton": close()

func refresh_entry() -> void:
	if is_instance_valid(entry_menu):
		var ready: bool=entry_menu.layout_ready and entry_menu.failure.is_empty() and not state.get("busy",false)
		entry_menu.set_context([connection,view_id],{"newbutton":false,"loadbutton":false,"intjoinbutton":ready,"lanjoinbutton":false,"dirconnectbutton":ready and state.get("canJoin",false),"cancelbutton":ready})
		for tag in ["newbutton","loadbutton","lanjoinbutton"]:
			if entry_menu.buttons.has(tag): entry_menu.buttons[tag].tooltip_text="LAN discovery is not implemented yet." if tag=="lanjoinbutton" else "Hosting a new or saved game is not implemented yet."
		entry_menu.position=((get_viewport().get_visible_rect().size-entry_menu.size)*0.5).max(Vector2.ZERO)
		entry_menu.visible=wanted and entry_context and not profile_first and entry_menu.art_ready() and (entry_stage=="entry" or entry_stage=="direct" and direct_return=="entry")
	var upper_modal: bool=is_instance_valid(profile_dialog) and profile_dialog.visible or is_instance_valid(direct_dialog) and direct_dialog.visible or is_instance_valid(filter_dialog) and filter_dialog.visible or is_instance_valid(password_dialog) and password_dialog.visible
	if is_instance_valid(details_dialog):
		if details_wanted and wanted and details_dialog.layout_ready: details_dialog.present(state)
		elif details_dialog.visible: details_dialog.dismiss()
	var modal: bool=upper_modal or is_instance_valid(details_dialog) and details_dialog.visible
	if modal: selection_pending.clear()
	if is_instance_valid(details_shield): details_shield.visible=upper_modal and is_instance_valid(details_dialog) and details_dialog.visible
	if is_instance_valid(modal_shield): modal_shield.visible=modal
	var source_visible: bool=entry_context and wanted and not profile_first and is_instance_valid(native_browser) and native_browser.layout_ready and str(state.get("tab","")) in ["Internet","History","Favorites"] and (entry_stage=="browser" or entry_stage=="direct" and direct_return=="browser")
	if is_instance_valid(native_browser):
		if source_visible: native_browser.set_view(state)
		native_browser.visible=source_visible
		if modal or not source_visible: native_browser.release_focus()
	# The source-defined frontend never exposes the prototype while a native
	# page or an authoritative opening view is preparing.
	panel.visible=wanted and not modal and not source_visible and not entry_context

func back() -> void:
	if entry_context and entry_stage=="browser":
		entry_stage="entry"; clear_secrets()
		if view_id>=0: _send("return-menu")
		refresh_entry()
	else: close()

func confirm_direct(address: String,password: String,capture: Array) -> void:
	if not wanted or capture!=[connection,view_id] or state.get("busy",false) or not state.get("canJoin",false): return
	var endpoint: Dictionary=preload("res://systems/native_data/connection_dialog_layout.gd").endpoint(address)
	var error:=""
	if int(endpoint.port)<1 or int(endpoint.port)>65535: error="Enter a server UDP port from 1 to 65535."
	elif str(endpoint.host).length()>255: error="The server address is too long."
	elif password.length()>255: error="The server password is too long."
	elif name_edit.text.is_empty() or name_edit.text.length()>64: error="Choose a valid player name before connecting."
	if not error.is_empty():
		status.text=error; entry_stage=direct_return
		if is_instance_valid(profile_dialog) and profile_dialog.layout_ready: profile_dialog.open_external_notice(error,[connection,view_id])
		refresh_entry(); return
	host_edit.text=str(endpoint.host); port_edit.value=int(endpoint.port)
	var values:=endpoint.duplicate(); values.merge({"name":name_edit.text,"password":password,"cdKey":key_edit.text},true)
	_send("join",{"direct":true,"entryId":-1,"values":values}); clear_secrets(); panel.show(); status.text="Connecting…"

func escape() -> bool:
	if not wanted: return false
	if is_instance_valid(profile_dialog) and profile_dialog.visible: profile_dialog.escape_profile()
	elif is_instance_valid(password_dialog) and password_dialog.visible: password_dialog.dismiss(); password_entry=-1; refresh_entry()
	elif is_instance_valid(details_dialog) and details_dialog.visible: details_action("close",[connection,view_id])
	elif is_instance_valid(filter_dialog) and filter_dialog.visible: filter_dialog.dismiss(); refresh_entry()
	elif is_instance_valid(direct_dialog) and direct_dialog.visible: direct_dialog.dismiss(); return_direct()
	else: back()
	return true

func close_native() -> void:
	if is_instance_valid(direct_dialog): direct_dialog.close()
	if is_instance_valid(profile_dialog): profile_dialog.close()
	if is_instance_valid(entry_menu): entry_menu.close()
	if is_instance_valid(filter_dialog): filter_dialog.close()
	if is_instance_valid(native_browser): native_browser.close()
	if is_instance_valid(details_dialog): details_dialog.close()
	if is_instance_valid(password_dialog): password_dialog.close()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = text; button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(callback); return button

func _label(parent: Node, text: String) -> void:
	var label := Label.new(); label.text = text; parent.add_child(label)

func _edit(parent: Node, limit: int, hint: String) -> LineEdit:
	var edit := LineEdit.new(); edit.max_length = limit; edit.placeholder_text = hint; edit.custom_minimum_size.x = 135; parent.add_child(edit); return edit

func place() -> void:
	var available := get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(1050, maxf(300, available.x - 32)), minf(760, maxf(240, available.y - 70)))
	panel.position = ((available - panel.size) * 0.5).max(Vector2.ZERO)
	refresh_entry()

func open_list() -> void:
	open(false,true,last_list_tab)

func open(ask_profile: bool=false,original_entry: bool=false,list_tab: String="") -> void:
	var list_page: bool=original_entry and list_tab in ["Internet","History","Favorites"]
	wanted = true; entry_context=original_entry; entry_stage="entry" if original_entry and not list_page else "browser"; profile_return=entry_stage; pending_direct=false; return_to_main=false; profile_first=ask_profile; view_id = -1; loaded_draft = false; clear_secrets(); panel.visible=not original_entry; status.text = "Reading saved servers…"; _enable(false); place(); _send("open",{"listTab":list_tab} if list_page else {})

func clear_secrets() -> void:
	password_edit.clear(); key_edit.clear()
	selection_pending.clear()
	if is_instance_valid(direct_dialog): direct_dialog.dismiss()
	if is_instance_valid(profile_dialog): profile_dialog.dismiss()
	if is_instance_valid(entry_menu): entry_menu.dismiss()
	if is_instance_valid(filter_dialog): filter_dialog.dismiss()
	filter_pending=false
	if is_instance_valid(native_browser): native_browser.dismiss()
	details_pending=false
	details_wanted=false; password_entry=-1
	if is_instance_valid(details_dialog): details_dialog.dismiss()
	if is_instance_valid(password_dialog): password_dialog.dismiss()
	if is_instance_valid(details_shield): details_shield.hide()
	profile_capture.clear()
	pending_direct=false
	if is_instance_valid(modal_shield): modal_shield.hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused == password_edit or focused == key_edit: focused.release_focus()

func reset(value: int) -> void:
	connection = value; wanted = false; loaded_draft = false; view_id = -1; state = {}; entries.clear(); selected = -1; clear_secrets(); panel.hide(); refresh_entry()

func close() -> void:
	return_to_main=entry_context or profile_first; wanted = false; clear_secrets(); panel.hide(); _send("close",{"leaveMultiplayer":entry_context}); closed.emit()

func _send(operation: String, fields: Dictionary = {}) -> void:
	if operation not in ["select","selection-step"]: selection_pending.clear()
	var message := {"kind":"browser-input", "connection":connection, "viewId":view_id, "operation":operation}; message.merge(fields, true)
	if operation not in ["open", "close"]: state["busy"] = true; _enable(false)
	request.emit(message)

func _tab(tab: String) -> void:
	if view_id >= 0 and not state.get("busy", false): _send("tab", {"tab":tab,"sourcePage":entry_context})

func _filter() -> void:
	if view_id < 0 or state.get("busy", false): return
	var values := {}; for key in filters: values[key] = filters[key].button_pressed
	_send("filter", {"filter":filter_edit.text, "sort":sort_edit.get_item_text(sort_edit.selected), "filters":values})

func _page(offset: int) -> void:
	_send("page", {"page":int(state.get("page", 0)) + offset})

func _select() -> void:
	var item := tree.get_selected()
	if item and not state.get("busy", false): _send("select", {"entryId":int(item.get_metadata(0))})

func _endpoint() -> Dictionary:
	return {"host":host_edit.text, "port":int(port_edit.value)}

func _selection() -> Dictionary:
	var direct: bool = state.get("tab", "Direct") == "Direct"
	return {"direct":direct, "entryId":selected, "values":_endpoint() if direct else {}}

func _inspect() -> void:
	if not inspect_button.disabled: _send("inspect", _selection())

func _favorite() -> void:
	if not favorite_button.disabled: _send("favorite", _selection())

func _join() -> void:
	if connect_button.disabled: return
	if state.get("tab","Direct")=="Direct" and is_instance_valid(direct_dialog): open_direct(); return
	if entry_context and entries.get(selected,{}).get("passwordRequired",false) and is_instance_valid(password_dialog):
		if password_dialog.layout_ready: password_entry=selected; password_dialog.open_password([connection,view_id]); refresh_entry()
		else: status.text="Preparing server password resources…" if password_dialog.failure.is_empty() else password_dialog.failure
		return
	submit_selected_join(password_edit.text)

func submit_selected_join(password: String) -> void:
	var fields := _selection(); fields.values.merge({"name":name_edit.text, "password":password_edit.text, "cdKey":key_edit.text}, true)
	fields.values.password=password
	_send("join", fields); clear_secrets(); _enable(false); status.text = "Connecting…"

func _enable(enabled: bool) -> void:
	for button in tab_buttons.values(): button.disabled = not enabled
	for button in [refresh_button, inspect_button, favorite_button, connect_button, previous_button, next_button, apply_button]: button.disabled = not enabled
	for edit in [host_edit, name_edit, password_edit, key_edit, filter_edit]: edit.editable = enabled
	port_edit.editable = enabled; sort_edit.disabled = not enabled; tree.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for toggle in filters.values(): toggle.disabled = not enabled
	if is_instance_valid(direct_dialog): direct_button.disabled=not enabled or not state.get("canJoin",false) or not direct_dialog.layout_ready
	if is_instance_valid(profile_dialog): profile_button.disabled=not enabled or not profile_dialog.layout_ready; name_edit.editable=false
	if is_instance_valid(filter_dialog):
		filter_button.visible=state.get("tab","")=="Internet"; filter_button.disabled=not enabled or not filter_dialog.layout_ready
		filter_button.tooltip_text=filter_dialog.failure if not filter_dialog.failure.is_empty() else "Preparing original filter resources…" if not filter_dialog.layout_ready else ""

func receive(message: Dictionary) -> void:
	if int(message.get("connection", -1)) != connection: return
	if message.kind=="browser-profile-result": profile_result(message); return
	if message.kind == "browser-closed": wanted = false; clear_secrets(); panel.hide(); return
	if message.kind == "browser-notice": status.text = str(message.text); clear_secrets(); return
	if message.kind != "browser-view" or not wanted and not message.get("reopen", false): return
	wanted = true; state = message.duplicate(true); view_id = int(message.viewId); panel.show()
	if entry_context and str(message.get("tab","")) in ["Internet","History","Favorites"]: last_list_tab=str(message.tab)
	if is_instance_valid(password_dialog) and password_dialog.visible and password_dialog.scope!=[connection,view_id]: password_dialog.dismiss(); password_entry=-1
	if details_wanted and message.has("detailsPosition") and int(message.detailsPosition.get("index",-1))<0: details_wanted=false
	if is_instance_valid(filter_dialog) and filter_dialog.visible and filter_dialog.scope!=[connection,view_id]: filter_dialog.dismiss()
	if entry_context and message.get("hasSessionProfile",false): profile_first=false
	if is_instance_valid(direct_dialog) and direct_dialog.visible and direct_dialog.scope!=[connection,view_id]:
		direct_dialog.dismiss(); entry_stage=direct_return
	if is_instance_valid(profile_dialog) and profile_dialog.visible and profile_capture.is_empty() and profile_dialog.scope!=[connection,view_id]:
		profile_dialog.revision+=1; profile_dialog.scope=[connection,view_id]
	if not loaded_draft:
		var draft: Dictionary = message.get("direct", {}); host_edit.text = str(draft.get("host", "127.0.0.1")); port_edit.value = int(draft.get("port", 5121)); name_edit.text = str(draft.get("name", "")); loaded_draft = true
	var profile_signature:=JSON.stringify(message.get("activeLoginProfile"))
	if profile_signature!=login_profile_signature:
		login_profile_signature=profile_signature; key_edit.clear(); password_edit.clear(); selection_pending.clear(); name_edit.text=str(message.get("direct",{}).get("name",name_edit.text))
		if is_instance_valid(profile_dialog) and profile_dialog.visible and not profile_dialog.pending: profile_dialog.edits.pnameeditbox.text=name_edit.text
	var direct := str(message.tab) == "Direct"; direct_row.visible = direct and not is_instance_valid(direct_dialog); list_box.visible = not direct
	for tab in tab_buttons: tab_buttons[tab].set_pressed_no_signal(tab == message.tab)
	filter_edit.text = str(message.get("filter", "")); sort_edit.select(["Name", "Module", "Players", "Latency"].find(str(message.get("sort", "Players"))))
	for key in filters: filters[key].set_pressed_no_signal(bool(message.get("filters", {}).get(key, true)))
	policy_label.text = "Local testing: only 127.0.0.1:5121 is enabled. Internet discovery is off." if message.get("localOnly", true) and not message.get("canDiscover", false) else "Only servers enabled for this session can be queried or joined."
	key_edit.placeholder_text = "Saved protected key will be used; enter only to replace for this login" if message.get("hasSavedCdKey", false) else "No saved key — enter a key or save one in Options"
	entries.clear(); selected = -1
	var fallback: bool=not (entry_context and is_instance_valid(native_browser) and native_browser.layout_ready and str(message.tab) in ["Internet","History","Favorites"])
	tree.set_block_signals(true)
	var tree_root: TreeItem
	if fallback: tree.clear(); tree_root=tree.create_item(); fallback_list_builds+=1
	for row in message.get("rows", []):
		var id := int(row.entryId); entries[id] = row
		if row.get("selected",false): selected=id
		if not fallback: continue
		var item := tree.create_item(tree_root); item.set_metadata(0,id)
		item.set_text(0, ("★ " if row.get("favorite", false) else "") + str(row.get("serverName", "")) + " · " + Numbers.endpoint(row)); item.set_text(1, str(row.get("moduleName", ""))); item.set_text(2, "%s / %s" % [Numbers.integer(row.get("playerCount")), Numbers.integer(row.get("maximumPlayers"))]); item.set_text(3, "%s–%s" % [Numbers.integer(row.get("minimumLevel")), Numbers.integer(row.get("maximumLevel"))]); item.set_text(4, "Local" if row.get("allowLocalVaultCharacters") == true else "Server" if row.get("allowLocalVaultCharacters") == false else "?"); item.set_text(5, "Yes" if row.get("passwordRequired", false) else ""); item.set_text(6, Numbers.integer(row.get("latency")))
		item.set_tooltip_text(0, "Enabled" if row.get("allowed", false) else "Not enabled for this session")
		if row.get("selected", false): selected = id; item.select(0)
	tree.set_block_signals(false)
	var detail = message.get("details"); info.text = "Enter an address or select a server, then request Server info."
	if detail is Dictionary:
		info.text = "%s · %s\n%s\n%s" % [detail.get("serverName", "Server"), Numbers.endpoint(detail), detail.get("moduleName", ""), str(detail.get("description", "")).left(4096)]
	status.text = str(message.get("status", "")); paging.text = "Page %s / %s · %s servers" % [int(message.get("page", 0)) + 1, Numbers.integer(message.get("pages",1)), Numbers.integer(message.get("total",0))]
	var enabled: bool = not message.get("busy", false); _enable(enabled)
	if details_pending and enabled: details_pending=false
	if filter_pending and enabled:
		filter_pending=false
		if not status.text.is_empty() and is_instance_valid(profile_dialog) and profile_dialog.layout_ready: profile_dialog.open_external_notice(status.text,[connection,view_id])
	refresh_button.visible = message.tab == "Internet"; refresh_button.disabled = not enabled or not message.get("canDiscover", false)
	previous_button.disabled = not enabled or int(message.get("page", 0)) == 0; next_button.disabled = not enabled or int(message.get("page", 0)) + 1 >= int(message.get("pages", 1))
	inspect_button.disabled = not enabled or not direct and (selected < 0 or not entries.get(selected, {}).get("allowed", false)); connect_button.disabled = not enabled or not message.get("canJoin", false) or not direct and (selected < 0 or not entries.get(selected, {}).get("allowed", false)); favorite_button.disabled = not enabled or not direct and selected < 0
	if entry_context and entry_stage=="direct" and enabled and not status.text.is_empty() and not direct_dialog.visible:
		entry_stage="entry"
		if profile_dialog.layout_ready: profile_dialog.open_external_notice(status.text,[connection,view_id])
		else: entry_stage="browser"
	place()
	if profile_first and is_instance_valid(profile_dialog) and profile_dialog.layout_ready and not profile_dialog.visible and not state.get("busy",false): open_profile()
	if pending_direct and not state.get("busy",false): pending_direct=false; entry_stage=profile_return if profile_return!="direct" else ("entry" if entry_context else "browser"); open_direct()
	refresh_entry()
	finish_selection(message)

func blocks_pointer(point: Vector2) -> bool:
	return panel.visible and panel.get_global_rect().has_point(point) or is_instance_valid(modal_shield) and modal_shield.visible or is_instance_valid(entry_menu) and entry_menu.visible and entry_menu.get_global_rect().has_point(point) or is_instance_valid(native_browser) and native_browser.visible and native_browser.get_global_rect().grow_individual(0,0,0,90).has_point(point)

func _exit_tree() -> void: close_native()
