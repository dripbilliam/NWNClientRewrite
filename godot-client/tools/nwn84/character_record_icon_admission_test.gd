extends SceneTree

const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Lobby=preload("res://systems/character_lobby.gd")
var checks:=0
var failures: Array=[]

func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func wait_until(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+30000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return predicate.call()
func run() -> void:
	var install:=""; var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--report="): report=arg.substr(9)
	if install.is_empty() or report.is_empty(): quit(2); return
	root.size=Vector2i(1200,850); root.set_flag(Window.FLAG_NO_FOCUS,true)
	if DisplayServer.get_screen_count()>1: root.current_screen=1
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed source catalog mounts")
	check(not catalog.raster_location("ir_level3").is_empty(),"Original record icon exists")
	var text:=Talk.new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Installed text resolves")
	var painter:=Painter.new(); root.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("res://.cache/nwn84-record-icons"))
	var lobby:=Lobby.new(); root.add_child(lobby); lobby.configure_native(painter,text,catalog,ProjectSettings.globalize_path("res://.cache/nwn84-record-icons"))
	var native=lobby.native_chooser
	check(await wait_until(func():return native.layout_ready or not native.failure.is_empty()),"Original chooser layout builds")
	if native.layout_ready:
		lobby.apply_state({"connection":1,"state":{"phase":"character-selection","connected":true,"canSelect":true,"canCreate":false,"selected":"server:one","choices":[{"key":"server:one","label":"Original record icon test","source":"server"}]}})
		check(await wait_until(func():return native.visible and native.art_ready()),"Original chooser art admits the selection")
		var pane=native.record_feats
		native.record_index=2; native.sync_record_page()
		var entries: Array=[]
		for at in 30: entries.append({"icon":"ir_level3","name":"Installed feat "+str(at),"description":{}})
		pane.present_entries(entries,10)
		check(pane.icon_targets.size()==30,"Thirty record icons bind to installed source art")
		check(await wait_until(func():return pane.list.visible and not pane.icon_pending),"Cold visible rows admit after current icons bind")
		var first: TextureRect=pane.icon_targets[0].target.get_ref()
		var last: TextureRect=pane.icon_targets[-1].target.get_ref()
		var first_saved: Texture2D=first.texture
		var last_saved: Texture2D=last.texture
		check(first_saved!=null and last_saved==first_saved,"Installed icon texture is strongly shared across rows")
		first.texture=null; pane.icon_pending=true; pane.list.hide(); pane.check_icon_admission()
		check(not pane.list.visible,"Missing current viewport icon blocks list exposure")
		first.texture=first_saved; pane.check_icon_admission()
		check(pane.list.visible,"Restored current icon admits list")
		last.texture=null; pane.icon_pending=true; pane.list.hide(); pane.check_icon_admission()
		check(pane.list.visible,"Missing offscreen icon does not block initial viewport")
		var scroll_max: float=pane.list.get_v_scroll_bar().max_value-pane.list.get_v_scroll_bar().page
		pane.list.scroll_vertical=roundi(scroll_max); await process_frame
		check(scroll_max>0 and not pane.list.visible,"Scrolling to a missing icon hides only the current record list")
		last.texture=last_saved; pane.check_icon_admission()
		check(pane.list.visible and not pane.icon_pending,"Restoring newly visible icon admits the scrolled list")
		var diagnostic:={"rows":pane.rows.size(),"list_height":pane.list.size.y,"scroll_max":scroll_max,"last_row_y":pane.rows[-1].position.y,"texture_resident":not painter.art.ui_assets.lookup("raster","ir_level3").is_empty()}
		print("RECORD_ICON_ADMISSION ",JSON.stringify(diagnostic))
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Installed record icon current-viewport admission, cold source binding, offscreen independence and scroll reveal. No FPS measurement or server connection."}
	lobby.close_native(); lobby.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close()
	print(JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
