extends ShaderMaterial
# Original stock vsvtc/fstc: ApplyColorSpace(vertex/texel), full RGBA
# modulation, RevertColorSpace(rgb). No synthesized mask or alpha scissor.
static var programs: Dictionary={}
var texture: Texture2D
var native_surface_output:=true
var sampler: Dictionary={}
var failure:=""
func configure(value: Texture2D,policy: Dictionary,surface_output: bool=true) -> bool:
	if value==null or not policy.get("filter") is bool or not policy.get("mipmap") is bool or not policy.get("clamp") is int:failure="Native highlight texture/sampler unavailable";return false
	var clamp_mask:=int(policy.clamp)&3
	if clamp_mask in [1,2]:failure="Native per-axis highlight clamp requires a per-axis sampler";return false
	# GL's mixed min/mag cases cannot be represented by one Godot hint:
	# filter1/mip0 = nearest min + linear mag; filter0/mip1 = nearest mipnearest.
	if policy.filter!=policy.mipmap:failure="Native mixed highlight min/mag filter is not yet mapped";return false
	var filtering: String="filter_linear_mipmap" if policy.filter else "filter_nearest"
	if policy.get("anisotropic",false) and policy.filter and policy.mipmap:filtering="filter_linear_mipmap_anisotropic"
	var repeat_hint: String="repeat_enable" if clamp_mask==0 else "repeat_disable"
	var key:=filtering+repeat_hint+str(surface_output)
	if not programs.has(key):
		var program:=Shader.new()
		program.code="shader_type spatial;\nrender_mode unshaded,blend_add,cull_disabled,depth_draw_never,fog_disabled;\nuniform sampler2D native_highlight_texture : "+filtering+","+repeat_hint+";\n"+"""
vec3 apply_native(vec3 value){return sign(value)*pow(abs(value),vec3(2.2));}
vec3 revert_native(vec3 value){return sign(value)*pow(abs(value),vec3(0.45454545));}
vec3 display_to_linear(vec3 value){
 vec3 low=value/12.92;
 vec3 high=sign(value)*pow((abs(value)+vec3(0.055))/1.055,vec3(2.4));
 return mix(high,low,lessThanEqual(abs(value),vec3(0.04045)));
}
void fragment(){
 vec4 texel=texture(native_highlight_texture,UV);
 vec3 native_display=revert_native(apply_native(COLOR.rgb)*apply_native(texel.rgb));
 ALBEDO=%s;
 ALPHA=COLOR.a*texel.a;
}
""" % ("native_display" if surface_output else "display_to_linear(native_display)")
		programs[key]=program
	shader=programs[key];render_priority=Material.RENDER_PRIORITY_MAX
	texture=value;sampler=policy.duplicate(true);native_surface_output=surface_output
	set_shader_parameter("native_highlight_texture",value);set_meta("native_surface_output",surface_output);failure="";return true
func clear_texture() -> void:
	texture=null;set_shader_parameter("native_highlight_texture",null)
func snapshot() -> Dictionary:
	return {"texture_available":texture!=null,"sampler":sampler.duplicate(true),"native_surface_output":native_surface_output,"failure":failure,"rgb":"original2.2 apply,RGBA product,.45454545 revert","alpha":"vertex alpha times sampled alpha; no discard"}
