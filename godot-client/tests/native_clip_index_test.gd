extends SceneTree
const Rigs=preload("res://systems/model_rigs.gd")
const Data=preload("res://systems/native_data/actor_model.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
var checks:=0
var failures: Array=[]
var observations: Array=[]
var old_rigs: GDScript
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func same(a: Variant,b: Variant) -> bool: return Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(b))
func authored() -> Dictionary:
	var clips: Array=[]
	for index in 600:
		clips.append({"name":"clip_"+str(index),"length":1.0,"transition":0.125,"events":[{"time":0.25,"name":"event_"+str(index)}],"tracks":[{"node":"root","property":"position","interpolation":"linear","frames":[{"time":0.0,"value":[0.0,0.0,0.0]},{"time":1.0,"value":[float(index),0.0,1.0]}]}]})
	clips.append({"name":"clip_4","length":2.0,"transition":0.375,"events":[{"time":0.5,"name":"last_duplicate"}],"tracks":[]})
	clips.append({"name":"CLIP_4","length":3.0,"transition":0.5,"events":[],"tracks":[]})
	clips.append({"name":"invalid","length":-1.0,"transition":0.0,"events":[],"tracks":[],"deferred_invalid_duration":true})
	return {"name":"authored","nodes":[{"name":"root","parent":-1,"position":[0.0,0.0,0.0],"orientation":[0.0,0.0,0.0,1.0],"scale":1.0}],"animations":clips}
func prepare(model: Dictionary) -> Dictionary: return {"asset":Data.new().rig_asset(model),"thread":OS.get_thread_caller_id()}
func worker(model: Dictionary) -> Dictionary:
	var thread:=Thread.new(); thread.start(prepare.bind(model))
	while thread.is_alive(): await process_frame
	return thread.wait_to_finish()
func nodes_for(host: Node3D,asset: Dictionary) -> Array[Node3D]:
	var nodes: Array[Node3D]=[]
	for index in asset.defaults.size():
		var node:=Node3D.new(); node.name="part_"+str(index); host.add_child(node); nodes.append(node)
	return nodes
func compare(asset: Dictionary,label: String) -> void:
	var before:=Cache.digest(var_to_bytes(asset)); var a:=Node3D.new(); var b:=Node3D.new(); root.add_child(a); root.add_child(b)
	var reference=old_rigs.new(); var candidate:=Rigs.new(); a.add_child(reference); b.add_child(candidate); reference.set_process(false); candidate.set_process(false); candidate.use_prepared_clips=true
	var nodes_a:=nodes_for(a,asset); var nodes_b:=nodes_for(b,asset)
	var first:=str(asset.clips[0].name); var source:={"parts":Array(range(asset.defaults.size())),"clip":first,"loop":true}
	var began:=Time.get_ticks_usec(); var old: Dictionary=reference._model(a,nodes_a,source,asset); var old_ms:=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec(); var prepared: Dictionary=candidate._model(b,nodes_b,source,asset); var prepared_ms:=(Time.get_ticks_usec()-began)/1000.0
	check(prepared.has("indexed_asset") and not prepared.has("deferred") and candidate.stats.indexed_clip_models==1,label+": actual instance uses immutable worker index")
	check(prepared.events.size()==1 and prepared.transitions.size()==1 and prepared.names.size()==1,label+": only the starting clip creates private playback metadata")
	check(old.names==prepared.names and old.clip==prepared.clip and old.loop==prepared.loop and old.play_serial==prepared.play_serial,label+": initial private playback state is unchanged")
	var names: Array=[first,str(asset.clips[-1].name)]
	if label=="authored": names.append_array(["clip_4","CLIP_4","clip_350","not_present"])
	for name in names:
		reference._play(old,str(name),false,0.75,0.125,true); candidate._play(prepared,str(name),false,0.75,0.125,true)
		check(old.names==prepared.names and old.clip==prepared.clip and old.loop==prepared.loop and old.speed==prepared.speed and old.last_time==prepared.last_time and old.play_serial==prepared.play_serial,label+": exact lazy playback state for "+str(name))
		if not old.names.has(name): continue
		var animation_a: Animation=old.player.get_animation(old.names[name]); var animation_b: Animation=prepared.player.get_animation(prepared.names[name])
		check(animation_a.length==animation_b.length and animation_a.loop_mode==animation_b.loop_mode and animation_a.get_track_count()==animation_b.get_track_count(),label+": real clip length/loop/channel count for "+str(name))
		var exact:=true
		for track in animation_a.get_track_count():
			exact=exact and animation_a.track_get_type(track)==animation_b.track_get_type(track) and animation_a.track_get_path(track)==animation_b.track_get_path(track) and animation_a.track_get_key_count(track)==animation_b.track_get_key_count(track)
			for index in animation_a.track_get_key_count(track): exact=exact and animation_a.track_get_key_time(track,index)==animation_b.track_get_key_time(track,index) and animation_a.track_get_key_value(track,index)==animation_b.track_get_key_value(track,index)
		check(exact,label+": every built track/path/time/value remains exact for "+str(name))
		check(same(old.events[name],prepared.events[name]) and same(old.transitions[name],prepared.transitions[name]),label+": original event order/transition preserved for "+str(name))
		for index in nodes_a.size(): exact=exact and nodes_a[index].transform==nodes_b[index].transform
		check(exact,label+": actual sought pose stays exact for "+str(name))
	check(candidate.stats.indexed_clip_metadata==prepared.names.size(),label+": duplicate requests never rebuild event metadata")
	check(Cache.digest(var_to_bytes(asset))==before,label+": shared source/index/events are immutable")
	if not prepared.events[first].is_empty():
		prepared.events[first][0].name="private-change"
		check(Cache.digest(var_to_bytes(asset))==before and old.events[first][0].name!="private-change",label+": private event copies cannot mutate another actor or shared cache")
	var legacy_asset:=asset.duplicate(); legacy_asset.erase("clipIndex")
	var fallback: Dictionary=candidate._model(b,nodes_b,source,legacy_asset)
	check(not fallback.has("indexed_asset") and fallback.has("deferred"),label+": older/nonprepared assets retain the original path")
	observations.append({"name":label,"source_clips":asset.clips.size(),"reference_install_ms":old_ms,"indexed_install_ms":prepared_ms,"private_metadata":prepared.events.size()})
	a.free(); b.free(); await process_frame
