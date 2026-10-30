extends "res://tests/native_quickbar_frame_test.gd"
var option_clicks:=0
func settled_party(ui) -> bool:
	if not settled(ui): return false
	for card in ui.desktop.party.cards.values():
		if card.has_node("Box/NativeHealth"):
			var status=card.get_node("Box/NativeHealth")
			if not status.pending.is_empty() or status.desired>=0 and (not is_equal_approx(status.desired,status.published) or status.desired_clip!=status.published_clip): return false
	var bar=ui.desktop.party_frame.member_bar
	return not is_instance_valid(bar) or bar.art_ready and not bar.snapshot().layout_pending and not bar.snapshot().thumb_pending
func variants_checks(_ui,_output: String,_actor: Dictionary,_objects: Array,_members: Array) -> Dictionary: return {}
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,800); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original party HUD resources mount read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); ui.request.connect(func(m):requests.append(m.duplicate(true))); ui.options_requested.connect(func():option_clicks+=1)
	check(await wait_until(func():return ui.tables_ready and ui.inventory.frame_skin.fonts!=null),"Active original HUD rule and font owners prepare")
	var desktop=ui.desktop; var rail=desktop.party; var skin=desktop.party_frame
	check(not skin.requested and skin.jobs.is_empty(),"Disconnected party HUD schedules no model preparation")
	var portrait:=-1
	for id in ui.text.tables.portraits.orderedRows.size():
		var ref: String=str(desktop.rules.cell(desktop.rules.row("portraits",id),"BaseResRef",""))
		if not ref.is_empty() and ref!="****" and not catalog.raster_location("po_"+ref+"m").is_empty(): portrait=id; break
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"HUD player"},"portrait":portrait,"position":[0,0,0],"hitPoints":{"current":100,"maximum":100},"stats":{"racialType":6,"classes":[{"id":10,"level":3}]}},"playerState":{"abilities":{"base":[10,12,10,16,11,8],"current":[10,12,10,16,11,8]},"combat":{"armorClass":12,"canLevelUp":false},"feats":[0]}}
	var other: Dictionary=actor.duplicate(true); other.id=43; other.replicated.name={"text":"HUD member"}; other.replicated.hitPoints={"current":50,"maximum":100}; other.erase("playerState")
	var unknown: Dictionary=other.duplicate(true); unknown.id=44; unknown.replicated.name={"text":"Undisclosed"}; unknown.replicated.erase("hitPoints")
	var objects: Array=[actor,other,unknown]; var members: Array=[43,44,45]
	ui.set_world(1,55,42,objects,{},{"area":{"id":55},"ui":{"party":members}})
	check(await wait_until(func():return skin.layout_ready or not skin.failure.is_empty()),"Original party/member/health/action models finish bounded preparation")
	var diagnostic: Dictionary={"failure":skin.failure}
	if skin.layout_ready and skin.failure.is_empty():
		check(await wait_until(func():return settled_party(ui)),"Original HUD poses, percentages, member scrollbar and fonts publish")
		var own: Control=rail.cards[0]; var self_button: Button=own.get_node("Box/Portrait"); var hp=own.get_node("Box/NativeHealth")
		check(rail.position==Vector2(1120,0) and self_button.position.distance_to(Vector2(12,4))<0.001 and self_button.size==Vector2(64,100),"Original rightmost80px anchor and64x100 self portrait replace generic margins")
		check(not own.get_node("Box/Health").visible and not own.get_node("Box/Name").visible and hp.published==100,"HUD uses original vertical health and native portrait tooltip rather than generic horizontal rows")
		check(hp.picture.position.distance_to(Vector2(3,3))<0.01 and hp.picture.size.distance_to(Vector2(7,100))<0.01,"Full original health mesh retains7x100 footprint and Health attachment")
		check(own.get_parent()==skin.stage and rail.cards[1].get_parent()==rail.column and rail.column.get_child_count()==3,"Self HUD stays fixed outside the separate party member list")
		check(rail.cards[1].get_node("Box/Portrait").position.distance_to(Vector2(6,3))<0.001 and rail.cards[1].get_node("Box/Portrait").size==Vector2(31,50),"Member portrait uses original31x50 frame and attachment")
		check(not rail.cards[2].get_node("Box/NativeHealth").visible and rail.cards[3].get_node("Box/Portrait").disabled,"Unknown HP remains undisclosed and unavailable membership remains disabled")
		check(rail.cards[1].get_node("Box/Name").get_meta("native_font_applied","")=="ttf fnt_default 14" and rail.cards[1].get_node("Box/Name").get_theme_color("font_color")==Color(0.8,0.8,0.8),"Member name uses original default font and grey color")
		var member_name: Label=rail.cards[1].get_node("Box/Name")
		check(member_name.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT and member_name.size.x==62 and absf(member_name.position.y+member_name.size.y-69)<0.001,"Member text uses original left/bottom attachment and62px width rather than the background plane as a text box")
		var expected:=[Vector2(4,109),Vector2(40,109),Vector2(4,127),Vector2(40,127),Vector2(4,145),Vector2(40,145),Vector2(4,163),Vector2(40,163)]
		for at in 8: check(rail.action_buttons[at].position.distance_to(expected[at])<1.01 and rail.action_buttons[at].size.distance_to(Vector2(35,17))<1.5,"HUD action%d retains original model hook and artwork proportions"%at)
		await shot(output,"-normal")
		await click(self_button.get_global_rect().get_center()); check(desktop.sheet.wanted and requests.any(func(m):return m.kind=="native-panel" and m.panel=="character" and m.open),"Portrait click keeps the native character record subscription")
		desktop.sheet.close_sheet()
		await click(rail.cards[1].get_node("Box/Portrait").get_global_rect().get_center()); check(requests.back().kind=="examine" and int(requests.back().targetId)==43,"Member portrait click requests the received member's real examination")
		await click(self_button.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT); check(desktop.radial.active and desktop.radial_target==42,"Native portrait right-click opens the received creature's actual radial")
		desktop.radial.reset()
		await click(rail.action_buttons[0].get_global_rect().get_center()); check(desktop.area_map.wanted,"Original Map art invokes live native map action"); desktop.area_map.close_map()
		await click(rail.action_buttons[1].get_global_rect().get_center()); check(ui.inventory.ui.wanted,"Original Inventory art opens the actual native inventory"); ui.inventory.ui.close_inventory()
		await click(rail.action_buttons[2].get_global_rect().get_center()); check(desktop.journal.wanted,"Original Journal art invokes live journal action"); desktop.journal.close_journal()
		await click(rail.action_buttons[3].get_global_rect().get_center()); check(desktop.sheet.wanted,"Original Character art invokes the live record action"); desktop.sheet.close_sheet()
		await click(rail.action_buttons[4].get_global_rect().get_center()); check(requests.back().kind=="native-rest","Original Rest art sends the original-compatible rest request")
		await click(rail.action_buttons[5].get_global_rect().get_center()); check(desktop.book.wanted,"Original Spellbook art invokes the live spellbook action"); desktop.book.wanted=false; desktop.book.hide()
		await click(rail.action_buttons[6].get_global_rect().get_center()); check(option_clicks==1,"Original Options art forwards to the real settings flow")
		await click(rail.action_buttons[7].get_global_rect().get_center()); check(desktop.players.wanted,"Original PvP art invokes the live player-attitude interface"); desktop.players.close_players()
		var identity: int=self_button.get_instance_id(); actor.replicated.hitPoints.current=25; ui.set_world(1,55,42,objects,{},{"area":{"id":55},"ui":{"party":members}})
		check(await wait_until(func():return settled_party(ui)) and self_button.get_instance_id()==identity and hp.published==25,"Received HP updates native percentage without replacing a pressed portrait")
		check(hp.picture.size.y>=25 and hp.picture.size.y<=27 and hp.picture.size.x==7,"Quarter health samples original vertices instead of shrinking the whole100px image")
		await shot(output,"-quarter")
		var original_requests: int=hp.requests
		for at in 64: hp.set_health({"current":at,"maximum":100})
		await wait_until(func():return hp.requests>original_requests); var queued: int=hp.requests-original_requests
		check(queued==1 and await wait_until(func():return settled_party(ui)) and hp.published==63,"A64-update HP burst coalesces to the latest original pose with one request")
		actor.playerState.combat.canLevelUp=true; ui.set_world(1,55,42,objects,{},{"area":{"id":55},"ui":{"party":members}}); await process_frame; await process_frame
		var level: Button=own.get_node("Box/Level"); check(level.visible and level.position.distance_to(Vector2(10,0))<1.01 and level.size.distance_to(Vector2(69,106))<1.5,"Received level-up availability uses original portrait overlay geometry")
		await click(level.get_global_rect().get_center()); check(desktop.level_up.wanted and requests.any(func(m):return m.kind=="native-level-up" and m.operation=="begin"),"Original level-up portrait overlay enters real server-authoritative level-up flow")
		desktop.level_up.reset(); actor.playerState.combat.canLevelUp=false
		await shot(output,"-level-overlay")
		var variants: Dictionary=await variants_checks(ui,output,actor,objects,members)
		var roster: Array=[]
		for at in 24:
			var member: Dictionary=other.duplicate(true); member.id=100+at; member.replicated.name={"text":"Member%d"%at}; member.replicated.hitPoints={"current":50,"maximum":100}; objects.append(member); roster.append(member.id)
		ui.set_world(1,55,42,objects,{},{"area":{"id":55},"ui":{"party":roster}})
		check(await wait_until(func():return rail.cards.size()==25 and rail.scroll.get_v_scroll_bar().max_value>rail.scroll.size.y and settled_party(ui)),"Larger received roster publishes original linked row and scrollbar geometry")
		var before: Vector2=self_button.get_global_rect().position; rail.scroll.scroll_vertical=100000; await process_frame; await process_frame
		check(self_button.get_global_rect().position==before and rail.scroll.scroll_vertical>0,"Scrolling a large roster leaves the controlled portrait/actions fixed")
		var last: Button=rail.cards[24].get_node("Box/Portrait"); check(rail.blocks_pointer(last.get_global_rect().get_center()),"Visible final party member participates in actual HUD pointer picking")
		await click(last.get_global_rect().get_center()); check(requests.back().kind=="examine" and int(requests.back().targetId)==123,"Scrolled original member portrait retains its server object identity")
		await shot(output,"-roster")
		ui.controls.scale=Vector2.ONE*1.25; rail.place(); await process_frame
		check(absf(rail.get_global_rect().end.x-1200)<0.01 and self_button.get_global_rect().size==Vector2(80,125),"125percent scale retains right anchoring and portrait aspect")
		await shot(output,"-scaled"); ui.controls.scale=Vector2.ONE; rail.place()
		var world:=WorldInput.new(); surface.add_child(world); await click(Vector2(900,450)); await key(KEY_W); await key(KEY_W,false); await click(Vector2(900,450),MOUSE_BUTTON_MIDDLE)
		check(world.clicks==1 and world.movement==1 and world.middle==1,"Outside HUD clicks, WASD and middle mouse still reach world input with the party roster open")
		var stale: Button=rail.action_buttons[4]; var old_portrait: Button=self_button; rail.reset(); var sent: int=requests.size(); stale.pressed.emit(); old_portrait.pressed.emit()
		check(requests.size()==sent and rail.cards.is_empty() and not rail.visible and not is_instance_valid(skin.member_bar),"Disconnect retires native scrollbar and rejects retained portrait/action callbacks")
		diagnostic=skin.snapshot(); diagnostic.physicalMouseWarped=false; diagnostic.coalesced_requests=queued; diagnostic.art_failure=ui.inventory.frame_skin.art.failed.keys(); diagnostic.metadata_members=24; diagnostic.variants=variants
	else: check(false,"Original HUD frame activates without generic fallback")
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"requests":requests,"publicConnections":0,"fullPartyParity":false,"scope":"Original HUD/frame/health geometry and isolated native UI input. Full state/associate/DM variants, name-fit/localization, locator/state/leader indicators and original-client comparison remain open; authoritative server actions tested separately."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
