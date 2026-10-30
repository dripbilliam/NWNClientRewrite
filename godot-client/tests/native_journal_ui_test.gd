extends "res://tests/native_quickbar_frame_test.gd"
const Notes=preload("res://systems/native_data/journal_notes.gd")
const Date=preload("res://systems/native_data/journal_date.gd")
func journal_settled(ui) -> bool:
	var skin=ui.desktop.journal_frame
	if not skin.layout_ready or not skin.failure.is_empty() or not settled(ui): return false
	return skin.quest_bar.art_ready and skin.notes_bar.art_ready and skin.quest_bar.failure.is_empty() and skin.notes_bar.failure.is_empty() and not skin.quest_bar.snapshot().layout_pending and not skin.quest_bar.snapshot().thumb_pending and not skin.notes_bar.snapshot().layout_pending and not skin.notes_bar.snapshot().thumb_pending
func type_text(value: String) -> void:
	for letter in value:
		var event:=InputEventKey.new(); event.keycode=KEY_ENTER if letter=="\n" else int(letter.to_upper().unicode_at(0)); event.physical_keycode=event.keycode; event.unicode=letter.unicode_at(0); event.pressed=true; surface.push_input(event,true); await process_frame; event=event.duplicate(); event.pressed=false; surface.push_input(event,true); await process_frame
func journal_packets() -> int: return requests.filter(func(row):return row.kind=="native-panel" and row.panel=="journal").size()
func pixels() -> Image:
	for at in 3: await process_frame
	await RenderingServer.frame_post_draw
	return surface.get_texture().get_image()
