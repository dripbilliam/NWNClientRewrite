extends "res://tests/native_particle_resident_test.gd"
# Paired owners in one process keep timing conditions and input identical.
# This is a CPU microbenchmark; real GPU/server acceptance is separate.
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(Kernel.available() and ClassDB.class_exists("NwnParticleOwner"),"Native particle owner loads")
	var seed_owner:=make_owner(false,"fountain",32|128|256,false,false)
	var owners: Array=[]; var rngs: Array=[]; var callbacks: Array=[]
	for direct in [false,true]:
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var configured: Dictionary=owner.call("dispatch",0,{"state":seed_owner.state,"update":"fountain","directFieldKeys":true,"compactRecords":direct},{})
		check(not configured.has("error"),"Configures storage path "+str(direct))
		var rng:=Random.new(); rng.seed_value(321)
		owners.append(owner); rngs.append(rng)
		callbacks.append({"random":rng.next,"cameraPosition":func():return [5.0,2.0,8.0],"cosineDouble":func(value):return cos(value),"addPointSourceWind":func(_p,_r,_l,_f):pass})
	var capacities: Array=[0,0]; var timing: Array=[[],[]]; var windows: Array=[]
	var peak_particles:=0
	for frame in 960:
		var source: Dictionary=seed_owner.state.source50.duplicate(true)
		source.position=[sin(frame*0.01),cos(frame*0.013),0.3]
		var results: Array=[{},{}]
		# Reverse call order every frame to avoid a systematic first-call bias.
		for turn in 2:
			var slot: int=(turn+frame)%2
			var input:={"clip":"","time":frame/60.0,"source":source,"pose":{"position":source.position,"quaternion":source.quaternion},"delta":1.0/60.0,"capacity":capacities[slot],"draw":{"factor":source.adjustedScale,"camera":[0.5,0.5,0.5,0.5],"tint":[1.0,1.0,1.0]},"patch":{"birthRate":600.0,"lifeExp":4.0}}
			var start:=Time.get_ticks_usec()
			var result: Dictionary=owners[slot].call("dispatch",1,input,callbacks[slot])
			var elapsed:=Time.get_ticks_usec()-start
			check(not result.has("error"),"Storage frame "+str(frame)+"/"+str(slot)+" "+str(result.get("error","")))
			if result.has("error"): break
			check(bool(result.compact_records)==bool(slot),"Actual storage path "+str(frame)+"/"+str(slot))
			capacities[slot]=int(result.capacity); results[slot]=result
			peak_particles=maxi(peak_particles,int(result.count)/6)
			if frame>=240: timing[slot].append(elapsed)
		if not failures.is_empty(): break
		check(results[0].positions==results[1].positions and results[0].attributes==results[1].attributes and results[0].count==results[1].count,"Exact storage-path GPU bytes "+str(frame))
		check(rngs[0].state==rngs[1].state and rngs[0].draws==rngs[1].draws,"Exact storage-path RNG "+str(frame))
		if frame%40==0 or frame==959:
			var a: Dictionary=owners[0].call("dispatch",2,{},{}); var b: Dictionary=owners[1].call("dispatch",2,{},{})
			var difference:=same(without_ids(a),without_ids(b))
			check(difference.is_empty(),"Exact storage-path records "+str(frame)+" "+difference)
		if frame>=240 and (frame+1)%120==0:
			var means: Array=[]
			for slot in 2:
				var sum:=0.0
				for n in range(timing[slot].size()-120,timing[slot].size()): sum+=float(timing[slot][n])
				means.append(sum/120.0/1000.0)
			windows.append({"end_frame":frame,"generic_ms":means[0],"compact_ms":means[1],"reduction":1.0-means[1]/means[0]})
	var summary: Array=[]
	for slot in 2:
		var values: Array=timing[slot]; values.sort(); var sum:=0.0
		for value in values: sum+=float(value)
		summary.append({"compact_records":bool(slot),"samples":values.size(),"mean_ms":sum/maxi(1,values.size())/1000.0,"p95_ms":float(values[int((values.size()-1)*0.95)])/1000.0 if not values.is_empty() else 0.0})
	check(peak_particles>2000,"Benchmark includes more than 2000 particles")
	for callback in callbacks: callback.clear()
	seed_owner.providers.clear(); owners.clear(); callbacks.clear(); seed_owner.clear()
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"timings":summary,"windows":windows,"peak_particles":peak_particles,"network_connections":0,"scope":"Paired native owners, identical RNG/input, exact GPU streams/records; CPU microbenchmark, no matched native executable or graphical acceptance"},"\t")); file.close()
	print("NATIVE_PARTICLE_COMPACT_PAIRED ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
