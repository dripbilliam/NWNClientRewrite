extends "res://tests/native_particle_simulation_test.gd"
const Channels=preload("res://systems/native_render/particle_channels.gd")
const FIELDS=preload("res://systems/native_render/particle_emitter.gd").FIELDS
var compact_records:=false
var typed_frame:=false
func channel_asset() -> Dictionary:
	var word:=PackedByteArray(); word.resize(4); word.encode_u32(0,0x3f800001)
	var vector_pool:=PackedFloat32Array([0,1])
	for index in 24: vector_pool.append((index-8)*0.05)
	return {"clips":[
		{"name":"constant","length":3.0,"emitterTracks":[{"part":0,"property":"birthrate","frames":[{"time":2.0,"value":[3.25]}]},{"part":0,"property":"colorstart","frames":[{"time":-1.0,"value":[0.1,0.2,0.3]}]},{"part":0,"property":"detonate","frames":[{"time":0.0,"value":[word.decode_float(0)]}]}]},
		{"name":"linear","length":1.0,"emitterTracks":[{"part":0,"property":"fps","frames":[{"time":0.0,"value":[1]},{"time":0.5,"value":[2]},{"time":1.0,"value":[4]}]},{"part":0,"property":"colorend","frames":[{"time":0.0,"value":[1,2,3]},{"time":0.5,"value":[2,3,4]},{"time":1.0,"value":[4,5,6]}]}]},
		{"name":"bezier","length":1.0,"emitterTracks":[{"part":0,"property":"birthrate","frames":[{"time":0.0,"value":[1]}],"nativeController":{"rows4":1,"timeIndex6":0,"valueIndex8":1,"columnsA":17,"displacement0":0x74},"nativeStorageIndex":0},{"part":0,"property":"colorstart","frames":[{"time":0.0,"value":[1,2,3]}],"nativeController":{"rows4":2,"timeIndex6":0,"valueIndex8":2,"columnsA":19,"displacement0":0},"nativeStorageIndex":1}],"emitterStorage":[{"values88":PackedFloat32Array([0,1,0,0.2,2,0.3])},{"values88":vector_pool}]},
		{"name":"unused_bad","length":1.0,"emitterTracks":[{"part":0,"property":"fps","frames":[{"time":0.0,"value":[1]}],"nativeController":{"rows4":1,"timeIndex6":0,"valueIndex8":1000,"columnsA":1,"displacement0":0x9c},"nativeStorageIndex":0}],"emitterStorage":[{"values88":PackedFloat32Array([0])}]},
		{"name":"empty","length":1.0,"emitterTracks":[]}]}
func test_channels() -> void:
	for cached in [true,false]:
		var gd:=Channels.new(); gd.cache_constants=cached; gd.configure(channel_asset(),0)
		var source:=make_owner(false,"fountain",32,false,false)
		var resident: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var parameters:={"birthrate":99.0,"fps":10.0}
		var configured: Dictionary=resident.call("dispatch",0,{"state":source.state,"parameters":parameters,"clips":gd.clips,"update":"fountain","cacheConstants":cached,"compactRecords":compact_records,"typedEmitter":typed_frame},{})
		check(not configured.has("error"),"Native channels compile lazily, including unused malformed storage")
		for clip in ["constant","linear","bezier","empty","missing","constant"]:
			for time in [-10.0,-0.001,0.0,0.2,0.5,1.0,2.0,100.0]:
				var expected:=gd.sample(clip,time,parameters)
				var actual: Dictionary=resident.call("dispatch",4,{"clip":clip,"time":time},{})
				check(expected and not actual.has("error") and same(actual,parameters).is_empty(),"Native persistent scalar/vector/byte controller "+clip+"/"+str(time)+" "+same(actual,parameters))
		for invalid in [NAN,INF,-INF]:
			var actual: Dictionary=resident.call("dispatch",4,{"clip":"constant","time":invalid},{})
			check(not gd.sample("constant",invalid,parameters) and actual.has("error"),"Native invalid controller clock retains failure")
		for clip in ["empty","missing"]:
			var actual: Dictionary=resident.call("dispatch",4,{"clip":clip,"time":NAN},{})
			check(gd.sample(clip,NAN,parameters) and not actual.has("error"),"No-channel clock remains a no-op")
		var bad: Dictionary=resident.call("dispatch",4,{"clip":"unused_bad","time":0},{})
		check(not gd.sample("unused_bad",0,parameters) and bad.has("error"),"Malformed native controller fails only when selected")
		source.providers.clear(); resident=null
