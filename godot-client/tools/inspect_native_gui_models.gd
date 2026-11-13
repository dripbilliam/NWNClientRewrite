extends SceneTree
# Read-only source model dimensions/hooks. Exports metadata, not mesh/art data.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _init() -> void: run.call_deferred()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["install","models","report"]) or FileAccess.file_exists(args.report): quit(2);return
	var catalog:=Catalog.new();var failures: Array=[];var rows: Array=[]
	if not catalog.mount_install(str(args.install)): failures.append(catalog.failure)
	for name in str(args.models).split(","):
		var raw: PackedByteArray=catalog.get_resource(name,2002);var parser:=Actor.new();var model:=parser.parse(raw)
		if not parser.failure.is_empty():failures.append(str(name)+": "+parser.failure);continue
		var geometry:=Geometry.model(model)
		if not str(geometry.error).is_empty():failures.append(str(name)+": "+str(geometry.error));continue
		var hooks: Dictionary={}
		for key in geometry.hooks: hooks[key]=[geometry.hooks[key].x,geometry.hooks[key].y]
		rows.append({"name":name,"sha256":Cache.digest(raw),"bounds":[geometry.bounds.position.x,geometry.bounds.position.y,geometry.bounds.size.x,geometry.bounds.size.y],"hooks":hooks,"clips":model.get("animations",[]).map(func(clip):return str(clip.get("name","")))})
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":rows.size(),"failures":failures,"models":rows,"publicConnections":0,"graphical":false,"scope":"Installed original GUI model metadata only. No pixels or original control/input parity."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
