extends SceneTree
const Lobby=preload("res://systems/character_lobby.gd")
const Browser=preload("res://systems/server_browser.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok: failures.append(label)
func _initialize()->void: call_deferred("run")
func run()->void:
	var lobby:=Lobby.new();root.add_child(lobby);lobby.native_frontend=true
	var requests: Array=[];lobby.request.connect(func(value):requests.append(value.duplicate(true)))
	var state: Dictionary={"phase":"connecting","canCancelJoin":true,"connected":false,"choices":[]}
	lobby.apply_state({"connection":7,"state":state})
	check(lobby.native_wait.visible and not lobby.window_column.visible and lobby.native_wait_text.text.contains("Connecting"),"Connecting shows the pre-join wait surface")
	check(not lobby.native_wait_cancel.disabled and lobby.native_sync_bar.visible==false,"Connecting retains scoped cancellation without false download progress")
	lobby.native_wait_cancel.pressed.emit()
	check(requests.size()==1 and requests[0].kind=="lobby-cancel-join" and requests[0].connection==7,"Wait Cancel targets the active connection")
	state.phase="resources";state.connected=true;state.resourceProgress={"phase":"server-manifest","completed":0,"total":0,"downloadedBytes":0}
	lobby.apply_state({"connection":7,"state":state})
	check(lobby.native_wait.visible and lobby.native_sync_bar.visible and lobby.native_sync_bar.indeterminate and lobby.native_wait_text.text.contains("manifest"),"Manifest check shows indeterminate sync progress")
	state.resourceProgress={"phase":"server-content","completed":2,"total":13,"downloadedBytes":1572864};lobby.apply_state({"connection":7,"state":state})
	check(not lobby.native_sync_bar.indeterminate and lobby.native_sync_bar.value==2 and lobby.native_sync_bar.max_value==13 and lobby.native_wait_text.text.contains("2 / 13"),"Download shows authoritative progress")
	state.resourceProgress={"phase":"server-content","completed":13,"total":13,"downloadedBytes":0};lobby.apply_state({"connection":7,"state":state})
	check(lobby.native_wait_text.text.contains("Checking cached"),"Cached content does not claim a download")
	state.phase="resources-unavailable";state.error="Required content failed";lobby.apply_state({"connection":7,"state":state})
	check(lobby.native_wait_text.text.contains("Required content failed") and not lobby.native_wait_cancel.disabled and not lobby.native_sync_bar.visible,"Failure remains visible and cancellable")
	lobby.apply_state({"connection":8,"state":{"phase":"menu","canJoin":true,"choices":[]}})
	check(not lobby.native_wait.visible and not lobby.panel.visible,"New connection retires the old sync screen")
	var browser:=Browser.new();root.add_child(browser);var sent: Array=[];browser.request.connect(func(value):sent.append(value.duplicate(true)))
	browser.open();browser.receive({"kind":"browser-view","connection":0,"viewId":1,"tab":"Direct","direct":{"host":"127.0.0.1","port":5121,"name":"Tester"},"canJoin":true,"hasSavedCdKey":true,"rows":[],"busy":false})
	check(browser.panel.visible and not browser.connect_button.disabled,"Join starts from a ready browser view")
	browser.submit_selected_join("")
	check(browser.join_handoff_pending and not browser.panel.visible and sent.back().operation=="join","Submission hides the old browser immediately")
	browser.receive({"kind":"browser-view","connection":0,"viewId":2,"tab":"Direct","direct":{"host":"127.0.0.1","port":5121,"name":"Tester"},"canJoin":false,"rows":[],"busy":true})
	check(browser.join_handoff_pending and not browser.panel.visible,"Busy backend view cannot flash the old browser")
	browser.receive({"kind":"browser-view","connection":0,"viewId":3,"tab":"Direct","direct":{"host":"127.0.0.1","port":5121,"name":"Tester"},"canJoin":true,"rows":[],"busy":false,"status":"Retry"})
	check(not browser.join_handoff_pending and browser.panel.visible and browser.status.text=="Retry","Authoritative retry restores the browser")
	browser.reset(1)
	check(not browser.join_handoff_pending and not browser.panel.visible,"Connection replacement retires pending browser UI")
	browser.open()
	check(not browser.join_handoff_pending and browser.panel.visible,"Reopening after retirement restores the browser loading surface")
	browser.free();lobby.free()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Pre-join sync surface and browser handoff with authored state fixtures; no live server or visual/FPS claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