func run() -> void:
	var report:=""; var catalog_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		elif arg.begins_with("--catalog="): catalog_path=arg.substr(10)
	if report.is_empty() or catalog_path.is_empty() or FileAccess.file_exists(report): quit(2); return
	var archive:="res://backups/native-loading-control-identity-v1.zip"
	check(FileAccess.get_sha256(archive)=="ddbc1dad4b6615d72f869a4fab114fdd19a018845ebc510c606069b405ffa12a","Pre-index authored checkpoint is hash-pinned")
	var zip:=ZIPReader.new(); check(zip.open(archive)==OK,"Independent authored reference opens")
	var code:=zip.read_file("systems/model_rigs.gd"); zip.close()
	check(Cache.digest(code)=="4cb7cf9ea3322ea4593d1fc8a22410437aa94ddbb671370d9b68c8b57e6a6318","Exact pre-change runtime source is hash-pinned")
	old_rigs=GDScript.new(); old_rigs.source_code=code.get_string_from_utf8(); check(old_rigs.reload()==OK,"Independent authored reference compiles unchanged")
	var model:=authored(); var source_hash:=Cache.digest(var_to_bytes(model)); var prepared: Dictionary=await worker(model); var asset: Dictionary=prepared.asset
	check(prepared.thread!=OS.get_thread_caller_id() and Cache.digest(var_to_bytes(model))==source_hash,"Actual data worker builds metadata without mutating source")
	check(asset.clipIndex.size()==601 and asset.clipIndex.clip_4==600 and asset.clipIndex.CLIP_4==601 and not asset.clipIndex.has("invalid"),"Index preserves current exact-case/last-duplicate rules and rejects invalid-duration clips")
	await compare(asset,"authored")
	var directory:=OS.get_environment("TEMP").path_join("nwn-native-clip-index-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())); var cache:=Cache.new(); check(cache.configure(directory),"Private derived cache opens")
	var sources: Array=[{"resref":"authored","sha256":source_hash}]; var identity:=Cache.digest(var_to_bytes(sources)); var old_decoder:="actor-rig-emitter-v9-deferred-axis"; var new_decoder:="actor-rig-emitter-v10-clip-index"
	var old_asset:=asset.duplicate(); old_asset.erase("clipIndex"); check(cache.save_data(Cache.key(identity,old_decoder),identity,old_decoder,old_asset),"Prior derived schema fixture is published")
	var service:=Assets.new(); root.add_child(service); service.set_process(false)
	var thread:=Thread.new(); thread.start(service.rig_data.bind(model,sources,directory))
	while thread.is_alive(): await process_frame
	var cold: Dictionary=thread.wait_to_finish(); check(same(cold,asset),"Actual worker rig service never reuses the stale index-free schema")
	var warm:=service.rig_data(model,sources,directory); check(same(warm,cold) and cache.load_data(Cache.key(identity,new_decoder),identity,new_decoder).has("clipIndex"),"Verified warm derived cache retains exact index and full original clips")
	service.close(); service.free()
	var files:=DirAccess.get_files_at(directory); check(files.size()==2,"Only old and new bounded derivative files exist")
	for file in files: DirAccess.remove_absolute(directory.path_join(file))
	check(DirAccess.remove_absolute(directory)==OK,"Owned derived-cache fixture cleans up")
	var catalog:=Recorded.new(); check(catalog.mount(catalog_path),"Sealed original animation sources mount")
	for name in ["a_ba","c_goblina"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2002); var parser:=Data.new(); parser.packed_keys=true; var parsed: Dictionary=parser.parse(bytes)
		check(not bytes.is_empty() and catalog.failure.is_empty() and parser.failure.is_empty() and not parsed.get("animations",[]).is_empty(),"Original animation source parses: "+name)
		if parsed.get("animations",[]).is_empty(): continue
		var result: Dictionary=await worker(parsed); await compare(result.asset,name)
	var output:=FileAccess.open(report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"public_connections":0,"scope":"Actual data workers, immutable shared clip index/derived cache, private real AnimationPlayer tracks/poses/events/clocks against pinned unchanged authored code. Exact current port duplicate/case semantics retained; native FindAnimation case-insensitive first-match parity is separate. Not clean FPS/whole-world or original-client timing acceptance."},"\t")); output.close(); print("NATIVE_CLIP_INDEX ",checks," checks"); quit(0 if failures.is_empty() else 1)
