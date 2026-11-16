extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")
const Vault=preload("res://systems/native_data/native_character_export_vault.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")

class FakePeer extends RefCounted:
	var sent: Array[PackedByteArray]=[]
	var incoming: Array[PackedByteArray]=[]
	var closed:=false
	func send_game_message(packet: PackedByteArray)->bool:
		sent.append(packet.duplicate())
		return true
	func poll()->Dictionary:
		var rows:=incoming.duplicate()
		incoming.clear()
		return {"payloads":rows}
	func close()->void:closed=true

class FailVault extends Vault:
	func store(_message: Dictionary,_existing_id: String="")->Dictionary:
		return {"error":"Isolated vault write failure"}

var folder: String=""

func _initialize()->void:call_deferred("run")

func run()->void:
	folder=ProjectSettings.globalize_path("res://.cache/nwn79-export-session-"+Vault._nonce())
	if DirAccess.dir_exists_absolute(folder):fail("Isolated export path collision");return
	var vault=Vault.new()
	if not vault.configure(folder):fail("Could not open isolated character vault");return
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_character_export_fixture.json"))
	if not fixture is Dictionary:fail("Original-format character export fixture missing");return
	var empty_packet:=PackedByteArray()
	for row in fixture.cases:
		if str(row.expected.dataHex).is_empty():empty_packet=str(row.packet).hex_decode();break
	var boundary:=int(empty_packet.decode_u32(3)) if empty_packet.size()>=7 else -1
	if boundary<11 or boundary>=empty_packet.size() or empty_packet.slice(boundary-4,boundary)!=PackedByteArray([0,0,0,0]):fail("Original zero-length export envelope changed");return
	var first:=bic(1);var second:=bic(2)
	if first.is_empty() or second.is_empty():fail("Could not write private BIC fixtures");return
	var peer=FakePeer.new();var session=Session.new();root.add_child(session)
	session.peer=peer;session.phase="playing";session.character_confirmed=true;session.character_vault=vault
	var statuses: Array=[];var ui: Array=[]
	session.character_export_status_ready.connect(func(row: Dictionary):statuses.append(row.duplicate(true)))
	session.ui_message_ready.connect(func(row: Dictionary):ui.append(row.duplicate(true)))
	var request: Dictionary=session.request_character_export()
	if not request.get("accepted",false) or request.get("alreadyPending",true) or peer.sent.size()!=1 or peer.sent[0]!=PackedByteArray([112,6,31]):fail("Original export request was not transmitted once");return
	if not session.request_character_export().get("alreadyPending",false) or peer.sent.size()!=1:fail("Concurrent export request was not coalesced");return
	peer.incoming.append(export_packet(empty_packet,first));session._process(0.0)
	if session.phase!="playing" or session.pending_character_export or session.character_export_uncertain or statuses.back().state!="saved" or ui.size()!=1 or ui[0].kind!="character-saved":fail("Server 3/10 did not finish the pending save");return
	var id: String=str(session.saved_character_id)
	if id.is_empty() or not exact(session.saved_character_bytes(id),first) or not session.saved_character_list().get("ready",false):fail("Saved BIC did not survive vault readback");return
	if not session.request_character_export().get("accepted",false) or peer.sent.size()!=2:fail("Second export request was not sent");return
	session.character_export_deadline=Time.get_ticks_msec()-1
	session._process(0.0)
	if not session.character_export_uncertain or session.pending_character_export or statuses.back().state!="failed" or not statuses.back().uncertain or not session.request_character_export().has("error"):fail("Timeout did not preserve one uncertain server reply");return
	peer.incoming.append(export_packet(empty_packet,second));session._process(0.0)
	var latest: Dictionary=session.saved_character_list()
	if session.character_export_uncertain or latest.entries.size()!=1 or int(latest.entries[0].revision)!=2 or str(latest.entries[0].id)!=id or not exact(session.saved_character_bytes(id),second):fail("Late server reply did not update the same durable character");return
	var failed=FailVault.new();failed.configure(folder);session.character_vault=failed
	if not session.request_character_export().get("accepted",false):fail("Failed-write scenario could not request export");return
	peer.incoming.append(export_packet(empty_packet,first));session._process(0.0)
	if session.phase!="playing" or session.peer!=peer or statuses.back().state!="failed" or session.pending_character_export or session.character_export_uncertain or not exact(vault.export_character(id),second):fail("Vault failure closed the connection or damaged the last save");return
	peer.incoming.append(PackedByteArray([80,3,10,0]));session._process(0.0)
	if session.phase!="failed" or not peer.closed:fail("Malformed server 3/10 did not close the failed session");return
	cleanup()
	print("NWN79 character-export session PASS: request_once=true pending_coalesced=true original_3_10=true durable_revisions=2 late_reply=true write_failure_keeps_connection=true malformed_rejected=true")
	quit(0)

func bic(marker: int)->PackedByteArray:
	var writer=Writer.new()
	return writer.write("BIC ",Writer.record({"FirstName":Writer.field(12,"Nibs"),"LastName":Writer.field(12,"Druid"),"NativeMarker":Writer.field(4,marker)}))

func export_packet(prefix: PackedByteArray,bytes: PackedByteArray)->PackedByteArray:
	var boundary:=int(prefix.decode_u32(3))
	var packet:=prefix.slice(0,boundary)
	packet.encode_u32(3,boundary+bytes.size())
	packet.encode_u32(boundary-4,bytes.size())
	packet.append_array(bytes)
	packet.append_array(prefix.slice(boundary))
	return packet

func exact(result: Dictionary,bytes: PackedByteArray)->bool:
	return result.get("ready",false) and result.get("data") is PackedByteArray and result.data==bytes

func cleanup()->void:
	if not folder.contains("nwn79-export-session-"):return
	for section in ["blobs","entries"]:
		var path:=folder.path_join(section);var directory:=DirAccess.open(path)
		if directory!=null:
			for name in directory.get_files():DirAccess.remove_absolute(path.path_join(name))
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)

func fail(reason: String)->void:
	printerr("NWN79 character-export session failed: "+reason)
	cleanup();quit(1)
