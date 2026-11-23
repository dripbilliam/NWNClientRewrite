extends WorldEnvironment
const Timing=preload("res://systems/native_render/frame_profile.gd")

const Core = preload("res://systems/area_environment_state.gd")
const Surface=preload("res://systems/native_render/native_surface_state.gd")
const LightPolicy=preload("res://systems/native_render/native_light_policy.gd")
const WeatherTable=preload("res://systems/native_data/two_da.gd")
const WeatherModels=preload("res://systems/native_render/cx_weather_models.gd")
var camera: Camera3D
var controller
var sunlight: DirectionalLight3D
var native_enhanced_lighting:=false
var native_surface_output:=false
var lighting_world: WeakRef
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
var cx_weather_source: Dictionary={}
var cx_weather_phase:=0.0
var cx_weather_wobble:=0.0
var cx_weather_running:=false
var cx_weather_loaded_rows:=false
var cx_weather_error:=""
var cx_weather_models: Node3D
var cx_weather_age:=0.0
var cx_weather_arrived:=false
var cx_roof_wetness:=0.0

func receive_cx_weather(value: Dictionary) -> bool:
	if value.is_empty(): return true
	var enabled: Variant=value.get("enabled")
	var type: Variant=value.get("type")
	if not (type is int or type is float) or not is_finite(float(type)) or type!=int(type) or type<0 or type>255: return false
	if not enabled is bool and not ((enabled is int or enabled is float) and (float(enabled)==0.0 or float(enabled)==1.0)): return false
	var request: Dictionary={"type":int(type),"enabled":bool(enabled)}
	if cx_weather_source==request: return true
	cx_weather_source=request
	if request.type!=0 and not cx_weather_loaded_rows:
		var room=lighting_world.get_ref() if lighting_world!=null else null
		if is_instance_valid(room) and room.get("catalog")!=null:
			var table: Dictionary=WeatherTable.new().parse(room.catalog.get_resource("weathertypes",2017).get_string_from_utf8())
			var rows: Array=table.get("orderedRows",[])
			for index in mini(rows.size(),256):
				var row: Dictionary=rows[index]
				var duration:=str(row.get("FadeTime",""))
				if duration.is_valid_int(): weather_fades[str(index)]=int(duration)
				var model:=_weather_name(row.get("Model",""))
				var animation:=_weather_name(row.get("Animation",""))
				var location: Dictionary=room.catalog.location(model,2002) if not model.is_empty() else {}
				weather_rows[str(index)]={"model":model,"animation":animation,"lightning":_weather_name(row.get("ModelLightning","")),
					"base_model":not location.is_empty() and location.layer.kind=="key"}
			cx_weather_loaded_rows=true
	weather_revision+=1
	weather.request(request.type,request.enabled)
	return true

static func _weather_name(value: Variant) -> String:
	var name:=str(value).strip_edges().to_lower()
	if name.is_empty() or name.length()>16: return ""
	for i in name.length():
		var character:=name.unicode_at(i)
		if not (character>=97 and character<=122 or character>=48 and character<=57 or character in [45,95]): return ""
	return name

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
	if delta < 0 or not is_finite(delta): return
	if not cx_weather_arrived: cx_weather_age+=delta
	if weather_revision < 0: return
	# Keep sub-millisecond time across rendered frames. The state transition
	# itself consumes integer elapsed milliseconds, as the native area update.
	weather_clock_fraction += delta*1000.0
	var milliseconds := int(weather_clock_fraction)
	weather_clock_fraction -= milliseconds
	weather.advance(milliseconds,weather_fades)
	if is_instance_valid(weather_world): weather_world.advance(weather)
	if not cx_weather_source.is_empty(): _publish_cx_precipitation(delta)

