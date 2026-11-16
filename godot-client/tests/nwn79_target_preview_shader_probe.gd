extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
func _initialize()->void:
	var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="):install=arg.substr(10)
	var catalog:=Catalog.new()
	if not catalog.mount_install(install):push_error(catalog.failure);quit(1);return
	var bytes: PackedByteArray=catalog.get_resource("inc_target",2069)
	if bytes.is_empty():push_error("Installed target shader is unavailable");quit(1);return
	var source:=bytes.get_string_from_utf8()
	print("INC_TARGET_SHA256=",source.sha256_text()," BYTES=",bytes.size())
	print(source)
	quit(0)
