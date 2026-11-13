extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); var mounted:=catalog.mount_install(args.install); var models: Dictionary={}
	if not mounted: failures.append(catalog.failure)
	for name in ["but_chat_reply","edit_chat_left","edit_chat_right","edit_chat_main"]:
		var bytes:=catalog.get_resource(name,2002); var parser:=Actor.new(); var model:=parser.parse(bytes); var geometry:=Geometry.model(model); checks+=1
		if not parser.failure.is_empty() or not str(geometry.error).is_empty(): failures.append(name+": "+parser.failure+str(geometry.error))
		var nodes: Array=[]
		for node in model.get("nodes",[]):
			var mesh: Dictionary=node.get("mesh",{})
			nodes.append({"name":node.name,"parent":node.parent,"position":node.position,"orientation":node.orientation,"scale":node.get("scale",1),"mesh":mesh})
		models[name]={"sha256":preload("res://systems/native_data/prepared_cache.gd").digest(bytes),"geometry":geometry,"nodes":nodes,"animations":model.get("animations",[])}
	var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"models":models,"publicConnections":0,"scope":"Read-only original chat reply geometry, hooks, raster names and animation data; no rendering or gameplay."},"  ")+"\n"); output.close(); catalog=null; quit(0 if failures.is_empty() else 1)
