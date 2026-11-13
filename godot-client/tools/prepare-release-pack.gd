extends SceneTree
# Package our own source only. Original game/server assets stay in their
# installed catalogs. Generated extension files change library paths only.
var files: Array=[]
var errors: Array=[]
func _initialize() -> void:call_deferred("run")
func collect(directory: String) -> void:
	var handle:=DirAccess.open("res://"+directory)
	if handle==null:errors.append("Cannot read source folder "+directory);return
	for name in handle.get_files():
		if name.get_extension() in ["gd","gdshader","gdshaderinc","tscn","tres","svg","json"]:files.append(directory.path_join(name))
	for name in handle.get_directories():
		if name not in [".cache",".godot",".tools","reports","backups"]:collect(directory.path_join(name))
func write(path: String,contents: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:errors.append("Cannot write generated pack input "+path);return
	file.store_string(contents);file.close()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("directory") or not args.has("report"):quit(2);return
	var directory:=str(args.directory);var output:=directory.path_join("NwnReleaseTest.pck")
	if FileAccess.file_exists(output) or FileAccess.file_exists(str(args.report)):quit(2);return
	var config:=ConfigFile.new();var loaded:=config.load("res://project.godot")
	if loaded!=OK:quit(2);return
	config.set_value("application","run/main_scene","res://__release_boot.tscn")
	if config.save(directory.path_join("project.godot"))!=OK:quit(2);return
	write(directory.path_join("boot.tscn"),'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://__release_boot.gd" id="1"]\n[node name="ReleaseTestBoot" type="Node"]\nscript = ExtResource("1")\n')
	write(directory.path_join("boot.gd"),'extends Node\nfunc _ready() -> void:\n\tvar entry:=""\n\tfor argument in OS.get_cmdline_user_args():\n\t\tif argument.begins_with("--release-entry="):entry=argument.trim_prefix("--release-entry=")\n\tif not entry.begins_with("res://tests/") and entry not in ["res://native_session_world.gd","res://tools/native_prework_worker.gd"]:\n\t\tpush_error("Invalid packaged test entry");get_tree().quit(2);return\n\tvar main_script: Script=load(entry)\n\tif main_script==null or not main_script.can_instantiate():\n\t\tpush_error("Packaged test script is unavailable");get_tree().quit(2);return\n\tvar loop:=get_tree()\n\tloop.set_script(main_script)\n\tloop.call("_initialize")\n\tqueue_free()\n')
	var pack:=PCKPacker.new();var started:=pack.pck_start(output)
	if started!=OK:quit(2);return
	collect("");files.sort()
	var receipts: Array=[]
	for name in files:
		var source: String="res://"+str(name)
		if pack.add_file(source,source)!=OK:errors.append("Cannot pack "+name)
		receipts.append({"path":name,"sha256":FileAccess.get_sha256(source)})
	for name in ["native/window_modes.c","tools/build-window-modes.ps1",".cache/native-window/build-manifest.json"]:
		var source: String="res://"+str(name)
		if not FileAccess.file_exists(source) or pack.add_file(source,source)!=OK:errors.append("Cannot pack native mode-query verification "+str(name))
		receipts.append({"path":name,"sha256":FileAccess.get_sha256(source)})
	for pair in [["res://project.godot","project.godot"],["res://__release_boot.gd","boot.gd"],["res://__release_boot.tscn","boot.tscn"]]:
		if pack.add_file(pair[0],directory.path_join(pair[1]))!=OK:errors.append("Cannot pack generated entry "+pair[0])
	var extensions: Array=[]
	for name in ["particle_kernel","resource_index"]:
		var extension:=ConfigFile.new();var relative: String="native/"+str(name)+".gdextension"
		if extension.load("res://"+relative)!=OK:errors.append("Missing native extension "+name);continue
		for platform in extension.get_section_keys("libraries"):
			var library:=str(extension.get_value("libraries",platform))
			if library.begins_with("res://"):extension.set_value("libraries",platform,ProjectSettings.globalize_path(library))
		var generated:=directory.path_join(name+".gdextension")
		if extension.save(generated)!=OK or pack.add_file("res://"+relative,generated)!=OK:errors.append("Cannot pack native extension "+name)
		extensions.append("res://"+relative)
	write(directory.path_join("extension_list.cfg"),"\n".join(extensions)+"\n")
	if pack.add_file("res://.godot/extension_list.cfg",directory.path_join("extension_list.cfg"))!=OK:errors.append("Cannot pack extension list")
	for name in ["global_script_class_cache.cfg","uid_cache.bin"]:
		var source: String="res://.godot/"+str(name)
		if FileAccess.file_exists(source) and pack.add_file(source,source)!=OK:errors.append("Cannot pack source script lookup "+name)
	var flushed:=pack.flush()
	if flushed!=OK:errors.append("Pack flush failed: "+str(flushed))
	var report:={"success":errors.is_empty(),"errors":errors,"source_files":receipts,"pack":output,"pack_sha256":FileAccess.get_sha256(output),"original_game_assets_packed":false,"generated_entry":"Existing SceneTree script is attached by a tiny packed boot scene; original source algorithms are unchanged.","extension_paths":"Absolute paths to the identical verified local native libraries"}
	write(str(args.report),JSON.stringify(report,"\t"));quit(0 if errors.is_empty() else 1)
