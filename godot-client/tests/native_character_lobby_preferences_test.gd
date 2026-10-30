extends "res://tests/native_character_lobby_frame_test.gd"
const Preferences=preload("res://systems/native_data/character_lobby_preferences.gd")
func create_lobby(painter,text,catalog,path: String) -> void:
	ui=Lobby.new(); surface.add_child(ui); ui.preferences.open_file(path); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2")); native=ui.native_chooser
	check(await wait_until(func():return native.layout_ready or not native.failure.is_empty()),"Recreated original chooser layout prepares")
	check(native.failure.is_empty(),"Recreated chooser has no layout failure")
func dispose_lobby() -> void:
	ui.close_native(); ui.free(); await process_frame; await process_frame
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:=output.trim_suffix(".json")+".prefs.cfg"; var bad_path:=output.trim_suffix(".json")+".bad.cfg"
	if FileAccess.file_exists(path) or FileAccess.file_exists(bad_path): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Preference UI uses the original read-only chooser catalog")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Preference captions use the original installed TLK")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	await create_lobby(painter,text,catalog,path)
	state={"phase":"character-selection","connected":true,"canSelect":true,"selected":null,"choices":[{"key":"local:p","label":"Alpha Pregen","source":"vault","pregenerated":true},{"key":"local:z","label":"Zulu","source":"vault","pregenerated":false}]}; await present()
	check(not native.show_pregenerated and not native.pregen.button_pressed and native.row_keys==["local:z"] and not FileAccess.file_exists(path),"An absent preference defaults off without writing on construction")
	await click(native.pregen.get_global_rect().get_center())
	check(native.show_pregenerated and native.row_keys==["local:p","local:z"] and requests.back().key=="local:p" and not ui.native_selection.activate,"Actual checkbox input reveals pregenerated rows and selects the first row without Play")
	check(not FileAccess.file_exists(path),"Checkbox input defers persistence until chooser destruction like the original")
	var external:=ConfigFile.new(); external.set_value("unrelated","keep","received after opening"); check(external.save(path)==OK,"An unrelated setting arrives before chooser destruction")
	var saved_owner=ui.preferences; ui.close_native(); ui.close_native()
	var disk:=ConfigFile.new(); check(disk.load(path)==OK and disk.get_value(Preferences.SECTION,Preferences.KEY)==true and disk.get_value("unrelated","keep")=="received after opening" and saved_owner.writes==1,"Destroying the chooser saves true once while preserving unrelated current settings")
	ui.free(); await process_frame; await process_frame
	await create_lobby(painter,text,catalog,path); await present(2)
	check(native.show_pregenerated and native.pregen.button_pressed and native.row_keys==["local:p","local:z"] and ui.preferences.failure.is_empty(),"A fresh native owner restores the saved checked state before its first catalog rebuild")
	if DisplayServer.get_name()!="headless":
		check(await wait_until(func():return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()),"Restored checked-state original artwork and fonts settle before visual capture")
		await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".restored.png")==OK,"Restored checked preference is captured using original native checkbox artwork")
	var known: Array=state.choices.duplicate(true); state.choices[0].erase("pregenerated"); await present(2)
	check(native.pregen.disabled and native.show_pregenerated and native.pregen.button_pressed,"Unavailable local metadata disables the control without erasing the saved preference")
	state.choices=known; await present(2); await click(native.pregen.get_global_rect().get_center())
	check(not native.show_pregenerated and native.row_keys==["local:z"] and requests.back().key=="local:z" and not ui.native_selection.activate,"Unchecking refilters and reselects the first visible row without a Play request")
	await dispose_lobby(); check(disk.load(path)==OK and disk.get_value(Preferences.SECTION,Preferences.KEY)==false,"Chooser destruction persists an explicit false instead of treating it as absent")
	await create_lobby(painter,text,catalog,path); await present(3)
	check(not native.show_pregenerated and not native.pregen.button_pressed and native.row_keys==["local:z"],"A second fresh owner restores the persisted false")
	var point: Vector2=native.pregen.get_global_rect().get_center(); await motion(point); await mouse(point,true); await present(4); await mouse(point,false)
	check(not native.show_pregenerated and not native.pregen.button_pressed,"A held checkbox cannot mutate the new connection's preference on release")
	check(requests.all(func(message):return message.kind!="lobby-play"),"Preference restoration, filtering and replacement never submit a character")
	await dispose_lobby()
	var invalid:=ConfigFile.new(); invalid.set_value(Preferences.SECTION,Preferences.KEY,"true"); check(invalid.save(bad_path)==OK,"Malformed-type preference fixture is written as valid configuration syntax")
	var before:=FileAccess.get_sha256(bad_path); var prefs:=Preferences.new(); prefs.open_file(bad_path)
	check(not prefs.show_pregenerated and not prefs.failure.is_empty() and not prefs.save(true) and FileAccess.get_sha256(bad_path)==before,"A non-boolean preference falls back off without overwriting the existing file")
	prefs.open_file(output+".missing/chooser.cfg"); check(not prefs.save(true) and not prefs.failure.is_empty() and not FileAccess.file_exists(prefs.path),"An unavailable destination reports a failed save without fabricating persistence")
	prefs.open_file(""); check(prefs.save(true) and prefs.show_pregenerated and prefs.writes==0 and not prefs.snapshot().persistent,"Unconfigured isolated fixtures retain memory state without touching normal user preferences")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"preferencePath":path,"publicConnections":0,"fullUiParity":false,"fullCharacterLobbyParity":false,"scope":"Actual original checkbox input, native owner reconstruction and on-disk preference round trips; source filter/reselection and stale-held ownership; unrelated/invalid/unavailable file handling. Native local metadata acquisition and Delete/Customize remain unfinished."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
