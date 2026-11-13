extends RefCounted
# Research-only material mode. Retain native gamma-space surface values through
# fog and alpha blending. Godot still supplies clustered lights and shadows.
# Its in/out light accumulators hold linear energy and the compensating output.
# Do not select for a world until every drawing family shares this carrier.
static func code(enabled: bool=false) -> String:
	return ("instance uniform float nwn_tile_fog_factor=1.0;" if enabled else "const float nwn_tile_fog_factor=1.0;")+"\n"+"""
uniform vec3 native_surface_fog_color=vec3(0.0);
uniform vec3 native_surface_fog_params=vec3(0.0,0.0,1.0);
uniform vec2 native_surface_fog_range=vec2(0.0,0.0);
uniform bool native_world_fog=false;
global uniform vec3 nwn_native_fog_color;
global uniform vec3 nwn_native_fog_params;
global uniform vec2 nwn_native_fog_range;
varying vec3 nwn_surface_texture;
varying vec3 nwn_surface_base;
varying vec3 nwn_surface_display_base;
varying float nwn_surface_fog;
varying vec3 nwn_surface_fog_color;
vec3 nwn_surface_transfer(vec3 value){
 vec3 display=sign(value)*pow(abs(value),vec3(0.45454545));
 return mix(display,nwn_surface_fog_color,clamp(nwn_surface_fog,0.0,1.0));
}
"""
static func vertex_code() -> String:
	return """
 vec3 nwn_fog=native_world_fog?nwn_native_fog_params:native_surface_fog_params;
 nwn_surface_fog_color=native_world_fog?nwn_native_fog_color:native_surface_fog_color;
 float nwn_tile_factor=INSTANCE_CUSTOM.y>0.5?INSTANCE_CUSTOM.x:nwn_tile_fog_factor;
 if(nwn_tile_factor<1.0){
  vec2 nwn_range=native_world_fog?nwn_native_fog_range:native_surface_fog_range;
  float nwn_begin=nwn_range.x*nwn_tile_factor;
  float nwn_end=nwn_range.y*nwn_tile_factor+0.1;
  nwn_surface_fog_color*=nwn_tile_factor*nwn_tile_factor;
  nwn_fog=vec3(1.0,nwn_begin,1.0/(nwn_end-nwn_begin));
 }
 nwn_surface_fog=nwn_fog.x==0.0?0.0:(-(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).z-nwn_fog.y)*nwn_fog.z;
"""
static func fragment_code() -> String:
	return """
 nwn_surface_texture=ALBEDO;
 nwn_surface_base=EMISSION;
 nwn_surface_display_base=nwn_surface_transfer(nwn_surface_base);
 EMISSION=nwn_surface_display_base; ALBEDO=vec3(1.0); SPECULAR=0.0;
"""
static func light_code() -> String:
	return """
 SPECULAR_LIGHT+=nwn_surface_diffuse*nwn_surface_texture+nwn_surface_specular;
 DIFFUSE_LIGHT=nwn_surface_transfer(nwn_surface_base+SPECULAR_LIGHT)-SPECULAR_LIGHT-nwn_surface_display_base;
"""
