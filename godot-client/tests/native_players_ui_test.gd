extends "res://tests/native_quickbar_frame_test.gd"
func ack(desktop,message: Dictionary,accepted: bool,text: String="") -> void:
	desktop.receive({"kind":"native-action-result","action":message.kind,"operation":message.get("operation",""),"requestId":message.requestId,"generation":message.generation,"areaId":message.areaId,"actorId":message.actorId,"accepted":accepted,"text":text,"result":{"sent":accepted,"serverAcknowledged":false}})
func players_settled(ui) -> bool:
	var skin=ui.desktop.players_frame
	return skin.layout_ready and skin.popup.layout_ready and skin.jobs.is_empty() and skin.failure.is_empty() and skin.bar.art_ready and settled(ui)
func type_text(value: String) -> void:
	for letter in value:
		var event:=InputEventKey.new(); event.keycode=letter.to_upper().unicode_at(0); event.unicode=letter.unicode_at(0); event.pressed=true; surface.push_input(event,true); await process_frame; event=event.duplicate(); event.pressed=false; surface.push_input(event,true); await process_frame

func present_invite(ui, actor_id: int, inviter: int, notice: int) -> bool:
	var actor := {"id":actor_id,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Tester"},"position":[5,5,0],"hitPoints":{"current":10,"maximum":10},"stats":{"racialType":6,"classes":[{"id":10,"level":1}]},"party":{"singleton":1,"leader":1,"field7DC":1,"field7D8":inviter}}}
	var header := {"area":{"pvp":1},"ui":{"partyInviteNotice":{"serial":notice,"name":"Inviter " + str(inviter)}}}
	ui.set_world(1,55,actor_id,[actor],{},header)
	var skin = ui.desktop.players_frame
	var popup = skin.popup
	var deadline := Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < deadline and skin.failure.is_empty():
		await process_frame
		if popup.layout_ready and popup.panel.is_visible_in_tree() and popup.state == {"scope":[1,55,actor_id],"inviter":inviter,"notice":notice}:
			return true
	return false

func invitation_replies() -> Array:
	return requests.filter(func(row): return row.kind == "native-party" and row.operation in ["accept","reject","ignore"])

func own_invitation_reply(rows: Array, operation: String, actor_id: int, inviter: int) -> bool:
	return rows.size() == 1 and rows[0].operation == operation and int(rows[0].actorId) == actor_id and int(rows[0].targetId) == inviter and int(rows[0].generation) == 1 and int(rows[0].areaId) == 55

func replace_invite_while_held(ui, previous_actor: int, next_actor: int, notice: int) -> Dictionary:
	var popup = ui.desktop.players_frame.popup
	var admitted := await present_invite(ui,previous_actor,84,notice)
	check(admitted,"Original invitation is visible before the gesture")
	if not admitted:
		return {"failure":ui.desktop.players_frame.failure,"popup":popup.snapshot()}
	var button: Button = popup.buttons.rejectbutton
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	await motion(point)
	check(surface.gui_get_hovered_control() == button,"Pointer hits the actual Reject control")
	var before := invitation_replies().size()
	await mouse(point,true)
	check(button.button_pressed and invitation_replies().size() == before,"Old Reject is held without sending a request")
	var replacement := await present_invite(ui,next_actor,85,notice+1)
	check(replacement and popup.buttons.rejectbutton == button,"The replacement invitation reuses the same popup control")
	var next_point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	await motion(next_point,next_point-point,true)
	await mouse(next_point,false)
	var stale := invitation_replies().slice(before)
	check(stale.is_empty(),"Release of a retired invitation press sends no request")
	if not stale.is_empty():
		ack(ui.desktop,stale[0],false,"Fixture restores controls for the fresh gesture")
	var before_fresh := invitation_replies().size()
	await click(next_point)
	var fresh := invitation_replies().slice(before_fresh)
	check(own_invitation_reply(fresh,"reject",next_actor,85),"Fresh Reject sends exactly the current inviter and controlled actor")
	if not fresh.is_empty():
		ack(ui.desktop,fresh[0],true)
	return {"stale":stale,"fresh":fresh}

func verify_invitation_controls(ui) -> Dictionary:
	var popup = ui.desktop.players_frame.popup
	var admitted := await present_invite(ui,43,87,6)
	check(admitted,"Same-notice scope presents a current invitation")
	if not admitted:
		return {"popup":popup.snapshot()}
	var button: Button = popup.buttons.rejectbutton
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	await motion(point)
	var before := invitation_replies().size()
	await mouse(point,true)
	check(await present_invite(ui,43,87,6),"Repeated snapshot retains the same invitation")
	await mouse(point,false)
	var repeated := invitation_replies().slice(before)
	check(own_invitation_reply(repeated,"reject",43,87),"Refreshing the same notice preserves a held Reject")
	check(await present_invite(ui,43,88,7),"Fresh Accept has its own admitted invitation")
	before = invitation_replies().size()
	await click(popup.buttons.okbutton.get_global_rect().get_center())
	var accepted := invitation_replies().slice(before)
	check(own_invitation_reply(accepted,"accept",43,88),"Fresh Accept responds once to its current inviter")
	check(await present_invite(ui,43,89,8),"Fresh Escape has its own admitted invitation")
	before = invitation_replies().size()
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE,false)
	var ignored := invitation_replies().slice(before)
	check(own_invitation_reply(ignored,"ignore",43,89),"Escape keeps the popup's distinct Ignore operation")
	return {"sameNotice":repeated,"accept":accepted,"escape":ignored}

