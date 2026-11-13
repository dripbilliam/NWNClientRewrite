extends "res://tests/native_quickbar_frame_test.gd"
const Details=preload("res://systems/native_data/party_details.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
func policy() -> void:
	var details:=Details.new(); var text:=Talk.new()
	var source:={77:{"id":77,"objectType":5,"areaId":55,"replicated":{"name":{"firstName":{"text":"Two"},"lastName":{"text":"Words"}},"hitPoints":{"current":-3.0,"fieldE8":5.0,"maximum":0.0}}}}
	var module:={"areas":[{"id":55,"name":"Original room"},{"id":56,"name":"Next room"}]}
	details.observe([77],source,text)
	check(details.tooltip(77,module)=="Two Words 2/1\nOriginal room","Original member tooltip uses signed current plus temporary HP, minimum maximum1 and integer formatting")
	source[77].replicated.hitPoints.current=99; details.observe([77],{},text)
	check(details.tooltip(77,module)=="Two Words 2/1\nOriginal room","Received member details are copied and retained when the creature is absent from a new area")
	details.observe([77],{77:{"objectType":5,"replicated":{"areaId":56}}},text)
	check(details.tooltip(77,module)=="Two Words 2/1\nNext room","A partial member update replaces disclosed area without erasing name or HP")
	check(details.tooltip(77,{})=="Two Words 2/1\n","Missing module area name preserves the original empty location line")
	details.observe([],source,text); check(details.tooltip(77,module).is_empty(),"Roster removal retires its disclosed details even if an unrelated object remains")
	details.observe([77,0x7f000000],{},text)
	check(details.tooltip(77,module)==" 0/0\n" and details.tooltip(0x7f000000,module).is_empty(),"Fresh undisclosed member uses original850330 defaults; invalid sentinel never fabricates a member")
	details.reset(); check(details.members.is_empty(),"Closing the details owner clears retained disclosure")
	text.close()
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	policy()
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original installed catalog mounts read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); ui.request.connect(func(message):requests.append(message.duplicate(true)))
	ui.set_gameplay_visible(false)
	check(await wait_until(func():return ui.tables_ready and ui.chat_skin.layout_ready),"Production native chat/resources prepare headlessly through the full gameplay owner")
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Controlled"},"position":[0,0,0],"hitPoints":{"current":10,"maximum":15},"stats":{"classes":[]}}}
	var other:={"id":77,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Other Character"},"position":[1,1,0],"hitPoints":{"current":12,"fieldE8":3,"maximum":18},"portraitRef":"po_clsbard_"}}
	var player:={"name":"Other Account","objectId":77,"character":{"id":177,"firstName":{"text":"Other"},"lastName":{"text":"Character"},"portraitRef":"po_clsbard_"}}
	var header:={"area":{"id":55},"module":{"areas":[{"id":55,"name":"First room"},{"id":56,"name":"Second room"}]},"ui":{"party":[{"id":42},{"id":77}],"players":[[7,player]]}}
	ui.set_world(1,55,42,[actor,other],{},header); ui.set_gameplay_visible(true)
	ui.receive({"kind":"server-speech","channel":1,"objectId":77,"text":{"text":"Retain this received speech"}},1)
	check(await wait_until(func():return ui.chat.rows.size()==1 and not ui.chat_skin.panes[0].replies.is_empty()),"Actual raw server-speech route publishes the retained chat row and portrait")
	var chat=ui.chat; var skin=ui.chat_skin; var serial:=int(chat.rows[0].chat_sequence); var reply: Button=skin.panes[0].replies[serial].button; var identity:=reply.get_instance_id()
	check(reply.get_tooltip()=="Other Character 15/18\nFirst room","Actual chat portrait tooltip resolves live player character through the shared disclosed member cache")
	var count:=requests.size(); await motion(reply.get_global_rect().get_center())
	check(requests.size()==count,"Hovering a disclosed tooltip sends no gameplay request")
	chat.entry.text="Draft survives area loading"; skin.select_mode(3); var sequence: int=chat.sequence
	ui.set_gameplay_visible(false); actor.areaId=56; header.area.id=56
	ui.set_world(2,56,42,[actor],{},header); ui.set_gameplay_visible(true)
	for at in 4: await process_frame
	check(ui.chat==chat and chat.rows.size()==1 and chat.sequence==sequence and chat.entry.text=="Draft survives area loading" and skin.mode==3,"Actual generation/area transition retains received history, sequence, outgoing mode and draft")
	check(skin.panes[0].replies[serial].button.get_instance_id()==identity and skin.panes[0].label.get_parsed_text().contains("Retain this received speech"),"Area transition retains the original portrait widget and displayed history")
	check(reply.get_tooltip()=="Other Character 15/18\nFirst room","Out-of-area party portrait retains its disclosed name/HP/location after the native world changes")
	ui.set_world(2,56,42,[actor,{"id":77,"objectType":5,"replicated":{"areaId":56,"hitPoints":{"current":6,"maximum":18}}}],{},header)
	check(reply.get_tooltip()=="Other Character 6/18\nSecond room","A later partial native update refreshes tooltip health and location without losing name")
	player.objectId=99; player.character.id=77; ui.set_world(2,56,42,[actor],{},header)
	check(reply.get_tooltip().is_empty(),"Tooltip follows the current controlled player object rather than the separate character")
	player.objectId=77; header.ui.party=[{"id":42}]; ui.set_world(2,56,42,[actor,other],{},header)
	check(reply.get_tooltip().is_empty(),"A nonmember player's portrait does not expose world creature health")
	header.ui.party.append({"id":77}); ui.set_world(2,56,42,[actor],{},header)
	check(reply.get_tooltip()==" 0/0\n","Rejoining the roster starts a fresh original UI record without reviving retired disclosure")
	header.ui.players=[]; ui.set_world(2,56,42,[actor],{},header)
	check(reply.get_tooltip().is_empty(),"Departed player cannot retain a tooltip through an old chat row")
	header.ui.players=[[7,player]]; ui.set_world(2,56,42,[actor,other],{},header)
	player.character.id=177; ui.set_world(2,56,42,[actor,other],{},header)
	var retained_rows: int=chat.rows.size(); chat.entry.text='/tp "Other Account" native-route-check'; chat.entry.grab_focus(); await key(KEY_ENTER); await key(KEY_ENTER,false)
	var forwarded_chat: Dictionary=requests.filter(func(message):return message.get("kind","")=="chat")[-1]
	check(forwarded_chat.get("playerId")==7 and forwarded_chat.get("playerAccount")=="Other Account" and forwarded_chat.get("actorId")==42 and forwarded_chat.get("generation")==2 and forwarded_chat.get("areaId")==56 and chat.rows.size()==retained_rows,"Actual entry emits scoped PLAYER_ID/account metadata through the production gameplay controller without echo")
	var forwarded_party: Array=[]
	for command in ['/invite Other Character','/accept']:
		chat.entry.text=command; chat.entry.grab_focus(); await key(KEY_ENTER); await key(KEY_ENTER,false)
		forwarded_party.append(requests.filter(func(message):return message.get("kind","")=="native-chat-party")[-1])
	check(forwarded_party[0].targetId==177 and forwarded_party[1].targetId==0x7f000000 and forwarded_party.all(func(message):return message.actorId==42 and message.generation==2 and message.areaId==56) and header.ui.party==[{"id":42},{"id":77}],"Actual chat Invite/Accept preserve original target namespaces and emit scoped requests without changing party membership")
	var before_feedback: int=chat.rows.size()
	for refusal in [{"actorId":43,"areaId":56},{"actorId":42,"areaId":55}]:
		ui.receive({"kind":"native-action-result","action":"native-chat-party","actorId":refusal.actorId,"areaId":refusal.areaId,"accepted":false,"text":"Stale refusal"},2)
	ui.receive({"kind":"native-action-result","action":"native-chat","actorId":42,"areaId":56,"accepted":true},2)
	check(chat.rows.size()==before_feedback,"Stale transport refusals and successful sends cannot add chat or predict server feedback")
	ui.receive({"kind":"native-action-result","action":"native-chat-party","actorId":42,"areaId":56,"accepted":false,"text":"Owned transport refusal"},2)
	check(chat.rows.size()==before_feedback+1 and chat.rows.back().text=="Owned transport refusal" and header.ui.party==[{"id":42},{"id":77}],"Current transport refusal is visible without changing received party state")
	ui.set_gameplay_visible(false)
	check(reply.get_tooltip().is_empty(),"Hidden loading/pregame chat cannot show an old portrait tooltip")
	ui.set_gameplay_visible(true); var old_provider: Callable=reply.tooltip_provider; count=requests.size(); ui.close()
	check(reply.get_tooltip().is_empty() and str(old_provider.call()).is_empty() and ui.desktop.party_details.members.is_empty() and requests.size()==count,"Closing gameplay immediately retires tooltip callbacks, retained disclosure and input")
	ui.free(); await process_frame
	var next:=Gameplay.new(); surface.add_child(next); next.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); next.set_gameplay_visible(false)
	check(next.chat.rows.is_empty() and next.desktop.party_details.members.is_empty(),"A new connection's gameplay owner cannot inherit a different profile's messages or member details")
	next.close(); next.free(); surface.free(); catalog=null; await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"forwardedChat":forwarded_chat,"forwardedParty":forwarded_party,"publicConnections":0,"graphical":false,"scope":"Original disclosed party tooltip fields/defaults and actual gameplay chat across generation/area hide-show, partial received data, membership/player changes, outgoing chat/party controller route and owner retirement. Full disconnect-history parity, original pixels and authoritative local-server acceptance remain open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
