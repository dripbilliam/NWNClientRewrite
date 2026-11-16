extends SceneTree
const Peer=preload("res://systems/native_data/native_network_peer.gd")

class FakeDatagram extends RefCounted:
	var closed:=false
	var packets: Array[PackedByteArray]=[]
	func receive()->Dictionary:return {"packets":packets.duplicate()}
	func send(_packet: PackedByteArray)->bool:return true
	func close()->void:closed=true

class FakeWindow extends RefCounted:
	var portal: PackedByteArray
	func receive(_bytes: PackedByteArray,_at: int)->Dictionary:return {"send":[],"delivered":[{"bytes":portal}]}

class FakeAssembler extends RefCounted:
	var rows: Array[Dictionary]=[]
	func push(frame: Dictionary)->bool:rows.append(frame);return true
	func drain()->Array[Dictionary]:return rows.duplicate(true)

class FakeInflater extends RefCounted:
	var closed:=false
	func decode(bytes: PackedByteArray)->Dictionary:return {"bytes":bytes}
	func close()->void:closed=true

class FakeCrypto extends RefCounted:
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_portal_fixture.json"))
	if not fixture is Dictionary:fail("Portal fixture unavailable");return
	var portal:=PackedByteArray()
	for row in fixture.cases:
		if str(row.name)=="native-character-0":portal=str(row.packet).hex_decode();break
	if portal.is_empty():fail("Original portal character packet unavailable");return
	var peer:=Peer.new();peer.closed=false;peer.started=true;peer.admitted=true;peer.deadline=Time.get_ticks_msec()+10000;peer.next_window_poll=Time.get_ticks_msec()+10000
	var datagram:=FakeDatagram.new();datagram.packets=[PackedByteArray([77,0,0,0]),"BNDP".to_ascii_buffer()]
	peer.datagram=datagram;peer.window=FakeWindow.new();peer.window.portal=portal;peer.assembler=FakeAssembler.new();peer.inflater=FakeInflater.new();peer.crypto=FakeCrypto.new()
	var result: Dictionary=peer.poll()
	if str(result.get("error",""))!="Native server disconnected" or result.get("payloads",[]).size()!=1 or result.payloads[0]!=portal or peer.closed!=true or not datagram.closed:fail("BNDP discarded reliable character record or failed to close transport");return
	print("NWN79 Godot portal peer drain PASS: reliable character precedes coalesced BNDP and transport closes")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot portal peer drain failed: "+reason)
	quit(1)
