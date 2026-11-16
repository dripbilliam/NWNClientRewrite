extends "res://tests/native_gui_panel_access_source_test.gd"
# Original-format wire packets through the production Godot session and the
# existing GameplayUI/Desktop access adapter. The inherited test also proves
# physical J/C input and source-sized native Journal controls.
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func close()->void:pass

func packet(rows: Array,name: String)->PackedByteArray:
	for row in rows:
		if str(row.get("name",""))==name:return str(row.packet).hex_decode()
	return PackedByteArray()

func run()->void:
	var options: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	if not options.has_all(["report","install","fixture"]) or FileAccess.file_exists(options.report):quit(2);return
	var source_diagnostic: Dictionary=await exercise_access(options)
	var route_diagnostic: Dictionary=exercise_route()
	if is_instance_valid(ui):ui.close();ui.free()
	if is_instance_valid(painter):painter.close()
	check(is_instance_valid(art) and art.closed and is_instance_valid(fonts) and fonts.closed,"Controlled raster/font owners complete close lifecycle")
	if is_instance_valid(surface):surface.free()
	await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"source":source_diagnostic,"route":route_diagnostic,"headless":true,"gpu":false,"serverConnections":0,"scope":"Original-format 53/2+36/4 bytes through NativeNetworkSession._process, actual GameplayUI receive and Desktop controls. Static original-JS producer oracle, controlled rasters/fonts, installed Journal models. No live server/pixel acceptance."}
	var file:=FileAccess.open(options.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print("NWN79_GUI_ACCESS_VERTICAL_RESULT ",JSON.stringify(result));quit(0 if result.success else 1)

func exercise_route()->Dictionary:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_gui_access_fixture.json"))
	if not check(fixture is Dictionary and fixture.get("cases") is Array,"Original-format GUI packet fixture exists"):return {}
	var rows: Array=fixture.cases
	var journal_off:=packet(rows,"disabled-35-6-1-2130706432")
	var journal_on:=packet(rows,"disabled-35-6-0-2130706432")
	var character_off:=packet(rows,"disabled-35-8-1-42")
	var journal_popup:=packet(rows,"popup-6")
	if not check(not journal_off.is_empty() and not journal_on.is_empty() and not character_off.is_empty() and not journal_popup.is_empty(),"Original-format panel packets cover target and popup"):return {}
	var desktop: Node=ui.desktop
	for node in [desktop.journal,desktop.players,desktop.book,desktop.sheet]:node.reset()
	ui.gui_panel_access.free()
	ui.gui_panel_access=Access.new();ui.add_child(ui.gui_panel_access);ui.gui_panel_access.configure(ui)
	var actor_id:=0x8000002a # Original client object-ID writer sets the server namespace bit.
	ui.generation=1;ui.area_id=9;ui.controlled_id=actor_id;ui.tables_ready=true;ui.hud_ready=true;ui.tlk_jobs.clear()
	var actor: Dictionary={"id":actor_id,"areaId":9,"objectType":5,"nativeLifetime":3,"clientKnownLifetime":3,"replicated":{"name":{"text":"Access fixture"}}}
	ui.text.objects={actor_id:actor};desktop.actor_id=actor_id;desktop.area_id=9;desktop.generation=1;desktop.objects={actor_id:actor};desktop.state={"journal":{"entries":[],"worldEntries":[],"loaded":true},"module":{"minutesPerHour":5}}
	var session=Session.new();root.add_child(session)
	var peer=FakePeer.new();session.peer=peer;session.phase="playing";session.remote_build={"number":8193,"revision":35,"postfix":0};session.area_generation=1
	session.world_state.area_id=9;session.world_state.area={"id":9};session.world_state.module={"name":"fixture"};session.world_state.local_object_id=actor_id;session.world_state.registry[actor_id]=actor.duplicate(true)
	var delivered: Array=[]
	session.ui_message_ready.connect(func(message: Dictionary):
		delivered.append(message.duplicate(true))
		ui.receive(message,ui.generation))
	var first: Dictionary=session.presentation(true)
	check(not first.has("error") and first.ui.has("guiPanelAccess"),"Session initial presentation carries GUI access header")
	ui.gui_panel_access.observe_header(first.get("ui",{}).get("guiPanelAccess"))
	peer.payloads=[journal_off,character_off];session._process(0.0)
	check(delivered.size()==2 and delivered[0].event.sequence==1 and delivered[1].event.sequence==2,"Session emits original packet order into GameplayUI")
	check(ui.gui_panel_access.policy.matches(6,Access.Policy.INVALID) and ui.gui_panel_access.policy.matches(8,actor_id),"Desktop policy receives journal and exact character targets")
	var before_blocked:=messages("blocked-attempt").size()
	desktop.panel("journal");desktop.panel("character")
	check(not desktop.journal.wanted and not desktop.sheet.wanted and messages("blocked-attempt").size()==before_blocked+2,"Actual Desktop rejects both blocked panel actions")
	peer.payloads=[journal_on,journal_popup];session._process(0.0)
	check(delivered.size()==4 and delivered[3].event.kind=="popup" and desktop.journal.wanted,"Server enable and popup open Journal through GameplayUI once")
	var journal_requests:=messages("journal").size()
	ui.gui_panel_access.observe_header(session.presentation(true).ui.guiPanelAccess)
	check(desktop.journal.wanted and messages("journal").size()==journal_requests,"Repeated world header does not replay popup")
	var control: Dictionary=ui.gui_panel_access.control.duplicate(true)
	session.world_state.registry[actor_id]=session.world_state.registry[actor_id].duplicate(true)
	ui.gui_panel_access.observe_header(session.presentation(true).ui.guiPanelAccess)
	check(ui.gui_panel_access.control==control,"Ordinary registry deep copy retains popup actor lifetime")
	desktop.journal.close_journal();ui.tables_ready=false;ui.hud_ready=false
	peer.payloads=[journal_popup];session._process(0.0)
	check(ui.gui_panel_access.pending.size()==1 and not desktop.journal.wanted,"Unready popup waits in actual UI adapter")
	session.world_state.registry[actor_id].nativeLifetime=4;session.world_state.registry[actor_id].clientKnownLifetime=4
	ui.gui_panel_access.observe_header(session.presentation(true).ui.guiPanelAccess)
	check(ui.gui_panel_access.pending.is_empty() and not desktop.journal.wanted and int(ui.gui_panel_access.control.controlLifetime)>int(control.controlLifetime),"Same-ID replacement retires the pending old-actor popup")
	ui.hud_ready=false;peer.payloads=[journal_popup];session._process(0.0)
	check(ui.gui_panel_access.pending.size()==1,"Current-area popup can await Journal readiness")
	session.area_generation+=1;session.world_state.area_id=10;session.world_state.area={"id":10};session.world_state.registry[actor_id].areaId=10
	ui.generation=2;ui.area_id=10;desktop.generation=2;desktop.area_id=10;desktop.objects[actor_id].areaId=10
	ui.gui_panel_access.observe_header(session.presentation(true).ui.guiPanelAccess)
	check(ui.gui_panel_access.pending.is_empty() and not desktop.journal.wanted,"Area transition retires old-area popup")
	session.close()
	check(session.gui_access.snapshot({}).revision==0,"Reconnect teardown clears connection-owned GUI access producer")
	ui.gui_panel_access.close()
	check(ui.gui_panel_access.pending.is_empty() and not ui.gui_panel_access.ordinary("journal"),"Reconnect teardown clears consumer queue and policy")
	session.free()
	return {"events":delivered.size(),"journalRequests":journal_requests,"actorLifetime":control.controlLifetime}
