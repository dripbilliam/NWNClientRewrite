extends ShaderMaterial
const Policy=preload("res://systems/native_render/native_light_policy.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const StandardLight=preload("res://systems/native_render/native_standard_light.gd")
const SurfaceTransfer=preload("res://systems/native_render/native_surface_transfer.gd")
const InstanceContract=preload("res://systems/native_render/native_material_contract.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
static var shaders: Dictionary={}
var _configuring_shader:=false
@export var native_surface_output:=false:
	set(value): native_surface_output=value; set_meta("native_surface_output",value); refresh_shader()
@export var native_tile_fog_enabled:=false:
	set(value): native_tile_fog_enabled=value; set_meta("native_tile_fog_enabled",value); refresh_shader()
@export var native_world_fog:=false:
	set(value): native_world_fog=value; set_shader_parameter("native_world_fog",value)
@export var standard_specular:=false:
	set(value): standard_specular=value; refresh_shader()
@export var standard_quality:=2:
	set(value): standard_quality=clampi(value,1,2); refresh_shader()
@export var albedo_color:=Color.WHITE:
	set(value): albedo_color=value; set_shader_parameter("native_diffuse",Policy.linear_rgb([value.r,value.g,value.b])); set_shader_parameter("native_alpha",value.a)
@export var emission:=Color.BLACK:
	set(value): emission=value; var raw:=value.linear_to_srgb(); set_shader_parameter("native_emission",Policy.linear_rgb([raw.r,raw.g,raw.b]))
@export var emission_enabled:=false:
	set(value): emission_enabled=value; set_shader_parameter("native_emission_enabled",value)
@export var transparency:=BaseMaterial3D.TRANSPARENCY_DISABLED:
	set(value):
		if transparency==value: return
		transparency=value; refresh_shader()
@export var albedo_texture: Texture2D:
	set(value): albedo_texture=value; set_shader_parameter("native_texture",value); set_shader_parameter("native_has_texture",value!=null)
@export var ambient_color:=Vector3.ONE:
	set(value): ambient_color=value; set_shader_parameter("native_ambient",value)
@export var filter_mode:=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
	set(value): filter_mode=value; refresh_shader()
@export var scissor:=false:
	set(value): scissor=value; refresh_shader()
func configure(source: StandardMaterial3D,ambient_value: Array,raw_emission: Array,standard: bool=false,quality: int=2,surface_policy: Variant=null) -> void:
	configure_values(source.albedo_color,source.albedo_texture,source.texture_filter,source.transparency,ambient_value,raw_emission,standard,quality,surface_policy)
func configure_values(diffuse_value: Color,texture_value: Texture2D,filter_value: int,transparency_value: int,ambient_value: Array,raw_emission: Array,standard: bool=false,quality: int=2,surface_policy: Variant=null) -> void:
	# Configure one final shader variant. Intermediate setter combinations are
	# never rendered, but compiling/binding them can drain unrelated render work.
	_configuring_shader=true
	standard_specular=standard; standard_quality=quality
	Palette.ensure(); filter_mode=filter_value; scissor=transparency_value==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	transparency=transparency_value
	# Omitted policy preserves legacy reconfiguration of an existing material.
	if surface_policy is bool:native_surface_output=surface_policy
	_configuring_shader=false; refresh_shader()
	albedo_color=diffuse_value; ambient_color=Policy.linear_rgb(ambient_value)
	albedo_texture=texture_value
	emission=Color(raw_emission[0],raw_emission[1],raw_emission[2]).srgb_to_linear(); emission_enabled=raw_emission.any(func(value):return value!=0)
static func filtering_name(value: int) -> String:
	return {BaseMaterial3D.TEXTURE_FILTER_NEAREST:"filter_nearest",BaseMaterial3D.TEXTURE_FILTER_LINEAR:"filter_linear",BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS:"filter_nearest_mipmap",BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:"filter_linear_mipmap",BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC:"filter_nearest_mipmap_anisotropic",BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC:"filter_linear_mipmap_anisotropic"}.get(value,"filter_linear_mipmap")
static func variant_key(blended: bool,cutout: bool,filter_value: int,standard: bool,quality: int,surface: bool,tile_fog: bool) -> String:
	# Pure final-policy identity shared with the bounded startup warmup. Preserve
	# the existing key bytes and every filtering/quality/surface combination.
	return str(blended)+str(cutout)+filtering_name(filter_value)+str(standard)+str(quality)+str(surface)+str(tile_fog)
func shader_variant_key() -> String:
	return variant_key(transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,scissor,filter_mode,standard_specular,standard_quality,native_surface_output,native_tile_fog_enabled)
func refresh_shader() -> void:
	if _configuring_shader:return
	if native_surface_output: preload("res://systems/native_render/native_surface_state.gd").ensure()
	var blended:=transparency==BaseMaterial3D.TRANSPARENCY_ALPHA
	var filtering:=filtering_name(filter_mode)
	var key:=shader_variant_key()
	if not shaders.has(key):
		var program_began:=Timing.begin()
		var program:=Shader.new()
		var shader_code: String="shader_type spatial;\nrender_mode diffuse_lambert,"+("" if standard_specular or native_surface_output else "specular_disabled,")+"ambient_light_disabled,cull_back"+(",depth_draw_never" if blended else "")+(",fog_disabled" if native_surface_output else "")+";\n"+Palette.shader_code()+(StandardLight.code(standard_quality) if standard_specular else "")+(SurfaceTransfer.code(native_tile_fog_enabled) if native_surface_output else "")+"""
uniform sampler2D native_texture : repeat_enable,%s;
uniform bool native_has_texture=false;
uniform vec3 native_ambient=vec3(1.0);
uniform vec3 native_diffuse=vec3(1.0);
uniform vec3 native_emission=vec3(0.0);
uniform bool native_emission_enabled=false;
uniform float native_alpha=1.0;
void vertex(){nwn_world_vertex=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; %s}
void fragment(){
 vec4 texel=native_has_texture?texture(native_texture,UV):vec4(1.0);
 ALBEDO=sign(texel.rgb)*pow(abs(texel.rgb),vec3(2.2));
 %s
 EMISSION=ALBEDO*(native_ambient*nwn_native_ambient*%s+(native_emission_enabled?native_emission:vec3(0.0)));
 %s
 %s
 %s
}
void light(){
 vec2 lighting=nwn_local_light(ATTENUATION,SPECULAR_AMOUNT,LIGHT_IS_DIRECTIONAL);
 float cosine=lighting.y>0.5?1.0:%s;
 float diffuse_cosine=cosine%s;
 vec3 response=lighting.y>0.5?native_ambient:native_diffuse;
 %sLIGHT_COLOR*(lighting.x*diffuse_cosine/PI)*response%s;
 %s
 %s
}
""" % [filtering,(StandardLight.vertex_code() if standard_specular else "")+(SurfaceTransfer.vertex_code() if native_surface_output else ""),StandardLight.fragment_code() if standard_specular else "","(1.0-nwn_environment_specularity)" if standard_specular else "1.0","EMISSION+=nwn_specular_color*nwn_environment_rgb*nwn_native_ambient*native_ambient*nwn_standard_environment_scale();" if standard_specular else "",("ALPHA=nwn_effective_alpha;" if standard_specular else "ALPHA=texel.a*native_alpha;") if blended else ("if(texel.a<0.035)discard;" if scissor else ""),SurfaceTransfer.fragment_code() if native_surface_output else "","nwn_standard_cosine(dot(NORMAL,LIGHT))" if standard_specular else "max(dot(NORMAL,LIGHT),0.0)","+(lighting.y>0.5?0.0:nwn_standard_translucence(dot(NORMAL,LIGHT)))" if standard_specular else "","vec3 nwn_surface_diffuse=" if native_surface_output else "DIFFUSE_LIGHT+=","*(1.0-nwn_environment_specularity)" if standard_specular else "",(("vec3 nwn_surface_specular=" if native_surface_output else "SPECULAR_LIGHT+=")+"LIGHT_COLOR*(lighting.x/PI)*nwn_specular_color*(diffuse_cosine*response*nwn_environment_rgb*nwn_standard_environment_scale()+(lighting.y<0.5&&cosine>0.0?cosine*nwn_standard_specular(NORMAL,LIGHT,VIEW,max(dot(NORMAL,LIGHT),0.0)):0.0));") if standard_specular else ("vec3 nwn_surface_specular=vec3(0.0);" if native_surface_output else ""),SurfaceTransfer.light_code() if native_surface_output else ""]
		program.code=shader_code
		InstanceContract.register_program(program,shader_code,native_surface_output and native_tile_fog_enabled)
		shaders[key]=program
		Timing.finish("publication_material_shader_build_ms",program_began)
	var bind_began:=Timing.begin()
	shader=shaders[key]
	Timing.finish("publication_material_shader_bind_ms",bind_began)
func publish_native_pose(color_value: Color,emission_value: Color,blended: bool) -> void:
	albedo_color=color_value; emission=emission_value; emission_enabled=emission_value.r!=0 or emission_value.g!=0 or emission_value.b!=0
	transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if blended else BaseMaterial3D.TRANSPARENCY_DISABLED
