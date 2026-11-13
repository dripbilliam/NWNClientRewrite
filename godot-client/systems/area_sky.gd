extends Node3D

# Original sky geometry/UVs/textures, camera-centred and independent of the
# area fog/clip/light pass, as Scene::RenderSkyBoxes1400d28f0. Godot's reversed
# far depth replaces the original temporary 1000-unit projection/depth mask.
const Resources = preload("res://systems/visual_resources.gd")
const State = preload("res://systems/area_sky_state.gd")
var resources
var phases: Array = []
var instances: Dictionary = {}
var materials: Dictionary = {}
var sky_id := 0
var error := ""
var state := State.new()
var configured := false
var updates := 0
var camera: Camera3D
var last_period := -1
var last_cycle := false
var last_night := false
var last_draw: Array = []
var material_updates := 0
var horizon := ""
var horizon_color := Color.WHITE
var native_surface_output:=false # Explicit research world; default output unchanged.

func install(message: Dictionary) -> bool:
	error = ""
	if configured or not message.get("resources") is Dictionary or not message.get("phases") is Array:
		return _fail("Invalid or repeated sky resource set")
	var id := int(message.get("skyId", -1))
	if id < 0 or id > 255 or message.phases.size() != (0 if id == 0 else 4) or message.resources.size() > 5:
		return _fail("Invalid sky phase/resource count")
	var fade: Variant = message.get("horizon")
	if fade != null and (not fade is String or not message.resources.has(fade) or id == 0): return _fail("Sky horizon resource is absent")
	for phase in message.phases:
		if not phase is String or not message.resources.has(phase): return _fail("Sky phase resource is absent")
	resources = Resources.new()
	resources.configure({"connection":message.connection,"areaId":message.areaId,"generation":message.generation,"transferId":message.transferId})
	# All surfaces have one program; only their uniforms and blend order vary.
	# Do not create/compile identical shaders for every material and phase.
	var sky_shader: Shader = _shader(native_surface_output) if not message.resources.is_empty() else null
	for key in message.resources:
		if not resources.prepare_resource(key, message.resources[key]): return _fail(resources.error)
		var model = resources.instantiate_model(key, self)
		if model == null: return _fail(resources.error)
		instances[key] = model
		materials[key] = []
		for mesh in model.meshes.meshes_by_name.values():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.extra_cull_margin = 1000.0
			for index in mesh.mesh.get_surface_count():
				var original = mesh.get_active_material(index)
				if not original is BaseMaterial3D: return _fail("Sky surface has an unsupported original material")
				var pair: Array = []
				for overlay in [false, true]:
					var material := ShaderMaterial.new()
					material.shader = sky_shader
					material.render_priority = -126 if key == fade else -127 if overlay else -128
					material.set_shader_parameter("horizon", key == fade)
					material.set_shader_parameter("original_texture", original.albedo_texture)
					material.set_shader_parameter("textured", original.albedo_texture != null)
					color_parameter(material,"original_color",original.albedo_color,native_surface_output)
					material.set_shader_parameter("vertex_tint", original.vertex_color_use_as_albedo)
					material.set_shader_parameter("uv_scale", Vector2(original.uv1_scale.x, original.uv1_scale.y))
					material.set_shader_parameter("uv_offset", Vector2(original.uv1_offset.x, original.uv1_offset.y))
					pair.append(material)
				materials[key].append({"mesh":mesh,"surface":index,"base":pair[0],"overlay":pair[1]})
		model.hide()
	sky_id = id
	horizon = str(fade) if fade != null else ""
	phases = message.phases.duplicate()
	configured = true
	return true