func _publish_cx_precipitation(delta: float) -> void:
	var room=lighting_world.get_ref() if lighting_world!=null else null
	if not is_instance_valid(room) or not room.has_meta("native_particle_stream_group"): return
	var group=room.get_meta("native_particle_stream_group")
	if not is_instance_valid(group) or not group.cx_records: return
	# CX classifies these physical WeatherTypes rows. Model and animation
	# overrides remain authored parts, including replacements with stock names.
	var kind:=1 if weather.current in [1,3,6,9] else 2 if weather.current in [2,4,5,10] else 0
	var recipe: Dictionary=weather_rows.get(str(weather.current),{})
	if kind!=0 and cx_weather_loaded_rows:
		var expected: String="rain" if kind==1 else "snow"
		if recipe.get("model")!="fx_"+expected or recipe.get("animation")!=expected or not recipe.get("base_model",false): kind=0
	if weather.instances>0 and kind==0:
		_advance_cx_weather_models(room,recipe)
	else:
		cx_weather_error=""
		_retire_cx_weather_models()
	var interior: bool=(int(source.get("fields",{}).get("8",0))&1)!=0
	var density: float=weather.intensity/100.0 if kind!=0 and weather.instances>0 and not interior else 0.0
	var raining:=kind==1 and density>0.0
	if interior:
		cx_roof_wetness=0.0
	else:
		# CX Weather.Surface ticks once per frame and clamps a long hiccup.
		if not cx_weather_arrived and density>0.0:
			if cx_weather_age<10.0: cx_roof_wetness=1.0 if raining else 0.0
			cx_weather_arrived=true
		var soak: float=density/60.0 if raining else -1.0/180.0
		cx_roof_wetness=clampf(cx_roof_wetness+minf(delta,0.25)*soak,0.0,1.0)
	var drip_wetness:=cx_roof_wetness if kind!=2 else 0.0
	if density==0.0 and drip_wetness==0.0:
		if cx_weather_running: group.set_weather({}); cx_weather_running=false
		return
	var dt:=minf(delta,0.1)
	cx_weather_phase=fmod(cx_weather_phase+dt*(1.2 if kind==2 else 12.0),52.0*1024.0)
	cx_weather_wobble=fmod(cx_weather_wobble+dt,400.0*PI)
	var wind: Array=room.point_wind.parameters.get("wind",[0.0,0.0,0.0]) if is_instance_valid(room.point_wind) else [0.0,0.0,0.0]
	var fall:=Vector3(0.6*float(wind[0]),-1.0,-0.6*float(wind[1])).normalized()
	var direction:=Vector3.ZERO
	var color:=Vector3.ZERO
	if is_instance_valid(sunlight) and sunlight.light_energy>0.0 and sample.has("diffuse"):
		direction=sunlight.global_basis.z.normalized()
		color=LightPolicy.linear_rgb(sample.diffuse)
	var sky_color: Vector4=sky.cx_fog_sky_color() if is_instance_valid(sky) and sky.has_method("cx_fog_sky_color") else Vector4.ZERO
	var ambient:=LightPolicy.linear_rgb(sample.ambient) if sample.has("ambient") else Vector3.ZERO
	var veil_ambient:=ambient
	var veil_sun:=Vector4.ZERO
	if raining:
		var blind: bool=is_instance_valid(room.focus_lighting) and room.focus_lighting.only_light_owner()!=0
		veil_ambient=LightPolicy.linear_rgb(sample.fog) if sample.has("fog") and not blind else Vector3.ZERO
		if sky_color.w>0.0 and not blind:
			veil_ambient=veil_ambient.lerp(Vector3(sky_color.x,sky_color.y,sky_color.z),0.5)
		var lum:=color.dot(Vector3(0.2126,0.7152,0.0722))
		if lum>0.0001 and not blind and not bool(sample.get("isNight",false)):
			var sun_share:=minf(lum,1.0)*0.5
			var beam: Vector3=(color/lum).min(Vector3.ONE*4.0)*sun_share
			veil_sun=Vector4(beam.x,beam.y,beam.z,sun_share)
	group.set_weather({"kind":kind,"density":density,"drip_wetness":drip_wetness,"phase":cx_weather_phase,"clock":cx_weather_wobble,
		"fall":fall,"ambient":ambient,"sun_direction":direction,"sun_color":color,"sky":Vector3(sky_color.x,sky_color.y,sky_color.z),
		"veil_ambient":veil_ambient,"veil_sun":veil_sun,"interior":interior})
	cx_weather_running=true

