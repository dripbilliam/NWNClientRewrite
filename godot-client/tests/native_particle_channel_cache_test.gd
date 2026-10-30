extends "res://tests/native_particle_schedule_test.gd"
const Channels=preload("res://systems/native_render/particle_channels.gd")
func asset() -> Dictionary:
	var word:=PackedByteArray(); word.resize(4); word.encode_u32(0,0x3f800001)
	return {"clips":[
		{"name":"constant","length":3.0,"emitterTracks":[{"part":0,"property":"birthrate","frames":[{"time":2.0,"value":[3.25]}]},{"part":0,"property":"colorstart","frames":[{"time":-1.0,"value":[0.1,0.2,0.3]}]},{"part":0,"property":"detonate","frames":[{"time":0.0,"value":[word.decode_float(0)]}]}]},
		{"name":"bezier","length":1.0,"emitterTracks":[{"part":0,"property":"birthrate","frames":[{"time":0.0,"value":[1]}],"nativeController":{"rows4":1,"timeIndex6":0,"valueIndex8":1,"columnsA":17,"displacement0":0x74},"nativeStorageIndex":0}],"emitterStorage":[{"values88":PackedFloat32Array([0,1,0,0.2,2,0.3])}]},
		{"name":"unused_bad","length":1.0,"emitterTracks":[{"part":0,"property":"fps","frames":[{"time":0.0,"value":[1]}],"nativeController":{"rows4":1,"timeIndex6":0,"valueIndex8":1000,"columnsA":1,"displacement0":0x9c},"nativeStorageIndex":0}],"emitterStorage":[{"values88":PackedFloat32Array([0])}]},
		{"name":"empty","length":1.0,"emitterTracks":[]}]}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var cached:=Channels.new(); cached.cache_constants=true
	var legacy:=Channels.new(); legacy.cache_constants=false
	cached.configure(asset(),0); legacy.configure(asset(),0)
	check(cached.failure.is_empty() and legacy.failure.is_empty(),"Unused malformed constant storage is not evaluated during configuration")
	var a:={"birthrate":99.0,"fps":10.0}; var b:=a.duplicate(true)
	for clip in ["constant","bezier","empty","missing","constant"]:
		for time in [-10.0,-0.001,0.0,0.2,0.5,1.0,2.0,100.0]:
			check(cached.sample(clip,time,a)==legacy.sample(clip,time,b) and same(a,b).is_empty(),"Cached scalar/vector/byte matches original-derived sampler at "+clip+"/"+str(time))
	check(cached.constant_hits>0 and cached.sampled_channels<legacy.sampled_channels,"Eligible single linear rows avoid repeated sampling")
	check(not cached.clips.bezier.channels[0].constant_eligible,"Single-row native Bezier is not incorrectly folded")
	var near: Dictionary={}; var far: Dictionary={}; cached.sample("bezier",0.2,near); cached.sample("bezier",0.8,far)
	check(near.birthrate!=far.birthrate,"Original endpoint-dependent single-row Bezier keeps changing")
	a.colorstart[0]=123.0; a.detonate=0; cached.sample("constant",0.4,a)
	check(M.f(a.colorstart[0])==M.f(0.1) and int(a.detonate)==1,"Caller vector edits and consumed byte pulses cannot poison cached values")
	for invalid in [NAN,INF,-INF]:
		check(not cached.sample("constant",invalid,a) and not legacy.sample("constant",invalid,b) and cached.failure==legacy.failure,"Invalid clocks retain sampling failure behavior")
	check(cached.sample("missing",NAN,a) and legacy.sample("missing",NAN,b) and cached.sample("empty",NAN,a) and legacy.sample("empty",NAN,b),"Absent/empty clips retain their existing no-op clock behavior")
	check(not cached.sample("unused_bad",0,a) and not legacy.sample("unused_bad",0,b) and cached.failure==legacy.failure,"Malformed storage still fails when its clip is first selected")
	var metrics:=cached.snapshot(); var legacy_metrics:=legacy.snapshot()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"cached":metrics,"legacy":legacy_metrics,"publicConnections":0,"scope":"Lazy per-instance cache for immutable single-row non-Bezier particle controllers. Authored scalar/vector/byte clocks, endpoint Bezier, alias isolation and delayed failure timing compared with existing original-derived native sampler. No general controller or FPS acceptance."},"\t")); file.close()
	print("NATIVE_PARTICLE_CHANNEL_CACHE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
