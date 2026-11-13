extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Channels=preload("res://systems/native_render/particle_channels.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var install:=""
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		elif arg.begins_with("--report="): report=arg.substr(9)
	if install.is_empty() or report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var catalog:=Catalog.new()
	if not catalog.mount_install(install): quit(1); return
	var bytes:=catalog.get_resource("c_jelly",2002)
	var parser:=Actor.new(); var model: Dictionary=parser.parse(bytes)
	var rig: Dictionary=parser.rig_asset(model)
	var rows: Array=[]
	for index in model.nodes.size():
		var node: Dictionary=model.nodes[index]
		if not node.has("emitter"): continue
		var channels:=Channels.new(); channels.configure(rig,index)
		var clip_birthrate: Array=[]
		for key in channels.clips:
			clip_birthrate.append({"clip":key,"birthrate":channels.clips[key].get("birthrate",null)})
		rows.append({"index":index,"name":node.name,"static_birthrate":node.emitter.get("birthrate",null),"render":node.emitter.get("render",null),"update":node.emitter.get("update",null),"clips":channels.clips.keys(),"clip_birthrate":clip_birthrate})
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":parser.failure.is_empty(),"rows":rows},"  ")); file.close(); quit(0)
