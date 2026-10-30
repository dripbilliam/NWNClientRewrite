extends Control
# Source-model menu presentation. The controller supplies capabilities and owns
# actions; this view never sends a protocol packet or predicts a game outcome.
signal prepared
signal artwork_ready
signal action_requested(tag: String)
signal title_input(event: InputEvent)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/entry_menu_layout.gd")
var frame
var text_owner
var assets
var models: Dictionary={}
var jobs: Dictionary={}
var requested: Dictionary={}
var definition: Dictionary={}
var source: Dictionary={}
var confirm_source: Dictionary={}
var confirm_definition: Dictionary={}
var confirmation: Control
var confirm_body: Label
var confirm_buttons: Dictionary={}
var confirm_capture: Dictionary={}
var kind:="options_main"
var failure:=""
var layout_ready:=false
var closed:=false
var started:=false
var stage: Control
var buttons: Dictionary={}
var captions: Dictionary={}
var enabled: Dictionary={}
var colors: Dictionary={}
var scope: Array=[]
var held: Dictionary={}
var revision:=0
var build_text:="NWN · Native Godot"
var art_announced:=false
func configure(shared_frame,text,catalog,cache_path: String,menu_kind: String="options_main") -> void:
	frame=shared_frame; text_owner=text; kind=menu_kind; mouse_filter=Control.MOUSE_FILTER_IGNORE
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(received)
	hide(); set_process(false)
func start() -> void:
	if closed or started: return
	started=true; set_process(true); jobs[assets.request(kind,2047,"gff")]="@layout"; jobs[assets.request("okcancelpanel",2047,"gff")]="@confirm"
