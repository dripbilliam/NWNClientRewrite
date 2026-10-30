extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""; var name:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--resource="): name=arg.substr(11)
	if output.is_empty() or install.is_empty() or name.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var failures: Array=[]; var result: Dictionary={}; var pool:=Pool.new()
	if not catalog.mount_install(install): failures.append(catalog.failure)
	var location: Dictionary=catalog.raster_location(name)
	if location.is_empty(): failures.append("Original raster unavailable")
	else:
		var decoder:=Assets.new(); result=decoder.decode(catalog.get_resource(name,int(location.type)),int(location.type),"raster",name); decoder.free()
		if not str(result.error).is_empty(): failures.append(result.error)
		else:
			var texture=pool.texture(result)
			if texture==null: failures.append(pool.failure)
			else: texture.get_image().save_png(output.trim_suffix(".json")+".png")
	pool.clear(); var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":1,"failures":failures,"resource":name,"publicConnections":0,"scope":"Read-only original raster decode, unmodified row orientation. No GUI/runtime parity accepted."})); file.close(); quit(0 if failures.is_empty() else 1)
