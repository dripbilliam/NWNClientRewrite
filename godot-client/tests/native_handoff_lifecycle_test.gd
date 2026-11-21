extends "res://native_session_world.gd"
# Actual entry SceneTree; no base startup, transport, install/profile or new tree.
const NativeNui=preload("res://systems/native_nui.gd")
const NuiView=preload("res://systems/server_nui.gd")
var handoff_checks:=0
var handoff_failures: Array=[]
var protocol_refusals: Array=[]
var outbound: Array=[]
var visual_publications:=0
var consumed_refusals:=0

func _initialize() -> void:call_deferred("test_handoff")
func handoff_check(value: bool,description: String)->void:
	handoff_checks+=1
	if not value:handoff_failures.append(description);print("FAIL: ",description)
func fail(reason: String)->void:
	# Observe expected malformed-input refusals without starting app shutdown.
	protocol_refusals.append(reason)
func send(value: Dictionary)->void:
	# Observe actual producer calls only; no socket or invented acknowledgement.
	outbound.append({"atConnection":session_connection,"value":value.duplicate(true)})
func expect_refusal(message: Dictionary,reason: String)->bool:
	var before: int=protocol_refusals.size();receive(message)
	var matched: bool=protocol_refusals.size()==before+1 and protocol_refusals.back()==reason
	if matched:consumed_refusals+=1
	return matched
