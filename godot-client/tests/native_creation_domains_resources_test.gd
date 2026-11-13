extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
var resources: Dictionary={}
var failures: Array=[]
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
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();var good:=catalog.mount_install(args.install)
	if not good:failures.append(catalog.failure)
	var bytes:=catalog.get_resource("cg_domain",2047);var parser:=Gff.new();var document:=parser.parse(bytes)
	if not parser.failure.is_empty():failures.append(parser.failure)
	var models: Dictionary={};var geometries: Dictionary={};var plan: Dictionary={}
	if failures.is_empty():
		collect(document.root)
		for helper in ["ctl_cg_btn_dom","ctl_cg_btn_left","ctl_cg_btn_right","scrollbar_simple","pb_scrl_up","pb_scrl_down"]:resources[helper]=true
		for name in resources:
			if str(name).is_empty():continue
			var decoder:=Actor.new();var model:=decoder.parse(catalog.get_resource(str(name),2002))
			if not decoder.failure.is_empty():failures.append(str(name)+": "+decoder.failure)
			models[name]=model;geometries[name]=Geometry.model(model)
		plan=Dialog.panel(document.root,models,[],[],{})
		if not str(plan.get("error","")).is_empty():failures.append(plan.error)
	var result:={"success":failures.is_empty(),"checks":3,"failures":failures,"sourceSha256":preload("res://systems/native_data/prepared_cache.gd").digest(bytes),"source":document.get("root",{}),"models":geometries,"plan":plan,"scope":"Read-only installed Domain GFF/model geometry and hooks. Resource inventory only, not input, original pixels, draft, server or gameplay acceptance.","gpu":false,"serverConnections":0}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(packed(result),"\t"));file.close();quit(0 if failures.is_empty() else 1)
