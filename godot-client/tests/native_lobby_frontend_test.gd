extends "res://tests/native_quickbar_frame_test.gd"
const Lobby=preload("res://systems/character_lobby.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1280,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var base:=Catalog.new(); check(base.mount_install(install),"Installed frontend catalog mounts without a server or gameplay UI")
	var text:=Talk.new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original chooser text opens independently of gameplay rule preparation")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(base,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ui:=Lobby.new(); surface.add_child(ui); ui.preferences.open_file(""); ui.request.connect(func(value):requests.append(value.duplicate(true)))
	ui.apply_state({"connection":0,"state":{"phase":"menu","endpoint":null}})
	ui.prepare_native_frontend(painter,text,base,ProjectSettings.globalize_path("user://native-prepared-v2"))
	ui.apply_state({"connection":0,"state":{"phase":"character-selection","canCancelJoin":true,"busy":true}}); await process_frame
	check(ui.native_wait.visible and not ui.window_column.visible and not ui.native_wait_cancel.disabled,"A cold frontend exposes only preparation/cancel status, never prototype character controls")
	await click(ui.native_wait_cancel.get_global_rect().get_center())
	check(requests.back()=={"kind":"lobby-cancel-join","connection":0},"Cold preparation retains the real scoped cancellation action")
	ui.apply_state({"connection":0,"state":{"phase":"menu"}}); requests.clear()
	check(await wait_until(func():return ui.native_chooser.art_ready()),"The complete original chooser prepares at Main Menu with no GameplayUi instance or server setup")
	check(await wait_until(func():return text.tables.has("classes")),"Class labels prewarm at Main Menu even when there are no local-vault characters")
	check(ui.native_chooser.class_caption(0)=="Barbarian","Original class ID zero resolves to its installed Barbarian label, not an internal table key")
	var state:={"phase":"character-selection","connected":true,"canSelect":true,"canCreate":true,"selected":null,"choices":[{"key":"server:a","label":"Alpha","source":"server","classes":[{"id":0,"level":1}]},{"key":"server:z","label":"Zulu","source":"server","classes":[{"id":0,"level":2}]}]}
	ui.apply_state({"connection":1,"state":state}); await process_frame
	check(ui.native_chooser.visible and not ui.window_column.visible and (not is_instance_valid(ui.native_wait) or not ui.native_wait.visible),"A received server roster immediately uses the already-ready original screen, never the prototype")
	check(ui.native_chooser.labels["row:classes:server:a"].text.contains("Barbarian") and not ui.native_chooser.labels["row:classes:server:a"].text.contains("classes 0"),"A server-vault-only roster has readable class names before any gameplay/server-resource setup")
	check(ui.native_chooser.class_caption(99999)=="Loading class…","An ID beyond the installed table waits for server rules without displaying an internal class ID")
	check(requests.size()==1 and requests[0].key=="server:a","Warm original selection still uses its scoped first-row request")
	var active=base.fork(); var active_text:=Talk.new(); active_text.base.open_file(install.path_join("lang/en/data/dialog.tlk")); active_text.tables={"classes":{"orderedRows":[{"Name":16777217}]}}; active_text.overrides={16777217:"Active server class"}
	var active_painter:=Painter.new(); surface.add_child(active_painter); active_painter.configure_source(active,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var old=ui.native_chooser
	var old_id: int=old.get_instance_id(); var play_id: int=old.buttons.playbutton.get_instance_id(); var gui_requests: int=old.assets.serial
	ui.configure_native(active_painter,active_text,active,ProjectSettings.globalize_path("user://native-prepared-v2"))
	check(old.class_caption(0)=="Active server class" and old.class_caption(99999)=="Class unavailable","Active server class names replace installed defaults; undisclosed active IDs stay unavailable")
	old.rule_assets.set_process(false)
	var held_rule: int=old.rule_assets.request("skills",2017,"2da"); old.rule_jobs[held_rule]=["skills",1]
	check(ui.native_chooser.get_instance_id()==old_id and old.visible and old.assets.serial==gui_requests,"Server resources rebind only data: the same original frame remains visible with no new GUI asset requests")
	for at in 4: await process_frame
	await click(old.rows[1].get_global_rect().get_center())
	check(requests.back().kind=="lobby-choose" and requests.back().key=="server:z","Roster input remains live while active-source completion is deliberately held")
	var chosen: Dictionary=requests.back(); state.selected="server:z"; state.selectionAck={"requestId":chosen.requestId,"key":"server:z"}; ui.apply_state({"connection":1,"state":state}); await process_frame
	check(ui.native_selection.is_empty() and not old.buttons.playbutton.disabled,"Only the matching authoritative acknowledgment releases Play on the visible screen")
	var before:=requests.size(); old.rule_assets.set_process(true)
	check(await wait_until(func():return old.rule_jobs.is_empty()),"Held server rule data finishes without rebuilding the original picker")
	check(ui.native_catalog==active and not ui.native_base_only and ui.native_chooser.visible and not ui.window_column.visible,"The same original frame uses active server data without exposing a fallback")
	check(ui.native_chooser.labels["row:classes:server:z"].text.contains("Active server class"),"Active server class tables/custom text replace installed defaults")
	check(ui.native_chooser.get_instance_id()==old_id and old.buttons.playbutton.get_instance_id()==play_id and requests.size()==before and state.selected=="server:z" and ui.native_selection.is_empty(),"A source repaint preserves the selected character and sends no new selection")
	await click(ui.native_chooser.buttons.playbutton.get_global_rect().get_center())
	check(requests.back()=={"kind":"lobby-play","key":"server:z","connection":1},"The original persistent Play control sends the same scoped authoritative request")
	await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Ready original active-source pixels are retained")
	var last_job: int=old.rule_assets.request("feat",2017,"2da"); old.rule_jobs[last_job]=["feat",1]
	ui.close_native(); check(old.closed and old.assets.running.is_empty() and old.rule_assets.running.is_empty(),"Retiring a connection drains both GUI and rule workers before their sources close")
	ui.free(); painter.close(); painter.free(); active_painter.close(); active_painter.free(); text.close(); active_text.close(); await process_frame; await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"scope":"Warm original chooser without gameplay setup, actual pointer input while rule-data publication is held, authoritative selection/Play signals, server table handoff with stable frame/control identities and worker cleanup. Authored replies, not a public-server latency benchmark."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
