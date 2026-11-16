extends SceneTree
class ProbeSession extends "res://native_session_world.gd":
	var metric_calls:=0
	func _initialize() -> void: pass # Do not start a network client.
	func publish_device_properties() -> void: metric_calls+=1
class LobbyStub extends Node:
	var state: Dictionary={}
	func apply_state(message: Dictionary) -> void: state=message.state
class MenuStub extends Node:
	func observe_lobby(_state: Dictionary) -> void: pass
class BrowserStub extends Node:
	var wanted:=false
	var join_handoff_pending:=false
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var session:=ProbeSession.new()
	session.character_lobby=LobbyStub.new(); session.render_menu=MenuStub.new(); session.server_browser=BrowserStub.new()
	check(session.session_connection==0 and not session.device_metrics_hello_ready,"Initial connection zero starts before metrics admission")
	session.receive_profiled({"kind":"lobby","connection":0,"state":{"phase":"playing","connected":true}})
	check(session.device_metrics_hello_ready and session.metric_calls==1,"Same-connection first lobby releases and publishes metrics")
	check(session.session_connection==0 and session.character_lobby.state.phase=="playing","Metrics publication preserves lobby state application")
	session.receive_profiled({"kind":"lobby","connection":0,"state":{"phase":"playing","connected":true}})
	check(session.metric_calls==2,"Later same-connection lobby reaches the deduping publisher")
	session.character_lobby.free(); session.render_menu.free(); session.server_browser.free()
	session.character_lobby=null; session.render_menu=null; session.server_browser=null
	session.free()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures},"  ")); file.close()
	quit(0 if failures.is_empty() else 1)
