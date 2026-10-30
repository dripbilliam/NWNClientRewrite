extends SceneTree
const Probe=preload("res://systems/lobby_record_probe.gd")
var checks:=0
var failures: Array=[]
class LobbyFixture extends RefCounted:
	var connection:=4
	var state: Dictionary={"selected":"installed:wizard.bic","preview":{"sha256":"a".repeat(64)}}
	var native_chooser: Control
class ClientFixture extends Node:
	signal process_frame
	var closing:=false
	var character_lobby
	var root: SubViewport
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var surface:=SubViewport.new(); surface.size=Vector2i(400,200); surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var button:=Button.new(); surface.add_child(button); button.position=Vector2(20,20); button.size=Vector2(120,40); button.focus_mode=Control.FOCUS_NONE; var pressed: Array=[]; button.pressed.connect(func():pressed.append(true))
	var client:=ClientFixture.new(); root.add_child(client); client.root=surface; client.character_lobby=LobbyFixture.new(); client.character_lobby.native_chooser=Control.new(); var first=client.character_lobby.native_chooser
	var probe:=Probe.new(); probe.client=client; probe.identity=probe.current_identity(); probe.owner_id=first.get_instance_id(); await process_frame
	check(probe.owned(),"Diagnostic input belongs to the exact native chooser, connection, key and digest")
	probe.click(button); client.character_lobby.state.selected="installed:cleric.bic"; client.process_frame.emit(); await process_frame
	check(pressed.is_empty() and not probe.owned(),"A changed character retires a queued click before mouse-down")
	client.character_lobby.state.selected="installed:wizard.bic"; probe.identity=probe.current_identity(); probe.click(button); client.character_lobby.state.preview.sha256="b".repeat(64); client.process_frame.emit(); await process_frame
	check(pressed.is_empty() and not probe.owned(),"A changed BIC digest retires queued diagnostic input")
	probe.identity=probe.current_identity(); probe.click(button); client.character_lobby.connection+=1; client.process_frame.emit(); await process_frame
	check(pressed.is_empty() and not probe.owned(),"A replacement connection retires queued diagnostic input")
	probe.identity=probe.current_identity(); probe.click(button); client.character_lobby.native_chooser=Control.new(); client.process_frame.emit(); await process_frame
	check(pressed.is_empty() and not probe.owned(),"A replacement chooser cannot receive an old task's click")
	probe.owner_id=client.character_lobby.native_chooser.get_instance_id(); probe.click(button); client.process_frame.emit(); client.process_frame.emit(); client.process_frame.emit(); await process_frame
	check(pressed.size()==1,"An unchanged scoped diagnostic performs exactly one real button press")
	client.closing=true; check(not probe.owned(),"Closing the client retires diagnostic ownership")
	probe.retire(); check(not probe.running and probe.client==null and probe.result.cancelled and not probe.result.success,"Retirement releases the client and cannot fabricate successful control evidence")
	first.free(); client.character_lobby.native_chooser.free(); client.free(); surface.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"scope":"Real isolated GUI clicks under owned-local diagnostic identity/lifetime guards. This does not replace authoritative local gameplay acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
