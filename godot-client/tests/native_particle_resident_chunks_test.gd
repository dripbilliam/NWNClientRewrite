extends "res://tests/native_particle_resident_test.gd"
const ChunkOwner=preload("res://systems/native_render/particle_chunks.gd")
func chunk_services(trace: Dictionary,present: bool) -> Dictionary:
	return {"createChunkModel":func(name):
		var child: Variant="chunk"+str(trace.created) if present else null
		trace.created+=1; trace.calls.append(["create",name,child]); return child,
		"chunkScene":func(child,attached):trace.calls.append(["scene",child,attached]),
		"chunkScale":func(child,factor,kind):trace.calls.append(["scale",child,factor,kind]),
		"chunkPlay":func(child,name,speed,flags,time):trace.calls.append(["play",child,name,speed,flags,time]),
		"chunkPosition":func(child,position):trace.calls.append(["position",child,position.duplicate()]),
		"chunkOrientation":func(child,q):trace.calls.append(["orientation",child,q.duplicate()]),
		"destroyChunkModel":func(child,flag):trace.calls.append(["destroy",child,flag]),
		"resetIgnoredHits":func(_hit):trace.calls.append(["reset"]),
		"addIgnoredHit":func(_hit,child):trace.calls.append(["ignore",child]),
		"collide":func(_old,goal,out,hit):
			hit.normal=[0.0,0.0,1.0]
			if goal[2]>=0: return false
			out.assign([goal[0],goal[1],0.0]); trace.calls.append(["collision"]); return true,
		"addPointSourceWind":func(position,radius,duration,strength):trace.calls.append(["wind",position.duplicate(),radius,duration,strength])}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	compact_records=args.get("particle-records","")=="compact"
	typed_frame=args.get("particle-emitter","")=="typed"
	check(Kernel.available() and ClassDB.class_exists("NwnParticleOwner"),"Native resident chunk owner loads")
	var frames:=0
	for kind in ["fountain","explosion","single"]:
		for scenario in 3:
			for present in [false,true]:
				var flags: int=32|128|256 if scenario==0 else 32|64|16 if scenario==1 else 32|1024|16
				var gd:=make_owner(false,kind,flags,scenario==1,false)
				gd.state.chunkName="authored_chunk"
				var expected_trace:={"created":0,"calls":[]}; var actual_trace:={"created":0,"calls":[]}
				gd.providers.merge(chunk_services(expected_trace,present),true)
				gd.providers.baseCreate=func(delta):return Init.create(gd.state,delta,gd.providers)
				gd.providers.baseInitialize=func(part,delta,factor):Init.initialize(part,gd.state,delta,factor,gd.providers)
				gd.providers.createParticle=func(_chunk,delta):return ChunkOwner.construct(gd.state,delta,gd.providers)
				gd.providers.initializeParticle=func(part,delta,factor):ChunkOwner.initialize(part,delta,factor,gd.providers)
				gd.providers.destroyParticle=func(part,_flag):ChunkOwner.destroy(part,gd.providers)
				gd.providers.detachChunk=func(child,_scene):gd.providers.chunkScene.call(child,false)
				var resident: RefCounted=ClassDB.instantiate("NwnParticleOwner")
				var configured: Dictionary=resident.call("dispatch",0,{"state":gd.state,"update":kind,"compactRecords":compact_records,"typedEmitter":typed_frame},{})
				check(not configured.has("error"),"Configures native chunk "+kind+str(scenario)+str(present))
				var rng:=Random.new(); rng.seed_value(321)
				var providers:=chunk_services(actual_trace,present)
				providers.random=rng.next; providers.cameraPosition=func():return [5.0,2.0,8.0]
				providers.cosineDouble=func(value):return cos(value)
				providers.detachChunk=func(child,_scene):providers.chunkScene.call(child,false)
				for frame in 120:
					expected_trace.calls.clear(); actual_trace.calls.clear()
					var e: Dictionary=gd.state; var angle:=M.f(frame*0.004)
					e.source50.position=[M.f(sin(frame*0.07)*0.3),M.f(cos(frame*0.03)*0.4),M.f(0.5+sin(frame*0.013)*0.2)]
					e.source50.quaternion=[M.f(cos(angle)),0.0,0.0,M.f(sin(angle))]
					if kind=="single": e.birthRate=0.0 if frame%45==44 else 1.0
					elif kind=="explosion": e.detonate108=int(frame%30==0)
					var delta: float=[1.0/60.0,1.0/40.0,0.0,-0.002,0.7][frame%5]
					var input:={"clip":"","time":frame/60.0,"source":e.source50,"pose":{"position":e.source50.position,"quaternion":e.source50.quaternion},"delta":delta,"capacity":0,"draw":{"factor":e.source50.adjustedScale,"camera":[0.5,0.5,0.5,0.5],"tint":[1.0,1.0,1.0]},"patch":{"birthRate":e.birthRate,"detonate108":e.detonate108}}
					GD.animate(e,delta,gd.providers); ChunkOwner.render(e,gd.providers)
					var output: Dictionary=resident.call("dispatch",1,input,providers)
					var label: String=kind+"/"+str(scenario)+"/"+str(present)+"/"+str(frame)
					check(not output.has("error"),"Native chunk frame "+label+" "+str(output.get("error","")))
					if output.has("error"): break
					check(bool(output.compact_records)==compact_records,"Requested chunk storage path is active "+label)
					check(int(output.count)==0,"Chunk model emitter emits no sprite quads "+label)
					var state: Dictionary=resident.call("dispatch",2,{},{})
					var difference:=same(without_ids(state),without_ids(e))
					check(difference.is_empty(),"Exact native chunk records "+label+" "+difference)
					var trace_difference:=same(actual_trace,expected_trace)
					check(trace_difference.is_empty(),"Exact native chunk model/collision/lifetime calls "+label+" "+trace_difference)
					check(rng.state==gd.rng.state and rng.draws==gd.rng.draws,"Exact native chunk RNG "+label)
					frames+=1
				gd.providers.clear(); providers.clear(); resident=null
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"frames":frames,"network_connections":0,"scope":"Resident chunk storage vs retained original-derived owners: all three schedules, source scale, motion trail, inheritance, collision, absent/present models, active/free reuse, private model operations and RNG. Real meshes/rigs/retirement require the graphical chunk test."},"\t")); file.close()
	print("NATIVE_PARTICLE_RESIDENT_CHUNKS ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
