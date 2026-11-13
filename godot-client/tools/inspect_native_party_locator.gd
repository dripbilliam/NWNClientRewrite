extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Keys=preload("res://systems/native_data/packed_animation_keys.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for value in OS.get_cmdline_user_args():
		var pair:=value.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); var failures: Array=[]
	if not catalog.mount_install(args.install): failures.append(catalog.failure)
	var bytes: PackedByteArray=catalog.get_resource("pb_mbr_pos",2002); var parser:=Actor.new(); var model:=parser.parse(bytes); var nodes: Array=[]; var animations: Array=[]
	if not parser.failure.is_empty(): failures.append(parser.failure)
	for node in model.get("nodes",[]):
		var row: Dictionary=node.duplicate(); row.erase("controller_storage"); row.erase("controller_raw"); row.erase("emitter"); row.erase("light"); nodes.append(row)
	for clip in model.get("animations",[]):
		var tracks: Array=[]
		for track in clip.tracks: tracks.append({"node":track.node,"property":track.property,"interpolation":track.interpolation,"frames":Keys.frames(track)})
		animations.append({"name":clip.name,"length":clip.length,"tracks":tracks})
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":nodes.size()+animations.size(),"failures":failures,"sha256":Cache.digest(bytes),"nodes":nodes,"animations":animations,"graphical":false,"publicConnections":0,"scope":"Read-only original locator geometry/controller metadata; no raster extraction or rendering"},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
