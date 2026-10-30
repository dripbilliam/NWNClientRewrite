extends SceneTree
const Schedule=preload("res://tests/native_particle_backend.gd")
const M=preload("res://systems/native_render/particle_math.gd")
const BINARY_SHA="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
var checks:=0
var failures: Array=[]
var evidence: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func same(a: Variant,b: Variant,path: String="") -> String:
	# The original owners store binary32. Godot's JSON decimal-to-double reader
	# need not reconstruct that promoted double bit-for-bit; compare exact f32,
	# with no epsilon. Integer IDs/capacities remain exact integer comparisons.
	if (a is int or a is float) and (b is int or b is float):
		var equal: bool=a==b if a is int else M.f(a)==M.f(b)
		return "" if equal else path+": "+str(a)+" != "+str(b)
	if a is Array and b is Array:
		if a.size()!=b.size(): return path+" array length "+str(a.size())+" != "+str(b.size())
		for index in a.size():
			var failure:=same(a[index],b[index],path+"/"+str(index))
			if not failure.is_empty(): return failure
		return ""
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return path+" dictionary size"
		for key in b:
			if not a.has(key): return path+" missing "+str(key)
			var failure:=same(a[key],b[key],path+"/"+str(key))
			if not failure.is_empty(): return failure
		return ""
	return "" if a==b else path+": value differs"
func original(name: String,count: int) -> Array:
	var path:=ProjectSettings.globalize_path("res://").path_join("../backups/animations/"+name+".json").simplify_path()
	var bytes:=FileAccess.get_file_as_bytes(path); var data: Variant=JSON.parse_string(bytes.get_string_from_utf8()); var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	check(data is Dictionary and data.get("binarySha256")==BINARY_SHA and data.get("rows",[]).size()==count,"Original observation identity/count "+name)
	evidence.append({"name":name,"sha256":hash.finish().hex_encode(),"rows":count})
	return data.rows if data is Dictionary else []
func state(e: Dictionary) -> Dictionary:
	return {"position":e.position1e0,"quaternion":e.quaternion1d0,"previous":e.previous19c,"previousQuaternion":e.previousQuaternion178,"reference":e.reference10c,"referenceQuaternion":e.referenceQuaternion118,"basis":e.basis140,"initialized":e.initialized208}
func frame_tests() -> void:
	var index:=0
	for row in original("native-particle-frame-observations",800):
		var c: Dictionary=row.case; var calls: Array=[]
		var e:={"flags":c.flags,"initialized208":c.initialized,"source50":{"position":[7,8,9],"quaternion":[0.5,0.5,0.5,-0.5],"instance":{"fade":M.f(c.sourceFade)} if c.sourceInstance else null} if c.source else null,"instance100":{"fade":M.f(c.fade)} if c.instance else null,"position1e0":[1,2,3],"quaternion1d0":[1,0,0,0],"previous19c":[-1,-2,-3],"previousQuaternion178":[0,1,0,0],"reference10c":[4,5,6],"referenceQuaternion118":[0,0,1,0],"basis140":[0,1,2,3,4,5,6,7,8]}
		var p:={"globalTransform":func(_emitter):
			var at:=calls.filter(func(v):return v[0]=="transform").size(); var position: Array=[[10,20,30],[-2,4,1]][at]; var quaternion: Array=[[0.5,0.25,-0.5,0.75],[0.5,-0.5,0.5,0.5]][at]
			calls.append(["transform",position,quaternion]); return {"position":position,"quaternion":quaternion},
			"updateEmitter":func(_emitter,delta):calls.append(["update",delta,state(e).duplicate(true)])}
		Schedule.animate(e,c.delta,p); var difference:=same({"calls":calls,"state":state(e)},{"calls":row.calls,"state":row.state})
		check(difference.is_empty(),"Original outer frame "+str(index)+" "+difference); index+=1
func lifetime_tests() -> void:
	var index:=0
	for row in original("native-particle-lifetime-observations",290):
		var c: Dictionary=row.case; var particles: Array=[]; var calls: Array=[]; var free: Array=[]
		for id in c.ages.size(): particles.append({"id":id,"age":M.f(c.ages[id]),"field48":100+id,"chunk78":{"id":id} if id%2==0 else null})
		for id in int(c.freeCount): free.append({"id":-1})
		var e:={"lifeExp":c.life,"chunkName":"synthetic_chunk" if c.chunk else "","active188":{"records":particles.duplicate()},"free130":{"records":free,"capacity":c.capacity}}
		Schedule.check_life(e,c.delta,{"reserveFree":func(n):calls.append(["reserve",n]),"detachChunk":func(chunk,flag):
			calls.append(["detach",chunk.id,flag])
			if c.has("detachLife"): e.lifeExp=c.detachLife})
		var out:={"calls":calls,"active":e.active188.records.map(func(v):return v.id),"retired":free.slice(int(c.freeCount)).map(func(v):return v.id),"capacity":e.free130.capacity,"ages":particles.map(func(v):return v.age),"fields48":particles.map(func(v):return v.field48)}
		var expected: Dictionary=row.duplicate(); expected.erase("case"); var difference:=same(out,expected)
		check(difference.is_empty(),"Original lifetime "+str(index)+" "+difference); index+=1
