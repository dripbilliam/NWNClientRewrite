extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","models","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();var failures: Array=[];var models: Array=[]
	if not catalog.mount_install(args.install):failures.append(catalog.failure)
	else:
		for name in str(args.models).split(","):
			var bytes:=catalog.get_resource(name,2002);var parser:=Actor.new();var model:=parser.parse(bytes)
			if not catalog.failure.is_empty() or not parser.failure.is_empty():failures.append(name+": "+catalog.failure+parser.failure);continue
			var nodes: Array=[]
			for node in model.nodes:
				nodes.append({"name":node.name,"parent":node.parent,"position":node.position,"orientation":node.orientation,"light":node.get("light",{}),"reference":node.get("reference",{})})
			models.append({"name":name,"sha256":Cache.digest(bytes),"nodes":nodes,"animations":model.animations.map(func(clip):return {"name":clip.name,"length":clip.length})})
	var result:={"success":failures.is_empty(),"checks":models.size(),"failures":failures,"models":models,"publicConnections":0,"scope":"Read-only installed original light-model metadata; no model instantiation, rendering, network or active-server override acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
