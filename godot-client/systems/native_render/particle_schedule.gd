extends RefCounted
# Native per-instance simulation owners. Source transforms, allocations, chunk
# lifetime and movement are explicit providers; no exported JS particle frames.
# Original build/address evidence is in NATIVE-PARTICLE-RUNTIME.md.
const M=preload("res://systems/native_render/particle_math.gd")
const TAU32=6.2831854820251465
static func invoke(p: Dictionary,name: String,args: Array=[]) -> Variant:
	assert(p.has(name) and p[name] is Callable and p[name].is_valid(),"Missing native particle provider: "+name)
	return p[name].callv(args)
static func check_life(e: Dictionary,delta: float,p: Dictionary) -> void:
	var active: Array=e.active188.records; var free: Array=e.free130.records
	for index in range(active.size()-1,-1,-1):
		var particle: Dictionary=active[index]
		# Age is checked before increment. A boundary crossing retires next frame.
		if not (M.f(e.lifeExp)>=0) or not (M.f(particle.age)>=M.f(e.lifeExp)):
			particle.age=M.f(M.f(delta)+M.f(particle.age))
			if particle.age<0: particle.age=0.0; particle.field48=0
		else:
			active.remove_at(index)
			if free.size()==int(e.free130.capacity):
				var capacity:=16 if int(e.free130.capacity)==0 else int(e.free130.capacity)*2
				assert(capacity>int(e.free130.capacity) and capacity<=2147483647,"Native particle free-list overflow")
				e.free130.capacity=capacity; invoke(p,"reserveFree",[capacity])
			free.append(particle)
			if not str(e.chunkName).is_empty() and particle.get("chunk78")!=null: invoke(p,"detachChunk",[particle.chunk78,0])
static func append(e: Dictionary,particle: Dictionary,p: Dictionary) -> void:
	if e.active188.records.size()==int(e.active188.capacity):
		var capacity:=16 if int(e.active188.capacity)==0 else int(e.active188.capacity)*2
		assert(capacity>int(e.active188.capacity) and capacity<=2147483647,"Native particle active-list overflow")
		e.active188.capacity=capacity; invoke(p,"reserveActive",[capacity])
	e.active188.records.append(particle)
static func rotate(particle: Dictionary,e: Dictionary,delta: float) -> void:
	var angle:=M.f(M.f(delta*M.f(e.particleRot))+M.f(particle.rotation1c))
	if angle>TAU32: angle=M.f(angle-TAU32)
	elif angle< -TAU32: angle=M.f(angle+TAU32)
	particle.rotation1c=angle
static func blur(particle: Dictionary,blend: float) -> void:
	var remaining:=M.f(1-blend); var result: Array=[]
	for axis in 3: result.append(M.f(M.f(blend*M.f(particle.position10[axis]))+M.f(remaining*M.f(particle.trail64[axis]))))
	particle.trail64=result
static func spawn(e: Dictionary,delta: float,factor: float,p: Dictionary) -> void:
	var particle: Dictionary=e.free130.records.pop_back() if not e.free130.records.is_empty() else invoke(p,"createParticle",[not str(e.chunkName).is_empty(),delta])
	invoke(p,"initializeParticle",[particle,delta,factor]); append(e,particle,p); invoke(p,"randomizeParticle",[e,e.active188.records.back()])
static func fountain(e: Dictionary,delta: float,p: Dictionary) -> void:
	delta=M.f(delta); var rate:=M.f(e.birthRate); e.enabled23c=int(not (0>=rate))
	var factor:=M.f(invoke(p,"sourceFactor",[e.source50])) if e.source50!=null else 1.0
	check_life(e,delta,p)
	if int(e.renderMode1a8)==6:
		var blend:=M.f((delta if delta<=M.f(e.blurLength) else M.f(e.blurLength))/M.f(e.blurLength))
		for index in range(e.active188.records.size()-1,-1,-1): blur(e.active188.records[index],blend)
	for index in range(e.active188.records.size()-1,-1,-1): rotate(e.active188.records[index],e,delta)
	invoke(p,"moveParticles",[e,delta])
	var rate_int:=M.cvtt(rate)
	if rate_int<=0: return
	var interval:=M.f(1/rate)
	if int(e.spawnType)==0:
		e.accumulator198=M.f(delta+M.f(e.accumulator198))
		if not (e.accumulator198>=interval): return
		var index:=0
		# Re-evaluate after callbacks, as the original owner does.
		while index<M.cvtt(M.f(rate*M.f(e.accumulator198)))%(rate_int+1): spawn(e,delta,factor,p); index+=1
		e.accumulator198=0.0; return
	var displacement: Array=[]
	for axis in 3: displacement.append(M.f(M.f(M.f(e.position1e0[axis])-M.f(e.previous19c[axis]))+M.f(e.remaining164[axis])))
	var squared:=M.f(M.f(M.f(displacement[1]*displacement[1])+M.f(displacement[0]*displacement[0]))+M.f(displacement[2]*displacement[2]))
	var length_value:=M.f(sqrt(squared)); var inverse:=M.f(1/length_value) if length_value>0 else 0.0; var direction: Array=[]
	for value in displacement: direction.append(M.f(value*inverse))
	var count:=M.cvtt(M.f(length_value*rate)) if int(e.enabled23c)!=0 else 0
	for index in count:
		spawn(e,delta,factor,p); var result: Array=[]
		for axis in 3:
			if e.active188.records.size()<2: result.append(M.f(M.f(e.position1e0[axis])-M.f(direction[axis]*length_value)))
			else: result.append(M.f(M.f(M.f(e.previous19c[axis])-M.f(e.remaining164[axis]))+M.f(direction[axis]*M.f(M.f(index+1)*interval))))
		e.active188.records.back().position10=result
	var emitted:=M.f(M.f(count)*interval); e.remaining164=[]
	for axis in 3: e.remaining164.append(M.f(displacement[axis]-M.f(direction[axis]*emitted)) if int(e.enabled23c)!=0 else 0.0)
