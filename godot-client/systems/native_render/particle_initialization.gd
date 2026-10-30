extends RefCounted
const M=preload("res://systems/native_render/particle_math.gd")
const Schedule=preload("res://systems/native_render/particle_schedule.gd")
const Trig=preload("res://systems/native_render/particle_trig.gd")
const STEP=0.009999999776482582
const POSITION_STEP=0.00009999999747378752
static func random_value(p: Dictionary) -> int: return int(Schedule.invoke(p,"random"))
static func remainder(value: int,count: int) -> int:
	assert(count!=0,"Original particle resource divides by zero")
	return value%count
static func random_position(particle: Dictionary,e: Dictionary,x_size: int,y_size: int,p: Dictionary) -> void:
	var x:=remainder(random_value(p),M.cvtt(M.f(M.f(x_size)*M.f(0.5)))) if x_size>3 else 0
	var y:=remainder(random_value(p),M.cvtt(M.f(M.f(y_size)*M.f(0.5)))) if y_size>3 else 0
	var flip_x:=random_value(p)%2; var flip_y:=random_value(p)%2
	if flip_x>0: x=-x
	if flip_y>0: y=-y
	var xf:=M.f(M.f(x)*POSITION_STEP); var yf:=M.f(M.f(y)*POSITION_STEP); var position: Array=[]
	for axis in 3: position.append(M.f(M.f(M.f(xf*M.f(e.basis140[axis]))+M.f(e.position1e0[axis]))+M.f(yf*M.f(e.basis140[axis+3]))))
	particle.position10=position
static func randomize_frame(e: Dictionary,particle: Dictionary,p: Dictionary) -> void:
	if not (int(e.flags)&32): return
	var difference:=M.cvtt(M.f(M.f(e.frameEnd)-M.f(e.frameStart))); var plus:=difference+1; var count:=plus if plus>=0 else ~difference
	if count!=0: particle.frame44=M.cvtt(M.f(M.f(remainder(random_value(p),count))+M.f(e.frameStart)))
static func inherit_velocity(particle: Dictionary,e: Dictionary,delta: float) -> void:
	var direction:=M.axis_z(e.previousQuaternion178); var inverse:=M.f(1/M.f(delta)) if M.f(delta)>0 else STEP
	var d:=M.subtract(e.position1e0,particle.position10); var length_value:=M.f(sqrt(M.f(M.f(M.f(d[1]*d[1])+M.f(d[0]*d[0]))+M.f(d[2]*d[2])))); var velocity: Array=[]
	for axis in 3:
		var rotational:=M.f(M.f(length_value*M.f(M.f(e.basis140[6+axis])-direction[axis]))*inverse); var translation:=M.f(M.f(M.f(e.position1e0[axis])-M.f(e.previous19c[axis]))*inverse)
		velocity.append(M.f(rotational+translation) if axis==0 else M.f(translation+rotational))
	var magnitude:=M.f(sqrt(M.f(M.f(M.f(velocity[0]*velocity[0])+M.f(velocity[1]*velocity[1]))+M.f(velocity[2]*velocity[2])))); var scale_value:=0.0 if magnitude==0 else M.f(1/magnitude)
	particle.inheritedSpeed20=magnitude; particle.inheritedDirection24=[M.f(velocity[0]*scale_value),M.f(velocity[1]*scale_value),M.f(velocity[2]*scale_value)] if magnitude!=0 else [0.0,0.0,0.0]
static func rotation(axis: Array,angle: float,p: Dictionary) -> Array:
	axis=M.normalize(axis)
	var cosine: float=p.cosineFloat.call(angle) if p.has("cosineFloat") else Trig.cosine(angle); var sine: float=p.sineFloat.call(angle) if p.has("sineFloat") else Trig.sine(angle)
	return [cosine,M.f(axis[0]*sine),M.f(axis[1]*sine),M.f(axis[2]*sine)]
