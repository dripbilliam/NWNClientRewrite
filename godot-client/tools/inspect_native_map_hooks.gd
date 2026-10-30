extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var install:=""; var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var success:=catalog.mount_install(install); var rows: Dictionary={}
	for name in ["pnl_mapgen_10x10","ctl_map_panbar"]:
		var parser:=Actor.new(); var model:=parser.parse(catalog.get_resource(name,2002)); success=success and parser.failure.is_empty(); var selected: Array=[]
		for node in model.get("nodes",[]):
			if str(node.name).to_lower() in ["horizontalindicator","verticalindicator","min","max","thumb","plane02"]: selected.append({"name":node.name,"parent":node.parent,"position":node.position,"orientation":node.orientation,"scale":node.scale})
		rows[name]={"nodes":selected,"animations":model.get("animations",[])}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":success,"checks":2,"failures":[],"models":rows,"publicConnections":0,"scope":"Read-only original map hook rotations and panbar animation metadata. No visual acceptance."},"  ")+"\n"); file.close(); quit(0 if success else 1)
