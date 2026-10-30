extends Node
# Drives the actual native controls. All success predicates read incoming
# replication/server-owned views. It never edits the live character or items.
var session
var ui
var desktop
var epoch:=-1
var checks: Array=[]
var failures: Array=[]
var finished:=false
var transfer_source:=0
var transfer_destination:=1
func check(value: bool,label: String,details: Dictionary={}) -> bool:
	var row:={"passed":value,"label":label,"details":details}; checks.append(row)
	if not value: failures.append(label)
	session.send({"kind":"actions-progress","check":row})
	return value
func wait_for(predicate: Callable,label: String,seconds: float=15.0) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while is_instance_valid(ui) and session.epoch==epoch and not predicate.call() and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	return check(is_instance_valid(ui) and session.epoch==epoch and predicate.call(),label)
func complete() -> void:
	if finished: return
	finished=true; session.send({"kind":"actions-finished","success":failures.is_empty(),"checks":checks,"failures":failures})
func current() -> Dictionary: return desktop.actor()
func position() -> Vector3:
	var p: Array=current().get("replicated",{}).get("position",[0,0,0]); return Vector3(p[0],p[2],-p[1])
func gold() -> int: return int(current().get("playerState",{}).get("combat",{}).get("field898",-1))
func level() -> int:
	var result:=0
	for cls in current().get("replicated",{}).get("stats",{}).get("classes",[]): result+=int(cls.level)
	return result
func item(id: int) -> Dictionary: return desktop.objects.get(id,{}).get("item",{})
func channel(id: int) -> String:
	var location: Variant=desktop.objects.get(id,{}).get("inventoryLocation")
	return str(location.get("channel","")) if location is Dictionary else ""
func stack(id: int) -> int:
	var data:=item(id); return int(data.get("stackSize",data.get("field454",0))) if not data.is_empty() else 0
func select_spell(id: int,memory: bool=false) -> int:
	for row in desktop.book.state.get("memory" if memory else "known",[]):
		if int(row.spellId)==id: desktop.book.select_entry(int(row.entryId)); return int(row.entryId)
	return -1
func preparation_cell(at: int) -> Dictionary:
	for row in desktop.book.state.get("memory",[]):
		if int(row.classIndex)==0 and int(row.level)==0 and int(row.slot)==at: return row
	return {}
func preparation_value(at: int) -> int:
	var entries: Array=current().get("playerState",{}).get("spellbooks",{}).get("0",{}).get("memorized",{}).get("0",[])
	return int(entries[at].get("spell",-1)) if at>=0 and at<entries.size() and entries[at] is Dictionary else -1
func preparation_settled(first: int,second: int) -> bool:
	return preparation_value(transfer_source)==first and preparation_value(transfer_destination)==second and desktop.preparation.pending.is_empty() and int(preparation_cell(transfer_source).get("spellId",-2))==first and int(preparation_cell(transfer_destination).get("spellId",-2))==second
func preparation_drop(source: Dictionary,destination: Dictionary) -> bool:
	if source.is_empty() or destination.is_empty(): return false
	var button=desktop.book.widgets[int(destination.entryId)]; var payload: Dictionary=desktop.book.widgets[int(source.entryId)].payload
	if not button._can_drop_data(Vector2.ZERO,payload): return false
	button._drop_data(Vector2.ZERO,payload); return true
func preparation_transfer_check() -> bool:
	var other:=-1
	for row in desktop.book.state.known:
		if int(row.classIndex)==0 and int(row.level)==0 and int(row.metamagic)==0 and int(row.spellId)!=100 and not row.family: other=int(row.spellId); break
	var light: Array=[]
	for row in desktop.book.state.memory:
		if int(row.classIndex)==0 and int(row.level)==0 and int(row.spellId)==100: light.append(int(row.slot))
	if not check(other>=0 and light.size()>=2,"Authoritative sample provides distinct known cantrips and two physical slots for transfer",{"other":other,"slots":light}): return false
	transfer_source=int(light[0]); transfer_destination=int(light[1]); var a:=transfer_source; var b:=transfer_destination
	desktop.book.select_entry(int(preparation_cell(b).entryId)); desktop.book.operation("book-clear")
	if not await wait_for(func():return preparation_settled(100,-1),"Server clears the received destination before the prepared-spell move"): return false
	if not check(preparation_drop(preparation_cell(a),preparation_cell(b)) and preparation_value(a)==100 and preparation_value(b)==-1 and desktop.preparation.pending.size()==2,"Native memory drag reserves both slots without predicting a server move"): return false
	if not await wait_for(func():return preparation_settled(-1,100),"Prepared-spell move fills destination and clears source through original-server replication"): return false
	var source: Dictionary={}
	for row in desktop.book.state.known:
		if int(row.spellId)==other and int(row.level)==0 and int(row.metamagic)==0: source=row; break
	if not preparation_drop(source,preparation_cell(a)): check(false,"Known alternate cantrip can fill the empty authoritative slot"); return false
	if not await wait_for(func():return preparation_settled(other,100),"Known-list copy supplies a distinct spell for the server exchange"): return false
	if not preparation_drop(preparation_cell(a),preparation_cell(b)): check(false,"Distinct prepared cells can start the authoritative exchange"); return false
	if not await wait_for(func():return preparation_settled(100,other),"Occupied prepared-spell exchange preserves both distinct spells on the original server"): return false
	source={}
	for row in desktop.book.state.known:
		if int(row.spellId)==100 and int(row.level)==0 and int(row.metamagic)==0: source=row; break
	if not preparation_drop(source,preparation_cell(b)): check(false,"Original Light preparation can be restored after the exchange"); return false
	return await wait_for(func():return preparation_settled(100,100),"Received Light slots are restored before the remaining gameplay checks")
func click_spell_target() -> void:
	if not desktop.target.is_empty(): desktop.world_click({"id":desktop.actor_id,"position":position()})
func inventory_action(id: int,operation: String) -> void:
	ui.inventory.ui.operation(id,operation)
func received_journal(tag: String) -> Dictionary:
	for value in desktop.state.get("journal",{}).get("entries",[]):
		var source: Dictionary=value[1] if value is Array else value
		if str(source.get("tag",""))==tag: return source
	return {}
func map_note(text: String) -> Dictionary:
	for pin in desktop.state.get("area",{}).get("playerMapPins",[]):
		if str(pin.get("text",""))==text: return pin
	return {}
func map_check() -> void:
	ui.chat.submit("-native-map-explore")
	if not await wait_for(func():return dialogue_history("NATIVE_MAP_EXPLORE") and current().get("playerState",{}).get("mapExploration",{}).get(str(desktop.area_id),[]).any(func(value):return int(value)==1),"Original server supplies exploration through its real script/API"):
		checks[-1].details={"chatAck":dialogue_history("NATIVE_MAP_EXPLORE"),"areaId":desktop.area_id,"mapKeys":current().get("playerState",{}).get("mapExploration",{}).keys(),"mapSample":current().get("playerState",{}).get("mapExploration",{}).get(str(desktop.area_id),[]).slice(0,16),"chatSystem":ui.chat.system_messages.get_parsed_text()}; return
	desktop.panel("map"); var skin=desktop.map_frame; var board=desktop.area_map.board
	if not await wait_for(func():return skin.layout_ready and skin.failure.is_empty() and skin.jobs.is_empty() and desktop.map_queue.is_empty() and desktop.map_jobs.is_empty() and skin.editor.layout_ready,"Actual local map publishes generated original frame, pin controls and source editor",30): return
	var server_pin: Dictionary={}
	for pin in board.pins:
		if int(pin.type)==0 and pin.visible and pin.text=="Native server map pin": server_pin=pin; break
	if not check(not server_pin.is_empty(),"Original server exposes the authored waypoint note as a visible map pin"): return
	board.pin_action.emit(server_pin)
	if not await wait_for(func():return dialogue_history("NATIVE_MAP_GUI_TYPE:7") and dialogue_history("NATIVE_MAP_GUI_TARGET:native_map_note"),"Native server-pin input reaches the original server OnPlayerGuiEvent and correct target"): return
	var point: Vector2=board.center(desktop.map_point([55.0,45.0,0.0],desktop.state.area)); skin.drop_note(point,{"kind":"native-map-note","viewId":desktop.area_map.view_id,"scope":skin.scope()})
	if not check(skin.editor.panel.visible and int(skin.editor.state.type)==-1,"Native map drop opens the source new-note editor in live local gameplay"): return
	skin.editor.edit.text="NATIVE_MAP_CREATED"
	await RenderingServer.frame_post_draw
	var screenshot: String=str(session.args.get("report","")).trim_suffix(".json")+"-map-note.png"
	check(not screenshot.is_empty() and not FileAccess.file_exists(screenshot) and get_viewport().get_texture().get_image().save_png(screenshot)==OK,"Actual original-server map and source note editor viewport is retained")
	skin.editor.buttons.okbutton.pressed.emit()
	if not await wait_for(func():return not map_note("NATIVE_MAP_CREATED").is_empty() and not skin.editor.panel.visible and skin.pending.is_empty(),"Original server Added reply confirms native note creation and completes its pending editor"): return
	var received:=map_note("NATIVE_MAP_CREATED").duplicate(true); var reference:=int(received.index)&0xffffffff
	check(reference>0 and absf(float(received.position[0])-55.0)<0.001 and absf(float(received.position[1])-45.0)<0.001,"Actual Added preserves server-issued note identity and original converted position")
	ui.chat.submit("-native-map-read")
	if not await wait_for(func():return dialogue_history("NATIVE_MAP_VALUE:NATIVE_MAP_CREATED:<END>"),"Original server script confirms the new note is stored on its controlled creature"): return
	var projected: Dictionary={}
	for pin in board.pins:
		if int(pin.type)==1 and int(pin.reference)==reference: projected=pin; break
	board.pin_action.emit(projected)
	if not check(skin.editor.panel.visible and skin.editor.edit.text=="NATIVE_MAP_CREATED" and skin.editor.buttons.deletebutton.visible,"Received personal-note control opens its original editable and deletable source window"): return
	skin.editor.edit.text="NATIVE_MAP_EDITED"; skin.editor.buttons.okbutton.pressed.emit()
	if not await wait_for(func():return skin.pending.is_empty() and not skin.editor.panel.visible and skin.overlays.has(str(reference)),"Native edit completes its send while retaining a separately marked unconfirmed presentation"): return
	check(map_note("NATIVE_MAP_CREATED")==received,"A sent edit does not overwrite the previously received authoritative note")
	ui.chat.submit("-native-map-read")
	if not await wait_for(func():return dialogue_history("NATIVE_MAP_VALUE:NATIVE_MAP_EDITED:<END>"),"Original server script confirms native edit changed the stored note text"): return
	projected={}
	for pin in board.pins:
		if int(pin.type)==1 and int(pin.reference)==reference: projected=pin; break
	board.pin_action.emit(projected); skin.editor.buttons.deletebutton.pressed.emit()
	if not await wait_for(func():return skin.pending.is_empty() and not board.pins.any(func(pin):return int(pin.type)==1 and int(pin.reference)==reference),"Original Delete routes the received reference and removes only its local pending presentation"): return
	ui.chat.submit("-native-map-read")
	if not await wait_for(func():return dialogue_history("NATIVE_MAP_VALUE::<END>"),"Original server script confirms Delete destroyed the stored personal note"): return
	ui.chat.submit("-native-map-hide")
	if not await wait_for(func():return board.pins.any(func(pin):return int(pin.type)==0 and int(pin.reference)==int(server_pin.reference) and not pin.visible),"Original server enable update hides its native map pin"): return
	ui.chat.submit("-native-map-show")
	if not await wait_for(func():return board.pins.any(func(pin):return int(pin.type)==0 and int(pin.reference)==int(server_pin.reference) and pin.visible),"Original server enable update restores the same native pin identity"): return
	desktop.area_map.close_button.pressed.emit(); check(not desktop.area_map.visible and not skin.editor.panel.visible,"Original map close control closes its actual local gameplay surfaces")
func journal_check() -> void:
	desktop.panel("journal")
	if not await wait_for(func():return desktop.journal.wanted and desktop.state.get("journal",{}).get("loaded",false),"Original-server open operation supplies the authoritative journal"): return
	var skin=desktop.journal_frame
	if not await wait_for(func():return skin.layout_ready and skin.failure.is_empty() and skin.quest_bar.art_ready,"Actual local journal publishes original panel, rows and scrollbar controls"): return
	ui.chat.submit("-native-journal-1")
	if not await wait_for(func():return int(received_journal("native_journal").get("state",-1))==1 and desktop.journal.state.entries.any(func(row):return row.key=="native_journal"),"Original server adds the authored journal quest through actual replication"): return
	if not check(desktop.journal.state.entries.any(func(row):return row.title.text=="NATIVE_JOURNAL_QUEST" and row.description.text.contains("NATIVE_JOURNAL_STAGE_1") and int(row.priority)==3),"Native journal displays the real JRL title, description and priority"): return
	var index:=-1
	for at in desktop.journal.state.entries.size():
		if desktop.journal.state.entries[at].key=="native_journal": index=at; break
	if not check(index>=0 and skin.row_controls.size()>index,"Received journal entry owns an actual original-style expand control"): return
	var before:=received_journal("native_journal").duplicate(true); skin.row_controls[index].button.pressed.emit()
	if not await wait_for(func():return skin.model.records.get("native_journal",{}).get("expanded",false),"Actual native quest button expands its local journal detail"): return
	if not check(received_journal("native_journal")==before,"Reading and expanding never mutate the authoritative server quest"): return
	ui.chat.submit("-native-journal-2")
	if not await wait_for(func():return int(received_journal("native_journal").get("state",-1))==2 and desktop.journal.state.entries.any(func(row):return row.key=="native_journal" and row.description.text.contains("NATIVE_JOURNAL_STAGE_2") and row.expanded),"Server quest update refreshes the native detail while retaining local expansion"): return
	if not await wait_for(func():return skin.row_controls.any(func(row):return row.detail!=null and row.detail.get_parsed_text().contains("NATIVE_JOURNAL_STAGE_2")),"Updated server text reaches the actual visible native detail control"): return
	await RenderingServer.frame_post_draw
	var screenshot: String=str(session.args.get("report","")).trim_suffix(".json")+"-journal.png"
	check(not screenshot.is_empty() and not FileAccess.file_exists(screenshot) and get_viewport().get_texture().get_image().save_png(screenshot)==OK,"Actual local journal viewport is retained for visual review")
	ui.chat.submit("-native-journal-3")
	if not await wait_for(func():return received_journal("native_journal").get("completed",false) and not desktop.journal.state.entries.any(func(row):return row.key=="native_journal"),"Original server completion retires the entry from the native Active page"): return
	desktop.journal.tabs[1].pressed.emit()
	if not await wait_for(func():return desktop.journal.page==1 and desktop.journal.state.entries.any(func(row):return row.key=="native_journal" and row.completed and row.description.text.contains("NATIVE_JOURNAL_STAGE_3")),"Original Completed control displays the actual server-completed quest"): return
	ui.chat.submit("-native-journal-0")
	if not await wait_for(func():return received_journal("native_journal").is_empty() and not skin.model.records.has("native_journal") and not desktop.journal.state.entries.any(func(row):return row.key=="native_journal"),"Original server removal revokes the quest and its native presentation identity"): return
	if not await wait_for(func():return dialogue_history("NATIVE_JOURNAL_ACK_0"),"The real journal removal script supplies server chat feedback"): return
	desktop.journal.close_button.pressed.emit(); check(not desktop.journal.visible and not desktop.journal.wanted,"Original journal close control closes the actual local gameplay window")
func dialogue_history(value: String) -> bool:
	return ui.chat.system_messages.get_parsed_text().contains(value)
func known_count(spell: int) -> int:
	var ids: Array=current().get("playerState",{}).get("spellbooks",{}).get("0",{}).get("known",[])
	return ids.filter(func(value):return int(value)==spell).size()
func scroll_item(spell: int) -> int:
	for id in ui.inventory.views:
		if channel(int(id))!="R" or int(item(int(id)).get("baseItem",-1))!=75: continue
		var properties: Array=item(int(id)).get("properties",[])
		if not properties.is_empty() and ui.inventory.item_context.policy.property_spell(properties[0])==spell: return int(id)
	return -1
func scroll_feedback_text(spell: int) -> String:
	var saved: Dictionary=ui.text.custom_tokens.duplicate(); ui.text.custom_tokens[0]=desktop.rules.title("spells",spell)
	var value: String=ui.text.resolve({"strRef":53307},2130706432); ui.text.custom_tokens=saved; return value
func recent_feedback(start: int,text: String) -> bool:
	return ui.chat.rows.slice(start).any(func(row):return row.get("category","")=="combat-feedback" and row.get("text","")==text)
func scroll_learning_check() -> bool:
	if not check(known_count(50)==0 and known_count(321)==0,"Unmodified sample wizard does not already know the two original fixture scrolls"): return false
	ui.chat.submit("-native-scroll-setup")
	if not await wait_for(func():return dialogue_history("GODOT_SCROLL_ITEMS_READY") and scroll_item(50)>=0 and scroll_item(321)>=0,"Original server creates both installed scrolls through its real script/API"): return false
	var first:=scroll_item(50); var last:=scroll_item(321); var menu=ui.inventory.item_context
	if not check(stack(first)==2 and stack(last)==1,"Received original scroll stack sizes match the authored acquisition"): return false
	var chat_start: int=ui.chat.rows.size(); var acknowledgements: int=ui.inventory.stats.get("learn_acks",0)
	ui.inventory.item_menu(first,Vector2(650,350))
	if not check(menu.entries.has(5) and menu.entries[5].action=="learn" and not menu.entries[5].disabled,"Actual scroll wheel exposes Learn from the active class rules at native slot5"): return false
	menu.wheel.choose(5)
	if not check(known_count(50)==0 and stack(first)==2 and ui.inventory.pending.has(first),"Clicking Learn reserves pending without granting a spell or consuming a scroll"): return false
	if not await wait_for(func():return known_count(50)==1 and stack(first)==1 and not ui.inventory.pending.has(first) and int(ui.inventory.stats.get("learn_acks",0))>acknowledgements and recent_feedback(chat_start,scroll_feedback_text(50)),"Original server learning updates known spells, stack, ACK and native success feedback"):
		checks[-1].details={"known":current().get("playerState",{}).get("spellbooks",{}),"stack":stack(first),"pending":ui.inventory.pending.get(first),"acks":ui.inventory.stats.get("learn_acks",0),"expectedFeedback":scroll_feedback_text(50),"chat":ui.chat.rows.slice(chat_start)}; return false
	if not await wait_for(func():return ui.inventory.views.get(first,{}).get("row",{}).get("stack",-1)==1 and not ui.inventory.views.get(first,{}).get("row",{}).get("pending",true),"Native inventory publishes the received learned-scroll count before its next interaction"): return false
	chat_start=ui.chat.rows.size(); acknowledgements=int(ui.inventory.stats.get("learn_acks",0)); ui.inventory.item_menu(first,Vector2(650,350)); menu.wheel.choose(5)
	if not await wait_for(func():return int(ui.inventory.stats.get("learn_acks",0))>acknowledgements and not ui.inventory.pending.has(first) and recent_feedback(chat_start,ui.text.raw({"strRef":53308})),"Original server duplicate refusal is visible and its ACK releases the native pending state"):
		checks[-1].details={"acks":ui.inventory.stats.get("learn_acks",0),"pending":ui.inventory.pending.get(first),"wheel":menu.snapshot(),"chat":ui.chat.rows.slice(chat_start)}; return false
	if not check(known_count(50)==1 and stack(first)==1,"Refused duplicate learning preserves the received scroll and exactly one known spell"): return false
	chat_start=ui.chat.rows.size(); ui.inventory.item_menu(last,Vector2(650,350)); menu.wheel.choose(5)
	if not await wait_for(func():return known_count(321)==1 and not ui.inventory.views.has(last) and not ui.inventory.pending.has(last) and recent_feedback(chat_start,scroll_feedback_text(321)),"Original server consumes the final scroll, removes its UI cell and teaches its spell family"): return false
	if not desktop.book.wanted: desktop.book.open()
	desktop.book.query({"classIndex":0,"level":1,"metamagic":0})
	if not await wait_for(func():return desktop.book.state.get("level",-1)==1 and desktop.book.state.get("known",[]).any(func(row):return int(row.spellId)==50) and desktop.book.state.get("known",[]).any(func(row):return int(row.spellId)==321 and row.family and not row.canDrag),"Actual native spellbook displays both server-learned spells and retains family selection"): return false
	if not await wait_for(func():
		for spell in [50,321]:
			var found:=false
			for row in desktop.book.state.get("known",[]):
				if int(row.spellId)==spell and int(row.metamagic)==0 and desktop.book.widgets.has(int(row.entryId)) and desktop.book.widgets[int(row.entryId)].image.texture!=null: found=true
			if not found: return false
		return true,"Newly learned native spellbook rows receive their original icons before visual capture"): return false
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var screenshot:=str(session.args.report).trim_suffix(".json")+"-scroll-learning.png"
		check(not FileAccess.file_exists(screenshot) and get_viewport().get_texture().get_image().save_png(screenshot)==OK,"Original-server learning, duplicate feedback and native spellbook viewport is retained")
	return check(not ui.feedback.diagnostics.any(func(reason):return reason in ["Unsupported feedback branch 78","Unsupported feedback branch 221","Unsupported feedback branch 222"]),"Learning outcomes are formatted rather than dropped as unsupported feedback")
