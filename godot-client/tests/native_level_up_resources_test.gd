extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
var failures: Array=[]
var checks:=0
var resources: Dictionary={}
func _initialize() -> void:run.call_deferred()
func collect(node: Dictionary) -> void:
	resources[str(node.get("Obj_ResRef","")).to_lower()]=true
	for child in node.get("Obj_ChildList",[]):collect(child)
func packed(value: Variant) -> Variant:
	if value is Vector2:return [value.x,value.y]
	if value is Rect2:return {"position":packed(value.position),"size":packed(value.size)}
	if value is Array:return value.map(packed)
	if value is Dictionary:
		var out: Dictionary={}
		for key in value:out[key]=packed(value[key])
		return out
	return value
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed base catalog mounts read-only")
	var layouts: Dictionary={};var models: Dictionary={}
	for name in ["cg_levup_attrib","cg_lvlup_summary","cg_class"]:
		var bytes:=catalog.get_resource(name,2047);var parser:=Gff.new();var document:=parser.parse(bytes)
		check(parser.failure.is_empty() and not document.get("root",{}).is_empty(),"Original level-up GUI parses: "+name)
		layouts[name]={"sha256":preload("res://systems/native_data/prepared_cache.gd").digest(bytes),"root":document.get("root",{})}
		collect(document.get("root",{}))
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down","ctl_cg_btn_class"]:resources[name]=true
	for name in resources:
		if str(name).is_empty():continue
		var decoder:=Actor.new();var bytes:=catalog.get_resource(str(name),2002);var model:=decoder.parse(bytes)
		check(decoder.failure.is_empty(),"Original level-up model parses: "+str(name))
		var geometry:=Geometry.model(model);check(str(geometry.error).is_empty(),"Original level-up model hierarchy is valid: "+str(name))
		models[name]={"sha256":preload("res://systems/native_data/prepared_cache.gd").digest(bytes),"geometry":geometry}
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"layouts":layouts,"models":models,"scriptSha256":FileAccess.get_sha256(get_script().resource_path),"scope":"Read-only exact installed level-up GUI and MDL geometry. No controls/input/draft/server/pixel acceptance.","gpu":false,"serverConnections":0}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(packed(result),"\t"));file.close();quit(0 if failures.is_empty() else 1)
