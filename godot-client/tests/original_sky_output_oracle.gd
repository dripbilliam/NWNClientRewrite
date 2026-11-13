extends "res://tests/original_surface_output_oracle.gd"
# Original vsvtc/fstc + selected retail inc_standard functions, compiled on a
# local device. Explicit boundaries: texture texel, rasterizer barycentrics,
# CPU-converted global color, blend destination and final Gamma. No asset copy.
func input_stride() -> int: return 32
func compile(catalog,quality: int) -> Dictionary:
	if pipelines.has(quality): return pipelines[quality]
	if rd==null: rd=RenderingServer.create_local_rendering_device()
	if rd==null: failure="Original sky oracle requires a local device"; return {}
	var common:=load_source(catalog,"inc_common"); var standard:=load_source(catalog,"inc_standard")
	var vertex:=standard.split("#elif SHADER_TYPE == 2")[0]; var fragment:=standard.split("#elif SHADER_TYPE == 2")[1]
	var code:="#version 450\n#define SHADER_TYPE 2\n#define GAMMA_CORRECTION 1\n#define LIGHTING 0\n#define VERTEX_COLOR 1\n#define FOG 0\n#define KEYHOLING 0\n#define POSITION_WORLD 0\n#define POSITION_VIEW 0\n#define FRAGMENT_NORMAL 0\n#define NORMAL_MAP 0\n#define HEIGHT_MAP 0\n#define SPECULAR_LIGHT 0\n#define ENVIRONMENT_MAP 0\n#define SHADER_DEBUG_MODE 0\n#define NO_DISCARD 1\n#define texture2D(s,uv) fixture_texel\nvec4 fixture_texel;vec4 fixture_fragment;vec4 vColor;vec4 VertexColor;vec4 FragmentColor;vec4 globalColor;vec2 vTexCoords;vec2 vVertexTexCoords;int texture0Bound=1;\n#define gl_FragColor fixture_fragment\nvoid TransformMainCoordinates(){}\nfloat sqr(float v){return v*v;}\n"
	for line in common.split("\n"):
		if line.strip_edges().begins_with("#define COLOR_WHITE"): code+=line+"\n"
	for name in ["ApplyColorSpace","RevertColorSpace","AlphaDiscard"]: code+=function_source(common,name)
	code+=function_source(vertex,"ApplyStandardShader").replace("ApplyStandardShader(","OriginalVertexProgram(")
	code+=function_source(load_source(catalog,"vsvtc"),"main").replace("void main", "void OriginalVertexEntry").replace("ApplyStandardShader(","OriginalVertexProgram(")
	for name in ["ApplyDebugModeOutput","SetupStandardShaderInputs","ApplyStandardShader"]: code+=function_source(fragment,name)
	code+=function_source(load_source(catalog,"fstc"),"main").replace("void main", "void OriginalFragmentEntry")
	code+=load_source(catalog,"inc_postpr_gam")+load_source(catalog,"inc_tonemap")
	if not failure.is_empty(): return {}
	code+="""
layout(local_size_x=1,local_size_y=1,local_size_z=1)in;
layout(set=0,binding=0,std430)readonly buffer Inputs{vec4 data[];};
layout(set=0,binding=1,std430)writeonly buffer Outputs{vec4 result[];};
void main(){
 uint i=gl_GlobalInvocationID.x;uint at=i*8;
 vec4 vertices[3];
 for(int n=0;n<3;n++){vColor=data[at+n];OriginalVertexEntry();vertices[n]=VertexColor;}
 VertexColor=data[at+7].w>0.0?vertices[0]*data[at+3].x+vertices[1]*data[at+3].y+vertices[2]*data[at+3].z:vec4(1.0);
 globalColor=ApplyColorSpace(data[at+4]);fixture_texel=data[at+5];texture0Bound=int(data[at+7].z);
 OriginalFragmentEntry();vec4 color=fixture_fragment;color.a*=data[at+7].y;
 color.rgb=mix(data[at+6].rgb,color.rgb,color.a);Gamma=data[at+7].x;
 FS_PostProcess_Gamma(color);ApplyColorTonemap(color.rgb);result[i]=color;
}
"""
	var source:=RDShaderSource.new();source.source_compute=code;var spirv:=rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty(): failure=spirv.compile_error_compute;return {}
	var shader:=rd.shader_create_from_spirv(spirv);var pipeline:=rd.compute_pipeline_create(shader)
	pipelines[quality]={"shader":shader,"pipeline":pipeline};return pipelines[quality]