func dialogue_check() -> bool:
	var speaker:=-1
	for id in desktop.objects:
		if int(desktop.objects[id].get("objectType",0))==5 and ui.text.name(null,int(id))=="Native Speaker": speaker=int(id); break
	if not check(speaker>=0,"Original-server dialogue fixture speaker is received"): return false
	desktop.command({"kind":"interact","targetId":speaker,"action":"conversation.start"})
	if not await wait_for(func():return ui.conversation.visible and ui.conversation.entry_id>=0 and ui.conversation.body.get_parsed_text().contains("FIRST_ENTRY"),"Ordinary native interaction opens the original server DLG"): return false
	if not check(ui.conversation.body.get_parsed_text().contains("token-ready") and ui.conversation.replies.get_child_count()==2,"Actual received dialogue preserves server custom tokens and both choices"): return false
	if not await wait_for(func():return ui.conversation_skin.layout_ready and ui.conversation_skin.failure.is_empty() and ui.conversation_skin.background.visible and ui.conversation_skin.portrait.texture!=null,"Actual local dialogue publishes original panel size artwork and speaker portrait"): return false
	if not check(ui.conversation_skin.name_label.get_parsed_text()=="Native Speaker" and not ui.conversation.window_column.visible,"Live conversation header belongs to the speaker and uses native controls"): return false
	ui.conversation.replies.get_child(0).pressed.emit()
	if not await wait_for(func():return ui.conversation.entry_id>=0 and not ui.conversation.pending and ui.conversation.body.get_parsed_text().contains("SECOND_ENTRY"),"Original-style reply control advances the actual original-server DLG"): return false
	if not await wait_for(func():return dialogue_history("GODOT_PICK_ACK"),"Dialogue choice action produces authoritative server chat feedback"): return false
	ui.conversation.replies.get_child(0).pressed.emit()
	if not await wait_for(func():return not ui.conversation.visible and dialogue_history("GODOT_END_ACK"),"Normal dialogue completion runs the server end script and closes native replies"): return false
	desktop.command({"kind":"interact","targetId":speaker,"action":"conversation.start"})
	if not await wait_for(func():return ui.conversation.visible and ui.conversation.entry_id>=0 and not ui.conversation.pending and ui.conversation.body.get_parsed_text().contains("FIRST_ENTRY"),"Same received speaker starts a fresh authoritative conversation"): return false
	ui.conversation.choose(4294967295,true)
	return await wait_for(func():return not ui.conversation.visible and dialogue_history("GODOT_ABORT_ACK"),"Native conversation abort reaches the original server abort script")
func video_menu_check(menu) -> bool:
	var video=menu.video_owner; var settings=session.window_settings
	if not await wait_for(func():return is_instance_valid(video) and video.art_ready() and settings.query_ready,"Live original video page and read-only monitor query prepare"): return false
	menu.native_frame.buttons.videooptionsbutton.pressed.emit()
	if not check(video.visible and not menu.panel.visible and video.mode_list.get_child_count()==settings.modes().size() and settings.error.is_empty(),"Live Resolution action opens original source controls and actual monitor modes"): return false
	var before: float=settings.applied_scale; var actor_id: int=ui.controlled_id; var scale_3d: float=session.root.scaling_3d_scale
	if not check(settings.maximum_scale>=before+0.09,"Owned test window has room for one original scale increment"): return false
	video.buttons.intupbutton.button_down.emit(); video.buttons.intupbutton.button_up.emit()
	check(video.pending_scale>before and settings.applied_scale==before,"Live video arrows remain pending before Apply")
	video.buttons.applybutton.button_down.emit(); video.buttons.applybutton.button_up.emit(); video.buttons.applybutton.pressed.emit()
	if not check(settings.applied_scale>before and video.visible and session.character_lobby.state.get("connected",false) and ui.controlled_id==actor_id and session.root.scaling_3d_scale==scale_3d,"Applying UI scale preserves the authoritative live actor, connection and3D resolution scale"): return false
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		session.root.get_texture().get_image().save_png(str(session.args.report).trim_suffix(".json")+".native-video.png")
	video.buttons.intdownbutton.button_down.emit(); video.buttons.intdownbutton.button_up.emit()
	video.buttons.okbutton.button_down.emit(); video.buttons.okbutton.button_up.emit(); video.buttons.okbutton.pressed.emit()
	return check(menu.panel.visible and not video.visible and is_equal_approx(settings.applied_scale,before),"Live video OK commits restored scale and returns to the same Options parent")
func inject_key(code: Key,down: bool=true) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down; get_viewport().push_input(event,true); await get_tree().process_frame
func key_control(editor,tag: String) -> void:
	editor.buttons[tag].button_down.emit(); editor.buttons[tag].button_up.emit(); editor.buttons[tag].pressed.emit()
func key_menu_check(menu) -> bool:
	var editor=menu.key_owner; var bindings=ui.key_bindings
	if not await wait_for(func():return is_instance_valid(editor) and editor.art_ready() and bindings.bindings_ready and not menu.native_frame.buttons.controlsbutton.disabled,"Live Change Key Settings prepares source artwork and the active native input owner"): return false
	menu.native_frame.buttons.controlsbutton.pressed.emit()
	if not check(editor.visible and not menu.panel.visible and editor.row_buttons.has("normal:90"),"Live Controls action opens the source key editor with real movement bindings"): return false
	editor.row_buttons["normal:90"].button_down.emit(); editor.row_buttons["normal:90"].pressed.emit(); await inject_key(KEY_T); await inject_key(KEY_T,false)
	if not check(bindings.pending.normal.values[90]==98 and bindings.active.normal.values[90]==101,"Live key assignment remains pending until the original Close action"): return false
	key_control(editor,"closebutton")
	if not check(menu.panel.visible and bindings.action_matches(90,make_key(KEY_T)),"Live Close installs the reassigned movement binding"): return false
	if not await wait_for(func():return not session.keyboard.context().is_empty(),"Server-authoritative native actor is admitted before remapped movement"): return false
	var old_focus: bool=session.keyboard.require_focus; session.keyboard.require_focus=false
	var before: int=session.keyboard.stats.drive; await inject_key(KEY_W); await inject_key(KEY_W,false)
	if not check(int(session.keyboard.stats.drive)==before,"Old movement key does not issue drive requests after rebinding"): session.keyboard.require_focus=old_focus; return false
	var start:=position(); await inject_key(KEY_T)
	var moved: bool=await wait_for(func():return position().distance_to(start)>0.15,"Rebound physical key moves the character through original-server position replication",5)
	await inject_key(KEY_T,false); session.keyboard.require_focus=old_focus
	if not moved: return false
	if not check(session.keyboard.held.is_empty() and session.keyboard.physical_held.is_empty(),"Releasing the rebound key retires native held movement"): return false
	menu.native_frame.buttons.controlsbutton.pressed.emit(); key_control(editor,"defaultbutton"); key_control(editor,"closebutton")
	return check(menu.panel.visible and bindings.action_matches(90,make_key(KEY_W)),"Live Defaults restores the original input map before remaining gameplay checks")
func make_key(code: Key) -> InputEventKey:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true; return event
func hotbar_key_check() -> bool:
	var menu=session.render_menu; var bindings=ui.key_bindings; menu.open(true)
	menu.native_frame.buttons.controlsbutton.pressed.emit(); var editor=menu.key_owner; key_control(editor,"tab1")
	if not check(editor.visible and editor.row_buttons.keys().filter(func(id):return str(id).begins_with("hotbar:")).size()==36,"Live Game key tab exposes all36 hotbar bindings"): return false
	var row: Button=editor.row_buttons["hotbar:0"]; row.button_down.emit(); row.pressed.emit(); await inject_key(KEY_G); await inject_key(KEY_G,false)
	if not check(bindings.pending.hotbar[0].key==KEY_G and bindings.active.hotbar[0].key==KEY_F1,"Live hotbar key edits remain pending without changing active input"): return false
	var shortcut: Array=desktop.state.get("quickbar",[]).duplicate(true); key_control(editor,"closebutton"); menu.dismiss()
	if not check(bindings.active.hotbar[0].key==KEY_G and desktop.state.get("quickbar",[])==shortcut,"Committing a hotbar key preserves the authoritative server shortcut contents"): return false
	var uses: int=desktop.rules.spell_uses(current(),100,0); await inject_key(KEY_G); await inject_key(KEY_G,false); click_spell_target()
	if not await wait_for(func():return desktop.rules.spell_uses(current(),100,0)<uses,"Custom hotbar key casts its assigned spell and consumes an authoritative prepared use"): return false
	menu.open(true); menu.native_frame.buttons.controlsbutton.pressed.emit(); key_control(editor,"defaultbutton"); key_control(editor,"closebutton"); menu.dismiss()
	return check(bindings.active.hotbar[0].key==KEY_F1 and desktop.state.get("quickbar",[])==shortcut,"Live hotbar Defaults restores F1 without rewriting server shortcut data")
func entry_menu_check() -> bool:
	var menu=session.render_menu
	ui.options_requested.emit()
	if not await wait_for(func():return is_instance_valid(menu.native_frame) and menu.native_frame.art_ready(),"Actual local session prepares the original in-game Options frame"): return false
	var view=menu.native_frame
	if not check(not menu.fallback.visible and view.buttons.has("savecharbutton") and not view.buttons.savecharbutton.disabled,"Live original Export control is available in its received connection context"): return false
	view.buttons.gamebutton.pressed.emit()
	if not check(session.render_settings.visible and not menu.panel.visible,"Live Game Options opens the current native child settings page"): return false
	session.render_settings.close_button.pressed.emit()
	if not check(menu.panel.visible and not session.render_settings.visible,"Closing the real settings page restores the original Options parent"): return false
	if not await video_menu_check(menu): return false
	if not await key_menu_check(menu): return false
	check(view.buttons.savebutton.disabled and view.buttons.loadbutton.disabled,"Joining a loopback original server does not fabricate local-host Save/Load privileges")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		session.root.get_texture().get_image().save_png(str(session.args.report).trim_suffix(".json")+".native-menu.png")
	view.buttons.exitbutton.pressed.emit()
	if not check(view.confirmation.visible and session.cancelled_connection!=session.session_connection,"Live End Game opens the original confirmation while preserving the current connection"): return false
	view.confirm_buttons.cancelbutton.pressed.emit()
	if not check(menu.panel.visible and not view.confirmation.visible and session.character_lobby.state.get("connected",false),"Live No returns to the source menu without disconnecting the original server"): return false
	var before: int=session.export_receipt_serial
	view.buttons.savecharbutton.pressed.emit()
	if not check(not menu.panel.visible,"Live original Export click dismisses only the menu"): return false
	if not await wait_for(func():return session.export_receipt_serial==before+1 and not session.character_lobby.state.get("busy",true),"Original Export control receives a real original-server BIC save acknowledgment",25): return false
	check(ui.chat.rows.any(func(row):return bool(row.get("system",false)) and str(row.get("text","")).begins_with("Character exported:")),"Export completion produces native system feedback after actual persistence")
	menu.open(true); view.buttons.resumegamebutton.pressed.emit()
	return check(not menu.panel.visible and session.character_lobby.state.get("connected",false),"Live Resume returns to the same authoritative world")
