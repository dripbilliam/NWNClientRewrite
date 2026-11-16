extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")
const Access=preload("res://systems/native_data/native_network_gui_access.gd")

class FakePeer extends RefCounted:
	var sent: Array[PackedByteArray]=[]
	func send_game_message(packet: PackedByteArray)->bool:
		sent.append(packet.duplicate())
		return true
	func poll()->Dictionary:return {"payloads":[]}
	func close()->void:pass

func _initialize()->void:
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_gui_outbound_oracle.json"))
	if not oracle is Dictionary or not oracle.get("cases") is Array:fail("Original GUI writer oracle unavailable");return
	var session=Session.new();root.add_child(session)
	var fake=FakePeer.new();session.peer=fake;session.phase="playing"
	session.remote_build={"number":8193,"revision":34,"postfix":0}
	session.area_generation=1;session.world_state.area_id=9;session.world_state.local_object_id=0x8000002a
	session.world_state.registry[0x8000002a]={"id":0x8000002a,"objectType":5,"areaId":9,"nativeLifetime":3,"clientKnownLifetime":3,"replicated":{}}
	var intent: Dictionary={"kind":"native-panel","open":true,"actorId":0x8000002a,"areaId":9,"generation":1,"accessRevision":0,"attemptSerial":1}
	if not session.gui_access.observe({"kind":"gui-panel-disabled","panelId":6,"targetId":Access.INVALID,"targetSource":"received","disabled":true}).get("accepted",false):fail("Journal policy setup failed");return
	intent.merge({"panel":"blocked-attempt","guiPanelId":6,"targetId":Access.INVALID,"accessRevision":1},true)
	if not check_send(session,fake,intent,oracle.cases[0]):return
	session.remote_build={"number":8193,"revision":35,"postfix":0}
	if not session.gui_access.observe({"kind":"gui-panel-disabled","panelId":8,"targetId":0x8000002a,"targetSource":"received","disabled":true}).get("accepted",false):fail("Record policy setup failed");return
	intent.merge({"guiPanelId":8,"targetId":0x8000002a,"accessRevision":2,"attemptSerial":2},true)
	if not check_send(session,fake,intent,oracle.cases[1]):return
	if not session.gui_access.observe({"kind":"gui-panel-disabled","panelId":16,"targetId":Access.INVALID,"targetSource":"received","disabled":true}).get("accepted",false):fail("Context policy setup failed");return
	intent.merge({"panel":"context-attempt","sourceKind":"ground","guiPanelId":16,"targetId":Access.INVALID,"position":[1.25,-2.5,0.5],"accessRevision":3,"attemptSerial":3},true)
	if not check_send(session,fake,intent,oracle.cases[2]):return
	var before: int=fake.sent.size()
	if not session.gui_panel_input(intent).has("error") or fake.sent.size()!=before:fail("Repeated context attempt escaped serial guard");return
	if not session.gui_access.observe({"kind":"gui-panel-disabled","panelId":16,"targetId":Access.INVALID,"targetSource":"received","disabled":false}).get("accepted",false):fail("Context unblock setup failed");return
	intent.merge({"accessRevision":4,"attemptSerial":4},true)
	if not check_send(session,fake,intent,oracle.cases[3]):return
	session.remote_build={"number":8193,"revision":34,"postfix":0}
	intent.merge({"sourceKind":"creature","guiPanelId":18,"targetId":0x8000002a,"position":[0,0,0],"attemptSerial":5},true)
	if not check_send(session,fake,intent,oracle.cases[4]):return
	before=fake.sent.size()
	intent.accessRevision=3;intent.attemptSerial=6
	if not session.gui_panel_input(intent).has("error") or fake.sent.size()!=before:fail("Stale access revision transmitted");return
	intent.accessRevision=4;intent.areaId=10
	if not session.gui_panel_input(intent).has("error") or fake.sent.size()!=before:fail("Stale area transmitted");return
	intent.areaId=9;intent.panel="blocked-attempt";intent.guiPanelId=8;intent.targetId=0x8000002a
	intent.recordActorLifetime=2;intent.recordTargetLifetime=2
	if not session.gui_panel_input(intent).has("error") or fake.sent.size()!=before:fail("Retired record disclosure transmitted");return
	session.world_state.registry[0x8000002a].nativeLifetime=4;session.world_state.registry[0x8000002a].clientKnownLifetime=4
	intent.erase("recordActorLifetime");intent.erase("recordTargetLifetime")
	intent.guiPanelId=6;intent.targetId=Access.INVALID
	if not session.gui_panel_input(intent).get("sent",false):fail("Replacement actor did not start a fresh attempt scope");return
	if fake.sent.size()!=before+1:fail("Replacement actor send missing");return
	session.close()
	if not session.gui_panel_attempt_scope.is_empty() or session.gui_panel_attempt_last!=0:fail("GUI attempt state survived disconnect");return
	print("NWN79 GUI outbound session PASS: five original packets, policy, serial, area, lifetime and reset")
	quit(0)

func check_send(session: Node,fake: FakePeer,intent: Dictionary,row: Dictionary)->bool:
	var result: Dictionary=session.gui_panel_input(intent)
	if not result.get("sent",false) or fake.sent.is_empty() or fake.sent[-1].hex_encode()!=str(row.hex):
		fail("GUI session packet differed from original writer: "+str(row.name)+" "+str(result)+" actual="+(fake.sent[-1].hex_encode() if not fake.sent.is_empty() else "none"));return false
	return true

func fail(reason: String)->void:
	printerr("NWN79 GUI outbound session failed: "+reason)
	quit(1)
