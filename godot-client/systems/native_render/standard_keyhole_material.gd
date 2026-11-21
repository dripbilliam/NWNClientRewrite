extends ShaderMaterial
# StandardMaterial3D tile values produced by ResourcePool, with the installed
# inc_keyhole stage appended. Burley/GGX, fog and shadows use Godot's shader
# paths; exact StandardMaterial3D shader-stage equivalence needs a visual check.
const Keyhole=preload("res://systems/native_render/native_camera_keyhole.gd")
const TargetPreview=preload("res://systems/native_render/native_target_preview_shader.gd")
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
static var shaders: Dictionary={}
@export_storage var standard_source: StandardMaterial3D
@export_storage var keyhole_enabled:=false

func configure(source: StandardMaterial3D,with_keyhole: bool=true) -> bool:
	if source==null or source.cull_mode!=BaseMaterial3D.CULL_BACK:return false
	if source.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]:return false
	if source.shading_mode not in [BaseMaterial3D.SHADING_MODE_PER_PIXEL,BaseMaterial3D.SHADING_MODE_UNSHADED]:return false
	for feature in ["normal_enabled","rim_enabled","clearcoat_enabled","anisotropy_enabled","subsurf_scatter_enabled"]:
		if bool(source.get(feature)):return false
	standard_source=source
	keyhole_enabled=with_keyhole
	_bind_standard_shader(source.transparency)
	_publish_standard_values(source.albedo_color,source.emission,source.emission_enabled)
	render_priority=source.render_priority
	return true

func _bind_standard_shader(transparency_mode: int) -> void:
	var source:=standard_source
	var with_keyhole:=keyhole_enabled
	if with_keyhole:Keyhole.ensure()
	TargetPreview.ensure()
	var blended:=transparency_mode==BaseMaterial3D.TRANSPARENCY_ALPHA
	var cutout:=transparency_mode==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var unshaded:=source.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED
	var key:=str(with_keyhole)+str(blended)+str(cutout)+str(unshaded)+NativeMaterial.filtering_name(source.texture_filter)+"|target:"+TargetPreview.source_identity()+("|keyhole-source:"+Keyhole.source_identity() if with_keyhole else "")
	if not shaders.has(key):
		var program:=Shader.new()
		program.code="shader_type spatial;\nrender_mode cull_back,"+("unshaded," if unshaded else "diffuse_burley,specular_schlick_ggx,")+("depth_draw_never," if blended else "")+"blend_mix;\n"+(Keyhole.code() if with_keyhole else "")+TargetPreview.code()+"""
uniform sampler2D original_texture : source_color,repeat_enable,%s;
uniform bool original_has_texture=false;
uniform vec4 original_color : source_color = vec4(1.0);
uniform vec3 original_emission=vec3(0.0);
uniform float original_emission_energy=1.0;
uniform float original_roughness=1.0;
uniform float original_metallic=0.0;
uniform float original_scissor=0.035;
varying vec3 nwn_keyhole_world_vertex;
void vertex(){
 nwn_keyhole_world_vertex=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 %s
}
void fragment(){
 vec4 texel=(original_has_texture?texture(original_texture,UV):vec4(1.0))*original_color;
 %s
 ALBEDO=texel.rgb;
 EMISSION=original_emission*original_emission_energy;
 ROUGHNESS=original_roughness;
 METALLIC=original_metallic;
 SPECULAR=0.5;
 %s
	vec3 target_weight=nwn_target_overlay(nwn_keyhole_world_vertex);
	// Godot's built-in lighting consumes ALBEDO after fragment(); the old
	// hook blends its completed pixel. Scale lit input, then add the target
	// color through the unlit channel instead of lighting white a second time.
	ALBEDO*=vec3(1.0)-target_weight;
	EMISSION=EMISSION*(vec3(1.0)-target_weight)+target_weight;
	SPECULAR*=1.0-max(target_weight.r,max(target_weight.g,target_weight.b));
 %s
}
""" % [NativeMaterial.filtering_name(source.texture_filter),"nwn_keyhole_view_z=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).z;nwn_keyhole_offset=nwn_keyhole_setup();" if with_keyhole else "","if(texel.a<original_scissor)discard;" if cutout else "","ALPHA=texel.a;" if blended else "","nwn_keyhole_apply(ALBEDO,EMISSION,FRAGCOORD.xy,nwn_keyhole_world_vertex);" if with_keyhole else ""]
		shaders[key]=program
	shader=shaders[key]
	set_shader_parameter("original_texture",source.albedo_texture)
	set_shader_parameter("original_has_texture",source.albedo_texture!=null)
	set_shader_parameter("original_roughness",source.roughness)
	set_shader_parameter("original_metallic",source.metallic)
	set_shader_parameter("original_scissor",source.alpha_scissor_threshold)

func _publish_standard_values(color: Color,emission_value: Color,emission_active: bool) -> void:
	set_shader_parameter("original_color",color)
	var emission_color:=emission_value.srgb_to_linear() if emission_active else Color.BLACK
	set_shader_parameter("original_emission",Vector3(emission_color.r,emission_color.g,emission_color.b))
	set_shader_parameter("original_emission_energy",standard_source.emission_energy_multiplier if emission_active else 0.0)