func run(owner) -> void:
	session=owner; ui=session.gameplay_ui; desktop=ui.desktop; epoch=session.epoch
	if not await wait_for(func():return ui.tables_ready,"Native original tables ready"): complete(); return
	if session.args.get("actions-special-attack-check","")=="true":
		var particles_before: bool=session.particle_visibility.enabled; session.particle_visibility.set_enabled(true)
		if session.args.get("actions-special-attack-kind","")=="ki" and is_instance_valid(session.frame_profile): await impact_profile_check()
		else: await special_attack_check()
		session.particle_visibility.set_enabled(particles_before); complete(); return
	if session.args.get("actions-parry-check","")=="true":
		var particles_before: bool=session.particle_visibility.enabled; session.particle_visibility.set_enabled(true)
		await parry_check(); session.particle_visibility.set_enabled(particles_before); complete(); return
	if session.args.get("actions-ranged-check","")=="true":
		var particles_before: bool=session.particle_visibility.enabled; session.particle_visibility.set_enabled(true)
		await ranged_check(); session.particle_visibility.set_enabled(particles_before); complete(); return
	if session.args.get("actions-effects-check","")=="true":
		var particles_before: bool=session.particle_visibility.enabled; session.particle_visibility.set_enabled(true)
		if session.args.get("actions-particle-crowd","")=="true": await particle_crowd_profile_check()
		elif is_instance_valid(session.frame_profile): await heal_profile_check()
		else: await effects_check()
		session.particle_visibility.set_enabled(particles_before); complete(); return
	if not ui.inventory.ui.wanted: ui.inventory.ui.open()
	if not desktop.sheet.wanted: desktop.sheet.open()
	if not await wait_for(func():return ui.inventory.views.size()>0 and current().get("inventoryStats",{}).has("fields70"),"Inventory and record receive authoritative data"): complete(); return
	if session.args.get("actions-nui-check","")=="true": await nui_check(); complete(); return
	if session.args.get("actions-radial-check","")=="true": await radial_check(); complete(); return
	if session.args.get("actions-feat-check","")=="true": await feat_family_check(); complete(); return
	if session.args.get("actions-correction-check","")=="true": await correction_check(); complete(); return
	if session.args.get("actions-players-check","")=="true": await players_protocol_check(); complete(); return
	if session.args.get("actions-barter-check","")=="true": await barter_check(); complete(); return
	if session.args.get("actions-journal-check","")=="true": await journal_check(); complete(); return
	if session.args.get("actions-map-check","")=="true": await map_check(); complete(); return
	if not await entry_menu_check(): complete(); return
	if not await dialogue_check(): complete(); return
	var chest:=-1; var potion:=-1
	for id in ui.inventory.views:
		var row: Dictionary=ui.inventory.views[id].row
		if row.channel=="I" and int(row.slot)==2: chest=int(id)
		if row.channel=="R" and int(item(int(id)).get("baseItem",-1))==49 and item(int(id)).get("properties",[]).any(func(p):return int(p.type)==15): potion=int(id)
	if not check(chest>=0 and potion>=0,"Original sample provides equipped chest and carried potion",{"chest":chest,"potion":potion}): complete(); return
	var menu=ui.inventory.item_context
	ui.inventory.item_menu(chest,Vector2(650,350))
	if not check(menu.wheel.active and menu.entries.has(6) and menu.entries[6].action=="unequip","Actual equipped-item wheel exposes original Unequip slot6"): complete(); return
	menu.wheel.choose(6)
	if not await wait_for(func():return channel(chest)=="R" and not ui.inventory.pending.has(chest) and ui.inventory.views.get(chest,{}).get("row",{}).get("channel","")=="R","Unequip moves the chest to the server backpack"): complete(); return
	inventory_action(chest,"toggle")
	if not await wait_for(func():return channel(chest)=="I" and not ui.inventory.pending.has(chest),"Equip restores the actual server equipment slot"): complete(); return
	var before_split:=stack(potion); var original_potions: Array=[]
	for id in ui.inventory.views:
		if int(item(int(id)).get("baseItem",-1))==49: original_potions.append(int(id))
	ui.inventory.item_menu(potion,Vector2(650,350))
	if not check(menu.entries.has(6) and menu.entries[6].action=="split" and not menu.entries[6].disabled,"Original carried potion wheel exposes Split stack"): complete(); return
	menu.wheel.choose(6)
	if not await wait_for(func():return ui.inventory.stack_dialog.modal!=null and ui.inventory.stack_dialog.modal.visible,"Original INV_STACKSPLIT dialog opens for the current item"): complete(); return
	ui.inventory.stack_dialog.number.text="1.9"; ui.inventory.stack_dialog.buttons.okbutton.pressed.emit()
	if not await wait_for(func():return stack(potion)==before_split-1 and not ui.inventory.pending.has(potion),"Original server confirms the selected split amount without a local stack edit"): complete(); return
	var split_id:=-1
	for id in ui.inventory.views:
		if not original_potions.has(int(id)) and int(item(int(id)).get("baseItem",-1))==49 and channel(int(id))=="R": split_id=int(id)
	if not check(split_id>=0 and stack(split_id)==1 and stack(split_id)+stack(potion)==before_split,"Server creates a separate potion item and conserves total stack count"): complete(); return
	var acknowledgements:=int(ui.inventory.stats.get("learn_acks",0)); var preserved:=stack(potion)
	var refusal_chat: int=ui.chat.rows.size()
	ui.inventory.input_request({"kind":"inventory-action","viewId":ui.inventory.view_serial,"entryId":potion,"operation":"learn"})
	if not await wait_for(func():return int(ui.inventory.stats.get("learn_acks",0))>acknowledgements and not ui.inventory.pending.has(potion) and not ui.inventory.views.get(potion,{}).get("row",{}).get("pending",true),"Original server learn reply releases pending even for a non-scroll refusal"): complete(); return
	check(stack(potion)==preserved,"Learn acknowledgement does not fabricate success or consume a refused non-scroll")
	if not await wait_for(func():return recent_feedback(refusal_chat,ui.text.raw({"strRef":53309})),"Original server non-scroll refusal appears in native feedback"): complete(); return
	if not await scroll_learning_check(): complete(); return
	var potion_before:=stack(potion); ui.inventory.item_menu(potion,Vector2(650,350))
	if not check(menu.entries.has(3) and menu.entries[3].action=="use","Actual native item wheel exposes its received potion power at slot3"): complete(); return
	menu.wheel.choose(3); click_spell_target()
	if not await wait_for(func():return stack(potion)<potion_before,"Item power consumes a real server potion stack"): complete(); return
	check(stack(potion)==potion_before-1,"One item activation spends one potion",{"before":potion_before,"after":stack(potion)})
	if not desktop.book.wanted: desktop.book.open()
	desktop.book.query({"classIndex":0,"level":0,"metamagic":0})
	if not await wait_for(func():return desktop.book.state.get("level",-1)==0 and desktop.book.state.get("known",[]).any(func(row):return int(row.spellId)==100),"Native spellbook receives prepared Light"): complete(); return
	var before_uses: int=desktop.rules.spell_uses(current(),100,0)
	if not check(before_uses>=2,"Sample has two ready Light preparations",{"uses":before_uses}): complete(); return
	select_spell(100); desktop.book.operation("book-activate"); click_spell_target()
	if not await animation_check("cast",100): complete(); return
	if not await wait_for(func():return desktop.rules.spell_uses(current(),100,0)<before_uses,"Spellbook cast consumes an authoritative prepared use"): complete(); return
	var entry:=select_spell(100); desktop.quickbar.render(0)
	desktop.quickbar.buttons[0].dropped.emit({"kind":"spell","viewId":desktop.book.view_id,"entryId":entry})
	if not await wait_for(func():return desktop.state.get("quickbar",[]).size()>0 and int(desktop.state.quickbar[0].get("type",0))==2 and int(desktop.state.quickbar[0].get("intParam",-1))==100 and desktop.quick_bindings.size()>0 and int(desktop.quick_bindings[0].get("intParam",-1))==100,"Dragging a spell to the quickbar is replicated by the server"): complete(); return
	if not await hotbar_key_check(): complete(); return
	if select_spell(100,true)<0: check(false,"Spent Light remains selectable in preparation slots"); complete(); return
	desktop.book.operation("book-clear")
	if not await wait_for(func():return desktop.book.state.get("memory",[]).any(func(row):return int(row.spellId)<0),"Clear preparation removes a server memorized slot"): complete(); return
	select_spell(100); desktop.book.operation("book-prepare")
	if not await wait_for(func():return not desktop.book.state.get("memory",[]).any(func(row):return int(row.spellId)<0),"Prepare fills the slot through server replication"): complete(); return
	if not await preparation_transfer_check(): complete(); return
	ui.chat.submit("-native-party-add")
	if not await wait_for(func():return desktop.party.rows.size()>1,"Server henchman membership appears in the party HUD"): complete(); return
	desktop.open_radial({"id":desktop.actor_id,"position":position()},Vector2(600,350))
	var command_slot:=-1
	for slot in desktop.radial_entries:
		if str(desktop.radial_entries[slot].label)=="Issue command": command_slot=int(slot)
	if not check(command_slot>=0,"Self radial exposes party commands"): complete(); return
	desktop.radial.choose(command_slot)
	for slot in desktop.radial_entries:
		if int(desktop.radial_entries[slot].get("binding",{}).get("intParam",-1))==22: desktop.radial.choose(int(slot)); break
	ui.chat.submit("-native-party-remove")
	if not await wait_for(func():return desktop.party.rows.size()==1,"Server removal retires the actual party card"): complete(); return
	ui.chat.submit("-native-store-setup")
	if not await wait_for(func():return gold()>40000,"Authored server script supplies test trade gold"): complete(); return
	ui.chat.submit("-native-store")
	if not await wait_for(func():return ui.inventory.store.get("open",false) and ui.inventory.ui.store_panel!=null and ui.inventory.ui.store_panel.visible,"Server OpenStore opens native merchant controls"): complete(); return
	if not await wait_for(func():return ui.inventory.store_skin.built(),"Actual local merchant uses the original native store GUI and confirmation meshes"): complete(); return
	if not check(ui.inventory.ui.store_panel.repository.size==Vector2(330,330) and ui.inventory.ui.store_panel.repository.cell_size==33 and ui.inventory.ui.store_panel.repository.bottom_origin,"Actual server merchant uses the native10×10 bottom-origin grid"): complete(); return
	if not await wait_for(func():return ui.inventory.views.values().any(func(view):return view.row.channel=="M"),"Merchant stock is received from the server"): complete(); return
	var stock_id:=-1
	for id in ui.inventory.views:
		if ui.inventory.views[id].row.channel=="M": stock_id=int(id); break
	var before_gold:=gold(); var price:=int(ui.inventory.views[stock_id].row.price)
	var trade_commands: int=ui.inventory.stats.commands
	ui.inventory.ui.store_panel.select_item(stock_id)
	if not check(ui.inventory.ui.store_panel.selection.visible and ui.inventory.ui.store_panel.prompt.get_parsed_text().contains(str(price)),"Original native confirmation displays the actual server-context purchase price"): complete(); return
	ui.inventory.ui.store_panel.confirm.pressed.emit()
	ui.inventory.ui.store_panel.select_item(stock_id); ui.inventory.ui.store_panel.confirm.pressed.emit()
	check(int(ui.inventory.stats.commands)==trade_commands+1,"Repeated purchase clicks send one pending server request")
	if not await wait_for(func():return channel(stock_id) in ["R","I"] and gold()<before_gold,"Buy changes actual item ownership and server gold"): complete(); return
	check(gold()==before_gold-price,"Server purchase charge matches displayed price",{"before":before_gold,"after":gold(),"price":price})
	if not await wait_for(func():return ui.inventory.ui.items.has(stock_id) and ui.inventory.ui.items[stock_id].channel in ["R","I"] and not ui.inventory.ui.items[stock_id].pending,"Bought item appears in the native player repository"): complete(); return
	before_gold=gold(); var sell_price:=int(ui.inventory.ui.items[stock_id].price)
	ui.inventory.ui.store_panel.select_item(stock_id); ui.inventory.ui.store_panel.confirm.pressed.emit()
	if not await wait_for(func():return channel(stock_id)=="M" and gold()>before_gold,"Sell returns the same item to actual merchant ownership"): complete(); return
	check(gold()==before_gold+sell_price,"Server sale credit matches displayed price",{"before":before_gold,"after":gold(),"price":sell_price})
	var identify_id:=-1
	for id in ui.inventory.views:
		var row: Dictionary=ui.inventory.views[id].row
		if row.channel=="R" and row.canIdentify: identify_id=int(id); break
	if not check(identify_id>=0,"Original local merchant fixture supplies a real carried unidentified item"): complete(); return
	before_gold=gold()
	ui.inventory.ui.operation(identify_id,"examine")
	if not await wait_for(func():return ui.examine.visible and int(ui.examine.state.get("targetId",-1))==identify_id and ui.examine_skin.layout_ready and ui.examine_skin.mode=="item","Actual server examination opens the original native item panel"): complete(); return
	if not await wait_for(func():return ui.examine.state.get("identified",false) and item(identify_id).get("identified",false) and gold()==before_gold,"Original server Lore identifies a cheap item without charging the merchant fee"): complete(); return
	if not check(ui.examine_skin.identify_button.disabled,"Native Identify is disabled after the server's free Lore identification"): complete(); return
	var existing_items: Array=ui.inventory.views.keys()
	ui.chat.submit("-native-identify-setup")
	var paid_item:=func():
		for id in ui.inventory.views:
			var row: Dictionary=ui.inventory.views[id].row
			if not existing_items.has(id) and row.channel=="R" and row.canIdentify: return int(id)
		return -1
	if not await wait_for(func():return int(paid_item.call())>=0,"Original server creates the high-value paid-identification target from its installed template"): complete(); return
	identify_id=int(paid_item.call()); ui.inventory.ui.operation(identify_id,"examine")
	if not await wait_for(func():return int(ui.examine.state.get("targetId",-1))==identify_id and not ui.examine.state.get("identified",true),"High-value item remains unidentified after the actual server Lore check"): complete(); return
	var fee:=int(ui.inventory.store.identifyPrice); before_gold=gold()
	if not check(ui.examine_skin.identify_button.visible and not ui.examine_skin.identify_button.disabled and ui.examine_skin.fee_label.get_parsed_text().contains(str(fee)),"Original native Identify button displays the actual merchant fee",{"context":ui.examine_skin.context(),"examine_identified":ui.examine.state.get("identified"),"fee_text":ui.examine_skin.fee_label.get_parsed_text(),"button_visible":ui.examine_skin.identify_button.visible,"button_disabled":ui.examine_skin.identify_button.disabled}): complete(); return
	var identify_commands: int=ui.inventory.stats.commands
	ui.examine_skin.identify_button.pressed.emit()
	if not check(gold()==before_gold and not item(identify_id).identified and ui.examine_skin.identify_button.disabled,"Identify does not predict item flags or the server gold charge"): complete(); return
	ui.examine_skin.identify_button.pressed.emit()
	if not check(ui.inventory.stats.commands==identify_commands+1,"Original Identify control cannot submit duplicates while awaiting examination"): complete(); return
	if not await wait_for(func():return item(identify_id).get("identified",false) and ui.examine.state.get("identified",false) and gold()==before_gold-fee and not ui.inventory.pending.has(identify_id),"Original server identifies the exact item, refreshes examination and charges the exact fee"): complete(); return
	check(ui.examine_skin.identify_button.disabled and ui.examine_skin.waiting.is_empty(),"Authoritative identified examination retires native pending state")
	ui.examine.hide()
	ui.inventory.ui.store_panel.command("close")
	if not await wait_for(func():return not ui.inventory.store.get("open",false),"Closing merchant retires server store state"): complete(); return
	if not await gold_transfer_check(): complete(); return
	if not await level_up(10): complete(); return
	if not await level_up(4): complete(); return
	if not await rest_and_feat_check(): complete(); return
	if not await combat_check(): complete(); return
	complete()
func gold_transfer_check() -> bool:
	var transfer=ui.inventory.gold
	if not await wait_for(func():return transfer.layout_ready,"Original native gold amount controls are ready"): return false
	if desktop.book.wanted: desktop.panel("spells")
	if desktop.sheet.wanted: desktop.panel("character")
	ui.inventory.ui.open()
	if not await wait_for(func():return not ui.inventory.ui.store_panel.visible,"Server store closure retires the native blocking merchant panel"): return false
	var before:=gold(); var existing: Array=desktop.objects.keys()
	ui.inventory.frame_skin.gold_button.pressed.emit()
	if not check(transfer.modal.visible and transfer.maximum==before,"Gold button opens original amount controls from actual server balance"): return false
	transfer.number.text="7.9"; transfer.buttons.okbutton.pressed.emit()
	if not check(transfer.payload.get("amount")==7,"Live native amount confirmation preserves the original decimal prefix before sending gold"): return false
	if not check(not transfer.payload.is_empty() and get_viewport().gui_is_dragging(),"Original amount confirmation creates a native private gold drag"): return false
	var screen:=Vector2.ZERO; var destination: Dictionary={}; var candidates: Array=[]
	for offset in [Vector3(0.8,0,0),Vector3(-0.8,0,0),Vector3(0,0,0.8),Vector3(0,0,-0.8),Vector3(1.5,0,1.5),Vector3(3,0,0),Vector3(-3,0,0),Vector3(0,0,3),Vector3(0,0,-3)]:
		var candidate: Vector2=session.camera.unproject_position(position()+offset)
		var selected: Dictionary=transfer.world_destination(candidate)
		var hit: Dictionary=transfer.world_pick.call(candidate)
		candidates.append({"screen":[candidate.x,candidate.y],"blocked":transfer.world_blocked.call(candidate),"id":hit.get("id"),"position":str(hit.get("position")),"destination":selected})
		if int(selected.get("targetId",-1))==2130706432: screen=candidate; destination=selected; break
	var point: Vector2=session.camera.unproject_position(position())
	var blockers: Dictionary={"desktop":desktop.blocks_pointer(point),"inventory":ui.inventory.blocks_pointer(point),"nui":ui.nui.blocks_pointer(point),"chat":ui.chat.visible and ui.chat.get_global_rect().has_point(point),"conversation":ui.conversation.visible and ui.conversation.get_global_rect().has_point(point),"examine":ui.examine.visible and ui.examine.get_global_rect().has_point(point),"inventory_rect":str(ui.inventory.ui.get_global_rect()),"inventory_visible":ui.inventory.ui.visible,"store_visible":ui.inventory.ui.store_panel.visible,"store_rect":str(ui.inventory.ui.store_panel.get_global_rect())}
	if not check(not destination.is_empty(),"Actual native world picker finds a ground gold destination",{"screen":[screen.x,screen.y],"destination":destination,"candidates":candidates,"blockers":blockers}): return false
	transfer._drop_data(transfer.get_global_transform().affine_inverse()*screen,transfer.payload.duplicate(true)); get_viewport().gui_cancel_drag()
	if not check(gold()==before,"Sending gold never predicts the authoritative balance"): return false
	if not await wait_for(func():return gold()==before-7,"Unchanged original server deducts exactly the dragged gold amount"): return false
	var heap_id:=-1
	var find_heap:=func():
		for id in desktop.objects:
			var object: Dictionary=desktop.objects[id]
			if not existing.has(id) and int(object.get("objectType",0))==6 and int(object.get("areaId",-1))==desktop.area_id and not object.get("replicationRemoved",false): return int(id)
		return -1
	if not await wait_for(func():return find_heap.call()>=0,"Original server replicates the new physical gold heap"): return false
	heap_id=int(find_heap.call()); var gold_base:=int(item(heap_id).get("baseItem",-1)); desktop.command({"kind":"pickup","targetId":heap_id})
	if not await wait_for(func():return gold()==before,"Picking up the actual server gold heap restores the original balance"): return false
	var recipient:=-1
	for id in desktop.objects:
		var object: Dictionary=desktop.objects[id]
		if int(id)!=desktop.actor_id and int(object.get("objectType",0))==5 and not object.get("replicationRemoved",false): recipient=int(id); break
	ui.inventory.frame_skin.gold_button.pressed.emit(); transfer.number.text="9"; transfer.buttons.okbutton.pressed.emit()
	if not check(transfer.can_target(transfer.payload,recipient),"Received creature is a valid original gold drag destination",{"id":recipient}): return false
	transfer.drop_target(transfer.payload.duplicate(true),recipient); get_viewport().gui_cancel_drag()
	# Original TransferGold starts barter for creatures. A non-PC recipient is
	# rejected by StartBarter and the temporary gold item returns to the donor.
	if not await wait_for(func():return gold()==before and ui.chat.rows.any(func(row):return row.get("category","")=="barter-reject" and int(row.get("targetId",-1))==recipient and int(row.get("reason",0))==1),"Original server rejects NPC barter, restores gold and displays its native rejection"): return false
	var chest:=-1
	for id in desktop.objects:
		if int(desktop.objects[id].get("objectType",0))==9 and ui.text.name(null,int(id))=="Native container chest": chest=int(id); break
	if not check(chest>=0,"Original local fixture provides a real container target"): return false
	desktop.command({"kind":"interact","targetId":chest,"action":"object.use"})
	if not await wait_for(func():return int(ui.inventory.containers.get("C",-1))==chest and ui.inventory.frame_skin.container_stage.visible,"Original server opens the actual container inventory"): return false
	ui.inventory.frame_skin.gold_button.pressed.emit(); transfer.number.text="5"; transfer.buttons.okbutton.pressed.emit()
	ui.inventory.ui.container_repository._drop_data(Vector2(180,40),transfer.payload.duplicate(true)); get_viewport().gui_cancel_drag()
	if not await wait_for(func():return gold()==before-5,"Original server deposits the dragged gold into the container"): return false
	var find_container_gold:=func():
		for entry in ui.inventory.views:
			var row: Dictionary=ui.inventory.views[entry].row
			if row.channel=="C" and int(item(int(row.itemId)).get("baseItem",-2))==gold_base: return int(entry)
		return -1
	if not await wait_for(func():return find_container_gold.call()>=0,"Native container receives the real original gold item"): return false
	ui.inventory.ui.operation(int(find_container_gold.call()),"move",{"destination":"backpack"})
	if not await wait_for(func():return gold()==before,"Moving the server container gold back restores the authoritative balance"): return false
	ui.inventory.ui.container_controls.close.pressed.emit()
	return await wait_for(func():return int(ui.inventory.containers.get("C",2130706432))==2130706432,"Native container close completes after the real gold cycle")
func party_flags() -> Dictionary: return current().get("replicated",{}).get("party",{})
func has_party_member(id: int) -> bool: return desktop.state.get("party",[]).any(func(row):return int(row.id)==id)
func peer_has_party_member(id: int) -> bool: return session.test_barter_peer.get("party",[]).any(func(row):return int(row.id)==id)
func peer_invite_named() -> bool:
	var notice=session.test_barter_peer.get("partyInviteNotice")
	return notice is Dictionary and not str(notice.get("name","")).is_empty()
func party_command(operation: String,target_id: int=-1) -> void:
	var skin=desktop.players_frame
	await get_tree().process_frame; await get_tree().process_frame
	if skin.layout_ready and desktop.players.wanted and operation!="list":
		if skin.popup.panel.visible and operation in ["accept","reject","ignore"]:
			skin.popup.buttons[{"accept":"okbutton","reject":"rejectbutton","ignore":"cancelbutton"}[operation]].pressed.emit(); return
		var tag: String={"invite":"invitebutton","kick":"invitebutton","accept":"invitebutton","reject":"leavebutton","leave":"leavebutton","transfer":"transferbutton","ignore":"transferbutton"}.get(operation,"")
		if not tag.is_empty():
			var expected: String={"invite":"ir_invite","kick":"ir_kick","accept":"ir_accept","reject":"ir_reject","leave":"ir_leave","transfer":"ir_transleader","ignore":"ir_ignore"}[operation]
			if not await wait_for(func():return not skin.buttons[tag].disabled and ui.inventory.frame_skin.button_geometry[skin.buttons[tag].get_instance_id()].overrides.gui_replace01==expected,"Original native "+operation+" control reaches its received-state presentation"): return
			skin.buttons[tag].pressed.emit(); return
	var value: Dictionary={"kind":"native-party","operation":operation}
	if operation in ["accept","reject","ignore"]: value.targetId=int(party_flags().get("field7D8",-1))
	elif target_id>=0:
		for entry in desktop.state.get("players",[]):
			if int(entry[1].get("objectId",-1))==target_id: value.playerId=int(entry[0]); value.targetId=target_id; break
	desktop.command(value)
func players_protocol_check() -> void:
	barter_peer_command("start-peer")
	if not await wait_for(func():return session.test_barter_peer.get("ready",false) or session.test_barter_peer.has("error"),"Second owned party participant completes admission",65): return
	if not check(session.test_barter_peer.get("ready",false),"Second real party participant enters the original loopback server",session.test_barter_peer): return
	var partner:=int(session.test_barter_peer.mainViewActorId); var remote_main:=int(session.test_barter_peer.mainTargetId)
	if not await players_frame_check(partner): return
	if not check(partner!=desktop.actor_id and not has_party_member(partner) and not peer_has_party_member(remote_main),"Two original-server characters begin in separate authoritative parties",{"main":party_flags(),"peer":session.test_barter_peer.partyState}): return
	await party_command("invite",partner)
	if not await wait_for(func():return session.test_barter_peer.get("partyState",{}).get("field7DC",false),"Original server replicates the invitation to its actual recipient"): return
	if not await wait_for(func():return int(session.test_barter_peer.partyState.field7D8)==remote_main and peer_invite_named(),"Original popup supplies inviter text and creature replication supplies its separate full identity"): return
	barter_peer_command("party-reject")
	if not await wait_for(func():return not session.test_barter_peer.get("partyState",{}).get("field7DC",true),"Actual Reject request clears the original server invitation"): return
	if not check(not has_party_member(partner) and not peer_has_party_member(remote_main),"Reject leaves both authoritative groups separate"): return
	await party_command("invite",partner)
	if not await wait_for(func():return session.test_barter_peer.get("partyState",{}).get("field7DC",false),"Original server accepts a fresh invitation after rejection"): return
	barter_peer_command("party-accept")
	if not await wait_for(func():return has_party_member(partner) and peer_has_party_member(remote_main),"Actual Accept joins both original-server party lists"): return
	if not await wait_for(func():return party_flags().get("leader",false) and not session.test_barter_peer.get("partyState",{}).get("leader",true),"Server creature flags identify the original inviter as group leader"): return
	await party_command("transfer",partner)
	if not await wait_for(func():return not party_flags().get("leader",true) and session.test_barter_peer.get("partyState",{}).get("leader",false),"Native transfer request changes leadership through original-server replication"): return
	barter_peer_command("party-kick")
	if not await wait_for(func():return not has_party_member(partner) and not peer_has_party_member(remote_main),"The new leader can actually remove the other participant through the original server"): return
	await party_command("invite",partner)
	if not await wait_for(func():return session.test_barter_peer.get("partyState",{}).get("field7DC",false),"Split groups can receive another actual invitation"): return
	barter_peer_command("party-accept")
	if not await wait_for(func():return has_party_member(partner) and peer_has_party_member(remote_main),"Both real peers rejoin through their original party lists"): return
	await party_command("leave")
	if not await wait_for(func():return not has_party_member(partner) and not peer_has_party_member(remote_main),"Native Leave splits the group through the original server without a predicted membership edit"): return
	barter_peer_command("party-invite")
	if not await wait_for(func():return party_flags().get("field7DC",false),"The main client receives a peer-initiated original invitation"): return
	await party_command("ignore")
	if not await wait_for(func():return not party_flags().get("field7DC",true),"Native Ignore reaches the original server and retires the pending invitation"): return
	if not check(not has_party_member(partner) and not peer_has_party_member(remote_main),"Ignoring an invitation never fabricates group membership"): return
	var revision:=int(desktop.state.get("partyListRevision",0)); await party_command("list")
	await wait_for(func():return int(desktop.state.get("partyListRevision",0))>revision,"Explicit native list refresh receives a new original-server party list")
