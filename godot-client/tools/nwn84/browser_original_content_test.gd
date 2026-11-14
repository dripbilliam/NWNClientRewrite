extends SceneTree
const Loader=preload("res://systems/native_data/session_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Entry=preload("res://systems/native_entry_menu_frame.gd")
const Browser=preload("res://systems/native_server_browser.gd")
const Direct=preload("res://systems/native_direct_connect.gd")
const Profile=preload("res://systems/native_player_profile.gd")
const Filters=preload("res://systems/native_server_filters.gd")
const Details=preload("res://systems/native_server_details.gd")
const Password=preload("res://systems/native_server_password.gd")
const Controller=preload("res://systems/server_browser.gd")

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		elif arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or FileAccess.file_exists(output) or not install.is_absolute_path(): quit(2); return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	var secondary:=-1
	for screen in DisplayServer.get_screen_count():
		if screen!=DisplayServer.get_primary_screen(): secondary=screen; break
	if secondary<0: quit(2); return
	root.current_screen=secondary
	root.position=DisplayServer.screen_get_position(secondary)+Vector2i(80,80)
	root.size=Vector2i(1100,800)
	var prepared: Dictionary=Loader.prepare({"install":install,"modsDirectory":"","disabledMods":[]})
	if not str(prepared.get("error","")).is_empty(): quit(3); return
	var catalog=prepared.catalog
	var text=Text.new()
	if not text.base.open_file(install.path_join("lang/en/data/dialog.tlk")): quit(3); return
	var painter=Painter.new(); root.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var controller=Controller.new(); root.add_child(controller); controller.configure_native(painter,text,catalog,"")
	var owners: Dictionary={"entry":controller.entry_menu,"browser":controller.native_browser,"direct":controller.direct_dialog,"profile":controller.profile_dialog,"filters":controller.filter_dialog,"details":controller.details_dialog,"password":controller.password_dialog}
	var started:=Time.get_ticks_msec()
	var deadline:=started+16000
	var snapshots: Dictionary={}
	while Time.get_ticks_msec()<deadline:
		await create_timer(0.1).timeout
		var terminal:=true
		for name in owners:
			var owner=owners[name]
			var cohort: Dictionary=owner.cohort_snapshot()
			snapshots[name]=cohort
			if not cohort.ready and cohort.failures.is_empty(): terminal=false
		if terminal: break
	var all_ready:=true
	for cohort in snapshots.values():
		if not cohort.ready: all_ready=false
	var opened: Dictionary={}
	var controller_gate: Dictionary={}
	var delayed: Dictionary={}
	var row_cohort: Dictionary={}
	if all_ready:
		var first_plan: Dictionary=owners.browser.definition.pages.Internet
		var highlight_key: String=painter.art.models.model_key(str(first_plan.highlight),"")
		var resident_highlight: Texture2D=painter.art.textures.get(highlight_key)
		row_cohort.highlight_prepared=resident_highlight!=null and owners.browser.static_cohort.images.any(func(image):return str(image.key)==highlight_key)
		opened.direct=owners.direct.open("localhost","",[1,1]); owners.direct.dismiss()
		opened.profile=owners.profile.open_profile("Tester",[1,1]); owners.profile.dismiss()
		opened.filters=owners.filters.open_filters({},[1,1]); owners.filters.dismiss()
		opened.password=owners.password.open_password([1,1]); owners.password.dismiss()
		opened.details=owners.details.present({"connection":1,"viewId":1,"details":{"host":"localhost","port":5121}}); owners.details.dismiss()
		owners.browser.set_view({"connection":1,"viewId":1,"tab":"Internet","rows":[],"busy":false})
		opened.browser=owners.browser.view_updates>0
		opened.entry=owners.entry.art_ready()
		controller.wanted=true; controller.entry_context=true; controller.entry_stage="browser"; controller.connection=1; controller.view_id=1; controller.state={"connection":1,"viewId":1,"tab":"Internet","rows":[],"busy":false}
		controller.refresh_entry()
		controller_gate.initial=owners.browser.visible and not controller.panel.visible
		var first: Dictionary=owners.browser.static_cohort.images[0]
		var image_target: Object=first.target.get_ref()
		var old_texture=image_target.get("texture")
		image_target.set("texture",null); painter.art.failed[first.key]=true
		controller.refresh_entry()
		controller_gate.failure_hides=not owners.browser.visible and controller.cohort_notice.visible and controller.cohort_notice.text.contains(str(first.key)) and owners.direct.art_ready()
		painter.art.failed.erase(first.key); image_target.set("texture",old_texture); controller.refresh_entry()
		controller_gate.restore=owners.browser.visible and not controller.cohort_notice.visible
		var sent: Array=[]
		controller.request.connect(func(message): sent.append(message))
		var selected:={"entryId":7,"host":"localhost","port":5121,"selected":true,"allowed":true,"passwordRequired":true,"serverName":"Fixture","moduleName":"Fixture","playerCount":1,"maximumPlayers":4,"minimumLevel":1,"maximumLevel":40,"pvpSetting":0}
		controller.entries={7:selected}; controller.selected=7
		controller.state={"connection":1,"viewId":2,"tab":"Internet","rows":[selected],"busy":false,"canJoin":true}
		controller.view_id=2; controller.refresh_entry()
		var row_button: Button=owners.browser.pages.Internet.rows[0] if not owners.browser.pages.Internet.rows.is_empty() else null
		var row_highlight: TextureRect=row_button.get_meta("browser_highlight") if is_instance_valid(row_button) and row_button.has_meta("browser_highlight") else null
		var row_labels: Array=row_button.get_meta("browser_labels",[]) if is_instance_valid(row_button) else []
		row_cohort.first_selected_row_uses_resident_highlight=is_instance_valid(row_highlight) and row_highlight.texture==resident_highlight
		row_cohort.first_row_fonts_ready=row_labels.size()==6 and row_labels.all(func(label):return str(label.get_meta("native_font_applied",""))==str(label.get_meta("native_font_resource","")))
		var password_image: Object=owners.password.static_cohort.images[0].target.get_ref()
		var password_texture=password_image.get("texture")
		password_image.set("texture",null); controller.refresh_entry()
		var current: Dictionary=owners.browser.pages.Internet
		delayed.password_button_disabled=current.buttons.connectbutton.disabled
		controller.connect_button.disabled=false; controller._join()
		delayed.no_early_join=sent.filter(func(message):return str(message.get("operation",""))=="join").is_empty() and not owners.password.visible
		controller.back()
		password_image.set("texture",password_texture)
		controller.state={"connection":1,"viewId":3,"tab":"Internet","rows":[selected],"busy":false,"canJoin":true}; controller.view_id=3; controller.entry_stage="browser"; controller.refresh_entry()
		delayed.back_or_view_change_cancels=sent.filter(func(message):return str(message.get("operation",""))=="join").is_empty() and not owners.password.visible and controller.pending_dialog.is_empty()
		for tab in ["History","Favorites"]:
			var plan: Dictionary=owners.browser.definition.pages[tab]
			var key: String=painter.art.models.model_key(str(plan.highlight),"")
			var resident: Texture2D=painter.art.textures.get(key)
			owners.browser.set_view({"connection":1,"viewId":4 if tab=="History" else 5,"tab":tab,"rows":[selected],"busy":false})
			var page: Dictionary=owners.browser.pages[tab]
			var button: Button=page.rows[0] if not page.rows.is_empty() else null
			var highlight: TextureRect=button.get_meta("browser_highlight") if is_instance_valid(button) and button.has_meta("browser_highlight") else null
			var labels: Array=button.get_meta("browser_labels",[]) if is_instance_valid(button) else []
			row_cohort[tab+"_highlight_ready"]=resident!=null and is_instance_valid(highlight) and highlight.texture==resident
			row_cohort[tab+"_fonts_ready"]=labels.size()==6 and labels.all(func(label):return str(label.get_meta("native_font_applied",""))==str(label.get_meta("native_font_resource","")))
		controller.wanted=false; controller.hide()
	var result:={"success":all_ready and opened.size()==owners.size() and not opened.values().has(false) and controller_gate.size()==3 and not controller_gate.values().has(false) and delayed.size()==3 and not delayed.values().has(false) and row_cohort.size()==7 and not row_cohort.values().has(false) and root.get_flag(Window.FLAG_NO_FOCUS) and root.current_screen!=DisplayServer.get_primary_screen(),"elapsed_ms":Time.get_ticks_msec()-started,"secondary":root.current_screen!=DisplayServer.get_primary_screen(),"no_focus":root.get_flag(Window.FLAG_NO_FOCUS),"cohorts":snapshots,"opened":opened,"controller_gate":controller_gate,"delayed":delayed,"row_cohort":row_cohort,"scope":"Installed original static multiplayer entry/browser/dialog content and first received selected-row asset reuse on all three tabs. Later scrollbar resizes remain separate; no FPS or original-client visual parity."}
	controller.close_native()
	painter.close()
	if catalog.has_method("release_ui_assets"): catalog.release_ui_assets()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")); file.close()
	quit(0 if result.success else 1)
