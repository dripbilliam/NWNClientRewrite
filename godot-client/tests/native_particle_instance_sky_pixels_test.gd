extends "res://tests/native_particle_instance_pixels_test.gd"
# A rotated camera and directional sky irradiance expose accidental normal-
# space differences that a constant-color ambient environment cannot detect.
func viewport_surface(instanced: bool,texture: Texture2D,additive: bool,lit: bool) -> Dictionary:
	var result:=super.viewport_surface(instanced,texture,additive,lit)
	var camera: Camera3D=result.viewport.get_children().filter(func(node):return node is Camera3D)[0]
	camera.position=Vector3(2,1,5); camera.look_at(Vector3.ZERO)
	var environment: Environment=result.viewport.get_children().filter(func(node):return node is WorldEnvironment)[0].environment
	var sky:=Sky.new(); var material:=ProceduralSkyMaterial.new()
	material.sky_top_color=Color(0.1,0.2,0.8); material.sky_horizon_color=Color(1,0.4,0.1); material.ground_bottom_color=Color(0.05,0.15,0.02); material.ground_horizon_color=Color(1,0.8,0.2)
	sky.sky_material=material; environment.sky=sky; environment.background_mode=Environment.BG_SKY
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY; environment.ambient_light_sky_contribution=1.0; environment.ambient_light_energy=0.8
	environment.fog_enabled=true; environment.fog_density=0.04; environment.fog_light_color=Color(0.2,0.3,0.7)
	return result
func compare_pixels(a: Image,b: Image) -> Dictionary:
	var result:=super.compare_pixels(a,b); result.sky_irradiance=true; return result
