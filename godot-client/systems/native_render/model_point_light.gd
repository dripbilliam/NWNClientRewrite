extends OmniLight3D
const Policy=preload("res://systems/native_render/native_light_policy.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
var native_slot:=-1
var native_state: Dictionary={}
var native_properties: Dictionary={}
var native_properties_revision:=0
var animation_cached:=false
var animation_color: Color
var animation_values: Vector4
var animation_publications:=0
var focus_owner: WeakRef
var native_admitted:=true
var native_fade:=1.0
var native_shadow_override: Variant=null
var camera_cover_range:=0.0
static func authored_number(properties: Dictionary,key: String,fallback: float) -> float:
	# model_light.js::number accepts finite authored values only.
	if not properties.has(key):return fallback
	var raw: Variant=properties[key]
	if raw is String and not raw.is_valid_float():return fallback
	var value:=float(raw)
	return value if is_finite(value) else fallback
# The ordinary path uses the old model-light quadratic/ambient-only shader
# response. Explicit enhanced and Godot modes retain their existing policies.
# The separately selected history owner publishes admission/fade here; lens
# flares and native static vertex baking remain separate owners.
func configure(properties: Dictionary) -> void:
	animation_cached=false
	var color_value: Variant=properties.get("color",[1.0,1.0,1.0])
	if not color_value is Array or color_value.size()<3: color_value=[1.0,1.0,1.0]
	light_color=Color(color_value[0],color_value[1],color_value[2])
	var radius:=maxf(0,authored_number(properties,"radius",0)); var multiplier:=maxf(0,authored_number(properties,"multiplier",1))
	omni_range=maxf(0.01,radius); light_energy=multiplier; visible=radius>0 and multiplier>0
	omni_attenuation=1.0
	if get_meta("native_enhanced_light",false):
		var legacy: bool=get_meta("native_legacy_light",false)
		if not legacy:camera_cover_range=0.0
		native_state={"color":Vector3.ZERO,"range":radius,"inverse":1.0,"factor":4.5,"ambient":float(properties.get("ambientonly",0))>0,"enabled":radius>0,"legacy":true} if legacy else Policy.point(properties,2.0,0.2,1.5,native_fade)
		var rgb: Vector3=native_state.color
		light_color=Color(color_value[0],color_value[1],color_value[2]) if legacy else Color(rgb.x,rgb.y,rgb.z).linear_to_srgb()
		light_energy=multiplier*PI if legacy else 1.0
		omni_range=maxf(0.01,maxf(native_state.range,camera_cover_range if legacy else 0.0)); omni_attenuation=0.0; visible=native_state.enabled
		if legacy:native_state.render_range=omni_range
		if native_slot>=0:
			light_specular=float(native_slot+32)*0.5
			Palette.update(native_slot,global_position,native_state)
	else:
		native_state.clear(); camera_cover_range=0.0; light_specular=0.5
	# No ordinary Godot decay fallback when the native metadata slot is full.
	visible=visible and native_admitted and (native_slot>=0 or not is_inside_tree() or not get_meta("native_enhanced_light",false))
	shadow_enabled=false
	# Slot fades change rendered RGB, not the authored history inputs. Keep the
	# immutable property snapshot/revision until a real source publication changes.
	if native_properties!=properties:
		native_properties=properties.duplicate(true); native_properties_revision+=1
		set_meta("native_model_light_properties",native_properties)
	var shadow_request: bool=float(properties.get("shadow",0))>0
	if native_shadow_override is bool and (float(properties.get("affectdynamic",0))!=0 or float(properties.get("isdynamic",0))!=0):shadow_request=bool(native_shadow_override)
	set_meta("native_shadow_requested",shadow_request and float(properties.get("ambientonly",0))==0)

func cover_camera_extent(distance: float) -> void:
	# Three's patched legacy shader has no authored-radius cutoff. Godot still
	# culls an OmniLight at omni_range, so include every fragment in the camera
	# frustum while the source radius remains the quadratic denominator.
	if native_slot<0 or not bool(native_state.get("legacy",false)) or not is_finite(distance):return
	var desired:=maxf(float(native_state.range),maxf(distance*1.01+0.1,0.01))
	if is_equal_approx(desired,camera_cover_range):return
	camera_cover_range=desired
	omni_range=desired
	native_state.render_range=desired
	Palette.update(native_slot,global_position,native_state)
func set_native_shadowing(enabled: bool) -> void:
	var properties: Dictionary=get_meta("native_model_light_properties",{})
	if float(properties.get("affectdynamic",0))==0 and float(properties.get("isdynamic",0))==0:return
	native_shadow_override=enabled
	var requested:=enabled and float(properties.get("ambientonly",0))==0
	set_meta("native_shadow_requested",requested)
	if not requested:shadow_enabled=false
func apply_native_admission(admitted: bool,fade: float) -> void:
	if native_admitted==admitted and native_fade==fade: return
	native_admitted=admitted; native_fade=fade; set_meta("native_light_fade",fade)
	var had_shadow:=shadow_enabled
	configure(get_meta("native_model_light_properties",{}))
	shadow_enabled=had_shadow and get_meta("native_shadow_requested",false)
func publish_native_light(color_value: Color,radius: float,shadow_radius: float,vertical: float,multiplier: float) -> void:
	var values:=Vector4(radius,shadow_radius,vertical,multiplier)
	if animation_cached and color_value==animation_color and values==animation_values: return
	var properties: Dictionary=get_meta("native_model_light_properties",{}).duplicate(true)
	properties.merge({"color":[color_value.r,color_value.g,color_value.b],"radius":radius,"shadowradius":shadow_radius,"verticaldisplacement":vertical,"multiplier":multiplier},true)
	# Animation changes lamp values, not the separate shadow-selection owner.
	var had_shadow:=shadow_enabled
	configure(properties)
	shadow_enabled=had_shadow and get_meta("native_shadow_requested",false)
	animation_color=color_value; animation_values=values; animation_cached=true; animation_publications+=1
func _enter_tree() -> void:
	add_to_group("native_original_model_lights")
	var ancestor:=get_parent()
	while ancestor!=null:
		var reference: WeakRef=ancestor.get_meta("native_focus_light_owner") if ancestor.has_meta("native_focus_light_owner") else null
		if reference!=null:
			var owner=reference.get_ref()
			if is_instance_valid(owner): focus_owner=reference; owner.register(self)
			break
		ancestor=ancestor.get_parent()
	if get_meta("native_enhanced_light",false):
		native_slot=Palette.acquire(self); set_notify_transform(true)
		configure(get_meta("native_model_light_properties",{}))
func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSFORM_CHANGED and native_slot>=0 and not native_state.is_empty() and is_inside_tree(): Palette.update(native_slot,global_position,native_state)
func _exit_tree() -> void:
	var owner=focus_owner.get_ref() if focus_owner!=null else null
	if is_instance_valid(owner): owner.unregister(self)
	focus_owner=null
	if native_slot>=0: Palette.release(native_slot); native_slot=-1
