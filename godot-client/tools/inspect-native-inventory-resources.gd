extends SceneTree
# Offline original resource inspection only; no protocol or live session.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Model=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	var requested:=""
	var extra_models: PackedStringArray=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--gui="): requested=arg.substr(6)
		if arg.begins_with("--models="): extra_models=arg.substr(9).split(",",false)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new()
	if not catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")): quit(3); return
	var layouts: Dictionary={}; var models: Dictionary={}; var failure:=""
	for name in ([requested] if not requested.is_empty() else ["inv_panel","inv_container","inv_equip"]):
		if not catalog.has_resource(name,2047): continue
		var bytes: PackedByteArray=catalog.get_resource(name,2047); var parser:=Gff.new(); var document:=parser.parse(bytes,"GUI ")
		if not parser.failure.is_empty(): failure=parser.failure; break
		layouts[name]={"sha256":Cache.digest(bytes),"root":document.root}
	var names: Dictionary={"pnl_inv":true,"pnl_equip":true,"inv_box_10x6":true,"ctl_inv_btn_tab":true}
	for name in extra_models: names[str(name).to_lower()]=true
	if requested=="ingame_store":
		for index in 5: names["ctl_inv_sto_tab"+str(index+1)]=true
	for layout in layouts.values():
		names[str(layout.root.get("Obj_ResRef",""))]=true
		collect(layout.root,names)
	for name in names:
		if not catalog.has_resource(name,2002): continue
		var bytes: PackedByteArray=catalog.get_resource(name,2002); var parser:=Model.new(); var model:=parser.parse(bytes)
		if not parser.failure.is_empty(): failure=parser.failure; break
		models[name]={"sha256":Cache.digest(bytes),"animations":model.animations.map(func(clip):return str(clip.name)),"nodes":model.nodes.map(func(node):return {"name":node.name,"parent":node.parent,"position":node.position,"orientation":node.orientation,"scale":node.get("scale",1),"mesh":node.get("mesh",{})})}
		if name in extra_models:
			models[name].animation_data=model.animations
			models[name].deformation=model.nodes.map(func(node):return {"name":node.name,"features":node.get("features",{}),"skin":node.get("skin",{}),"flags":node.get("flags",0)})
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failure.is_empty(),"error":failure,"layouts":layouts,"models":models},"\t")); file.close()
	print("NATIVE_INVENTORY_RESOURCES ",layouts.size()," layouts / ",models.size()," models / ",failure); quit(0 if failure.is_empty() else 1)
func collect(root: Dictionary,names: Dictionary) -> void:
	for child in root.get("Obj_ChildList",[]):
		if child.has("Obj_ResRef"): names[str(child.Obj_ResRef)]=true
		collect(child,names)
