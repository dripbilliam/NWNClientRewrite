extends "res://tests/native_server_list_keyboard_test.gd"
const Profiles=preload("res://systems/native_login_profiles.gd")
const MAIN:="11111111-1111-4111-8111-111111111111"
const ALT:="22222222-2222-4222-8222-222222222222"
var profile_requests: Array=[]
func profile_view(panel,operation: String="open",active: Variant=null,locked: bool=false) -> Dictionary:
	return {"kind":"login-profiles-view","connection":panel.connection,"requestId":panel.request_id,"viewId":panel.view_id+2,"operation":operation,"activeProfileId":active,"profiles":[{"id":MAIN,"label":"Main","playerName":"Main Player","hasSavedCdKey":true},{"id":ALT,"label":"Alt","playerName":"Alt Player","hasSavedCdKey":true}],"hasLegacyCdKey":true,"protectedStorageAvailable":true,"locked":locked}
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1280,950); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var manager_layer:=CanvasLayer.new(); manager_layer.layer=60; surface.add_child(manager_layer)
	var panel:=Profiles.new(); manager_layer.add_child(panel); panel.setup(""); panel.request.connect(func(m):profile_requests.append(m.duplicate(true)))
	panel.open("Legacy Player",3); check(panel.visible and profile_requests.back().operation=="open","Login manager requests a scoped metadata view")
	panel.receive(profile_view(panel)); panel.new_draft(); panel.profile_label.text="Main"; panel.player_name.text="Main Player"; var fake_key:="-".join(PackedStringArray(["AAAAA","AAAAA","AAAAA","AAAAA","AAAAA","AAAAA","AAAAA"])); panel.cd_key.text=fake_key
	check(panel.cd_key.secret and not panel.cd_key.context_menu_enabled,"Key input is masked and has no context menu")
	await process_frame
	await click(panel.save_profile.get_global_rect().get_center())
	check(profile_requests.back().operation=="save" and profile_requests.back().values.playerName=="Main Player" and profile_requests.back().values.cdKey==fake_key,"Save and use submits the requested name/key pair to its current private view")
	check(panel.cd_key.text.is_empty() and panel.save_profile.disabled,"Submitting a key immediately clears it and disables duplicate saves")
	panel.receive(profile_view(panel,"save",MAIN)); await process_frame
	check(panel.profile_label.text=="Main" and panel.player_name.text=="Main Player" and panel.cd_key.text.is_empty() and not JSON.stringify(panel.state).contains(fake_key),"Saved profile metadata repopulates names without any stored key readback")
	panel.profiles.select(2); panel.profiles.item_selected.emit(2)
	check(panel.profile_label.text=="Alt" and panel.player_name.text=="Alt Player" and not panel.use_profile.disabled,"Choosing another saved profile exposes its exact player name")
	await click(panel.use_profile.get_global_rect().get_center()); check(profile_requests.back().operation=="select" and profile_requests.back().profileId==ALT and not profile_requests.back().has("values"),"Use selected sends only the opaque profile handle")
	var stale:=profile_view(panel,"select",ALT); panel.receive(stale)
	check(not panel.visible and panel.cd_key.text.is_empty() and profile_requests.back().operation=="close","Successful switching closes the manager and retires its view")
	panel.receive(stale); check(not panel.visible,"A late selection reply cannot reopen the retired manager")
	panel.open("",4); var current:=profile_view(panel,"open",ALT,true); panel.receive(current)
	check(panel.save_profile.disabled and panel.use_profile.disabled and panel.new_profile.disabled and not panel.cd_key.editable,"Profiles are read-only while a connection or login owns the credentials")
	current=profile_view(panel,"open",ALT); panel.receive(current); await click(panel.delete_profile.get_global_rect().get_center())
	check(profile_requests.back().operation=="delete" and profile_requests.back().profileId==ALT,"Delete targets only the chosen current profile")
	panel.receive({"kind":"login-profiles-notice","connection":4,"requestId":panel.request_id,"text":"Profile could not be saved"})
	check(not panel.save_profile.disabled and panel.cd_key.text.is_empty(),"A rejected change unlocks the form without restoring a private key")
	panel.close_panel()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original multiplayer UI mounts locally")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original labels load")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var styling=preload("res://systems/native_client_menu_style.gd").new(); surface.add_child(styling); styling.configure(painter)
	var ui:=Browser.new(); surface.add_child(ui); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2")); var opened:=[0]; ui.login_profiles_requested.connect(func():opened[0]+=1)
	check(await wait_until(func():return ui.native_browser.layout_ready and ui.profile_dialog.layout_ready and ui.entry_menu.art_ready()),"Native server pages and player-name profile access prepare")
	ui.open(true,true); var view:={"kind":"browser-view","connection":0,"viewId":1,"tab":"Direct","direct":{"host":"127.0.0.1","port":5121,"name":"Legacy Player"},"hasSessionProfile":false,"canJoin":true,"canDiscover":false,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"rows":[],"busy":false}
	ui.receive(view); await process_frame; await click(ui.profile_dialog.login_profiles_button.get_global_rect().get_center())
	check(opened[0]==1,"The original player-name dialog opens the shared login-profile manager")
	ui.key_edit.text=fake_key; ui.password_edit.text="old transient password"
	view.viewId=2; view.activeLoginProfile={"id":ALT,"label":"Alt","playerName":"Alt Player"}; view.activeProfileId=ALT; view.direct.name="Alt Player"; view.hasSessionProfile=true; ui.receive(view)
	check(ui.name_edit.text=="Alt Player" and ui.profile_dialog.edits.pnameeditbox.text=="Alt Player" and ui.key_edit.text.is_empty() and ui.password_edit.text.is_empty(),"A canonical profile switch updates names and clears transient credentials from the previous login")
	ui.profile_dialog.dismiss(); ui.profile_first=false; ui.entry_stage="browser"; view.viewId=3; view.tab="Internet"; ui.receive(view); await process_frame
	var button: Button=ui.native_browser.login_profiles_button
	check(button.text=="Alt" and button.tooltip_text.contains("Alt Player") and not button.get_rect().intersects(ui.native_browser.refresh_servers.get_rect()),"Browser header identifies the chosen profile without overlapping refresh")
	await click(button.get_global_rect().get_center()); check(opened[0]==2,"The browser header opens the same manager for quick profile switching")
	panel.open("Alt Player",4); panel.receive(profile_view(panel,"open",ALT)); await process_frame
	if DisplayServer.get_name()!="headless":
		check(await wait_until(func():return styling.presentation_ready and painter.art.waiting.is_empty() and painter.fonts.pending.is_empty()),"Shared native menu font/artwork settles")
		await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Profile manager and native browser header captured")
	panel.close_panel(); panel.free(); ui.close_native(); ui.free(); styling.close(); styling.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Actual native profile form, masked/scrubbed key input, scoped CRUD/selection messages, stale replies, locked state, original login dialog and header entry points. Fake credentials and provider metadata only."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
