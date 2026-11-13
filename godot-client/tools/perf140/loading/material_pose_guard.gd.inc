var pose_original_publications:=0
var pose_unchanged_skips:=0
var _pose_snapshot_ready:=false
var _pose_snapshot_shader: Shader
var _pose_snapshot_color:=Color.WHITE
var _pose_snapshot_emission:=Color.BLACK
var _pose_snapshot_blended:=false
var _pose_snapshot_bytes:=PackedByteArray()
func _pose_owner_state(color_value: Color,emission_value: Color,blended: bool) -> Array:
	# These are the resource owner's authoritative values. Do not reconstruct
	# gamma/color conversions, approximate floats, or query the rendering backend.
	return [color_value,emission_value,blended,albedo_color,emission,emission_enabled,transparency,get_shader_parameter(&"native_diffuse"),get_shader_parameter(&"native_alpha"),get_shader_parameter(&"native_emission"),get_shader_parameter(&"native_emission_enabled")]
static func _pose_finite_color(value: Color) -> bool:
	return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
static func _pose_finite_state(state: Array) -> bool:
	return _pose_finite_color(state[0]) and _pose_finite_color(state[1]) and _pose_finite_color(state[3]) and _pose_finite_color(state[4]) and state[7] is Vector3 and state[7].is_finite() and typeof(state[8])==TYPE_FLOAT and is_finite(state[8]) and state[9] is Vector3 and state[9].is_finite() and typeof(state[10])==TYPE_BOOL
func _pose_recapture(color_value: Color,emission_value: Color,blended: bool) -> void:
	var state:=_pose_owner_state(color_value,emission_value,blended)
	_pose_snapshot_ready=_pose_finite_state(state)
	_pose_snapshot_shader=shader;_pose_snapshot_color=color_value;_pose_snapshot_emission=emission_value;_pose_snapshot_blended=blended
	# Variant serialization preserves types and signed-zero bits. It records the
	# exact original outputs, rather than duplicating the color implementation.
	_pose_snapshot_bytes=var_to_bytes(state) if _pose_snapshot_ready else PackedByteArray()