func without_ids(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary={}
		for name in value:
			if name!="id": out[name]=without_ids(value[name])
		return out
	if value is Array: return value.map(without_ids)
	return value
func expected_bytes(bytes: PackedByteArray,capacity: int) -> Array:
	var positions:=PackedByteArray(); var attributes:=PackedByteArray(); positions.resize(capacity*12); attributes.resize(capacity*12)
	for vertex in bytes.size()/24:
		var offset:=vertex*24; var target:=vertex*12
		positions.encode_float(target,bytes.decode_float(offset+4)); positions.encode_float(target+4,bytes.decode_float(offset+12)); positions.encode_float(target+8,-bytes.decode_float(offset+8))
		attributes.encode_u32(target,bytes.decode_u32(offset)); attributes.encode_float(target+4,bytes.decode_float(offset+16)); attributes.encode_float(target+8,bytes.decode_float(offset+20))
	return [positions,attributes]
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	compact_records=args.get("particle-records","")=="compact"
	typed_frame=args.get("particle-emitter","")=="typed"
	check(Kernel.available() and ClassDB.class_exists("NwnParticleOwner"),"Resident RefCounted native owner loads")
	test_channels()
	for kind in ["fountain","explosion","single"]:
		for scenario in 6:
			var flags:=32|128
			if scenario%3==1: flags|=64|256
			elif scenario%3==2: flags|=1024
			if scenario>=3: flags|=16
			var gd:=make_owner(false,kind,flags,scenario==1,false)
			var resident: RefCounted=ClassDB.instantiate("NwnParticleOwner")
			var configured: Dictionary=resident.call("dispatch",0,{"state":gd.state,"update":kind,"compactRecords":compact_records,"typedEmitter":typed_frame},{})
			check(not configured.has("error"),"Native owner configures "+kind+str(scenario))
			var rng:=Random.new(); rng.seed_value(321)
			var providers:={"random":rng.next,"cameraPosition":func():return [5.0,2.0,8.0],"cosineDouble":func(value):return cos(value),"addPointSourceWind":func(_p,_r,_l,_f):pass}
			var collisions:={"hits":0,"misses":0}
			providers.collide=func(_old,goal,out,hit):
				hit.normal=[0.0,0.0,1.0]
				if goal[2]>=0: collisions.misses+=1; return false
				out.assign([goal[0],goal[1],0.0]); collisions.hits+=1; return true
			var capacity:=0
			for frame in 180:
				var expected:=step(gd,kind,frame)
				var source: Dictionary=gd.state.source50
				var input:={"clip":"","time":frame/60.0,"source":source,"pose":{"position":source.position,"quaternion":source.quaternion},"delta":[1.0/60.0,1.0/40.0,0.0,-0.002,0.7][frame%5],"capacity":capacity,"draw":{"factor":source.adjustedScale,"camera":[0.5,0.5,0.5,0.5],"tint":[1.0,1.0,1.0]},"patch":{"birthRate":gd.state.birthRate,"detonate108":int(frame%30==0) if kind=="explosion" else 0}}
				var actual: Dictionary=resident.call("dispatch",1,input,providers)
				check(not actual.has("error"),"Resident frame prepares "+kind+"/"+str(scenario)+"/"+str(frame)+" "+str(actual.get("error","")))
				if actual.has("error"): break
				check(bool(actual.compact_records)==compact_records,"Requested particle storage path is active")
				capacity=int(actual.capacity)
				var packed:=expected_bytes(expected.buffer,capacity)
				check(actual.positions==packed[0] and actual.attributes==packed[1] and int(actual.count)==int(expected.draw_count),"Resident GPU streams exactly match reference "+kind+"/"+str(scenario)+"/"+str(frame))
				var state: Dictionary=resident.call("dispatch",2,{},{}); var difference:=same(without_ids(state),without_ids(expected.state))
				check(difference.is_empty(),"Resident state exactly matches reference "+kind+"/"+str(scenario)+"/"+str(frame)+" "+difference)
				check(rng.state==gd.rng.state and rng.draws==gd.rng.draws and int(actual.allocated)==int(gd.context.created),"Resident recycling and shared RNG order "+kind+"/"+str(scenario)+"/"+str(frame))
			if scenario>=3: check(collisions.hits>0 and collisions.misses>0,"Resident collision bridge exercised hit/miss output parameters "+kind+str(scenario))
			gd.providers.clear(); resident=null
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"network_connections":0,"scope":"3240 moving frames including bouncing sprite collisions: persistent native state/recycling/RNG/GPU stream vs reference, hit/miss output mutation; actual scene and world integration require separate checks"},"\t")); file.close()
	print("NATIVE_PARTICLE_RESIDENT ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
