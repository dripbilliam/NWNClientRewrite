extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var install:=""; var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--report="): output=arg.substr(9)
	if install.is_empty() or output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog=preload("res://systems/native_data/resource_catalog.gd").new()
	if not catalog.mount_install(install): quit(2); return
	var bytes: PackedByteArray=catalog.get_resource("pregen",2017); var table=preload("res://systems/native_data/two_da.gd").new(); var value: Dictionary=table.parse(bytes.get_string_from_utf8())
	var files: Array=[]
	for file in DirAccess.get_files_at(install.path_join("data/lcv")):
		if file.get_extension().to_lower()=="bic": files.append(file)
	var out:=FileAccess.open(output,FileAccess.WRITE); out.store_string(JSON.stringify({"success":catalog.failure.is_empty() and table.failure.is_empty(),"table":value,"files":files,"pregenSha256":preload("res://systems/native_data/prepared_cache.gd").digest(bytes),"publicConnections":0},"  ")); out.close(); quit()
