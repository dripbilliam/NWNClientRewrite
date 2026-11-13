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
# The normal path retains Godot lighting. Opt-in native materials use verified
# enhanced radius/color/falloff and ambient-only response, with Godot shadows.
# The separately selected history owner publishes admission/fade here; lens
# flares and native static vertex baking remain separate owners.
# Public configure remains one-argument. Opaque synchronous observers, editor
# gizmos, inherited scripts and malformed inputs retain the original body.
func configure(properties: Dictionary) -> void:
	if get_script().get_base_script()==null and _can_publish_final(properties):
		_configure_final(properties,false)
	else:
		_configure_original(properties)
func _finite_component(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value))<=1000000.0
func _can_publish_final(properties: Dictionary) -> bool:
	if Engine.is_editor_hint() or get_child_count(true)!=0 or not visibility_changed.get_connections().is_empty(): return false
	if not _finite_component(native_fade) or native_slot < -1 or native_slot>=Palette.CAPACITY: return false
	var source: Variant=properties.get("color",[1.0,1.0,1.0])
	if not source is Array or source.size()<3: return false
	for component in 3:
		if not _finite_component(source[component]): return false
	for key in ["radius","multiplier","shadow","ambientonly"]:
		if properties.has(key) and not _finite_component(properties[key]): return false
	return true
func _configure_original(properties: Dictionary) -> void:
	animation_cached=false
	var color_value: Variant=properties.get("color",[1.0,1.0,1.0])
	if not color_value is Array or color_value.size()<3: color_value=[1.0,1.0,1.0]
	light_color=Color(color_value[0],color_value[1],color_value[2])
	var radius:=maxf(0,float(properties.get("radius",0))); var multiplier:=maxf(0,float(properties.get("multiplier",1)))
	omni_range=maxf(0.01,radius); light_energy=multiplier; visible=radius>0 and multiplier>0
	omni_attenuation=1.0
	if get_meta("native_enhanced_light",false) and (not is_inside_tree() or native_slot>=0):
		native_state=Policy.point(properties,2.0,0.2,1.5,native_fade)
		var rgb: Vector3=native_state.color
		light_color=Color(rgb.x,rgb.y,rgb.z).linear_to_srgb(); light_energy=1.0
		omni_range=maxf(0.01,native_state.range); omni_attenuation=0.0; visible=native_state.enabled
		if native_slot>=0:
			light_specular=float(native_slot+32)*0.5
			Palette.update(native_slot,global_position,native_state)
	else:
		native_state.clear(); light_specular=0.5
	visible=visible and native_admitted
	shadow_enabled=false
	# Slot fades change rendered RGB, not the authored history inputs. Keep the
	# immutable property snapshot/revision until a real source publication changes.
	if native_properties!=properties:
		native_properties=properties.duplicate(true); native_properties_revision+=1
		set_meta("native_model_light_properties",native_properties)
	set_meta("native_shadow_requested",float(properties.get("shadow",0))>0 and float(properties.get("ambientonly",0))==0)
# Compute final support once: authored->enhanced->authored range bounces
# trigger renderer dependency/BVH work; equal shadow setters advance versions.
func _configure_final(properties: Dictionary,preserve_selected_shadow: bool) -> void:
	animation_cached=false
	var selected_shadow:=shadow_enabled if preserve_selected_shadow else false
	var color_value: Array=properties.get("color",[1.0,1.0,1.0])
	var final_color:=Color(color_value[0],color_value[1],color_value[2])
	var radius:=maxf(0,float(properties.get("radius",0))); var multiplier:=maxf(0,float(properties.get("multiplier",1)))
	var final_range:=maxf(0.01,radius)
	var final_energy:=multiplier
	var final_visible:=radius>0 and multiplier>0
	var final_attenuation:=1.0
	var final_specular:=light_specular
	if get_meta("native_enhanced_light",false) and (not is_inside_tree() or native_slot>=0):
		native_state=Policy.point(properties,2.0,0.2,1.5,native_fade)
		var rgb: Vector3=native_state.color
		final_color=Color(rgb.x,rgb.y,rgb.z).linear_to_srgb(); final_energy=1.0
		final_range=maxf(0.01,native_state.range); final_attenuation=0.0; final_visible=native_state.enabled
		if native_slot>=0:
			final_specular=float(native_slot+32)*0.5
			Palette.update(native_slot,global_position,native_state)
	else:
		native_state.clear(); final_specular=0.5
	final_visible=final_visible and native_admitted
	# Keep final color/energy/attenuation writes, including signed zero bits.
	# Positive range is normalized to the engine's float32 property boundary.
	light_color=final_color; light_energy=final_energy
	final_range=Vector3(final_range,0,0).x
	if omni_range!=final_range: omni_range=final_range
	omni_attenuation=final_attenuation
	if light_specular!=final_specular: light_specular=final_specular
	if visible!=final_visible: visible=final_visible
	var shadow_requested:=float(properties.get("shadow",0))>0 and float(properties.get("ambientonly",0))==0
	var final_shadow:=selected_shadow and shadow_requested
	if shadow_enabled!=final_shadow: shadow_enabled=final_shadow
	if native_properties!=properties:
		native_properties=properties.duplicate(true); native_properties_revision+=1
		set_meta("native_model_light_properties",native_properties)
	set_meta("native_shadow_requested",shadow_requested)
func apply_native_admission(admitted: bool,fade: float) -> void:
	if native_admitted==admitted and native_fade==fade: return
	native_admitted=admitted; native_fade=fade; set_meta("native_light_fade",fade)
	var properties: Dictionary=get_meta("native_model_light_properties",{})
	if get_script().get_base_script()==null and _can_publish_final(properties):
		_configure_final(properties,true)
	else:
		var had_shadow:=shadow_enabled
		configure(properties)
		shadow_enabled=had_shadow and get_meta("native_shadow_requested",false)
func publish_native_light(color_value: Color,radius: float,shadow_radius: float,vertical: float,multiplier: float) -> void:
	var values:=Vector4(radius,shadow_radius,vertical,multiplier)
	if animation_cached and color_value==animation_color and values==animation_values: return
	var properties: Dictionary=get_meta("native_model_light_properties",{}).duplicate(true)
	properties.merge({"color":[color_value.r,color_value.g,color_value.b],"radius":radius,"shadowradius":shadow_radius,"verticaldisplacement":vertical,"multiplier":multiplier},true)
	# Animation changes lamp values, not the separate shadow-selection owner.
	if get_script().get_base_script()==null and _can_publish_final(properties):
		_configure_final(properties,true)
	else:
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
