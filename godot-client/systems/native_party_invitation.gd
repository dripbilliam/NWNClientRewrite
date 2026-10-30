extends Node
const Draggable=preload("res://systems/draggable_panel.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
const Text=preload("res://systems/server_text.gd")
var owner_frame
var panel
var body: RichTextLabel
var check_button: Button
var checkbox_label: Label
var buttons: Dictionary={}
var state: Dictionary={}
var context: Array=[]
var seen:=-1
var wanted:=false
var enabled:=true
var layout_ready:=false
var pending_id:=-1
func configure(owner) -> void:
	owner_frame=owner; var config:=ConfigFile.new()
	if config.load(owner.panel.settings_path)==OK: enabled=bool(config.get_value("ui","party_invite_popup",true))
func observe() -> void:
	var scope: Array=owner_frame.scope()
	if scope!=context: reset_view(); context=scope
	var notice=owner_frame.desktop.state.get("partyInviteNotice")
	var inviter: int=owner_frame.invitation()
	if inviter<0 or inviter==2130706432:
		wanted=false
		if is_instance_valid(panel): panel.hide()
		return
	if not notice is Dictionary or not enabled or int(notice.get("serial",-1))<=seen: return
	wanted=true
	if not layout_ready: return
	seen=int(notice.serial); pending_id=-1; state={"scope":scope.duplicate(),"inviter":inviter,"notice":seen}; panel.show(); panel.move_to_front(); panel._clamp()
	var resolved: String=owner_frame.desktop.owner_ui.text.resolve({"strRef":0x104d8},owner_frame.desktop.actor_id,{"localCustomTokens":{0:str(notice.get("name",""))}})
	body.clear(); body.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER); Text.append(body,preload("res://systems/native_data/rich_text.gd").parse(resolved)); body.pop(); check_button.set_pressed_no_signal(not enabled)
	for button in buttons.values(): button.disabled=false
func activate(layout: Dictionary,models: Dictionary) -> void:
	var name:=str(layout.get("Obj_ResRef","")).to_lower(); var main:=Geometry.model(models[name]); var origin: Vector2=-main.bounds.position; var parsed:=Gui.elements(layout,models,origin)
	if not str(parsed.error).is_empty(): owner_frame.fail(str(parsed.error)); return
	for tag in ["okbutton","cancelbutton","rejectbutton","disablepartyinvitecheck"]:
		if not parsed.entries.has(tag): owner_frame.fail("Missing original invitation control: "+tag); return
	if not parsed.entries.has("messagelabel"): owner_frame.fail("Missing original invitation message label"); return
	panel=Draggable.new(); owner_frame.desktop.owner_ui.controls.add_child(panel); panel.configure("Party invitation","party-invitation",Vector2(260,180),owner_frame.panel.settings_path); panel.window_column.hide(); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); panel.custom_minimum_size=main.bounds.size; panel.size=main.bounds.size; panel.close_hides=false; panel.close_requested.connect(func():reply("ignore"))
	var stage:=Control.new(); panel.add_child(stage); stage.size=main.bounds.size; stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; owner_frame.picture(stage,name,Rect2(Vector2.ZERO,main.bounds.size))
	var drag:=Control.new(); stage.add_child(drag); drag.position=Vector2(0,0); drag.size=Vector2(main.bounds.size.x,18); drag.mouse_filter=Control.MOUSE_FILTER_STOP; drag.gui_input.connect(panel._title_input)
	for tag in ["okbutton","cancelbutton","rejectbutton"]:
		var button:=Button.new(); stage.add_child(button); owner_frame.frame.button(button,parsed.entries[tag],stage,models,false)
		var ref:=0x104d6 if tag=="okbutton" else 0x1051a if tag=="cancelbutton" else int(parsed.entries[tag].caption.get("Obj_StrRef",-1)); owner_frame.frame.button_caption(button,owner_frame.desktop.owner_ui.text.raw({"strRef":ref})); buttons[tag]=button
	buttons.okbutton.pressed.connect(func():reply("accept")); buttons.cancelbutton.pressed.connect(func():reply("ignore")); buttons.rejectbutton.pressed.connect(func():reply("reject"))
	check_button=Button.new(); stage.add_child(check_button); check_button.toggle_mode=true; owner_frame.button(check_button,parsed.entries.disablepartyinvitecheck,stage,true); check_button.toggled.connect(func(value):set_enabled(not value))
	var entry: Dictionary=parsed.entries.messagelabel; body=Text.label({}); stage.add_child(body); body.position=entry.rect.position; body.size=entry.rect.size; body.fit_content=false; body.scroll_active=false; body.mouse_filter=Control.MOUSE_FILTER_IGNORE; owner_frame.frame.font_style(body,entry.caption)
	for child in layout.get("Obj_ChildList",[]):
		if str(child.get("Obj_Tag","")).to_lower()=="disablepartyinvitecheck":
			var nested:=Gui.elements(child,models,parsed.entries.disablepartyinvitecheck.offset)
			if not str(nested.error).is_empty() or not nested.entries.has("tguilabel"): owner_frame.fail("Missing original nested invitation preference caption"); return
			var label_entry: Dictionary=nested.entries.tguilabel; checkbox_label=owner_frame.make_label(stage,label_entry,owner_frame.desktop.owner_ui.text.raw({"strRef":int(label_entry.caption.get("Obj_StrRef",-1))})); checkbox_label.clip_text=false
	layout_ready=true; panel.hide()
func set_enabled(value: bool) -> void:
	var config:=ConfigFile.new(); config.load(owner_frame.panel.settings_path); config.set_value("ui","party_invite_popup",value)
	if config.save(owner_frame.panel.settings_path)!=OK:
		check_button.set_pressed_no_signal(not enabled); owner_frame.help_label.text="Could not save the party invitation preference."; return
	enabled=value
func reply(operation: String) -> void:
	if not wanted or pending_id>=0 or state.get("scope",[])!=owner_frame.scope() or int(state.get("inviter",-1))!=owner_frame.invitation(): return
	owner_frame.send("native-party",{"operation":operation,"targetId":int(state.inviter)},true); pending_id=owner_frame.serial
	for button in buttons.values(): button.disabled=true
func receive(message: Dictionary) -> void:
	if int(message.get("requestId",-1))!=pending_id: return
	pending_id=-1
	if message.get("accepted",false): wanted=false; panel.hide()
	else:
		for button in buttons.values(): button.disabled=false
func reset_view() -> void:
	wanted=false; seen=-1; state.clear(); pending_id=-1
	if is_instance_valid(panel): panel.hide()
func blocks_pointer(point: Vector2) -> bool: return is_instance_valid(panel) and panel.visible and panel.get_global_rect().has_point(point)
func snapshot() -> Dictionary: return {"ready":layout_ready,"visible":is_instance_valid(panel) and panel.visible,"enabled":enabled,"pending":pending_id>=0}
func _input(event: InputEvent) -> void:
	if not is_instance_valid(panel) or not panel.visible or not event is InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_ESCAPE: return
	var windows: Array=panel.get_parent().get_children(); windows.reverse()
	for window in windows:
		if window is Draggable and window.visible:
			if window==panel: reply("ignore"); get_viewport().set_input_as_handled()
			return
func close() -> void:
	reset_view()
	if is_instance_valid(panel): panel.queue_free()
