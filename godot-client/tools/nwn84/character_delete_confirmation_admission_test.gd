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
	root.size=Vector2i(1200,800); root.set_flag(Window.FLAG_NO_FOCUS,true)
	if DisplayServer.get_screen_count()>1: root.current_screen=1
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed original confirmation catalog mounts")
	var text:=Talk.new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Installed confirmation text resolves")
	var painter:=Painter.new(); root.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("res://.cache/nwn84-delete-confirmation"))
	var lobby:=Lobby.new(); root.add_child(lobby); lobby.configure_confirmation(painter,text,catalog,ProjectSettings.globalize_path("res://.cache/nwn84-delete-confirmation"))
	var dialog=lobby.confirmation
	check(await wait_until(func():return dialog.layout_ready or not dialog.failure.is_empty()),"Original confirmation GUI/model construction completes")
	check(dialog.failure.is_empty() and dialog.layout_ready and not dialog.visible,"Confirmation remains hidden after layout construction")
	check(await wait_until(func():return dialog.art_ready() or not dialog.cohort_snapshot().failures.is_empty()),"Original confirmation image and font cohort settles")
	var cohort: Dictionary=dialog.cohort_snapshot()
	if not cohort.ready: print("CONFIRMATION_COHORT ",JSON.stringify(cohort))
	check(cohort.ready and cohort.images_expected>0 and cohort.fonts_expected>0 and cohort.images_ready==cohort.images_expected and cohort.fonts_ready==cohort.fonts_expected,"Every constructed confirmation image and font is ready before Delete can open it")
	var resident:=true; var target: Object=null; var key:=""
	for row in dialog.static_cohort.get("images",[]):
		if painter.art.ui_assets.lookup(str(row.kind),str(row.key)).is_empty(): resident=false
		if target==null and row.target.get_ref() is TextureRect: target=row.target.get_ref(); key=str(row.key)
	check(resident and target!=null,"Original confirmation art has strong catalog-scoped texture residency")
	if target!=null and painter.art.textures.has(key):
		var saved: Texture2D=target.get("texture")
		target.set("texture",null)
		check(not dialog.art_ready() and not dialog.ask(0x2910,0x42,0x43,[1,1]) and not dialog.visible,"A missing current panel image blocks the first confirmation reveal")
		target.set("texture",saved)
		check(dialog.art_ready(),"Restoring the exact resident image admits confirmation")
		var before: int=dialog.assets.serial
		var answers: Array=[]; dialog.answered.connect(func(result: int,_capture: Array):answers.append(result))
		check(dialog.ask(0x2910,0x42,0x43,[1,1]) and dialog.visible and dialog.message.text==text.raw({"strRef":0x2910}),"Admitted confirmation shows the original localized question")
		dialog.finish(2)
		check(not dialog.visible and answers==[2],"Cancel preserves original result 2 and closes the modal")
		check(dialog.ask(0x2910,0x42,0x43,[1,2]) and dialog.visible and dialog.assets.serial==before,"Warm reopen uses resident art without new source reads")
		dialog.finish(2)
		target.set("texture",null); painter.art.failed[key]=true
		check(not dialog.art_ready() and not dialog.ask(0x2910,0x42,0x43,[1,3]) and lobby.failure_text(text).contains("confirmation artwork unavailable"),"Corrupt original art blocks Delete and produces visible chooser failure text")
		painter.art.failed.erase(key); target.set("texture",saved)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Installed local Delete confirmation image/font residency, cold gate, warm reopen, cancel ownership and explicit art failure. No FPS measurement or character deletion."}
	lobby.close_native(); lobby.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close()
	print(JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
