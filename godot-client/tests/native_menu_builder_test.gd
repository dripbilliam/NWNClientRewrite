extends SceneTree
const Builder=preload("res://systems/native_menu_builder.gd")
const Options=preload("res://systems/native_render_settings.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Inventory=preload("res://systems/native_inventory_frame.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message); print("FAIL ",message)
func run() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1280,800)
	var host:=Control.new(); root.add_child(host)
	var invalid:=Builder.build(host,[{"kind":"button","id":"same"},{"kind":"label","id":"same"}])
	check(not str(invalid.error).is_empty() and host.get_child_count()==0,"A duplicate definition cannot partially publish controls into a live menu")
	invalid=Builder.build(host,[{"kind":"column","children":[{"kind":"unknown"}]}])
	check(not str(invalid.error).is_empty() and host.get_child_count()==0,"Invalid nested definitions leave the existing window untouched")
	invalid=Builder.build(host,[{"kind":"button","properties":{"script":"invalid"}}])
	check(not str(invalid.error).is_empty() and host.get_child_count()==0,"Menu definitions cannot install behavior instead of describing controls")
	var a:=Options.new(); host.add_child(a); a.setup(output+".a.cfg","")
	var b:=Options.new(); host.add_child(b); b.setup(output+".b.cfg","")
	check(a.tabs.get_tab_count()==5 and b.tabs.get_tab_count()==5,"One definition constructs both complete five-page Client Options instances")
	check(a.particles_toggle!=b.particles_toggle and a.prework_content!=b.prework_content,"Constructed menus never share mutable widget instances")
	check(not a.particles_enabled and not b.particles_enabled and not a.creature_slots,"Definition construction preserves default-off gameplay preferences")
	var actions: Array=[]
	a.particles_changed.connect(func(value):actions.append(["particles",value]))
	a.prework_requested.connect(func():actions.append(["prework"]))
	a.ui_preload_requested.connect(func():actions.append(["ui-preload"]))
	a.prework_workers_changed.connect(func(value):actions.append(["workers",value]))
	a.particles_toggle.button_pressed=true
	check(actions==[["particles",true]] and a.particles_enabled and not b.particles_enabled,"The definition's checkbox updates only its owning controller")
	var saved:=ConfigFile.new(); saved.load(output+".a.cfg")
	check(saved.get_value("rendering","particles_enabled",false),"Controller-owned preference persistence remains functional after construction moves")
	a.set_prework_sources(["Owned local assets"],false)
	a.prework_prepare.pressed.emit(); a.ui_preload_prepare.pressed.emit()
	check(actions.slice(1)==[["prework"],["ui-preload"]],"Separate model/UI-preload actions remain connected to their owning signals")
	a.prework_workers.select(a.prework_workers.get_item_index(8)); a.prework_workers.item_selected.emit(a.prework_workers.selected)
	check(actions.back()==["workers",8] and a.prework_worker_setting==8,"Choice controls retain stable worker IDs rather than using their row number")
	a.update_prework({"active":true,"total":10,"completed":3,"message":"Working"})
	check(a.prework_prepare.disabled and a.ui_preload_prepare.disabled and not a.prework_cancel.disabled and a.prework_progress.value==3,"Dynamic busy/progress state updates the built controls without rebuilding the menu")
	a.update_prework({"active":false,"message":"Ready"}); a.update_ui_preload({"active":true,"total":8,"completed":2,"message":"Preloading"})
	check(a.prework_prepare.disabled and not a.ui_preload_cancel.disabled and a.ui_preload_progress.value==2,"Model preparation and UI preload preserve their mutual exclusion")
	var painter_script: GDScript=Painter; var inventory_script: GDScript=Inventory
	check(painter_script.get_base_script()==null and inventory_script.get_base_script()==painter_script,"The common painter no longer depends on inventory implementation")
	# Load every migrated adapter: failures here catch source-only compile paths
	# that an isolated options test would not instantiate.
	for name in ["native_character_lobby","native_character_sheet_frame","native_confirmation","native_direct_connect","native_entry_menu_frame","native_examine_frame","native_gold_transfer","native_journal_frame","native_key_settings","native_lobby_pages","native_lobby_record_feats","native_players_frame","native_player_profile","native_server_browser","native_server_details","native_server_filters","native_server_password","native_spellbook_frame","native_video_options","native_barter_view","native_map_note_editor"]:
		var script=load("res://systems/"+name+".gd")
		check(script is GDScript and script.can_instantiate(),"Migrated source adapter compiles: "+name)
	a.free(); b.free(); host.free(); await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Shared definition construction, instance separation, real settings ownership/persistence/signals/busy state and migrated adapter compilation. Graphical input is covered separately."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
