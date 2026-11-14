extends "res://tests/native_quickbar_frame_test.gd"
const DialogPlan=preload("res://systems/native_data/conversation_layout.gd")
func dialog_settled(ui) -> bool:
	var skin=ui.conversation_skin
	if not skin.layout_ready or not skin.failure.is_empty() or not ui.conversation.visible or not skin.display_ready() or skin.background==null or not skin.background.visible or not settled(ui): return false
	for pair in [[skin.entry_bar,skin.entry_bar_host,skin.geometry.entry_bar],[skin.reply_bar,skin.reply_bar_host,skin.geometry.reply_bar]]:
		if not pair[1].visible: continue
		var bar=pair[0]; var entry: Dictionary=pair[2]
		if not is_instance_valid(bar) or not bar.art_ready or not bar.failure.is_empty() or bar.snapshot().layout_pending or bar.snapshot().thumb_pending or bar.plan.attachment.distance_to(entry.offset+entry.model.hooks.scrollmin)>=0.001: return false
	return true
func receive(ui,message: Dictionary) -> void:
	ui.receive(message,1); await process_frame; await process_frame
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,900); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original conversation resources mount read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); ui.request.connect(func(m):requests.append(m.duplicate(true)))
	check(await wait_until(func():return ui.tables_ready),"Active original TLK and portrait rules prepare")
	var dialog=ui.conversation; var skin=ui.conversation_skin; check(skin.requested and not dialog.opened,"Installed conversation models prepare before the first dialogue")
	var portrait:=-1
	for id in ui.text.tables.portraits.orderedRows.size():
		var res: String=ui.desktop.rules.cell(ui.desktop.rules.row("portraits",id),"BaseResRef","")
		if not res.is_empty() and res!="****" and not catalog.raster_location("po_"+res+"m").is_empty(): portrait=id; break
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Listener"},"portrait":portrait,"hitPoints":{"current":10,"maximum":10},"stats":{"racialType":6,"classes":[{"id":10,"level":1}]}},"playerState":{}}
	var speaker:=actor.duplicate(true); speaker.id=43; speaker.replicated.name={"text":"Native Speaker"}; ui.set_world(1,55,42,[actor,speaker],{},{"area":{"id":55}}); ui.text.custom_tokens[18]="ready"
	dialog.position=Vector2(60,70)
	await receive(ui,{"kind":"dialog-entry","ownerId":43,"speakerId":43,"tokenObjectId":43,"text":{"text":"Choose a reply. <CUSTOM18>"}})
	await receive(ui,{"kind":"dialog-replies","entryId":4294967294,"end":false,"firstCount":2,"secondCount":1,"tokenObjectId":43,"replies":[{"id":4294967293,"text":{"text":"First offered reply"}},{"id":9,"text":{"text":"A long reply that wraps onto a second line without moving its separate number column."}},{"id":77,"text":{"text":"A received read-only reply"}}]})
	check(await wait_until(func():return skin.layout_ready or not skin.failure.is_empty()),"Original programmatic dialogue frame finishes preparation")
	var diagnostic: Dictionary={"failure":skin.failure}
	if skin.layout_ready and skin.failure.is_empty():
		check(await wait_until(func():return dialog_settled(ui)),"Original conversation size pose, scrollbars, portraits and fonts publish")
		check(not dialog.window_column.visible and dialog.size.x==360 and dialog.size.y>=258,"Generic title/reply/end controls are replaced by the original-width dynamic panel")
		check(not is_instance_valid(skin.entry_bar) and not is_instance_valid(skin.reply_bar),"Short original conversation does not create hidden scrollbars or invalid empty-list rail geometry")
		check(skin.name_label.get_parsed_text()=="Native Speaker" and skin.name_label.get_meta("native_font_applied","")=="fnt_galahad14","Header uses the actual received speaker name and original font")
		check(skin.portrait.size==Vector2(64,100) and skin.portrait.texture!=null and skin.portrait.flip_v,"Speaker portrait uses its original64x100 attachment and native UV row order")
		check(dialog.body.get_parsed_text()=="Choose a reply. ready" and dialog.body.get_meta("native_font_applied","")==DialogPlan.FONT,"Entry uses native token expansion and the original default dialogue font")
		var button: Button=dialog.replies.get_child(1); var label: RichTextLabel=button.get_child(0); var number: Label=button.get_meta("native_dialog_number")
		check(number.text=="2." and number.size.x==16 and number.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT and label.position.x==20 and label.size.x==311,"Reply numbering has its separate source16px column and20px text indent")
		check(label.get_content_height()>17 and absf(button.custom_minimum_size.y-label.get_content_height())<0.01,"Wrapped reply hit area follows native text height without a generic button frame")
		check(dialog.reply_available==[true,true,false] and dialog.replies.get_child(2).disabled,"Trailing second-count replies remain visible and nonselectable")
		var before: int=requests.size(); dialog.replies.get_child(2).pressed.emit(); await key(KEY_3); await key(KEY_3,false); check(requests.size()==before,"Read-only pointer/number input cannot submit a received disabled reply")
		await shot(output,"-normal")
		var start: Vector2=dialog.position; var title_point: Vector2=skin.name_label.get_global_rect().get_center(); await motion(title_point); await mouse(title_point,true); await motion(title_point+Vector2(25,30),Vector2(25,30),true); await mouse(title_point+Vector2(25,30),false)
		check(dialog.position.distance_to(start+Vector2(25,30))<0.01,"Actual original speaker-name header can drag the conversation window")
		var config:=ConfigFile.new(); config.load(output+".layout.cfg"); check(config.get_value("positions","local-dialog",Vector2.ZERO)==dialog.position,"Conversation placement persists in the configured menu-layout file")
		ui.controls.scale=Vector2.ONE*1.25; await process_frame; await process_frame
		check(absf(dialog.get_global_rect().size.x-450)<0.001 and skin.portrait.get_global_rect().size==Vector2(80,125) and absf(label.get_global_rect().size.x-388.75)<0.001,"125percent UI scale preserves source frame, portrait and reply-column proportions")
		await shot(output,"-scaled"); ui.controls.scale=Vector2.ONE; await process_frame
		await motion(button.get_global_rect().get_center()); check(label.get_meta("native_text_color")==Color.WHITE,"Actual reply hover selects the original white highlight")
		await click(dialog.replies.get_child(0).get_global_rect().get_center())
		check(requests.size()==before+1 and requests.back()=={"kind":"reply","entryId":4294967294,"replyId":4294967293,"abort":false} and dialog.pending,"Native reply click preserves full unsigned wire IDs and waits for the server")
		dialog.replies.get_child(1).pressed.emit(); check(requests.size()==before+1,"Pending conversation cannot send a second reply")
		await receive(ui,{"kind":"dialog-error","entryId":5}); check(dialog.pending,"A stale reply error cannot unlock the current entry")
		await receive(ui,{"kind":"dialog-error","entryId":4294967294}); check(not dialog.pending and not dialog.replies.get_child(0).disabled and dialog.replies.get_child(2).disabled,"Current refusal restores only originally available choices")
		var entry_text: String=dialog.body.get_parsed_text()
		await receive(ui,{"kind":"dialog-selected","field0":9,"field1":4294967294,"end":0,"tokenObjectId":43,"text":{"text":"Server-selected text"}})
		check(dialog.body.get_parsed_text()==entry_text and dialog.replies.get_child(1).get_child(0).get_parsed_text()=="Server-selected text","Selected transcript replaces the matching reply rather than appending to the speaker entry")
		var count: int=dialog.replies.get_child_count(); await receive(ui,{"kind":"dialog-selected","field0":999,"field1":1,"end":0,"tokenObjectId":43,"text":{"text":"Stale"}}); check(dialog.replies.get_child_count()==count,"Selected text for an old entry is ignored")
		await receive(ui,{"kind":"dialog-selected","field0":999,"field1":4294967294,"end":0,"tokenObjectId":43,"text":{"text":"Another participant selected this"}})
		check(dialog.replies.get_child_count()==count+1 and dialog.replies.get_child(count).disabled and not dialog.available(999),"A selected reply absent from the offer is displayed read-only")
		var retired: Button=dialog.replies.get_child(0); before=requests.size()
		await receive(ui,{"kind":"dialog-entry","ownerId":43,"speakerId":43,"tokenObjectId":43,"text":{"text":"A newer entry"}})
		check(dialog.position.distance_to(start+Vector2(25,30))<0.01,"A new server entry retains the dragged conversation position")
		await receive(ui,{"kind":"dialog-replies","entryId":7,"end":false,"firstCount":1,"secondCount":0,"tokenObjectId":43,"replies":[{"id":4294967293,"text":{"text":"Same ID in a new view"}}]})
		# Retain the old callback itself because native view retirement frees its node.
		check(requests.size()==before and not dialog.pending,"New entry presentation sends no reply or predicted gameplay action")
		var old_callback: Callable=dialog.replies.get_child(0).pressed.get_connections()[0].callable
		await receive(ui,{"kind":"dialog-replies","entryId":7,"end":false,"firstCount":1,"secondCount":0,"tokenObjectId":43,"replies":[{"id":4294967293,"text":{"text":"Fresh callback owner"}}]}); old_callback.call(); check(requests.size()==before,"A retired callback cannot select a repeated wire ID in a replacement view")
		retired=null
		# Chat focus now has its own native-panel notifications. Those are valid
		# server UI events, so testing all request traffic as though it were only
		# dialogue commands incorrectly rejects a successful focus transition.
		var chat_start: int=requests.size(); var chat_entry: int=dialog.entry_id; var chat_serial: int=dialog.serial; var chat_pending: bool=dialog.pending
		ui.chat.entry.grab_focus(); await key(KEY_1); await key(KEY_1,false); ui.chat.entry.release_focus(); await process_frame
		var chat_messages: Array=requests.slice(chat_start)
		var focus_messages: Array=chat_messages.filter(func(message):return message.kind=="native-panel" and message.get("panel")=="chat-focus")
		check(not chat_messages.any(func(message):return message.kind=="reply") and dialog.entry_id==chat_entry and dialog.serial==chat_serial and dialog.pending==chat_pending,"Typing numbers in chat leaves dialogue choices, entry serial and pending state untouched")
		check(focus_messages.size()==2 and focus_messages.map(func(message):return message.open)==[true,false] and focus_messages.all(func(message):return message.actorId==42 and message.areaId==55 and message.generation==1 and message.mode==2),"Chat focus emits its separate open/close native-panel notifications")
		ui.desktop.panel("character"); check(await wait_until(func():return ui.desktop.sheet.visible),"Character sheet is admitted before testing covered dialogue input")
		await key(KEY_1); await key(KEY_1,false); check(not dialog.pending,"A covered dialogue does not steal another window's numeric shortcuts"); ui.desktop.sheet.close_sheet(); before=requests.size()
		check(await wait_until(func():return dialog.visible),"Dialogue is admitted before testing its numeric choice")
		dialog.move_to_front(); await key(KEY_1); await key(KEY_1,false); check(requests.size()==before+1 and requests.back().entryId==7,"The front dialogue accepts its real numeric choice")
		await receive(ui,{"kind":"dialog-entry","ownerId":43,"speakerId":43,"tokenObjectId":43,"text":{"text":"A terminal entry"}})
		await receive(ui,{"kind":"dialog-replies","entryId":8,"end":true,"firstCount":0,"secondCount":0,"tokenObjectId":43,"replies":[]}); before=requests.size(); dialog.choose(4294967295)
		check(not dialog.visible and requests.size()==before,"An original synthetic end choice dismisses locally without fabricating a server reply")
		await receive(ui,{"kind":"dialog-entry","ownerId":43,"speakerId":43,"tokenObjectId":43,"text":{"text":"Another terminal entry"}})
		await receive(ui,{"kind":"dialog-replies","entryId":8,"end":true,"firstCount":0,"secondCount":0,"tokenObjectId":43,"replies":[]}); before=requests.size(); await key(KEY_ESCAPE); await key(KEY_ESCAPE,false)
		check(not dialog.visible and requests.size()==before,"Escape on the synthetic terminal entry also follows the original local-only close")
		var choices: Array=[]
		for at in 40: choices.append({"id":at,"text":{"text":"Long offered choice ".repeat(8)}})
		await receive(ui,{"kind":"dialog-entry","ownerId":43,"speakerId":43,"tokenObjectId":43,"text":{"text":"A long received entry ".repeat(80)}})
		await receive(ui,{"kind":"dialog-replies","entryId":9,"end":false,"firstCount":40,"secondCount":0,"tokenObjectId":43,"replies":choices})
		check(await wait_until(func():return dialog_settled(ui)),"Long original conversation reflows and publishes bounded size artwork")
		check(skin.entry_bar_host.visible and skin.reply_bar_host.visible and dialog.size.y<=901 and skin.geometry.flow.entry_scroll and skin.geometry.flow.reply_scroll,"Long speaker and reply text have separate native scrolling within the available viewport")
		check(skin.reply_bar.plan.attachment.distance_to(skin.geometry.reply_bar.offset+skin.geometry.reply_bar.model.hooks.scrollmin)<0.001,"Resized reply scrollbar stays attached to the current content-dependent reply origin")
		skin.reply_scroll.scroll_vertical=100000; await process_frame; await process_frame; check(skin.reply_scroll.scroll_vertical>0,"Long reply list can scroll beyond its first offered rows")
		await shot(output,"-long")
		var world:=WorldInput.new(); surface.add_child(world); await click(Vector2(1000,500)); await key(KEY_W); await key(KEY_W,false); await click(Vector2(1000,500),MOUSE_BUTTON_MIDDLE); check(world.clicks==1 and world.movement==1 and world.middle==1 and dialog.visible,"Open conversation preserves outside world clicks, WASD and outside middle camera input")
		check(await wait_until(func():return dialog.visible and skin.display_ready()),"Long conversation remains admitted before Escape input")
		before=requests.size(); await key(KEY_ESCAPE); await key(KEY_ESCAPE,false); check(dialog.visible and dialog.pending and requests.size()==before+1 and requests.back().abort,"Escape requests authoritative abort and keeps the dialog until the server responds")
		await receive(ui,{"kind":"dialog-close"}); check(not dialog.visible and dialog.reply_ids.is_empty(),"Server close retires every received reply")
		diagnostic=skin.snapshot(); diagnostic.art_failure=ui.inventory.frame_skin.art.failed.keys(); diagnostic.physicalMouseWarped=false; check(diagnostic.art_failure.is_empty(),"Original conversation resources and poses have no missing-art failures")
	else: check(false,"Native conversation frame activates without fallback")
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"requests":requests,"publicConnections":0,"fullConversationParity":false,"scope":"Original conversation artwork/layout and isolated native ownership/input; original-client comparison, large-font/state variants and authoritative dialogue outcomes checked separately."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
