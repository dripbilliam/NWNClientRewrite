extends "res://systems/native_direct_connect.gd"
# Original MULTI_LOGIN/OKPANEL; no server connection or fabricated persistence.
signal profile_confirmed(player_name: String,save_default: bool,capture: Array)
signal external_notice_closed
signal login_profiles_requested
const ProfilePlan=preload("res://systems/native_data/player_profile_layout.gd")
const Policy=preload("res://systems/native_data/player_profile.gd")
var notice_source: Dictionary={}
var notice_definition: Dictionary={}
var notice: Control
var notice_body: Label
var notice_button: Button
var notice_shield: Control
var pending:=false
var notice_ref:=0
var external_notice:=false
var login_profiles_button: Button
func configure(painter,text,catalog,cache_path: String) -> void:
	frame=painter; text_owner=text; mouse_filter=Control.MOUSE_FILTER_STOP; hide()
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(received)
	jobs[assets.request("multi_login",2047,"gff")]="@layout"; jobs[assets.request("okpanel",2047,"gff")]="@notice"
	get_viewport().size_changed.connect(place)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	if name in ["@layout","@notice"]:
		if str(result.value.get("type",""))!="GUI ": failure="Invalid original Player Profile GUI"; return
		if name=="@layout": source=result.value.root; collect(source)
		else: notice_source=result.value.root; collect(notice_source)
	else: models[name]=result.value
	if jobs.is_empty() and not source.is_empty() and not notice_source.is_empty() and failure.is_empty(): build()
func build() -> void:
	definition=ProfilePlan.parse(source,models); notice_definition=ProfilePlan.notice(notice_source,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	if not str(notice_definition.error).is_empty(): failure=str(notice_definition.error); return
	size=definition.size; custom_minimum_size=size; frame.image(definition.resource,definition.main,self)
	for tag in ProfilePlan.LABELS:
		var entry: Dictionary=definition.entries[tag]; var label: Label=frame.create_label(entry,self); labels[tag]=label
		label.clip_text=false; label.text="" if tag=="tguireason" else text_owner.raw({"strRef":int(entry.caption.get("Obj_StrRef",-1))}); label.minimum_size_changed.connect(place_label.bind(tag)); place_label(tag)
	var entry: Dictionary=definition.entries.pnameeditbox
	var edit: LineEdit=frame.create_edit(entry,self); edits.pnameeditbox=edit; edit.text_submitted.connect(submit_edit)
	for tag in ProfilePlan.BUTTONS:
		var data: Dictionary=definition.entries[tag]; var button: Button=frame.create_button(data,self,models,tag=="passwordcheck"); buttons[tag]=button
		if tag=="passwordcheck": button.toggle_mode=true
		var ref:=int(data.caption.get("Obj_StrRef",-1))
		if ref>=0 and ref!=4294967295: frame.button_caption(button,text_owner.raw({"strRef":ref}))
		button.button_down.connect(func():held[tag]={"revision":revision,"scope":scope.duplicate()})
		button.pressed.connect(invoke.bind(tag))
	login_profiles_button=Button.new(); add_child(login_profiles_button); login_profiles_button.text="Login profiles…"; login_profiles_button.position=Vector2((size.x-200)*0.5,75); login_profiles_button.size=Vector2(200,38); login_profiles_button.focus_mode=Control.FOCUS_NONE
	login_profiles_button.theme=preload("res://systems/native_client_menu_style.gd").for_tree(get_tree()); frame.font_style(login_profiles_button,{"AurString_Font":"fnt_galahad14"})
	login_profiles_button.pressed.connect(func():if visible and not pending and not notice.visible: login_profiles_requested.emit())
	notice_shield=Control.new(); add_child(notice_shield); notice_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); notice_shield.mouse_filter=Control.MOUSE_FILTER_STOP; notice_shield.hide()
	notice=Control.new(); add_child(notice); notice.mouse_filter=Control.MOUSE_FILTER_STOP; notice.size=notice_definition.size; notice.position=(size-notice.size)*0.5
	frame.image(notice_definition.resource,notice_definition.main,notice)
	notice_body=frame.create_label(notice_definition.entries.messagelabel,notice); notice_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notice_button=frame.create_button(notice_definition.entries.okbutton,notice,models); frame.button_caption(notice_button,text_owner.raw({"strRef":int(notice_definition.entries.okbutton.caption.get("Obj_StrRef",66))}))
	notice_button.button_down.connect(func():held["@notice"]={"revision":revision,"scope":scope.duplicate()})
	notice_button.pressed.connect(confirm_notice); notice.hide(); layout_ready=true; place(); prepared.emit()