func mismatch(a: Image,b: Image,rect: Rect2i) -> int:
	var count:=0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			if a.get_pixel(x,y)!=b.get_pixel(x,y): count+=1
	return count
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,900); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original journal assets mount read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); ui.request.connect(func(m):requests.append(m.duplicate(true)))
	check(await wait_until(func():return ui.tables_ready),"Active journal TLK and original tables prepare")
	var desktop=ui.desktop; var journal=desktop.journal; var skin=desktop.journal_frame
	check(not skin.requested,"A closed native journal schedules no model work")
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"firstName":{"text":"Journal"},"lastName":{"text":"Tester"}},"hitPoints":{"current":10,"maximum":10},"stats":{"racialType":6,"classes":[{"id":10,"level":1}]}},"playerState":{}}
	var data:={"entries":[["zebra",{"tag":"zebra","title":{"text":"Zebra"},"description":{"text":"Find the zebra gate."},"date":450270,"time":420000,"priority":5,"completed":false,"isQuest":true}],["alpha",{"tag":"alpha","title":{"text":"Alpha"},"description":{"text":"Find the alpha gate."},"date":450269,"time":0,"priority":0,"completed":false,"isQuest":true}],["ordinary",{"tag":"ordinary","title":{"text":"An ordinary entry"},"description":{"text":"A received entry, not personal notes."},"date":450268,"time":0,"priority":1,"completed":false,"isQuest":false}],["done",{"tag":"done","title":{"text":"Completed work"},"description":{"text":"The server says this is complete."},"date":450271,"time":0,"priority":0,"completed":true,"isQuest":true}]],"worldEntries":[[4294967295,{"id":4294967295,"title":{"text":"A received message"},"description":{"text":"World message body"},"date":450270,"time":0}]],"loaded":true}
	var original:=data.duplicate(true); var header:={"area":{"id":55},"module":{"minutesPerHour":5},"ui":{"journal":data}}
	ui.set_world(1,55,42,[actor],{},header); desktop.panel("journal")
	check(journal_packets()==1 and requests.back().open,"Opening requests the original-compatible journal window operation once")
	check(await wait_until(func():return skin.layout_ready or not skin.failure.is_empty()),"Original journal panel, pages, rows and notes resources prepare")
	var diagnostic: Dictionary={"failure":skin.failure}
	if skin.layout_ready and skin.failure.is_empty():
		check(await wait_until(func():return journal_settled(ui)),"Native journal font, original poses and both scrollbar owners publish")
		desktop.panel("character"); check(await wait_until(func():return desktop.sheet_frame.layout_ready and settled(ui)),"A simultaneous original character sheet prepares behind the journal")
		desktop.sheet.position=Vector2(80,80); journal.position=Vector2(250,100); journal.move_to_front(); var layered:=await pixels(); desktop.sheet.hide(); var alone:=await pixels(); desktop.sheet.show()
		check(mismatch(layered,alone,Rect2i(250,100,360,460))==0,"Original journal pixels match its world-only composition even with a character sheet behind it")
		await shot(output,"-overlap"); desktop.sheet.close_sheet()
		check(not journal.window_column.visible and journal.size==Vector2(360,460) and journal.visual_extent.y==journal.tabs[3].get_rect().end.y and skin.definition.size==Vector2(360,460),"The original360x460 journal keeps its true click rectangle beside a separate Messages utility")
		check(skin.definition.tabs.size()==3 and journal.tabs[3].position.y>=460 and not journal.tabs[3].toggle_mode,"Received Messages uses a separate native-styled utility rather than a fourth original tab")
		check(journal.state.entries.size()==3 and journal.state.entries[0].key=="zebra" and journal.state.entries.any(func(row):return row.key=="ordinary"),"Active entries include received non-quest records and use original newest-date ordering")
		check(skin.row_controls.size()==3 and skin.row_controls.all(func(row):return not row.expanded) and skin.title.get_meta("native_font_applied","")=="fnt_galahad14","Original checkbox rows begin collapsed and use the source journal font")
		check(ui.inventory.frame_skin.button_geometry[skin.row_controls[0].button.get_instance_id()].styles.normal[1]=="encouraged" and ui.inventory.frame_skin.button_geometry[skin.row_controls[2].button.get_instance_id()].styles.normal[1]=="uncheckedup","Received unread flags select the original attention animation without inventing a Notes category")
		await shot(output,"-active")
		var packets:=journal_packets(); var callback: Callable=skin.row_controls[0].button.pressed.get_connections()[0].callable
		await click(skin.row_controls[0].button.get_global_rect().get_center()); check(skin.model.records.zebra.expanded and not skin.model.records.zebra.unread and journal_packets()==packets,"Real quest checkbox input expands and marks the local record read without a gameplay packet")
		check(await wait_until(func():return journal_settled(ui)),"Original expanded entry vertex art publishes after measured text")
		check(ui.inventory.frame_skin.button_geometry[skin.row_controls[0].button.get_instance_id()].styles.normal_checked[1]=="checkedup","Opening an unread record restores the source checked animation")
		var detail: RichTextLabel=skin.row_controls[0].detail; var stamp:=Date.format(450270,420000,5,ui.text.raw({"strRef":0x10c40}),ui.text.raw({"strRef":0x10c3f}))
		check(detail.get_parsed_text()==stamp+"\n\nFind the zebra gate." and detail.get_parsed_text().contains("[01:02]"),"Expanded entry includes original-format world timestamp, spacing and received description")
		callback.call(); check(skin.model.records.zebra.expanded,"A retired row callback cannot toggle a replacement view")
		await shot(output,"-expanded")
		await click(skin.sort_controls[1].get_global_rect().get_center()); check(skin.model.modes[0]==1 and journal.state.entries[0].key=="alpha" and journal_packets()==packets,"Original Name radio changes local ordering without reopening the server panel")
		await click(skin.sort_controls[2].get_global_rect().get_center()); check(skin.model.modes[0]==2 and journal.state.entries[0].key=="alpha" and journal.state.entries[1].key=="ordinary","Priority radio uses received priority with the original tie policy")
		await click(journal.tabs[1].get_global_rect().get_center()); check(journal.page==1 and journal.state.entries.size()==1 and journal.state.entries[0].key=="done" and journal_packets()==packets,"Completed tab shows only server-completed records without a second open packet")
		await click(journal.tabs[0].get_global_rect().get_center()); check(skin.model.modes[0]==2 and journal.state.entries.back().expanded,"Returning to Active retains local sort and expansion state")
		await click(journal.tabs[2].get_global_rect().get_center()); check(journal.page==2 and journal.state.entries.is_empty() and skin.edit.visible and skin.edit.has_focus() and skin.edit.text.is_empty(),"Personal Notes is an editable focused local page, never a received record category")
		var before: int=requests.size(); await type_text("My notes\nRemember the gate")
		check(skin.edit.text=="My notes\nRemember the gate" and requests.size()==before,"Actual native text input edits personal notes without sending server actions")
		check(await wait_until(func():return skin.notes.drafts.is_empty() and skin.notes.writes>0),"Personal note edits persist through the native profile writer")
		var saved:=Notes.new(); saved.configure(skin.notes.directory); saved.select(skin.model.context); check(saved.value==skin.edit.text,"A fresh notes owner reads the persisted character-specific text")
		await shot(output,"-notes")
		journal.close_button.pressed.emit(); check(not journal.visible and journal_packets()==packets+1 and requests.back().open==false,"Original close control closes only the journal and sends its real close operation")
		desktop.panel("journal"); check(journal.page==2 and skin.edit.text==saved.value and journal_packets()==packets+2,"Reopening keeps the selected Personal Notes page and its saved text")
		await click(journal.tabs[3].get_global_rect().get_center()); check(journal.page==3 and journal.state.entries.size()==1 and journal.state.entries[0].id==4294967295 and skin.row_controls[0].detail.get_parsed_text().contains("World message body"),"Separate Messages utility preserves received world text and full unsigned identity")
		await click(journal.tabs[0].get_global_rect().get_center()); skin.edit.release_focus()
		var world:=WorldInput.new(); surface.add_child(world); await click(Vector2(1000,500)); await key(KEY_W); await key(KEY_W,false); await click(Vector2(1000,500),MOUSE_BUTTON_MIDDLE); check(world.clicks==1 and world.movement==1 and world.middle==1,"Open original journal leaves outside movement, WASD and middle-camera input available")
		var gap: Vector2=journal.global_position+Vector2(300,480); await click(gap); check(world.clicks==2 and not ui.blocks_pointer(gap) and ui.blocks_pointer(journal.tabs[3].get_global_rect().get_center()),"Empty space beside Messages permits world movement while the actual utility button blocks it")
		var start: Vector2=journal.position; var point: Vector2=skin.title.get_global_rect().get_center(); await motion(point); await mouse(point,true); await motion(point+Vector2(20,25),Vector2(20,25),true); await mouse(point+Vector2(20,25),false)
		check(journal.position.distance_to(start+Vector2(20,25))<0.01,"Original journal title supports actual retained window dragging")
		var config:=ConfigFile.new(); config.load(output+".layout.cfg"); check(config.get_value("positions","journal",Vector2.ZERO)==journal.position,"Journal position persists under its own menu key")
		ui.controls.scale=Vector2.ONE*1.25; await process_frame; await process_frame; check(absf(journal.get_global_rect().size.x-450)<0.001,"125percent UI scale preserves original journal width"); await shot(output,"-scaled"); ui.controls.scale=Vector2.ONE
		var large:=original.duplicate(true)
		for at in 35: large.entries.append(["long-"+str(at),{"tag":"long-"+str(at),"title":{"text":"Received quest "+str(at)},"description":{"text":"Received detail "+str(at)},"date":at,"time":0,"priority":10,"completed":false,"isQuest":true}])
		var expanded_header:=header.duplicate(true); expanded_header.ui.journal=large; ui.set_world(1,55,42,[actor],{},expanded_header)
		check(await wait_until(func():return skin.row_controls.size()==38 and skin.quest_scroll.get_v_scroll_bar().max_value-skin.quest_scroll.get_v_scroll_bar().page>500 and journal_settled(ui)),"A long received journal publishes its real scroll range and original thumb")
		skin.quest_scroll.scroll_vertical=0; await process_frame; await process_frame; await click(skin.quest_bar.down.get_global_rect().get_center()); check(skin.quest_scroll.scroll_vertical>0,"Actual original journal arrow scrolls the long received quest list")
		await shot(output,"-long-quests")
		await click(journal.tabs[2].get_global_rect().get_center()); skin.edit.text="Stored note line\n".repeat(80)
		check(await wait_until(func():return skin.notes_scroll.get_v_scroll_bar().max_value-skin.notes_scroll.get_v_scroll_bar().page>500 and journal_settled(ui)),"Long editable notes grow within the original text viewport and scrollbar")
		skin.notes_scroll.scroll_vertical=0; await process_frame; await process_frame; await click(skin.notes_bar.down.get_global_rect().get_center()); check(skin.notes_scroll.scroll_vertical>0,"Actual original notes arrow scrolls editable local text")
		skin.edit.grab_focus(); skin.notes_scroll.scroll_vertical=0; await key(KEY_END,true,false,true); await key(KEY_END,false,false,true); await process_frame; await process_frame
		check(skin.notes_scroll.scroll_vertical>0 and skin.edit.get_caret_line()==skin.edit.get_line_count()-1,"Native Ctrl-End keeps the editing caret visible in long notes")
		await shot(output,"-long-notes")
		var long_text: String=skin.edit.text; var other:=actor.duplicate(true); other.replicated.name={"text":"Another Character"}; ui.set_world(1,55,42,[other],{},header); await process_frame; await process_frame
		check(skin.edit.text.is_empty() and skin.notes.value.is_empty(),"A controlled-character identity change cannot display the previous character's notes")
		await type_text("Other notes"); ui.set_world(1,55,42,[actor],{},header); await process_frame; await process_frame; check(skin.edit.text==long_text,"Returning to a character restores its independently saved long notes")
		var dm_header:=header.duplicate(true); dm_header.ui.players=[[1,{"objectId":42,"dm":true}]]; ui.set_world(1,55,42,[actor],{},dm_header); await process_frame; await process_frame
		check(skin.edit.text.is_empty(),"DM identity has separate notes storage from the same player-character name")
		ui.set_world(1,55,42,[actor],{},header); await process_frame; await process_frame; check(skin.edit.text==long_text,"Leaving DM identity restores the player's notes without cross-role leakage")
		check(data==original,"Journal viewing, sorting, expansion and notes never mutate authoritative input data")
		diagnostic=skin.snapshot(); diagnostic.physicalMouseWarped=false; diagnostic.art_failures=ui.inventory.frame_skin.art.failed.keys(); check(diagnostic.art_failures.is_empty(),"Native journal resources, poses and original texture bindings have no missing-art failures")
	else: check(false,"Native journal activates without fallback")
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"requests":requests,"fullJournalParity":false,"publicConnections":0,"scope":"Actual isolated native journal controls, original-resource appearance and local note persistence. Authoritative server journal events, original-client visual/input and role comparison remain separate open checks."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
