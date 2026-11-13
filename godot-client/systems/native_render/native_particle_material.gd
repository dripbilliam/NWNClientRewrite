extends RefCounted
# Fallback surfaces receive already CPU-tinted original byte colors. Keep their
# texels/raw tint and fog in the same carrier as the shared native raster.
const State=preload("res://systems/native_render/native_surface_state.gd")
static var shaders: Dictionary={}
static func make(texture: Texture2D,additive: bool,two_sided: bool,vertex: String="") -> ShaderMaterial:
	State.ensure()
	var key:=str(additive)+str(two_sided)+vertex
	if not shaders.has(key):
		var shader:=Shader.new()
		shader.code="shader_type spatial;\nrender_mode unshaded,fog_disabled,depth_draw_never,shadows_disabled,"+("blend_add" if additive else "blend_mix")+","+("cull_disabled" if two_sided else "cull_front")+(",skip_vertex_transform" if not vertex.is_empty() else "")+";\n"+"""
global uniform vec3 nwn_native_fog_color;
global uniform vec3 nwn_native_fog_params;
uniform sampler2D original_texture : filter_linear_mipmap;
uniform float native_alpha_discard=-1.0;
varying float nwn_particle_fog;
void vertex(){
 %s
 nwn_particle_fog=nwn_native_fog_params.x==0.0?0.0:(-%s.z-nwn_native_fog_params.y)*nwn_native_fog_params.z;
}
void fragment(){
 vec4 value=texture(original_texture,UV)*COLOR;
 if(native_alpha_discard>=0.0&&value.a<=native_alpha_discard)discard;
 float amount=clamp(nwn_particle_fog,0.0,1.0);
 %s
 ALBEDO=value.rgb; ALPHA=value.a;
}
""" % [vertex,"VERTEX" if not vertex.is_empty() else "(MODELVIEW_MATRIX*vec4(VERTEX,1.0))","value.a*=1.0-amount;" if additive else "value.rgb=mix(value.rgb,nwn_native_fog_color,amount);"]
		shaders[key]=shader
	var material:=ShaderMaterial.new(); material.shader=shaders[key]; material.set_meta("native_surface_output",true); material.set_shader_parameter("original_texture",texture); return material