func run_invitation_lifetime(ui, output: String) -> void:
	var replacement := await replace_invite_while_held(ui,42,42,1)
	var control_change := await replace_invite_while_held(ui,42,43,3)
	var current_controls := await verify_invitation_controls(ui)
	ui.close()
	ui.free()
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"success":failures.is_empty(),"replacement":replacement,"controlChange":control_change,"currentControls":current_controls,"scope":"Installed native invitation controls and standalone SubViewport input, with authored received actor and invite notices. No graphical client or server session."},"  "))
	file.close()
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var invitation_lifetime := OS.get_cmdline_user_args().has("--invitation-lifetime")
	root.size=Vector2i(1200,900); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED if invitation_lifetime else SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	if not invitation_lifetime:
		var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original player-window resources mount read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); ui.request.connect(func(message):requests.append(message.duplicate(true)))
	if invitation_lifetime:
		await run_invitation_lifetime(ui,output)
		return
	check(await wait_until(func():return ui.tables_ready),"Active player-window rules and original text prepare")
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Player Tester"},"position":[5,5,0],"hitPoints":{"current":10,"maximum":10},"stats":{"racialType":6,"classes":[{"id":10,"level":1}]},"party":{"singleton":1,"leader":1,"field7DC":0}}}
	var objects: Array=[actor,{"id":84,"objectType":5,"areaId":55,"replicated":{"reaction":1}},{"id":85,"objectType":5,"areaId":55,"replicated":{"reaction":2}}]
	objects.append({"id":86,"objectType":5,"areaId":56,"replicated":{"reaction":2}}); objects.append({"id":87,"objectType":5,"areaId":55,"replicationRemoved":true,"replicated":{"reaction":0}})
	var players: Array=[[1,{"playerId":1,"objectId":42,"isDM":0,"name":"Own account","character":{"id":42,"firstName":{"text":"Player"},"lastName":{"text":"Tester"}}}],[99,{"playerId":99,"objectId":500,"isDM":1,"name":"DM account","character":{"id":600,"firstName":{"text":"Hidden DM"}}}]]
	for index in 14: players.append([7+index,{"playerId":7+index,"objectId":84+index,"isDM":0,"name":"Account "+str(index),"character":{"id":184+index,"firstName":{"text":"Citizen"},"lastName":{"text":str(index)}}}])
	var header:={"area":{"pvp":1},"ui":{"players":players,"party":[],"playerAttitudes":[],"partyListRevision":1}}; var original:=header.duplicate(true); var actor_original:=actor.duplicate(true)
	ui.set_world(1,55,42,objects,{},header); var desktop=ui.desktop; var panel=desktop.players; var skin=desktop.players_frame; check(skin.requested.has("pnl_ig_pvp"),"Original player models schedule during desktop setup before first open")
	desktop.panel("pvp"); var diagnostic: Dictionary={}
	var prepared: bool=await wait_until(func():return players_settled(ui)); check(prepared,"Original player frame, rows, icons, fonts, source scrollbar and invitation controls publish")
	if prepared:
		check(panel.size.distance_to(Vector2(360,461))<0.001 and not panel.window_column.visible and skin.cards.size()==14,"Source360x461 player window replaces generic rows and excludes own/DM entries")
		check(skin.selected==13 and not skin.buttons.bootbutton.visible and not skin.buttons.banbutton.visible,"Original initial last-row selection and unprivileged admin visibility are retained")
		check(panel.rows[2].reaction==255 and panel.rows[3].reaction==255 and skin.cards[9].reaction.text==ui.text.raw({"strRef":0x1076b}),"Retained other-area and removed creature proxies cannot disclose a stale reaction instead of Elsewhere")
		check(skin.scroll.get_v_scroll_bar().max_value>skin.scroll.get_v_scroll_bar().page and skin.cards[7].button.size.distance_to(Vector2(335,29))<0.01,"Original29px rows and linked spacing overflow through the native scrollbar")
		await shot(output,"-normal"); await click(skin.cards[7].button.get_global_rect().get_center()); var selection: Dictionary=requests.back()
		check(selection.kind=="native-players" and selection.operation=="select" and selection.playerId==7 and selection.targetId==184 and skin.selected==0,"Actual player-row selection sends original GUI selection with original character target identity")
		ack(desktop,selection,true); check(skin.pending.is_empty(),"Selection transport completion releases only its own native request")
		await click(skin.buttons.invitebutton.get_global_rect().get_center()); var invite: Dictionary=requests.back()
		check(invite.kind=="native-party" and invite.operation=="invite" and invite.targetId==184 and skin.buttons.invitebutton.disabled,"Actual original Invite button emits its received target and owns pending transport")
		var wrong:=invite.duplicate(); wrong.requestId+=100; ack(desktop,wrong,true); check(not skin.pending.is_empty(),"Unrelated transport results cannot release the player action")
		ack(desktop,invite,false,"Owned player refusal"); check(skin.pending.is_empty() and skin.help_label.text=="Owned player refusal" and header==original,"A refusal preserves original controls, visible feedback and received party state")
		await click(skin.buttons.tellbutton.get_global_rect().get_center()); var tell: Dictionary=requests.filter(func(row):return row.get("kind","")=="native-players")[-1]
		check(tell.kind=="native-players" and tell.operation=="tell" and tell.targetId==84 and ui.chat.entry.has_focus() and ui.chat.entry.text=='/t "Citizen 0" ',"Original Tell action uses the controlled target and primes the original full character name")
		ack(desktop,tell,true); await type_text("Hello there"); await key(KEY_ENTER); await key(KEY_ENTER,false)
		check(requests.back().kind=="chat" and requests.back().channel==4 and requests.back().playerId==7 and requests.back().playerAccount=="Account 0" and requests.back().text=="Hello there","Typing into primed account Tell submits the actual PLAYER_ID and message without the visible command prefix")
		var before: int=requests.size(); await click(skin.cards[7].attitude.get_global_rect().get_center())
		check(requests.size()==before+2 and requests.back().kind=="native-player-attitude" and requests.back().playerId==7 and not requests.back().likes,"Original nested attitude checkbox selects the correct row and emits its own preference change")
		for message in requests.slice(before): ack(desktop,message,true)
		check(not skin.cards[7].attitude.button_pressed,"A sent attitude request never overwrites received checkbox state")
		var updated:=header.duplicate(true); updated.ui.playerAttitudes=[[7,{"ownLikes":0,"incomingLikes":0}]]; ui.set_world(1,55,42,objects,{},updated)
		check(await wait_until(func():return skin.cards[7].attitude.button_pressed and ui.inventory.frame_skin.button_geometry[skin.cards[7].button.get_instance_id()].overrides.gui_replace01=="gui_ig_madface"),"Received local and incoming attitudes drive separate original checkbox and face artwork")
		await motion(skin.cards[7].attitude.get_global_rect().get_center()); await wait_until(func():return players_settled(ui))
		check(ui.inventory.frame_skin.button_geometry[skin.cards[7].attitude.get_instance_id()].styles.hover_checked[1]=="checkedhilite","An original checked attitude hover uses its authored checkedhilite clip")
		await wait_until(func():return players_settled(ui)); await shot(output,"-attitude")
		var grouped:=actor.duplicate(true); grouped.replicated.party.singleton=0; updated.ui.party=[{"id":184,"stale":false}]; ui.set_world(1,55,42,[grouped,objects[1],objects[2]],{},updated)
		check(await wait_until(func():return skin.cards[7].attitude.disabled and not skin.buttons.transferbutton.disabled),"Received group membership disables hostility changes and enables original leader controls")
		var delayed:=grouped.duplicate(true); delayed.replicated.party.singleton=1; ui.set_world(1,55,42,[delayed,objects[1],objects[2]],{},updated)
		check(await wait_until(func():return not skin.buttons.leavebutton.disabled),"Original party-list membership keeps Leave available while separate creature flags are delayed")
		await click(skin.buttons.leavebutton.get_global_rect().get_center()); var leave: Dictionary=requests.back()
		check(leave.kind=="native-party" and leave.operation=="leave" and leave.playerId==7 and leave.targetId==184,"Actual Leave click retains the original selected character identity without predicting group removal")
		ack(desktop,leave,true); check(panel.rows[0].member and skin.pending.is_empty(),"Leave transport success keeps membership until authoritative replication changes it")
		ui.set_world(1,55,42,[grouped,objects[1],objects[2]],{},updated); await process_frame
		await click(skin.buttons.transferbutton.get_global_rect().get_center()); var transfer: Dictionary=requests.back(); check(transfer.kind=="native-party" and transfer.operation=="transfer" and transfer.targetId==184,"Actual Transfer control emits the authoritative member target")
		ack(desktop,transfer,true); grouped=grouped.duplicate(true); grouped.replicated.party.leader=0; ui.set_world(1,55,42,[grouped,objects[1],objects[2]],{},updated)
		check(await wait_until(func():return skin.buttons.transferbutton.disabled and skin.buttons.invitebutton.disabled and not skin.buttons.leavebutton.disabled),"Received loss of leadership disables Kick/Transfer while retaining Leave")
		await shot(output,"-member")
		grouped=grouped.duplicate(true); grouped.replicated.party.field7DC=1; grouped.replicated.party.field7D8=84; updated.ui.partyInviteNotice={"serial":1,"name":"Arch Druid"}; ui.set_world(1,55,42,[grouped,objects[1],objects[2]],{},updated)
		check(await wait_until(func():return skin.popup.panel.visible and skin.popup.body.get_parsed_text().contains("Arch Druid")),"A received invitation opens its separate original popup with the server-provided inviter token")
		check(ui.blocks_pointer(skin.popup.panel.get_global_rect().get_center()) and ui.inventory.frame_skin.button_geometry[skin.buttons.invitebutton.get_instance_id()].overrides.gui_replace01=="ir_accept","Invitation mode uses the source popup hit region and original Accept toolbar artwork")
		check(is_instance_valid(skin.popup.checkbox_label) and skin.popup.checkbox_label.text==ui.text.raw({"strRef":66777}) and skin.popup.checkbox_label.position.x>skin.popup.check_button.position.x,"The original preference caption is bound from its actual nested checkbox GUI node")
		await shot(output,"-invitation"); await click(skin.popup.buttons.rejectbutton.get_global_rect().get_center()); var rejection: Dictionary=requests.back()
		check(rejection.operation=="reject" and rejection.targetId==84 and skin.popup.buttons.okbutton.disabled,"Original invitation Reject emits the current inviter and holds its pending controls")
		ack(desktop,rejection,true); check(not skin.popup.panel.visible and grouped.replicated.party.field7DC==1,"Transport completion closes the source popup without fabricating an invitation-state update")
		updated=updated.duplicate(true); updated.ui.partyInviteNotice.serial=2; ui.set_world(1,55,42,[grouped,objects[1],objects[2]],{},updated); await wait_until(func():return skin.popup.panel.visible)
		await click(skin.popup.check_button.get_global_rect().get_center()); var config:=ConfigFile.new(); config.load(output+".layout.cfg"); check(not skin.popup.enabled and not bool(config.get_value("ui","party_invite_popup",true)),"Original Disable popup checkbox changes persistent local presentation preference without a server command")
		await click(skin.popup.buttons.cancelbutton.get_global_rect().get_center()); var ignore: Dictionary=requests.back(); check(ignore.operation=="ignore" and ignore.targetId==84,"Original invitation Cancel has its distinct Ignore action")
		ack(desktop,ignore,false,"Invitation reply refused"); check(skin.popup.panel.visible and not skin.popup.buttons.okbutton.disabled,"A refused invitation reply leaves its source popup available")
		await click(skin.popup.buttons.cancelbutton.get_global_rect().get_center()); ack(desktop,requests.back(),true); skin.popup.set_enabled(true)
		grouped=grouped.duplicate(true); grouped.replicated.party.field7DC=0; ui.set_world(1,55,42,[grouped,objects[1],objects[2]],{},updated); await process_frame
		var old_card: Dictionary=skin.cards[7]; var saved_position: Vector2=panel.position; var title_point: Vector2=panel.get_global_transform()*Vector2(40,8)
		await motion(title_point); await mouse(title_point,true); await motion(title_point+Vector2(30,20),Vector2(30,20),true); await mouse(title_point+Vector2(30,20),false)
		check(panel.position.distance_to(saved_position+Vector2(30,20))<0.01,"Source player title supports retained native window dragging")
		ui.controls.scale=Vector2.ONE*1.25; await process_frame; check(absf(panel.get_global_rect().size.x-450)<0.01,"125percent UI scale retains original player-frame proportions"); await shot(output,"-scaled"); ui.controls.scale=Vector2.ONE
		await click(panel.close_button.get_global_rect().get_center()); before=requests.size(); check(not panel.visible and not skin.valid_card(old_card),"Original player close retires its rendered row identities")
		desktop.panel("pvp"); check(panel.position.distance_to(saved_position+Vector2(30,20))<0.01 and not skin.valid_card(old_card) and requests.size()==before,"Reopened player window retains placement and cannot reuse old row callbacks")
		var world:=WorldInput.new(); surface.add_child(world); await click(Vector2(1100,500)); await key(KEY_W); await key(KEY_W,false); await click(Vector2(1100,500),MOUSE_BUTTON_MIDDLE); check(world.clicks==1 and world.movement==1 and world.middle==1,"Player windows preserve outside click movement, WASD and middle-camera input")
		check(header==original and actor==actor_original,"Native player use never mutates caller-owned received header or actor data")
		var held: Vector2=skin.buttons.leavebutton.get_global_rect().get_center(); await motion(held); await mouse(held,true); var packet_count:=requests.size(); var retired:=updated.duplicate(true); retired.ui.players=players.slice(0,2); ui.set_world(1,55,42,[grouped,objects[1],objects[2]],{},retired); await process_frame; await process_frame; await mouse(held,false)
		check(skin.cards.is_empty() and requests.size()==packet_count,"Removing a selected player while holding a source action cannot retarget its released click")
		ui.set_world(2,55,42,[grouped,objects[1],objects[2]],{},updated); ack(desktop,invite,false,"Retired result"); check(skin.pending.is_empty() and not panel.wanted and not skin.popup.panel.visible,"Changed world scope retires player/popup actions and ignores old results")
		diagnostic=skin.snapshot(); diagnostic.physicalMouseWarped=false; diagnostic.art_failures=ui.inventory.frame_skin.art.failed.keys()+desktop.art.failed.keys(); check(diagnostic.art_failures.is_empty(),"Original player and invitation art has no missing-resource failures")
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"requests":requests,"publicConnections":0,"fullPlayersParity":false,"scope":"Original-resource native player/invitation input and projection only. Real local-server control outcomes, administrator/role variants and direct original-client visual/gesture comparison remain separate gates."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
