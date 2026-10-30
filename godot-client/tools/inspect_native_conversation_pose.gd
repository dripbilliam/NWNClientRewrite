extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Pose=preload("res://systems/native_data/gui_pose.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var failures: Array=[]; var samples: Array=[]
	if not catalog.mount_install(install): failures.append(catalog.failure)
	var parser:=Actor.new(); var source:=parser.parse(catalog.get_resource("pnl_dialog",2002)); var rig:=parser.rig_asset(source)
	if not parser.failure.is_empty(): failures.append(parser.failure)
	for height in [112,254,300,400,700]:
		var poses: Array=[{"clip":"size","time":(float(height)/100-0.64)/0.01/30}]; var sampled:=Pose.nodes(source,poses); var mesh:=Pose.compose(rig,poses)
		if not str(sampled.error).is_empty() or not str(mesh.error).is_empty(): failures.append(str(sampled.error)+str(mesh.error)); continue
		for index in mesh.meshes:
			if mesh.meshes[index].has("positions"):
				var node: Dictionary=sampled.model.nodes[int(index)].duplicate(); node.mesh=node.mesh.duplicate(); node.mesh.vertices=mesh.meshes[index].positions; sampled.model.nodes[int(index)]=node
		var geometry:=Geometry.model(sampled.model); var hooks: Dictionary={}
		for key in geometry.hooks: hooks[key]=[geometry.hooks[key].x,geometry.hooks[key].y]
		samples.append({"height":height,"bounds":geometry.bounds,"hooks":hooks})
	var tracks: Array=[]
	for clip in source.animations:
		for track in clip.tracks: tracks.append({"node":track.node,"property":track.property,"keys":track.frames})
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":samples.size(),"failures":failures,"tracks":tracks,"samples":samples,"publicConnections":0,"scope":"Original conversation size animation metadata only; no visible UI/action parity acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
