extends RefCounted
# Module gameplay camera: NewCAurCamera/Camera ctor45deg; LoadModule's later
# +0x80 call is SetClipDist, not an FOV override. RenderScene preserves vertical
# tan(angle/2) and multiplies horizontal extent by actual viewport width/height.
const DEFAULT_DEGREES:=45.0
const MIN_DEGREES:=20.0
const MAX_DEGREES:=120.0
static func valid(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=MIN_DEGREES and float(value)<=MAX_DEGREES
static func apply(camera: Camera3D,value: Variant) -> bool:
	if not is_instance_valid(camera) or not valid(value):return false
	# Godot KEEP_HEIGHT preserves the vertical angle as viewport aspect changes.
	# Native Camera frustum Y=tan(angle/2), X=Y*aspect uses this same convention.
	if camera.keep_aspect!=Camera3D.KEEP_HEIGHT:camera.keep_aspect=Camera3D.KEEP_HEIGHT
	if camera.fov!=float(value):camera.fov=float(value)
	return true
static func horizontal_degrees(vertical_degrees: float,aspect: float) -> float:
	if not is_finite(vertical_degrees) or not is_finite(aspect) or aspect<=0 or vertical_degrees<=0 or vertical_degrees>=180:return NAN
	return rad_to_deg(2*atan(tan(deg_to_rad(vertical_degrees)*0.5)*aspect))
