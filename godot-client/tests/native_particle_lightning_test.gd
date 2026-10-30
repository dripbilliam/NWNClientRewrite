extends "res://tests/native_particle_schedule_test.gd"
const Lightning=preload("res://systems/native_render/particle_lightning.gd")
const Target=preload("res://systems/native_render/particle_target.gd")
const Initialization=preload("res://tests/native_particle_backend.gd")
const Random=preload("res://systems/native_render/particle_random.gd")
func make_particle(particles: Array,id: int,index: int) -> Dictionary:
	var particle:={"id":id,"position10":[1+id,2+id,3+id],"trail64":[-1,-2,-3],"age":0.25 if index%2!=0 else 0.0,"field48":0.25 if index%2!=0 else 1.0,"frame44":2}
	particles.append(particle); return particle
func lightning_tests() -> void:
	var index:=0
	for row in original("native-lightning-update-observations",2697):
		var c: Dictionary=row.case; var calls: Array=[]; var draws: Array=[]; var rng:=Random.new(); rng.seed_value(int(c.seed)); var particles: Array=[]
		var e:={"birthRate":M.f(c.rate),"source50":{} if c.source else null,"target1c0":{} if c.target else null,"active188":{"records":[],"capacity":c.activeCount},"free130":{"records":[],"capacity":c.freeCount},"lightningElapsed":M.f(c.elapsed),"lightningDelay":M.f(c.delay),"lightningRadius":M.f(c.radius),"lightningScale":M.f(c.scale),"partScale":M.f(c.partScale),"lightningPreviousDirection":M.values(c.oldDirection),"lightningPreviousPosition":M.values(c.oldPosition),"position1e0":M.values(c.position),"basis140":[1,0,0,0,1,0,0,0,1],"frameStart":M.f(c.frameStart),"frameEnd":M.f(c.frameEnd),"xSize":M.f(c.xSize),"ySize":M.f(c.ySize),"flags":c.flags,"renderMode1a8":c.mode,"blurLength":M.f(0.3)}
		for id in int(c.activeCount): e.active188.records.append(make_particle(particles,id,id))
		for id in int(c.freeCount): e.free130.records.append(make_particle(particles,int(c.activeCount)+id,id))
		var p:={"sourceFactor":func(_source):calls.append(["source"]); return c.factor,"targetPosition":func(_target):calls.append(["target"]); return c.targetPosition,"random":func():var result:=rng.next(); draws.append(result); return result,
			"createParticle":func(_chunk,delta):
				var id:=particles.size(); calls.append(["allocate",id]); calls.append(["initialize",id,delta,1]); var made:=make_particle(particles,id,0); made.age=0.0; made.field48=0.0; made.frame44=int(c.frameStart); return made,
			"reserveActive":func(n):calls.append(["reserveActive",n]),"reserveFree":func(n):calls.append(["reserveFree",n])}
		p.randomPosition=func(particle,x,y):calls.append(["randomPosition",particle.id,int(x)&0xffffffff,int(y)&0xffffffff]); Initialization.random_position(particle,e,int(x),int(y),p)
		var error:=Lightning.update(e,c.delta,p); check(error.is_empty(),"Original lightning update completes "+str(index)+" "+error)
		var actual:={"calls":calls,"draws":draws,"rng":rng.state,"active":e.active188.records.map(func(part):return part.id),"free":e.free130.records.map(func(part):return part.id),"activeCapacity":e.active188.capacity,"freeCapacity":e.free130.capacity,"elapsed":e.lightningElapsed,"oldDirection":e.lightningPreviousDirection,"oldPosition":e.lightningPreviousPosition,"particles":particles.map(func(part):return {"id":part.id,"position":part.position10,"trail":part.trail64,"age":part.age,"field48":part.field48,"frame":part.frame44})}
		var expected: Dictionary=row.duplicate(); expected.erase("case"); expected.erase("normalizes"); var difference:=same(actual,expected)
		check(difference.is_empty(),"Original lightning state/order/draws "+str(index)+" "+difference); index+=1
		# randomPosition deliberately receives the same provider table. Break
		# that test callback's Dictionary cycle; native particles have no backref.
		p.clear()
func target_tests() -> void:
	var index:=0
	for row in original("native-emitter-target-observations",97):
		var c: Dictionary=row.case; var calls: Array=[]; var target: Dictionary={}
		var e:={"source50":{},"target1c0":null,"position1e0":c.cachedPosition,"lightningPreviousDirection":[-7,-8,-9],"lightningPreviousPosition":[-1,-2,-3],"targetDistance20c":-1,"lifeExp":3,"ageMode1cc":1,"targetListener128":88}; var children: Array=[]
		for id in c.references.size(): children.append({"id":id,"ref":c.references[id],"model68":target})
		var p:={"children":func(_emitter):return children,"referenceView":func(part):calls.append(["reference",part.id]); return part if part.ref else null,"globalPosition":func(_emitter):calls.append(["pose"]); return c.globalPosition,"targetPosition":func(_target):calls.append(["position"]); return c.targetPosition,"lightningView":func(_emitter):calls.append(["lightning"]); return e if c.lightning else null,"removeListener":func(_source,listener):calls.append(["remove",listener]),"baseInitialize":func(_emitter):calls.append(["base"]),"listen":func(_source,callback,name,owner):
			check(callback==Target.set_target and is_same(owner,e),"Original target listener binds callback and owner"); calls.append(["listen","0x1400643c0",name]); return 99}
		if c.mode=="target": Target.set_target(e,p)
		else: Target.initialize_lightning(e,p)
		var actual:={"calls":calls,"target":e.target1c0!=null,"distance":e.targetDistance20c,"previousDirection":e.lightningPreviousDirection,"previousPosition":e.lightningPreviousPosition,"life":e.lifeExp,"ageMode":e.ageMode1cc,"listener":e.targetListener128}
		var expected: Dictionary=row.duplicate(); expected.erase("case"); var difference:=same(actual,expected)
		check(difference.is_empty(),"Original physical target/init "+str(index)+" "+difference); index+=1
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	lightning_tests(); target_tests()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"backend":"compiled" if Schedule.compiled() else "gd","success":failures.is_empty(),"checks":checks,"failures":failures,"binarySha256":BINARY_SHA,"originalEvidence":evidence,"scope":"Native lightning CPU update/fractal/vector helpers and target/init callbacks, with explicit captured lower providers; no rendered chain or full model-reference lifetime acceptance"},"\t")); file.close()
	print("NATIVE_PARTICLE_LIGHTNING ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
