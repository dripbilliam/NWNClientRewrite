extends SceneTree

const Connection=preload("res://systems/local_connection.gd")
const Lobby=preload("res://systems/character_lobby.gd")
const Browser=preload("res://systems/server_browser.gd")
const MainMenu=preload("res://systems/native_main_menu.gd")

var failures: Array[String]=[]
var frames: Array=[]
var output:=""
var record_path:=""
var client
var lobby
var browser

func _initialize()->void: call_deferred("run")

func check(ok: bool, label: String)->void:
	if not ok: failures.append(label)

func capture(label: String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path:=output.trim_suffix(".json")+"-"+label+".png"
	var image:=root.get_texture().get_image()
	var saved:=image.save_png(path)==OK
	var row:={"label":label,"image":path,"saved":saved,"browser_visible":browser.panel.visible,"lobby_visible":lobby.panel.visible,"native_wait_visible":is_instance_valid(lobby.native_wait) and lobby.native_wait.visible,"fallback_visible":lobby.window_column.visible,"wait_text":lobby.native_wait_text.text if is_instance_valid(lobby.native_wait_text) else "","browser_pending":browser.join_handoff_pending,"main_menu_visible":client.main_menu.panel.visible}
	frames.append(row)
	check(saved,label+" screenshot saved")

func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		elif arg.begins_with("--record="): record_path=arg.substr(9)
	if output.is_empty() or record_path.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	var secondary:=-1
	for screen in DisplayServer.get_screen_count():
		if screen!=DisplayServer.get_primary_screen(): secondary=screen; break
	if secondary<0: quit(2); return
	root.current_screen=secondary
	root.position=DisplayServer.screen_get_position(secondary)+Vector2i(80,80)
	root.size=Vector2i(1100,800)
	var record_file:=FileAccess.open(record_path,FileAccess.READ)
	if record_file==null: quit(2); return
	var record: Variant=JSON.parse_string(record_file.get_as_text())
	if not record is Dictionary or record.get("states",[]).slice(0,2)!=["connecting","resources"]: quit(2); return
	var phases: Array=record.get("nuiHandoffPhases",[])
	if phases.is_empty(): quit(2); return
	var progress: Array=phases[0].get("result",{}).get("download",{}).get("progress",[])
	if progress.is_empty(): quit(2); return
	client=Connection.new()
	client.connection=1
	client.main_menu=MainMenu.new()
	root.add_child(client.main_menu)
	lobby=Lobby.new(); root.add_child(lobby); lobby.native_frontend=true
	browser=Browser.new(); root.add_child(browser); browser.reset(1)
	client.lobby=lobby; client.server_browser=browser
	browser.request.connect(client.browser_request)
	lobby.apply_state({"connection":1,"state":{"phase":"menu","canJoin":true,"choices":[]}})
	browser.open()
	browser.receive({"kind":"browser-view","connection":1,"viewId":1,"tab":"Direct","direct":{"host":"127.0.0.1","port":5121,"name":"Recorded local NWSync"},"canJoin":true,"hasSavedCdKey":true,"rows":[],"busy":false})
	check(browser.panel.visible and not browser.connect_button.disabled,"browser ready before join")
	await capture("before-join")
	browser.submit_selected_join("")
	check(browser.join_handoff_pending and not browser.panel.visible and lobby.panel.visible and lobby.native_wait.visible,"same-frame join handoff")
	await capture("first-after-join")
	client.receive({"kind":"lobby","connection":1,"state":{"phase":"connecting","canCancelJoin":true,"connected":false,"choices":[]}})
	check(not browser.panel.visible and lobby.native_wait.visible and not lobby.window_column.visible,"connecting shows wait only")
	await capture("connecting")
	for index in progress.size():
		var item: Dictionary=progress[index]
		if str(item.get("phase","")) not in ["server-manifest","server-content"]: continue
		var state:={"phase":"resources","canCancelJoin":true,"connected":true,"choices":[],"resourceProgress":{"phase":item.phase,"completed":int(item.get("completed",0)),"total":int(item.get("total",0)),"downloadedBytes":int(item.get("downloadedBytes",0))}}
		client.receive({"kind":"lobby","connection":1,"state":state})
		check(not browser.panel.visible and lobby.native_wait.visible and not lobby.window_column.visible,"resource frame %d shows wait only" % index)
		if index==0 or index==progress.size()-1 or int(item.get("completed",0))>0 and int(item.get("completed",0))<int(item.get("total",0)) and frames.filter(func(row): return row.label=="download").is_empty():
			await capture("manifest" if index==0 else "complete" if index==progress.size()-1 else "download")
	client.receive({"kind":"browser-view","connection":1,"viewId":2,"tab":"Direct","direct":{"host":"127.0.0.1","port":5121,"name":"Recorded local NWSync"},"canJoin":false,"rows":[],"busy":true})
	check(not browser.panel.visible and lobby.native_wait.visible,"busy browser update does not flash")
	await capture("busy-browser-update")
	var report:={"success":failures.is_empty(),"failures":failures,"frames":frames,"record":record_path,"record_sha256":FileAccess.get_sha256(record_path),"sources":{"local_connection":FileAccess.get_sha256("res://systems/local_connection.gd"),"character_lobby":FileAccess.get_sha256("res://systems/character_lobby.gd"),"server_browser":FileAccess.get_sha256("res://systems/server_browser.gd"),"native_main_menu":FileAccess.get_sha256("res://systems/native_main_menu.gd")},"secondary":root.current_screen!=DisplayServer.get_primary_screen(),"no_focus":root.get_flag(Window.FLAG_NO_FOCUS),"scope":"Graphical replay through actual LocalConnection, CharacterLobby, ServerBrowser, and MainMenu instances using recorded local NWSync progress values. Browser join envelope is reconstructed because the older recording used lobby-join. No network, Arelith authority, or FPS claim."}
	check(report.secondary and report.no_focus,"secondary unfocused window")
	report.success=failures.is_empty(); report.failures=failures
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print(JSON.stringify({"success":report.success,"failures":failures,"frames":frames.size(),"report":output}))
	browser.queue_free()
	lobby.queue_free()
	client.main_menu.queue_free()
	await process_frame
	client.free()
	quit(0 if report.success else 1)
