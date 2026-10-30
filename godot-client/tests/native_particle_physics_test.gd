extends "res://tests/native_particle_schedule_test.gd"
const Movement=preload("res://tests/native_particle_backend.gd")
const Initialization=preload("res://tests/native_particle_backend.gd")
const Random=preload("res://systems/native_render/particle_random.gd")
func initialization_tests() -> void:
	var index:=0
	for row in original("native-particle-initialization-observations",876):
		var c: Dictionary=row.case; var rng:=Random.new(); rng.seed_value(int(c.seed)); var draws: Array=[]
		var e:={"flags":c.flags,"deadspace":M.f(c.deadspace),"position1e0":[4,-3,2],"previous19c":[3,-2,1],"previousQuaternion178":[1,0,0,0],"quaternion1d0":M.values(c.quaternion),"basis140":M.values(c.basis),"frameStart":M.f(0.5),"frameEnd":M.f(3.75),"randomVelocity":M.f(c.randomVelocity),"velocity":2,"xSize":M.f(c.size[0]),"ySize":M.f(c.size[1]),"spread":M.f(c.spread)}
		var p:={"random":func():var v:=rng.next(); draws.append(v); return v,"cameraPosition":func():return [10,20,30],"cosineDouble":func(value):return cos(value)}
		var part: Dictionary={}
		if c.mode in ["constructor","both"]: part=Initialization.create(e,c.delta,p)
		if c.mode in ["initialize","both"]: Initialization.initialize(part,e,c.delta,c.factor,p)
		Initialization.randomize_frame(e,part,p)
		var out:={"draws":draws,"rng":rng.state,"position":part.position10,"rotation":part.rotation1c,"inheritedSpeed":part.inheritedSpeed20,"inheritedDirection":part.inheritedDirection24,"quaternion":part.quaternion34,"frame":part.frame44,"field48":part.field48,"direction":part.direction4c,"velocity":part.velocity58,"trail":part.trail64,"stopped":part.stopped70,"age":part.age}
		var expected: Dictionary=row.duplicate(); expected.erase("case"); var difference:=same(out,expected)
		check(difference.is_empty(),"Original initialization "+str(index)+" "+difference); index+=1
func movement_tests() -> void:
	var index:=0
	for row in original("native-particle-movement-observations",384):
		var c: Dictionary=row.case; var calls: Array=[]; var particles: Array=[]
		for id in int(c.count): particles.append({"position10":M.values([0.5+id,0.75-id,1+id]),"velocity58":M.values([0.3,-0.2,0.1]),"inheritedSpeed20":M.f(0.4),"inheritedDirection24":[0.25,0.5,0.75],"quaternion34":[1,0,0,0],"trail64":[-1,-2,-3],"direction4c":[0,0,1],"stopped70":int(id==2),"chunk78":{"id":id} if id%2==0 else null})
		var e:={"flags":c.flags,"source50":{"position":[4.5,-3.5,2.5],"quaternion":[1,0,0,0]} if c.source else null,"position1e0":[4,-3,2],"previous19c":[3,-2,1],"reference10c":[2,-1,0.5],"referenceQuaternion118":[0.5,0.5,0.5,0.5],"quaternion1d0":M.values(c.quaternion),"previousQuaternion178":[1,0,0,0],"mass":M.f(0.2),"bounceCoefficient":M.f(c.bounce),"sizeStart":M.f(0.3),"chunkName":"synthetic_chunk" if c.chunk else "","active188":{"records":particles},"hit1f0":{"normal":[0,0,0]}}
		Movement.standard(e,c.delta,{"wind":func(position,delta):calls.append(["wind",position,delta]); return M.values([0.01,-0.02,0.03]),"clearHit":func(hit):calls.append(["clearHit"]); hit.normal=[0,0,0],"resetIgnoredHits":func(_hit):calls.append(["resetIgnored"]),"addIgnoredHit":func(_hit,chunk):calls.append(["ignore",chunk.id]),"collide":func(old,goal,out,hit):
			calls.append(["collide",old,goal]); hit.normal=M.values(c.normal)
			if c.collision: out.assign([0.5,0.75,1])
			return c.collision})
		var out:={"calls":calls,"reference":e.reference10c,"referenceQuaternion":e.referenceQuaternion118,"particles":particles.map(func(part):return {"position":part.position10,"velocity":part.velocity58,"inheritedSpeed":part.inheritedSpeed20,"quaternion":part.quaternion34,"trail":part.trail64,"direction":part.direction4c,"stopped":part.stopped70})}
		var expected: Dictionary=row.duplicate(); expected.erase("case"); var difference:=same(out,expected)
		check(difference.is_empty(),"Original movement "+str(index)+" "+difference); index+=1
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	initialization_tests(); movement_tests()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"backend":"compiled" if Schedule.compiled() else "gd","success":failures.is_empty(),"checks":checks,"failures":failures,"binarySha256":BINARY_SHA,"originalEvidence":evidence,"scope":"Native initialization/movement with explicit camera/wind/intersection boundaries; no drawing/full-world acceptance"},"\t")); file.close()
	print("NATIVE_PARTICLE_PHYSICS ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
