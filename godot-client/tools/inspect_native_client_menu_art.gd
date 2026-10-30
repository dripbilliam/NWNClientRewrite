extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var assets:=Assets.new(); var rows: Dictionary={}; var failures: Array=[]
	var captions: Dictionary={}
	if not catalog.mount_install(install): failures.append(catalog.failure)
	var gui:=preload("res://systems/native_data/gff_document.gd").new().parse(catalog.get_resource("pre_main",2047),"GUI ")
	for child in gui.root.get("Obj_ChildList",[]): captions[str(child.get("Obj_Tag",""))]=child.get("Obj_Caption",{})
	for name in ["ctl_chk_pre","ctl_btn_pre_176","ctl_btn_x"]:
		var raw:=catalog.get_resource(name,2002); var decoded:=assets.actor_data(catalog,name,raw,ProjectSettings.globalize_path("user://native-prepared-v2"),[],{})
		if not str(decoded.get("error","")).is_empty(): failures.append(str(decoded.error)); continue
		var rig:=assets.rig_data(decoded.value,decoded.get("animation_sources",[]),ProjectSettings.globalize_path("user://native-prepared-v2"))
		rows[name]={"sha256":Cache.digest(raw),"source_keys":decoded.value.keys(),"supermodel":decoded.value.get("supermodel",""),"clips":rig.get("clips",[]),"nodes":decoded.value.nodes.map(func(node):return {"name":node.name,"parent":node.parent,"alpha":node.get("alpha",1),"position":node.position,"features":node.features,"mesh_keys":node.get("mesh",{}).keys()})}
	assets.free(); var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":rows.size(),"failures":failures,"publicConnections":0,"models":rows,"captions":captions,"scope":"Original native menu actor/clip/caption inspection; no full UI parity claim."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
