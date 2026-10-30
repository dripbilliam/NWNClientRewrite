extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var names: Array=["ctl_pre_btn_char","ctl_pre_btn_plyr","ctl_playmod_page","ctl_pre_btn_tab","ctl_pre_btn_tab2","pmod_details800","ctl_pre_plyrlist","scrollbar_simple","pb_scrl_up","pb_scrl_down","pnl_chrsht2","pnl_chrsht_char2","pnl_chrsht_skil2"]
func visit(node: Dictionary) -> void:
	var resource:=str(node.get("Obj_ResRef","")).to_lower()
	if not resource.is_empty() and not names.has(resource): names.append(resource)
	for child in node.get("Obj_ChildList",[]): visit(child)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var decoder:=Assets.new(); var failures: Array=[]; var models: Dictionary={}
	if not catalog.mount_install(install): failures.append(catalog.failure)
	var raw: PackedByteArray=catalog.get_resource("pre_playmod",2047); var gui:=decoder.decode(raw,2047,"gff","")
	if not str(gui.error).is_empty(): failures.append(gui.error)
	else: visit(gui.value.root)
	for name in names:
		var bytes: PackedByteArray=catalog.get_resource(name,2002); var parsed:=decoder.decode(bytes,2002,"mdl-original","")
		if not str(parsed.error).is_empty(): failures.append(str(name)+": "+str(parsed.error)); continue
		var model:=Geometry.model(parsed.value)
		if not str(model.error).is_empty(): failures.append(str(name)+": "+str(model.error)); continue
		var hooks: Dictionary={}
		for key in model.hooks: hooks[key]=[model.hooks[key].x,model.hooks[key].y]
		models[name]={"bytes":bytes.size(),"sha256":Cache.digest(bytes),"bounds":[model.bounds.position.x,model.bounds.position.y,model.bounds.size.x,model.bounds.size.y],"hooks":hooks,"drawn":model.drawn,"animations":parsed.value.get("animations",[]).map(func(a):return str(a.get("name","")))}
	decoder.free(); var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":models.size(),"failures":failures,"gui":gui.value.get("root",{}),"guiSha256":Cache.digest(raw),"models":models,"publicConnections":0,"scope":"Read-only original character-chooser layout/model/hooks, no pixels or UI/action parity accepted."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