func players_frame_check(partner: int) -> bool:
	if not desktop.players.wanted: desktop.panel("pvp")
	var skin=desktop.players_frame
	if not await wait_for(func():return skin.layout_ready and skin.popup.layout_ready and skin.failure.is_empty() and skin.jobs.is_empty() and skin.bar.art_ready and skin.cards.size()==1,"Live original player frame, source controls and remote player row publish",30): return false
	var player_id:=int(desktop.players.rows[0].playerId); skin.cards[player_id].button.pressed.emit()
	if not await wait_for(func():return dialogue_history("NATIVE_PLAYERS_GUI_TYPE:12") and dialogue_history("NATIVE_PLAYERS_GUI_TARGET:NativeBarterPartner"),"Native player selection reaches the original server GUI event12 and correct remote account"): return false
	if not await wait_for(func():return skin.pending.is_empty(),"Selection send releases its actual native pending owner"): return false
	skin.buttons.tellbutton.pressed.emit()
	if not await wait_for(func():return dialogue_history("NATIVE_PLAYERS_GUI_TYPE:28"),"Original Tell button reaches its distinct server GUI event28"): return false
	if not check(ui.chat.entry.text.begins_with('/t "') and ui.chat.entry.has_focus(),"Actual live Tell button primes the native quoted chat entry"): return false
	ui.chat.entry.clear(); ui.chat.entry.release_focus()
	if not await wait_for(func():return skin.pending.is_empty(),"Tell send releases its native owner without sending premature chat"): return false
	skin.cards[player_id].attitude.pressed.emit()
	if not await wait_for(func():return desktop.players.rows[0].ownLikes==0 and skin.cards[player_id].attitude.button_pressed,"Original server acknowledges a native Dislike checkbox as the separate local attitude"): return false
	barter_peer_command("attitude",false)
	if not await wait_for(func():return desktop.players.rows[0].incomingLikes==0,"The other real player changes the distinct incoming attitude through the original server"): return false
	if not await wait_for(func():return skin.pending.is_empty(),"Dislike sends retire before a new native checkbox request"): return false
	skin.cards[player_id].attitude.pressed.emit()
	if not await wait_for(func():return desktop.players.rows[0].ownLikes==1 and desktop.players.rows[0].incomingLikes==0,"Restoring local Like preserves the independently received remote Dislike"): return false
	barter_peer_command("attitude",true)
	if not await wait_for(func():return desktop.players.rows[0].incomingLikes==1 and skin.pending.is_empty(),"Both real players restore their independent server-owned attitudes"): return false
	await RenderingServer.frame_post_draw; get_viewport().get_texture().get_image().save_png(session.args.report.trim_suffix(".json")+"-players.png")
	return check(skin.cards[player_id].button.size.distance_to(Vector2(335,29))<0.01 and desktop.players.rows[0].objectId==partner,"Actual local multiplayer preserves the original player-row proportions and received target")
func barter_check() -> void:
	barter_peer_command("start-peer")
	if not await wait_for(func():return session.test_barter_peer.get("ready",false) or session.test_barter_peer.has("error"),"Second owned local barter peer completes its admission attempt",65): return
	if not check(session.test_barter_peer.get("ready",false),"Second real participant enters the original loopback server",session.test_barter_peer): return
	var partner:=int(session.test_barter_peer.mainViewActorId)
	if not await wait_for(func():return desktop.objects.has(partner) and session.world.instances.has(partner),"Native world receives and renders the actual second participant"): return
	barter_peer_command("prepare-item")
	if not await wait_for(func():return session.test_barter_peer.get("preparedItemId")!=null and session.test_barter_peer.backpack.has(session.test_barter_peer.preparedItemId),"Second real participant unequips its original armor through the server"): return
	var peer_item:=int(session.test_barter_peer.preparedItemId); var own_item:=-1
	for id in ui.inventory.views:
		var row: Dictionary=ui.inventory.views[id].row
		if row.channel=="I" and int(row.slot)==2: own_item=int(id); break
	if not check(own_item>=0,"Main sample provides an original equipped chest item for barter"): return
	inventory_action(own_item,"unequip")
	if not await wait_for(func():return channel(own_item)=="R" and not ui.inventory.pending.has(own_item),"Main barter item moves to its real server backpack"): return
	var before:=gold(); var peer_before:=int(session.test_barter_peer.gold)
	desktop.open_radial({"id":partner,"position":session.world.instances[partner].position},Vector2(650,350))
	var slot:=-1
	for index in desktop.radial_entries:
		if desktop.radial_entries[index].get("action","")=="barter": slot=int(index); break
	if not check(slot==7,"Original other-player radial offers Barter at slot7"): return
	desktop.radial.choose(slot)
	if not await wait_for(func():return ui.barter.active() and ui.barter.view.visible,"Native player radial starts an actual server barter session"): return
	if not check(ui.barter.state.initiator and int(ui.barter.state.partnerId)==partner,"Native trade correctly identifies the initiating player's side"): return
	if not await barter_offer(own_item): return
	barter_peer_command("add")
	if not await wait_for(func():return ui.barter.all_rows.has(peer_item) and ui.barter.all_rows[peer_item].channel=="A","Native trade receives the real remote item in its read-only offer"): return
	if not check(not ui.barter.view.grids.A._can_drop_data(Vector2(16,16),ui.barter.payload(own_item)),"Remote offer grid rejects local drag input"): return
	var move_data: Dictionary=ui.barter.payload(own_item)
	ui.barter.view.grids.B._drop_data(Vector2(49,280),move_data)
	if not await wait_for(func():return ui.barter.own_rows.has(own_item) and int(ui.barter.own_rows[own_item].x)==1 and int(ui.barter.own_rows[own_item].y)==1 and not ui.barter.pending.has("item:"+str(own_item)),"Moving an offered item receives original-server coordinates"): return
	ui.barter.item_menu(own_item,Vector2(650,350))
	var item_menu=ui.inventory.item_context
	if not check(item_menu.wheel.active and item_menu.entries.has(2) and not item_menu.entries[2].disabled,"Requested native offer wheel exposes current-serial Remove"): return
	item_menu.wheel.choose(2)
	if not check(channel(own_item)=="B","Removing through the offer wheel does not predict membership"): return
	if not await wait_for(func():return channel(own_item)=="R" and not ui.barter.own_rows.has(own_item) and not ui.barter.pending.has("item:"+str(own_item)),"Original two-player server confirms item-wheel removal into the backpack"): return
	if not await barter_offer(own_item): return
	ui.barter.item_menu(peer_item,Vector2(650,350)); item_menu.wheel.choose(0)
	if not await wait_for(func():return ui.examine.visible and int(ui.examine.state.get("targetId",-1))==peer_item,"Original server returns examination of the actual remote offer"): return
	ui.examine.hide()
	if not await barter_gold(5): return
	if not await barter_locks(): return
	barter_peer_command("accept",true)
	if not await wait_for(func():return ui.barter.active() and ui.barter.state.otherAccepted and not ui.barter.state.ownAccepted and barter_drawn_checked("rightacceptbut"),"Real peer acceptance visibly checks only the remote native Accept control"): return
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		session.root.get_texture().get_image().save_png(str(session.args.report).trim_suffix(".json")+".native-peer-accepted.png")
	barter_peer_command("accept",false)
	if not await wait_for(func():return ui.barter.active() and not ui.barter.state.otherAccepted and not barter_drawn_checked("rightacceptbut"),"Real peer retraction visibly restores its unchecked native Accept control"): return
	ui.barter.view.buttons.leftacceptbut.button_pressed=true
	if not await wait_for(func():return ui.barter.active() and ui.barter.state.ownAccepted and barter_drawn_checked("leftacceptbut") and not barter_drawn_checked("rightacceptbut"),"First native Accept is acknowledged without completing the exchange"): return
	if not check(channel(own_item)=="B" and channel(peer_item)=="A" and not barter_peer_has(own_item),"One participant acceptance cannot deliver offered items"): return
	barter_peer_command("accept",true)
	if not await wait_for(func():return not ui.barter.active() and bool(ui.barter.state.get("completed",false)),"Both real Accept requests complete the original-server trade"): return
	if not await wait_for(func():return channel(peer_item)=="R" and barter_peer_has(own_item) and not barter_peer_has(peer_item),"Completed trade transfers the exact canonical items to opposite players"):
		check(false,"Barter exchange ownership diagnostic",{"own_item":own_item,"peer_item":peer_item,"own_channel":channel(own_item),"peer_channel":channel(peer_item),"peer":session.test_barter_peer}); return
	if not await wait_for(func():return gold()==before-5 and int(session.test_barter_peer.gold)==peer_before+5,"Completed trade transfers exactly five server gold"): return
	if not check(ui.inventory.inventories.get("A",{}).get("entries",[]).is_empty() and ui.inventory.inventories.get("B",{}).get("entries",[]).is_empty(),"Completed trade retires both offer repositories"): return
	barter_peer_command("start")
	if not await wait_for(func():return ui.barter.active() and not ui.barter.state.initiator and int(ui.barter.state.partnerId)==partner,"Peer-initiated real trade opens native recipient-side controls"): return
	if not await barter_offer(peer_item): return
	barter_peer_command("add",own_item)
	if not await wait_for(func():return ui.barter.all_rows.has(own_item) and ui.barter.all_rows[own_item].channel=="A","Recipient-side native trade receives the other real offer"): return
	if not await barter_gold(3): return
	if not await barter_locks(): return
	ui.barter.view.buttons.leftcancelbut.pressed.emit()
	if not await wait_for(func():return not ui.barter.active() and not ui.barter.view.visible and not bool(ui.barter.state.get("completed",true)),"Native Cancel closes the real two-player server trade"): return
	if not await wait_for(func():return channel(peer_item)=="R" and barter_peer_has(own_item) and not barter_peer_has(peer_item),"Cancellation returns each actual item to its previous owner"): return
	await wait_for(func():return gold()==before-5 and int(session.test_barter_peer.gold)==peer_before+5,"Cancellation refunds reserved gold without transferring currency")
func barter_offer(id: int) -> bool:
	if not await wait_for(func():return ui.inventory.views.has(id) and ui.inventory.views[id].row.channel=="R","Native backpack presents the current barter item"): return false
	var data:={"kind":"native-inventory-item","viewId":ui.inventory.view_serial,"entryId":id}
	var grid=ui.barter.view.grids.B; var point:=Vector2(16,313)
	if not check(grid._can_drop_data(point,data),"Native own-offer grid accepts the current backpack item"): return false
	grid._drop_data(point,data)
	if not check(channel(id)=="R","Sending an offer never predicts item membership"): return false
	return await wait_for(func():return ui.barter.own_rows.has(id) and channel(id)=="B" and not ui.barter.pending.has("item:"+str(id)),"Original server moves the exact item into the local offer")
func barter_gold(amount: int) -> bool:
	var transfer=ui.inventory.gold; var before:=gold()
	if not await wait_for(func():return transfer.layout_ready,"Original gold amount controls are ready for barter"): return false
	ui.barter.view.buttons.goldbutton.pressed.emit()
	if not check(transfer.modal.visible and transfer.maximum==before,"Native barter gold button opens the original amount dialog"): return false
	transfer.number.text=str(amount); transfer.buttons.okbutton.pressed.emit()
	var grid=ui.barter.view.grids.B; var point:=Vector2(82,115); var data: Dictionary=transfer.payload.duplicate(true)
	if not check(grid._can_drop_data(point,data),"Native barter grid accepts its private gold drag"): return false
	grid._drop_data(point,data); get_viewport().gui_cancel_drag()
	if not check(gold()==before,"Sending barter gold never predicts the balance"): return false
	return await wait_for(func():return gold()==before-amount,"Original server reserves the exact offered gold amount")
func barter_drawn_checked(tag: String) -> bool:
	var view=ui.barter.view; var drawn: Dictionary=view.frame.button_geometry[view.buttons[tag].get_instance_id()].get("drawn",{})
	return str(drawn.get("state","")).ends_with("_checked")
func barter_locks() -> bool:
	ui.barter.view.buttons.leftdeclinebut.button_pressed=true
	if not await wait_for(func():return ui.barter.state.ownLocked and not ui.barter.pending.has("lock") and barter_drawn_checked("leftdeclinebut"),"Native Offer control receives its actual original-server lock acknowledgement"): return false
	barter_peer_command("lock",true)
	return await wait_for(func():return ui.barter.state.otherLocked and not ui.barter.view.buttons.leftacceptbut.disabled and barter_drawn_checked("rightdeclinebut"),"Other real participant lock enables the native Accept control")
func barter_peer_command(operation: String,value: Variant=null) -> void:
	session.send({"kind":"test-barter-peer","operation":operation,"value":value,"generation":epoch,"areaId":desktop.area_id})
func barter_peer_has(id: int) -> bool:
	return session.test_barter_peer.get("backpack",[]).any(func(value):return int(value)==id)
func find_control(operation: String,value: Variant=null) -> int:
	for id in desktop.level_owner.controls:
		var c: Dictionary=desktop.level_owner.controls[id]
		if str(c.operation)==operation and (value==null or c.value==value): return int(id)
	return -1
func heal_profile_window(label: String,seconds: float) -> Dictionary:
	var profiler=session.frame_profile; var rows: Array=[]; var resources: Dictionary={}; var peaks:={"active":0,"vertices":0,"models":0}
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not profiler.rows.is_empty(): rows.append(profiler.rows.back().duplicate())
		for row in session.world.effects.models.values():
			var model=row.model
			if is_instance_valid(model): resources[str(model.bundle_data.get("resource_name",model.bundle_data.get("value",{}).get("name","")))]=true
		peaks.models=maxi(peaks.models,session.world.effects.models.size())
		peaks.active=maxi(peaks.active,int(session.world.particle_metrics.sums[1])); peaks.vertices=maxi(peaks.vertices,int(session.world.particle_metrics.sums[2]))
	return {"label":label,"particles":session.particle_visibility.enabled,"collision":session.particle_visibility.collision_enabled,"native_scene":session.world.static_collision_index.native_queries_enabled,"direct_scene":session.world.direct_particle_collision_enabled,"frames":rows,"resources":resources.keys(),"peaks":peaks,"particle_state":session.world.particle_metrics.snapshot()}
func heal_profile_summary(rows: Array) -> Dictionary:
	var fields: Dictionary={}; var metrics: Dictionary={}
	for row in rows:
		for field in row:
			if not fields.has(field): fields[field]=[]
			fields[field].append(float(row[field]))
	for field in fields:
		var values: Array=fields[field]; var total:=0.0; var present:=values.size()
		for value in values: total+=value
		while values.size()<rows.size(): values.append(0.0)
		values.sort(); metrics[field]={"mean":total/values.size(),"p95":values[mini(values.size()-1,ceili(values.size()*0.95)-1)],"max":values[-1],"samples":values.size(),"active_samples":present}
	return metrics
func heal_profile_check() -> void:
	var owner=session.world.effects
	if not await wait_for(func():return owner.tables.size()==3,"Original visual tables ready for Heal profiling"): return
	var captures: Array=[await heal_profile_window("Heal idle baseline",1.0)]
	for attempt in 4:
		session.particle_visibility.set_enabled(attempt!=3)
		var before: int=owner.stats.started; ui.chat.submit("-native-vfxi")
		captures.append(await heal_profile_window("Heal effect profile "+str(attempt),4.0))
		check(owner.stats.started>before,"Original server delivered Heal effect "+str(attempt))
		if not await wait_for(func():return not owner.entries.values().any(func(entry):return int(entry.visual)==69),"Heal effect retires "+str(attempt),10): return
	check(owner.stats.failed==0,"Heal profiling has no native effect-owner failures")
	save_heal_profile_captures(captures)
func save_heal_profile_captures(captures: Array,prefix: String="heal") -> void:
	# Keep complete frame rows on disk. Large diagnostic packets themselves cause
	# hitches and exceed the command bound; serialize only after all measurements.
	for index in captures.size():
		var capture: Dictionary=captures[index]; var rows: Array=capture.frames
		var path:=str(session.args.report).trim_suffix(".json")+"-"+prefix+"-"+str(index)+".frames.json"
		var file:=FileAccess.open(path,FileAccess.WRITE)
		if not check(file!=null,"Heal raw frame evidence can be saved"): return
		file.store_string(JSON.stringify(rows)); file.close(); capture.erase("frames")
		capture.metrics=heal_profile_summary(rows); capture.frame_count=rows.size(); capture.raw_frames=path; capture.first_frames=rows.slice(0,12)
		rows.sort_custom(func(a,b):return float(a.wall_ms)>float(b.wall_ms)); capture.worst_frames=rows.slice(0,12)
		check(not rows.is_empty(),str(capture.label),capture)
