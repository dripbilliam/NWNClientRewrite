extends WorldEnvironment
const Timing=preload("res://systems/native_render/frame_profile.gd")

const Core = preload("res://systems/area_environment_state.gd")
var camera: Camera3D
var controller
var sunlight: DirectionalLight3D
var source: Dictionary = {}
var elapsed := 0.0
var revision := -1
var sample: Dictionary = {}
var range_state: Dictionary = {}
var updates := 0
var colors: Dictionary = {}
var phase_updates := 0
var sky
var weather = preload("res://systems/weather_state.gd").new()
var weather_revision := -1
var weather_rows: Dictionary = {}
var weather_fades: Dictionary = {}
var weather_clock_fraction := 0.0
var weather_world

func receive_weather(message: Dictionary) -> bool:
	var next := int(message.get("revision",-1))
	if next <= weather_revision or not message.get("weather") is Dictionary or not message.get("rows") is Dictionary: return false
	var value: Dictionary = message.weather
	if not value.get("enabled") is bool: return false
	var type_value := float(value.get("type",NAN))
	if not is_finite(type_value) or type_value != floor(type_value) or type_value < 0 or type_value > 255: return false
	var fades: Dictionary = {}
	for key in message.rows:
		if not str(key).is_valid_int() or int(key) < 0 or int(key) > 255 or not message.rows[key] is Dictionary: return false
		var duration := float(message.rows[key].get("fadeTime",NAN))
		if not is_finite(duration) or duration != floor(duration) or duration < -2147483648 or duration > 2147483647: return false
		fades[str(key)] = int(duration)
	weather_rows = message.rows.duplicate(true);weather_fades = fades;weather_revision = next
	weather.request(int(type_value),value.enabled)
	return true

func advance_weather(delta: float) -> void:
	if weather_revision < 0 or delta < 0 or not is_finite(delta): return
	# Keep sub-millisecond time across rendered frames. The state transition
	# itself consumes integer elapsed milliseconds, as the native area update.
	weather_clock_fraction += delta*1000.0
	var milliseconds := int(weather_clock_fraction)
	weather_clock_fraction -= milliseconds
	weather.advance(milliseconds,weather_fades)
	if is_instance_valid(weather_world): weather_world.advance(weather)

func receive_sky(message: Dictionary) -> bool:
	var next = preload("res://systems/area_sky.gd").new()
	add_child(next)
	if not next.install(message):
		push_warning(next.error)
		next.free()
		return false
	if is_instance_valid(sky): sky.free()
	sky = next
	sky.camera = camera
	if not source.is_empty() and not sample.is_empty(): sky.advance(source,elapsed,rgb(sample.fog))
	return true

func configure(metadata: Dictionary,room: Node) -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 1.0
	environment.ambient_light_sky_contribution = 0.0
	# Exported Three colors are linear. Raw native area colors below are packed
	# RGB inputs and must not undergo this conversion a second time.
	if metadata.get("background") is Array and metadata.background.size() == 3:
		environment.background_color = rgb(metadata.background).linear_to_srgb()
	if metadata.get("ambient") is Array: environment.ambient_light_color = rgb(metadata.ambient).linear_to_srgb()
	for light in metadata.get("lights",[]):
		if light.get("areaPrimary",false):
			var node := room.find_child(str(light.name),true,false)
			if node is DirectionalLight3D: sunlight = node
	# After the camera and connection owners; no bridge/JS calls per frame.
	process_priority = 90

static func rgb(v: Array) -> Color: return Color(float(v[0]),float(v[1]),float(v[2]))
static func packed(value: int) -> Array:
	return [Core.f(float(value&255)/255.0),Core.f(float((value>>8)&255)/255.0),Core.f(float((value>>16)&255)/255.0)]

