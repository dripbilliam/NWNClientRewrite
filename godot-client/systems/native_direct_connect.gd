extends Control
# Original DIRECTCONNECT view only. The browser owns admission, credentials,
# session generations and authoritative connection outcomes.
signal prepared
signal confirmed(address: String,password: String,capture: Array)
signal canceled
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/connection_dialog_layout.gd")
var frame
var text_owner
var assets
var jobs: Dictionary={}
var models: Dictionary={}
var source: Dictionary={}
var definition: Dictionary={}
var buttons: Dictionary={}
var edits: Dictionary={}
var labels: Dictionary={}
var held: Dictionary={}
var scope: Array=[]
var revision:=0
var layout_ready:=false
var failure:=""
var closed:=false
func configure(painter,text,catalog,cache_path: String) -> void:
	frame=painter; text_owner=text; mouse_filter=Control.MOUSE_FILTER_STOP; hide()
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(received)
	jobs[assets.request("directconnect",2047,"gff")]="@layout"
	get_viewport().size_changed.connect(place)
func collect(node: Dictionary) -> void:
	var name:=str(node.get("Obj_ResRef","")).to_lower()
	if not name.is_empty() and not models.has(name): models[name]={}; jobs[assets.request(name,2002,"actor-model")]=name
	for child in node.get("Obj_ChildList",[]): collect(child)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	if name=="@layout":
		if str(result.value.get("type",""))!="GUI ": failure="Invalid original Direct Connect GUI"; return
		source=result.value.root; collect(source)
	else: models[name]=result.value
	if jobs.is_empty() and not source.is_empty() and failure.is_empty(): build()
func build() -> void:
	definition=Plan.parse(source,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	size=definition.size; custom_minimum_size=size
	frame.image(definition.resource,definition.main,self)
	for tag in Plan.LABELS:
		var entry: Dictionary=definition.entries[tag]; var label: Label=frame.create_label(entry,self); labels[tag]=label
		label.clip_text=false; label.text=text_owner.raw({"strRef":int(entry.caption.get("Obj_StrRef",-1))}); label.minimum_size_changed.connect(place_label.bind(tag)); place_label(tag)
	for tag in Plan.EDITS:
		var entry: Dictionary=definition.entries[tag]
		var edit: LineEdit=frame.create_edit(entry,self); edits[tag]=edit
		edit.text_submitted.connect(submit_edit)
	# The original password-only panel masks with '*'; Direct Connect's own
	# initializer does not set that font. Mask here deliberately until original
	# inherited edit behavior is verified; never expose a stored private key.
	edits.passwordeditbox.secret=true
	for tag in Plan.BUTTONS:
		var entry: Dictionary=definition.entries[tag]; var button: Button=frame.create_button(entry,self,models); buttons[tag]=button
		var ref:=int(entry.caption.get("Obj_StrRef",-1))
		if ref>=0 and ref!=4294967295: frame.button_caption(button,text_owner.raw({"strRef":ref}))
		button.button_down.connect(func():held[tag]={"revision":revision,"scope":scope.duplicate()})
		button.pressed.connect(invoke.bind(tag))
	layout_ready=true; place(); prepared.emit()
func place_label(tag: String) -> void:
	if closed or not labels.has(tag): return
	var label: Label=labels[tag]; var entry: Dictionary=definition.entries[tag]; var extent:=label.get_combined_minimum_size()
	label.size=extent; label.position=entry.anchor-extent*Vector2(float(entry.caption.get("AurString_AlignH",0)),float(entry.caption.get("AurString_AlignV",0)))
func place() -> void:
	if layout_ready: position=((get_viewport_rect().size-size)*0.5).max(Vector2.ZERO)
func open(address: String,password: String,capture: Array) -> bool:
	if closed or not layout_ready or not failure.is_empty(): return false
	dismiss(); revision+=1; scope=capture.duplicate(); edits.ipeditbox.text=address; edits.passwordeditbox.text=password
	show(); move_to_front(); place(); edits.ipeditbox.grab_focus(); return true
func invoke(tag: String) -> void:
	if closed or not layout_ready or not is_visible_in_tree() or not buttons.has(tag) or buttons[tag].disabled: return
	var press: Dictionary=held.get(tag,{"revision":revision,"scope":scope}); held.erase(tag)
	if int(press.revision)!=revision or press.scope!=scope: return
	if tag=="okbutton":
		var address: String=edits.ipeditbox.text; var password: String=edits.passwordeditbox.text; var capture:=scope.duplicate()
		dismiss(); confirmed.emit(address,password,capture); password=""
	else: dismiss(); canceled.emit()
func submit_edit(_value: String) -> void:
	# A fresh Enter in the current edit is independent of an old, retired
	# mouse-down on OK. Keep stale guards for mouse releases, not new keys.
	held.erase("okbutton"); invoke("okbutton")
func dismiss() -> void:
	revision+=1; hide()
	if edits.has("passwordeditbox"): edits.passwordeditbox.clear()
	for edit in edits.values(): if edit.has_focus(): edit.release_focus()
	for button in buttons.values():
		var disabled: bool=button.disabled; button.disabled=true; button.disabled=disabled
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"failure":failure,"visible":visible,"jobs":jobs.size(),"closed":closed,"native_only":true,"full_connection_ui_parity":false}
func close() -> void:
	if closed: return
	dismiss(); closed=true
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(frame):
		for button in buttons.values(): frame.button_geometry.erase(button.get_instance_id())
	jobs.clear(); models.clear(); frame=null; text_owner=null
func _exit_tree() -> void: close()