func source_row()->Dictionary:
	return {"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13,"replicated":{"name":{"text":"Handoff fixture"}}}
func speech(body: String)->Dictionary:
	return {"kind":"server-speech","channel":1,"objectId":42,"text":{"text":body}}
func nui_create(token: int)->Dictionary:
	return {"kind":"nui-create","token":token,"nativeSerial":77,"format":1,"layout":{"root":{"type":"column","children":[]}}}
func make_ui():
	var ui=GameplayUi.new();host.add_child(ui);ui.set_process(false);ui.set_process_unhandled_key_input(false)
	ui.generation=1;ui.area_id=91;ui.controlled_id=42;ui.text.objects={42:source_row()};ui.native_connection_query=native_text_connection
	var owner:=NativeNui.new();ui.add_child(owner);owner.set_process(false);owner.ui=ui
	var view:=NuiView.new();owner.add_child(view);owner.view=view;ui.nui=owner
	return ui
func setup_frame(connection: int,fixture: String,name: String)->Dictionary:
	return {"kind":"setup","connection":connection,"install":fixture,"moduleName":name,"serverLabel":"Owned fixture","resourceSources":{"recordedCatalog":fixture,"marker":name}}
func test_handoff()->void:
	var output:="";var fixture:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
		if argument.begins_with("--catalog-fixture="):fixture=argument.trim_prefix("--catalog-fixture=")
	if output.is_empty() or fixture.is_empty() or FileAccess.file_exists(output):quit(2);return
	host=Node3D.new();root.add_child(host);label=Label.new();root.add_child(label)
	world_retirement=WorldRetirement.new();host.add_child(world_retirement);world_retirement.set_process(false)
	handoff_check(native_clock_runtime==null and peer.get_status()==StreamPeerTCP.STATUS_NONE and not authenticated and args.is_empty(),"Actual entry startup stays suppressed with no protocol/native clock owner")
	session_connection=1;epoch=1;initialized=true;accepted_raw_serial=30;raw_serial=31
	raw_world={"serial":31,"generation":1,"count":2,"data":{"objects":[source_row()]}}
	gameplay_ui=make_ui();var old_ui=gameplay_ui;var old_nui=old_ui.nui
	old_ui.receive(speech("Origin pending"),1,1);old_ui.receive(nui_create(10),1,1)
	world=World.new();host.add_child(world);world.set_process(false);world.generation=1;world.area_id=91;world.controlled_id=42
	# Normal Root binds this weak owner before snapshot; this idle fixture has
	# explicitly no shadow owner and exercises the existing unavailable branch.
	var absent_budget:=Node.new();world.set_meta("native_point_shadow_budget",weakref(absent_budget));absent_budget.free()
	var old_world=world;var old_world_ref: WeakRef=weakref(old_world);var old_ui_ref: WeakRef=weakref(old_ui)
	old_world.instance_ready.connect(func(_id,_row,_instance):visual_publications+=1)
	handoff_check(old_ui.queue.size()==1 and old_nui.state.windows.has(10),"Actual origin Gameplay and NUI retain authored pending state before transfer")
	handoff_check(expect_refusal(setup_frame(2,fixture,"Premature"),"Native protocol connection advanced without a lobby/reset boundary") and session_connection==1 and not old_ui.closed,"Destination setup cannot advance a connection without the existing boundary")
	receive({"kind":"session-reset","connection":2})
	handoff_check(session_connection==2 and cancelled_connection==-1,"Existing reset boundary admits the destination connection")
	handoff_check(old_ui.closed and old_nui.closed and old_ui.queue.is_empty() and old_nui.state.windows.is_empty(),"Actual origin Gameplay closes and clears speech/NUI before destination setup")
	handoff_check(world==null and gameplay_ui==null and old_world.retiring and old_world.closed,"Actual origin world retires and detaches before destination ownership")
	handoff_check(raw_world.is_empty() and accepted_raw_serial==-1 and raw_serial==31 and epoch==-1,"Transfer reset invalidates raw base/assembler and preserves global sequence")
	var retired_instance:=Node3D.new();old_world.instance_ready.emit(42,source_row(),retired_instance);retired_instance.free()
	handoff_check(visual_publications==0 and old_world.instance_ready.get_connections().is_empty(),"Actual world retirement disconnects old visual callbacks before destination publication")
	old_ui.receive(speech("Late origin"),1,1);old_nui.resource_prepared(11,{"error":"","bytes":PackedByteArray()})
	handoff_check(old_ui.queue.is_empty() and old_nui.state.windows.is_empty(),"Closed actual origin UI and late NUI preparation cannot republish")

	handoff_check(expect_refusal({"kind":"raw-world-begin","connection":2,"serial":32,"generation":1,"count":0,"data":{"bridgeMode":"delta","bridgeBaseSerial":30}},"Native raw-world delta has no accepted base") and raw_serial==31 and raw_world.is_empty(),"Destination cannot reuse the origin raw delta base")
	handoff_check(expect_refusal({"kind":"raw-world-begin","connection":2,"serial":32,"generation":-1,"count":0,"data":{"bridgeMode":"delta","bridgeBaseSerial":-1}},"Native raw-world delta has no accepted base") and raw_serial==31 and raw_world.is_empty(),"A reset sentinel is not an accepted base: destination first frame must be full")
	reset_session()
	var next_serial: int=raw_serial+1
	receive({"kind":"raw-world-begin","connection":2,"serial":next_serial,"generation":1,"count":1,"data":{"bridgeMode":"full"}})
	receive({"kind":"raw-world-chunk","connection":2,"serial":next_serial,"generation":1,"objects":[source_row()]})
	handoff_check(raw_serial==next_serial and accepted_raw_serial==-1 and raw_world.data.objects.size()==1,"A higher process-global full frame begins independently of the origin base")
	gameplay_ui=make_ui();var destination_ui=gameplay_ui
	receive({"kind":"ui-protocol","connection":2,"generation":1,"message":nui_create(90)})
	receive({"kind":"ui-protocol","connection":2,"generation":1,"message":speech("Destination pending")})
	handoff_check(destination_ui.queue.size()==1 and destination_ui.nui.state.windows.has(90),"Current connection positively reaches actual destination speech and native NUI owners")
	var stale_before: int=int(report.get("stale_session_messages",0));var raw_before:=raw_world.duplicate(true)
	var retired_packets: Array=[setup_frame(1,fixture,"Retired"),{"kind":"raw-world-begin","connection":1},{"kind":"raw-world-chunk","connection":1},{"kind":"raw-world-end","connection":1},{"kind":"ui-protocol","connection":1,"generation":1,"message":speech("Wrong scope")},{"kind":"ui-protocol","connection":1,"generation":1,"message":nui_create(91)},{"kind":"ui-protocol","connection":1,"generation":1,"message":{"kind":"nui-binds","updates":[{"token":90,"bind":"origin","value":true}]}}]
	for packet in retired_packets:receive(packet)
	handoff_check(int(report.get("stale_session_messages",0))==stale_before+retired_packets.size(),"Old setup/raw/speech/NUI messages reject before destination dispatch")
	handoff_check(raw_world==raw_before and raw_serial==next_serial and destination_ui.queue.size()==1 and destination_ui.nui.state.windows.size()==1 and destination_ui.nui.state.windows[90].bindings.is_empty(),"Retired payloads cannot alter current raw, speech queue or reused NUI token")
	handoff_check(outbound.is_empty(),"Retired raw tails cannot emit a raw acknowledgement or catalogue-ready producer call")

	receive({"kind":"session-reset","connection":3})
	handoff_check(destination_ui.closed and destination_ui.nui.state.windows.is_empty() and raw_serial==next_serial,"Another boundary retires destination UI without resetting process sequence")
	receive(setup_frame(3,fixture,"Origin pending catalog"))
	var origin_loader=catalog_loader;origin_loader.set_process(false);var origin_loader_serial: int=origin_loader.serial
	handoff_check(catalog_loading and origin_loader.task>=0 and gameplay_ui==null,"Actual setup starts its owned recorded-catalog worker and suspends before Gameplay configuration")
	receive({"kind":"session-reset","connection":4})
	handoff_check(catalog_loader==null and origin_loader.task==-1 and origin_loader.serial>origin_loader_serial and not catalog_loading,"Reset cancels/joins the actual pending origin catalog before a new setup")
	receive(setup_frame(4,fixture,"Destination pending catalog"))
	var destination_loader=catalog_loader;destination_loader.set_process(false)
	handoff_check(destination_loader!=origin_loader and catalog_loading and current_prework_sources.get("marker")=="Destination pending catalog","Destination setup owns a distinct loader and descriptor after reset")
	var late_catalog:=Catalog.new();origin_loader.completed.emit(origin_loader_serial,late_catalog,"",{"late":true})
	await process_frame;await process_frame
	handoff_check(catalog_loader==destination_loader and catalog_loading and not initialized and gameplay_ui==null and catalog!=late_catalog,"Old setup coroutine cannot install its late catalog or construct destination Gameplay")
	handoff_check(outbound.is_empty() and module_name=="Destination pending catalog" and current_prework_sources.get("marker")=="Destination pending catalog","Late catalog completion cannot emit catalogue-ready or overwrite destination metadata")
	handoff_check(old_ui_ref.get_ref()==null and old_world_ref.get_ref()==null and world_retirement.snapshot().pending_worlds==0,"Actual UI/world retirement releases prior owners without a new retirement acknowledgement")
	receive({"kind":"session-reset","connection":5})
	handoff_check(destination_loader.task==-1 and catalog_loader==null and raw_world.is_empty() and accepted_raw_serial==-1 and raw_serial==next_serial,"Final reset joins the destination catalog and preserves clean raw ownership")
	await process_frame;await process_frame
	handoff_check(gameplay_ui==null and not initialized and not catalog_loading and outbound.is_empty() and native_clock_runtime==null and peer.get_status()==StreamPeerTCP.STATUS_NONE,"All cancelled setup continuations finish without UI/ACK/transport resurrection")
	handoff_check(protocol_refusals.size()==consumed_refusals,"No unexpected production refusal is hidden by the test's fatal-report observer")
	world_retirement.close();catalog=null;late_catalog=null;render_pool.clear();host.queue_free();label.queue_free();host=null;label=null
	await process_frame
	var result: Dictionary={"success":handoff_failures.is_empty(),"checks":handoff_checks,"failures":handoff_failures,"protocolRefusals":protocol_refusals,"outbound":outbound,"globalRawSerial":raw_serial,"connection":session_connection,"retiredPackets":retired_packets.size(),"scope":"Actual startup-suppressed SessionWorld reset/admission/setup and async SessionCatalog cancellation, actual idle World retirement and Gameplay/NUI owners. Authored protocol/empty recorded catalog; fatal/send observation seams only. No successful destination asset admission, raw-end ACK, live handoff, install/profile/network/key/GPU/native build."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("NATIVE_HANDOFF_LIFECYCLE ",handoff_checks," checks, ",handoff_failures.size()," failures");quit(0 if handoff_failures.is_empty() else 1)
