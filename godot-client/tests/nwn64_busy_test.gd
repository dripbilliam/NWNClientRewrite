extends "res://tests/nwn64_resident_test.gd"
# Complete CPU particle owner frames; timing is opt-in and coordinator-scheduled.
# No frame intervals, renderer or FPS are measured here.
func quantiles(values: Array) -> Dictionary:
	values.sort();var total:=0.0
	for value in values:total+=float(value)
	return {"samples":values.size(),"median_us":values[int(ceil(values.size()*0.5))-1],"p95_us":values[int(ceil(values.size()*0.95))-1],"p99_us":values[int(ceil(values.size()*0.99))-1],"mean_us":total/values.size()}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	check(Kernel.available() and ClassDB.class_exists("NwnParticleOwner"),"Private native particle owner loads")
	var seed_owner:=make_owner(false,"fountain",32|128|256,false,false)
	seed_owner.state.birthRate=120.0;seed_owner.state.lifeExp=1.2;seed_owner.state.renderMode1a8=0
	var owners: Array=[];var callbacks: Array=[];var rngs: Array=[];var capacities: Array=[]
	for index in 48:
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var initial: Dictionary=seed_owner.state.duplicate(true);initial.renderMode1a8=index%7
		var result: Dictionary=owner.call("dispatch",0,{"state":initial,"update":"fountain","compactRecords":true,"typedEmitter":true},{})
		check(not result.has("error"),"Busy typed compact source configures")
		var rng:=Random.new();rng.seed_value(321+index);rngs.append(rng);owners.append(owner);capacities.append(0)
		callbacks.append({"random":rng.next,"cameraPosition":func():return [5.0,2.0,8.0],"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass})
	var timing: Array=[];var peak:=0;var observed: Array=[];var hashes:=HashingContext.new();hashes.start(HashingContext.HASH_SHA256)
	var measuring: bool=args.get("benchmark","off")=="on"
	var frames:=240 if measuring else 120
	var source: Dictionary=seed_owner.state.source50.duplicate(true)
	for frame in frames:
		source.position=[M.f(sin(frame*0.01)*0.3),M.f(cos(frame*0.013)*0.4),0.5]
		var input:={"clip":"","time":frame/60.0,"source":source,"pose":{"position":source.position,"quaternion":source.quaternion},"delta":1.0/60.0,"draw":{"factor":source.adjustedScale,"camera":[0.5,0.5,0.5,0.5],"tint":[0.8,0.9,1.0]}}
		var active:=0;var results: Array=[];var began:=Time.get_ticks_usec()
		for slot in owners.size():
			input.capacity=capacities[slot]
			var result: Dictionary=owners[slot].call("dispatch",1,input,callbacks[slot]);results.append(result)
			if result.has("error"):check(false,"Busy source frame: "+str(result.error));break
			capacities[slot]=int(result.capacity);active+=int(result.active)
		if measuring and frame>=80:timing.append(Time.get_ticks_usec()-began)
		if not failures.is_empty():break
		peak=maxi(peak,active)
		if frame%60==59 or frame==frames-1:
			var draws:=0
			for slot in owners.size():
				hashes.update(results[slot].positions);hashes.update(results[slot].attributes)
				hashes.update(var_to_bytes(without_ids(owners[slot].call("dispatch",2,{},{}))))
				hashes.update(var_to_bytes([rngs[slot].state,rngs[slot].draws,results[slot].count]));draws+=int(rngs[slot].draws)
			observed.append({"frame":frame,"active":active,"rng_draws":draws})
	check(peak>6000,"Busy population reaches more than6000 simultaneous particles with all seven render modes")
	for cb in callbacks:cb.clear()
	seed_owner.providers.clear();owners.clear();callbacks.clear()
	var report:={"issue":"NWN-64","success":failures.is_empty(),"checks":checks,"failures":failures,"frames":frames,"sources":48,"peak_active":peak,"observed":observed,"state_rng_packet_sha256":hashes.finish().hex_encode(),"benchmark":quantiles(timing) if not timing.is_empty() else {},"scope":"Complete native particle owner CPU batch,48 deterministic sources/all7 render modes and6000+ particles, exact cold-state/RNG/packet digest across binary controls. Component timing only when enabled; no renderer/FPS/loading measurement."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("NWN64_BUSY ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
