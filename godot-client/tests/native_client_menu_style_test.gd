extends "res://tests/native_quickbar_frame_test.gd"
const Painter=preload("res://systems/native_gui_painter.gd")
const Style=preload("res://systems/native_client_menu_style.gd")
const Settings=preload("res://systems/native_render_settings.gd")
const WindowPanel=preload("res://systems/draggable_panel.gd")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1280,800); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Shared client-menu style reads the actual original catalog")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var settings:=Settings.new(); surface.add_child(settings); settings.setup(output+".cfg",output+".layout.cfg")
	var ordinary:=WindowPanel.new(); surface.add_child(ordinary); ordinary.configure("Shared window","test-shared",Vector2.ZERO,""); ordinary.hide()
	var style:=Style.new(); surface.add_child(style); style.configure(painter)
	check(await wait_until(func():return style.presentation_ready),"Original menu button/check/arrow/close artwork and Galahad font finish without generic Godot substitutes")
	check(style.images.size()==11 and painter.art.failed.is_empty(),"All11 exact source model states resolve without missing artwork")
	check(style.images["check:uncheckedup"].get_image().get_data()!=style.images["check:checkedup"].get_image().get_data(),"Original unchecked and checked checkbox images are visibly distinct after source face-culling")
	check(settings.theme.default_font==painter.fonts.fonts[Style.FONT] and settings.theme.default_font_size==roundi(painter.fonts.metrics[Style.FONT].height),"Client settings inherit the original Galahad font at its native bitmap height")
	check(settings.theme.get_stylebox("normal","Button") is StyleBoxTexture and settings.theme.get_stylebox("normal","Button").texture==style.images["button:up"],"Flexible settings buttons use original pregame button pixels")
	check(settings.theme.get_icon("checked","CheckBox")==style.images["check:checkedup"] and settings.close_button.theme_type_variation=="ClientCloseButton","Settings checks and close control use the same original artwork family")
	check(ordinary.theme==settings.theme and ordinary.close_button.theme_type_variation=="ClientCloseButton","One theme publication updates ordinary windows and settings without per-menu subscriptions")
	var late:=WindowPanel.new(); late.configure("Late window","test-late",Vector2.ZERO,""); late.hide(); surface.add_child(late)
	check(late.theme==ordinary.theme and late.theme.default_font==painter.fonts.fonts[Style.FONT],"A window created after artwork publication inherits the same ready theme immediately")
	var source_panel:=StyleBoxEmpty.new(); late.add_theme_stylebox_override("panel",source_panel); style.refresh()
	check(late.get_theme_stylebox("panel")==source_panel and late.theme==ordinary.theme,"Theme updates preserve an original source frame's exact transparent panel override")
	settings.position=Vector2(100,80); settings.show(); await process_frame; await process_frame
	check(not settings.has_theme_stylebox_override("panel") and settings.heading.text=="Client Options" and settings.tabs.get_tab_count()==5,"One styled client-options shell retains all five existing settings pages")
	check(Rect2(Vector2.ZERO,Vector2(surface.size)).encloses(settings.get_global_rect()),"The menu fits the1280x800 viewport without clipping")
	check(not settings.particles_toggle.button_pressed and not settings.creature_toggle.button_pressed and not settings.compact_scenery_toggle.button_pressed,"Visual unification preserves particles/creature slots/compact scenery defaults")
	await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".graphics.png")==OK,"The actual styled Graphics viewport is retained for visual review")
	var tabs: TabBar=settings.tabs.get_tab_bar(); await click(tabs.get_global_transform_with_canvas()*tabs.get_tab_rect(2).get_center())
	check(settings.tabs.current_tab==2,"Actual pointer input switches to the Interface page")
	await click(settings.creature_toggle.get_global_rect().get_center())
	var config:=ConfigFile.new(); config.load(output+".cfg"); check(settings.creature_slots and config.get_value("interface","creature_slots",false),"The themed checkbox still persists its real preference")
	await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".interface.png")==OK,"The actual styled Interface viewport is retained for visual review")
	await click(settings.close_button.get_global_rect().get_center()); check(not settings.visible,"The original-art close button dismisses Client Options through its existing action")
	ordinary.free(); late.free(); style.close(); style.free(); settings.free(); painter.close(); painter.free(); await process_frame; await process_frame
	check(not has_meta("native_client_menu_theme"),"Retiring the style owner releases its tree-scoped theme publication")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"physicalMouseWarped":false,"scope":"Original-art shared client-menu style and actual native settings tab/check/close input at1280x800. Original ConfigWindow parity and full UI remain unfinished."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
