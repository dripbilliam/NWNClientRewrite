extends RefCounted
# Isolated original-SSE perspective half-FOV candidate. GDS float arithmetic
# is f64, matching each separate MULSD/ADDSD/SUBSD/DIVSD. f32 codec boundaries
# match half-angle MULSS, original DegToRad MULSS and final CVTSD2SS.
# No FMA, host tan, arbitrary-radian API, scene owner or production import.
const ORIGINAL_BRANCH="original-sse"
const RAW={
	"degrees_to_radians":"35fa8e3c",
	"poly_n0":"ad6afd6eba9d91bf","poly_n1":"17cb56dab0a8d83f",
	"poly_d0":"d992c60390e2923f","poly_d1":"1b51b3d76672e0bf","poly_d2":"2e3ae7a3847ef23f",
	"small_cubic":"555555555555d53f","tiny_threshold":"000000000000403e","cubic_threshold":"000000000000203f",
	"reduction_round":"000000000000e03f","pi_over_two_hi":"00004054fb21f93f","pi_over_two_lo":"3163621a61b4d03d",
	"two_over_pi":"83c8c96d305fe43f","reciprocal_numerator":"000000000000f0bf","direct_threshold":"182d4454fb21e93f",
	"tiny_status_multiplier":"ffff7f3f","tiny_status_addend":"0000804f"}
static var _constants: Dictionary=_decode_constants()
static func _decode_constants() -> Dictionary:
	var result: Dictionary={}
	for name in RAW:
		var bytes: PackedByteArray=RAW[name].hex_decode()
		result[name]=bytes.decode_float(0) if bytes.size()==4 else bytes.decode_double(0)
	return result
static func f32(value: float) -> float:return PackedFloat32Array([value])[0]
static func word(value: float) -> int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
static func scalar(value: int) -> float:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_u32(0,value);return bytes.decode_float(0)
static func _rational(x: float) -> float:
	# Original d830..d87c / da5d..daa5. Separate VM operations preclude FMA.
	var square: float=x*x
	var numerator: float=_constants.poly_n0*square
	numerator=numerator+_constants.poly_n1
	var denominator: float=_constants.poly_d0*square
	denominator=denominator+_constants.poly_d1
	denominator=denominator*square
	denominator=denominator+_constants.poly_d2
	var quotient: float=numerator/denominator
	var correction: float=square*x
	correction=correction*quotient
	return x+correction
static func evaluate(angle_value: Variant,cpu_branch: String) -> Dictionary:
	if cpu_branch!=ORIGINAL_BRANCH:return {"available":false,"reason":"native-tangent-candidate-cpu-branch-unavailable"}
	if not (angle_value is int or angle_value is float) or not is_finite(float(angle_value)):return {"available":false,"reason":"native-tangent-candidate-angle-unavailable"}
	var angle:=f32(float(angle_value))
	if not is_finite(angle) or angle<=0.0 or angle>=180.0:return {"available":false,"reason":"native-tangent-candidate-native-angle-outside-perspective-domain"}
	var half:=f32(angle*.5)
	var radians:=f32(half*_constants.degrees_to_radians)
	var x: float=radians;var result: float;var path: String
	if x<=_constants.direct_threshold:
		if x<_constants.cubic_threshold:
			if x<_constants.tiny_threshold:
				# Original performs two discarded f32 ops only to raise FP
				# status; returned XMM0 is unchanged. Status is not emulated.
				result=x;path="tiny-return"
			else:
				var cube: float=x*x
				cube=cube*x
				cube=cube*_constants.small_cubic
				result=cube+x;path="cubic"
		else:result=_rational(x);path="direct-rational"
	else:
		# For native0<angle<180, radians<pi/2. Native nearest quadrant
		# is1 here; huge-radian multi-limb reduction is unreachable.
		var scaled: float=x*_constants.two_over_pi
		scaled=scaled+_constants.reduction_round
		var quadrant:=int(scaled)
		if quadrant!=1:return {"available":false,"reason":"native-tangent-candidate-domain-proof-failed"}
		var high: float=float(quadrant)*_constants.pi_over_two_hi
		var reduced: float=x-high
		var low: float=float(quadrant)*_constants.pi_over_two_lo
		reduced=reduced-low
		result=_rational(reduced)
		result=_constants.reciprocal_numerator/result
		path="reduced-reciprocal"
	var tangent:=f32(result)
	return {"available":true,"half_tangent_angle_word":word(angle),"half_angle_word":word(half),"radians_word":word(radians),"half_tangent_word":word(tangent),"branch":ORIGINAL_BRANCH,"path":path,"plane_usable":is_finite(tangent) and tangent>0.0,"source":"DegToRad22c210/tanf-c7d790-SSE-domain-port-v1"}
