extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
const Radial=preload("res://systems/server_radial.gd")
const Table=preload("res://systems/native_data/two_da.gd")
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
	var table: Dictionary=Table.new().parse(catalog.get_resource("actions",2017).get_string_from_ascii())
	var icons: Array[String]=[]
	for row in table.get("orderedRows",[]):
		for column in row:
			if str(column).to_lower()=="iconresref":
				var candidate:=str(row[column]).to_lower()
				if not catalog.raster_location(candidate).is_empty() and candidate not in icons:icons.append(candidate)
				break
		if icons.size()>=2:break
	if icons.size()<2:quit(4);return
	var art:=Art.new();root.add_child(art);art.configure(catalog,"")
	var fonts:=Fonts.new();root.add_child(fonts);fonts.configure(catalog,"")
	var radial:=Radial.new();root.add_child(radial);radial.configure_art(art);radial.configure_text(fonts)
	radial.open_at(Vector2(450,350),1,Vector3.ZERO,false)
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":1,"depth":0,"title":"Original actions","entries":[{"slot":0,"label":"First action","icon":icons[0],"submenu":false,"disabled":false}]})
	radial.set_center("ir_use")
	art.bind(radial.icons[0],icons[0])
	var shown_before_ready: bool=radial.stage.visible and not radial.menu_art_snapshot().ready
	var deadline:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline and not radial.stage.visible and radial.menu_art_failure.is_empty():await process_frame
	var cohort: Dictionary=radial.menu_art_snapshot()
	var first_shared: Dictionary=catalog.ui_asset_owner().lookup("raster",icons[0])
	var success: bool=graphical and not shown_before_ready and radial.stage.visible and cohort.ready and cohort.images_ready==cohort.images_expected and cohort.fonts_ready==cohort.fonts_expected and not first_shared.is_empty()
	radial.text_preview_mode=2
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":2,"depth":0,"title":"Changed actions","entries":[{"slot":0,"label":"Second action","icon":icons[1],"submenu":true,"disabled":false}]})
	radial.set_center("ir_use");art.bind(radial.icons[0],icons[1])
	var rebind_gated: bool=not radial.stage.visible
	deadline=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline and not radial.stage.visible and radial.menu_art_failure.is_empty():await process_frame
	var second_shared: Dictionary=catalog.ui_asset_owner().lookup("raster",icons[1])
	var submenu_cohort: Dictionary=radial.menu_art_snapshot()
	success=success and rebind_gated and radial.stage.visible and submenu_cohort.ready and submenu_cohort.images_expected>=7 and not second_shared.is_empty()
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":3,"depth":0,"title":"Missing action","entries":[{"slot":0,"label":"Missing action","icon":"nwn84_absent_radial_icon","submenu":false,"disabled":false}]})
	radial.set_center("ir_use");art.bind(radial.icons[0],"nwn84_absent_radial_icon")
	deadline=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline and radial.menu_art_failure.is_empty():await process_frame
	var missing_explicit: bool=radial.stage.visible and radial.menu_art_failure.contains("nwn84_absent_radial_icon") and radial.hint.visible and not radial.buttons[0].visible
	success=success and missing_explicit
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":4,"depth":0,"title":"Cached action","entries":[{"slot":0,"label":"Cached action","icon":icons[0],"submenu":false,"disabled":false}]})
	radial.set_center("ir_use");art.bind(radial.icons[0],icons[0])
	deadline=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline and not radial.stage.visible and radial.menu_art_failure.is_empty():await process_frame
	var cached_reopen: bool=radial.stage.visible and radial.menu_art_snapshot().ready and radial.menu_art_failure.is_empty() and not radial.menu_art_pending
	success=success and cached_reopen
	print(JSON.stringify({"success":success,"icons":icons,"first_cohort":cohort,"submenu_cohort":submenu_cohort,"shown_before_ready":shown_before_ready,"rebind_gated":rebind_gated,"missing_explicit":missing_explicit,"cached_reopen":cached_reopen,"shared_raster":not first_shared.is_empty() and not second_shared.is_empty(),"failure":radial.menu_art_failure}))
	radial.reset();radial.free();fonts.close();fonts.free();art.close();art.free()
	quit(0 if success else 1)
