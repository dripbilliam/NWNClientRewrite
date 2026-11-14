extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Queue=preload("res://systems/server_action_queue.gd")
const Table=preload("res://systems/native_data/two_da.gd")
class FakeDesktop extends Node:
	var art
	var owner_ui
	var target_prompt
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var install:="";var graphical:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="):install=arg.trim_prefix("--install=")
		elif arg=="--graphical":graphical=true
	if install.is_empty():quit(2);return
	if graphical:
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		var primary:=DisplayServer.get_primary_screen()
		for screen in DisplayServer.get_screen_count():
			if screen!=primary:
				root.current_screen=screen;root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80);break
		root.size=Vector2i(900,700)
	var catalog:=Catalog.new()
	if not catalog.mount_install(install):quit(3);return
	catalog.build_resource_index()
	var source: Dictionary=Table.new().parse(catalog.get_resource("actions",2017).get_string_from_ascii())
	var icons: Array[String]=[]
	for row in source.get("orderedRows",[]):
		for column in row:
			if str(column).to_lower()=="iconresref":
				var candidate:=str(row[column]).to_lower()
				if not catalog.raster_location(candidate).is_empty() and candidate not in icons:icons.append(candidate)
				break
		if icons.size()>=2:break
	if icons.size()<2:quit(4);return
	var icon: String=icons[0]
	var art:=Art.new();root.add_child(art);art.configure(catalog,"")
	var owner:=FakeDesktop.new();root.add_child(owner);owner.art=art;owner.target_prompt=Label.new();owner.add_child(owner.target_prompt);owner.target_prompt.hide()
	var queue:=Queue.new();root.add_child(queue);queue.setup(owner)
	queue.present([{"widgetSerial":1,"type":1,"group":1,"special":false,"icon":icon,"label":"Installed action"}])
	var shown_before_ready: bool=queue.visible and not queue.cohort_snapshot().ready
	var deadline:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline and not queue.visible and queue.artwork_failure.is_empty() and queue.failure.is_empty():await process_frame
	var cohort: Dictionary=queue.cohort_snapshot()
	var shared: Dictionary=catalog.ui_asset_owner().lookup("raster",icon)
	var success: bool=graphical and not shown_before_ready and cohort.ready and queue.visible and cohort.images_ready==cohort.images_expected and not shared.is_empty() and shared.texture!=null
	queue.present([{"widgetSerial":1,"type":1,"group":1,"special":false,"icon":icons[1],"label":"Changed installed action"}])
	var rebind_gated: bool=not queue.visible
	deadline=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline and not queue.visible and queue.artwork_failure.is_empty():await process_frame
	var second_shared: Dictionary=catalog.ui_asset_owner().lookup("raster",icons[1])
	success=success and rebind_gated and queue.visible and queue.cohort_snapshot().ready and not second_shared.is_empty()
	queue.present([{"widgetSerial":1,"type":1,"group":1,"special":false,"icon":"nwn84_absent_action_icon","label":"Missing original action"}])
	deadline=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline and queue.artwork_failure.is_empty():await process_frame
	var missing_gated: bool=not queue.visible and not queue.artwork_failure.is_empty() and owner.target_prompt.visible and owner.target_prompt.text.contains("nwn84_absent_action_icon")
	success=success and missing_gated
	queue.reset();success=success and not queue.visible and queue.rows.is_empty()
	print(JSON.stringify({"success":success,"icons":icons,"cohort":cohort,"shown_before_ready":shown_before_ready,"rebind_gated":rebind_gated,"missing_gated":missing_gated,"shared_raster":not shared.is_empty() and not second_shared.is_empty(),"failure":queue.failure}))
	queue.close();queue.free();art.close();art.free();owner.free()
	quit(0 if success else 1)
