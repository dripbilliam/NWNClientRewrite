extends "res://tests/native_particle_schedule_test.gd"
const GD=preload("res://systems/native_render/particle_schedule.gd")
const Init=preload("res://systems/native_render/particle_initialization.gd")
const Move=preload("res://systems/native_render/particle_movement.gd")
const Vertices=preload("res://systems/native_render/particle_vertices.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
const Random=preload("res://systems/native_render/particle_random.gd")
func apply(operation: String,e: Dictionary,delta: float,p: Dictionary,part: Dictionary={},factor: float=1.0) -> Dictionary:
	var out:=Kernel.simulate(operation,e,delta,p,part,factor)
	check(not out.has("error"),"Compiled operation "+operation+" "+str(out.get("error","")))
	return out
func make_owner(compiled: bool,kind: String,flags: int,spatial: bool,chunk: bool) -> Dictionary:
	var e:={"flags":flags,"chunkName":"authored_chunk" if chunk else "","renderMode1a8":6,"blendMode68":0,"spawnType":int(spatial),"loop":1,"xGrid":2,"yGrid":4,"ageMode1cc":1,"accumulator198":0.0,"remaining164":[0.0,0.0,0.0],"detonate108":0,"blastLatch1c8":0.0,"elevationThreshold":5.0,"hit1f0":{"normal":[0,0,0]},"twoSided":false,"position1e0":[0.0,0.0,0.5],"quaternion1d0":[1.0,0.0,0.0,0.0],"previous19c":[0.0,0.0,0.5],"previousQuaternion178":[1.0,0.0,0.0,0.0],"reference10c":[0.0,0.0,0.0],"referenceQuaternion118":[1.0,0.0,0.0,0.0],"basis140":[1.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0],"active188":{"records":[],"capacity":0},"free130":{"records":[],"capacity":0},"initialized208":0,"source50":{"position":[0.0,0.0,0.5],"quaternion":[1.0,0.0,0.0,0.0],"adjustedScale":1.25,"opacity108":1.0,"instance":null},"instance100":null,"birthRate":17.0,"lifeExp":0.6,"particleRot":2.3,"blurLength":0.2,"velocity":0.8,"randomVelocity":0.6,"frameStart":0.0,"frameEnd":7.0,"xSize":5.0,"ySize":10.0,"spread":1.2,"mass":0.3,"bounceCoefficient":0.3,"sizeStart":0.1,"sizeEnd":0.05,"sizeStartY":0.0,"sizeEndY":0.0,"alphaStart":0.8,"alphaEnd":0.1,"fps":10.0,"deadspace":0.0,"blastRadius":0.5,"blastLength":0.4,"colorStart":[0.8,0.4,0.1],"colorEnd":[0.1,0.4,0.8]}
	var rng:=Random.new(); rng.seed_value(321); var context:={"created":0,"all":[],"calls":[],"frame":0,"pose_calls":0}; var p: Dictionary={}
	p.merge({"random":rng.next,"cameraPosition":func():return [5.0,2.0,8.0],"cameraQuaternion":func():return [0.5,0.5,0.5,0.5],"cosineDouble":func(value):return cos(value),"globalTransform":func(_owner):
		context.pose_calls+=1; return {"position":e.source50.position.duplicate(),"quaternion":e.source50.quaternion.duplicate()},
		"sourceFactor":func(source):return source.adjustedScale,"lightColor":func(_position):return [1.0,1.0,1.0],"reserveFree":func(n):context.calls.append(["free",n]),"reserveActive":func(n):context.calls.append(["active",n]),"detachChunk":func(child,flag):context.calls.append(["detach",child.id,flag]),"destroyParticle":func(part,flag):context.calls.append(["destroy",part.id,flag]),
		"createParticle":func(with_chunk,delta):
			var part: Dictionary=apply("create",e,delta,p).get("value",{}) if compiled else Init.create(e,delta,p)
			part.id=context.created; context.created+=1
			if with_chunk: part.chunk78={"id":part.id}
			context.all.append(part); context.calls.append(["create",part.id]); return part,
		"initializeParticle":func(part,delta,factor):
			context.calls.append(["initialize",part.id,factor])
			if compiled: apply("initialize",e,delta,p,part,factor)
			else: Init.initialize(part,e,delta,factor,p),
		"randomizeParticle":func(_owner,part):
			if compiled: apply("randomize_frame",e,0,p,part)
			else: Init.randomize_frame(e,part,p),
		"moveParticles":func(_owner,delta):
			if compiled: apply("standard",e,delta,p)
			else: Move.standard(e,delta,p),
		"updateEmitter":func(_owner,delta):
			if compiled: apply(kind,e,delta,p)
			elif kind=="fountain": GD.fountain(e,delta,p)
			elif kind=="explosion": GD.explosion(e,delta,p)
			else: GD.single(e,delta,p),
		"clearHit":func(hit):hit.normal=[0.0,0.0,0.0],"wind":func(_position,delta):return [M.f(delta*0.1),M.f(delta*-0.2),0.0],"resetIgnoredHits":func(_hit):context.calls.append(["reset"]),"addIgnoredHit":func(_hit,child):context.calls.append(["ignore",child.id]),"collide":func(_old,goal,out,hit):
			hit.normal=[0.0,0.0,1.0]
			if goal[2]>=0: return false
			out.assign([goal[0],goal[1],0.0]); context.calls.append(["collide"]); return true,
		"addPointSourceWind":func(position,radius,length_value,flag):context.calls.append(["wind",position,radius,length_value,flag])})
	return {"state":e,"providers":p,"context":context,"rng":rng,"compiled":compiled}
func step(owner: Dictionary,kind: String,frame: int) -> Dictionary:
	var e: Dictionary=owner.state; var p: Dictionary=owner.providers; var context: Dictionary=owner.context
	context.frame=frame; context.calls.clear(); var angle:=M.f(frame*0.004)
	e.source50.position=[M.f(sin(frame*0.07)*0.3),M.f(cos(frame*0.03)*0.4),M.f(0.5+sin(frame*0.013)*0.2)]; e.source50.quaternion=[M.f(cos(angle)),0.0,0.0,M.f(sin(angle))]
	if kind=="single": e.birthRate=0.0 if frame%45==44 else 1.0
	elif kind=="explosion": e.detonate108=int(frame%30==0)
	var delta: float=[1.0/60.0,1.0/40.0,0.0,-0.002,0.7][frame%5]
	if owner.compiled: apply("animate",e,delta,p)
	else: GD.animate(e,delta,p)
	var out:=Kernel.build(e,p) if owner.compiled else Vertices.build(e,p)
	check(not out.has("error"),"Integrated particle draw prepares "+kind+" "+str(frame))
	return {"state":e,"calls":context.calls,"parts":context.all,"rng_state":owner.rng.state,"rng_draws":owner.rng.draws,"created":context.created,"pose_calls":context.pose_calls,"draw_count":out.get("count",0),"buffer":out.get("buffer",PackedByteArray())}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(Kernel.available(),"Compiled native simulation is available")
	var summaries: Array=[]
	for kind in ["fountain","explosion","single"]:
		for scenario in 4:
			var flags:=32|128
			if scenario==1: flags|=64|256
			elif scenario==2: flags|=1024|4|16
			elif scenario==3: flags|=256|4|16
			var gd:=make_owner(false,kind,flags,scenario==1,scenario==3); var native:=make_owner(true,kind,flags,scenario==1,scenario==3)
			for frame in 180:
				var expected:=step(gd,kind,frame); var actual:=step(native,kind,frame)
				check(expected.buffer==actual.buffer,"Moving integration exact vertex bytes "+kind+"/"+str(scenario)+"/"+str(frame))
				actual.erase("buffer"); expected.erase("buffer")
				var difference:=same(actual,expected)
				check(difference.is_empty(),"Moving integration state/providers/RNG "+kind+"/"+str(scenario)+"/"+str(frame)+" "+difference)
			summaries.append({"kind":kind,"scenario":scenario,"frames":180,"created":native.context.created,"rng_draws":native.rng.draws,"active":native.state.active188.records.size(),"free":native.state.free130.records.size()})
			gd.providers.clear(); native.providers.clear()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scenarios":summaries,"native_only":true,"network_connections":0,"scope":"2160 deterministic authored moving-emitter frames, GD vs compiled state/provider/RNG/vertex bytes. Based on separately original-checked owners; not an original-client moving-world or GPU/performance acceptance."},"\t")); file.close()
	print("NATIVE_PARTICLE_SIMULATION ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