static func explosion(e: Dictionary,delta: float,p: Dictionary) -> void:
	delta=M.f(delta); var count:=M.cvtt(M.f(e.birthRate)); var factor:=M.f(invoke(p,"sourceFactor",[e.source50])) if e.source50!=null else 1.0
	check_life(e,delta,p)
	var blend:=M.f((delta if not (delta>M.f(e.blurLength)) else M.f(e.blurLength))/M.f(e.blurLength)) if int(e.renderMode1a8)==6 else 0.0
	for index in range(e.active188.records.size()-1,-1,-1):
		if int(e.renderMode1a8)==6: blur(e.active188.records[index],blend)
		rotate(e.active188.records[index],e,delta)
	invoke(p,"moveParticles",[e,delta])
	if count!=0 and int(e.detonate108)!=0 and 1>M.f(e.blastLatch1c8):
		if M.f(e.blastRadius)!=0: invoke(p,"addPointSourceWind",[e.position1e0.duplicate(),M.f(e.blastRadius),M.f(e.blastLength),1])
		for index in maxi(0,count):
			var reuse: bool=not e.free130.records.is_empty()
			var particle: Dictionary=e.free130.records.pop_back() if reuse else invoke(p,"createParticle",[not str(e.chunkName).is_empty(),delta])
			invoke(p,"initializeParticle",[particle,delta,1.0 if reuse else factor]); append(e,particle,p); invoke(p,"randomizeParticle",[e,e.active188.records.back()])
	e.blastLatch1c8=1.0 if int(e.detonate108)!=0 else 0.0; e.detonate108=0
static func single(e: Dictionary,delta: float,p: Dictionary) -> void:
	delta=M.f(delta); var active: Array=e.active188.records
	if M.cvtt(M.f(e.birthRate))==0:
		if not active.is_empty(): invoke(p,"destroyParticle",[active.pop_front(),1])
		return
	if active.is_empty(): append(e,invoke(p,"createParticle",[not str(e.chunkName).is_empty(),delta]),p); invoke(p,"randomizeParticle",[e,active[0]]); return
	var particle: Dictionary=active[0]; var age:=M.f(delta+M.f(particle.age)); var life:=M.f(e.lifeExp); particle.age=age
	if not (life>0):
		if age<0: particle.age=0.0
	elif age>life and int(e.loop)!=0: particle.age=0.0
	rotate(particle,e,delta)
	if int(e.renderMode1a8)==6: blur(particle,M.f((delta if not (delta>M.f(e.blurLength)) else M.f(e.blurLength))/M.f(e.blurLength)))
	invoke(p,"moveParticles",[e,delta])
static func transform(e: Dictionary,p: Dictionary) -> void:
	var pose: Dictionary=invoke(p,"globalTransform",[e]); e.position1e0=M.values(pose.position); e.quaternion1d0=M.values(pose.quaternion)
static func animate(e: Dictionary,delta: float,p: Dictionary) -> void:
	delta=M.f(minf(M.f(0.5),M.f(delta)))
	if e.source50!=null and e.source50.get("instance")!=null and 1>M.f(e.source50.instance.fade): return
	if e.instance100!=null and 1>M.f(e.instance100.fade): return
	var shift: Array=[0.0,0.0,0.0]
	if int(e.flags)&256 and e.source50!=null and int(e.initialized208)!=0: shift=M.subtract(e.source50.position,e.reference10c)
	if int(e.initialized208)==0:
		transform(e,p)
		if e.source50!=null and int(e.flags)&0x500: e.reference10c=M.values(e.source50.position); e.referenceQuaternion118=M.values(e.source50.quaternion)
		if int(e.flags)&1024: e.reference10c=e.position1e0.duplicate(); e.referenceQuaternion118=e.quaternion1d0.duplicate()
		e.initialized208=1
	e.previous19c=M.add(shift,e.position1e0) if int(e.flags)&256 else M.values(e.position1e0); e.previousQuaternion178=M.values(e.quaternion1d0)
	if e.source50!=null: transform(e,p)
	e.basis140=M.quaternion_basis(e.quaternion1d0); invoke(p,"updateEmitter",[e,delta])
