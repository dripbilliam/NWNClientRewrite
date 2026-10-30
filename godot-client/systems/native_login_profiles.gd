extends "res://systems/draggable_panel.gd"
signal request(message: Dictionary)
signal used
var connection:=0
var request_id:=0
var view_id:=-1
var wanted:=false
var busy:=false
var state: Dictionary={}
var rows: Array=[]
var selected_id: Variant=null
var drafting:=false
var profiles: OptionButton
var profile_label: LineEdit
var player_name: LineEdit
var cd_key: LineEdit
var notice: Label
var save_profile: Button
var use_profile: Button
var delete_profile: Button
var new_profile: Button
func setup(storage: String="user://native-menu-layout.cfg") -> void:
	configure("Login profiles","login-profiles",Vector2(240,120),storage); close_hides=false; close_requested.connect(close_panel)
	var built:=MenuBuilder.build(content,preload("res://systems/native_data/login_profiles_layout.gd").definition()); assert(str(built.error).is_empty())
	for key in ["profiles","profile_label","player_name","cd_key","notice","save_profile","use_profile","delete_profile","new_profile"]: set(key,built.nodes[key])
	profile_label.max_length=32; player_name.max_length=32; cd_key.max_length=41; cd_key.secret=true; cd_key.context_menu_enabled=false
	cd_key.placeholder_text="Enter a key for a new profile"
	profiles.item_selected.connect(select_row); new_profile.pressed.connect(new_draft); save_profile.pressed.connect(save); use_profile.pressed.connect(use_selected); delete_profile.pressed.connect(remove_selected)
	reset()
func reset() -> void:
	wanted=false; request_id+=1; view_id=-1; busy=false; state.clear(); rows.clear(); selected_id=null; drafting=false
	cd_key.clear(); profile_label.clear(); player_name.clear(); hide()
func open(default_name: String="",owner_connection: int=0) -> void:
	reset(); connection=owner_connection; wanted=true; show(); move_to_front(); player_name.text=default_name.left(32); notice.text="Reading saved login profiles…"; send_operation("open")
func close_panel() -> void:
	if wanted: send_operation("close")
	reset()
func send_operation(operation: String,fields: Dictionary={}) -> void:
	request_id+=1; busy=true; update_controls()
	var message:={"kind":"login-profile-input","connection":connection,"operation":operation,"requestId":request_id,"viewId":view_id}; message.merge(fields,true); request.emit(message)
func receive(message: Dictionary) -> void:
	if not wanted or int(message.get("connection",-1))!=connection or int(message.get("requestId",-1))!=request_id: return
	cd_key.clear(); busy=false
	if message.kind=="login-profiles-notice": notice.text=str(message.text); update_controls(); return
	if message.kind!="login-profiles-view": return
	state=message.duplicate(true); view_id=int(message.viewId); rows=message.profiles; selected_id=message.get("activeProfileId"); drafting=false
	profiles.clear(); profiles.add_item("Existing saved key / manual player name" if message.hasLegacyCdKey else "Manual login")
	var selected:=0
	for index in rows.size():
		profiles.add_item(str(rows[index].label)+" · "+str(rows[index].playerName))
		if rows[index].id==selected_id: selected=index+1
	profiles.select(selected); select_row(selected)
	notice.text="Disconnect before switching or changing login profiles." if message.locked else "Windows-protected key storage is unavailable." if not message.protectedStorageAvailable else "Profile saved. It will be used for the next connection." if message.operation=="save" else "Choose a saved profile or create a new one."
	if str(message.operation)=="select": used.emit(); close_panel()
	update_controls(); _clamp()
func select_row(index: int) -> void:
	cd_key.clear(); drafting=false
	if index>0 and index<=rows.size():
		var row: Dictionary=rows[index-1]; selected_id=row.id; profile_label.text=str(row.label); player_name.text=str(row.playerName); cd_key.placeholder_text="Saved key retained unless you enter a replacement"
	else:
		selected_id=null; profile_label.clear(); cd_key.placeholder_text="Leave blank to use the existing saved key" if state.get("hasLegacyCdKey",false) and rows.is_empty() else "Enter a key for a new profile"
	update_controls()
func new_draft() -> void:
	if busy or state.get("locked",true): return
	selected_id=null; drafting=true; profiles.select(-1); profile_label.clear(); player_name.clear(); cd_key.clear(); cd_key.placeholder_text="Leave blank to use the existing saved key" if rows.is_empty() and state.get("hasLegacyCdKey",false) else "Enter a key for a new profile"; update_controls(); profile_label.grab_focus()
func save() -> void:
	if save_profile.disabled: return
	var values:={"label":profile_label.text,"playerName":player_name.text}
	if selected_id!=null: values.id=selected_id
	if not cd_key.text.is_empty(): values.cdKey=cd_key.text
	cd_key.clear(); notice.text="Saving profile…"; send_operation("save",{"values":values})
	if values.has("cdKey"): values.cdKey=""
func use_selected() -> void:
	if not use_profile.disabled: notice.text="Selecting profile…"; send_operation("select",{"profileId":selected_id})
func remove_selected() -> void:
	if not delete_profile.disabled: notice.text="Deleting profile…"; send_operation("delete",{"profileId":selected_id})
func update_controls() -> void:
	if not is_instance_valid(profiles): return
	var locked: bool=busy or view_id<0 or state.get("locked",true)
	profiles.disabled=locked; new_profile.disabled=locked
	profile_label.editable=not locked; player_name.editable=not locked; cd_key.editable=not locked and state.get("protectedStorageAvailable",false)
	save_profile.disabled=locked or not state.get("protectedStorageAvailable",false)
	var usable: bool=rows.any(func(row):return row.id==selected_id and row.get("hasSavedCdKey",false)) if selected_id!=null else state.get("hasLegacyCdKey",false)
	use_profile.disabled=locked or drafting or not usable
	delete_profile.disabled=locked or selected_id==null
func _notification(what: int) -> void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and not visible and is_instance_valid(cd_key): cd_key.clear()
