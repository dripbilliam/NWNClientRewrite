extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_gui_access_fixture.json"))
	if not fixture is Dictionary:fail("Original-format GUI access fixture unavailable");return
	var disabled: Dictionary={};var popup: Dictionary={}
	for row in fixture.cases:
		if str(row.name)=="disabled-35-6-1-42":disabled=row
		if str(row.name)=="popup-6":popup=row
	if disabled.is_empty() or popup.is_empty():fail("Original-format GUI access packets unavailable");return
	var session=Session.new();root.add_child(session);var peer=FakePeer.new();session.peer=peer;session.phase="playing"
	session.remote_build={"number":8193,"revision":35,"postfix":0};session.area_generation=1
	session.world_state.area_id=9;session.world_state.area={"id":9};session.world_state.module={"name":"fixture"};session.world_state.local_object_id=42
	session.world_state.registry[42]={"id":42,"objectType":5,"areaId":9,"nativeLifetime":3,"clientKnownLifetime":3,"replicated":{"position":[0.0,0.0,0.0]}}
	var delivered: Array=[];session.ui_message_ready.connect(func(message: Dictionary):delivered.append(message.duplicate(true)))
	peer.payloads=[str(disabled.packet).hex_decode(),str(popup.packet).hex_decode()];session._process(0.0)
	if delivered.size()!=2 or delivered[0].kind!="gui-panel-access-event" or delivered[0].event.kind!="disabled" or delivered[1].event.kind!="popup":fail("Ordered GUI access packets did not reach the UI caller");return
	if int(delivered[1].event.scope.actorId)!=42 or int(delivered[1].event.scope.areaId)!=9 or int(delivered[1].event.scope.areaGeneration)!=1:fail("Popup did not bind to received actor and area scope");return
	var presented: Dictionary=session.presentation(true)
	if presented.has("error") or not presented.ui.has("guiPanelAccess") or int(presented.ui.guiPanelAccess.revision)!=2 or presented.ui.guiPanelAccess.events.size()!=2:fail("GUI access state was absent from the world header");return
	var lifetime:=int(presented.ui.guiPanelAccess.control.controlLifetime)
	session.world_state.registry[42]=session.world_state.registry[42].duplicate(true)
	if int(session.presentation(true).ui.guiPanelAccess.control.controlLifetime)!=lifetime:fail("Canonical registry copy changed GUI control lifetime");return
	session.world_state.registry[42].nativeLifetime=4;session.world_state.registry[42].clientKnownLifetime=4
	if int(session.presentation(true).ui.guiPanelAccess.control.controlLifetime)<=lifetime:fail("Replaced same-ID actor retained GUI control lifetime");return
	var malformed: PackedByteArray=str(popup.packet).hex_decode();malformed.append(0)
	peer.payloads=[malformed];session._process(0.0)
	if session.phase!="failed" or not session.error.contains("Invalid native GUI access") or int(session.gui_access.snapshot({}).revision)!=0:fail("Malformed GUI access did not fail closed and reset connection state");return
	print("NWN79 GUI access session PASS: ordered original packets, UI event/header, stable/replaced lifetime and reset")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 GUI access session failed: "+reason)
	quit(1)
