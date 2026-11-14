extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Preloader=preload("res://systems/native_data/ui_icon_texture_preloader.gd")
const SpellIcons=preload("res://systems/native_data/spellbook_icon_sources.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func wait_for(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+60000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or install.is_empty() or FileAccess.file_exists(report): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original game install mounts read-only")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-item-icon-oracle-v1.json"))
	var item_name:=""
	for entry in oracle.get("cases",[]):
		if entry.get("error",false) or int(entry.get("gender",-1))!=0 or str(entry.get("plan",{}).get("kind",""))!="flat": continue
		var selected: Dictionary=entry.get("selected",{})
		if not selected.is_empty() and not selected.get("layers",[]).is_empty(): item_name=str(selected.layers[0].name); break
	var spell_name:=""
	for name in SpellIcons.referenced(catalog):
		if str(name)!=item_name and not catalog.raster_location(str(name)).is_empty(): spell_name=str(name); break
	check(not item_name.is_empty() and not spell_name.is_empty(),"Installed item and spell raster sources are available")
	var icons:=Preloader.new(); root.add_child(icons); icons.configure(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"),[item_name,spell_name])
	var texture_events: Array=[]; var finish_events: Array=[]
	icons.texture_ready.connect(func(name,texture):texture_events.append({"name":name,"size":Vector2i(texture.get_width(),texture.get_height())}))
	icons.completed.connect(func(stats):finish_events.append(stats.duplicate(true)))
	var actual: Array=icons.discover()
	icons.explicit_names=[]; var full: Array=icons.discover(); icons.explicit_names=[item_name,spell_name]
	check(actual.size()==2 and full.size()>100 and full.has(item_name) and full.has(spell_name),"Full installed item/spell enumeration includes both original raster families")
	icons.start(); check(await wait_for(func():return icons.finished),"Bounded worker decode and main-thread texture publication complete")
	var progress: Dictionary=icons.progress()
	check(progress.total==2 and progress.completed==2 and progress.failed==0 and finish_events.size()==1 and texture_events.size()==2,"Both original rasters publish once with exact progress and no failures")
	var owner=catalog.ui_asset_owner()
	check(not owner.lookup("raster",item_name).is_empty() and not owner.lookup("raster",spell_name).is_empty() and texture_events.all(func(row):return row.size.x>0 and row.size.y>0),"Completed item and spell textures remain resident in the catalog owner")
	icons.close(); icons.free()
	var reused:=Preloader.new(); root.add_child(reused); reused.configure(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"),[item_name,spell_name]); reused.start()
	check(reused.finished and reused.progress().reused==2 and reused.progress().retained==0 and reused.progress().failed==0,"A second pre-menu owner reuses resident textures without decoding again")
	var absent:=Preloader.new(); root.add_child(absent); absent.configure(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"),["nwn84_missing_original_icon"]); absent.start()
	check(absent.finished and absent.progress().missing==1 and absent.progress().failed==0 and absent.failure.is_empty(),"An absent original table reference finishes as a visible missing warning, not a decode failure")
	var diagnostic:={"item":item_name,"spell":spell_name,"full_count":full.size(),"progress":progress,"finish_events":finish_events,"texture_events":texture_events,"reuse":reused.progress(),"missing":absent.progress(),"owner":owner.snapshot()}
	absent.close(); absent.free()
	reused.close(); reused.free()
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
