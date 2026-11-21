extends RefCounted
# Process-wide CNWCProjectile random angle side, shared across areas and actors.
const M=preload("res://systems/native_render/particle_math.gd")
const NativeMath=preload("res://systems/native_data/native_math.gd")
const ProjectileMath=preload("res://systems/native_data/native_projectile_math.gd")
static var angle_side:=0
static func draw(p: Dictionary) -> int:
	if not p.has("random") or not p.random is Callable:
		push_error("Native random projectile provider random is unavailable")
		return -1
	var value: Variant=p.random.call()
	# JS Number.isInteger accepts an integral Number even when the provider
	# represents it as a floating-point value.
	if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or float(value)<0.0 or float(value)>32767.0:
		push_error("Native projectile CRT draw is unavailable")
		return -1
	return int(value)
static func initialize(s: Dictionary,orientation: Array,delta: Array,time: float,p: Dictionary) -> bool:
	var kind:=int(s.node.kind)
	if kind not in [4,9,12]:
		push_error("Native projectile initialization kind %d is unavailable" % kind)
		return false
	var normalized:=M.normalize(orientation)
	for i in 3:orientation[i]=normalized[i]
	var angle:=ProjectileMath.native_acosf(float(orientation[0]))
	if not is_finite(angle):return false
	if orientation[1]<0:angle=M.f(M.f(2.0*PI)-angle)
	var first:=draw(p)
	if first<0:return false
	var offset:=M.f(M.f(float(first%900)/10.0)*M.f(0.017453292))
	angle=M.f(angle-offset) if angle_side!=0 else M.f(angle+offset)
	var vector: Array=[NativeMath.native_cosf(angle),NativeMath.native_sinf(angle),0.0]
	if kind==9:
		var sign_draw:=draw(p)
		var value:=draw(p)
		if sign_draw<0 or value<0:return false
		vector[2]=M.f(float(value%50)/-100.0) if sign_draw%2==0 else M.f(float(value%100)/100.0)
	else:
		var value:=draw(p)
		if value<0:return false
		vector[2]=M.f(float(value%100)/100.0)
	angle_side=1 if angle_side==0 else 0
	var length:=M.f(sqrt(M.f(M.f(M.f(M.f(delta[0])*M.f(delta[0]))+M.f(M.f(delta[1])*M.f(delta[1])))+M.f(M.f(delta[2])*M.f(delta[2])))))
	var speed_range:=ProjectileMath.speed_range(length)
	if speed_range<=0:return false
	var speed_draw:=draw(p)
	if speed_draw<0:return false
	var speed:=M.f(float(speed_draw%speed_range)+3.0)
	var normal:=M.normalize(vector)
	s.velocity=[]
	for value in normal:s.velocity.append(M.f(speed*float(value)))
	var scale_value:=M.f(1.0/M.f(time*time))
	s.acceleration=[]
	for i in 3:
		var remaining:=M.f(M.f(delta[i])-M.f(time*float(s.velocity[i])))
		s.acceleration.append(M.f(M.f(remaining+remaining)*scale_value))
	if kind==12:
		if not p.has("linkRandomModel") or not p.linkRandomModel is Callable:
			push_error("Native random projectile provider linkRandomModel is unavailable")
			return false
		s.auxiliaryModel=p.linkRandomModel.call(s)
	return true
