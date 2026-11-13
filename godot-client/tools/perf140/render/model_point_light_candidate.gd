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
# Private candidate: compute final engine inputs once. configure() retains its
# existing direct-call shadow reset; animated/admission callers preserve the
# independent shadow selection without temporarily invalidating the atlas.
func configure(properties: Dictionary,preserve_selected_shadow: bool=false) -> void:
	animation_cached=false
	var selected_shadow:=shadow_enabled if preserve_selected_shadow else false
	var color_value: Variant=properties.get("color",[1.0,1.0,1.0])
	if not color_value is Array or color_value.size()<3: color_value=[1.0,1.0,1.0]
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
	# The pinned Godot renderer increments the shadow version on every shadow
	# setter call, including unchanged values. Range changes also invalidate it.
	if light_color!=final_color: light_color=final_color
	if light_energy!=final_energy: light_energy=final_energy
	if omni_range!=final_range: omni_range=final_range
	if omni_attenuation!=final_attenuation: omni_attenuation=final_attenuation
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
	configure(get_meta("native_model_light_properties",{}),true)
func publish_native_light(color_value: Color,radius: float,shadow_radius: float,vertical: float,multiplier: float) -> void:
	var values:=Vector4(radius,shadow_radius,vertical,multiplier)
	if animation_cached and color_value==animation_color and values==animation_values: return
	var properties: Dictionary=get_meta("native_model_light_properties",{}).duplicate(true)
	properties.merge({"color":[color_value.r,color_value.g,color_value.b],"radius":radius,"shadowradius":shadow_radius,"verticaldisplacement":vertical,"multiplier":multiplier},true)
	configure(properties,true)
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
