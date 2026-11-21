extends RefCounted
# Direct translation of bounded finite native_math.js CRT float32 branches.
# The accepted result requires identical SSE and fused-dispatch float32 bits.
const M=preload("res://systems/native_render/particle_math.gd")
const ATAN=preload("res://systems/native_data/projectile_atan_table.gd").VALUES
const PI4:=0.7853981633974483
const INV_PI2:=0.6366197723675814
const PI2_HI:=1.5707963267341256
const PI2_LO:=6.077100506506192e-11
const PI2_HI2:=6.077100506303966e-11
const PI2_LO2:=2.0222662487959506e-21
const C=[0.041666666666666664,-0.0013888888888888887,0.000024801587301587298,-2.755731922398589e-7]
const S=[-0.16666666666666666,0.008333333333333333,-0.0001984126984126984,0.0000027557319223985893]
static var last_error: String=""

static func _fail(reason: String)->float:
	last_error=reason
	push_error(reason)
	return NAN
static func _f(value: float)->float:return M.f(value)
static func _bits32(value: float)->int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
static func _from_bits32(word: int)->float:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_u32(0,word&0xffffffff)
	return bytes.decode_float(0)
static func _negative(value: float)->bool:return (_bits32(value)&0x80000000)!=0
static func _exponent(value: float)->int:return (PackedFloat64Array([value]).to_byte_array().decode_u64(0)>>52)&2047
static func _fma64(a: float,b: float,c: float)->float:
	if not ClassDB.class_exists(&"NwnNativeMath") or not ClassDB.class_has_method(&"NwnNativeMath",&"fma64"):return _fail("Native fma64 binding is unavailable")
	return ClassDB.class_call_static(&"NwnNativeMath",&"fma64",a,b,c)

static func native_cosf(value: float)->float:return _native_trig(value,true)
static func native_sinf(value: float)->float:return _native_trig(value,false)

static func _native_trig(value: float,cosine: bool)->float:
	value=_f(value)
	if not is_finite(value) or absf(value)>=500000:return _fail("Native trigonometric input branch is not implemented")
	last_error=""
	var sse:=_trig_branch(value,cosine,false)
	if not last_error.is_empty():return NAN
	var fused:=_trig_branch(value,cosine,true)
	if not last_error.is_empty():return NAN
	if _bits32(sse)!=_bits32(fused):return _fail("Native trigonometric CPU dispatch produces different float32 results")
	return sse

static func _polynomial(value: float,cosine: bool,fused: bool)->float:
	var square:=value*value
	var fourth:=square*square
	var coefficients: Array=C if cosine else S
	var correction: float
	if fused:
		correction=_fma64(coefficients[3],square,coefficients[2])
		correction=_fma64(correction,square,coefficients[1])
		correction=_fma64(correction,square,coefficients[0])
		return _fma64(correction,fourth,1-square*0.5) if cosine else _fma64(correction,value*square,value)
	correction=(coefficients[3]*square+coefficients[2])*fourth+(coefficients[1]*square+coefficients[0])
	return (-0.5*square+1)+correction*fourth if cosine else value+correction*(value*square)

static func _trig_branch(value: float,cosine: bool,fused: bool)->float:
	var absolute:=absf(value)
	if not cosine and absolute<0.0001220703125:return value
	if absolute<=PI4:
		if absolute<0.0078125:
			if not cosine:return _f(_fma64(-(value*value*value),1.0/6.0,value) if fused else value-(value*value*value)*(1.0/6.0))
			if fused:return 1.0 if absolute<0.0001220703125 else _f(_fma64(-(value*0.5),value,1.0))
		return _f(_polynomial(value,cosine,fused))
	var quadrant:=int(_fma64(absolute,INV_PI2,0.5) if fused else absolute*INV_PI2+0.5)
	var reduced: float
	if fused:reduced=_fma64(-float(quadrant),PI2_HI,absolute)-quadrant*PI2_LO
	else:
		var first:=absolute-PI2_HI*quadrant
		reduced=first-PI2_LO*quadrant
		if _exponent(absolute)-_exponent(reduced)>15:
			var next:=first-PI2_HI2*quadrant
			reduced=next-(PI2_LO2*quadrant-((first-next)-PI2_HI2*quadrant))
	var use_cosine: bool=((quadrant&1)==0) if cosine else ((quadrant&1)!=0)
	var small_exponent:=_exponent((absolute-PI2_HI*quadrant)-PI2_LO*quadrant)
	var result: float
	if not fused and small_exponent<1010:
		if small_exponent<=990:result=1.0 if use_cosine else reduced
		else:result=1-(reduced*reduced)*0.5 if use_cosine else reduced-((1.0/6.0)*reduced)*(reduced*reduced)
	else:result=_polynomial(reduced,use_cosine,fused)
	var negate: bool=(((quadrant+1)&2)!=0) if cosine else (((quadrant>>1)&1)!=int(value<0))
	if negate:result=-result
	return _f(result)

