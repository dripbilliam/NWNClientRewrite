extends SceneTree
# Read-only source geometry inventory; no world, model rasterizer or GUI window.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); var mounted:=catalog.mount_install(str(args.install)); var records: Array=[]; var errors: Array=[]
	for name in catalog.resource_names(2002):
		if not str(name).to_lower().contains("bubble") and str(name).to_lower()!="but_popup_prtrt": continue
		var bytes: PackedByteArray=catalog.get_resource(str(name),2002); var parser:=Actor.new(); var model: Dictionary=parser.parse(bytes); var nodes: Array=[]
		if not parser.failure.is_empty(): errors.append({"resource":name,"error":parser.failure}); continue
		for node in model.get("nodes",[]):
			var mesh: Dictionary=node.get("mesh",{}); var entry:={"name":node.name,"parent":node.parent,"position":node.position,"orientation":node.orientation,"scale":node.get("scale",1),"alpha":node.get("alpha",1),"render":mesh.get("render",false)}
			if not mesh.is_empty(): entry.merge({"vertices":Array(mesh.get("vertices",PackedFloat32Array())),"indices":Array(mesh.get("indices",PackedInt32Array())),"uv":mesh.get("uv",[]).map(func(value):return Array(value)),"textures":mesh.get("textures",[]),"material":mesh.get("material",{})})
			nodes.append(entry)
		records.append({"resource":name,"bytes":bytes.size(),"sha256":Cache.digest(bytes),"nodes":nodes,"animations":model.get("animations",[])})
	var result:={"success":mounted and errors.is_empty() and not records.is_empty(),"checks":records.size(),"records":records,"errors":errors,"publicConnections":0,"graphical":false,"scope":"Original model metadata only; use original constructor/caller evidence before assigning these resources to world nameplates."}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); catalog=null; quit(0 if result.success else 1)
