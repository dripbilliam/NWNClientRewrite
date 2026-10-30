extends RefCounted
const M=preload("res://systems/native_render/particle_math.gd")
const Schedule=preload("res://systems/native_render/particle_schedule.gd")
const GRAVITY=9.8100004196167
const EPSILON=0.019999999552965164
const BOUNCE_TIME=0.032999999821186066
# Original moveParticleStandard, including per-particle wind/collision providers.
# All positions stay in original Z-up coordinates through simulation.
static func standard(e: Dictionary,delta: float,p: Dictionary) -> void:
	delta=M.f(delta)
	if e.active188.records.is_empty(): return
	var flags:=int(e.flags); var inherit_local: bool=(flags&256)!=0; var inherit_part: bool=(flags&1024)!=0; var inherit: bool=(flags&64)!=0; var bounce: bool=(flags&16)!=0
	var previous:=M.values(e.previousQuaternion178); previous[0]=M.f(previous[0]*-1); var rotation:=M.multiply(e.quaternion1d0,previous)
	for particle in e.active188.records:
		if int(particle.stopped70)!=0: continue
		var old:=M.values(particle.position10); var position:=old.duplicate()
		if inherit:
			position=M.add(M.rotate(rotation,M.subtract(old,e.previous19c)),e.position1e0); particle.velocity58=M.rotate(rotation,particle.velocity58)
		if inherit_local and not inherit and e.source50!=null:
			var shift:=M.subtract(e.source50.position,e.reference10c); position=M.add(position,shift); particle.trail64=M.add(particle.trail64,shift)
		if inherit_part:
			var shift:=M.subtract(e.position1e0,e.reference10c); position=M.add(position,shift); particle.trail64=M.add(particle.trail64,shift)
		var inherited:=M.f(particle.inheritedSpeed20); var velocity: Array=particle.velocity58; var direction: Array=particle.inheritedDirection24; var moved: Array=[]
		for axis in 3:
			var travel:=M.f(delta*M.f(velocity[axis])); var carried:=M.f(M.f(inherited*M.f(direction[axis]))*delta)
			moved.append(M.f(M.f(travel+position[axis])+carried) if axis==0 else M.f(carried+M.f(travel+position[axis])))
		particle.position10=moved
		if int(e.flags)&4: particle.position10=M.add(particle.position10,Schedule.invoke(p,"wind",[position,delta]))
		var damped:=M.f(M.f(1-delta)*M.f(particle.inheritedSpeed20)); particle.inheritedSpeed20=damped
		particle.velocity58[2]=M.f(M.f(particle.velocity58[2])-M.f(M.f(M.f(e.mass)*GRAVITY)*delta))
		if damped<0: particle.inheritedSpeed20=M.f(damped*-1)
		Schedule.invoke(p,"clearHit",[e.hit1f0])
		if not bounce: continue
		if not str(e.chunkName).is_empty():
			Schedule.invoke(p,"resetIgnoredHits",[e.hit1f0])
			if particle.get("chunk78")!=null: Schedule.invoke(p,"addIgnoredHit",[e.hit1f0,particle.chunk78])
		if not Schedule.invoke(p,"collide",[old,particle.position10.duplicate(),particle.position10,e.hit1f0]): continue
		var speed_squared:=0.0; var normal:=M.values(e.hit1f0.normal)
		if M.f(e.bounceCoefficient)==0: particle.velocity58=[0.0,0.0,0.0]
		else:
			var v:=M.values(particle.velocity58); var dot:=M.f(M.f(M.f(v[0]*normal[0])+M.f(v[1]*normal[1]))+M.f(v[2]*normal[2])); var reflected: Array=[]
			for axis in 3: reflected.append(M.f(M.f(M.f(M.f(normal[axis]*M.f(-2))*dot)+v[axis])*M.f(0.75)))
			particle.velocity58=reflected
			var damp:=maxf(M.f(0.5),minf(1,M.f(BOUNCE_TIME/delta) if delta!=0 else INF))
			particle.velocity58[2]=M.f(M.f(particle.velocity58[2]*M.f(e.bounceCoefficient))*damp)
			var x:=float(particle.velocity58[0]); var y:=float(particle.velocity58[1]); var z:=float(particle.velocity58[2]); speed_squared=M.f(M.f(M.f(x*x)+M.f(y*y))+M.f(z*z))
		if speed_squared<M.f(0.5):
			particle.stopped70=1; particle.quaternion34=M.rotation_arc([0,0,1],normal); particle.direction4c=normal.duplicate(); var offset: Array=[]
			for value in normal: offset.append(M.f(value*EPSILON))
			particle.position10=M.add(particle.position10,offset)
			if not str(e.chunkName).is_empty():
				offset=[]
				for value in normal: offset.append(M.f(M.f(e.sizeStart)*value))
				particle.position10=M.add(particle.position10,offset)
	if e.source50!=null and inherit_local: e.reference10c=M.values(e.source50.position); e.referenceQuaternion118=M.values(e.source50.quaternion)
	elif inherit_part: e.reference10c=M.values(e.position1e0); e.referenceQuaternion118=M.values(e.quaternion1d0)