func particle_crowd_profile_check() -> void:
	var owner=session.world.effects; var actors: Array=[]
	if not await wait_for(func():
		actors.clear()
		for id in desktop.objects:
			if int(desktop.objects[id].get("objectType",0))==5 and ui.text.name(null,int(id)).begins_with("Particle Test "): actors.append(int(id))
		return actors.size()==12 and actors.all(func(id):return session.world.instances.has(id)) and session.world.batches.is_empty() and session.world.terrain.done and owner.tables.size()==3,"Twelve original-server crowd actors and the room are rendered",45): return
	var visible:=0
	for id in actors:
		var point: Vector3=session.world.instances[id].global_position
		if not session.camera.is_position_behind(point) and get_viewport().get_visible_rect().has_point(session.camera.unproject_position(point)): visible+=1
	check(visible>=8,"Crowd timing includes visible characters",{"visible":visible,"actors":actors.size(),"world_instances":session.world.instances.size()})
	var prior_collision: bool=session.render_settings.particle_collision_enabled
	session.render_settings.particle_collision_toggle.button_pressed=true
	var captures: Array=[await heal_profile_window("Crowd idle baseline",2.0)]
	for stage in 14:
		var count:=4 if stage in [0,5] else 12; var great:=stage in [5,6,7]; session.particle_visibility.set_enabled(stage!=7)
		session.world.static_collision_index.native_queries_enabled=stage not in [8,9]
		session.world.terrain.collision_index.native_queries_enabled=stage not in [8,9]
		session.world.direct_particle_collision_enabled=stage not in [11,12]
		# Use the production checkbox/signal path, including new emitters born off.
		session.render_settings.particle_collision_toggle.button_pressed=stage not in [2,3]
		var before: int=owner.stats.started; ui.chat.submit(("-native-healg" if great else "-native-heal")+str(count))
		captures.append(await heal_profile_window("Crowd "+("Great" if great else "Small")+" Heal "+str(count)+" stage "+str(stage),4.0))
		check(owner.stats.started>=before+count,"Original server delivers every crowd Heal",{"stage":stage,"expected":count,"started":owner.stats.started-before})
		if not await wait_for(func():return not owner.entries.values().any(func(entry):return int(entry.visual) in [66,69]),"Crowd Heal models retire "+str(stage),15): return
	session.render_settings.particle_collision_toggle.button_pressed=prior_collision
	session.world.static_collision_index.native_queries_enabled=true; session.world.terrain.collision_index.native_queries_enabled=true
	session.world.direct_particle_collision_enabled=true
	# Pixel inspection is outside all performance windows.
	session.particle_visibility.set_enabled(true); ui.chat.submit("-native-heal12")
	var healing:=func():return owner.models.values().filter(func(row):return is_instance_valid(row.model) and str(row.model.bundle_data.get("resource_name",row.model.bundle_data.get("value",{}).get("name","")))=="vim_heal01").map(func(row):return row.model)
	if not await wait_for(func():return healing.call().size()==12,"All twelve genuine Heal models exist for visual inspection",10): return
	await get_tree().create_timer(0.2).timeout
	var models: Array=healing.call(); var mode: int=session.world.process_mode; var controls_visible: bool=ui.controls.visible
	session.world.process_mode=Node.PROCESS_MODE_DISABLED; ui.controls.hide(); await RenderingServer.frame_post_draw
	var shown:=get_viewport().get_texture().get_image()
	for model in models: model.hide()
	await RenderingServer.frame_post_draw
	var hidden:=get_viewport().get_texture().get_image(); var pixels:=0
	for y in range(0,shown.get_height(),4):
		for x in range(0,shown.get_width(),4):
			if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): pixels+=1
	for model in models: model.show()
	session.world.process_mode=mode; ui.controls.visible=controls_visible; shown.save_png(str(session.args.report).trim_suffix(".json")+"-crowd.png")
	check(pixels>20,"Crowd Heal effects change actual viewport pixels",{"changed_samples":pixels,"model_count":models.size()})
	await wait_for(func():return not owner.entries.values().any(func(entry):return int(entry.visual)==69),"Inspected crowd Heal models retire",15)
	check(owner.stats.failed==0,"Crowd effect delivery has no model-owner failures")
	save_heal_profile_captures(captures,"crowd")
func effects_check() -> void:
	var owner=session.world.effects
	if not await wait_for(func():return owner.tables.size()==3,"Native visual tables load from the admitted server scope"): return
	var first: int=owner.next_effect; ui.chat.submit("-native-vfx")
	if not await wait_for(func():return owner.entries.values().any(func(entry):return int(entry.visual)==1 and entry.runtime!=null),"Server duration effect starts with native resource preparation",25): return
	var effect:=-1
	for id in owner.entries:
		if int(owner.entries[id].visual)==1: effect=int(id); break
	var runtime=owner.entries[effect].runtime
	check(effect>first and runtime.state.durationFc==1 and runtime.state.attached114!=0,"Original duration phase attaches to the actual creature")
	check(owner.models.size()>0 and runtime.models.size()>0,"Original private effect model reaches the native renderer")
	await get_tree().create_timer(0.5).timeout
	var mode: int=session.world.process_mode; session.world.process_mode=Node.PROCESS_MODE_DISABLED
	ui.controls.hide(); await RenderingServer.frame_post_draw
	var shown:=get_viewport().get_texture().get_image()
	var hidden_models: Array=[]
	for row in owner.models.values():
		if int(row.effect)==effect and row.model.visible: hidden_models.append(row.model); row.model.hide()
	await RenderingServer.frame_post_draw
	var hidden:=get_viewport().get_texture().get_image()
	var changed:=0
	for y in range(0,shown.get_height(),4):
		for x in range(0,shown.get_width(),4):
			if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): changed+=1
	for model in hidden_models: model.show()
	session.world.process_mode=mode
	shown.save_png(str(session.args.report).trim_suffix(".json")+"-effect.png"); ui.controls.show()
	check(changed>20,"Private native visual model changes actual viewport pixels",{"sampled_changed_pixels":changed})
	if not await wait_for(func():return not owner.entries.has(effect),"Server expiry retires the duration visual and private model",18): return
	var instant_before: int=owner.stats.started; ui.chat.submit("-native-vfxi")
	if not await wait_for(func():return owner.stats.started>instant_before,"Original instant visual packet starts a native effect",25): return
	if not await wait_for(func():return not owner.entries.values().any(func(entry):return int(entry.visual)==69),"Instant impact retires through native phase timing",15): return
	if not await wait_for(func():return owner.world_audio.stats.played>0,"Original effect sound is decoded and played natively",10): return
	check(not owner.models.values().any(func(row):return int(row.effect)>first),"Completed test effects release their private native model owners")
	var area_before: int=owner.client_dummies.stats.area_created; ui.chat.submit("-native-vfxp")
	if not await wait_for(func():return owner.entries.values().any(func(entry):return entry.areaVisual and int(entry.visual)==69 and entry.runtime!=null),"Actual server location packet starts native type11 area rendering",25): return
	var area_effect:=-1
	for id in owner.entries:
		if owner.entries[id].areaVisual and int(owner.entries[id].visual)==69: area_effect=int(id); break
	var area: Dictionary=owner.entries[area_effect]; var state: Dictionary=area.runtime.state
	check(owner.client_dummies.stats.area_created==area_before+1 and int(state.objectType)==11,"Location effects use their original type11 owner rather than a creature loop")
	check(not desktop.objects.has(int(area.actor)) and not session.world.desired.has(int(area.actor)) and not session.registry.entities.has(int(area.actor)),"Private area ID is absent from server gameplay and interaction registries")
	var native_point:=Vector3(float(state.position[0]),float(state.position[2]),-float(state.position[1]))
	check(is_instance_valid(state.model) and state.model.position.distance_to(native_point)<0.0001 and native_point.distance_to(position())<0.05,"Original area model draws at the server-provided location")
	await get_tree().create_timer(0.15).timeout
	var area_mode: int=session.world.process_mode; session.world.process_mode=Node.PROCESS_MODE_DISABLED; ui.controls.hide()
	await RenderingServer.frame_post_draw
	var area_shown:=get_viewport().get_texture().get_image(); state.model.hide(); await RenderingServer.frame_post_draw
	var area_hidden:=get_viewport().get_texture().get_image(); var area_pixels:=0
	for y in range(0,area_shown.get_height(),2):
		for x in range(0,area_shown.get_width(),2):
			if area_shown.get_pixel(x,y)!=area_hidden.get_pixel(x,y): area_pixels+=1
	state.model.show(); session.world.process_mode=area_mode; ui.controls.show()
	area_shown.save_png(str(session.args.report).trim_suffix(".json")+"-area-effect.png")
	check(area_pixels>5,"Actual location effect changes native viewport pixels",{"sampled_changed_pixels":area_pixels})
	if not await wait_for(func():return not owner.entries.has(area_effect),"Original impact and retirement timer release the native area effect",15): return
	check(owner.client_dummies.stats.area_retired==area_before+1 and not owner.client_dummies.entries.has(int(area.actor)),"Area retirement releases the private internal ID")
	ui.chat.submit("-native-beam")
	if not await wait_for(func():return owner.entries.values().any(func(entry):return not entry.areaVisual and entry.runtime!=null and int(entry.runtime.state.programType10d)==7 and is_instance_valid(entry.runtime.state.proceduralB8)),"Real server beam starts the native source-to-target program",25): return
	var beam_id:=-1
	for id in owner.entries:
		if owner.entries[id].runtime!=null and not owner.entries[id].areaVisual and int(owner.entries[id].runtime.state.programType10d)==7: beam_id=int(id); break
	var beam=owner.entries[beam_id].runtime; var beam_state: Dictionary=beam.state
	check(int(beam_state.source58)==desktop.actor_id and int(beam_state.target54)!=desktop.actor_id,"Beam endpoints retain actual replicated source and target identities")
	check(beam.beam_signature.size()>=3 and beam_state.proceduralB8.anchor_node==owner.anchor(desktop.actor_id,0,str(beam_state.sourceAnchor28)),"Beam model attaches to the original source physical part")
	var endpoint_bound:=func():
		if not is_instance_valid(beam_state.proceduralB8): return false
		var target: Node3D=owner.anchor(int(beam_state.target54),0,str(beam_state.targetAnchor38))
		if not is_instance_valid(target): return false
		for graph in beam_state.proceduralB8.reference_graphs:
			if graph==null: continue
			for row in graph.rows:
				if is_instance_valid(row.helper) and row.helper.external_anchor!=null and row.helper.external_anchor.get_ref()==target and is_instance_valid(row.helper.model68) and row.helper.model68.global_position.distance_to(target.global_position)<0.0001: return true
		return false
	if not await wait_for(endpoint_bound,"Late native reference publication binds the beam to the actual target part",3): return
	await get_tree().create_timer(0.5).timeout
	var beam_mode: int=session.world.process_mode; session.world.process_mode=Node.PROCESS_MODE_DISABLED; ui.controls.hide(); await RenderingServer.frame_post_draw
	var beam_shown:=get_viewport().get_texture().get_image(); beam_state.proceduralB8.hide(); await RenderingServer.frame_post_draw
	var beam_hidden:=get_viewport().get_texture().get_image(); var beam_pixels:=0
	for y in range(0,beam_shown.get_height(),2):
		for x in range(0,beam_shown.get_width(),2):
			if beam_shown.get_pixel(x,y)!=beam_hidden.get_pixel(x,y): beam_pixels+=1
	beam_state.proceduralB8.show(); session.world.process_mode=beam_mode; ui.controls.show(); beam_shown.save_png(str(session.args.report).trim_suffix(".json")+"-beam.png")
	check(beam_pixels>5,"Native beam program draws real endpoint-linked geometry",{"sampled_changed_pixels":beam_pixels})
	if not await wait_for(func():return not owner.entries.has(beam_id),"Server beam removal retires its procedural model and bindings",18): return
	var projectiles=owner.projectiles; var spawned_before: int=projectiles.stats.spawned
	var casts=owner.casts; var casts_before: int=casts.stats.created; var releases_before: int=casts.stats.releases
	ui.chat.submit("-native-projectile")
	if not await wait_for(func():return projectiles.active.size()>0,"Actual original-server spell emits a native traveling projectile",25): return
	var projectile: Dictionary=projectiles.active.values()[0]; var projectile_id:=int(projectile.id); var start: Array=projectile.position.duplicate()
	check(projectile.sourceId==desktop.actor_id and projectile.targetId!=desktop.actor_id and projectile.spellId==58 and projectile.resource=="vpr_fireball" and projectile.path==1,"Projectile uses actual packet identities and active original spell metadata")
	check(casts.stats.created>casts_before and casts.stats.releases==releases_before+1,"Actual server Fireball starts original conjure and releases it exactly once")
	check(not session.world.desired.has(projectile_id) and not session.registry.entities.has(projectile_id) and owner.client_dummies.has(projectile_id,int(projectile.token)),"Private projectile IDs do not become authoritative or interactable world objects")
	await get_tree().create_timer(0.1).timeout
	check(not projectile.destroyed and Vector3(projectile.position[0],projectile.position[1],projectile.position[2]).distance_to(Vector3(start[0],start[1],start[2]))>0.01,"Native projectile advances along its actual server-timed path")
	if projectile.destroyed: check(false,"Projectile remains visible for render inspection"); return
	var projectile_mode: int=session.world.process_mode; session.world.process_mode=Node.PROCESS_MODE_DISABLED; ui.controls.hide(); await RenderingServer.frame_post_draw
	var projectile_center: Vector2=session.camera.unproject_position(projectile.model.global_position)
	var projectile_shown:=get_viewport().get_texture().get_image(); projectile.model.hide(); await RenderingServer.frame_post_draw
	var projectile_hidden:=get_viewport().get_texture().get_image(); var projectile_pixels:=0
	for y in range(maxi(0,int(projectile_center.y)-100),mini(projectile_shown.get_height(),int(projectile_center.y)+100),2):
		for x in range(maxi(0,int(projectile_center.x)-100),mini(projectile_shown.get_width(),int(projectile_center.x)+100),2):
			if projectile_shown.get_pixel(x,y)!=projectile_hidden.get_pixel(x,y): projectile_pixels+=1
	projectile.model.show(); session.world.process_mode=projectile_mode; ui.controls.show(); projectile_shown.save_png(str(session.args.report).trim_suffix(".json")+"-projectile.png")
	check(projectile_pixels>2,"Actual traveling original model changes native viewport pixels",{"sampled_changed_pixels":projectile_pixels,"region_center":[projectile_center.x,projectile_center.y],"region_radius":100})
	if not await wait_for(func():return not projectiles.active.has(projectile_id),"Original travel/impact timer retires the projectile",10): return
	check(projectiles.stats.spawned==spawned_before+1 and projectiles.stats.impacts>0 and not owner.client_dummies.entries.has(projectile_id),"Impact and retirement release the actual private projectile allocation")
	var released_before: int=casts.stats.releases
	ui.chat.submit("-native-cast-release")
	if not await wait_for(func():return casts.stats.releases>released_before and casts.handles.values().any(func(h):return h.category=="castvisual" and h.resource=="vca_outsonic" and is_instance_valid(h.model)),"Actual server Magic Missile emits original parent cast visual",25): return
	# Its impact script may emit separate genuine child missiles. The parent
	# row's Proj=0 must not itself become an invented traveling projectile.
	check(not projectiles.history.any(func(e):return e.kind=="ready" and int(e.spellId)==107),"Original no-projectile parent creates no invented missile")
	var cast_models: Array=casts.handles.values().filter(func(h):return h.category=="castvisual" and h.resource=="vca_outsonic" and is_instance_valid(h.model)).map(func(h):return h.model)
	if not await wait_for(func():return cast_models.all(func(model):return is_instance_valid(model) and float(model.rigs.entities[0].models[0].last_time)>0.12),"Original cast01 controller advances before visible output is sampled",3): return
	check(cast_models.all(func(model):return model.anchor_node==owner.anchor(desktop.actor_id,0,"handconjure") and model.rigs.entities[0].models[0].clip=="cast01"),"Real server release plays original cast01 on the caster handconjure Part")
	var cast_mode: int=session.world.process_mode; session.world.process_mode=Node.PROCESS_MODE_DISABLED; ui.controls.hide(); await RenderingServer.frame_post_draw
	var center: Vector2=session.camera.unproject_position(session.world.instances[desktop.actor_id].global_position)
	var cast_shown:=get_viewport().get_texture().get_image()
	for model in cast_models: model.hide()
	await RenderingServer.frame_post_draw
	var cast_hidden:=get_viewport().get_texture().get_image(); var cast_pixels:=0
	for y in range(maxi(0,int(center.y)-220),mini(cast_shown.get_height(),int(center.y)+220),2):
		for x in range(maxi(0,int(center.x)-220),mini(cast_shown.get_width(),int(center.x)+220),2):
			if cast_shown.get_pixel(x,y)!=cast_hidden.get_pixel(x,y): cast_pixels+=1
	for model in cast_models: model.show()
	session.world.process_mode=cast_mode; ui.controls.show(); cast_shown.save_png(str(session.args.report).trim_suffix(".json")+"-cast-release.png")
	check(cast_pixels>2,"Original Magic Missile cast-release model changes actual native viewport pixels",{"changed_pixels":cast_pixels,"radius":220,"source_center":[center.x,center.y]})
	if not await wait_for(func():return casts.handles.is_empty(),"Native casting timers retire real server conjure and release models",15): return
	check(casts.stats.failed==0 and casts.stats.callbacks>0 and casts.stats.created==casts.stats.destroyed,"Original donefade callbacks and cleanup release every private casting model")