static func native_atanf(value: float)->float:
	value=_f(value)
	if is_nan(value):return _fail("Native atanf NaN/CRT exception state is not implemented")
	last_error=""
	var negative:=_negative(value)
	var x:=absf(value)
	var offset:=0.0
	if x<0.4375:pass
	elif x<0.6875:offset=0.4636476090008061;x=(x+x-1)/(x+2)
	elif x<1.1875:offset=0.7853981633974483;x=(x-1)/(x+1)
	elif x<2.4375:offset=0.982793723247329;x=(x-1.5)/(x*1.5+1)
	elif x>5512405943901487000.0:return -_f(1.5707963267948966) if negative else _f(1.5707963267948966)
	else:offset=1.5707963267948966;x=-1/x
	var square:=x*x
	var numerator:=((square*0.004706779342861492+0.19232454640210858)*square+0.2965285988192392)*(square*x)
	var denominator: float=(square*0.2993096999596597+1.1107249999539954)*square+0.8895857968624323
	var output: float=offset-(numerator/denominator-x)
	return _f(-output if negative else output)

static func native_asinf(value: float)->float:
	value=_f(value)
	if not is_finite(value) or absf(value)>1:return _fail("Native asinf exceptional input branch is not implemented")
	last_error=""
	var absolute:=absf(value)
	var exp:=_bits32(absolute)>>23
	if exp<0x71:return value
	if absolute==1:return -_f(1.5707963705062866) if value<0 else _f(1.5707963705062866)
	var z:=_f(absolute*absolute) if exp<0x7e else _f(_f(1-absolute)*0.5)
	var r:=_f(-0.013381929136812687-_f(z*0.003961374517530203))
	r=_f(_f(r*z)-0.05652986839413643)
	r=_f(_f(r*z)+0.18416160345077515)
	r=_f(_f(r*z)/_f(1.1049696207046509-_f(z*0.8364112973213196)))
	var output: float
	if exp<0x7e:output=_f(_f(r*absolute)+absolute)
	else:
		var root:=_f(sqrt(z))
		var split:=_from_bits32(_bits32(root)&0xffff0000)
		var correction_low:=_f(_f(z-_f(split*split))/_f(split+root))
		var correction:=_f(_f(_f(root*2)*r)-_f(7.549789415861596e-08-_f(correction_low+correction_low)))
		output=_f(0.7853981256484985-_f(correction-_f(0.7853981256484985-_f(split*2))))
	return -output if value<0 else output

static func native_atan2f(y: float,x: float)->float:
	y=_f(y);x=_f(x)
	if not is_finite(x) or not is_finite(y):return _fail("Native atan2f exceptional input branch is not implemented")
	last_error=""
	var negative_x:=_negative(x)
	var negative_y:=_negative(y)
	var pi:=_f(3.141592653589793)
	var half_pi:=_f(1.5707963267948966)
	if y==0:return (-pi if negative_y else pi) if negative_x else y
	var delta:=_exponent(y)-_exponent(x)
	if x==0 and negative_y:return -half_pi
	if delta>26:return -half_pi if negative_y else half_pi
	if delta< -13 and not negative_x:
		if delta< -150:return -0.0 if negative_y else 0.0
		# The old scaled-ratio exponent adjustment is exactly the same normal
		# binary64 quotient for finite float32 x/y; its exponent shift cancels.
		return _f(y/x)
	if delta< -26 and negative_x:return -pi if negative_y else pi
	var ax:=absf(x)
	var ay:=absf(y)
	var swapped:=ax<ay
	var low:=ax if swapped else ay
	var high:=ay if swapped else ax
	var angle:=low/high
	if angle>0.0625:
		var index:=int(angle*256+0.5)
		var residual: float=(low*256-index*high)/(index*low+high*256)
		angle=(residual+float(ATAN[index-16]))-((residual*residual)*residual)*0.33333333333224097
	elif angle>=0.0001:
		var square:=angle*angle
		angle-=(0.3333333333333317-(0.19999999999393223-square*0.1428571356180717)*square)*(square*angle)
	if swapped:angle=1.5707963267948966-angle
	if negative_x:angle=3.141592653589793-angle
	if negative_y:angle=-angle
	return _f(angle)
