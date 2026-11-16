extends SceneTree
const Lobby=preload("res://systems/character_lobby.gd")
const Direct=preload("res://native_direct_session_world.gd")

func _initialize()->void:
	run_case.call_deferred()

func run_case()->void:
	root.size=Vector2i(1200,850)
	var lobby:=Lobby.new();root.add_child(lobby)
	var requests: Array=[]
	lobby.request.connect(func(message: Dictionary):requests.append(message))
	lobby.apply_state({"connection":7,"state":{"phase":"resources","busy":true,"canCancelJoin":true,"canSelect":false,"connected":true,"resourceProgress":{"phase":"server-content","completed":2,"total":13,"downloadedBytes":0}}})
	lobby.show_sync_wait()
	await process_frame
	if not is_instance_valid(lobby.native_wait_cancel) or not lobby.native_wait_cancel.is_visible_in_tree() or lobby.native_wait_cancel.disabled or not lobby.play_button.disabled or lobby.play_button.is_visible_in_tree():fail("Visible native wait layer did not expose enabled Cancel and gate Play");return
	if lobby.cancel_button.is_visible_in_tree():fail("Hidden character list Cancel was mistaken for the visible NWSync wait control");return
	lobby.native_wait_cancel.pressed.emit()
	if requests.size()!=1 or str(requests[0].get("kind",""))!="lobby-cancel-join" or int(requests[0].get("connection",-1))!=7:fail("Visible native wait Cancel did not request current-connection cancellation");return
	var direct=Direct.new();direct.character_lobby=lobby;direct.session_connection=7
	direct.direct_lobby_state={"phase":"resources","busy":true,"canCancelJoin":true,"connected":true,"resourceProgress":{"phase":"server-content","completed":13,"total":13}}
	direct.direct_phase_changed("playing")
	await process_frame
	if lobby.panel.is_visible_in_tree() or lobby.native_wait_cancel.is_visible_in_tree() or str(lobby.state.get("phase",""))!="playing" or bool(lobby.state.get("canCancelJoin",true)) or lobby.state.has("resourceProgress"):fail("Direct world retained NWSync wait controls after admission");return
	direct.character_lobby=null;direct.free()
	lobby.free()
	print("NWN79 Godot NWSync wait visibility PASS: actual native Cancel visible/actionable, Play gated, controls retired")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot NWSync wait visibility failed: "+reason)
	quit(1)