func ranged_check() -> void:
	var sling: bool=session.args.get("actions-ranged-weapon","bow")=="sling"; var weapon_base:=61 if sling else 8; var ammo_base:=27 if sling else 20
	var deflected: bool=session.args.get("actions-deflection-check","")=="true"
	var shield: bool=session.args.get("actions-shield-check","")=="true"
	var shield_base:=int({"small":14,"large":56,"tower":57}[session.args.get("actions-shield-kind","small")])
	var miss: bool=session.args.get("actions-miss-check","")=="true"; var shot_target:=-1
	if not ui.inventory.ui.wanted: ui.inventory.ui.open()
	if not desktop.sheet.wanted: desktop.sheet.open()
	if not await wait_for(func():return ui.inventory.views.size()>0 and current().get("inventoryStats",{}).has("fields70"),"Original ranger inventory arrives from the actual local server"): return
	var bow:=-1; var ammo:=-1; var npc:=-1; var projectiles=session.world.effects.projectiles
	for id in ui.inventory.views:
		if channel(int(id))=="I" and int(item(int(id)).get("baseItem",-1))==weapon_base: bow=int(id)
		if channel(int(id))=="I" and int(item(int(id)).get("baseItem",-1))==ammo_base: ammo=int(id)
	for id in desktop.objects:
		if int(id)!=desktop.actor_id and int(desktop.objects[id].get("objectType",0))==5 and not desktop.objects[id].get("replicationRemoved",false): npc=int(id); break
	if not check(bow>=0 and ammo>=0 and npc>=0,"Original ranger test equipment and encounter target are present",{"weapon":bow,"ammunition":ammo,"target":npc,"weaponBase":weapon_base,"ammunitionBase":ammo_base}): return
	if not await wait_for(func():return session.world.instances.has(npc) and projectiles.ranged_tables.size()==2,"Actual target model and active ranged tables prepare"): return
	if shield:
		ui.chat.submit("-native-shield-start")
		if not await wait_for(func():return ui.chat.rows.any(func(row):return str(row.get("text","")).contains("GODOT_SHIELD_COMBAT")),"Original server starts the authored shield encounter"): return
		if not await wait_for(func():return session.world.combat.engine.actors.get(npc,{}).get("equipment",{}).get("32",{}).get("baseItem",-1)==shield_base and session.world.instances[npc].equipment_part(32,"imp_shield_1")!=null,"Original server equips a real shield with native physical impact Parts"): return
	if deflected:
		ui.chat.submit("-native-deflect-start")
		if not await wait_for(func():return ui.chat.rows.any(func(row):return str(row.get("text","")).contains("GODOT_DEFLECT_COMBAT")),"Original server starts the authored deflection encounter"): return
		if not await wait_for(func():return not session.world.combat.engine.states.get(npc,{}).get("current",{}).is_empty(),"Deflecting NPC enters an actual original-server combat round",25): return
	var before_ammo:=stack(ammo)
	desktop.open_radial({"id":npc,"position":session.world.instances[npc].position},Vector2(600,350))
	var clicked:=false
	for index in desktop.radial_entries:
		if str(desktop.radial_entries[index].get("interaction",""))=="combat.attack": desktop.radial.choose(int(index)); clicked=true; break
	if not check(clicked,"Actual native radial attack command is selected"): return
	if not await animation_check("attack"): return
	# npc is selected above; miss packets intentionally have no canonical target.
	shot_target=0x7f000000 if miss else npc
	var flying:=func():return projectiles.active.values().any(func(s):return s.get("ranged",false) and int(s.phase)==0 and int(s.targetId)==shot_target and not s.destroyed and (not deflected or int(s.path)==13) and (not miss or int(s.path)==12) and (not shield or int(s.result)==2 and int(s.path)==2))
	if not await wait_for(flying,"Original server shot creates an actual native in-flight projectile",45 if shield else 30):
		if shield: check(false,"Shield shot diagnostics",{"projectiles":projectiles.snapshot(),"target":desktop.objects.get(npc,{}),"combat":session.world.combat.snapshot()})
		return
	var shot: Dictionary={}
	for s in projectiles.active.values():
		if s.get("ranged",false) and int(s.phase)==0 and int(s.targetId)==shot_target and (not deflected or int(s.path)==13) and (not miss or int(s.path)==12) and (not shield or int(s.result)==2 and int(s.path)==2): shot=s; break
	check(int(shot.sourceId)==desktop.actor_id and (int(shot.path)==13 if deflected else int(shot.path)==12 if miss else int(shot.path) in [11,12] if sling else int(shot.path)==2) and shot.resource!="" and not session.world.desired.has(int(shot.id)) and not session.registry.entities.has(int(shot.id)),"Ranged packet uses its original private path without changing server identities")
	var landing: Array=[]
	if sling or deflected:
		check(shot.nodes.size()==(1 if deflected else 2) and shot.nodes.all(func(n):return int(n.kind)==2 and int(n.targetId)==0x7f000000),"Actual native projectile has its original bounce/deflection tail")
		if not shot.nodes.is_empty(): landing=shot.nodes.back().point.duplicate()
	var before: Array=shot.position.duplicate(); await get_tree().process_frame; await get_tree().process_frame
	check(not shot.destroyed and Vector3(shot.position[0],shot.position[1],shot.position[2]).distance_to(Vector3(before[0],before[1],before[2]))>0.001,"Native ballistic projectile visibly advances rather than waiting at its launch point")
	if not await wait_for(func():return stack(ammo)<before_ammo,"Unchanged original server consumes actual equipped ammunition"): return
	if not await wait_for(func():return ui.chat.rows.any(func(row):return row.get("category","")=="attack-feedback"),"Original ranged attack outcome is formatted in native chat"): return
	var previous_mode: int=session.world.process_mode; session.world.process_mode=Node.PROCESS_MODE_DISABLED; var ui_visible: bool=ui.controls.visible; ui.controls.hide(); await RenderingServer.frame_post_draw
	var center: Vector2=session.camera.unproject_position(shot.model.global_position); var shown:=get_viewport().get_texture().get_image(); shot.model.hide(); await RenderingServer.frame_post_draw
	var hidden:=get_viewport().get_texture().get_image(); var pixels:=0
	for y in range(maxi(0,int(center.y)-80),mini(shown.get_height(),int(center.y)+80)):
		for x in range(maxi(0,int(center.x)-80),mini(shown.get_width(),int(center.x)+80)):
			if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): pixels+=1
	shot.model.show(); session.world.process_mode=previous_mode; ui.controls.visible=ui_visible; shown.save_png(str(session.args.report).trim_suffix(".json")+"-ranged.png")
	check(pixels>2,"Actual original ammunition model changes native viewport pixels",{"changed_pixels":pixels,"resource":shot.resource,"region_center":[center.x,center.y],"radius":80})
	if not await wait_for(func():return int(shot.phase)==1 and not shot.destroyed,"Native arrow reaches its impact stage"): return
	if sling or deflected:
		check(shot.model.anchor_node==null and shot.position==landing,"Native projectile completes its ground tail without embedding in the creature",{"landing":landing,"position":shot.position.duplicate()})
	elif shield:
		var actor=session.world.instances[npc]; var parts: Array=[actor.equipment_part(32,"imp_shield_1"),actor.equipment_part(32,"imp_shield_2")]
		check(shot.model.anchor_node!=null and parts.has(shot.model.anchor_node) and shot.model.anchor_flags==0,"Actual block embeds the arrow in an original shield impact Part")
		check(int(shot.result)==2 and int(shot.rangedEffect)==0 and not projectiles.tracking.get(npc,[]).has(int(shot.id)),"Original shield block stays distinct from damaging body-hit tracking and blood")
		await get_tree().process_frame; await get_tree().process_frame
		if not check(is_instance_valid(shot.model.anchor_node) and shot.model.global_position.distance_to(shot.model.anchor_node.global_position)<0.001,"Embedded arrow follows the animated held shield position",{"distance":shot.model.global_position.distance_to(shot.model.anchor_node.global_position) if is_instance_valid(shot.model.anchor_node) else -1}): return
		if not await shield_pixels(shot): return
	else:
		var expected: Node3D=session.world.instances[npc].physical_part(str(shot.impactNode))
		check(expected!=null and shot.model.anchor_node==expected,"Native body impact attaches to the actual original weighted physical Part",{"part":shot.impactNode})
	if not sling and not deflected and not miss and not shield:
		if not await blood_check(npc): return
	var retired_model: WeakRef=weakref(shot.model)
	if not await wait_for(func():return not desktop.action_queue.buttons.is_empty(),"Real server attack action is present in the native queue"): return
	var serial: int=desktop.action_queue.buttons.keys()[0]; desktop.action_queue.buttons[serial].pressed.emit()
	if not await wait_for(func():return not desktop.action_queue.buttons.has(serial) and not desktop.action_queue.pending.has(serial),"Native action queue cancellation reaches the original server"): return
	if not await wait_for(func():return projectiles.active.is_empty() and projectiles.tracking.is_empty(),"Native 8000ms impact expiry releases ranged models and creature tracking",14): return
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	check(retired_model.get_ref()==null,"Rendered arrow expiry releases its actual native model")
	check(int(projectiles.stats.failed)==0 and int(projectiles.stats.impacts)>0,"Actual ranged delivery/impact finishes without receiver failures",projectiles.stats.duplicate())
func shield_pixels(shot: Dictionary) -> bool:
	var previous_mode: int=session.world.process_mode; session.world.process_mode=Node.PROCESS_MODE_DISABLED; var ui_visible: bool=ui.controls.visible; ui.controls.hide()
	await RenderingServer.frame_post_draw
	var center: Vector2=session.camera.unproject_position(shot.model.global_position); var shown:=get_viewport().get_texture().get_image(); shot.model.hide()
	await RenderingServer.frame_post_draw
	var hidden:=get_viewport().get_texture().get_image(); var pixels:=0
	for y in range(maxi(0,int(center.y)-120),mini(shown.get_height(),int(center.y)+120)):
		for x in range(maxi(0,int(center.x)-120),mini(shown.get_width(),int(center.x)+120)):
			if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): pixels+=1
	shot.model.show(); session.world.process_mode=previous_mode; ui.controls.visible=ui_visible
	shown.save_png(str(session.args.report).trim_suffix(".json")+"-shield.png")
	return check(pixels>0,"Real shield-embedded arrow changes native viewport pixels",{"changed_pixels":pixels,"center":[center.x,center.y],"radius":120,"result":shot.result,"target":shot.targetId,"resource":shot.resource})
func change(operation: String,value: Variant,chosen: Variant=null) -> bool:
	var id:=find_control(operation,value)
	if not check(id>=0,"Native level-up control "+operation+" is present"): return false
	desktop.level_up.change(id,chosen,desktop.level_up.view_id); return true
func level_up(class_id: int) -> bool:
	var before:=level(); var previous_token: int=desktop.level_owner.token; desktop.level_up.open()
	if not await wait_for(func():return not desktop.level_owner.draft.is_empty() and desktop.level_owner.token>previous_token and not desktop.level_up.state.is_empty(),"Server returns level-up class choices"): return false
	if int(desktop.level_owner.draft.classId)!=class_id:
		if not change("class",class_id): return false
	if not await wait_for(func():return int(desktop.level_owner.draft.classId)==class_id and not desktop.level_rules_waiting,"Native class progression becomes ready"): return false
	desktop.level_up.navigate(1)
	if (before+1)%4==0 and not change("ability",3): return false
	desktop.level_up.navigate(2)
	var skill:=-1
	for id in desktop.level_owner.controls:
		var c: Dictionary=desktop.level_owner.controls[id]
		if c.operation=="skill-plus" and not desktop.level_up.controls[id].disabled: skill=int(c.value); break
	if skill>=0 and not change("skill-plus",skill): return false
	desktop.level_up.navigate(3)
	var slots: Dictionary=desktop.level_owner.feat_slots(); var needed:=int(slots.normal)+int(slots.bonus)
	while desktop.level_owner.draft.feats.size()<needed:
		var selected:=-1
		for id in desktop.level_owner.controls:
			var c: Dictionary=desktop.level_owner.controls[id]
			if c.operation=="feat" and not desktop.level_owner.draft.feats.has(c.value) and (int(slots.bonus)==0 or desktop.level_owner.feat_allowed(int(c.value),"bonus")): selected=int(c.value); break
		if not change("feat",selected,true): return false
	desktop.level_up.navigate(4)
	if int(desktop.level_owner.num(desktop.rules.row("classes",class_id),"SpellCaster"))!=0:
		var chosen:=0
		while chosen<2:
			var selected: Variant=null
			for id in desktop.level_owner.controls:
				var c: Dictionary=desktop.level_owner.controls[id]
				if c.operation=="spell" and int(c.value[0])>0 and not desktop.level_owner.draft.known.get(str(c.value[0]),[]).has(c.value[1]): selected=c.value; break
			if not check(selected!=null,"A native learnable spell is available"): return false
			if not change("spell",selected,true): return false
			chosen+=1
	desktop.level_up.navigate(6)
	if not check(desktop.level_up.state.get("canFinish",false),"Native review permits a valid proposal",{"errors":desktop.level_up.state.get("errors",[])}): return false
	desktop.level_up.finish.pressed.emit()
	return await wait_for(func():return not desktop.level_up.wanted and level()==before+1,"Server accepts and replicates class "+str(class_id)+" advancement",20.0)

func combat_check() -> bool:
	if not await wait_for(func():return ui.chat.rows.any(func(row):return row.get("category","")=="spell-feedback"),"Real server spell feedback appears in native chat"): return false
	var npc:=-1
	for id in desktop.objects:
		var source: Dictionary=desktop.objects[id]
		if id!=desktop.actor_id and int(source.get("objectType",0))==5 and not source.get("replicationRemoved",false): npc=int(id); break
	if not check(npc>=0,"Immortal server combat fixture is present",{"id":npc,"name":ui.text.name(null,npc),"master":desktop.objects.get(npc,{}).get("replicated",{}).get("master",-1)}): return false
	desktop.open_radial({"id":npc,"position":position()},Vector2(600,350))
	var attack_selected:=false
	for index in desktop.radial_entries:
		if str(desktop.radial_entries[index].get("interaction",""))=="combat.attack": desktop.radial.choose(int(index)); attack_selected=true; break
	if not check(attack_selected,"Native radial selects the real attack interaction",{"target":npc,"targeting":not desktop.target.is_empty()}): return false
	if not await wait_for(func():return ui.chat.rows.any(func(row):return row.get("category","")=="attack-feedback"),"Server attack result is formatted in native combat chat",25):
		check(false,"Attack feedback failure diagnostics",{"target":npc,"chat":ui.chat.rows.slice(-12),"queue":desktop.action_queue.rows,"targeting":not desktop.target.is_empty()})
		return false
	if not await animation_check("attack"): return false
	if not await facing_check(npc): return false
	if not await wait_for(func():return int(session.world.combat.engine.stats.hits)>0,"Original attack hit event reaches native presentation",20): return false
	var particles_before: bool=session.particle_visibility.enabled; session.particle_visibility.set_enabled(true)
	var blood_ready: bool=await blood_check(npc); session.particle_visibility.set_enabled(particles_before)
	if not blood_ready: return false
	if not await wait_for(func():return not desktop.action_queue.buttons.is_empty(),"Native action queue displays the server attack action"): return false
	var serial: int=desktop.action_queue.buttons.keys()[0]
	desktop.action_queue.buttons[serial].pressed.emit()
	if not check(desktop.action_queue.pending.has(serial),"Queue cancellation dims the widget while awaiting the server"): return false
	return await wait_for(func():return not desktop.action_queue.buttons.has(serial) and not desktop.action_queue.pending.has(serial),"Server deletion retires the canceled action widget")

func contains_radial_feat(entry: Dictionary,id: int,auxiliary: int) -> bool:
	var binding: Dictionary=entry.get("binding",{})
	if int(binding.get("type",-1))==4 and (int(binding.intParam)&65535)==id and ((int(binding.intParam)>>16)&65535)==auxiliary: return true
	for child in entry.get("children",[]):
		if contains_radial_feat(child,id,auxiliary): return true
	return false
func feat_family_check() -> bool:
	var id:=int(desktop.actor_id)
	if not check(current().get("replicated",{}).get("stats",{}).get("classes",[]).any(func(cls):return int(cls.id)==3) and desktop.rules.feats(current()).has(305),"Original installed Druid owns the native shape-family feat"): return false
	var ctx: Dictionary=desktop.feat_rules.context(current(),id)
	var parent: Dictionary=desktop.feat_rules.leaf(ctx,305)
	if not check(not parent.is_empty() and parent.get("submenu",false),"Active original feat/spell tables resolve the owned shape-family successor",parent): return false
	var parent_id:=int(parent.featId); var variants: Array=desktop.feat_rules.variants(ctx,parent_id)
	if not check(not variants.is_empty() and not variants[0].disabled,"A charged native shape variant is available from received state",{"parent":parent_id,"variants":variants}): return false
	var auxiliary:=int(variants[0].auxiliary); var packed:=int(desktop.FeatRadial.binding(parent_id,auxiliary).intParam)
	var uses_before:=int(desktop.rules.feat_uses(current(),parent_id)); var appearance_before:=int(current().get("appearance",{}).get("appearance",-1))
	desktop.open_radial({"id":id,"position":position()},Vector2(650,350))
	var leaf_slot:=-1
	for depth_index in 16:
		var chosen:=-1
		for slot in desktop.radial_entries:
			if contains_radial_feat(desktop.radial_entries[slot],parent_id,auxiliary): chosen=int(slot); break
		if not check(chosen>=0,"Original shape-family variant is reachable in the native wheel at depth "+str(depth_index)): return false
		if desktop.radial_entries[chosen].has("binding"): leaf_slot=chosen; break
		await radial_click(chosen)
	if not check(leaf_slot>=0 and desktop.radial.can_shortcut(desktop.radial.buttons[leaf_slot].payload),"Live shape-family leaf provides a current private shortcut payload"): return false
	var payload: Dictionary=desktop.radial.buttons[leaf_slot].payload.duplicate(true)
	desktop.quickbar.buttons[0].dropped.emit(payload)
	if not await wait_for(func():return desktop.quick_bindings.size()>0 and int(desktop.quick_bindings[0].get("type",0))==4 and int(desktop.quick_bindings[0].get("intParam",0))==packed,"Server replicates the parent feat and complete variant WORD in its shortcut"): return false
	if not check(int(desktop.quickbar.rows[0].get("uses",-1))==uses_before,"Variant shortcut displays its received parent's remaining uses"): return false
	desktop.radial.reset(); desktop.quickbar.buttons[0].selected.emit()
	if not await wait_for(func():return int(current().get("appearance",{}).get("appearance",-1))!=appearance_before and int(desktop.rules.feat_uses(current(),parent_id))==uses_before-1,"Server receives the signed variant shortcut and changes the character shape",30): return false
	check(true,"Authoritative shape-family outcome details",{"parent":parent_id,"auxiliary":auxiliary,"replicated_shortcut":desktop.quick_bindings[0],"uses_before":uses_before,"uses_after":desktop.rules.feat_uses(current(),parent_id),"appearance_before":appearance_before,"appearance_after":current().get("appearance",{}).get("appearance",-1)})
	if not await wait_for(func():return session.world.instances.has(id) and session.world.desired.has(id) and str(session.world.installed.get(id,""))==str(session.world.desired[id].key) and session.world.combat.engine.states.has(id),"Authoritative shape loads its actual native body and combat owner",30): return false
	if not check(session.world.failed_objects.is_empty(),"Shaped body preparation has no failed object resources",session.world.failed_objects): return false
	var origin: Vector3=session.world.motion.objects[id].position
	desktop.command({"kind":"walk","position":[origin.x-6.0,origin.y,origin.z]})
	if not await wait_for(func():return session.world.motion.objects[id].active and int(session.world.combat.engine.states[id].visual) in [2,3,4,5],"Unchanged local server drives the shaped creature's locomotion"): return false
	var body: Node3D=session.world.instances[id]; var rigs=body.rigs; var animation:=int(session.world.combat.engine.states[id].visual)
	var clip_seconds: float=rigs.clip_length(id,animation)
	if not check(clip_seconds>0 and clip_seconds<2.5,"Shaped locomotion selects an available original clip",{"animation":animation,"length":clip_seconds}): return false
	await RenderingServer.frame_post_draw
	var before: Dictionary=rigs.diagnostic_sample([id],true)
	await get_tree().create_timer(clip_seconds+0.15).timeout; await RenderingServer.frame_post_draw
	var changed: Dictionary=rigs.compare_samples(before,rigs.diagnostic_sample([id],true))
	return check(session.world.motion.objects[id].active and int(session.world.combat.engine.states[id].visual)==animation and rigs.entities[id].models.any(func(model):return model.loop and not str(model.clip).is_empty()) and int(changed.changed_local_parts)>0 and int(changed.advanced_model_clocks)>0 and changed.missing_requested_clips.is_empty(),"Shaped native locomotion keeps cycling past one original clip length",changed)
func radial_click(slot: int) -> void:
	var point: Vector2=desktop.radial.buttons[slot].get_global_rect().get_center()
	await radial_click_point(point)
