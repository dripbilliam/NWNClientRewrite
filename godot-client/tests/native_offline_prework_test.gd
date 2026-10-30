extends SceneTree
const Settings=preload("res://systems/native_render_settings.gd")
const Controller=preload("res://systems/native_asset_prework.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Session=preload("res://native_session_world.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func write(path: String,bytes: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func wait_done(owner) -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while owner.state.active and Time.get_ticks_msec()<deadline: await process_frame
	check(not owner.state.active,"Offline preparation/cancel/clear drains its workers")
func click(control: Control) -> void:
	var point:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point; event.global_position=point; root.push_input(event,true); await process_frame
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-offline-prework-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var recorded:=folder.path_join("recorded"); DirAccess.make_dir_recursive_absolute(recorded.path_join("objects"))
	var raw:="newmodel authored\nbeginmodelgeom authored\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom authored\n".to_utf8_buffer()
	var sha:=Cache.digest(raw); write(recorded.path_join("objects").path_join(sha),raw)
	write(recorded.path_join("manifest.json"),JSON.stringify({"version":2,"complete":true,"availability":{"authored:2002":2},"resources":{"authored:2002":{"sha256":sha,"bytes":raw.size()}}}).to_utf8_buffer())
	var offline:={"recordedCatalog":recorded}; var cache_path:=folder.path_join("cache")
	var owner:=Controller.new(); root.add_child(owner)
	var settings:=Settings.new(); root.add_child(settings); settings.setup(folder.path_join("settings.cfg"),"")
	settings.set_prework_sources(["Installed game + local content","Downloaded test server"],false)
	check(settings.prework_available and not settings.prework_prepare.disabled,"Prepare is enabled with downloaded local content and no connection")
	check(settings.prework_content.selected==1 and settings.prework_scope.selected==1,"Offline menu defaults to downloaded content and all available models")
	owner.changed.connect(settings.update_prework)
	settings.prework_requested.connect(func():owner.start_sources(offline,cache_path,settings.prework_scope.selected==1))
	settings.prework_cancel_requested.connect(owner.cancel)
	settings.prework_clear_requested.connect(func():owner.clear_saved(cache_path))
	root.size=Vector2i(1100,800); settings.tabs.current_tab=settings.tabs.get_tab_count()-1; settings.show(); await process_frame; await process_frame
	await click(settings.prework_prepare); await wait_done(owner)
	check(int(owner.state.saved)==2 and int(owner.state.failed)==0,"Actual offline Prepare click indexes sources and persists static/animated model routes")
	check(owner.owned_catalog==null and owner.source_loader==null,"Offline source ownership is released after preparation")
	check(not settings.prework_prepare.disabled and not settings.prework_clear.disabled,"Prepare and Clear remain usable without a connection")
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(report+".png")
	settings.prework_prepare.pressed.emit(); await wait_done(owner)
	check(int(owner.state.reused)==2,"A subsequent offline action reuses saved model bundles")
	settings.prework_prepare.pressed.emit(); settings.prework_cancel.pressed.emit(); await wait_done(owner)
	check(str(owner.state.message).begins_with("Preparation cancelled"),"Cancellation is valid while offline catalog indexing is in flight")
	settings.prework_prepare.pressed.emit(); settings.prework_clear.pressed.emit(); await wait_done(owner)
	check(str(owner.state.message).begins_with("Cleared") and DirAccess.get_files_at(owner.store.directory).is_empty(),"Clear during offline indexing cancels admission and deletes only saved prework")
	settings.set_prework_sources(["Installed game + local content","Downloaded test server"],true)
	check(settings.prework_content.get_item_text(0)=="Current server","A live server adds its own isolated source instead of replacing downloaded choices")
	settings.set_prework_sources(["Installed game + local content","Downloaded test server"],false)
	check(not settings.prework_prepare.disabled,"Disconnecting does not disable offline prework")
	owner.close(); owner.queue_free(); settings.queue_free(); await process_frame; await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"public_connections":0,"scope":"Disconnected graphical Prepare control, data-only offline catalog mount, persistent model preparation, repeat reuse, indexing cancellation/flush and connected/disconnected source choices"}
	write(report,JSON.stringify(result,"\t").to_utf8_buffer()); print(JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
