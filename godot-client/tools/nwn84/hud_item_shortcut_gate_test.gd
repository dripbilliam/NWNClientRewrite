extends SceneTree
# Installed-content integration: a quickbar must never present a partly
# published set of exact item shortcut icons, including on a cached refresh.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
var checks:=0
var failures: Array=[]
var visible_records: Array=[]

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func wait_for(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+90000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return predicate.call()
func capture_visible(bar,desktop) -> void:
	if not bar.visible: return
	var all_keys_ready:=true
	for key in desktop.quickbar_item_keys.values():
		if not desktop.owner_ui.inventory.icons.textures.has(key): all_keys_ready=false
	visible_records.append({"all_keys_ready":all_keys_ready,"slot0_image":bar.buttons.has(0) and bar.buttons[0].image.texture!=null,"slot1_image":bar.buttons.has(1) and bar.buttons[1].image.texture!=null,"item_keys":desktop.quickbar_item_keys.size()})
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or install.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(1000,700)
	var surface:=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface)
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original game install mounts read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),report+".layout.cfg")
	check(await wait_for(func():return ui.tables_ready and ui.inventory.icon_tables_ready()),"Installed item icon tables prepare")
	var desktop=ui.desktop; var bar=desktop.quickbar
	bar.visibility_changed.connect(func():capture_visible(bar,desktop))
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-item-icon-oracle-v1.json"))
	var cases: Array=[]
	for kind in ["flat","armor","composite"]:
		for entry in oracle.get("cases",[]):
			if not entry.get("error",false) and int(entry.get("gender",-1))==0 and str(entry.get("plan",{}).get("kind",""))==kind:
				cases.append(entry); break
	check(cases.size()==3,"Three distinct original item icon families are available")
	if cases.size()==3:
		var actor:={"id":42,"objectType":5,"areaId":55,"appearance":{"gender":0},"replicated":{"name":{"text":"Shortcut icon test"},"position":[0,0,0]},"playerState":{"abilities":{"base":[10,10,10,10,10,10],"current":[10,10,10,10,10,10]},"combat":{"armorClass":12}}}
		var objects: Array=[actor]
		for index in 3:
			var item: Dictionary=cases[index].item.duplicate(true); item.name={"text":"Original item "+str(index)}; item.stackSize=1
			objects.append({"id":100+index,"objectType":6,"item":item})
		var bindings: Array=[]
		for index in 36: bindings.append({"type":1,"itemId":100+(0 if index==0 else 1 if index==1 else 2),"intParam":255} if index in [0,1,12] else {"type":0})
		ui.set_world(1,55,42,objects,{}, {"area":{"id":55},"ui":{"quickbar":bindings}})
		await wait_for(func():return desktop.quickbar_item_keys.size()==3 or bar.visible)
		check(desktop.quickbar_item_keys.has(0) and desktop.quickbar_item_keys.has(1) and desktop.quickbar_item_keys.has(12),"All three page0 and off-page item icons are requested before view admission")
		check(await wait_for(func():return bar.visible or not desktop.quickbar_frame.failure.is_empty()),"First quickbar item view settles")
		check(bar.visible and desktop.quickbar_frame.failure.is_empty(),"First item shortcut view is admitted")
		check(not visible_records.is_empty() and visible_records.all(func(row):return row.all_keys_ready and row.slot0_image and row.slot1_image and row.item_keys==3),"Every first-view reveal already contains both displayed item icons and all three prepared keys")
		var icons=ui.inventory.icons
		var owner=catalog.ui_asset_owner()
		check(desktop.quickbar_item_keys.values().all(func(key):return icons.textures.has(key) and not owner.lookup("item",key).is_empty()),"All page0 and off-page originals remain strongly resident")
		visible_records.clear(); desktop.refresh_quickbar()
		check(await wait_for(func():return bar.visible),"Cached item shortcut refresh reopens")
		check(not visible_records.is_empty() and visible_records.all(func(row):return row.all_keys_ready and row.slot0_image and row.slot1_image and row.item_keys==3),"Cached refresh never reveals a partially assigned item icon row")
	var diagnostic:={"visible_records":visible_records.duplicate(true),"item_keys":desktop.quickbar_item_keys.duplicate(),"item_errors":desktop.quickbar_icon_errors.duplicate(),"quickbar":desktop.quickbar_frame.snapshot(),"icon_stats":ui.inventory.icons.snapshot()}
	ui.close(); ui.free(); await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