func radial_click_point(point: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		get_tree().root.push_input(event,true); await get_tree().process_frame
func contains_radial_spell(entry: Dictionary,spell: int) -> bool:
	if int(entry.get("binding",{}).get("type",-1))==2 and int(entry.binding.get("intParam",-1))==spell: return true
	for child in entry.get("children",[]):
		if contains_radial_spell(child,spell): return true
	return false
func radial_check() -> bool:
	if not await wait_for(func():return desktop.radial.layout_ready and desktop.radial.center_frame.texture!=null and desktop.radial.selection.texture!=null,"Original radial layout and circular art are live in the server UI",15): return false
	var npc:=-1
	for id in desktop.objects:
		if int(id)!=desktop.actor_id and int(desktop.objects[id].get("objectType",0))==5 and session.world.instances.has(id): npc=int(id); break
	if not check(npc>=0,"Owned fixture supplies a real received NPC for radial examination"): return false
	desktop.open_radial({"id":npc,"position":session.world.instances[npc].position},Vector2(650,350))
	var examine_slot:=-1
	for slot in desktop.radial_entries:
		if desktop.radial_entries[slot].action=="examine": examine_slot=int(slot); break
	if not check(examine_slot>=0 and desktop.radial.layer==100 and desktop.radial.buttons[examine_slot].size==Vector2(56,56),"Original-looking radial exposes native Examine above simultaneous windows",desktop.radial.skin_snapshot()): return false
	await radial_click(examine_slot)
	if not await wait_for(func():return ui.examine.visible and int(ui.examine.state.get("targetId",-1))==npc,"Actual radial icon click receives the server's NPC examination"): return false
	ui.examine.reset()
	desktop.open_radial({"id":desktop.actor_id,"position":position()},Vector2(650,350))
	if not await wait_for(func():return desktop.radial.center_image.texture!=null,"Native root center receives the character portrait"): return false
	var portrait_texture: Texture2D=desktop.radial.center_image.texture
	if not await wait_for(func():return desktop.radial.icons.keys().all(func(slot):return not desktop.radial.buttons[slot].visible or desktop.radial.icons[slot].texture!=null),"Live root wheel finishes its current icon bindings"): return false
	await RenderingServer.frame_post_draw
	var radial_screen: Image=get_tree().root.get_texture().get_image()
	var screenshot_path: String=str(session.args.get("report","")).get_basename()+"-radial.png"
	if not check(radial_screen!=null and screenshot_path.is_absolute_path() and not FileAccess.file_exists(screenshot_path) and radial_screen.save_png(screenshot_path)==OK,"Native wheel and portrait are captured over the actual local-server scene",{"path":screenshot_path}): return false
	await radial_click(1)
	if not await wait_for(func():return desktop.radial.center_frame.visible and desktop.radial.center_image.texture!=null,"Native submenu center replaces the portrait with its category icon"): return false
	await radial_click_point(desktop.radial.center.get_global_rect().get_center())
	var restored: Texture2D=desktop.radial.center_image.texture
	# Portrait crops are private AtlasTexture wrappers over the shared original
	# raster; restoring a menu need not reuse the mutable wrapper's identity.
	var same_portrait: bool=restored==portrait_texture or restored is AtlasTexture and portrait_texture is AtlasTexture and restored.atlas==portrait_texture.atlas and restored.region==portrait_texture.region
	if not check(desktop.radial_stack.size()==1 and not desktop.radial.center_frame.visible and same_portrait,"Actual center click restores the previous menu and its original portrait",{"stack":desktop.radial_stack.size(),"frame_visible":desktop.radial.center_frame.visible,"same_portrait":same_portrait}): return false
	var uses_before: int=desktop.rules.spell_uses(current(),100,0)
	if not check(uses_before>0,"Original sample has a real prepared Light use for radial casting"): return false
	var visited: Array=[]; var leaf:=false
	for depth_index in 12:
		var chosen:=-1
		for slot in desktop.radial_entries:
			if contains_radial_spell(desktop.radial_entries[slot],100): chosen=int(slot); break
		if not check(chosen>=0,"Live native radial resolves the spell through current server tables at depth "+str(depth_index)): return false
		var entry: Dictionary=desktop.radial_entries[chosen]; leaf=not entry.has("children")
		visited.append({"menu":desktop.radial.menu_id,"slot":chosen,"label":entry.label,"leaf":leaf})
		await radial_click(chosen)
		if leaf: break
	if not check(leaf and visited.size()>=3,"Actual circular control clicks descend class/level/spell menus",{"visited":visited}): return false
	click_spell_target()
	if not await animation_check("cast",100): return false
	return await wait_for(func():return desktop.rules.spell_uses(current(),100,0)==uses_before-1,"Native radial spell click consumes an authoritative prepared use")
func correction_check() -> bool:
	var id:=int(session.world.controlled_id); var engine=session.world.combat.engine
	if not await wait_for(func():return engine.states.has(id) and int(engine.states[id].visual) in [0,1] and engine.states[id].current.is_empty() and not session.world.motion.objects[id].active and int(session.world.motion.objects[id].correction)==0 and session.world.motion.objects[id].render.distance_to(session.world.motion.objects[id].position)<0.001,"Correction fixture reaches an idle native body before the server move",8): return false
	# UI snapshots omit movement-only deltas. Read the settled native motion
	# destination instead; this probe never writes it or the rendered pose.
	var before_wire: Vector3=session.world.motion.objects[id].position; var since: int=engine.now(); var before_count:=int(engine.stats.movement_cues)
	ui.chat.submit("-native-correction-step")
	var active:=func():return engine.stats.movement_cues>before_count and engine.states.has(id) and int(engine.states[id].visual) in [24,25,26,27] and int(engine.states[id].current.get("remaining",0))>120
	if not await wait_for(active,"Original server position correction owns a real native directional step",10): return false
	var body: Node3D=session.world.instances[id]; var rigs=body.rigs
	await RenderingServer.frame_post_draw
	var before: Dictionary=rigs.diagnostic_sample([id],true)
	await get_tree().create_timer(0.06).timeout; await RenderingServer.frame_post_draw
	var changed: Dictionary=rigs.compare_samples(before,rigs.diagnostic_sample([id],true))
	if not check(int(changed.changed_local_parts)>0 and int(changed.advanced_model_clocks)>0 and (int(changed.skin_meshes_sampled)==0 or float(changed.maximum_local_skin_vertex_delta)>0.00001),"Original correction clip visibly deforms native character geometry",changed): return false
	var after_wire: Vector3=session.world.motion.objects[id].position
	if not check(absf(after_wire.x-before_wire.x-0.75)<0.03 and absf(after_wire.y-before_wire.y)<0.03,"Server script, not a client-side pose edit, supplies the correction destination",{"before":[before_wire.x,before_wire.y,before_wire.z],"after":[after_wire.x,after_wire.y,after_wire.z]}): return false
	if not await wait_for(func():return int(session.world.motion.objects[id].correction)==0 and int(engine.states[id].visual) in [0,1] and engine.states[id].current.is_empty(),"Correction finishes and restores the authoritative idle/ready base",4): return false
	var events: Array=engine.events.filter(func(row):return row.kind=="movement-cue" and int(row.id)==id and int(row.atMs)>=since and int(row.get("type",0))==6)
	return check(events.size()==1,"One server correction queues one fitted step instead of restarting each frame",{"cues":events,"position_error":session.world.motion.objects[id].render.distance_to(session.world.motion.objects[id].position)})
func facing_check(target: int) -> bool:
	var id:=int(session.world.controlled_id)
	var aligned:=func():
		if not session.world.instances.has(id) or not session.world.instances.has(target): return false
		if int(current().get("replicated",{}).get("facingTarget",0x7f000000))!=target: return false
		var actor: Node3D=session.world.instances[id]; var other: Node3D=session.world.instances[target]
		var delta: Vector3=other.global_position-actor.global_position; delta.y=0
		return delta.length_squared()>0.000001 and (-actor.global_basis.z).normalized().dot(delta.normalized())>0.99
	if not await wait_for(aligned,"Actual native body faces the original server's attack target",8): return false
	var actor: Node3D=session.world.instances[id]; var other: Node3D=session.world.instances[target]
	var delta: Vector3=other.global_position-actor.global_position; delta.y=0
	var dot:=(-actor.global_basis.z).normalized().dot(delta.normalized())
	return check(dot>0.99,"Attack-facing evidence is measured on the rendered native pivot",{"source":id,"target":target,"server_facing_target":int(current().replicated.facingTarget),"dot":dot,"angle_degrees":rad_to_deg(acos(clampf(dot,-1,1)))})
func blood_models(target: int) -> Array:
	var blood=session.world.effects.blood; var result: Array=[]
	if not blood.owners.has(target): return result
	for entry in blood.owners[target].slots:
		if entry==null or not is_instance_valid(entry.model): continue
		# Initial particles can have zero alpha/size at their first controller
		# sample. Inspect the real running impact after its first visible phase.
		if float(entry.model.rigs.entities[0].models[0].last_time)<0.12: continue
		if entry.model.find_children("*","Node",true,false).any(func(node):return node.has_method("active_count") and node.failure.is_empty() and node.active_count()>0 and is_instance_valid(node.surface) and node.surface.vertex_count>0): result.append(entry.model)
	return result
func parry_model() -> Dictionary:
	var owner=session.world.effects
	for i in range(owner.parries.history.size()-1,-1,-1):
		var event: Dictionary=owner.parries.history[i]; var entry: Dictionary=owner.entries.get(int(event.effect),{})
		if entry.is_empty() or entry.runtime==null or not is_instance_valid(entry.runtime.state.model): continue
		var model=entry.runtime.state.model
		if float(model.rigs.entities[0].models[0].last_time)<0.12: continue
		if model.find_children("*","Node",true,false).any(func(node):return node.has_method("active_count") and node.failure.is_empty() and node.active_count()>0 and is_instance_valid(node.surface) and node.surface.vertex_count>0): return {"event":event,"model":model}
	return {}
func parry_check() -> void:
	var npc:=-1; var owner=session.world.effects; var parries=owner.parries
	for id in desktop.objects:
		if int(id)!=desktop.actor_id and int(desktop.objects[id].get("objectType",0))==5 and not desktop.objects[id].get("replicationRemoved",false): npc=int(id); break
	if not check(npc>=0,"Original-server melee encounter target exists"): return
	ui.chat.submit("-native-parry-start")
	if not await wait_for(func():return ui.chat.rows.any(func(row):return str(row.get("text","")).contains("GODOT_PARRY_COMBAT")),"Server script starts the real equipped melee encounter"): return
	if not await wait_for(func():return session.world.instances.has(npc) and session.world.combat.engine.actors.get(npc,{}).get("equipment",{}).has("16"),"Unchanged server equips the actual target with the original weapon"):
		check(false,"Parry target preparation diagnostics",{"target":npc,"object":desktop.objects.get(npc,{}),"desired":session.world.desired.get(npc,{}),"models":session.world.instances.keys(),"failures":session.world.failed_objects,"actor":session.world.combat.engine.actors.get(npc,{}),"world":session.world.stats})
		return
	var hit_observations: Array=[]; var listeners: Array=[]
	for actor in [desktop.actor_id,npc]:
		var rigs=session.world.instances[actor].rigs
		var callback:=func(id,index,name,serial):
			if str(name).to_lower()!="hit" or hit_observations.size()>=32: return
			var physical: Dictionary=rigs.entities[id].models[index]
			hit_observations.append({"actor":id,"model":index,"event_source":physical.event_source,"serial":serial,"clip":physical.clip,"authored_events":physical.events.get(physical.clip,[]),"runs":physical.native_owner.gob.runsE0.map(func(run):return {"clip":run.clip0.name,"previous":run.previous10,"time":run.time14,"weight":run.weight18,"flags":run.flagsC}) if physical.has("native_owner") else []})
		rigs.model_event.connect(callback); listeners.append({"rigs":rigs,"callback":callback})
	desktop.open_radial({"id":npc,"position":session.world.instances[npc].position},Vector2(600,350)); var clicked:=false
	for index in desktop.radial_entries:
		if str(desktop.radial_entries[index].get("interaction",""))=="combat.attack": desktop.radial.choose(int(index)); clicked=true; break
	if not check(clicked,"Native radial sends the actual melee attack request"): return
	if not await animation_check("attack"): return
	if not await wait_for(func():return not parry_model().is_empty(),"Original server miss/parry response produces actual native spark particles",45): return
	var selected:=parry_model(); var event: Dictionary=selected.event; var model=selected.model; var effect:=int(event.effect)
	var cue: Array=session.world.combat.engine.events.filter(func(row):return row.kind=="parry" and int(row.id)==int(event.source) and int(row.get("record",{}).get("result",-1)) in [2,4])
	check(not cue.is_empty() and int(event.target) in [desktop.actor_id,npc] and int(event.source) in [desktop.actor_id,npc],"Spark is driven by a real server result2/4 and native parry hit callback",{"cue":cue.back() if not cue.is_empty() else {},"placement":event})
	check(model.anchor_node==null and int(owner.entries[effect].visual)==118 and int(owner.client_dummies.entries[owner.records[effect].actor].object.objectType)==11 and not session.registry.entities.has(int(owner.records[effect].actor)),"Original spark remains a private location effect outside server identities")
	var previous_mode: int=session.world.process_mode; session.world.process_mode=Node.PROCESS_MODE_DISABLED; var ui_visible: bool=ui.controls.visible; ui.controls.hide()
	await RenderingServer.frame_post_draw
	var center: Vector2=session.camera.unproject_position(model.global_position); var shown:=get_viewport().get_texture().get_image(); model.hide()
	await RenderingServer.frame_post_draw
	var hidden:=get_viewport().get_texture().get_image(); var pixels:=0
	for y in range(maxi(0,int(center.y)-200),mini(shown.get_height(),int(center.y)+200)):
		for x in range(maxi(0,int(center.x)-200),mini(shown.get_width(),int(center.x)+200)):
			if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): pixels+=1
	model.show(); session.world.process_mode=previous_mode; ui.controls.visible=ui_visible
	shown.save_png(str(session.args.report).trim_suffix(".json")+"-parry.png")
	check(pixels>0,"Real server parry spark changes the native viewport",{"changed_pixels":pixels,"radius":200,"center":[center.x,center.y],"parries":parries.snapshot(),"hit_observations":hit_observations})
	var held: WeakRef=weakref(model)
	if not await wait_for(func():return not owner.entries.has(effect),"Original parry spark retires through its native area timer"): return
	await get_tree().process_frame; await get_tree().process_frame
	check(held.get_ref()==null,"Original spark retirement releases its actual native model")
	check(parries.stats.failed==0 and parries.stats.spawned>0,"Real parry presentation has no placement/preparation failures",parries.snapshot())
	for row in listeners:
		if is_instance_valid(row.rigs) and row.rigs.model_event.is_connected(row.callback): row.rigs.model_event.disconnect(row.callback)
	await equipped_visual_check(npc)
	await creature_voice_check()

func creature_voice_check() -> void:
	# Queued with the sustained localhost melee fixture; never run headless
	# integration through a live server while the user's test pause is active.
	var voices=session.world.effects.creature_voices; var audio=session.world.effects.world_audio
	var eligible: bool=(int(current().get("appearance",{}).get("field8A0",65535))&65535)!=65535
	if not eligible: check(true,"This sample has no authoritative voice soundset; actual combat voice coverage remains missing"); return
	var selected: Dictionary={}
	if not await wait_for(func():
		for value in voices.history:
			if not value.started or int(value.actor)!=desktop.actor_id or not audio.voices.has(int(value.sound)): continue
			if not session.world.combat.engine.events.any(func(event):return event.kind=="bark" and int(event.id)==int(value.actor) and int(event.code)==int(value.code)): continue
			var source: Dictionary=audio.voices[int(value.sound)]
			if not is_instance_valid(source.player) or source.player.get_playback_position()<=0: continue
			selected.merge({"event":value.duplicate(),"profile":source.profile.duplicate(),"resource":source.name,"position":source.position.duplicate(),"clock":source.player.get_playback_position(),"metadata":audio.resources[source.resourceId].metadata.duplicate(true)})
			return true
		return false,"Real server melee presentation produces an advancing native controlled-actor voice",25):
		check(false,"Native combat voice diagnostics",{"voices":voices.snapshot(),"audio":audio.snapshot()}); return
	check(int(selected.profile.priority)==6 and bool(selected.profile.positional) and selected.clock>0 and voices.stats.failed==0 and audio.stats.failed==0,"Actual combat bark uses original source priority and native decoding without provider failures",{"selected":selected,"driver":AudioServer.get_driver_name(),"physicalAudibilityVerified":false})

func equipped_visual_check(actor: int) -> void:
	# Queued localhost acceptance; do not run while live/GPU tests are paused.
	var weapons=session.world.effects.equipped_attacks
	if not await wait_for(func():return weapons.records.has(actor) and is_instance_valid(weapons.records[actor].model),"Original server melee animation admits a native equipped blur model",30): return
	var record: Dictionary=weapons.records[actor]; var model=record.model
	check(model.anchor_node==session.world.instances[actor].equipment_part(16,"root") and model.get_meta("native_weapon_slot_configuration",[])==[251,0,0],"Actual equipped blur has original slotFB and the real held-model anchor")
	var mode: int=session.world.process_mode; var controls_visible: bool=ui.controls.visible
	session.world.process_mode=Node.PROCESS_MODE_DISABLED; ui.controls.hide(); await RenderingServer.frame_post_draw
	var center: Vector2=session.camera.unproject_position(model.global_position); var shown:=get_viewport().get_texture().get_image(); model.hide()
	await RenderingServer.frame_post_draw
	var hidden:=get_viewport().get_texture().get_image(); var pixels:=0
	for y in range(maxi(0,int(center.y)-120),mini(shown.get_height(),int(center.y)+120)):
		for x in range(maxi(0,int(center.x)-120),mini(shown.get_width(),int(center.x)+120)):
			if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): pixels+=1
	model.show(); session.world.process_mode=mode; ui.controls.visible=controls_visible
	shown.save_png(str(session.args.report).trim_suffix(".json")+"-weapon-blur.png")
	check(pixels>0,"Real original weapon blur changes viewport pixels",{"pixels":pixels,"actor":actor,"resource":model.bundle_data.resource_name})
	var retained: WeakRef=weakref(model)
	if not await wait_for(func():return retained.get_ref()==null,"Original blur end/completion releases the equipped native model",15): return
	check(weapons.stats.failed==0,"Original-server equipped attack visuals finish without model/colour failures",weapons.snapshot())
func blood_check(target: int) -> bool:
	if not await wait_for(func():return not blood_models(target).is_empty(),"Real original-server hit creates active native blood particles",25): return false
	var blood=session.world.effects.blood; var models: Array=blood_models(target)
	check(blood.stats.failed==0 and models.all(func(model):return is_instance_valid(model.anchor_node) and model.anchor_flags==3),"Server hit blood models have real body anchors and no preparation failures",blood.snapshot())
	var previous_mode: int=session.world.process_mode; session.world.process_mode=Node.PROCESS_MODE_DISABLED; var ui_visible: bool=ui.controls.visible; ui.controls.hide()
	await RenderingServer.frame_post_draw
	var center: Vector2=session.camera.unproject_position(models[0].global_position); var shown:=get_viewport().get_texture().get_image()
	for model in models: model.hide()
	await RenderingServer.frame_post_draw
	var hidden:=get_viewport().get_texture().get_image(); var pixels:=0
	for y in range(maxi(0,int(center.y)-160),mini(shown.get_height(),int(center.y)+160)):
		for x in range(maxi(0,int(center.x)-160),mini(shown.get_width(),int(center.x)+160)):
			if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): pixels+=1
	for model in models: model.show()
	session.world.process_mode=previous_mode; ui.controls.visible=ui_visible
	shown.save_png(str(session.args.report).trim_suffix(".json")+"-blood.png")
	return check(pixels>0,"Actual original blood models change the native viewport after the real server hit",{"changed_pixels":pixels,"region_center":[center.x,center.y],"radius":160,"blood":blood.snapshot()})

func rigid_mesh_sample(instance) -> Dictionary:
	var output: Dictionary={}; var inverse: Transform3D=instance.global_transform.affine_inverse()
	for mesh in instance.meshes:
		if mesh.skin!=null or not mesh.is_visible_in_tree(): continue
		# Sample the indexed positions submitted by the native resource pool,
		# without a GPU mesh readback during a live animation/render frame.
		var geometry=mesh.mesh.get_meta("native_pick_geometry",null)
		if geometry==null or geometry.indices.is_empty(): continue
		var sampled:=PackedVector3Array(); var transform: Transform3D=inverse*mesh.global_transform
		for index in [0,geometry.indices.size()/2,geometry.indices.size()-1]: sampled.append(transform*geometry.vertices[geometry.indices[int(index)]])
		output[str(mesh.get_instance_id())]=sampled
	return output
func rigid_mesh_delta(before: Dictionary,after: Dictionary) -> float:
	var delta:=0.0
	for key in before:
		if not after.has(key): continue
		for index in mini(before[key].size(),after[key].size()): delta=maxf(delta,before[key][index].distance_to(after[key][index]))
	return delta
