extends SceneTree
# CPU-only source inspection. No viewport, image publication or server access.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Pose=preload("res://systems/native_data/gui_pose.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); var rows: Dictionary={}; var failures: Array=[]
	if not catalog.mount_install(args.install): failures.append(catalog.failure)
	var gff:=Gff.new(); var source:=gff.parse(catalog.get_resource("cg_portrait",2047))
	if not gff.failure.is_empty(): failures.append(gff.failure)
	for name in ["pnl_chr_portrait","ctl_cg_portraits","ctl_cg_mportrait","ctl_cg_bigportrt"]:
		var parser:=Actor.new(); var model:=parser.parse(catalog.get_resource(name,2002))
		if not parser.failure.is_empty(): failures.append(name+": "+parser.failure); continue
		var clips: Array=[]
		for clip in model.animations:
			var posed:=Pose.nodes(model,[{"clip":clip.name,"time":0.0}])
			var meshes: Array=[]
			if str(posed.error).is_empty():
				for node in posed.model.nodes:
					if not node.get("mesh",{}).get("render",false): continue
					meshes.append({"name":node.name,"scale":node.get("scale",1),"alpha":node.get("alpha",1),"position":node.position,"parent":node.parent,"mesh":node.mesh})
			clips.append({"name":clip.name,"length":clip.length,"tracks":clip.tracks,"posed":Geometry.model(posed.model) if str(posed.error).is_empty() else posed,"meshes":meshes})
		rows[name]={"rest":Geometry.model(model),"nodes":model.nodes,"clips":clips}
	var result:={"success":failures.is_empty(),"checks":rows.size(),"failures":failures,"source":source,"models":rows,"publicConnections":0,"scope":"Original portrait GUI/model transforms and states, CPU only; no graphical acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
