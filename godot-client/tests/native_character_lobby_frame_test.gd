extends "res://tests/native_quickbar_frame_test.gd"
const Lobby=preload("res://systems/character_lobby.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
var ui
var native
var state: Dictionary={}
func present(connection: int=1) -> void:
	ui.apply_state({"connection":connection,"state":JSON.parse_string(JSON.stringify(state))}); await process_frame
func row_down(key_value: String,double_click: bool=false) -> void:
	var index: int=native.row_keys.find(key_value); var point: Vector2=native.rows[index].get_global_rect().get_center(); await motion(point)
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; event.double_click=double_click; event.button_mask=MOUSE_BUTTON_MASK_LEFT; surface.push_input(event,true); await process_frame
	await mouse(point,false)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original chooser catalog mounts read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original chooser captions use the installed TLK")
	text.tables={"classes":{"orderedRows":[{"Name":16777217,"Short":16777218}]},"ruleset":{"orderedRows":[{"Label":"CHARGEN_ABILITY_NEUTRAL_VALUE","Value":"8"}]}}
	text.overrides={16777217:"Server custom class",16777218:"SCC"}
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	ui=Lobby.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2")); native=ui.native_chooser
	check(await wait_until(func():return native.layout_ready or not native.failure.is_empty()),"Original chooser layout prepares without a world or JS rendering")
	check(native.failure.is_empty(),"Original model attachments validate: "+native.failure)
	if native.layout_ready:
		state={"phase":"character-selection","connected":true,"canSelect":true,"canCreate":true,"selected":null,"choices":[{"key":"server:z","label":"Zulu","source":"server","serverSource":17,"portraitRef":"po_clsbard_","classes":[{"id":0,"level":4}]},{"key":"server:a","label":"Alpha","source":"server","serverSource":2,"classes":[{"id":0,"level":1}]},{"key":"vault:p","label":"Pregen","source":"vault","pregenerated":true,"classes":[]}]}
		await present()
		check(requests.size()==1 and requests[0].kind=="lobby-choose" and requests[0].key=="server:a" and not ui.native_selection.activate,"Opening the original chooser selects its first visible row without submitting Play")
		var initial_count:=requests.size(); await present()
		check(requests.size()==initial_count,"Repeated state presentation does not repeat automatic selection")
		check(native.visible and not ui.window_column.visible and ui.panel.visible,"Admitted character selection replaces the generic chooser with the original frame")
		check(native.definition.size.is_equal_approx(Vector2(766,527.000244)) and ui.panel.size.is_equal_approx(native.definition.size),"Original panel dimensions remain unscaled")
		check(native.definition.portrait.size.is_equal_approx(Vector2(16,25)),"The original row portrait is16x25, not a stretched32x40 substitute")
		check(native.row_keys==["server:a","server:z"] and not native.show_pregenerated,"Rows sort case-insensitively and supplied pregenerated entries default hidden")
		check(native.labels["row:classes:server:z"].text.contains("Server custom class"),"Class captions resolve active server tables and custom TLK")
		await row_down("server:z")
		check(requests.back().kind=="lobby-choose" and requests.back().key=="server:z" and requests.back().connection==1 and requests.back().requestId>0,"Original row mouse-down sends a scoped catalog identity and selection nonce")
		var request: Dictionary=requests.back(); var count:=requests.size(); await row_down("server:z",true)
		check(requests.size()==count and ui.native_selection.activate,"Fast double-click queues activation until this selection is acknowledged")
		state.selected="server:z"; state.selectionAck={"requestId":request.requestId+1,"key":"server:z"}; await present()
		check(requests.size()==count,"An unrelated acknowledgment cannot play a character")
		state.selectionAck={"requestId":request.requestId,"key":"server:z"}; await present()
		check(requests.size()==count+1 and requests.back()=={"kind":"lobby-play","key":"server:z","connection":1} and ui.native_selection.is_empty(),"Matching authoritative selection completes double-click once through existing Play")
		await present(); check(requests.size()==count+1,"Repeating the same state cannot duplicate Play")
		state.preview={"firstName":{"text":"Zulu"},"lastName":{"text":"Test"},"portraitRef":"po_clsbard_","abilities":{"Str":12},"classes":[{"id":0,"level":4}],"hitPoints":20,"currentHitPoints":15,"armorClass":16,"experience":6000,"description":{"text":"Received description"}}
		var preview_fixture: Dictionary=state.preview.duplicate(true)
		await present()
		check(native.record_labels.title.text==text.raw({"strRef":0xf182})+", Zulu Test" and native.record_labels.strstat.text=="12" and native.record_labels.strmod.text=="2" and native.record_labels.hitpoints.text=="15/20" and native.record_labels.armorclass.text=="16","Original record attachments show the localized title prefix, received values and active ruleset modifiers")
		check(native.buttons.deletecharbutton.disabled and native.buttons.customcharbutton.disabled and native.record_tabs[1].disabled and native.record_tabs[3].disabled and not native.record_tabs[2].disabled,"Unmigrated local mutation and Skills/Spells stay disabled while the native Feats page is available")
		await click(native.pregen.get_global_rect().get_center()); check(native.row_keys==["server:a","vault:p","server:z"],"The source checkbox reveals supplied pregenerated records")
		check(requests.back().kind=="lobby-choose" and requests.back().key=="server:a" and not ui.native_selection.activate,"Rebuilding the filtered catalog returns selection to its first visible row without Play")
		var created:=[]; ui.creation_requested.connect(func():created.append(true)); await click(native.buttons.newcharbutton.get_global_rect().get_center())
		check(created.size()==1 and not ui.panel.visible,"Original New Character invokes the real existing creator owner")
		await present(); await row_down("server:a",true); count=requests.size(); var pending: Dictionary=ui.native_selection.duplicate()
		await present(2); state.selected="server:a"; state.selectionAck={"requestId":pending.requestId,"key":"server:a"}; await present(2)
		check(requests.size()==count+1 and requests.back().kind=="lobby-choose" and requests.back().connection==2 and requests.back().requestId!=pending.requestId and ui.native_selection.connection==2 and not ui.native_selection.activate,"Replacing the connection retires the old activation and independently selects the new connection's first row")
		check(native.buttons.playbutton.disabled,"A stale selection acknowledgment cannot unlock Play on the replacement connection")
		state.selectionAck={"requestId":ui.native_selection.requestId,"key":"server:a"}; await present(2)
		check(ui.native_selection.is_empty() and not native.buttons.playbutton.disabled and requests.size()==count+1,"Only the new automatic selection acknowledgment enables Play without submitting it")
		await row_down("server:z"); var manual: Dictionary=requests.back(); state.selected="server:z"; state.selectionAck={"requestId":manual.requestId,"key":"server:z"}; await present(2); var paint_count:=requests.size()
		text.revision+=1; await present(2)
		check(requests.size()==paint_count and state.selected=="server:z" and ui.native_selection.is_empty(),"Late text repaint preserves the user's selection rather than rebuilding the logical catalog")
		await click(native.buttons.cancelbutton.get_global_rect().get_center()); check(requests.back()=={"kind":"lobby-disconnect","saveCharacter":false,"connection":2},"Original Cancel routes to the authoritative no-save lobby disconnect")
		state={"phase":"playing","connected":true}; await present(2)
		check(not native.visible and not ui.panel.visible,"World entry hides the native chooser and releases its pointer region")
		state={"phase":"character-selection","canSelect":true,"connected":true,"choices":[{"key":"server:z","label":"Zulu","source":"server","serverSource":17,"portraitRef":"po_clsbard_","classes":[{"id":0}]}],"selected":"server:z","preview":preview_fixture}; await present(3)
		check(native.record_tabs.size()==4 and native.page.get_index()<native.buttons.playbutton.get_index() and native.page.position.y+native.page.size.y<=native.buttons.playbutton.position.y,"Four original pregame record tabs and the source viewport leave the footer controls visible above the page")
		if DisplayServer.get_name()!="headless":
			check(await wait_until(func():return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()),"Original chooser artwork and font preparation settles")
			await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Native chooser viewport saved for visual review")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	ui.close_native(); check(native.closed and native.assets.running.is_empty(),"Chooser workers retire before shared painter/catalog disposal")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"fullCharacterLobbyParity":false,"scope":"Source chooser frame, original row/portrait/list attachments, supplied metadata filtering/sorting, server table labels, scoped actual mouse input/activation/new/cancel and selected basic record fields. Full record tabs, local metadata/mutation, player/server pages, original comparison and admission remain open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
