extends SceneTree
# Read-only active original HUD model geometry, attachment and animation metadata.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Pose=preload("res://systems/native_data/gui_pose.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""; var names: PackedStringArray=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--models="): names=arg.substr(9).split(",",false)
	if output.is_empty() or install.is_empty() or names.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var failures: Array=[]; var results: Dictionary={}
	if not catalog.mount_install(install): failures.append(catalog.failure)
	for name in names:
		var bytes: PackedByteArray=catalog.get_resource(name,2002); var parser:=Actor.new(); var model:=parser.parse(bytes)
		if not parser.failure.is_empty(): failures.append(name+": "+parser.failure); continue
		var geometry:=Geometry.model(model)
		if not str(geometry.error).is_empty(): failures.append(name+": "+str(geometry.error)); continue
		var hooks: Dictionary={}
		for key in geometry.hooks: hooks[key]=[geometry.hooks[key].x,geometry.hooks[key].y]
		var animations: Array=[]
		for clip in model.animations:
			animations.append({"name":clip.name,"length":clip.length,"tracks":clip.get("tracks",[]).size(),"meshes":clip.get("mesh_tracks",[]).size()})
		var result:={"sha256":Cache.digest(bytes),"bytes":bytes.size(),"bounds":[geometry.bounds.position.x,geometry.bounds.position.y,geometry.bounds.size.x,geometry.bounds.size.y],"hooks":hooks,"animations":animations}
		if name in ["ctl_playr_health","ctl_party_health"]:
			var samples: Array=[]; var asset:=parser.rig_asset(model)
			for percent in [0,1,25,50,75,99,100]:
				var pose:=Pose.compose(asset,[{"clip":"percentage","time":float(percent)/30.0}]); var parts: Array=[]
				if not str(pose.error).is_empty(): failures.append(name+": "+str(pose.error)); break
				for index in pose.meshes: parts.append({"node":model.nodes[int(index)].name,"data":pose.meshes[index]})
				samples.append({"percent":percent,"parts":parts})
			result.samples=samples
		results[name]=result
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":results.size(),"failures":failures,"models":results,"publicConnections":0,"scope":"Read-only original HUD model/hook/hash/animation metadata; no full UI or runtime action parity accepted."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
