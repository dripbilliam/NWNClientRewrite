extends SceneTree
const Preferences=preload("res://systems/native_data/chat_preferences.gd")
const Options=preload("res://systems/native_chat_options.gd")
var checks:=0
var failures: Array=[]
var emitted: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)
func frames(count: int=2)->void:
	for _index in count:await process_frame
func _initialize()->void:run.call_deferred()
func click(control: Control)->void:
	var point:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await frames()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;root.push_input(event,true);await frames()
func key(code: Key)->void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;root.push_input(event,true);await frames()
func choose(choice: OptionButton,id: int)->bool:
	await click(choice)
	var popup:=choice.get_popup()
	if not popup.visible:return false
	for _attempt in choice.item_count+1:
		if popup.get_focused_item()==choice.get_item_index(id):break
		await key(KEY_DOWN)
	await key(KEY_ENTER)
	return not popup.visible and choice.get_selected_id()==id
func run()->void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	root.size=Vector2i(1300,1400);root.gui_embed_subwindows=true
	var defaults:=Preferences.clean({})
	check(defaults["ui.text-bubble-mode"] is int and defaults["ui.text-bubble-mode"]==2 and defaults["ui.large-font"] is bool and defaults["ui.large-font"],"Missing popup keys use exact registered INT2/BOOLtrue defaults")
	for mode_value in [0,1,2]:check(Preferences.clean({"ui.text-bubble-mode":mode_value})["ui.text-bubble-mode"]==mode_value,"Exact persisted INT mode admitted: "+str(mode_value))
	for index in 15:
		var bad: Variant=[-1,3,1.0,2.0,0.5,NAN,INF,-INF,true,false,"1",null,{},[],4294967295][index]
		check(Preferences.clean({"ui.text-bubble-mode":bad})["ui.text-bubble-mode"]==2,"Malformed typed mode defaults without coercion: "+str(index))
	check(not Preferences.clean({"ui.large-font":false})["ui.large-font"] and Preferences.clean({"ui.large-font":true})["ui.large-font"],"Both actual BOOL preferences retain their meaning")
	for index in 10:
		var bad: Variant=[0,1,0.0,1.0,"true","false",null,{},[],NAN][index]
		check(Preferences.clean({"ui.large-font":bad})["ui.large-font"],"Malformed non-BOOL font preference defaults: "+str(index))
	var old:={"width":640,"x":30,"bottom":20,"compact_prompt":true,"font_size":22,"opacity":0.35,"timestamps":true,"seconds":true,"autoscroll":false,"locked":true,"split":true,"history":500,"mask_combined":123,"mask_left":456,"mask_right":789,"show_talk":false,"show_shout":false,"show_whisper":false,"show_tell":false,"show_party":false,"show_dm":false,"show_system":false}
	var clean:=Preferences.clean(old)
	check(old.keys().all(func(field):return clean[field]==old[field]),"Every existing chat preference is preserved when adding missing popup defaults")
	var storage:=output+".settings.cfg";var config:=ConfigFile.new()
	for field in old:config.set_value("chat-hud",field,old[field])
	config.set_value("chat-hud","height0",211.0);config.set_value("chat-hud","future-owner","keep");config.set_value("unrelated","unchanged",42);config.save(storage)
	var before:=FileAccess.get_sha256(storage);var loaded:=Preferences.load_settings(storage)
	check(loaded["ui.text-bubble-mode"]==2 and loaded["ui.large-font"] and FileAccess.get_sha256(storage)==before,"Loading an old file uses native defaults without writing or losing old chat values")
	loaded["ui.text-bubble-mode"]=1;loaded["ui.large-font"]=false;Preferences.save_settings(storage,loaded);config.load(storage)
	check(config.get_value("chat-hud","ui.text-bubble-mode") is int and config.get_value("chat-hud","ui.text-bubble-mode")==1 and config.get_value("chat-hud","ui.large-font") is bool and not config.get_value("chat-hud","ui.large-font"),"Canonical dotted keys roundtrip through the existing chat-hud ConfigFile section")
	check(config.get_value("chat-hud","font_size")==22 and config.get_value("chat-hud","height0")==211.0 and config.get_value("chat-hud","future-owner")=="keep" and config.get_value("unrelated","unchanged")==42,"Saving popup preferences preserves chat font, unknown own-section fields and unrelated sections")
	var window=Options.acquire(root,storage);window.open_settings();await frames(4)
	window.settings_changed.connect(func(value):emitted.append(value))
	var mode: OptionButton=window.fields["ui.text-bubble-mode"];var large: CheckBox=window.fields["ui.large-font"]
	check(mode.item_count==3 and [mode.get_item_text(0),mode.get_item_text(1),mode.get_item_text(2)]==["Off","Text only","Full background"] and [mode.get_item_id(0),mode.get_item_id(1),mode.get_item_id(2)]==[0,1,2],"Existing ChatOptions exposes the exact three source-defined mode IDs/captions")
	check(mode.get_selected_id()==1 and not large.button_pressed and large.text=="Large dialog font" and Options.acquire(root,storage)==window,"Existing shared window reflects persisted popup values without a second service")
	check(await choose(mode,0) and window.values["ui.text-bubble-mode"]==0 and emitted.size()==1 and emitted[-1]["ui.text-bubble-mode"]==0,"Actual pointer/keyboard Off selection publishes through current settings_changed")
	check(await choose(mode,2) and window.values["ui.text-bubble-mode"]==2 and emitted.size()==2,"Actual popup selection restores full background through the same owner")
	await click(large)
	check(large.button_pressed and window.values["ui.large-font"] and emitted.size()==3 and emitted[-1]["ui.large-font"] is bool,"Actual Large dialog font checkbox publishes a typed BOOL")
	check(window.values.font_size==22 and window.values.width==640 and not window.values.show_talk,"Popup controls preserve existing message font/layout/channel choices")
	emitted[-1]["ui.text-bubble-mode"]=99
	check(window.values["ui.text-bubble-mode"]==2 and Preferences.load_settings(storage)["ui.text-bubble-mode"]==2,"Signal observers receive a detached dictionary and cannot mutate persisted owner values")
	var count:=emitted.size();window.refresh();window.open_settings();await frames()
	check(emitted.size()==count and mode.get_selected_id()==2 and large.button_pressed,"Refresh/reopen selects controls without feedback signals or duplicate setting changes")
	var reflected: Dictionary=window.values.duplicate();reflected["ui.text-bubble-mode"]=1;reflected["ui.large-font"]=false;window.reflect(reflected)
	check(emitted.size()==count and mode.get_selected_id()==1 and not large.button_pressed,"Reflect updates all popup controls silently via the existing owner contract")
	window.open_settings();await frames();await click(window.fields.original)
	check(window.values==Preferences.DEFAULTS and window.values["ui.text-bubble-mode"]==2 and window.values["ui.large-font"] and window.values.font_size==14,"Original-style preset uses registered popup defaults while retaining the old chat-font default")
	config.load(storage);check(config.get_value("chat-hud","future-owner")=="keep" and config.get_value("unrelated","unchanged")==42,"Preset preserves fields owned by other settings owners")
	window.get_parent().queue_free();await frames(3)
	var reopened=Options.acquire(root,storage);reopened.open_settings();await frames()
	check(reopened.values["ui.text-bubble-mode"]==2 and reopened.values["ui.large-font"] and reopened.fields["ui.text-bubble-mode"].get_selected_id()==2,"Fresh window owner reloads typed canonical popup settings from the same file")
	reopened.get_parent().queue_free();await frames(3)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Copied current ChatPreferences/ChatOptions only: strict typed canonical defaults/persistence, preservation and real embedded pointer/keyboard/checkbox settings controls. No original profile, Gameplay/Overhead/timer integration, server/key/GPU/native build or OS input."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
