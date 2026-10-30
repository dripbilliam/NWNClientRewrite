extends Control
# Original OKCANCELPANEL, its original artwork/font controls and result codes.
# The caller owns the operation and verifies this returned opaque capture.
signal prepared
signal answered(result: int,capture: Array)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/connection_dialog_layout.gd")
var frame
var text_owner
var assets
var jobs: Dictionary={}
var models: Dictionary={}
var source: Dictionary={}
var definition: Dictionary={}
var panel: Control
var message: Label
var buttons: Dictionary={}
var captions: Dictionary={}
var held: Dictionary={}
var scope: Array=[]
var revision:=0
var layout_ready:=false
var failure:=""
var closed:=false
func configure(painter,text,catalog,cache_path: String) -> void:
	frame=painter; text_owner=text; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP; focus_mode=Control.FOCUS_ALL; hide()
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=1; assets.completed.connect(received)
	jobs[assets.request("okcancelpanel",2047,"gff")]="@layout"; get_viewport().size_changed.connect(place)
func collect(node: Dictionary) -> void:
	var name:=str(node.get("Obj_ResRef","")).to_lower()
	if not name.is_empty() and not models.has(name): models[name]={}; jobs[assets.request(name,2002,"actor-model")]=name
	for child in node.get("Obj_ChildList",[]): collect(child)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); prepared.emit(); return
	if name=="@layout": source=result.value.get("root",{}); collect(source)
	else: models[name]=result.value
	if jobs.is_empty() and not source.is_empty() and failure.is_empty(): build()
func build() -> void:
	definition=Plan.panel(source,models,["messagelabel"],[],{"okbutton":"0x140201ef0","cancelbutton":"0x140201e30"})
	if not str(definition.error).is_empty(): failure=str(definition.error); prepared.emit(); return
	# PostAttachmentInitialize201fa0 imports a claimed CGuiLabel with flag4;
	# this is bounded text, unlike the pregame helper's floating auto-labels.
	definition.entries.messagelabel.floating=false
	panel=Control.new(); add_child(panel); panel.size=definition.size; panel.mouse_filter=Control.MOUSE_FILTER_STOP; frame.image(definition.resource,definition.main,panel)
	message=frame.create_label(definition.entries.messagelabel,panel)
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for tag in ["okbutton","cancelbutton"]:
		var button: Button=frame.create_button(definition.entries[tag],panel,models); buttons[tag]=button; captions[tag]=frame.button_caption(button,"")
		button.button_down.connect(func():held[tag]=[scope.duplicate(true),revision]); button.pressed.connect(invoke.bind(tag))
	layout_ready=true; place(); prepared.emit()
func place() -> void:
	if layout_ready: panel.position=((get_viewport_rect().size-panel.size)*0.5).max(Vector2.ZERO)
func ask(message_ref: int,yes_ref: int,no_ref: int,capture: Array) -> bool:
	if closed or not layout_ready or not failure.is_empty(): return false
	dismiss(); scope=capture.duplicate(true); message.text=text_owner.raw({"strRef":message_ref}); captions.okbutton.text=text_owner.raw({"strRef":yes_ref}); captions.cancelbutton.text=text_owner.raw({"strRef":no_ref})
	show(); move_to_front(); place(); grab_focus(); return true
func invoke(tag: String) -> void:
	var capture: Array=held.get(tag,[]); held.erase(tag)
	if not is_visible_in_tree() or buttons[tag].disabled or capture!=[scope,revision]: return
	finish(1 if tag=="okbutton" else 2)
func finish(result: int) -> void:
	if not is_visible_in_tree(): return
	var capture:=scope.duplicate(true); dismiss(); answered.emit(result,capture)
func _input(event: InputEvent) -> void:
	# CGuiMan dispatches Escape to the top modal even if another GUI control
	# owns edit focus. Do not rely on this Control retaining Godot GUI focus.
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and is_visible_in_tree(): get_viewport().set_input_as_handled(); finish(2)
func dismiss() -> void:
	revision+=1; held.clear(); scope=[]; hide(); release_focus()
	for button in buttons.values():
		if button.has_method("reset_native_pressed_state"): button.reset_native_pressed_state()
func close() -> void:
	if closed: return
	dismiss(); closed=true
	if is_instance_valid(assets): assets.close()
func _exit_tree() -> void: close()
