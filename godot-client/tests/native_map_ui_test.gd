extends "res://tests/native_quickbar_frame_test.gd"
func map_settled(ui) -> bool:
	var skin=ui.desktop.map_frame
	return skin.layout_ready and skin.displayed_level==skin.level and skin.jobs.is_empty() and skin.failure.is_empty() and is_instance_valid(skin.editor) and skin.editor.layout_ready and skin.editor.bar.art_ready and settled(ui) and ui.desktop.map_queue.is_empty() and ui.desktop.map_jobs.is_empty() and ui.desktop.map_set_job<0 and skin.bars.all(func(bar):return not bar.visible or bar.texture.texture!=null)
func type_text(value: String) -> void:
	for letter in value:
		var event:=InputEventKey.new(); event.keycode=KEY_ENTER if letter=="\n" else int(letter.to_upper().unicode_at(0)); event.physical_keycode=event.keycode; event.unicode=letter.unicode_at(0); event.pressed=true; surface.push_input(event,true); await process_frame; event=event.duplicate(); event.pressed=false; surface.push_input(event,true); await process_frame
func pin_point(board,pin: Dictionary) -> Vector2: return board.get_global_transform()*board.center(pin.point)
func acknowledge(desktop,message: Dictionary,accepted: bool,text: String="") -> void:
	desktop.receive({"kind":"native-action-result","action":"native-map","operation":message.operation,"requestId":message.requestId,"generation":message.generation,"areaId":message.areaId,"actorId":message.actorId,"accepted":accepted,"text":text,"result":{"sent":accepted,"serverAcknowledged":false}})
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,900); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original map assets mount read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); ui.request.connect(func(message):requests.append(message.duplicate(true)))
	check(await wait_until(func():return ui.tables_ready),"Active original map text and rules prepare")
	var desktop=ui.desktop; var panel=desktop.area_map; var board=panel.board; var skin=desktop.map_frame
	check(not skin.requested,"A closed native map schedules no frame or pin-editor preparation")
	var exploration: Array=[]; exploration.resize(1024); exploration.fill(0); exploration[0]=2
	for y in range(14,18):
		for x in range(14,18): exploration[y*32+x]=1
	var tiles: Array=[]
	for at in 1024: tiles.append({"fields":{"14":0,"24":at%4}})
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Map Tester"},"position":[155.0,155.0,0.0],"orientation":[0,1,0],"hitPoints":{"current":10,"maximum":10},"stats":{"racialType":6,"classes":[{"id":10,"level":1}]}},"playerState":{"mapExploration":{"55":exploration}}}
	var area:={"id":55,"tileset":"tic01","width":32,"height":32,"tiles":tiles,"mapPins":[{"id":4294967294,"name":{"text":"Server destination"},"enabled":true,"position":[145.0,145.0,0.0]},{"id":7,"name":{"text":"Undisclosed"},"enabled":true,"position":[5.0,5.0,0.0]},{"id":8,"name":{"text":"Disabled"},"enabled":false,"position":[155.0,155.0,0.0]}],"playerMapPins":[{"index":4294967295,"text":"Remember café","position":[165.0,165.0,0.0]}]}
	var original:=area.duplicate(true); var header:={"area":area}; ui.set_world(1,55,42,[actor],{},header); desktop.panel("map")
	check(await wait_until(func():return skin.layout_ready or not skin.failure.is_empty()),"Original generated map frame and pin editor prepare")
	var diagnostic: Dictionary={"failure":skin.failure}
	if skin.layout_ready and skin.failure.is_empty():
		check(await wait_until(func():return map_settled(ui)),"Original map poses, tile bank, font, note scrollbar and pan indicators publish")
		check(not panel.window_column.visible and skin.definition.resource=="pnl_mapgen_21x24" and panel.size.distance_to(Vector2(346,413))<0.001 and skin.level==1,"The generic map is replaced by the original dynamic frame at its native default level")
		check(skin.definition.viewport.size.distance_to(Vector2(336,384))<0.001 and skin.buttons.pinbutton.tooltip_text==ui.text.raw({"strRef":0x10807}),"Original map viewport and source help text are retained")
		check(board.tile_banks[16].size()==16 and not board.tile_banks[16].has(0) and board.pins.filter(func(pin):return pin.visible).size()==2,"Only exact-one exploration prepares/draws map tiles and visible pins")
		check(board.pins.any(func(pin):return pin.type==0 and pin.reference==4294967294) and board.pins.any(func(pin):return pin.type==1 and pin.reference==4294967295),"Server and personal pins preserve separate origins and full unsigned reference numbers")
		var server_pin: Dictionary=board.pins.filter(func(pin):return pin.type==0 and pin.visible)[0]; var personal: Dictionary=board.pins.filter(func(pin):return pin.type==1)[0]
		await shot(output,"-normal")
		await click(pin_point(board,server_pin)); check(requests.back().kind=="native-map" and requests.back().operation=="click" and requests.back().reference==4294967294,"Actual source map-pin input sends its server GUI event with the received target identity")
		acknowledge(desktop,requests.back(),true); check(not skin.editor.panel.visible and skin.pending.is_empty(),"A server-pin send does not fabricate an examination or personal-note editor")
		await click(pin_point(board,personal)); check(skin.editor.panel.visible and skin.editor.edit.text=="Remember café" and skin.editor.buttons.deletebutton.visible and skin.editor.edit.has_focus(),"Actual personal-pin input opens the original editable Map Note controls")
		await shot(output,"-editor")
		check(ui.blocks_pointer(skin.editor.panel.get_global_rect().get_center()),"The real pin editor blocks pointer movement only within its window")
		await key(KEY_A,true,false,true); await key(KEY_A,false,false,true); await type_text("Revised note\nKeep bridge")
		skin.editor.edit.text="Long note line\n".repeat(80); skin.editor.edit.grab_focus(); skin.editor.scroll.scroll_vertical=0; await key(KEY_END,true,false,true); await key(KEY_END,false,false,true); await process_frame; await process_frame
		check(await wait_until(func():return skin.editor.scroll.scroll_vertical>0 and skin.editor.edit.get_caret_line()==skin.editor.edit.get_line_count()-1),"Long native note editing keeps the caret visible through the original scrollbar")
		await shot(output,"-long-note")
		var escape_packets: int=requests.size(); await key(KEY_ESCAPE); await key(KEY_ESCAPE,false)
		check(not skin.editor.panel.visible and requests.size()==escape_packets,"Escape cancels the front native note editor while typing without a gameplay packet")
		await click(pin_point(board,personal)); skin.editor.edit.text="Unsaved Cancel"
		var count: int=requests.size(); await click(skin.editor.buttons.cancelbutton.get_global_rect().get_center()); check(not skin.editor.panel.visible and requests.size()==count,"Original Cancel closes note editing without a gameplay packet")
		await click(pin_point(board,personal)); skin.editor.edit.text="Revised note"; await click(skin.editor.buttons.okbutton.get_global_rect().get_center())
		var change: Dictionary=requests.back(); check(change.kind=="native-map" and change.operation=="change" and change.reference==4294967295 and change.position==[165.0,165.0,0.0] and change.text=="Revised note" and skin.editor.pending,"Original OK emits the real edit fields and retains pending ownership")
		check(area==original and board.pins.filter(func(pin):return pin.type==1)[0].text=="Remember café","Sending a note edit never mutates or fabricates received server state")
		var stale:=change.duplicate(); stale.requestId=int(change.requestId)+100; acknowledge(desktop,stale,false,"Stale callback"); check(skin.editor.pending,"Unrelated transport results cannot release the current editor")
		acknowledge(desktop,change,false,"Owned test refusal"); check(not skin.editor.pending and skin.editor.edit.text=="Revised note" and skin.editor.notice.text=="Owned test refusal","A real refusal leaves the source editor available with its text and feedback")
		await click(skin.editor.buttons.okbutton.get_global_rect().get_center()); change=requests.back(); acknowledge(desktop,change,true); await process_frame; await process_frame
		check(not skin.editor.panel.visible and skin.overlays.size()==1 and board.pins.filter(func(pin):return pin.type==1)[0].text=="Revised note" and area==original,"Sent edits use a distinct unconfirmed local presentation, keeping authoritative input unchanged")
		await shot(output,"-edited")
		personal=board.pins.filter(func(pin):return pin.type==1)[0]; await click(pin_point(board,personal)); await click(skin.editor.buttons.deletebutton.get_global_rect().get_center()); var deletion: Dictionary=requests.back()
		check(deletion.operation=="delete" and deletion.reference==4294967295 and skin.editor.pending,"Actual original Delete button emits the received personal reference and owns its pending operation")
		acknowledge(desktop,deletion,false,"Deletion refused"); check(skin.editor.panel.visible and not skin.editor.pending and skin.editor.notice.text=="Deletion refused","Delete refusal preserves the original editor and existing note")
		await click(skin.editor.buttons.cancelbutton.get_global_rect().get_center())
		var source: Vector2=skin.buttons.pinbutton.get_global_rect().get_center(); var target: Vector2=board.get_global_transform()*board.center(desktop.map_point([155.0,155.0,0.0],area))
		await motion(source); await mouse(source,true); await motion(source+Vector2(0,15),Vector2(0,15),true); await motion(target,target-source-Vector2(0,15),true)
		check(surface.gui_is_dragging(),"Original pin-source control starts a real isolated drag gesture")
		await mouse(target,false); await process_frame
		check(skin.editor.panel.visible and int(skin.editor.state.type)==-1 and not skin.editor.buttons.deletebutton.visible and skin.editor.state.position[0]>=154.99 and skin.editor.state.position[0]<=155.01,"Dropping on explored map art opens a new source note at the original world-coordinate conversion")
		await shot(output,"-new-note")
		await type_text("A new map note"); await click(skin.editor.buttons.okbutton.get_global_rect().get_center()); var add: Dictionary=requests.back(); acknowledge(desktop,add,true)
		check(add.operation=="add" and skin.editor.pending and skin.pending.has(int(add.requestId)) and board.pins.size()==4,"A new note remains pending after transport acceptance until its actual Added reply")
		skin.pending[int(add.requestId)].deadline=Time.get_ticks_msec()-1; await process_frame; count=requests.size(); await click(skin.editor.buttons.okbutton.get_global_rect().get_center())
		check(skin.editor.notice.text.contains("has not confirmed") and skin.editor.pending and skin.editor.buttons.okbutton.disabled and requests.size()==count,"An uncertain add shows feedback and cannot create duplicates while awaiting its actual reply")
		await shot(output,"-pending-note")
		var updated:=area.duplicate(true); updated.playerMapPins.append({"index":100,"text":add.text,"position":add.position}); ui.set_world(1,55,42,[actor],{},{"area":updated})
		check(await wait_until(func():return not skin.editor.panel.visible and not skin.pending.has(int(add.requestId)) and board.pins.any(func(pin):return pin.type==1 and pin.reference==100)),"Only matching received personal-note identity/text/position completes the pending add")
		var twin: Dictionary={"operation":"add","position":[155.0,155.0,0.0],"text":"Twin note","editorSerial":-1}; skin.send(twin); var first_twin: Dictionary=requests.back(); skin.send(twin); var second_twin: Dictionary=requests.back(); acknowledge(desktop,first_twin,true); acknowledge(desktop,second_twin,true)
		updated.playerMapPins.append({"index":101,"text":"Twin note","position":[155.0,155.0,0.0]}); ui.set_world(1,55,42,[actor],{},{"area":updated})
		check(await wait_until(func():return skin.pending.size()==1 and skin.pending.has(int(second_twin.requestId))),"One original Added identity can complete only one of two identical pending note requests")
		updated=updated.duplicate(true); updated.playerMapPins.append({"index":102,"text":"Twin note","position":[155.0,155.0,0.0]}); ui.set_world(1,55,42,[actor],{},{"area":updated})
		check(await wait_until(func():return skin.pending.is_empty()),"The second received note identity completes its own pending operation")
		updated=updated.duplicate(true); updated.playerMapPins[0].text="Revised note"; ui.set_world(1,55,42,[actor],{},{"area":updated})
		check(await wait_until(func():return skin.overlays.is_empty() and board.pins.any(func(pin):return pin.type==1 and pin.reference==4294967295 and pin.text=="Revised note" and not pin.get("unconfirmed",false))),"A matching received edit replaces its unconfirmed presentation with authoritative content")
		personal=board.pins.filter(func(pin):return pin.type==1 and pin.reference==4294967295)[0]; await click(pin_point(board,personal)); await click(skin.editor.buttons.deletebutton.get_global_rect().get_center()); deletion=requests.back(); acknowledge(desktop,deletion,true); await process_frame; await process_frame
		check(skin.overlays.size()==1 and not board.pins.any(func(pin):return pin.type==1 and pin.reference==4294967295) and updated.playerMapPins.size()==4,"Sent Delete hides only its local presentation while retaining received note ownership")
		updated=updated.duplicate(true); updated.playerMapPins=updated.playerMapPins.filter(func(pin):return pin.index!=4294967295); ui.set_world(1,55,42,[actor],{},{"area":updated})
		check(await wait_until(func():return skin.overlays.is_empty()),"A received personal-note removal retires the unconfirmed Delete presentation")
		var old_width: float=board.rect_for(board.art[int(board.controls.pin)],Vector2.ZERO,1).size.x
		await click(skin.buttons.upbutton.get_global_rect().get_center()); check(await wait_until(func():return map_settled(ui) and board.zoom==32),"Actual original Zoom In publishes the32px tile bank and matching frame")
		check(skin.buttons.upbutton.disabled and not skin.buttons.downbutton.disabled and board.rect_for(board.art[int(board.controls.pin)],Vector2.ZERO,1).size.x==old_width,"Original maximum zoom disables its endpoint while pin artwork keeps native size")
		await click(skin.buttons.downbutton.get_global_rect().get_center()); check(await wait_until(func():return map_settled(ui) and board.zoom==16),"Source Zoom Out returns to the middle level")
		await click(skin.buttons.downbutton.get_global_rect().get_center()); check(await wait_until(func():return map_settled(ui) and board.zoom==8),"Source Zoom Out publishes the8px tile bank and smaller generated window")
		check(skin.buttons.downbutton.disabled and not skin.buttons.upbutton.disabled and panel.size.distance_to(Vector2(266,285))<0.001,"Original minimum zoom uses its source frame dimensions and endpoint state")
		await shot(output,"-minimum")
		await click(skin.buttons.upbutton.get_global_rect().get_center()); await wait_until(func():return map_settled(ui)); skin.auto_center=false
		var maximum: float=panel.scroll.get_h_scroll_bar().max_value-panel.scroll.get_h_scroll_bar().page; panel.scroll.scroll_horizontal=0; await process_frame
		var horizontal=skin.bars[1]; var thumb: Vector2=horizontal.get_global_rect().get_center(); await motion(thumb); await mouse(thumb,true); await motion(thumb+Vector2(50,0),Vector2(50,0),true); await mouse(thumb+Vector2(50,0),false)
		check(maximum>0 and panel.scroll.scroll_horizontal>0,"Actual source horizontal pan indicator changes the native map scroll range")
		await shot(output,"-panned")
		ui.controls.scale=Vector2.ONE*1.25; await process_frame; await process_frame; check(absf(panel.get_global_rect().size.x-panel.size.x*1.25)<0.001,"125percent UI scale keeps the original map proportions"); await shot(output,"-scaled"); ui.controls.scale=Vector2.ONE
		var start: Vector2=panel.position; var header_point: Vector2=skin.drag_header.get_global_rect().get_center(); await motion(header_point); await mouse(header_point,true); await motion(header_point+Vector2(20,30),Vector2(20,30),true); await mouse(header_point+Vector2(20,30),false)
		check(panel.position.distance_to(start+Vector2(20,30))<0.001,"Original free header area supports retained native window dragging")
		var saved:=ConfigFile.new(); saved.load(output+".layout.cfg"); check(saved.get_value("positions","area-map",Vector2.ZERO)==panel.position,"The native map writes its retained position under the existing menu profile key")
		var world:=WorldInput.new(); surface.add_child(world); await click(Vector2(1000,500)); await key(KEY_W); await key(KEY_W,false); await click(Vector2(1000,500),MOUSE_BUTTON_MIDDLE); check(world.clicks==1 and world.movement==1 and world.middle==1,"The open map leaves outside click movement, WASD and middle-camera input available")
		await click(skin.buttons.xbutton.get_global_rect().get_center()); check(not panel.visible and not skin.editor.panel.visible,"Original map close control retires its editor and closes the map")
		desktop.panel("map"); check(panel.position.distance_to(start+Vector2(20,30))<0.001,"Reopening the map retains its last window position")
		count=requests.size(); skin.pin_selected(personal); check(requests.size()==count and not skin.editor.panel.visible,"A retained callback from the closed map cannot act on the reopened view")
		check(area==original,"Native map use and local note presentation never mutate authoritative caller data")
		diagnostic=skin.snapshot(); diagnostic.physicalMouseWarped=false; diagnostic.last_drag=board.last_drag; diagnostic.art_failures=desktop.art.failed.keys()+ui.inventory.frame_skin.art.failed.keys(); check(diagnostic.art_failures.is_empty(),"Original map controls, tile banks, editor and poses have no missing-art failures")
	else: check(false,"The native map activates without a generic fallback")
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"requests":requests,"publicConnections":0,"fullMapParity":false,"scope":"Original-resource native map, pan/zoom, actual isolated pin/edit/drag input and authoritative-vs-local presentation ownership. Original-server GUI/note lifecycle and full original-client visual/role comparison remain separate checks."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
