extends RefCounted
const M=preload("res://systems/native_render/particle_math.gd")
const Schedule=preload("res://systems/native_render/particle_schedule.gd")
const STEP=0.009999999776482582
# Original fixed-chain Lightning owner; neither standard movement nor the
# particle-life pass is part of this update. Empty String means success.
static func release_last(e: Dictionary,p: Dictionary) -> void:
	var particle: Dictionary=e.active188.records.pop_back()
	if e.free130.records.size()==int(e.free130.capacity):
		var capacity:=16 if int(e.free130.capacity)==0 else int(e.free130.capacity)*2
		assert(capacity>int(e.free130.capacity) and capacity<=2147483647,"Native lightning free-list overflow")
		e.free130.capacity=capacity; Schedule.invoke(p,"reserveFree",[capacity])
	e.free130.records.append(particle)
static func fractal(e: Dictionary,middle: int,span: int,depth: int,first: Array,second: Array,factor: float,p: Dictionary) -> String:
	if middle-span<0 or middle+span>=e.active188.records.size() or depth>64: return "Original lightning subdivision addresses unavailable particle storage"
	var sign_value:=1 if (int(Schedule.invoke(p,"random"))&1)!=0 else -1
	var left: Dictionary=e.active188.records[middle-span]; var right: Dictionary=e.active188.records[middle+span]; var position: Array=[]
	for axis in 3: position.append(M.f(M.f(M.f(right.position10[axis])+M.f(left.position10[axis]))*0.5))
	if M.f(e.lightningRadius)>=0.01:
		var count:=M.cvtt(M.f(M.f(e.lightningRadius)*100))
		if count==0: return "Original lightning radius divides by zero"
		var distance:=M.f(M.f(int(Schedule.invoke(p,"random"))%count)*STEP)
		for axis in 3: position[axis]=M.f(M.f(M.f(M.f(sign_value*first[axis])*distance)*M.f(factor))+position[axis])
	var second_sign:=1 if (int(Schedule.invoke(p,"random"))&1)!=0 else -1
	if M.f(e.lightningRadius)>=0.01:
		var count:=M.cvtt(M.f(M.f(e.lightningRadius)*100))
		if count==0: return "Original lightning radius divides by zero"
		var distance:=M.f(M.f(int(Schedule.invoke(p,"random"))%count)*STEP)
		for axis in 3: position[axis]=M.f(M.f(M.f(M.f(second_sign*second[axis])*distance)*M.f(factor))+position[axis])
	e.active188.records[middle].position10=position
	if span!=0:
		var half:=span/2; var error:=fractal(e,middle-half,half,depth+1,first,second,factor,p)
		if not error.is_empty(): return error
		return fractal(e,middle+half,half,depth+1,first,second,factor,p)
	return ""
static func update(e: Dictionary,delta: float,p: Dictionary) -> String:
	delta=M.f(delta); var count:=M.cvtt(M.f(e.birthRate)); var factor:=M.f(Schedule.invoke(p,"sourceFactor",[e.source50])) if e.source50!=null else 1.0
	e.lightningElapsed=M.f(delta+M.f(e.lightningElapsed))
	if count==0 or e.target1c0==null:
		while not e.active188.records.is_empty(): release_last(e,p)
		return ""
	if count<0: return "Original lightning negative chain count addresses invalid particle storage"
	# The original caches the initial free index. Preserve repeated pointer
	# aliases on refill, rather than replacing this quirk with repeated pop().
	var free_count: int=e.free130.records.size(); var reused: Variant=e.free130.records[free_count-1] if free_count>0 else null
	while e.active188.records.size()<count:
		var particle: Dictionary
		if free_count>0:
			particle=reused
			if free_count-1<e.free130.records.size(): e.free130.records.remove_at(free_count-1)
		else: particle=Schedule.invoke(p,"createParticle",[false,delta])
		if int(e.flags)&32:
			var difference:=M.cvtt(M.f(M.f(e.frameEnd)-M.f(e.frameStart))); var plus:=difference+1; var size:=plus if plus>=0 else ~difference
			if size!=0: particle.frame44=M.cvtt(M.f(M.f(int(Schedule.invoke(p,"random"))%size)+M.f(e.frameStart)))
		Schedule.append(e,particle,p)
	while e.active188.records.size()>count: release_last(e,p)
	for particle in e.active188.records:
		if M.f(particle.age)==M.f(particle.field48): particle.field48=0.0; particle.age=0.0
		particle.age=M.f(M.f(particle.age)+delta)
		if int(e.renderMode1a8)==6: Schedule.blur(particle,M.f((M.f(e.blurLength) if M.f(e.blurLength)<delta else delta)/M.f(e.blurLength)))
	if not (M.f(e.lightningElapsed)>M.f(e.lightningDelay)):
		var difference:=M.subtract(Schedule.invoke(p,"targetPosition",[e.target1c0]),e.position1e0); var q:=M.rotation_arc(e.lightningPreviousDirection,difference)
		for particle in e.active188.records:
			var relative:=M.subtract(particle.position10,e.lightningPreviousPosition); particle.position10=M.add(M.rotate(q,relative),e.position1e0)
		e.lightningPreviousDirection=difference; e.lightningPreviousPosition=M.values(e.position1e0); return ""
	var first: Dictionary=e.active188.records[0]
	if M.f(e.xSize)==0 and M.f(e.ySize)==0: first.position10=M.values(e.position1e0)
	else: Schedule.invoke(p,"randomPosition",[first,M.cvtt(M.f(M.f(M.f(e.xSize)*100)*factor)),M.cvtt(M.f(M.f(M.f(e.ySize)*100)*factor))])
	e.active188.records[count-1].position10=M.values(Schedule.invoke(p,"targetPosition",[e.target1c0]))
	var difference:=M.subtract(first.position10,e.active188.records[count-1].position10)
	if difference.all(func(value):return value==0): return ""
	e.lightningElapsed=0.0
	var direction:=M.normalize(difference); var basis: Array=[M.f(-direction[1]),direction[2],M.f(-direction[0])]; var other:=M.cross(direction,basis); var half:=count/2
	var error:=fractal(e,half,half,1,basis,other,factor,p)
	if not error.is_empty(): return error
	var squared:=M.f(M.f(M.f(difference[1]*difference[1])+M.f(difference[0]*difference[0]))+M.f(difference[2]*difference[2])); var extent:=M.f(M.f(M.f(sqrt(squared))/M.f(e.active188.records.size()))*0.5)
	for index in range(1,e.active188.records.size()-1):
		if extent<0.01: return ""
		var sign_value:=1 if (int(Schedule.invoke(p,"random"))&1)!=0 else -1; var divisor:=M.cvtt(M.f(extent*100))
		if divisor==0: return "Original lightning jitter divides by zero"
		# This owner uses DOUBLE *.01, unlike the fractal FLOAT multiply.
		var distance:=M.f((int(Schedule.invoke(p,"random"))%divisor)*0.01); var scale_value:=M.f(e.lightningScale); var part_scale:=M.f(e.partScale); var particle: Dictionary=e.active188.records[index]
		for axis in 3: particle.position10[axis]=M.f(M.f(M.f(M.f(M.f(sign_value*direction[axis])*distance)*scale_value)*part_scale)+M.f(particle.position10[axis]))
	return ""
