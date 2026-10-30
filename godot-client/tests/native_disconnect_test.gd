extends "res://native_session_world.gd"
var checks:=0
var failures: Array=[]
var requests: Array=[]
class PendingWorld extends Node3D:
	var retired:=false
	func begin_retirement() -> void: retired=true; hide()
	func worker_tasks() -> Array: return []
	func close() -> void: pass
func check(value: bool,description: String) -> void:
	checks+=1
	if not value: failures.append(description)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	host=Node3D.new(); root.add_child(host); label=Label.new(); host.add_child(label)
	world_retirement=WorldRetirement.new(); host.add_child(world_retirement)
	catalog_retirement=WorldRetirement.new(); host.add_child(catalog_retirement)
	loading_screen=preload("res://systems/native_loading_screen.gd").new(); host.add_child(loading_screen)
	server_browser=Browser.new(); host.add_child(server_browser)
	character_lobby=Lobby.new(); host.add_child(character_lobby)
	character_lobby.request.connect(lobby_request)
	render_menu=MainMenu.new(); host.add_child(render_menu)
	render_menu.connection_query=func():return character_lobby.state.get("connected",false) or character_lobby.state.get("canCancelJoin",false)
	render_menu.disconnect_requested.connect(func():request_disconnect(false))
	server_browser.request.connect(func(value):requests.append(value.duplicate(true)))
	receive({"kind":"lobby","connection":1,"state":{"phase":"area-loading","busy":true,"connected":true,"canCancelJoin":false,"choices":[]}})
	check(server_browser.connection==1,"Server browser follows the connection boundary")
	world=PendingWorld.new(); host.add_child(world)
	render_menu.open(true); check(render_menu.disconnect_button.visible,"Main menu offers Disconnect during loading")
	check(not character_lobby.disconnect_button.disabled,"Character upload/loading cannot disable Disconnect")
	check(not character_lobby.save_on_disconnect.visible,"A server character is never implicitly exported")
	pending_voice.append({"kind":"raw-voice-events","connection":1,"generation":7})
	pending_script_sounds.append({"kind":"raw-script-sounds","connection":1,"generation":7})
	render_menu.choose("disconnect")
	check(pending_voice.is_empty() and pending_script_sounds.is_empty(),"Disconnect clears queued actor voices and script sounds before a new connection can reuse area/generation IDs")
	check(world==null and not loading_screen.active and cancelled_connection==1,"Disconnect immediately retires world/control and loading overlay")
	check(native_pointer_blocked(Vector2.ZERO),"Deferred pointer callbacks are safely blocked after their world/UI owner is cleared")
	check(not accept_connection({"kind":"setup","connection":1}),"Late same-connection setup cannot resurrect the retired world")
	check(not accept_connection({"kind":"raw-world-begin","connection":1}),"Late same-connection snapshot is fenced")
	check(not accept_connection({"kind":"raw-voice-events","connection":1}) and not accept_connection({"kind":"raw-script-sounds","connection":1}),"Closed-session voice and script-sound frames cannot repopulate reset queues")
	receive({"kind":"lobby","connection":2,"state":{"phase":"menu","busy":false,"connected":false,"canJoin":true,"choices":[]}})
	check(server_browser.connection==2 and server_browser.wanted and requests[-1].connection==2,"Cancellation returns to server selection with the new owner")
	server_browser.receive({"kind":"browser-view","connection":2,"viewId":2,"tab":"Direct","filters":{},"direct":{"host":"127.0.0.1","port":5121,"name":"Tester"},"rows":[],"page":0,"pages":1,"total":0,"canJoin":true,"busy":false})
	check(server_browser.view_id==2,"Reopened browser accepts fresh views")
	receive({"kind":"lobby","connection":3,"state":{"phase":"playing","connected":true,"busy":false,"choices":[]}})
	world=PendingWorld.new(); host.add_child(world); server_browser.reset(3)
	receive({"kind":"lobby","connection":3,"state":{"phase":"closed","connected":false,"busy":false,"error":"Server closed the connection","choices":[]}})
	check(world==null and server_browser.wanted and cancelled_connection==3,"Remote disconnect retires the world and opens server selection")
	check(not accept_connection({"kind":"movement","connection":3}),"Movement from a closed session is discarded")
	await process_frame
	world_retirement.close(); catalog_retirement.close(); host.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"public_connections":0,"scope":"Native disconnect ownership, loading, menus and remote close; live protocol acceptance separate"},"  ")+"\n"); file.close()
	quit(0 if failures.is_empty() else 1)
func send(value: Dictionary) -> void:
	var scoped:=value.duplicate(true); scoped.connection=session_connection
	requests.append(scoped)
