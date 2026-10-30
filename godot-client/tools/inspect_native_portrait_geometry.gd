extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var assets:=Assets.new(); var rows: Dictionary={}; var failures: Array=[]
	if not catalog.mount_install(install): failures.append(catalog.failure)
	for name in ["pnl_chr_portrait","ctl_cg_bigportrt","ctl_cg_portraits","ctl_cg_mportrait","ctl_btn_pre_176"]:
		var raw:=catalog.get_resource(name,2002); var result:=assets.decode(raw,2002,"mdl-original","")
		if not str(result.error).is_empty(): failures.append(str(name)+": "+str(result.error)); continue
		var geometry:=Geometry.model(result.value); var meshes: Array=[]
		for node in result.value.nodes:
			if node.get("mesh",{}).get("render",false): meshes.append({"name":node.name,"textures":node.mesh.get("textures",[]),"uv":node.mesh.get("uv",[])})
		rows[name]={"geometry":geometry,"sha256":FileAccess.get_sha256(install.path_join("bin/win32/nwmain.exe")),"animations":result.value.get("animations",[]).map(func(row):return row.name),"meshes":meshes}
	assets.free(); var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":rows.size(),"failures":failures,"publicConnections":0,"models":rows,"scope":"Original source-model hooks, bounds, UVs and animation names; no full UI acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