func receive(message: Dictionary) -> bool:
	var next := int(message.get("revision",-1))
	if next <= revision or not message.get("state") is Dictionary: return false
	var state: Dictionary = message.state
	var fields: Dictionary = state.get("fields",{})
	for key in ["98","9c","a0","a4","a8","b8","bc","c0","c4","c8","d8","dc","e0","104","108"]:
		if not fields.has(key) or not is_finite(float(fields[key])): return false
	if not state.get("time") is Dictionary or not is_finite(float(state.get("elapsed",NAN))) or not is_finite(float(state.get("minutesPerHour",NAN))) or float(state.minutesPerHour) <= 0: return false
	var period := int(state.time.get("timeOfDay",-1))
	if period < 0 or period > 4: return false
	source = state.duplicate(true); elapsed = Core.f(state.elapsed); revision = next
	colors = {"moonAmbient":packed(int(fields["98"])),"moonDiffuse":packed(int(fields["9c"])),"moonFog":packed(int(fields.a0)),"sunAmbient":packed(int(fields.b8)),"sunDiffuse":packed(int(fields.bc)),"sunFog":packed(int(fields.c0))}
	sample.clear()
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_energy = 1.0
	environment.fog_density = 1.0
	environment.fog_depth_curve = 1.0
	environment.fog_height_density = 0.0
	environment.fog_sun_scatter = 0.0
	environment.fog_aerial_perspective = 0.0
	if not is_instance_valid(sunlight):
		sunlight = DirectionalLight3D.new(); sunlight.name = "NativeAreaSun"; add_child(sunlight)
	advance(0)
	return true

func _process(delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(delta)
	Timing.finish("callback_environment",began)
func _profile_process(delta: float) -> void:
	advance(delta)
	advance_weather(delta)

func advance(delta: float) -> void:
	if source.is_empty() or not is_instance_valid(camera): return
	elapsed = Core.f(elapsed+Core.f(delta))
	var fields: Dictionary = source.fields
	var period := int(source.time.timeOfDay)
	var cycle := bool(fields.d8)
	var night := bool(fields.dc) if not cycle else period in [2,3]
	var mode := "dawn" if cycle and period == 3 else "dusk" if cycle and period == 4 else "fixed"
	if sample.is_empty() or not sample.complete:
		sample = Core.phase_sample(colors,{"moon":fields.a4,"sun":fields.c4},mode,elapsed,Core.f(float(source.minutesPerHour)*60),fields["104"],night)
		var fog := rgb(sample.fog)
		environment.background_color = fog
		environment.ambient_light_color = rgb(sample.ambient)
		environment.fog_light_color = fog
		_apply_sun(fields)
		phase_updates += 1
	var distance: float = float(controller.distance) if is_instance_valid(controller) else 20.0
	if is_instance_valid(controller) and controller.follow_state != null: distance = controller.follow_state.state.distance
	range_state = Core.fog_range(camera.near,fields["108"],distance,sample.amount,int(fields.e0) != 0,true)
	# Godot setters maintain begin<=end, including when the new interval is
	# wholly before/after the previous one. Native negative starts are retained.
	if range_state.start != environment.fog_depth_begin or range_state.end != environment.fog_depth_end:
		if range_state.start > environment.fog_depth_end: environment.fog_depth_end = range_state.end
		environment.fog_depth_begin = range_state.start
		environment.fog_depth_end = range_state.end
	if camera.far != range_state.far: camera.far = range_state.far
	if is_instance_valid(sky): sky.advance(source,elapsed,rgb(sample.fog))
	updates += 1

func _apply_sun(fields: Dictionary) -> void:
	var moon: bool = sample.isNight
	var direction := Vector3(float(fields.get("ac" if moon else "cc",0)),float(fields.get("b4" if moon else "d4",0)),-float(fields.get("b0" if moon else "d0",0)))
	if not direction.is_zero_approx():
		var z := direction.normalized()
		sunlight.global_basis = Basis.looking_at(-z,Vector3.RIGHT if absf(z.dot(Vector3.UP)) > .999 else Vector3.UP)
	# No guessed light direction for old packets that omit the direction.
	sunlight.light_color = rgb(sample.diffuse)
	sunlight.light_energy = 1.0 if not direction.is_zero_approx() else 0.0
	sunlight.shadow_enabled = bool(fields.a8 if moon else fields.c8)
	sunlight.shadow_opacity = sample.shadow

func snapshot() -> Dictionary:
	return {"revision":revision,"updates":updates,"phaseUpdates":phase_updates,"elapsed":elapsed,"sample":sample.duplicate(true),"range":range_state.duplicate(true),"fog":environment.fog_enabled,"background":[environment.background_color.r,environment.background_color.g,environment.background_color.b],"sky":sky.snapshot() if is_instance_valid(sky) else null,"weather":weather.snapshot() if weather_revision >= 0 else null}