func particle(context: Dictionary,id: int,age: float=0.0) -> Dictionary:
	var row:={"id":id,"age":M.f(age),"field48":100+id,"rotation1c":7.0 if id%2==0 else -7.0,"position10":[M.f(0.5+id),M.f(1.0+id),M.f(1.5+id)],"trail64":[-1,-2,-3],"chunk78":{"id":id} if id%2==0 else null}
	context.all.append(row); return row
func update_tests(name: String,count: int,kind: String) -> void:
	var index:=0
	for row in original(name,count):
		var c: Dictionary=row.case; var calls: Array=[]; var context:={"all":[],"next":c.ages.size()+int(c.freeCount)}; var active: Array=[]; var free: Array=[]
		for id in c.ages.size(): active.append(particle(context,id,c.ages[id]))
		for id in int(c.freeCount): free.append(particle(context,c.ages.size()+id))
		var e:={"lifeExp":M.f(c.get("life",1.0)),"loop":c.get("loop",0),"chunkName":"synthetic_chunk" if c.chunk else "","birthRate":M.f(c.rate),"source50":{} if c.source else null,"renderMode1a8":c.renderMode,"blurLength":M.f(0.3),"particleRot":M.f(2.25),"spawnType":c.get("spawnType",0),"accumulator198":M.f(0.05),"position1e0":M.values(c.get("position",[1.25,-0.5,0.75])),"previous19c":[0,0,0],"remaining164":M.values([0.1,0.2,0.3]),"blastRadius":M.f(c.get("blastRadius",0)),"blastLength":M.f(0.5),"blastLatch1c8":M.f(c.get("latch",0)),"detonate108":c.get("detonate",0),"active188":{"records":active,"capacity":16 if not active.is_empty() else 0},"free130":{"records":free,"capacity":16 if not free.is_empty() else 0}}
		var p:={"sourceFactor":func(_source):calls.append(["source",c.factor]); return c.factor,
			"reserveFree":func(n):calls.append(["reserveFree",n]),"reserveActive":func(n):calls.append(["reserveActive",n]),"detachChunk":func(chunk,flag):calls.append(["detach",chunk.id,flag]),
			"moveParticles":func(_emitter,delta):
				calls.append(["move",delta,active.map(func(v):return v.id)])
				if c.has("moveDetonate"): e.detonate108=c.moveDetonate,
			"createParticle":func(chunk,delta):
				var made:=particle(context,int(context.next)); context.next+=1; calls.append(["construct",made.id,int(chunk),delta]); return made,
			"initializeParticle":func(part,delta,factor):calls.append(["initialize",part.id,delta,factor]); part.age=0.0; part.rotation1c=0.0; part.position10=[M.f(factor),M.f(2*factor),M.f(3*factor)],
			"randomizeParticle":func(_emitter,part):
				calls.append(["randomize",part.id])
				if c.has("mutateAccumulator"): e.accumulator198=M.f(c.mutateAccumulator),
			"destroyParticle":func(part,flag):calls.append(["destroy",part.id,flag]),"addPointSourceWind":func(position,radius,length_value,flag):calls.append(["wind",position,radius,length_value,flag])}
		if kind=="fountain": Schedule.fountain(e,c.delta,p)
		elif c.kind=="Explosion": Schedule.explosion(e,c.delta,p)
		else: Schedule.single(e,c.delta,p)
		var out:={"calls":calls,"active":active.map(func(v):return v.id),"free":free.map(func(v):return v.id),"activeCapacity":e.active188.capacity,"freeCapacity":e.free130.capacity,"particles":context.all.map(func(v):return {"id":v.id,"age":v.age,"field48":v.field48,"rotation":v.rotation1c,"position":v.position10,"trail":v.trail64})}
		if kind=="fountain": out.enabled=e.enabled23c; out.accumulator=e.accumulator198; out.remaining=e.remaining164
		else: out.latch=e.blastLatch1c8; out.detonate=e.detonate108
		var expected: Dictionary=row.duplicate(); expected.erase("case"); var difference:=same(out,expected)
		check(difference.is_empty(),"Original "+kind+" "+str(index)+" "+difference); index+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(M.f(1.00000006)==PackedFloat32Array([1.00000006])[0] and M.cvtt(INF)==-2147483648 and M.cvtt(-1.9)==-1,"Native binary32 and CVTT conversion")
	lifetime_tests(); frame_tests(); update_tests("native-fountain-update-observations",165,"fountain"); update_tests("native-burst-single-update-observations",647,"burst/single")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"backend":"compiled" if Schedule.compiled() else "gd","success":failures.is_empty(),"checks":checks,"failures":failures,"binarySha256":BINARY_SHA,"originalEvidence":evidence,"scope":"Native schedule/lifetime/frame owners with explicit provider boundaries; no drawing or full simulation acceptance"},"\t")); file.close()
	print("NATIVE_PARTICLE_SCHEDULE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
