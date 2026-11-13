extends RefCounted
# Snapshot once on the main thread. The render callback never reads a scene
# Environment. Layout is two std140 vec4s, retained by the immutable packet.
static func environment_for(camera: Camera3D) -> Environment:
	if camera==null: return null
	if camera.environment!=null: return camera.environment
	var world:=camera.get_world_3d()
	return world.environment if world!=null else null
static func unsupported(camera: Camera3D) -> String:
	var environment:=environment_for(camera)
	if environment==null: return ""
	if environment.volumetric_fog_enabled: return "volumetric fog"
	if not environment.fog_enabled: return ""
	if absf(environment.fog_height_density)>=0.0001: return "height fog"
	if environment.fog_aerial_perspective>0.0: return "sky fog scattering"
	if environment.fog_sun_scatter>0.001: return "sun fog scattering"
	return ""
static func sample(camera: Camera3D,native_surface_output: bool=false,owner: Node=null) -> Array:
	if native_surface_output and owner!=null:
		var packet: Array=preload("res://systems/native_render/native_surface_state.gd").packet(owner)
		if not packet.is_empty(): return packet
	var environment:=environment_for(camera)
	if environment==null or not environment.fog_enabled: return [0,0,0,0,0,1,1,0]
	if native_surface_output:
		var raw:=environment.fog_light_color
		var native_end:=environment.fog_depth_end if environment.fog_depth_end>0.0 else camera.far
		var native_begin:=environment.fog_depth_begin
		return [raw.r,raw.g,raw.b,0,native_begin,native_end,1.0/(native_end-native_begin),3.0]
	var color:=environment.fog_light_color.srgb_to_linear()*environment.fog_light_energy
	var end:=environment.fog_depth_end if environment.fog_depth_end>0.0 else camera.far
	var begin:=minf(environment.fog_depth_begin,end-0.001)
	return [color.r,color.g,color.b,environment.fog_density,begin,end,environment.fog_depth_curve,1.0 if environment.fog_mode==Environment.FOG_MODE_DEPTH else 2.0]
