extends SceneTree
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Keys=preload("res://systems/native_data/packed_animation_keys.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Rigs=preload("res://systems/model_rigs.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func same_frames(a: Array,b: Array) -> bool: return Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(b))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("catalog") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Recorded.new(); check(catalog.mount(str(args.catalog)),"Sealed original corpus mounts without installed/network fallback")
	var samples: Array=[]
	for name in ["pme0","c_nulltail","a_ba","a_ba_non_combat","a_fa","h_ba_med_weap","h_ba_custom","h_ba_casts"]:
		var bytes:=catalog.get_resource(name,2002)
		check(catalog.failure.is_empty(),"Exact original model is present: "+name)
		if bytes.is_empty(): continue
		var eager:=Actor.new(); var packed:=Actor.new(); packed.packed_keys=true
		var began:=Time.get_ticks_usec(); var original:=eager.parse(bytes); var eager_ms:=(Time.get_ticks_usec()-began)/1000.0
		began=Time.get_ticks_usec(); var compact:=packed.parse(bytes); var packed_ms:=(Time.get_ticks_usec()-began)/1000.0
		check(eager.failure.is_empty() and packed.failure.is_empty(),"Both native paths decode original model: "+name)
		if original.is_empty() or compact.is_empty(): continue
		check(same_frames(original.nodes,compact.nodes),"Geometry, physical indices, skins and static controllers unchanged: "+name)
		check(original.animations.size()==compact.animations.size(),"Every original clip remains available: "+name)
		var tracks:=0; var frames:=0; var clips_ok:=true; var keys_ok:=true
		for index in original.animations.size():
			var old: Dictionary=original.animations[index]; var next: Dictionary=compact.animations[index]
			for field in ["name","length","transition","root","events","unsupported","controller_nodes"]:
				if old.get(field)!=next.get(field): clips_ok=false
			for field in ["tracks","emitter_tracks"]:
				if old[field].size()!=next[field].size(): keys_ok=false; continue
				for track in old[field].size():
					var a: Dictionary=old[field][track]; var b: Dictionary=next[field][track]
					if a.node!=b.node or a.property!=b.property or a.interpolation!=b.interpolation or not same_frames(a.frames,Keys.frames(b)): keys_ok=false
					tracks+=1; frames+=a.frames.size()
		check(clips_ok,"Durations/events/native controller runs remain exact: "+name)
		check(keys_ok,"All expanded transform/emitter key bytes match eager decoding: "+name)
		var old_rig:=eager.rig_asset(original); var new_rig:=packed.rig_asset(compact); var rigs_ok: bool=old_rig.defaults==new_rig.defaults and old_rig.controlled==new_rig.controlled
		for index in old_rig.clips.size():
			var old: Dictionary=old_rig.clips[index]; var next: Dictionary=new_rig.clips[index]
			if old.name!=next.name or old.tracks.size()!=next.tracks.size(): rigs_ok=false; continue
			for track in old.tracks.size():
				if not same_frames(old.tracks[track].keys,Keys.keys(next.tracks[track])): rigs_ok=false
		check(rigs_ok,"Every rig channel materializes identical Godot-space keys: "+name)
		samples.append({"name":name,"source_bytes":bytes.size(),"sha256":Cache.digest(bytes),"clips":original.animations.size(),"tracks":tracks,"frames":frames,"eager_ms":eager_ms,"packed_ms":packed_ms,"eager_serialized_bytes":var_to_bytes(original).size(),"packed_serialized_bytes":var_to_bytes(compact).size()})
	var packed:={"values":PackedFloat32Array([0,1,2,4,6,8,10,12]),"times":0,"first":2,"rows":2,"components":3,"bezier":false}
	check(Keys.valid(packed),"Authored ordered binary32 keys validate")
	var channel:={"part":0,"property":"position","source_property":"position","sourceInterpolation":"linear","native_keys":packed,"position_scale":0.25}
	var expected:=[{"time":0.0,"value":[0.5,1.5,-1.0]},{"time":1.0,"value":[2.0,3.0,-2.5]}]
	check(Keys.keys(channel)==expected,"Inherited position scaling and coordinate conversion match explicit expected values")
	var bad: Dictionary=packed.duplicate(true); bad.values[0]=2
	check(not Keys.valid(bad),"Unordered original times are rejected")
	bad=packed.duplicate(true); bad.values[2]=NAN
	check(not Keys.valid(bad),"Non-finite used values are rejected")
	var ascii_text:="newanim exact authored\nlength 1\nnode dummy root\npositionbezierkey 2\n0 0.123456789123 2 3 4 5 6 7 8 9\n1 10 11 12 13 14 15 16 17 18\norientationkey 2\n0 1 2 3 0.25\n1 0 0 0 0\nscalekey\n0 1.000000000123\n1 2\nendlist\nendnode\nevent 0.5 test\ndoneanim exact authored\n"
	var eager_ascii:=Actor.new(); var compact_ascii:=Actor.new(); compact_ascii.packed_keys=true
	var eager_clips:=eager_ascii.ascii_animations(ascii_text); var compact_clips:=compact_ascii.ascii_animations(ascii_text)
	check(eager_ascii.failure.is_empty() and compact_ascii.failure.is_empty() and eager_clips.size()==1 and compact_clips.size()==1,"Counted/uncounted ASCII and Bezier/quaternion/constants decode")
	var ascii_exact:=eager_clips.size()==1 and compact_clips.size()==1
	if ascii_exact:
		for index in eager_clips[0].tracks.size():
			var a: Dictionary=eager_clips[0].tracks[index]; var b: Dictionary=compact_clips[0].tracks[index]
			if not same_frames(a.frames,Keys.frames(b)) or not Keys.valid(b.packed_frames): ascii_exact=false
	check(ascii_exact,"ASCII double precision, axis-angle output, Bezier tangents and list order remain exact")
	for invalid in [ascii_text.replace("1 10 11 12", "-1 10 11 12"),ascii_text.replace("1 2\nendlist", "-1 2\nendlist"),ascii_text.replace("1 10 11 12", "nan 10 11 12")]:
		eager_ascii.failure=""; compact_ascii.failure=""
		eager_ascii.ascii_animations(invalid); compact_ascii.ascii_animations(invalid)
		check(not eager_ascii.failure.is_empty() and not compact_ascii.failure.is_empty(),"Both ASCII paths reject invalid times/numbers")
	var host:=Node3D.new(); root.add_child(host); var part:=Node3D.new(); host.add_child(part)
	var rigs:=Rigs.new(); host.add_child(rigs); var nodes: Array[Node3D]=[part]
	var controlled:={"0:position":{"part":0,"property":"position","bezier":false}}
	var defaults:=[{"position":[0,0,0],"quaternion":[0,0,0,1],"scale":[1,1,1]}]
	var a:=rigs._clip_resource(host,nodes,{"parts":[0]},defaults,controlled,{"length":1.0,"tracks":[channel]})
	var b:=rigs._clip_resource(host,nodes,{"parts":[0]},defaults,controlled,{"length":1.0,"tracks":[{"part":0,"property":"position","sourceInterpolation":"linear","keys":expected}]})
	check(a.get_track_count()==b.get_track_count() and a.track_get_key_value(0,0)==b.track_get_key_value(0,0) and a.track_get_key_value(0,1)==b.track_get_key_value(0,1),"Actual native Animation builder consumes deferred channels identically")
	host.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"scope":"Exact recorded binary/ASCII bytes versus native eager decoding, authored scaling/precision and actual Animation construction; not original-executable timing or FPS acceptance"},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
