extends "res://tests/native_character_lobby_frame_test.gd"
# Actual native GUI input under the headless renderer. Original artwork pixels,
# public admission and world entry are intentionally outside this CPU check.
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Native picker input uses the original installed layout")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original picker captions use the actual TLK")
	text.publish_table("classes",{"orderedRows":[{"Name":16777217}]}); text.overrides={16777217:"First server class",16777218:"Revised server class"}
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	ui=Lobby.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2")); native=ui.native_chooser
	check(await wait_until(func():return native.layout_ready or not native.failure.is_empty()),"Original native controls prepare independently of world/artwork readiness")
	check(native.failure.is_empty(),"Native control attachment hooks remain valid")
	if native.layout_ready:
		state={"phase":"character-selection","connected":true,"canSelect":true,"canLobbyPages":true,"selected":"server:a","choices":[{"key":"server:a","label":"Alpha","source":"server","serverSource":17},{"key":"server:b","label":"Beta","source":"server","serverSource":17}],"serverInfo":{"moduleName":"Owned metadata","playerCount":2,"maximumPlayers":8},"players":[{"id":7,"firstName":{"text":"Known player"},"classes":[{"id":0,"level":3}]}]}
		await present(); var pages=native.extra_pages
		check(pages.info_signature.is_empty() and pages.player_signature.is_empty() and pages.rows.is_empty(),"Character Info never formats or constructs either hidden page")
		await row_down("server:b"); var sent: Dictionary=requests.back()
		check(sent.kind=="lobby-choose" and sent.key=="server:b" and sent.requestId>0,"Actual roster mouse-down sends the scoped existing selection command")
		state.selected="server:b"; state.selectionAck={"requestId":sent.requestId,"key":"server:b"}; await present()
		check(ui.native_selection.is_empty() and not native.buttons.playbutton.disabled,"Matching authoritative acknowledgment enables Play without submitting")
		await click(native.tabs[1].get_global_rect().get_center())
		check(requests.back().kind=="lobby-page" and requests.back().page==1 and pages.info.visible and pages.info_text.get_parsed_text().contains("Owned metadata"),"Actual Server Info action still sends subscription and formats supplied metadata")
		check(pages.player_signature.is_empty() and pages.rows.is_empty(),"Showing Server Info still avoids all hidden Players work")
		await click(native.tabs[2].get_global_rect().get_center())
		check(requests.back().page==2 and pages.players.visible and pages.rows.size()==1,"Actual Players action builds current received rows on demand")
		var labels: Array=pages.rows[0].get_children().filter(func(node):return node is Label)
		check(labels[0].text=="Known player" and labels[1].text=="First server class(3) ","Player rows preserve original ordering and whole-number active class captions")
		text.publish_table("classes",{"orderedRows":[{"Name":16777218}]}); native.sync()
		labels=pages.rows[0].get_children().filter(func(node):return node is Label)
		check(labels[1].text=="Revised server class(3) ","Visible Players refresh when the active class table is republished")
		await row_down("server:a"); sent=requests.back(); state.selected="server:a"; state.selectionAck={"requestId":sent.requestId,"key":"server:a"}; await present()
		var prior: String=pages.player_signature; state.players=[]; await present()
		check(native.page_index==0 and pages.player_signature==prior and not pages.players.visible,"Hidden Players updates defer reconstruction without blocking character selection")
		await click(native.tabs[2].get_global_rect().get_center()); check(pages.rows.is_empty(),"Reopening Players immediately uses the newest removal state")
		await row_down("server:b",true); sent=requests.back(); state.selected="server:b"; state.selectionAck={"requestId":sent.requestId+1,"key":"server:b"}; var count:=requests.size(); await present()
		check(requests.size()==count and not ui.native_selection.is_empty(),"Unrelated acknowledgment cannot activate double-click Play")
		state.selectionAck={"requestId":sent.requestId,"key":"server:b"}; await present()
		check(requests.size()==count+1 and requests.back()=={"kind":"lobby-play","key":"server:b","connection":1},"Exact double-click acknowledgment emits one existing Play command")
		await click(native.buttons.cancelbutton.get_global_rect().get_center())
		check(requests.back()=={"kind":"lobby-disconnect","saveCharacter":false,"connection":1},"Actual Cancel sends the existing authoritative no-save disconnect")
		state={"phase":"menu","connected":false,"choices":[]}; await present(2)
		check(not native.visible,"Disconnect hides the picker without a Play or stale subscription")
	ui.close_native(); check(native.closed and native.projection_work.snapshot().closed and not native.projection_work.snapshot().running,"Closing joins its selected-character worker before frame retirement")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"gpuBenchmark":false,"liveClientValidated":false},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
