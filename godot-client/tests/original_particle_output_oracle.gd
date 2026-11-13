extends "res://tests/original_surface_output_oracle.gd"
# Unchanged retail fsparticle main, inc_fog, native Gamma/tonemap functions on
# a local GPU device. Texture texel and depth lookup are explicit boundaries.
# NO_DISCARD is selected for this compute oracle; real alpha-discard coverage
# must use a fragment fixture. No original resource payload is retained.
func input_stride() -> int: return 20
func compile(catalog,quality: int) -> Dictionary:
	if pipelines.has(quality): return pipelines[quality]
	if rd==null: rd=RenderingServer.create_local_rendering_device()
	if rd==null: failure="Original particle oracle requires a local GPU device"; return {}
	var code:="#version 450\n#define SHADER_TYPE 2\n#define SHADER_QUALITY_MODE 2\n#define POSTPROCESSING 0\n#define NO_DISCARD 1\n#define BLEND_MODE_NORMAL 0\n#define BLEND_MODE_ADDITIVE 1\n#define BLEND_MODE_PUNCHTHROUGH 2\nfloat sqr(float v){return v*v;}\n"
	code+=load_source(catalog,"inc_config")
	code+=load_source(catalog,"inc_fog").replace("varying ","")
	code+=load_source(catalog,"inc_postpr_gam")
	code+=load_source(catalog,"inc_tonemap")
	code+="""
vec4 fixture_texel; vec4 FragmentColor; vec4 VertexColor;
vec3 vVertexTexCoords=vec3(0.0); vec2 vPixelSize=vec2(1.0);
vec4 fixture_frag_coord=vec4(0.5,0.5,0.5,1.0);
#define gl_FragCoord fixture_frag_coord
vec4 fixture_fragment_output;
#define gl_FragColor fixture_fragment_output
int texUnit0=0; int blendMode; float particleSoftness; float fixture_depth; float fixture_view_z;
vec4 fixture_texture_lookup(int sampler_boundary,vec2 uv){return fixture_texel;}
#define texture2D fixture_texture_lookup
float GetDepth(vec2 uv){return fixture_depth;}
float GetFragmentViewZ(){return fixture_view_z;}
"""
	code+=function_source(load_source(catalog,"inc_common"),"AlphaDiscard")
	code+=function_source(load_source(catalog,"fsparticle"),"main").replace("void main", "void original_particle_main")
	if not failure.is_empty(): return {}
	code+="""
layout(local_size_x=1,local_size_y=1,local_size_z=1)in;
layout(set=0,binding=0,std430)readonly buffer Inputs{vec4 data[];};
layout(set=0,binding=1,std430)writeonly buffer Outputs{vec4 result[];};
void main(){
 uint i=gl_GlobalInvocationID.x; uint at=i*5;
 fixture_texel=data[at]; VertexColor=data[at+1]; fogColor=vec4(data[at+2].rgb,1.0); fFogFragCoord=data[at+2].a;
 Gamma=data[at+3].a; blendMode=int(data[at+4].x); particleSoftness=data[at+4].y; fixture_depth=data[at+4].z; fixture_view_z=data[at+4].w;
 original_particle_main();
 vec4 color=FragmentColor;
 color.rgb=color.rgb*color.a+data[at+3].rgb*(blendMode==BLEND_MODE_ADDITIVE?1.0:1.0-color.a);
 FS_PostProcess_Gamma(color); ApplyColorTonemap(color.rgb); result[i]=color;
}
"""
	var source:=RDShaderSource.new(); source.source_compute=code
	var spirv:=rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty(): failure=spirv.compile_error_compute; return {}
	var shader:=rd.shader_create_from_spirv(spirv); var pipeline:=rd.compute_pipeline_create(shader)
	pipelines[quality]={"shader":shader,"pipeline":pipeline}; return pipelines[quality]
