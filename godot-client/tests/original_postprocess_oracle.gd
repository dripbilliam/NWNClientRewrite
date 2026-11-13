extends "res://tests/original_surface_output_oracle.gd"
# Unchanged original dynamic midpoint + fragment chain on a local GPU. Explicit
# boundaries: gamma-space framebuffer texel, admitted view-space light arrays,
# projection, converted area colors and raw fog. Alpha output is midpoint debug.
const Post=preload("res://systems/native_render/native_postprocess.gd")
var selected_mask:=0
func input_stride() -> int:return Post.FLOATS+8
func execute(catalog,mask: int,inputs: PackedFloat32Array) -> PackedFloat32Array:
	selected_mask=mask;return super.execute(catalog,0,inputs)
func compile(catalog,_quality: int) -> Dictionary:
	if pipelines.has(selected_mask):return pipelines[selected_mask]
	if rd==null:rd=RenderingServer.create_local_rendering_device()
	if rd==null:failure="Original postprocess oracle needs a local rendering device";return {}
	var common:=load_source(catalog,"inc_common");var original_chain:=load_source(catalog,"inc_postpr")
	var code:="#version 450\n#define SHADER_TYPE 1\n#define GAMMA_CORRECTION 1\n#define POSTPROCESSING_TYPES_ENABLED "+str(selected_mask)+"\n#define MAX_NUM_LIGHTS 128\nvec3 lightAreaAmbient;vec3 lightAreaDiffuse;vec3 lightAreaDiffuseDirection;vec4 lightPosition[128];vec4 lightColor[128];int numLights;mat4 m_proj;vec4 fogColor;float fogStart;float fogEnd;vec2 vVertexTexCoords;vec4 fixture_color;float Vibrance;float Gamma;\n#define texture2D(s,uv) fixture_color\nfloat sqr(float v){return v*v;}\n"
	for line in original_chain.split("\n"):
		if line.begins_with("#define POSTPROCESSING_"):code+=line+"\n"
	code+=load_source(catalog,"inc_config")
	for name in ["ColorToBrightness","ColorToLuma","RevertColorSpace"]:code+=function_source(common,name)
	code+=load_source(catalog,"inc_postpr_dyn_c").replace("varying ","")
	code+=function_source(load_source(catalog,"inc_postpr_dyn_c"),"FS_PostProcess_DynamicContrast")
	code+=function_source(load_source(catalog,"inc_postpr_vibr"),"FS_PostProcess_Vibrance")
	code+=function_source(load_source(catalog,"inc_postpr_gam"),"FS_PostProcess_Gamma")
	code+=load_source(catalog,"inc_tonemap")
	code+="void FS_PostProcess_Debug(inout vec4 color){}\n"+function_source(original_chain,"FS_PostProcess")
	if not failure.is_empty():return {}
	code+="""
layout(local_size_x=1,local_size_y=1,local_size_z=1)in;
layout(set=0,binding=0,std430)readonly buffer Inputs{vec4 data[];};
layout(set=0,binding=1,std430)writeonly buffer Outputs{vec4 result[];};
void main(){
 uint i=gl_GlobalInvocationID.x;uint at=i*267;
 fixture_color=data[at];DynamicContrastMidpoint=data[at+1].x;DynamicContrastIntensity=data[at+1].y;Vibrance=data[at+1].z;Gamma=data[at+1].w;
 lightAreaAmbient=data[at+2].rgb;numLights=int(data[at+2].w);lightAreaDiffuse=data[at+3].rgb;lightAreaDiffuseDirection=data[at+4].xyz;
 fogColor=vec4(data[at+5].rgb,1.0);fogStart=data[at+5].w;fogEnd=data[at+6].x;
 m_proj=mat4(data[at+7],data[at+8],data[at+9],data[at+10]);
 for(int n=0;n<numLights;n++){lightPosition[n]=data[at+11+n*2];lightColor[n]=data[at+12+n*2];}
 fMidPoint=0.0;
 #if (POSTPROCESSING_TYPES_ENABLED & POSTPROCESSING_DYNAMIC_CONTRAST)
 VS_PostProcess_DynamicContrast();
 #endif
 vec4 color=FS_PostProcess();result[i]=vec4(color.rgb,fMidPoint);
}
"""
	var source:=RDShaderSource.new();source.source_compute=code;var spirv:=rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty():failure=spirv.compile_error_compute;return {}
	var shader:=rd.shader_create_from_spirv(spirv);var pipeline:=rd.compute_pipeline_create(shader)
	pipelines[selected_mask]={"shader":shader,"pipeline":pipeline};return pipelines[selected_mask]
static func inputs(frame: PackedFloat32Array,color: Color,options: Dictionary,gamma: float) -> PackedFloat32Array:
	var result:=PackedFloat32Array([color.r,color.g,color.b,color.a,options.get("midpoint",.4),options.get("intensity",0.0),options.get("vibrance",0.0),gamma]);result.append_array(frame);return result