static func random_direction(particle: Dictionary,e: Dictionary,p: Dictionary) -> void:
	var camera: Array=Schedule.invoke(p,"cameraPosition"); var cam:=M.normalize(M.subtract(particle.position10,camera))
	var spread:=M.f(M.f(e.spread)*M.f(0.5)); var count:=1-M.cvtt(M.f(spread*M.f(-100)))
	var first:=M.f(M.f(M.f(remainder(random_value(p),count))*STEP)*M.f(0.5))
	particle.quaternion34=M.multiply(rotation(e.basis140.slice(0,3),first,p),particle.quaternion34)
	var second:=M.f(M.f(M.f(remainder(random_value(p),628))*STEP)*M.f(0.5))
	particle.quaternion34=M.multiply(rotation(e.basis140.slice(6,9),second,p),particle.quaternion34)
	if M.f(e.deadspace)==0: return
	var original: Array=particle.quaternion34.duplicate(); var direction:=M.axis_y(original); var dot:=M.f(M.f(M.f(direction[1]*cam[1])+M.f(direction[0]*cam[0]))+M.f(direction[2]*cam[2])); var candidate: Array=original; var iterations:=0
	while absf(dot)<float(Schedule.invoke(p,"cosineDouble",[1.57079632-M.f(e.deadspace)])):
		iterations+=1
		assert(iterations<=4096,"Original particle camera dead-space failed to converge")
		if iterations>4096: return
		var dead:=M.f(e.deadspace); var angle:=M.f(M.f(dot-1.5707963705062866)+dead) if dot>=0 else M.f(M.f(dead+1.5707963705062866)-dot)
		candidate=M.multiply(rotation(M.cross(cam,direction),M.f(angle*M.f(0.5)),p),original); var y:=M.axis_y(candidate)
		dot=absf(M.f(M.f(M.f(cam[0]*y[0])+M.f(cam[1]*y[1]))+M.f(cam[2]*y[2])))
	particle.quaternion34=candidate
static func initialize(particle: Dictionary,e: Dictionary,delta: float,factor: float,p: Dictionary) -> void:
	particle.stopped70=0; particle.rotation1c=0.0; particle.field48=0; particle.age=0.0; particle.quaternion34=M.values(e.quaternion1d0); particle.inheritedSpeed20=0.0; particle.inheritedDirection24=[0.0,0.0,0.0]; particle.frame44=M.cvtt(e.frameStart)
	var jitter:=0; var random_velocity:=M.f(e.randomVelocity)
	if random_velocity>0.01:
		jitter=remainder(random_value(p),M.cvtt(M.f(random_velocity*100)))
		if random_value(p)%2>0: jitter=-jitter
	var x_size:=M.cvtt(M.f(M.f(M.f(e.xSize)*100)*M.f(factor))); var y_size:=M.cvtt(M.f(M.f(M.f(e.ySize)*100)*M.f(factor)))
	if x_size==0 and y_size==0: particle.position10=M.values(e.position1e0)
	else: random_position(particle,e,x_size,y_size,p)
	particle.trail64=particle.position10.duplicate()
	if int(e.flags)&128: inherit_velocity(particle,e,delta)
	if M.f(e.spread)!=0: random_direction(particle,e,p)
	particle.direction4c=M.axis_z(particle.quaternion34); var speed:=M.f(M.f(M.f(jitter)*STEP)+M.f(e.velocity)); var velocity: Array=[]
	for value in particle.direction4c: velocity.append(M.f(speed*value))
	particle.velocity58=velocity
static func create(e: Dictionary,delta: float,p: Dictionary) -> Dictionary:
	# The original stores an emitter pointer; explicit arguments avoid a native
	# Dictionary reference cycle between owner and active/free particle lists.
	var particle:={"position10":[0.0,0.0,0.0],"quaternion34":[1.0,0.0,0.0,0.0],"inheritedSpeed20":0.0,"inheritedDirection24":[0.0,0.0,0.0],"direction4c":[0.0,0.0,0.0],"velocity58":[0.0,0.0,0.0],"trail64":[0.0,0.0,0.0]}
	initialize(particle,e,delta,1,p); return particle
