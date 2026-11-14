extends SceneTree

const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Loading=preload("res://systems/native_loading_screen.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
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
func current_image(screen,art) -> bool:
	if screen.art_key.is_empty() or screen.image.texture==null: return false
	var resident: Dictionary=art.ui_assets.lookup("model",screen.art_key)
	return not resident.is_empty() and screen.image.texture==resident.texture
func run() -> void:
	var install:=""; var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--report="): report=arg.substr(9)
	if install.is_empty() or report.is_empty(): quit(2); return
	root.size=Vector2i(1200,800); root.set_flag(Window.FLAG_NO_FOCUS,true)
	if DisplayServer.get_screen_count()>1: root.current_screen=1
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed loading-screen resources mount")
	var ui:=Gameplay.new(); root.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("res://.cache/nwn84-loading-preload"),report+".layout.cfg")
	var screen:=Loading.new(); root.add_child(screen); screen.configure(ui)
	check(screen.table_job>=0 and ui.desktop.art.models!=null,"Installed loadscreens table and original fallback panel start before an area")
	screen.begin(1,"Cold area",{"loadingScreen":2})
	check(screen.active and screen.veil.visible and screen.image.texture==null and not screen.art_notice.visible,"Cold area shows progress without a guessed fallback image")
	screen.advance(1,{"terrain":false,"player":false,"camera":false,"tiles":1,"total_tiles":2})
	check(screen.progress.value>0 and screen.veil.visible,"Progress remains visible while exact area art prepares")
	check(await wait_until(func():return current_image(screen,ui.desktop.art) or not screen.art_error.is_empty()),"Received area selects and prepares its exact original panel art")
	check(screen.art_error.is_empty() and current_image(screen,ui.desktop.art),"Cold area's exact replacement image is strongly resident and displayed")
	var first_name: String=screen.art_resource; var first_texture: Texture2D=screen.image.texture
	screen.begin(2,"Warm area",{"loadingScreen":2})
	check(screen.art_resource==first_name and screen.image.texture==first_texture and current_image(screen,ui.desktop.art),"Warm area reuses the prepared original image without a blank or stale frame")
	var next_row:=-1
	for row in range(3,screen.table.get("orderedRows",[]).size()):
		var name: String=str(Rules.cell(screen.table.orderedRows[row],"BMPResRef",""))
		if name not in ["","****",first_name] and not catalog.raster_location(name).is_empty(): next_row=row; break
	check(next_row>=3,"A distinct installed area image exists for replacement validation")
	if next_row>=3:
		screen.begin(3,"Changed area",{"loadingScreen":next_row})
		check(screen.art_resource!=first_name and (screen.image.texture==null or current_image(screen,ui.desktop.art)),"Changed area never exposes the previous area's image")
		check(await wait_until(func():return current_image(screen,ui.desktop.art) or not screen.art_error.is_empty()),"Changed area replacement art prepares")
		check(screen.art_error.is_empty() and current_image(screen,ui.desktop.art),"Changed area's exact replacement texture is displayed and resident")
	screen.begin(4,"Unavailable row",{"loadingScreen":9999})
	check(screen.art_error.contains("row unavailable") and screen.art_notice.visible and screen.progress.visible,"Missing received art row is reported beside the loading progress")
	var missing_rows: Array=screen.table.orderedRows.duplicate(true); missing_rows[2]={"BMPResRef":"nwn84_missing_original_bitmap"}; screen.table={"orderedRows":missing_rows}
	screen.begin(5,"Unavailable bitmap",{"loadingScreen":2})
	check(screen.art_error.contains("bitmap is missing") and screen.art_resource=="nwn84_missing_original_bitmap" and screen.art_notice.visible and screen.progress.visible,"Missing original replacement bitmap is reported with its requested resource")
	screen.reset()
	check(not screen.active and not screen.veil.visible and screen.art_key.is_empty() and screen.art_error.is_empty(),"Reset retires current art and notice without exposing a late callback")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"coldResource":first_name,"changedRow":next_row,"scope":"Installed loading table, exact original area replacement art, cold/warm/changed-area admission, visible progress and missing-row notice. No FPS measurement."}
	screen.free(); ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close()
	print(JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
