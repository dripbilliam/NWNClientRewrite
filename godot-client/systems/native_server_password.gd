extends "res://systems/native_direct_connect.gd"
signal password_confirmed(password: String,capture: Array)
const PasswordPlan=preload("res://systems/native_data/server_password_layout.gd")
func configure(painter,text,catalog,cache_path: String) -> void:
	frame=painter; text_owner=text; mouse_filter=Control.MOUSE_FILTER_STOP; hide()
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(received)
	jobs[assets.request("playerpassword",2047,"gff")]="@layout"; get_viewport().size_changed.connect(place)
func build() -> void:
	definition=PasswordPlan.parse(source,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	size=definition.size; custom_minimum_size=size; frame.image(definition.resource,definition.main,self)
	var data: Dictionary=definition.entries.tguilabel; var label: Label=frame.create_label(data,self); labels.tguilabel=label; label.clip_text=false; label.text=text_owner.raw({"strRef":int(data.caption.get("Obj_StrRef",-1))}); label.minimum_size_changed.connect(place_label.bind("tguilabel")); place_label("tguilabel")
	var entry: Dictionary=definition.entries.passwordeditbox
	var edit: LineEdit=frame.create_edit(entry,self); edits.passwordeditbox=edit; edit.secret=true; edit.secret_character="*"; edit.max_length=255
	edit.text_submitted.connect(submit_edit)
	for tag in PasswordPlan.BUTTONS:
		var source_entry: Dictionary=definition.entries[tag]; var control: Button=frame.create_button(source_entry,self,models); frame.button_caption(control,text_owner.raw({"strRef":int(source_entry.caption.get("Obj_StrRef",-1))})); buttons[tag]=control
		control.button_down.connect(func():held[tag]={"scope":scope.duplicate(),"revision":revision}); control.pressed.connect(invoke.bind(tag))
	static_cohort=Cohort.capture("playerpassword",self,frame,models)
	layout_ready=true; place(); prepared.emit()
func open_password(capture: Array) -> bool:
	if closed or not art_ready(): return false
	dismiss(); scope=capture.duplicate(); show(); place(); edits.passwordeditbox.grab_focus(); return true
func invoke(tag: String) -> void:
	if closed or not visible or not layout_ready or not buttons.has(tag) or buttons[tag].disabled: return
	var capture: Dictionary=held.get(tag,{"scope":scope,"revision":revision}); held.erase(tag)
	if capture.scope!=scope or int(capture.revision)!=revision: return
	if tag=="okbutton":
		var password: String=edits.passwordeditbox.text; var context:=scope.duplicate(); dismiss(); password_confirmed.emit(password,context); password=""
	else: dismiss(); canceled.emit()
