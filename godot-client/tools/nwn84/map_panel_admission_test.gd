extends SceneTree

const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Map=preload("res://systems/server_map.gd")
const MapSkin=preload("res://systems/native_map_frame.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")

class InventoryOwner extends Node:
	var frame_skin
class UiOwner extends Node:
	var inventory
	var controls
	var text
class DesktopOwner extends Node:
	var area_map
	var owner_ui
	var art
	var generation:=1
	var area_id:=1
	var actor_id:=1
	var target_prompt
	func prepare_map_level(_level: int) -> void: pass

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,850); root.set_flag(Window.FLAG_NO_FOCUS,true)
	if DisplayServer.get_screen_count()>1: root.current_screen=1
	var install:=""; var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--report="): report=arg.substr(9)
	var failures: Array[String]=[]
	var catalog=Catalog.new()
	if install.is_empty() or not catalog.mount_install(install): failures.append("Original installation failed to mount")
	var cache:=ProjectSettings.globalize_path("res://.cache/nwn84-map-art")
	var painter:=Painter.new(); root.add_child(painter); painter.configure_source(catalog,cache)
	var map:=Map.new(); root.add_child(map); map.setup("")
	var inventory:=InventoryOwner.new(); root.add_child(inventory); inventory.frame_skin=painter
	var ui:=UiOwner.new(); root.add_child(ui); ui.inventory=inventory; ui.controls=Control.new(); ui.add_child(ui.controls); ui.text=Talk.new(); ui.text.base.open_file(install.path_join("lang/en/data/dialog.tlk"))
	var desktop:=DesktopOwner.new(); root.add_child(desktop); desktop.area_map=map; desktop.owner_ui=ui; desktop.art=painter.art; desktop.target_prompt=Label.new(); desktop.add_child(desktop.target_prompt)
	var skin:=MapSkin.new(); desktop.add_child(skin); skin.configure(desktop,catalog,cache)
	var early_jobs: int=skin.assets.serial
	if early_jobs<MapSkin.STATIC.size()+1: failures.append("Installed map models and note layout were not requested before opening")
	for i in 600:
		if skin.jobs.is_empty(): break
		await process_frame
	if not skin.failure.is_empty() or not skin.jobs.is_empty(): failures.append("Installed static map preparation failed: "+skin.failure)
	var keys: Array=[]
	for name in skin.Plan.TOOLS.values():
		for clip in ["up","hilite","down"]: keys.append(painter.art.models.model_key(name,clip))
	for i in 600:
		if keys.all(func(key):return painter.art.textures.has(key) or painter.art.failed.has(key)): break
		await process_frame
	for key in keys:
		if not painter.art.textures.has(key): failures.append("Original map control did not prepare: "+key)
		elif painter.art.ui_assets.lookup("model",key).is_empty(): failures.append("Prepared map control was not strongly resident: "+key)
	var sent: Array=[]; map.request.connect(func(message):sent.append(message))
	map.open()
	if map.visible or sent.size()!=1 or str(sent[0].kind)!="map-open": failures.append("First-open map did not hold the window while requesting its view")
	if skin.assets.serial!=early_jobs: failures.append("First open repeated installed static model reads")
	map.receive({"kind":"map-view","viewId":2,"width":2,"height":2,"cells":[0,0,0,0],"controls":{"pin":1,"player":2,"hilite":1,"down":1}})
	if map.visible: failures.append("Received map data exposed unprepared generated artwork")
	for i in 600:
		if map.visible or not skin.failure.is_empty(): break
		await process_frame
	if not skin.failure.is_empty(): failures.append("Generated original map failed: "+skin.failure)
	if not map.visible or not skin.display_ready(): failures.append("The map did not appear after its generated frame and controls became resident")
	for request in skin.image_requests.values():
		if painter.art.ui_assets.lookup("model",str(request.key)).is_empty(): failures.append("Generated map image is not retained by the shared UI owner")
	map.receive({"kind":"map-view","viewId":3,"width":2,"height":2,"cells":[0,0,0,0],"controls":{"pin":1,"player":2,"hilite":1,"down":1}})
	if map.visible: failures.append("A replacement view bypassed map admission")
	for i in 120:
		if map.visible or not skin.failure.is_empty(): break
		await process_frame
	if not map.visible or not skin.display_ready(): failures.append("A replacement view with the same dimensions did not reopen from resident art")
	var generated_resource:=str(skin.definition.get("resource",""))
	map.close_map(); skin.close(); desktop.free(); ui.text.close(); ui.free(); inventory.free(); map.free(); painter.close(); painter.free()
	var result:={"success":failures.is_empty(),"staticModelRequests":early_jobs,"residentControlKeys":keys.size(),"generatedResource":generated_resource,"failures":failures,"scope":"Original installed static map model/layout preparation, generated area frame, shared control/background residency and first-open gate; no public server connection."}
	if not report.is_empty():
		var file:=FileAccess.open(report,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(result,"  ")+"\n"); file.close()
	print(JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
