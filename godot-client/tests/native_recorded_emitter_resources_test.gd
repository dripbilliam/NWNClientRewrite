extends "res://tests/native_particle_schedule_test.gd"
const Catalog=preload("res://systems/native_data/recorded_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Keys=preload("res://systems/native_data/packed_animation_keys.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("catalog") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); var manifest_path:=str(args.catalog).path_join("manifest.json"); var manifest_sha:=FileAccess.get_sha256(manifest_path)
	check(catalog.mount(args.catalog),"Sealed recorded catalog mounts without live network or installed-resource substitution: "+catalog.failure)
	if not failures.is_empty(): quit(1); return
	var models: Array=[]; var missing: Array=[]; var parse_failures: Array=[]; var recorded_misses: Array=[]; var emitter_count:=0
	for key in catalog.manifest.resources:
		if not str(key).ends_with(":2002"): continue
		var name:=str(key).trim_suffix(":2002")
		if catalog.manifest.resources[key].has("error"):
			check(not catalog.has_resource(name,2002),"Recorded model lookup miss agrees with sealed resource namespace: "+name)
			recorded_misses.append({"name":name,"error":catalog.manifest.resources[key].error}); continue
		var bytes:=catalog.get_resource(name,2002)
		check(catalog.failure.is_empty(),"Recorded model payload integrity: "+name+" "+catalog.failure)
		if not catalog.failure.is_empty(): continue
		var parser:=Actor.new(); parser.packed_keys=true; var model:=parser.parse(bytes)
		check(parser.failure.is_empty() and not model.is_empty(),"Original recorded actor parses: "+name+" "+parser.failure)
		if model.is_empty(): parse_failures.append({"name":name,"error":parser.failure}); continue
		models.append({"name":name,"sha256":catalog.manifest.resources[key].sha256,"nodes":model.nodes.size(),"clips":model.animations.size()})
		for node in model.nodes:
			if not node.has("emitter"): continue
			emitter_count+=1; var texture:=str(node.emitter.get("texture","")).to_lower()
			if texture in ["","null"] or not catalog.raster_location(texture).is_empty() or catalog.has_resource(texture,6): continue
			var tracks: Array=[]
			for clip in model.animations:
				for track in clip.get("emitter_tracks",[]):
					if str(track.node).to_lower()!=str(node.name).to_lower(): continue
					var frames:=Keys.frames(track); var minimum: Array=[]; var maximum: Array=[]
					for frame in frames:
						if minimum.is_empty(): minimum=frame.value.duplicate(); maximum=minimum.duplicate()
						for c in frame.value.size(): minimum[c]=minf(minimum[c],frame.value[c]); maximum[c]=maxf(maximum[c],frame.value[c])
					tracks.append({"clip":clip.name,"length":clip.length,"property":track.property,"interpolation":track.interpolation,"frames":frames.size(),"minimum_keys":minimum,"maximum_keys":maximum})
			missing.append({"model":name,"node":node.name,"supermodel":model.supermodel,"properties":node.emitter,"tracks":tracks})
		if models.size()%8==0: await process_frame
	check(FileAccess.get_sha256(manifest_path)==manifest_sha,"Recording manifest is unchanged after the read-only audit")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"manifest_sha256":manifest_sha,"models":models,"emitter_count":emitter_count,"missing":missing,"parse_failures":parse_failures,"recorded_misses":recorded_misses,"publicConnections":0,"scope":"Read-only native parse of every recorded MDL payload and local emitter channels. Reports unavailable image names and authored keys; does not infer active server animation, inherited controllers, actual missing-image pixels, or full lighting acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
