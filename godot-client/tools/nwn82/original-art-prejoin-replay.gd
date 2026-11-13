extends SceneTree

const Loader=preload("res://systems/native_data/session_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Connection=preload("res://systems/local_connection.gd")
const Lobby=preload("res://systems/character_lobby.gd")
const Browser=preload("res://systems/server_browser.gd")
const MainMenu=preload("res://systems/native_main_menu.gd")

var failures: Array[String]=[]
var frames: Array=[]
var output:=""
var record_path:=""
var install:=""
var client
var lobby
var browser
var painter
var catalog

func _initialize()->void: call_deferred("run")
func check(ok: bool,label: String)->void:
	if not ok: failures.append(label)

func capture(label: String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path:=output.trim_suffix(".json")+"-"+label+".png"
	var saved:=root.get_texture().get_image().save_png(path)==OK
	var row:={"label":label,"image":path,"saved":saved,"native_browser_visible":browser.native_browser.visible,"prototype_browser_visible":browser.panel.visible,"entry_visible":browser.entry_menu.visible,"lobby_visible":lobby.panel.visible,"native_wait_visible":is_instance_valid(lobby.native_wait) and lobby.native_wait.visible,"fallback_character_visible":lobby.window_column.visible,"main_menu_visible":client.main_menu.panel.visible,"wait_text":lobby.native_wait_text.text if is_instance_valid(lobby.native_wait_text) else "","browser_pending":browser.join_handoff_pending}
	frames.append(row)
	check(saved,label+" screenshot saved")

func no_old_menu(label: String)->void:
	check(not browser.native_browser.visible and not browser.panel.visible and not browser.entry_menu.visible and not client.main_menu.panel.visible and lobby.panel.visible and lobby.native_wait.visible and not lobby.window_column.visible,label+" has only native wait")

func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		elif arg.begins_with("--record="): record_path=arg.substr(9)
		elif arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or record_path.is_empty() or not install.is_absolute_path() or FileAccess.file_exists(output): quit(2); return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	var secondary:=-1
	for screen in DisplayServer.get_screen_count():
		if screen!=DisplayServer.get_primary_screen(): secondary=screen; break
	if secondary<0: quit(2); return
	root.current_screen=secondary; root.position=DisplayServer.screen_get_position(secondary)+Vector2i(80,80); root.size=Vector2i(1100,800)
	var record_file:=FileAccess.open(record_path,FileAccess.READ)
	if record_file==null: quit(2); return
	var record: Variant=JSON.parse_string(record_file.get_as_text())
	if not record is Dictionary or record.get("states",[]).slice(0,2)!=["connecting","resources"]: quit(2); return
	var phases: Array=record.get("nuiHandoffPhases",[])
	if phases.is_empty(): quit(2); return
	var progress: Array=phases[0].get("result",{}).get("download",{}).get("progress",[])
	if progress.is_empty(): quit(2); return
	var prepared: Dictionary=Loader.prepare({"install":install,"modsDirectory":"","disabledMods":[]})
	if not str(prepared.get("error","")).is_empty(): quit(3); return
	catalog=prepared.catalog
	var text=Text.new()
	if not text.base.open_file(install.path_join("lang/en/data/dialog.tlk")): quit(3); return
	painter=Painter.new(); root.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	client=Connection.new(); client.connection=1
	client.main_menu=MainMenu.new(); root.add_child(client.main_menu)
	lobby=Lobby.new(); root.add_child(lobby); lobby.native_frontend=true
	browser=Browser.new(); root.add_child(browser); browser.configure_native(painter,text,catalog,""); browser.reset(1)
	client.lobby=lobby; client.server_browser=browser
	browser.request.connect(client.browser_request)
	var requests: Array=[]
	browser.request.connect(func(message): requests.append(message.duplicate(true)))
	lobby.request.connect(func(message): requests.append(message.duplicate(true)))
	var deadline:=Time.get_ticks_msec()+16000
	var cohorts: Dictionary={}
	var owners:={"entry":browser.entry_menu,"browser":browser.native_browser,"direct":browser.direct_dialog,"profile":browser.profile_dialog,"filters":browser.filter_dialog,"details":browser.details_dialog,"password":browser.password_dialog}
	while Time.get_ticks_msec()<deadline:
		await create_timer(0.1).timeout
		var terminal:=true
		for name in owners:
			cohorts[name]=owners[name].cohort_snapshot()
			if not cohorts[name].ready and cohorts[name].failures.is_empty(): terminal=false
		if terminal: break
	for name in cohorts: check(cohorts[name].ready,"installed "+name+" cohort ready")
	if not failures.is_empty(): await finish(cohorts,requests); return
	lobby.apply_state({"connection":1,"state":{"phase":"menu","canJoin":true,"choices":[]}})
	browser.open(false,true,"Internet")
	var selected:={"entryId":7,"host":"127.0.0.1","port":5121,"selected":true,"allowed":true,"passwordRequired":false,"serverName":"Recorded local NWSync","moduleName":"Fixture","playerCount":1,"maximumPlayers":4,"minimumLevel":1,"maximumLevel":40,"pvpSetting":0}
	browser.receive({"kind":"browser-view","connection":1,"viewId":1,"tab":"Internet","rows":[selected],"busy":false,"canJoin":true,"hasSessionProfile":true,"hasSavedCdKey":true,"direct":{"name":"Fixture"}})
	check(browser.native_browser.visible and not browser.panel.visible and not browser.entry_menu.visible,"native browser visible before join")
	await capture("before-join")
	# Use the controller action; it emits the normal browser request into LocalConnection.browser_request.
	browser.connect_button.disabled=false; browser._join()
	check(requests.any(func(message): return message.get("operation","")=="join"),"join emitted through browser request")
	check(browser.join_handoff_pending,"join handoff pending in same frame")
	no_old_menu("same frame after Join")
	await capture("first-after-join")
	client.receive({"kind":"lobby","connection":1,"state":{"phase":"connecting","canCancelJoin":true,"connected":false,"choices":[]}})
	no_old_menu("connecting")
	await capture("connecting")
	var captured_download:=false
	for index in progress.size():
		var item: Dictionary=progress[index]
		if str(item.get("phase","")) not in ["server-manifest","server-content"]: continue
		var state:={"phase":"resources","canCancelJoin":true,"connected":true,"choices":[],"resourceProgress":{"phase":item.phase,"completed":int(item.get("completed",0)),"total":int(item.get("total",0)),"downloadedBytes":int(item.get("downloadedBytes",0))}}
		client.receive({"kind":"lobby","connection":1,"state":state})
		no_old_menu("resource %d" % index)
		if str(item.phase)=="server-manifest" and not frames.any(func(row): return row.label=="manifest"):
			await capture("manifest")
		elif not captured_download and int(item.get("completed",0))>0 and int(item.get("completed",0))<int(item.get("total",0)):
			captured_download=true; await capture("download")
	client.receive({"kind":"lobby","connection":1,"state":{"phase":"resources","canCancelJoin":true,"connected":true,"choices":[],"resourceProgress":{"phase":"server-content","completed":15,"total":15,"downloadedBytes":0}}})
	no_old_menu("cached resources")
	await capture("cached")
	client.receive({"kind":"browser-view","connection":1,"viewId":2,"tab":"Internet","rows":[selected],"busy":true,"canJoin":false})
	no_old_menu("busy browser update")
	await capture("busy-browser-update")
	client.receive({"kind":"lobby","connection":1,"state":{"phase":"resources-unavailable","canCancelJoin":true,"connected":true,"choices":[],"error":"Fixture missing server content"}})
	no_old_menu("resource failure")
	check(lobby.native_wait_text.text.contains("Fixture missing server content"),"failure shown in native wait")
	await capture("failure")
	lobby.native_wait_cancel.pressed.emit()
	check(requests.any(func(message): return message.get("kind","")=="lobby-cancel-join"),"cancel request emitted")
	client.receive({"kind":"lobby","connection":1,"state":{"phase":"menu","canJoin":true,"choices":[]}})
	client.receive({"kind":"browser-view","connection":1,"viewId":3,"tab":"Internet","rows":[selected],"busy":false,"canJoin":true,"hasSessionProfile":true})
	check(browser.native_browser.visible and not browser.join_handoff_pending and not lobby.panel.visible,"browser restored after cancel")
	check(not client.main_menu.panel.visible,"main menu hidden over restored browser")
	await capture("cancel-restored")
	# A new connection scope must not inherit the old join handoff or wait page.
	client.connection=2; browser.reset(2); lobby.apply_state({"connection":2,"state":{"phase":"menu","canJoin":true,"choices":[]}}); browser.open(false,true,"Internet")
	client.receive({"kind":"browser-view","connection":2,"viewId":1,"tab":"Internet","rows":[],"busy":false,"canJoin":true,"hasSessionProfile":true})
	check(browser.native_browser.visible and not browser.join_handoff_pending and not lobby.panel.visible,"new connection browser visible without old wait")
	check(not client.main_menu.panel.visible,"main menu hidden over new connection browser")
	await capture("connection-switch")
	await finish(cohorts,requests)

func finish(cohorts: Dictionary,requests: Array)->void:
	var sources:={}
	for path in ["systems/local_connection.gd","systems/character_lobby.gd","systems/server_browser.gd","systems/native_server_browser.gd","systems/native_entry_menu_frame.gd","systems/native_gui_painter.gd","systems/native_data/session_catalog.gd"]: sources[path]=FileAccess.get_sha256("res://"+path)
	var report:={"success":failures.is_empty(),"failures":failures,"frames":frames,"cohorts":cohorts,"request_operations":requests.map(func(message): return str(message.get("operation",message.get("kind","")))),"record":record_path,"record_sha256":FileAccess.get_sha256(record_path),"sources":sources,"install":install,"secondary":root.current_screen!=DisplayServer.get_primary_screen(),"no_focus":root.get_flag(Window.FLAG_NO_FOCUS),"scope":"Installed original static browser art; actual ServerBrowser → LocalConnection join handoff and lobby/browser owners; recorded local NWSync progress values. Browser join envelope reconstructed because original recording used lobby join. No network, Arelith authority, dynamic row/scrollbar cohort, FPS, or original-client parity claim."}
	check(report.secondary and report.no_focus,"unfocused secondary window")
	report.success=failures.is_empty(); report.failures=failures
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print(JSON.stringify({"success":report.success,"failures":failures,"frames":frames.size(),"report":output}))
	browser.close_native(); painter.close(); catalog.release_ui_assets()
	browser.queue_free(); lobby.queue_free(); client.main_menu.queue_free(); painter.queue_free()
	await process_frame
	client.free()
	quit(0 if report.success else 1)