func request_models(node: Dictionary) -> void:
	var name:=str(node.get("Obj_ResRef","")).to_lower()
	if not name.is_empty() and not requested.has(name): requested[name]=true; jobs[assets.request(name,2002,"actor-model")]=name
	for child in node.get("Obj_ChildList",[]): request_models(child)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	if name=="@layout": source=result.value.root; request_models(source)
	elif name=="@confirm": confirm_source=result.value.root; request_models(confirm_source)
	else: models[name]=result.value
	if not jobs.is_empty() or source.is_empty() or confirm_source.is_empty() or not failure.is_empty(): return
	definition=Plan.parse(kind,source,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	var resource:=str(confirm_source.get("Obj_ResRef","")).to_lower(); var geometry:=Plan.Geometry.model(models.get(resource,{}))
	if not str(geometry.error).is_empty() or not geometry.drawn: failure="Missing original exit-confirmation geometry"; return
	var entries:=Plan.Gui.elements(confirm_source,models,-geometry.bounds.position)
	if not str(entries.error).is_empty(): failure=str(entries.error); return
	for tag in ["okbutton","cancelbutton","messagelabel"]:
		if not entries.entries.has(tag): failure="Missing original exit-confirmation control: "+tag; return
	confirm_definition={"resource":resource,"size":geometry.bounds.size,"entries":entries.entries}
	build()
func build() -> void:
	if closed or layout_ready: return
	size=definition.size; custom_minimum_size=definition.size
	stage=Control.new(); add_child(stage); stage.size=size; stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.image(definition.resource,definition.main.rect,stage)
	for tag in Plan.MENUS[kind].buttons:
		var entry: Dictionary=definition.entries[tag]
		# Current original initializers remove these model-owned controls; the
		# callbacks are literal RET0. Do not turn legacy source data into a new
		# active Sound button. Direct original-window comparison remains open.
		if entry.get("model_deleted_after_init",false): continue
		var button: Button=frame.create_button(entry,stage,models); buttons[tag]=button
		var caption: Label=frame.button_caption(button,caption_text(entry)); captions[tag]=caption
		button.button_down.connect(func():held[tag]={"scope":scope.duplicate(),"revision":revision})
		button.pressed.connect(func():invoke(tag))
	for tag in Plan.MENUS[kind].labels:
		var entry: Dictionary=definition.entries[tag]; var label: Label=frame.create_label(entry,stage); label.text=build_text if entry.get("runtime_text_kind","")=="build-version" else caption_text(entry)
		if tag=="tguilabel": label.mouse_filter=Control.MOUSE_FILTER_STOP; label.gui_input.connect(title_input.emit)
		if entry.has("runtime_color"): label.add_theme_color_override("font_color",entry.runtime_color)
	confirmation=Control.new(); add_child(confirmation); confirmation.mouse_filter=Control.MOUSE_FILTER_IGNORE; confirmation.size=confirm_definition.size; confirmation.position=(size-confirmation.size)*0.5
	frame.image(confirm_definition.resource,Rect2(Vector2.ZERO,confirmation.size),confirmation)
	confirm_body=frame.create_label(confirm_definition.entries.messagelabel,confirmation); confirm_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; confirm_body.text=text_owner.raw({"strRef":0x2844})
	for pair in [["okbutton",0x2052],["cancelbutton",0x2053]]:
		var button: Button=frame.create_button(confirm_definition.entries[pair[0]],confirmation,models); frame.button_caption(button,text_owner.raw({"strRef":pair[1]})); confirm_buttons[pair[0]]=button
		var confirm_tag: String=pair[0]
		button.button_down.connect(func():held["@"+confirm_tag]={"scope":scope.duplicate(),"revision":revision})
		button.pressed.connect(confirm_result.bind(confirm_tag=="okbutton"))
	confirmation.hide()
	layout_ready=true; refresh(); prepared.emit()
func caption_text(entry: Dictionary) -> String:
	if entry.has("runtime_text"): return str(entry.runtime_text)
	var caption: Dictionary=entry.get("caption",{}); var reference:=int(caption.get("Obj_StrRef",4294967295))
	return text_owner.raw({"strRef":reference}) if reference>=0 and reference!=4294967295 else str(caption.get("AurString_Text",""))
func set_context(value: Array,availability: Dictionary,caption_colors: Dictionary={}) -> void:
	if scope==value and enabled==availability and colors==caption_colors: return
	if scope!=value: revision+=1; cancel_confirmation()
	scope=value.duplicate(); enabled=availability.duplicate(); colors=caption_colors.duplicate(); refresh()
func refresh() -> void:
	if not layout_ready or closed: return
	for tag in buttons:
		var button: Button=buttons[tag]; button.disabled=not bool(enabled.get(tag,false))
		captions[tag].add_theme_color_override("font_color",colors.get(tag,Color(0.5,0.5,0.5,1) if button.disabled else Color.WHITE))
func invoke(tag: String) -> void:
	if closed or not layout_ready or not is_visible_in_tree() or not buttons.has(tag) or buttons[tag].disabled: return
	var capture: Dictionary=held.get(tag,{"scope":scope,"revision":revision}); held.erase(tag)
	if int(capture.revision)!=revision or capture.scope!=scope: return
	action_requested.emit(tag)
func dismiss() -> void:
	revision+=1; cancel_confirmation()
	# Godot4.7 visibility retirement clears press_attempt but leaves the
	# pressed_down_with_focus latch. Disabling resets both through the public
	# API and emits the corresponding button_up; toggled-state setters cannot
	# reset a non-toggle press. Keep each real disabled state and stale guard.
	for button in buttons.values(): release_button(button)
	for button in confirm_buttons.values(): release_button(button)
	hide()
func release_button(button: Button) -> void:
	var unavailable:=button.disabled; button.disabled=true; button.disabled=unavailable
func ask_exit() -> void:
	if not layout_ready or not bool(enabled.get("exitbutton",false)): return
	revision+=1; confirm_capture={"scope":scope.duplicate(),"revision":revision}; stage.hide(); confirmation.show()
func cancel_confirmation() -> bool:
	var was_open:=is_instance_valid(confirmation) and confirmation.visible
	if was_open: revision+=1
	confirm_capture.clear()
	if is_instance_valid(confirmation): confirmation.hide()
	if is_instance_valid(stage): stage.show()
	return was_open
func confirm_result(accepted: bool) -> void:
	if closed or not is_instance_valid(confirmation) or not confirmation.is_visible_in_tree(): return
	var tag: String="@okbutton" if accepted else "@cancelbutton"
	var press: Dictionary=held.get(tag,confirm_capture); held.erase(tag)
	var valid: bool=confirm_capture.get("scope",[])==scope and int(confirm_capture.get("revision",-1))==revision and press.get("scope",[])==scope and int(press.get("revision",-1))==revision and bool(enabled.get("exitbutton",false))
	cancel_confirmation()
	if accepted and valid: action_requested.emit("exit-confirmed")
func art_ready() -> bool:
	if not layout_ready or closed or not is_instance_valid(frame) or not failure.is_empty(): return false
	# Only this menu's visuals gate its presentation. Unrelated inventory/model
	# jobs on the shared painter cannot hold the menu behind a prototype screen.
	for owner in [stage,confirmation]:
		for node in owner.find_children("*","TextureRect",true,false):
			if node.texture==null: return false
		for node in owner.find_children("*","Label",true,false):
			if not node.text.is_empty() and not node.has_meta("native_font_applied"): return false
	for button in buttons.values()+confirm_buttons.values():
		var data: Dictionary=frame.button_geometry.get(button.get_instance_id(),{})
		if data.is_empty(): return false
		for pair in data.styles.values():
			if pair[0].texture==null: return false
	return true
func _process(_delta: float) -> void:
	if not art_announced and art_ready(): art_announced=true; set_process(false); artwork_ready.emit()
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"art_ready":art_ready(),"failure":failure,"kind":kind,"size":[size.x,size.y],"buttons":buttons.keys(),"confirmation":is_instance_valid(confirmation) and confirmation.visible,"scope":scope.duplicate(),"jobs":jobs.size(),"native_only":true,"full_entry_menu_parity":false}
func close() -> void:
	if closed: return
	closed=true; dismiss()
	if is_instance_valid(frame):
		for button in buttons.values(): frame.button_geometry.erase(button.get_instance_id())
		for button in confirm_buttons.values(): frame.button_geometry.erase(button.get_instance_id())
	if is_instance_valid(assets): assets.close()
	jobs.clear(); models.clear(); buttons.clear(); captions.clear(); text_owner=null; frame=null
func _exit_tree() -> void: close()
