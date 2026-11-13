extends "res://native_session_world.gd"
# Exercise the actual session/base reveal predicate without a protocol peer.
# The canvas/input behavior and original-resource rendering are tested separately.
class PendingWorld extends Node:
	var control_ready:=false
	func ready_for_control() -> bool: return control_ready
class LoadingGate extends Node:
	var blocked:=false
	func blocks_input() -> bool: return blocked
class PreparedUi extends Node:
	var presentation_enabled:=false
class LobbyState extends Node:
	var state: Dictionary={}
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	args={}; world=PendingWorld.new(); loading_screen=LoadingGate.new(); gameplay_ui=PreparedUi.new(); character_lobby=LobbyState.new()
	for node in [world,loading_screen,gameplay_ui,character_lobby]: root.add_child(node)
	world.control_ready=true
	for phase in ["menu","connecting","resources","character-selection","character-rejected","area-loading","disconnecting","closed"]:
		character_lobby.state={"phase":phase}; check(not gameplay_presentation_allowed(),"A ready model cannot reveal gameplay during "+phase)
	character_lobby.state={"phase":"playing"}; world.control_ready=false
	check(not gameplay_presentation_allowed(),"Playing alone does not reveal before initial player readiness")
	world.control_ready=true; loading_screen.blocked=true
	check(not gameplay_presentation_allowed(),"The loading overlay retains the gameplay presentation gate")
	loading_screen.blocked=false
	check(gameplay_presentation_allowed(),"Received playing plus initial readiness and reveal permits gameplay")
	gameplay_ui.presentation_enabled=true; world.control_ready=false
	check(gameplay_presentation_allowed(),"An admitted HUD stays visible during later model/reference preparation")
	character_lobby.state.phase="area-loading"
	check(not gameplay_presentation_allowed(),"A new server loading phase overrides an already visible HUD")
	gameplay_ui.presentation_enabled=false; character_lobby.state.phase="playing"
	check(not gameplay_presentation_allowed(),"The explicit new-area hide resets first-reveal readiness")
	args["offline-replay"]="true"; character_lobby.state={}; world.control_ready=true
	check(gameplay_presentation_allowed(),"Sealed replay can reveal without a live lobby phase")
	closing=true
	check(not gameplay_presentation_allowed(),"Closing overrides replay and ready state")
	closing=false; args={}; character_lobby.state.phase="playing"; world.free(); world=null
	check(not gameplay_presentation_allowed(),"A retired world cannot retain a gameplay canvas")
	for node in [loading_screen,gameplay_ui,character_lobby]: node.free()
	loading_screen=null; gameplay_ui=null; character_lobby=null
	# Client Options must share the gameplay layout file, not rendering options.
	# This route also needs to work before any world/chat owner exists.
	var chat_options=preload("res://systems/native_chat_options.gd")
	var preferences=preload("res://systems/native_data/chat_preferences.gd")
	args={"menu-layout":output+".layout.cfg"}; var saved: Dictionary=preferences.DEFAULTS.duplicate(); saved.width=640; preferences.save_settings(args["menu-layout"],saved)
	host=Node3D.new(); root.add_child(host); open_chat_settings()
	var window=chat_options.acquire(root,args["menu-layout"])
	check(window.visible and window.settings_path==args["menu-layout"] and window.fields.width.value==640,"Actual pregame session route opens the same persisted chat layout used by gameplay")
	window.fields.width.value=680; window.hide(); open_chat_settings()
	check(window.visible and window.fields.width.value==680 and preferences.load_settings(args["menu-layout"]).width==680,"Actual session reopen retains chat settings without a live world")
	window.get_parent().queue_free(); host.queue_free(); host=null
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"scope":"Actual native session/base gameplay reveal predicates with authored readiness/loading/lobby owners; no world rendering, protocol peer or physical input."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
