extends SceneTree
const Settings=preload("res://systems/native_render_settings.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var destination:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):destination=arg.trim_prefix("--report=")
	if destination.is_empty() or FileAccess.file_exists(destination):quit(2);return
	var config_path:=destination+".cfg"
	var holder:=CanvasLayer.new();root.add_child(holder)
	var settings:=Settings.new();holder.add_child(settings);settings.setup(config_path,"")
	check(settings.creature_shadow_detail==2 and settings.creature_shadow_select.get_selected_id()==2,"Absent preference matches native constructor default All2")
	var changes: Array=[];settings.creature_shadow_detail_changed.connect(func(value):changes.append(value))
	for mode in [1,0,2]:
		var index:=settings.creature_shadow_select.get_item_index(mode)
		settings.creature_shadow_select.select(index);settings.creature_shadow_select.item_selected.emit(index)
		var restored:=Settings.new();holder.add_child(restored);restored.setup(config_path,"")
		check(settings.creature_shadow_detail==mode and restored.creature_shadow_detail==mode and restored.creature_shadow_select.get_selected_id()==mode,"Actual option signal and reconstructed settings preserve native mode%d"%mode)
		restored.queue_free()
	check(changes==[1,0,2],"Every native setting emits its actual ID rather than UI row index")
	for invalid in [-1,3,1.5,true,"1",null]:
		var config:=ConfigFile.new();config.set_value("rendering","creature_shadow_detail",invalid);config.save(config_path)
		var rejected:=Settings.new();holder.add_child(rejected);rejected.setup(config_path,"")
		check(rejected.creature_shadow_detail==2,"Malformed option falls back to original default, never guessed role or light budget")
		rejected.queue_free()
	holder.queue_free();await process_frame;await process_frame
	var out:=FileAccess.open(destination,FileAccess.WRITE);out.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual native settings option/persistence; no world shadow/visual claim"}));out.close();quit(0 if failures.is_empty() else 1)
