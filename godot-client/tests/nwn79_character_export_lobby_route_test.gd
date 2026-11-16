extends SceneTree
const Direct=preload("res://native_direct_session_world.gd")
const Session=preload("res://systems/native_data/native_network_session.gd")
const Lobby=preload("res://systems/character_lobby.gd")
const Vault=preload("res://systems/native_data/native_character_export_vault.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")

class DirectHarness extends Direct:
	var saved_receipts: Array[Dictionary]=[]
	# The full native host has separate connection admission and a render tree.
	# Keep its real direct export/lobby caller and capture only the unrelated
	# global character-saved notification at this isolated boundary. Route it
	# through the actual host receiver to catch a missing connection scope.
	func receive(message: Dictionary)->void:
		if message.get("kind")=="character-saved":
			saved_receipts.append(message.duplicate(true))
			super.receive(message)

class FakePeer extends RefCounted:
	var sent: Array[PackedByteArray]=[]
	var incoming: Array[PackedByteArray]=[]
	func send_game_message(packet: PackedByteArray)->bool:sent.append(packet.duplicate());return true
	func poll()->Dictionary:
		var result:={"payloads":incoming.duplicate()};incoming.clear();return result
	func close()->void:pass

var folder: String=""
var checks:=0
var failures: Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func bic()->PackedByteArray:
	var writer=Writer.new()
	return writer.write("BIC ",Writer.record({"FirstName":Writer.field(12,"Nibs"),"LastName":Writer.field(12,"Druid"),"NativeMarker":Writer.field(4,1)}))
func export_packet(prefix: PackedByteArray,bytes: PackedByteArray)->PackedByteArray:
	var boundary:=int(prefix.decode_u32(3));var packet:=prefix.slice(0,boundary)
	packet.encode_u32(3,boundary+bytes.size());packet.encode_u32(boundary-4,bytes.size());packet.append_array(bytes);packet.append_array(prefix.slice(boundary))
	return packet
func run()->void:
	folder=ProjectSettings.globalize_path("res://.cache/nwn79-export-lobby-route-"+Vault._nonce())
	if DirAccess.dir_exists_absolute(folder):fail("Isolated vault path collision");return
	var vault=Vault.new()
	if not vault.configure(folder):fail("Isolated vault unavailable");return
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_character_export_fixture.json"))
	if not fixture is Dictionary:fail("Original-format 3/10 packet fixture unavailable");return
	var prefix:=PackedByteArray()
	for row in fixture.cases:
		if str(row.expected.dataHex).is_empty():prefix=str(row.packet).hex_decode();break
	if prefix.is_empty():fail("Original-format 3/10 envelope unavailable");return
	var peer=FakePeer.new();var session=Session.new();root.add_child(session)
	session.peer=peer;session.phase="playing";session.character_confirmed=true;session.character_vault=vault;session.local_vault_allowed=true
	var lobby=Lobby.new();root.add_child(lobby)
	var direct=DirectHarness.new();direct.direct_mode=true;direct.direct_session=session;direct.character_lobby=lobby;direct.session_connection=7;direct.label=Label.new();direct.ticket={"localCharacterRoots":[]}
	direct.direct_lobby_state={"phase":"playing","connected":true,"busy":false,"localAllowed":true,"savedCharacters":[],"choices":[]}
	lobby.request.connect(direct.lobby_request)
	session.character_export_status_ready.connect(direct.direct_character_export_status)
	direct.direct_show_character_state();lobby.panel.show()
	check(not lobby.export_button.disabled,"Active server actor offers Save Character in Godot lobby")
	lobby.export_button.pressed.emit()
	check(peer.sent.size()==1 and peer.sent[0]==PackedByteArray([112,6,31]) and lobby.export_button.disabled and lobby.export_status_label.text=="Saving character…","Actual lobby button sends one original export packet and shows pending")
	lobby.export_button.pressed.emit()
	check(peer.sent.size()==1,"Pending Save Character cannot issue a second request")
	peer.incoming.append(export_packet(prefix,bic()));session._process(0.0)
	var saved: Dictionary=session.saved_character_list()
	check(saved.get("ready",false) and saved.get("entries",[]).size()==1 and direct.saved_receipts.size()==1,"Original 3/10 reply commits one durable vault entry and visible save receipt")
	check(direct.export_receipt_serial==1 and direct.saved_receipts[0].get("connection",-1)==direct.session_connection and session.phase=="playing","Actual base receiver accepts scoped character-saved receipt without closing the live session")
	check(lobby.export_status_label.text.begins_with("Saved ") and lobby.saved_list.item_count==1 and lobby.saved_list.get_item_metadata(0)==saved.entries[0].id,"Direct status/list caller refreshes actual lobby controls")
	session.phase="character-selection";session.catalog=RefCounted.new();direct.direct_character_list([])
	var key: String="godot-vault:"+str(saved.entries[0].id)
	var index: int=lobby.keys.find(key)
	check(index>=0 and lobby.choices.get_item_text(index)==str(saved.entries[0].name),"Saved vault BIC joins the normal eligible character list")
	var deadline:=Time.get_ticks_msec()+5000
	while not lobby.local_catalog.ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(lobby.local_catalog.ready() and lobby.local_catalog.values.has(key) and lobby.local_catalog.errors.is_empty(),"Normal chooser worker verifies saved ID/hash/size and projects BIC")
	if index>=0 and lobby.can_select():lobby.choices.item_selected.emit(index)
	check(direct.direct_lobby_state.get("selected")==key and direct.direct_lobby_state.get("preview") is Dictionary and not direct.direct_lobby_state.preview.has("error"),"Saved character selection previews verified vault bytes through direct caller")
	if lobby.can_select():lobby.play_button.pressed.emit()
	check(session.phase=="character-loading" and session.saved_character_id==str(saved.entries[0].id) and peer.sent.size()==2 and str(direct.direct_lobby_state.phase)=="area-loading","Actual Play uploads verified saved BIC and retains vault revision identity")
	session.close();lobby.free();session.free();direct.label.free();direct.direct_session=null;direct.character_lobby=null;direct.free();cleanup()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Original 3/10 wire reply through direct-world export status, actual Godot Save Character button and ordered vault list, verified chooser preview/Play; isolated vault and fake peer"}
	print("NWN79_CHARACTER_EXPORT_LOBBY_ROUTE_RESULT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func cleanup()->void:
	if not folder.contains("nwn79-export-lobby-route-"):return
	for section in ["blobs","entries"]:
		var path:=folder.path_join(section);var directory:=DirAccess.open(path)
		if directory!=null:
			for name in directory.get_files():DirAccess.remove_absolute(path.path_join(name))
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)
func fail(reason: String)->void:
	printerr("NWN79 character export lobby route failed: "+reason);cleanup();quit(1)