func open_profile(player_name: String,capture: Array,reason: int=0) -> bool:
	if closed or not layout_ready or not failure.is_empty(): return false
	for child in get_children():
		if child is CanvasItem: child.show()
	dismiss(); revision+=1; scope=capture.duplicate(); edits.pnameeditbox.text=player_name; buttons.passwordcheck.set_pressed_no_signal(false)
	labels.tguireason.text=text_owner.raw({"strRef":0x2831 if reason==6 else 0x2836}) if reason in [6,8] else ""
	show(); move_to_front(); place(); edits.pnameeditbox.grab_focus(); return true
func invoke(tag: String) -> void:
	if closed or not layout_ready or not is_visible_in_tree() or pending or notice.visible or not buttons.has(tag) or buttons[tag].disabled: return
	var press: Dictionary=held.get(tag,{"revision":revision,"scope":scope}); held.erase(tag)
	if int(press.revision)!=revision or press.scope!=scope: return
	if tag=="passwordcheck": return
	if tag=="okbutton":
		var result:=Policy.confirmed(edits.pnameeditbox.text); edits.pnameeditbox.text=result.name
		if not result.accepted: show_notice(int(result.notice)); return
		set_pending(true); profile_confirmed.emit(str(result.name),buttons.passwordcheck.button_pressed,scope.duplicate())
	else: dismiss(); canceled.emit()
func set_pending(value: bool) -> void:
	pending=value
	if is_instance_valid(login_profiles_button): login_profiles_button.disabled=value
	for tag in buttons: buttons[tag].disabled=value and tag!="passwordcheck"
	if edits.has("pnameeditbox"): edits.pnameeditbox.editable=not value
	if is_instance_valid(notice_shield): notice_shield.visible=value or notice.visible
func show_notice(ref: int,message: String="") -> void:
	revision+=1; notice_ref=ref; notice_body.text=text_owner.raw({"strRef":ref}) if ref>0 else message
	notice_shield.show(); notice.show(); notice.move_to_front(); edits.pnameeditbox.release_focus(); edits.pnameeditbox.editable=false
func close_notice() -> void:
	if closed or not is_instance_valid(notice) or not notice.visible: return
	if external_notice: dismiss(); external_notice_closed.emit(); return
	revision+=1; notice.hide(); notice_shield.hide(); notice_ref=0; notice_button.disabled=true; notice_button.disabled=false
	for tag in buttons: buttons[tag].disabled=pending and tag!="passwordcheck"
	edits.pnameeditbox.editable=not pending
	if not pending: edits.pnameeditbox.grab_focus()
func open_external_notice(message: String,capture: Array) -> void:
	if closed or not layout_ready: return
	dismiss(); scope=capture.duplicate(); external_notice=true
	for child in get_children():
		if child is CanvasItem and child!=notice and child!=notice_shield: child.hide()
	show(); show_notice(0,message)
func confirm_notice() -> void:
	var press: Dictionary=held.get("@notice",{"revision":revision,"scope":scope}); held.erase("@notice")
	if int(press.revision)==revision and press.scope==scope: close_notice()
func _input(event: InputEvent) -> void:
	if closed or not visible or not is_instance_valid(notice) or not notice.visible or not event is InputEventKey: return
	if event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_ESCAPE]: close_notice()
	get_viewport().set_input_as_handled()
func escape_profile() -> bool:
	if not visible: return false
	if notice.visible: close_notice()
	elif not pending: dismiss(); canceled.emit()
	return true
func dismiss() -> void:
	super.dismiss(); pending=false; notice_ref=0; external_notice=false
	if is_instance_valid(login_profiles_button): login_profiles_button.disabled=true; login_profiles_button.disabled=false
	if is_instance_valid(notice): notice.hide(); notice_shield.hide(); notice_button.disabled=true; notice_button.disabled=false
	set_pending(false)
func snapshot() -> Dictionary:
	var value:=super.snapshot(); value.merge({"kind":"multi_login","pending":pending,"notice":notice_ref,"notice_visible":is_instance_valid(notice) and notice.visible}); return value
func close() -> void:
	if closed: return
	if is_instance_valid(frame) and is_instance_valid(notice_button): frame.button_geometry.erase(notice_button.get_instance_id())
	super.close()
