extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); var good:=catalog.mount_install(args.install); var parser:=Actor.new(); var model:=parser.parse(catalog.get_resource("ctl_ig_plreffect",2002)); var nodes: Array=[]
	for node in model.nodes:
		var mesh: Dictionary=node.get("mesh",{})
		if not mesh.get("render",false): continue
		nodes.append({"name":node.name,"parent":node.parent,"position":node.position,"vertices":Array(mesh.vertices),"indices":Array(mesh.indices),"uv":mesh.uv.map(func(value):return Array(value)),"textures":mesh.textures,"material":mesh.get("material",{}),"alpha":node.get("alpha",1)})
	var result:={"success":good and parser.failure.is_empty(),"checks":nodes.size(),"error":parser.failure,"nodes":nodes,"animations":model.animations,"publicConnections":0,"graphical":false}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if result.success else 1)
