extends OmniLight3D
# Original model light values; Godot attenuation and shadow rendering differ
# from the legacy shader. Ambient-only/flare/fade behavior remains incomplete.
func configure(properties: Dictionary) -> void:
	var color_value: Variant=properties.get("color",[1.0,1.0,1.0])
	if not color_value is Array or color_value.size()<3: color_value=[1.0,1.0,1.0]
	light_color=Color(color_value[0],color_value[1],color_value[2])
	var radius:=maxf(0,float(properties.get("radius",0))); var multiplier:=maxf(0,float(properties.get("multiplier",1)))
	omni_range=maxf(0.01,radius); light_energy=multiplier; visible=radius>0 and multiplier>0
	shadow_enabled=false
	set_meta("native_model_light_properties",properties.duplicate(true))
	set_meta("native_shadow_requested",float(properties.get("shadow",0))>0 and float(properties.get("ambientonly",0))==0)
func _enter_tree() -> void: add_to_group("native_original_model_lights")
