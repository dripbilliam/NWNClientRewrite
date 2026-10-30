extends SceneTree
# Read-only native GUI animation/controller metadata; no game connection.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""; var name:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--model="): name=arg.substr(8)
	if output.is_empty() or install.is_empty() or name.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var failures: Array=[]
	if not catalog.mount_install(install): failures.append(catalog.failure)
	var raw: PackedByteArray=catalog.get_resource(name,2002); var parser:=Actor.new(); var model: Dictionary=parser.parse(raw)
	if not parser.failure.is_empty(): failures.append(parser.failure)
	var clips: Array=[]
	for clip in model.get("animations",[]):
		var tracks: Array=[]
		for track in clip.get("tracks",[]): tracks.append({"node":track.node,"property":track.property,"frames":track.get("frames",[]),"packed":track.has("packed_frames")})
		clips.append({"name":clip.name,"length":clip.length,"tracks":tracks,"meshTracks":clip.get("mesh_tracks",[]),"fields":clip.keys(),"unsupported":clip.get("unsupported",[])})
	var nodes: Array=[]
	for node in model.get("nodes",[]): nodes.append({"name":node.name,"alpha":node.get("alpha",1),"meshFields":node.get("mesh",{}).keys()})
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":1,"failures":failures,"resource":name,"sha256":Cache.digest(raw),"clips":clips,"nodes":nodes,"publicConnections":0,"scope":"Installed original GUI-model animation metadata only; unsupported channels remain explicit. No pixel, input or full UI parity acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
