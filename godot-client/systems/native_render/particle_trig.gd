extends RefCounted
const M=preload("res://systems/native_render/particle_math.gd")
# Bounded original CRT SSE reduction/polynomial. Used by recorded initialization
# profiles. Exceptional/large-angle and differing CPU-dispatch paths remain open.
const C=[0.041666666666666664,-0.0013888888888888887,0.000024801587301587298,-2.755731922398589e-7]
const S=[-0.16666666666666666,0.008333333333333333,-0.0001984126984126984,0.0000027557319223985893]
static func exponent(value: float) -> int:
	return int((PackedFloat64Array([value]).to_byte_array().decode_u64(0)>>52)&2047)
static func polynomial(value: float,cosine: bool) -> float:
	var square:=value*value; var fourth:=square*square; var coefficients: Array=C if cosine else S
	var correction: float=(coefficients[3]*square+coefficients[2])*fourth+(coefficients[1]*square+coefficients[0])
	return (-0.5*square+1)+correction*fourth if cosine else value+correction*(value*square)
static func trig(value: float,cosine: bool) -> float:
	value=M.f(value); var absolute:=absf(value)
	assert(is_finite(value) and absolute<500000,"Unmapped native CRT particle angle")
	if not cosine and absolute<0.0001220703125: return value
	if absolute<=0.7853981633974483:
		if absolute<0.0078125 and not cosine: return M.f(value-(value*value*value)*(1.0/6.0))
		return M.f(polynomial(value,cosine))
	var quadrant:=int(absolute*0.6366197723675814+0.5); var first:=absolute-1.5707963267341256*quadrant
	var reduced:=first-6.077100506506192e-11*quadrant; var initial_exponent:=exponent(reduced)
	if exponent(absolute)-initial_exponent>15:
		var next_value:=first-6.077100506303966e-11*quadrant
		reduced=next_value-(2.0222662487959506e-21*quadrant-((first-next_value)-6.077100506303966e-11*quadrant))
	var use_cosine: bool=(quadrant&1)==0 if cosine else (quadrant&1)!=0; var result: float
	if initial_exponent<1010:
		if initial_exponent<=990: result=1.0 if use_cosine else reduced
		else: result=1-(reduced*reduced)*0.5 if use_cosine else reduced-((1.0/6.0)*reduced)*(reduced*reduced)
	else: result=polynomial(reduced,use_cosine)
	var negative: bool=((quadrant+1)&2)!=0 if cosine else ((quadrant>>1)&1)!=int(value<0)
	return M.f(-result if negative else result)
static func cosine(value: float) -> float: return trig(value,true)
static func sine(value: float) -> float: return trig(value,false)