static func _shader(native_output: bool=false) -> Shader:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, blend_mix;
uniform sampler2D original_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool textured;
uniform bool vertex_tint;
uniform vec4 original_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float sky_weight = 1.0;
uniform bool horizon = false;
uniform vec4 horizon_color : source_color = vec4(1.0);
void vertex() {
 vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
 clip.z = CLIP_SPACE_FAR * clip.w;
 POSITION = clip;
}
void fragment() {
 // PartTriMesh::Mat uses white + part/object alpha for sky phases. The
 // horizon flag replaces both mesh tint and part alpha with fog RGB + 1.
 vec4 value = horizon ? vec4(horizon_color.rgb, 1.0) : vec4(1.0, 1.0, 1.0, original_color.a);
 if (textured) value *= texture(original_texture, UV * uv_scale + uv_offset);
 if (vertex_tint) value *= COLOR;
 ALBEDO = value.rgb;
 ALPHA = value.a * sky_weight;
}
"""
	if native_output:
		# Original vsvtc/inc_standard converts vertex RGB before interpolation;
		# fstc uses the converted global color and texture, then RevertColorSpace.
		# Keep the resulting gamma-space surface through original alpha blending.
		shader.code=shader.code.replace("source_color, ","").replace(": source_color =", "=")
		shader.code=shader.code.replace("void vertex() {","varying vec4 native_vertex_color;\nvoid vertex() {\n native_vertex_color=vec4(sign(COLOR.rgb)*pow(abs(COLOR.rgb),vec3(2.2)),COLOR.a);")
		shader.code=shader.code.replace("if (textured) value *= texture(original_texture, UV * uv_scale + uv_offset);", "value.rgb=sign(value.rgb)*pow(abs(value.rgb),vec3(2.2));\n if (textured){vec4 texel=texture(original_texture,UV*uv_scale+uv_offset); value*=vec4(sign(texel.rgb)*pow(abs(texel.rgb),vec3(2.2)),texel.a);}")
		shader.code=shader.code.replace("if (vertex_tint) value *= COLOR;", "if (vertex_tint) value *= native_vertex_color;\n value.rgb=sign(value.rgb)*pow(abs(value.rgb),vec3(0.45454545));")
	return shader

static func color_parameter(material: ShaderMaterial,key: String,value: Color,native_output: bool=false) -> void:
	# Godot converts Color shader parameters for the linear renderer even without
	# a source_color hint. Vector4 preserves the original gamma-space channels.
	material.set_shader_parameter(key,Vector4(value.r,value.g,value.b,value.a) if native_output else value)

func advance(source: Dictionary, elapsed: float, fog: Variant = null) -> void:
	if not configured or phases.is_empty() or not is_instance_valid(camera): return
	global_position = camera.global_position
	if fog is Color: horizon_color = fog
	var fields: Dictionary = source.fields
	var cycle := bool(fields.d8)
	var period := int(source.time.timeOfDay)
	var night := bool(fields.dc) if not cycle else period in [2, 3]
	if last_period != period or last_cycle != cycle or last_night != bool(fields.dc):
		state.reset(3 if night else 1)
		last_period = period; last_cycle = cycle; last_night = bool(fields.dc)
	var mode := "dawn" if cycle and period == 3 else "dusk" if cycle and period == 4 else "fixed"
	state.advance(mode, elapsed, float(source.minutesPerHour) * 60.0, night)
	var weights: Array = [state.current,state.target,state.alpha,horizon_color if not horizon.is_empty() else Color.WHITE]
	if weights != last_draw:
		for model in instances.values(): model.hide()
		_apply(state.current, 1.0 - state.alpha, false)
		if state.alpha > 0: _apply(state.target, state.alpha, true)
		if not horizon.is_empty():
			instances[horizon].show()
			for row in materials[horizon]:
				row.base.set_shader_parameter("sky_weight",1.0)
				color_parameter(row.base,"horizon_color",horizon_color,native_surface_output)
				row.mesh.set_surface_override_material(int(row.surface),row.base)
		last_draw = weights
		material_updates += 1
	updates += 1

func _apply(index: int, weight: float, additive: bool) -> void:
	if index < 0 or index >= phases.size() or weight <= 0: return
	var key: String = phases[index]
	# A non-cyclical row may use the same resource for all four periods. Avoid
	# overwriting its one live surface with its own second blend contribution.
	if additive and phases[state.current] == key: return
	instances[key].show()
	for row in materials[key]:
		var material: ShaderMaterial = row.overlay if additive else row.base
		material.set_shader_parameter("sky_weight", 1.0 if phases[state.current] == phases[state.target] else weight)
		row.mesh.set_surface_override_material(int(row.surface), material)

func snapshot() -> Dictionary:
	return {"configured":configured,"skyId":sky_id,"resources":instances.keys(),"phases":phases.duplicate(),"imports":resources.stats.imports if resources != null else 0,"updates":updates,"materialUpdates":material_updates,"current":state.current,"target":state.target,"alpha":state.alpha,"position":[position.x,position.y,position.z],"error":error,"horizon":horizon,"horizonColor":[horizon_color.r,horizon_color.g,horizon_color.b],"native_surface_output":native_surface_output,"blend":"normal-alpha","fullRenderingParity":false}

func _fail(reason: String) -> bool:
	error = reason
	return false
