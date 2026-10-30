extends RefCounted
# Apply per-texture original sampling only inside private GUI model viewports.
# World materials retain their separate lighting/texture contracts.
const Info=preload("res://systems/native_data/gui_texture_info.gd")
static var shaders: Dictionary={}
static func min_filter(info: Dictionary) -> int:
	return (0x2703 if info.get("filter",true) else 0x2700) if info.get("mipmap",true) else 0x2600
static func mag_filter(info: Dictionary) -> int: return 0x2601 if info.get("filter",true) else 0x2600
static func filter_mode(info: Dictionary) -> int:
	if info.get("mipmap",true): return BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if info.get("filter",true) else BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return BaseMaterial3D.TEXTURE_FILTER_LINEAR if info.get("filter",true) else BaseMaterial3D.TEXTURE_FILTER_NEAREST
static func material(source: StandardMaterial3D,info: Dictionary) -> Material:
	var axes:=int(info.get("clamp",0))&3
	var asymmetric: bool=info.get("filter",true) and not info.get("mipmap",true)
	if ((axes==0 or axes==3) and not asymmetric) or source.albedo_texture==null:
		var result: StandardMaterial3D=source.duplicate(); result.texture_filter=filter_mode(info); result.texture_repeat=axes!=3; return result
	# Godot's standard repeat flag couples S/T. Resolve each texel independently
	# for original clamp1/2, including linear edge taps and mip levels. Clamping
	# interpolated UVs to0/1 before a repeat sampler would still wrap the edge.
	var cull: String={BaseMaterial3D.CULL_BACK:"cull_back",BaseMaterial3D.CULL_FRONT:"cull_front",BaseMaterial3D.CULL_DISABLED:"cull_disabled"}[source.cull_mode]
	var hint:="mixed_axes:"+cull
	if not shaders.has(hint):
		var shader:=Shader.new(); shader.code="""shader_type spatial;
render_mode unshaded, __GUI_CULL__, depth_draw_never, shadows_disabled;
uniform sampler2D original_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 original_color : source_color = vec4(1.0);
uniform int clamp_axes = 0;
uniform bool linear_filter = true;
uniform bool use_mipmaps = true;
uniform int last_mip = 0;
vec4 tap(ivec2 point, int level) {
    ivec2 extent = textureSize(original_texture, level);
    point.x = (clamp_axes & 1) != 0 ? clamp(point.x, 0, extent.x - 1) : ((point.x %% extent.x) + extent.x) %% extent.x;
    point.y = (clamp_axes & 2) != 0 ? clamp(point.y, 0, extent.y - 1) : ((point.y %% extent.y) + extent.y) %% extent.y;
    return texelFetch(original_texture, point, level);
}
vec4 sample_level(vec2 point, int level, bool linear) {
    vec2 pixel = point * vec2(textureSize(original_texture, level));
    if (!linear) { return tap(ivec2(floor(pixel)), level); }
    pixel -= vec2(0.5);
    ivec2 lo = ivec2(floor(pixel));
    vec2 weight = fract(pixel);
    return mix(mix(tap(lo, level), tap(lo + ivec2(1, 0), level), weight.x),
               mix(tap(lo + ivec2(0, 1), level), tap(lo + ivec2(1, 1), level), weight.x), weight.y);
}
void fragment() {
    vec2 pixel = UV * vec2(textureSize(original_texture, 0));
    float rho = max(length(dFdx(pixel)), length(dFdy(pixel)));
    float level = use_mipmaps ? clamp(log2(max(rho, 0.000001)), 0.0, float(last_mip)) : 0.0;
    bool linear = linear_filter && (use_mipmaps || rho <= 1.0);
    vec4 sampled;
    if (linear_filter) {
        int lo = int(floor(level));
        sampled = mix(sample_level(UV, lo, linear), sample_level(UV, min(lo + 1, last_mip), linear), fract(level));
    } else { sampled = sample_level(UV, int(floor(level + 0.5)), linear); }
    sampled *= original_color;
    ALBEDO = sampled.rgb;
    ALPHA = sampled.a;
}
""".replace("%%","%").replace("__GUI_CULL__",cull); shaders[hint]=shader
	var result:=ShaderMaterial.new(); result.shader=shaders[hint]; result.set_shader_parameter("original_texture",source.albedo_texture); result.set_shader_parameter("original_color",source.albedo_color); result.set_shader_parameter("clamp_axes",axes); result.set_shader_parameter("linear_filter",bool(info.get("filter",true))); result.set_shader_parameter("use_mipmaps",bool(info.get("mipmap",true))); result.set_shader_parameter("last_mip",maxi(0,int(info.get("mip_levels",1))-1)); return result
