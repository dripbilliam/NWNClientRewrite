extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""; var names: PackedStringArray=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--models="): names=arg.substr(9).split(",",false)
	if output.is_empty() or install.is_empty() or names.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var decoder:=Assets.new(); var failures: Array=[]; var results: Dictionary={}
	if not catalog.mount_install(install): failures.append(catalog.failure)
	for name in names:
		var raw: PackedByteArray=catalog.get_resource(name,2002); var data:=decoder.decode(raw,2002,"mdl-original","")
		if not str(data.error).is_empty(): failures.append(str(data.error)); continue
		var nodes: Array=[]
		for node in data.value.nodes:
			var mesh: Dictionary=node.get("mesh",{}); var points: PackedFloat32Array=mesh.get("vertices",PackedFloat32Array()); var bounds:=AABB(); var has_points:=false
			for at in range(0,points.size(),3):
				var point:=Vector3(points[at],points[at+1],points[at+2]); bounds=bounds.expand(point) if has_points else AABB(point,Vector3.ZERO); has_points=true
			nodes.append({"name":node.name,"parent":node.parent,"position":node.position,"alpha":node.get("alpha",1),"features":node.features,"render":mesh.get("render",false),"textures":mesh.get("textures",[]),"local_bounds":[bounds.position.x,bounds.position.y,bounds.position.z,bounds.size.x,bounds.size.y,bounds.size.z]})
		results[name]=nodes
	decoder.free(); var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":results.size(),"failures":failures,"models":results,"publicConnections":0,"scope":"Read-only original GUI mesh/hierarchy/opacity metadata. No rendered or runtime UI parity accepted."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
