extends SceneTree
# Real Client Options construction/input/persistence only. All preference paths
# are unique files below the isolated report directory, never the user's menu.
const Settings=preload("res://systems/native_render_settings.gd")
const Layout=preload("res://systems/native_data/client_options_layout.gd")
const Builder=preload("res://systems/native_menu_builder.gd")
var checks:=0
var failures: Array=[]
var signals: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func nodes_with_id(rows: Array,id: String) -> Array:
	var result: Array=[]
	for item in rows:
		if item.get("id","")==id:result.append(item)
		result.append_array(nodes_with_id(item.get("children",[]),id))
	return result
func click(control: Control) -> void:
	var point:=control.get_global_rect().get_center();var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;event.position=point;event.global_position=point;root.push_input(event,true);await process_frame
func preferences(path: String) -> Dictionary:
	var config:=ConfigFile.new();var error:=config.load(path)
	return {"error":error,"tile":config.get_value("rendering","tile_borders_enabled",null),"sentinel":config.get_value("unrelated","sentinel",null),"gamma":config.get_value("rendering","gamma",null)}
func create(path: String) -> Control:
	var settings:=Settings.new();root.add_child(settings);settings.setup(path,"");return settings
func file_state(path: String) -> Array:return [FileAccess.file_exists(path),FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""]
func run() -> void:
	var report:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report=argument.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	root.size=Vector2i(1200,900)
	var user_paths:=["user://native-options.cfg","user://native-menu-layout.cfg"];var user_before: Array=[]
	for path in user_paths:user_before.append(file_state(path))
	var prefix:=report.get_base_dir().path_join("private-preferences");DirAccess.make_dir_recursive_absolute(prefix)
	var path:=prefix.path_join("actual-input.cfg")
	var defaults:=Settings.new();check(defaults.tile_borders_enabled,"Native tile-border option initializes ON before preference loading")
	defaults.tile_borders_changed.connect(func(value):signals.append(value));root.add_child(defaults);defaults.setup(path,"")
	check(defaults.tile_borders_enabled and defaults.tile_borders_toggle.button_pressed,"Missing private config retains native default ON in real control")
	check(not FileAccess.file_exists(path) and signals.is_empty(),"Menu construction neither persists implicit defaults nor emits a user toggle")
	check(defaults.preference_path==path and defaults.settings_path.is_empty(),"Controller receives explicit private preference path and disabled layout persistence")
	check(not defaults.particles_enabled and not defaults.compact_scenery_enabled and defaults.gamma_value==2.2,"New border option leaves unrelated existing defaults intact")
	var definition:=Layout.definition();var entries:=nodes_with_id(definition,"tile_borders_toggle")
	check(entries.size()==1 and entries[0].kind=="check" and entries[0].properties.text=="Show scenery beyond area edges","One meaningful Graphics checkbox comes from shared Client Options definition")
	var host:=Control.new();root.add_child(host);var built:=Builder.build(host,definition)
	check(built.error.is_empty() and built.nodes.tile_borders_toggle is CheckBox and built.nodes.tile_borders_toggle!=defaults.tile_borders_toggle and built.nodes.tile_borders_toggle.text==defaults.tile_borders_toggle.text,"Shared MenuBuilder constructs separate controls from same definition")
	host.hide()
	var config:=ConfigFile.new();config.set_value("unrelated","sentinel","preserve-this-value");config.set_value("rendering","gamma",3.0);check(config.save(path)==OK,"Private config seeded without user preference writes")
	defaults.show();defaults.move_to_front();await process_frame;await process_frame
	check(defaults.tabs.current_tab==0 and defaults.tabs.get_tab_title(0)=="Graphics" and defaults.tile_borders_toggle.is_visible_in_tree(),"Actual Graphics pane exposes the border toggle")
	await click(defaults.tile_borders_toggle)
	var saved:=preferences(path)
	check(not defaults.tile_borders_enabled and not defaults.tile_borders_toggle.button_pressed and signals==[false],"Real pointer click disables border option and emits exactly one false")
	check(saved.error==OK and saved.tile is bool and saved.tile==false and saved.sentinel=="preserve-this-value" and saved.gamma==3.0,"Typed false persists while unrelated config values remain intact")
	var restored:=create(path)
	check(not restored.tile_borders_enabled and not restored.tile_borders_toggle.button_pressed and restored.tile_borders_toggle!=defaults.tile_borders_toggle,"Reconstructed menu reads saved OFF with independent widgets")
	defaults.tile_borders_toggle.button_pressed=false;check(signals==[false],"Assigning unchanged state does not duplicate toggle signal")
	await click(defaults.tile_borders_toggle);saved=preferences(path)
	check(defaults.tile_borders_enabled and defaults.tile_borders_toggle.button_pressed and signals==[false,true],"Real second click restores ON and emits exactly one true")
	check(saved.tile is bool and saved.tile==true and saved.sentinel=="preserve-this-value" and saved.gamma==3.0,"ON persists using same existing configuration owner")
	var restored_on:=create(path)
	check(restored_on.tile_borders_enabled and restored_on.tile_borders_toggle.button_pressed and not restored.tile_borders_enabled,"Reopen reads current preference without mutating older menu instances")
	var invalid_values: Array=["false",0,1,0.0,1.0,{},[]]
	var owned: Array=[defaults,restored,restored_on,host]
	for index in invalid_values.size():
		var invalid_path:=prefix.path_join("invalid-%d.cfg"%index);var invalid:=ConfigFile.new();invalid.set_value("rendering","tile_borders_enabled",invalid_values[index]);invalid.save(invalid_path)
		var menu:=create(invalid_path);owned.append(menu)
		check(menu.tile_borders_enabled and menu.tile_borders_toggle.button_pressed,"Malformed saved type retains native default ON: "+str(typeof(invalid_values[index])))
	for node in owned:node.queue_free()
	await process_frame;await process_frame
	var user_unchanged:=true
	for index in user_paths.size():user_unchanged=user_unchanged and file_state(user_paths[index])==user_before[index]
	check(user_unchanged,"Default user option/layout files were never created or changed")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"userPreferencesUnchanged":user_unchanged,"scope":"Existing native Client Options definition/shared MenuBuilder, native-default ON/strict saved BOOL loading, actual headless pointer toggle, controller signal/persistence/reopen and private-file isolation only. No tile scenery/world integration, native pixels, GPU or server acceptance.","gpu":false,"serverConnections":0}
	var output:=FileAccess.open(report,FileAccess.WRITE);output.store_string(JSON.stringify(result,"\t"));output.close();print("AREA_BORDER_SETTINGS ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
