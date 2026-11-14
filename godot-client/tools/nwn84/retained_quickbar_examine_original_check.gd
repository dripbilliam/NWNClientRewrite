extends SceneTree
# Installed-content graphical integration for two item shortcuts and both
# examine presentation sizes. No FPS measurement or client connection.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Service=preload("res://systems/native_item_icon_scene_service.gd")
var checks:=0
var failures: Array=[]

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		print("FAIL ",label)
func wait_until(predicate: Callable,seconds: int=90) -> bool:
	var deadline:=Time.get_ticks_msec()+seconds*1000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	return predicate.call()
func sample(cases: Array,kind: String,width_gate: int=0) -> Dictionary:
	for value in cases:
		if value.get("error",false) or int(value.get("gender",-1))!=0:continue
		if kind!="" and str(value.get("plan",{}).get("kind",""))!=kind:continue
		if width_gate==1 and int(value.plan.width)>=3:continue
		if width_gate==2 and int(value.plan.width)<3:continue
		return value
	return {}
func item_object(id: int,row: Dictionary) -> Dictionary:
	var item: Dictionary=row.item.duplicate(true)
	item.name={"text":"Original item "+str(id)}
	item.stackSize=1
	return {"id":id,"objectType":6,"item":item}
func write_report(path: String,data: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(data,"  ")+"\n");file.close()