func _advance_cx_weather_models(room: Node,recipe: Dictionary) -> void:
	if is_instance_valid(cx_weather_models) and cx_weather_models.row_id!=weather.current: _retire_cx_weather_models()
	var model: String=recipe.get("model","")
	if model.is_empty():
		cx_weather_error="WeatherTypes row "+str(weather.current)+" has no original model"
		return
	var hub=room.get_meta("native_reference_hub") if room.has_meta("native_reference_hub") else null
	if not is_instance_valid(hub) or hub.closed: return
	if not is_instance_valid(cx_weather_models):
		cx_weather_models=WeatherModels.new()
		cx_weather_models.hide()
		room.add_child(cx_weather_models)
		cx_weather_models.prepare(hub,weather.current,model,recipe.get("animation",""))
	cx_weather_error=""
	var focus: Dictionary=room.shadow_focus()
	if focus.get("source","") not in ["controlled-actor","controlled-pose"] or not is_instance_valid(camera): return
	cx_weather_models.advance(focus.position,camera,weather.intensity/100.0)

func _retire_cx_weather_models() -> void:
	if is_instance_valid(cx_weather_models): cx_weather_models.retire()
	cx_weather_models=null

func _exit_tree() -> void:
	_retire_cx_weather_models()

func receive_sky(message: Dictionary) -> bool:
	var next = preload("res://systems/area_sky.gd").new()
	next.native_surface_output=native_surface_output
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
	lighting_world=weakref(room)
	native_enhanced_lighting=room.get_meta("native_enhanced_lighting",false)
	native_surface_output=room.get_meta("native_surface_output",false)
	# Native live worlds provide a data-only sky owner. The older GLB delivery
	# API remains confined to its reference fixtures/local_connection path.
	if room.has_meta("native_sky_owner"): sky=room.get_meta("native_sky_owner")
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
	if is_instance_valid(sky) and sky.has_method("select_sky"): sky.select_sky(int(fields.e0))
	colors = {"moonAmbient":packed(int(fields["98"])),"moonDiffuse":packed(int(fields["9c"])),"moonFog":packed(int(fields.a0)),"sunAmbient":packed(int(fields.b8)),"sunDiffuse":packed(int(fields.bc)),"sunFog":packed(int(fields.c0))}
	sample.clear()
	environment.fog_enabled = not native_surface_output
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
		# Godot decodes the color property into its linear framebuffer. The
		# candidate framebuffer instead carries native gamma-space values.
		environment.background_color = fog.linear_to_srgb() if native_surface_output else fog
		environment.ambient_light_color = rgb(sample.ambient)
		if native_enhanced_lighting: preload("res://systems/native_render/native_light_palette.gd").ambient(preload("res://systems/native_render/native_light_policy.gd").linear_rgb(sample.ambient))
		environment.fog_light_color = fog
		_apply_sun(fields)
		phase_updates += 1
	var room=lighting_world.get_ref() if lighting_world!=null else null
	var reference: WeakRef=room.get_meta("native_focus_light_owner") if is_instance_valid(room) and room.has_meta("native_focus_light_owner") else null
	var focus_owner=reference.get_ref() if reference!=null else null
	# Original Scene::DoFog replaces only the geometry fog RGB while m_pOnlyGob
	# is set. The clear color and sky/horizon still use the area's authored RGB.
	var blind: bool=is_instance_valid(focus_owner) and focus_owner.only_light_owner()!=0
	var geometry_fog:=Color.BLACK if blind else rgb(sample.fog)
	var cx_fog: bool=native_surface_output and is_instance_valid(room) and room.get_meta("native_cx_particles",false)
	if environment.fog_light_color!=geometry_fog: environment.fog_light_color=geometry_fog
	if is_instance_valid(focus_owner):
		focus_owner.set_area(sample.ambient,sample.diffuse)
		focus_owner.history_camera=weakref(camera); focus_owner.history_environment=weakref(self)
		if is_instance_valid(controller): focus_owner.focus=controller.target
	var distance: float = float(controller.distance) if is_instance_valid(controller) else 20.0
	if is_instance_valid(controller) and controller.follow_state != null: distance = controller.follow_state.state.distance
	range_state = Core.fog_range(camera.near,fields["108"],distance,sample.amount,int(fields.e0) != 0,true)
	if native_surface_output and is_instance_valid(room):
		Surface.publish(room,Vector3(geometry_fog.r,geometry_fog.g,geometry_fog.b),true,range_state.start,range_state.end)
	if is_instance_valid(focus_owner): focus_owner.history_radius=range_state.end
	# Godot setters maintain begin<=end, including when the new interval is
	# wholly before/after the previous one. Native negative starts are retained.
	if range_state.start != environment.fog_depth_begin or range_state.end != environment.fog_depth_end:
		if range_state.start > environment.fog_depth_end: environment.fog_depth_end = range_state.end
		environment.fog_depth_begin = range_state.start
		environment.fog_depth_end = range_state.end
	if is_instance_valid(sky):
		sky.camera=camera
		sky.advance(source,elapsed,null if cx_fog and sky.has_method("cx_fog_horizon") else rgb(sample.fog))
	var far_plane: float=_publish_cx_fog(room,blind) if cx_fog else range_state.far
	if camera.far!=far_plane: camera.far=far_plane
	updates += 1