func animation_check(kind: String,spell_id: int=-1) -> bool:
	var id: int=desktop.actor_id
	var ranged: bool=kind=="attack" and session.args.get("actions-ranged-check","")=="true"
	var active:=func():
		if not is_instance_valid(session.world) or not is_instance_valid(session.world.combat): return false
		var state: Dictionary=session.world.combat.engine.states.get(id,{})
		var action: Variant=state.get("action")
		# action survives between attack cues. Under incoming NPC attacks it can
		# coexist with a ready/reaction clip; sample the actual live attack cue,
		# with enough remaining time for the 60ms geometry comparison below.
		var ranged_ready: bool=not ranged or int(state.get("visual",-1)) in [200,201,202,203,204,205,263,264,265] and int(state.get("current",{}).get("remaining",0))>=150
		return ranged_ready and not state.get("current",{}).is_empty() and action is Dictionary and int(action.get("type",-1))==(4 if kind=="cast" else 1) and (spell_id<0 or int(action.get("spellId",-1))==spell_id)
	if not await wait_for(active,"Real server %s cue owns the controlled actor animation"%kind,25): return false
	var instance: Node3D=session.world.instances[id]; var rigs=instance.rigs
	await RenderingServer.frame_post_draw
	var before: Dictionary=rigs.diagnostic_sample([id],not ranged)
	var rigid_before: Dictionary=rigid_mesh_sample(instance) if ranged else {}
	await get_tree().create_timer(0.06).timeout
	await RenderingServer.frame_post_draw
	var comparison: Dictionary=rigs.compare_samples(before,rigs.diagnostic_sample([id],not ranged))
	var visible: bool=int(comparison.changed_local_parts)>0 and int(comparison.advanced_model_clocks)>0 and (int(comparison.skin_meshes_sampled)==0 or float(comparison.maximum_local_skin_vertex_delta)>0.00001)
	if ranged:
		comparison.rigid_meshes_sampled=rigid_before.size(); comparison.maximum_actor_local_rigid_vertex_delta=rigid_mesh_delta(rigid_before,rigid_mesh_sample(instance))
		visible=int(comparison.changed_local_parts)>0 and int(comparison.advanced_model_clocks)>0 and float(comparison.maximum_actor_local_rigid_vertex_delta)>0.00001
	if not check(visible,"Original %s clips visibly deform native actor geometry"%kind,comparison): return false
	var state: Dictionary=session.world.combat.engine.states.get(id,{})
	check(not state.is_empty() and int(state.visual) not in [0,1],"Idle movement cannot overwrite the live %s cue"%kind)
	# Keep the ordinary UI/server state intact, but expose the actor for visual
	# review. The geometry samples above still use the normal visible menus.
	var was_visible: bool=ui.controls.visible; ui.controls.hide()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(session.args.report).trim_suffix(".json")+"-"+kind+".png")
	ui.controls.visible=was_visible
	return true

func nui_record(title: String) -> Dictionary:
	for record in ui.nui.records.values():
		if str(ui.nui.state.windows[int(record.token)].layout.get("title",""))==title: return record
	return {}
func nui_node(record: Dictionary,tag: String):
	if record.is_empty() or not ui.nui.view.windows.has(int(record.id)): return null
	for node in ui.nui.view.windows[int(record.id)].nodes.values():
		if str(node.spec.get("tag",""))==tag: return node
	return null
func nui_bind(record: Dictionary,key: String) -> Variant:
	return ui.nui.state.windows.get(int(record.get("token",-1)),{}).get("bindings",{}).get(key)
func nui_check() -> void:
	ui.chat.submit("-native-nui")
	if not await wait_for(func():return not nui_record("Local native NUI").is_empty(),"Server creates the native NUI root"): return
	var record:=nui_record("Local native NUI")
	if not await wait_for(func():return nui_bind(record,"caption")=="Native open event accepted" and nui_node(record,"edit")!=null,"Native open event reaches the real server callback"): return
	var edit=nui_node(record,"edit"); edit.widget.text="Native Godot input"; edit.widget.text_changed.emit(edit.widget.text)
	if not await wait_for(func():return nui_bind(record,"echo")=="Native Godot input","Native text editing triggers a server watched binding"): return
	var toggle=nui_node(record,"check"); toggle.widget.button_pressed=true; toggle.widget.pressed.emit()
	if not await wait_for(func():return nui_bind(record,"echo_check")==true,"Native checkbox watch returns authoritative echo"): return
	var combo=nui_node(record,"combo"); combo.widget.item_selected.emit(1)
	if not await wait_for(func():return int(nui_bind(record,"echo_choice"))==20,"Native combo maps displayed index to server value"): return
	var list=nui_node(record,"rows"); list.send({"operation":"range","start":100,"count":16})
	if not await wait_for(func():return ui.nui.view.windows[int(record.id)].nodes.values().any(func(node):return str(node.spec.get("tag",""))=="row_check" and int(node.spec.index)==105),"Native virtual list presents a distant server row"): return
	for node in ui.nui.view.windows[int(record.id)].nodes.values():
		if str(node.spec.get("tag",""))=="row_check" and int(node.spec.index)==105: node.widget.button_pressed=true; node.widget.pressed.emit(); break
	if not await wait_for(func():return nui_bind(record,"echo_checks") is Array and nui_bind(record,"echo_checks")[105]==true,"Indexed list edit reaches the server as a whole binding with row index"): return
	nui_node(record,"next").widget.pressed.emit()
	if not await wait_for(func():return not nui_record("Native child menu").is_empty(),"Native button callback opens a server child menu"): return
	var child:=nui_record("Native child menu"); nui_node(child,"third").widget.pressed.emit()
	if not await wait_for(func():return not nui_record("Resource-backed grandchild").is_empty(),"Server JUI resource opens a native grandchild"): return
	if not await wait_for(func():return ui.nui.image_jobs.is_empty(),"NUI images finish through native archive readers"): return
	var toolbar:=nui_record("")
	check(not toolbar.is_empty() and int(ui.nui.view.windows[int(toolbar.id)].size.y)>=48,"Native toolbar retains the full icon-box height")
	var toolbar_rect: Rect2=ui.nui.view.windows[int(toolbar.id)].get_global_rect()
	check(toolbar_rect.position.x>=0 and toolbar_rect.position.y>=0 and toolbar_rect.end.x<=session.root.size.x and toolbar_rect.end.y<=session.root.size.y,"Headerless toolbar remains fully inside the viewport")
	if nui_node(child,"target")!=null:
		nui_node(child,"target").widget.pressed.emit()
		if not await wait_for(func():return int(desktop.target.get("type",0))==45,"NUI callback enters native server targeting mode"): return
		click_spell_target()
		if not await wait_for(func():return nui_bind(record,"target_ack")=="Native target selection accepted","Native world click reaches the server targeting callback"): return
	if nui_node(child,"cast")!=null:
		nui_node(child,"cast").widget.pressed.emit()
		if not await wait_for(func():return int(desktop.target.get("type",0))==45,"NUI spell button enters server targeting mode"): return
		click_spell_target()
		if not await wait_for(func():return nui_bind(record,"target_ack")=="Native cast target accepted","NUI target selection queues the server spell action"): return
	await RenderingServer.frame_post_draw
	session.root.get_texture().get_image().save_png(str(session.args.report)+".nui.png")
	var root_window=ui.nui.view.windows[int(record.id)]; root_window.close.pressed.emit()
	if not await wait_for(func():return not ui.nui.records.has(int(record.token)),"Closing native NUI retires its connection-owned window"): return
	check(ui.nui.diagnostics.is_empty(),"Native NUI projection has no failures",{"diagnostics":ui.nui.diagnostics})

func impact_profile_check() -> void:
	var npc:=-1
	for id in desktop.objects:
		if int(desktop.objects[id].get("objectType",0))==5 and int(id)!=desktop.actor_id: npc=int(id); break
	if not check(npc>=0,"Actual local combat target is available for impact profiling"): return
	desktop.open_radial({"id":npc,"position":position()},Vector2(600,350))
	for slot in desktop.radial_entries:
		if str(desktop.radial_entries[slot].get("interaction",""))=="combat.attack": desktop.radial.choose(int(slot)); break
	if not await wait_for(func():return session.world.combat.engine.stats.hits>0,"Original server attacks drive native impact profiling",25): return
	for pass_index in 4:
		var enabled:=pass_index%2==1; session.particle_visibility.set_enabled(enabled)
		await get_tree().create_timer(0.5).timeout
		var profiler=session.frame_profile; profiler.rows.clear(); profiler.last_summary={}; profiler.mode="impact-particles-"+("on" if enabled else "off")+"-"+str(pass_index)
		var hits: int=session.world.combat.engine.stats.hits
		await get_tree().create_timer(3.0).timeout
		var snapshot: Dictionary=profiler.snapshot(); var worst: Array=profiler.rows.duplicate(true)
		worst.sort_custom(func(a,b):return float(a.wall_ms)>float(b.wall_ms))
		check(session.world.combat.engine.stats.hits>hits,"Impact cost with particles "+("on" if enabled else "off"),{"pass":pass_index,"particles":enabled,"hits":session.world.combat.engine.stats.hits-hits,"profile":snapshot,"worst_frames":worst.slice(0,8),"particle_state":session.world.particle_metrics.snapshot()})
	if not desktop.action_queue.buttons.is_empty():
		var action_serial: int=desktop.action_queue.buttons.keys()[0]; desktop.action_queue.buttons[action_serial].pressed.emit()
		await wait_for(func():return not desktop.action_queue.buttons.has(action_serial),"Profiled attack is cancelled through the original server")
func special_attack_check() -> void:
	if not ui.inventory.ui.wanted: ui.inventory.ui.open()
	if not await wait_for(func():return not ui.inventory.views.is_empty(),"Original monk inventory arrives from unchanged local server"): return
	check(current().get("replicated",{}).get("stats",{}).get("classes",[]).any(func(cls):return int(cls.id)==5) and desktop.rules.feats(current()).has(39) and desktop.rules.feats(current()).has(296),"Original sample owns Monk, Stunning Fist and Quivering Palm")
	var weapons: Array=[]
	for id in ui.inventory.views:
		var row: Dictionary=ui.inventory.views[id].row
		if row.channel=="I" and int(row.slot) in [16,32]: weapons.append(int(id))
	for id in weapons:
		inventory_action(int(id),"unequip")
		if not await wait_for(func():return channel(int(id))=="R" and not ui.inventory.pending.has(int(id)),"Original server accepts unarmed equipment choice"): return
	var npc:=-1
	for id in desktop.objects:
		if int(desktop.objects[id].get("objectType",0))==5 and ui.text.name(null,int(id)).contains("Native"): npc=int(id); break
	if not check(npc>=0,"Actual original-server target is available for special attacks"): return
	var specials=session.world.effects.special_attacks
	if not await special_initialization_check(): return
	if not await wait_for(func():return ["vcm_monkstun","vcm_monkquiv","vcm_monkki"].all(func(resource):return session.world.effects.bundles.has(resource) and str(session.world.effects.bundles[resource].get("error","")).is_empty()),"Owned special-attack resources are warm through native workers"): return
	var kind:=str(session.args.get("actions-special-attack-kind","stun")); var selected_feat:=39 if kind=="stun" else (296 if kind=="quivering" else 0)
	for feat in [selected_feat]:
		var before: int=specials.history.size(); var uses: int=desktop.rules.feat_uses(current(),int(feat))
		desktop.open_radial({"id":npc,"position":position()},Vector2(600,350))
		var chosen:=-1
		if feat==0:
			for slot in desktop.radial_entries:
				if str(desktop.radial_entries[slot].get("interaction",""))=="combat.attack": chosen=int(slot); break
		else:
			for slot in desktop.radial_entries:
				if str(desktop.radial_entries[slot].label)=="Special abilities": desktop.radial.choose(int(slot)); break
			for slot in desktop.radial_entries:
				if int(desktop.radial_entries[slot].get("binding",{}).get("intParam",-1))==feat: chosen=int(slot); break
		if not check(chosen>=0,"Native radial exposes owned special attack"+str(feat)): return
		desktop.radial.choose(chosen)
		if not desktop.target.is_empty(): desktop.world_click({"id":npc,"position":session.world.instances[npc].global_position})
		var resource:="vcm_monkstun" if feat==39 else ("vcm_monkquiv" if feat==296 else "vcm_monkki")
		if not await wait_for(func():return specials.history.slice(before).any(func(e):return e.kind=="play" and e.resource==resource and e.clip=="impact" and e.played),"Real server special-attack cue and original blur event play "+resource,30):
			check(false,"Special-attack failure diagnostics",{"effects":specials.snapshot(),"combat":session.world.combat.snapshot(),"feedback":ui.chat.rows.slice(-16),"uses":desktop.rules.feat_uses(current(),int(feat))}); return
		if feat!=0: check(desktop.rules.feat_uses(current(),int(feat))<uses,"Original server consumes special-attack use"+str(feat),{"before":uses,"after":desktop.rules.feat_uses(current(),int(feat))})
		var handle: Dictionary={}
		for h in specials.handles.values():
			if h.resource==resource and is_instance_valid(h.model) and h.model.anchor_node!=null: handle=h; break
		if not check(not handle.is_empty(),"Real special attack has an actual original physical limb attachment"): return
		var samples: Array=[]
		if not await wait_for(func():
			var drawn:=false
			for node in handle.model.find_children("*","Node3D",true,false):
				if not node.has_method("detonate"): continue
				drawn=drawn or is_instance_valid(node.surface) and int(node.surface.vertex_count)>0
				if samples.size()<256: samples.append({"clock":node.clock_provider.call(),"particle":node.snapshot(),"parameters":node.parameters.duplicate(true)})
			return drawn,"Original special-attack particles produce actual GPU geometry"):
			check(false,"Missing special-attack particle diagnostics",{"samples":samples,"events":specials.snapshot()}); return
		var mode: int=session.world.process_mode; var visible: bool=ui.controls.visible; session.world.process_mode=Node.PROCESS_MODE_DISABLED; ui.controls.hide()
		await RenderingServer.frame_post_draw
		var center: Vector2=session.camera.unproject_position(handle.model.global_position); var shown:=get_viewport().get_texture().get_image(); handle.model.hide()
		await RenderingServer.frame_post_draw
		var hidden:=get_viewport().get_texture().get_image(); var pixels:=0
		for y in range(maxi(0,int(center.y)-160),mini(shown.get_height(),int(center.y)+160)):
			for x in range(maxi(0,int(center.x)-160),mini(shown.get_width(),int(center.x)+160)):
				if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): pixels+=1
		handle.model.show(); session.world.process_mode=mode; ui.controls.visible=visible; shown.save_png(str(session.args.report).trim_suffix(".json")+"-special-"+str(feat)+".png")
		check(pixels>0,"Real original special-attack model changes native viewport pixels",{"feat":feat,"resource":resource,"pixels":pixels})
		if not await wait_for(func():return specials.history.slice(before).any(func(e):return e.kind=="play" and e.resource==resource and e.clip=="cessation" and e.played),"Original blur-end/completion plays cessation for "+resource,20): return
		if not desktop.action_queue.buttons.is_empty():
			var action_serial: int=desktop.action_queue.buttons.keys()[0]; desktop.action_queue.buttons[action_serial].pressed.emit()
			if not await wait_for(func():return not desktop.action_queue.buttons.has(action_serial) and not desktop.action_queue.pending.has(action_serial),"Special-attack action cancellation reaches the unchanged server"): return
		await get_tree().create_timer(1.0).timeout
	check(specials.stats.failed==0,"Real server special-attack visual delivery has no model/Part/clip failures",specials.snapshot())
func special_initialization_check() -> bool:
	var init=preload("res://systems/native_data/special_initialization.gd"); var state=preload("res://systems/native_data/special_attack_visual.gd")
	var classes: Array=current().get("replicated",{}).get("stats",{}).get("classes",[]); var specials=session.world.effects.special_attacks; var id: int=desktop.actor_id
	if state.gate(classes,[desktop.rules.feats(current())],0)==1:
		if not await wait_for(func():return specials.records.has(id) and specials.records[id].state.slots.slice(0,2).all(func(h):return h!=null and is_instance_valid(h.model)),"Original authoritative monk initializes both lazy ki models before a swing"): return false
	var appearance: Dictionary=current().get("appearance",{}); var eligible: bool=state.gate(classes,[],1)==1 and int(appearance.get("appearance",65535))<=6
	if not eligible: return check(true,"Eye visual acceptance requires an original level20 compatible appearance; this sample does not cover it",{"classes":classes,"appearance":appearance})
	if not await wait_for(func():return specials.records.has(id) and specials.records[id].eye.model!=null and is_instance_valid(specials.records[id].eye.model.model),"Original server state initializes the persistent level20 eye model"): return false
	var handle: Dictionary=specials.records[id].eye.model; var model=handle.model
	var alignment:=clampi(int(current().replicated.stats.fieldDE4),0,100); var expected: String=init.resource(alignment,int(appearance.appearance),int(appearance.get("gender",0)))
	if not check(handle.resource==expected and model.anchor_node==session.world.instances[id].physical_part("head_g"),"Persistent eyes select the original variant and physical head_g from authoritative metadata",{"resource":handle.resource,"expected":expected}): return false
	if not await wait_for(func():return model.find_children("*","Node3D",true,false).any(func(node):return node.has_method("detonate") and is_instance_valid(node.surface) and int(node.surface.vertex_count)>0),"Original persistent eye emitters produce native GPU geometry"): return false
	var mode: int=session.world.process_mode; var visible: bool=ui.controls.visible; session.world.process_mode=Node.PROCESS_MODE_DISABLED; ui.controls.hide()
	await RenderingServer.frame_post_draw
	var center: Vector2=session.camera.unproject_position(model.global_position); var shown:=get_viewport().get_texture().get_image(); model.hide()
	await RenderingServer.frame_post_draw
	var hidden:=get_viewport().get_texture().get_image(); var pixels:=0
	for y in range(maxi(0,int(center.y)-80),mini(shown.get_height(),int(center.y)+80)):
		for x in range(maxi(0,int(center.x)-80),mini(shown.get_width(),int(center.x)+80)):
			if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): pixels+=1
	model.show(); session.world.process_mode=mode; ui.controls.visible=visible; shown.save_png(str(session.args.report).trim_suffix(".json")+"-monk-eyes.png")
	return check(pixels>0 and specials.stats.failed==0,"Real original eye model changes viewport pixels without native provider failures",{"pixels":pixels,"effects":specials.snapshot()})
func rest_and_feat_check() -> bool:
	var before: int=desktop.rules.spell_uses(current(),100,0)
	desktop.party.action_buttons[4].pressed.emit()
	if not await wait_for(func():return desktop.rules.spell_uses(current(),100,0)>before,"Party HUD Rest restores real server spell preparations",30): return false
	desktop.open_radial({"id":desktop.actor_id,"position":position()},Vector2(600,350))
	for index in desktop.radial_entries:
		if str(desktop.radial_entries[index].label)=="Special abilities": desktop.radial.choose(int(index)); break
	var slot:=-1
	for index in desktop.radial_entries:
		if int(desktop.radial_entries[index].get("binding",{}).get("intParam",-1))==303: slot=int(index); break
	if not check(slot>=0,"Owned Summon Familiar feat appears in the native special-ability radial"): return false
	desktop.radial.choose(slot); click_spell_target()
	if not await wait_for(func():return int(current().get("familiarId",2130706432))!=2130706432,"Activating a native feat summons the authoritative server familiar",20): return false
	var familiar: int=current().familiarId
	desktop.open_radial({"id":familiar,"position":position()},Vector2(600,350))
	for index in desktop.radial_entries:
		if str(desktop.radial_entries[index].label)=="Companion commands": desktop.radial.choose(int(index)); break
	slot=-1
	for index in desktop.radial_entries:
		if int(desktop.radial_entries[index].get("binding",{}).get("intParam",0))==-8: slot=int(index); break
	if not check(slot>=0,"Actual familiar radial exposes Unsummon"): return false
	desktop.radial.choose(slot)
	return await wait_for(func():return int(current().get("familiarId",2130706432))==2130706432,"Unsummon removes the familiar through server replication")