func run() -> void:
	var options: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	if not options.has_all(["install","oracle","report"]) or FileAccess.file_exists(str(options.report)):
		quit(2);return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.size=Vector2i(1100,850)
	var primary:=DisplayServer.get_primary_screen()
	for screen in DisplayServer.get_screen_count():
		if screen!=primary:
			root.current_screen=screen
			root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80)
			break
	var catalog:=Catalog.new()
	check(catalog.mount_install(str(options.install)),"Installed original catalog")
	check(catalog.mount_erf(str(options.install).path_join("data/nwm/Prelude.nwm"),100000000),"Prelude model templates")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(options.oracle)))
	var flat: Dictionary=sample(oracle.get("cases",[]),"flat",1)
	var armor: Dictionary=sample(oracle.get("cases",[]),"armor",1)
	var wide: Dictionary=sample(oracle.get("cases",[]),"",2)
	check(not flat.is_empty() and not armor.is_empty() and not wide.is_empty(),"Three installed normal, armor and wide item examples")
	if not failures.is_empty():write_report(str(options.report),{"success":false,"checks":checks,"failures":failures});quit(1);return
	var surface:=SubViewport.new()
	surface.size=root.size
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	surface.gui_disable_input=false
	surface.handle_input_locally=true
	root.add_child(surface)
	var display:=TextureRect.new()
	root.add_child(display)
	display.texture=surface.get_texture()
	display.size=root.size
	display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var ui:=Gameplay.new()
	surface.add_child(ui)
	ui.configure(catalog,str(options.install),ProjectSettings.globalize_path("user://native-prepared-v2"),str(options.report)+".layout.cfg")
	check(await wait_until(func():return ui.tables_ready and ui.inventory.icon_tables_ready()),"Original UI and item tables prepare")
	check(ui.inventory.retained_item_icons and ui.inventory.icons is Service,"Whole item-icon system uses retained scene service")
	var actor:={"id":42,"objectType":5,"areaId":55,"appearance":{"gender":0},"replicated":{"name":{"text":"Retained icon test"},"position":[0,0,0]},"playerState":{"abilities":{"base":[10,10,10,10,10,10],"current":[10,10,10,10,10,10]},"combat":{"armorClass":12}}}
	var objects: Array=[actor,item_object(100,flat),item_object(101,armor),item_object(102,wide)]
	var bindings: Array=[]
	for index in 36:
		bindings.append({"type":1,"itemId":100,"secondaryItemId":101,"intParam":255} if index==0 else {"type":0})
	ui.set_world(1,55,42,objects,{}, {"area":{"id":55},"ui":{"quickbar":bindings}})
	var desktop=ui.desktop
	var bar=desktop.quickbar
	check(await wait_until(func():return desktop.quickbar_item_keys.has(0) and desktop.quickbar_secondary_keys.has(0)),"Quickbar requests primary and secondary item models")
	var primary_key: String=str(desktop.quickbar_item_keys.get(0,""))
	var secondary_key: String=str(desktop.quickbar_secondary_keys.get(0,""))
	check(not primary_key.is_empty() and not secondary_key.is_empty() and primary_key!=secondary_key,"Primary and secondary source keys are distinct")
	check(await wait_until(func():return bar.visible or not desktop.quickbar_frame.failure.is_empty()),"Retained quickbar first view settles")
	var quick_host=desktop.quickbar_frame.item_icon_host
	var quick_ready: bool=bar.visible and desktop.quickbar_frame.failure.is_empty() and is_instance_valid(quick_host) and quick_host.binding_ready("0") and quick_host.binding_ready("0:secondary")
	check(quick_ready,"Both item models reach the quickbar viewport draw receipt before reveal")
	check(quick_ready and quick_host.slots["0"].key==primary_key and quick_host.slots["0:secondary"].key==secondary_key,"Primary and secondary slots retain their own source identity")
	check(quick_ready and bar.buttons.has(0) and bar.buttons[0].image.texture==null and bar.buttons[0].secondary_image.texture==null,"Item shortcuts do not use raster icon textures")
	var icons=ui.inventory.icons
	var quick_models: Dictionary={}
	for key in [primary_key,secondary_key]:
		if icons.bundles.has(key):quick_models[key]=icons.bundles[key].icon_scene
		check(icons.bundles.has(key) and str(icons.bundles[key].icon_scene.presentation).begins_with("small"),"Quickbar selects original small GUI_ICON model for "+key)
	var examine=ui.examine
	var examine_skin=ui.examine_skin
	var narrow_message:={"type":"item","targetId":100,"revision":1,"name":{"text":"Narrow item"},"nativeBody":{"text":"Original narrow item"},"identified":true}
	examine.present(narrow_message)
	check(await wait_until(func():return examine.visible or not examine.admission_failure.is_empty()),"Narrow item examine settles")
	var normal_key: String=str(examine_skin.icon_key)
	var normal_ready: bool=examine.visible and examine.admission_failure.is_empty() and icons.bundles.has(normal_key) and is_instance_valid(examine_skin.item_icon_host) and examine_skin.item_icon_host.binding_ready("item")
	check(normal_ready,"Normal examine icon reaches its panel viewport draw receipt")
	check(normal_ready and str(icons.bundles[normal_key].icon_scene.presentation)=="normal","Narrow examine item selects normal GUI_ICON template")
	var wide_message:={"type":"item","targetId":102,"revision":2,"name":{"text":"Wide item"},"nativeBody":{"text":"Original wide item"},"identified":true}
	examine.present(wide_message)
	check(await wait_until(func():return examine.visible and examine_skin.icon_target==102 and examine_skin.item_icon_host.binding_ready("item") or not examine.admission_failure.is_empty()),"Wide item examine settles")
	var wide_key: String=str(examine_skin.icon_key)
	var wide_ready: bool=examine.visible and examine.admission_failure.is_empty() and icons.bundles.has(wide_key) and examine_skin.item_icon_host.binding_ready("item")
	check(wide_ready and str(icons.bundles[wide_key].icon_scene.presentation).begins_with("small"),"Wide examine item selects original small GUI_ICON template")
	check(wide_ready and examine_skin.item_icon_host.slots["item"].key==wide_key and wide_key!=normal_key,"Examine source revision replaces the prior model")
	var screenshot:=str(options.report)+".png"
	await process_frame
	await process_frame
	var frame_image: Image=root.get_texture().get_image() if RenderingServer.get_rendering_device()!=null else null
	if frame_image!=null and not frame_image.is_empty():frame_image.save_png(screenshot)
	var diagnostic:={"quickbar":{"visible":bar.visible,"failure":desktop.quickbar_frame.failure,"primary":primary_key,"secondary":secondary_key,"models":quick_models,"slots":quick_host.slots.keys() if is_instance_valid(quick_host) else [],"revision":quick_host.revision if is_instance_valid(quick_host) else -1,"presented":quick_host.presented_revision if is_instance_valid(quick_host) else -1},"examine":{"visible":examine.visible,"failure":examine.admission_failure,"normal":normal_key,"wide":wide_key,"normal_ready":normal_ready,"wide_ready":wide_ready,"art":examine_skin.art_snapshot()},"screenshot":screenshot,"scope":"Installed original item assets, quickbar primary and secondary retained models, narrow and wide item examine, graphical draw receipts and UI composite; no FPS or live server."}
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic}
	write_report(str(options.report),report)
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures,"screenshot":screenshot}))
	ui.close();ui.free();display.free();surface.free();await process_frame
	quit(0 if failures.is_empty() else 1)