func _publish_cx_fog(room: Node,blind: bool) -> float:
	var focus: Dictionary=room.shadow_focus() if room.has_method("shadow_focus") else {}
	var player: Vector3=focus.get("position",Vector3.ZERO)
	var radial: bool=focus.get("source","") in ["controlled-actor","controlled-pose"]
	var origin:=Vector4(player.x,player.y,player.z,1.0 if radial else 0.0)
	var height:=maxf(0.0,environment.fog_height_density)
	var layer:=Vector4(height,environment.fog_height if height>0.0 else player.y,0.0,1.0)
	var has_sky: bool=is_instance_valid(sky) and sky.has_method("cx_fog_sky_color")
	var sky_color: Vector4=sky.cx_fog_sky_color() if has_sky and not blind else Vector4.ZERO
	var sun:=Vector4.ZERO
	var sun_color:=Vector4.ZERO
	if sky_color.w>0.0 and is_instance_valid(sunlight) and sunlight.light_energy>0.0:
		var direction:=sunlight.global_basis.z.normalized()
		sun=Vector4(direction.x,direction.y,direction.z,8.0)
		var diffuse:=LightPolicy.linear_rgb(sample.diffuse)
		if native_enhanced_lighting:
			var current:=sunlight.light_color.srgb_to_linear()
			diffuse=Vector3(current.r,current.g,current.b)
		sun_color=Vector4(diffuse.x,diffuse.y,diffuse.z,0.0)*0.35
	Surface.publish_cx(room,origin,sky_color,layer,sun,sun_color)
	if has_sky:
		var horizon:=LightPolicy.linear_rgb(sample.fog).lerp(Vector3(sky_color.x,sky_color.y,sky_color.z),sky_color.w)
		sky.cx_fog_horizon(Color(pow(horizon.x,1.0/2.2),pow(horizon.y,1.0/2.2),pow(horizon.z,1.0/2.2)))
	return maxf(range_state.far,range_state.end+camera.global_position.distance_to(player)) if radial else range_state.far

func apply_native_area_light(ambient: Vector3,diffuse: Vector3) -> void:
	# Native history supplies already converted raw-color * fade. Preserve sun
	# direction, shadows and fog; only the two independent RGB channels change.
	preload("res://systems/native_render/native_light_palette.gd").ambient(ambient)
	if is_instance_valid(sunlight): sunlight.light_color=Color(diffuse.x,diffuse.y,diffuse.z).linear_to_srgb()

