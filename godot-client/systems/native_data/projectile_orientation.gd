extends RefCounted
# Original projectile9ddda0/AI983860: Pitch/Yaw then YawPitchRoll. Finite
# CRT SSE branches from retained native_math.js; no engine look_at substitute.
const M=preload("res://systems/native_render/particle_math.gd")
const ATAN=preload("res://systems/native_data/projectile_atan_table.gd").VALUES
static func exponent(value: float) -> int: return (PackedFloat64Array([value]).to_byte_array().decode_u64(0)>>52)&2047
static func negative(value: float) -> bool: return (PackedFloat32Array([value]).to_byte_array().decode_u32(0)>>31)!=0
static func atanf(value: float) -> float:
	value=M.f(value)
	if is_nan(value): return NAN
	var sign:=negative(value); var x:=absf(value); var offset:=0.0
	if x<0.4375: pass
	elif x<0.6875: offset=0.4636476090008061; x=(x+x-1)/(x+2)
	elif x<1.1875: offset=0.7853981633974483; x=(x-1)/(x+1)
	elif x<2.4375: offset=0.982793723247329; x=(x-1.5)/(x*1.5+1)
	elif x>5512405943901487000.0: return -M.f(1.5707963267948966) if sign else M.f(1.5707963267948966)
	else: offset=1.5707963267948966; x=-1/x
	var square:=x*x; var numerator:=((square*0.004706779342861492+0.19232454640210858)*square+0.2965285988192392)*(square*x)
	var denominator: float=(square*0.2993096999596597+1.1107249999539954)*square+0.8895857968624323
	var output: float=offset-(numerator/denominator-x)
	return M.f(-output if sign else output)
static func atan2f(y: float,x: float) -> float:
	y=M.f(y); x=M.f(x)
	if not is_finite(y) or not is_finite(x): return NAN
	var nx:=negative(x); var ny:=negative(y); var pi:=M.f(3.141592653589793); var half_pi:=M.f(1.5707963267948966)
	if y==0: return (-pi if ny else pi) if nx else y
	var delta:=exponent(y)-exponent(x)
	if x==0 and ny: return -half_pi
	if delta>26: return -half_pi if ny else half_pi
	if delta< -13 and not nx:
		if delta< -150: return -0.0 if ny else 0.0
		# The original scaled-ratio exponent adjustment is exact scaling by
		# 2^100 for finite float32 inputs; their double ratio remains normal.
		return M.f(y/x)
	if delta< -26 and nx: return -pi if ny else pi
	var ax:=absf(x); var ay:=absf(y); var swapped:=ax<ay; var low:=ax if swapped else ay; var high:=ay if swapped else ax
	var angle:=low/high
	if angle>0.0625:
		var index:=int(angle*256+0.5); var residual: float=(low*256-index*high)/(index*low+high*256)
		angle=(residual+float(ATAN[index-16]))-((residual*residual)*residual)*0.33333333333224097
	elif angle>=0.0001:
		var square:=angle*angle; angle-=(0.3333333333333317-(0.19999999999393223-square*0.1428571356180717)*square)*(square*angle)
	if swapped: angle=1.5707963267948966-angle
	if nx: angle=3.141592653589793-angle
	if ny: angle=-angle
	return M.f(angle)
static func polynomial(value: float,cosine: bool) -> float:
	var square:=value*value; var fourth:=square*square
	var c: Array=[0.041666666666666664,-0.0013888888888888887,0.000024801587301587298,-2.755731922398589e-7] if cosine else [-0.16666666666666666,0.008333333333333333,-0.0001984126984126984,0.0000027557319223985893]
	var correction: float=(c[3]*square+c[2])*fourth+(c[1]*square+c[0])
	return (-0.5*square+1)+correction*fourth if cosine else value+correction*(value*square)
static func trig(value: float,cosine: bool) -> float:
	value=M.f(value); var absolute:=absf(value)
	if not is_finite(value) or absolute>=500000: return NAN
	if not cosine and absolute<0.0001220703125: return value
	if absolute<=0.7853981633974483:
		if not cosine and absolute<0.0078125: return M.f(value-(value*value*value)*(1.0/6.0))
		return M.f(polynomial(value,cosine))
	var quadrant:=int(absolute*0.6366197723675814+0.5); var first: float=absolute-1.5707963267341256*quadrant
	var reduced: float=first-6.077100506506192e-11*quadrant
	if exponent(absolute)-exponent(reduced)>15:
		var next: float=first-6.077100506303966e-11*quadrant
		reduced=next-(2.0222662487959506e-21*quadrant-((first-next)-6.077100506303966e-11*quadrant))
	var use_cosine:=((quadrant&1)==0) if cosine else ((quadrant&1)!=0)
	var small:=exponent((absolute-1.5707963267341256*quadrant)-6.077100506506192e-11*quadrant); var result: float
	if small<1010:
		if small<=990: result=1.0 if use_cosine else reduced
		else: result=1-(reduced*reduced)*0.5 if use_cosine else reduced-((1.0/6.0)*reduced)*(reduced*reduced)
	else: result=polynomial(reduced,use_cosine)
	var negate:=(((quadrant+1)&2)!=0) if cosine else (((quadrant>>1)&1)!=int(value<0))
	return M.f(-result if negate else result)
static func impact(vector: Array) -> Array:
	var v:=M.values(vector); var yaw:=M.f(atan2f(M.f(-v[0]),v[1])*M.f(57.295776)) if v[0]!=0 or v[1]!=0 else 0.0
	var pitch:=M.f(atan2f(v[2],M.f(sqrt(M.f(M.f(v[1]*v[1])+M.f(v[0]*v[0])))))*M.f(57.295776)); var q: Array=[1.0,0.0,0.0,0.0]
	if yaw!=0:
		var angle:=M.f(M.f(yaw*M.f(0.017453292))*0.5); var s:=trig(angle,false); q=[trig(angle,true),M.f(0*s),M.f(0*s),s]
	if pitch!=0:
		var angle:=M.f(M.f(pitch*M.f(0.017453292))*0.5); var s:=trig(angle,false); q=M.multiply(q,[trig(angle,true),s,M.f(0*s),M.f(0*s)])
	return q
static func model(vector: Array) -> Variant:
	var v:=M.values(vector); var length:=M.f(sqrt(M.f(M.f(M.f(v[0]*v[0])+M.f(v[1]*v[1]))+M.f(v[2]*v[2]))))
	return null if length<=M.f(0.0001) else impact(M.normalize(v))
