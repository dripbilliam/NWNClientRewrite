extends "res://systems/native_direct_connect.gd"
# CFilterPanel's source dialog. The browser persists/applies its draft only on OK.
signal filters_confirmed(values: Dictionary,capture: Array)
const FilterPlan=preload("res://systems/native_data/server_filter_layout.gd")
func configure(painter,text,catalog,cache_path: String) -> void:
	frame=painter; text_owner=text; mouse_filter=Control.MOUSE_FILTER_STOP; hide()
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(received)
	jobs[assets.request("serverlist_filt",2047,"gff")]="@layout"; get_viewport().size_changed.connect(place)
func build() -> void:
	definition=FilterPlan.parse(source,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	size=definition.size; custom_minimum_size=size; frame.image(definition.resource,definition.main,self)
	for tag in FilterPlan.LABELS:
		var entry: Dictionary=definition.entries[tag]; var label: Label=frame.create_label(entry,self); labels[tag]=label
		label.clip_text=false; label.text=text_owner.raw({"strRef":int(entry.caption.get("Obj_StrRef",-1))}); label.minimum_size_changed.connect(place_label.bind(tag)); place_label(tag)
	var entry: Dictionary=definition.entries.moduleedit
	if entry.model.drawn: frame.image(entry.resource,entry.rect,self)
	var edit:=LineEdit.new(); add_child(edit); edits.moduleedit=edit; edit.custom_minimum_size=Vector2.ZERO; edit.max_length=1024
	for state in ["normal","focus","read_only"]: edit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	frame.font_style(edit,entry.caption); edit.position=entry.text_rect.position; edit.size=entry.text_rect.size; edit.text_submitted.connect(submit_edit)
	for tag in FilterPlan.BUTTONS.keys()+FilterPlan.CHECKS:
		var data: Dictionary=definition.entries[tag]; var button:=Button.new(); add_child(button); var check: bool=tag in FilterPlan.CHECKS
		frame.button(button,data,self,models,false,check); buttons[tag]=button; button.toggle_mode=check
		var ref:=int(data.caption.get("Obj_StrRef",-1))
		if ref>=0 and ref!=4294967295: frame.button_caption(button,text_owner.raw({"strRef":ref}))
		button.button_down.connect(func():held[tag]={"revision":revision,"scope":scope.duplicate()}); button.pressed.connect(invoke.bind(tag))
	static_cohort=Cohort.capture("serverlist_filt",self,frame,models)
	layout_ready=true; place(); prepared.emit()
func open_filters(values: Dictionary,capture: Array) -> bool:
	if closed or not art_ready() or not failure.is_empty(): return false
	dismiss(); scope=capture.duplicate(); buttons.havepeoplebox.set_pressed_no_signal(values.get("hideEmpty",false)); buttons.notfullbox.set_pressed_no_signal(values.get("hideFull",false)); edits.moduleedit.text=str(values.get("module",""))
	show(); move_to_front(); place(); return true
func invoke(tag: String) -> void:
	if closed or not layout_ready or not is_visible_in_tree() or not buttons.has(tag) or buttons[tag].disabled: return
	var press: Dictionary=held.get(tag,{"revision":revision,"scope":scope}); held.erase(tag)
	if int(press.revision)!=revision or press.scope!=scope or tag in FilterPlan.CHECKS: return
	if tag=="okbutton":
		var values:={"hideEmpty":buttons.havepeoplebox.button_pressed,"hideFull":buttons.notfullbox.button_pressed,"module":edits.moduleedit.text}; var capture:=scope.duplicate()
		dismiss(); filters_confirmed.emit(values,capture)
	else: dismiss(); canceled.emit()
func snapshot() -> Dictionary:
	var value:=super.snapshot(); value.kind="serverlist_filt"; value.full_filter_ui_parity=false; return value