func _apply_sun(fields: Dictionary) -> void:
	var moon: bool = sample.isNight
	var direction := Vector3(float(fields.get("ac" if moon else "cc",0)),float(fields.get("b4" if moon else "d4",0)),-float(fields.get("b0" if moon else "d0",0)))
	if not direction.is_zero_approx():
		var z := direction.normalized()
		sunlight.global_basis = Basis.looking_at(-z,Vector3.RIGHT if absf(z.dot(Vector3.UP)) > .999 else Vector3.UP)
	# No guessed light direction for old packets that omit the direction.
	sunlight.light_color = rgb(sample.diffuse)
	if native_enhanced_lighting:
		var value: Vector3=preload("res://systems/native_render/native_light_policy.gd").linear_rgb(sample.diffuse)
		sunlight.light_color=Color(value.x,value.y,value.z).linear_to_srgb()
	sunlight.light_energy = 1.0 if not direction.is_zero_approx() else 0.0
	sunlight.shadow_enabled = bool(fields.a8 if moon else fields.c8)
	sunlight.shadow_opacity = sample.shadow

func snapshot() -> Dictionary:
	var result: Dictionary={"revision":revision,"updates":updates,"phaseUpdates":phase_updates,"elapsed":elapsed,"sample":sample.duplicate(true),"range":range_state.duplicate(true),"fog":environment.fog_enabled,"native_surface_output":native_surface_output,"native_fog":Surface.snapshot() if native_surface_output else {},"background":[environment.background_color.r,environment.background_color.g,environment.background_color.b],"sky":sky.snapshot() if is_instance_valid(sky) else null,"weather":weather.snapshot() if weather_revision >= 0 else null}
	if not cx_weather_source.is_empty(): result.cx_precipitation={"requested":cx_weather_source.duplicate(),"phase":cx_weather_phase,"active":cx_weather_running,"roof_wetness":cx_roof_wetness,"failure":cx_weather_error}
	if is_instance_valid(cx_weather_models): result.cx_precipitation.models=cx_weather_models.snapshot()
	return result

func lighting_diagnostic() -> Dictionary:
	# Read cached renderer properties only: no GPU readback, scene mutation,
	# resource requests or light/quality overrides during a user's live session.
	if environment==null: return {"configured":false}
	var ambient:=environment.ambient_light_color;var fog:=environment.fog_light_color
	var result:={"configured":true,"revision":revision,"source":source.duplicate(true),"sample":sample.duplicate(true),"ambient":{"color":[ambient.r,ambient.g,ambient.b],"energy":environment.ambient_light_energy,"source":environment.ambient_light_source},"fog":{"enabled":environment.fog_enabled,"color":[fog.r,fog.g,fog.b],"begin":environment.fog_depth_begin,"end":environment.fog_depth_end},"sun":{"present":is_instance_valid(sunlight)}}
	result.native_lighting={"enabled":native_enhanced_lighting,"active_lamps":preload("res://systems/native_render/native_light_palette.gd").active.size(),"metadata_capacity":preload("res://systems/native_render/native_light_palette.gd").CAPACITY,"metadata_uploads":preload("res://systems/native_render/native_light_palette.gd").flushes,"metadata_overflows":preload("res://systems/native_render/native_light_palette.gd").overflows,"policy":"Enhanced native light/material candidate; Godot cluster/shadow owners retained"}
	if is_instance_valid(camera) and camera.compositor!=null:
		for effect in camera.compositor.compositor_effects:
			if effect.has_method("snapshot") and effect.get_meta("native_final_color",false): result.native_lighting.gamma=effect.snapshot()
	if is_instance_valid(sunlight):
		var color:=sunlight.light_color;var axis:=sunlight.global_basis.z
		result.sun={"present":true,"visible":sunlight.is_visible_in_tree(),"energy":sunlight.light_energy,"color":[color.r,color.g,color.b],"basis_z":[axis.x,axis.y,axis.z],"shadows":sunlight.shadow_enabled}
	return result
