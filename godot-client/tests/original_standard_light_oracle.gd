extends RefCounted
# Test-only original shader execution. Reads installed SHDs through the native
# catalog and compiles their unchanged functions on a local RenderingDevice.
# Includes/uniform storage are adapted to an explicit compute-input boundary.
# No copied original asset is retained, public connection or runtime dependency.
var rd: RenderingDevice
var hashes: Dictionary={}
var failure:=""
var pipelines: Dictionary={}
var last_debug:=PackedFloat32Array()
func load_source(catalog,name: String) -> String:
	var bytes: PackedByteArray=catalog.get_resource(name,2069)
	if bytes.is_empty(): failure="Original shader unavailable: "+name; return ""
	var hashing:=HashingContext.new(); hashing.start(HashingContext.HASH_SHA256); hashing.update(bytes); hashes[name]=hashing.finish().hex_encode()
	var text:=bytes.get_string_from_utf8(); var result:=""
	for line in text.split("\n"):
		if line.strip_edges().begins_with("#include"): continue
		result+=line.replace("uniform ","")+"\n"
	return result
func compile(catalog,quality: int) -> Dictionary:
	if pipelines.has(quality): return pipelines[quality]
	if rd==null: rd=RenderingServer.create_local_rendering_device()
	if rd==null: failure="Original shader oracle requires a local GPU device"; return {}
	var code:="#version 450\n#define LIGHTING 1\n#define SHADER_TYPE 2\n#define GAMMA_CORRECTION 1\n#define SPECULAR_LIGHT 1\n#define FRAGMENT_LIGHTING 1\n#define FRAGMENT_NORMAL 0\n#define SHADER_QUALITY_MODE "+str(quality)+"\n#define MAX_NUM_LIGHTS 128\n#define NORMAL_MAP 0\n#define SPECULAR_MAP 0\n#define ROUGHNESS_MAP 0\n#define HEIGHT_MAP 0\n#define SELF_ILLUMINATION_MAP 0\n#define ENVIRONMENT_MAP 0\n#define POSTPROCESSING 0\n#define SHADER_DEBUG_MODE 0\nvec3 vPosView; vec3 vViewToSurface_n;\nfloat sqr(float value){return value*value;}\nfloat ApplyColorSpace(float value){return sign(value)*pow(abs(value),2.2);}\nvec3 ApplyColorSpace(vec3 value){return sign(value)*pow(abs(value),vec3(2.2));}\nvec4 ApplyColorSpace(vec4 value){return vec4(ApplyColorSpace(value.rgb),value.a);}\n"
	# Pull the original named colors rather than re-declaring approximations.
	for line in load_source(catalog,"inc_common").split("\n"):
		if line.strip_edges().begins_with("#define COLOR_") and ("COLOR_BLACK" in line or "COLOR_WHITE" in line): code+=line+"\n"
	# Explicit environment sampling boundary, initially an authored black map.
	# The original lighting/material functions below are not rewritten.
	code+="int envMapCube=0; vec3 fixture_environment; vec2 vVertexTexCoordsEnvironment=vec2(0.0); vec3 vVertexTexCoordsEnvironmentCube=vec3(0.0);\nvec3 SampleEnvironmentMap(vec2 uv,float lod){return fixture_environment;}\nvec3 SampleEnvironmentMapCube(vec3 uv,float lod){return fixture_environment;}\nvec2 CalculateEnvironmentTexCoords(vec3 normal){return vec2(0.0);}\nvec3 CalculateEnvironmentTexCoordsCube(vec3 normal){return vec3(0.0);}\n"
	for name in ["inc_config","inc_material","inc_lighting"]: code+=load_source(catalog,name)
	if not failure.is_empty(): return {}
	code+="""
layout(local_size_x=1,local_size_y=1,local_size_z=1)in;
layout(set=0,binding=0,std430)readonly buffer Inputs{vec4 data[];};
layout(set=0,binding=1,std430)writeonly buffer Outputs{vec4 result[];};
void main(){
 uint i=gl_GlobalInvocationID.x; uint at=i*13;
 materialFrontDiffuse=vec4(data[at+1].rgb,1.0);
 materialFrontAmbient=vec4(data[at+2].rgb,1.0);
 materialFrontEmissive=vec4(data[at+3].rgb,1.0);
 frontLightModelProductSceneColor=vec4(0.0);
 vPosView=vec3(0.0); vViewToSurface_n=-data[at+7].xyz;
 lightAreaAmbient=data[at+8].rgb; lightAreaDiffuse=data[at+9].rgb;
 lightAreaDiffuseDirection=data[at+10].xyz;
 numLights=int(data[at+4].a)<3?1:0;
 lightColor[0]=vec4(data[at+4].rgb,data[at+5].a*(int(data[at+4].a)==2?-1.0:1.0));
 lightPosition[0]=vec4(data[at+5].xyz,1.0);
 lightMaxIntensityInv=data[at+11].x; lightFalloffFactor=data[at+11].y;
 staticLighting=0; Specularity=0.0; Roughness=0.0; Metallicness=0.0; CustomSpecularColor=vec4(0.0);
 fixture_environment=data[at+12].rgb;
 vec4 color=data[at]; SetupSpecularity(color.rgb*materialFrontDiffuse.rgb);
 ComputeLighting(color,data[at+6].xyz);
 result[i*5]=color; result[i*5+1]=vec4(SpecularColor,fSpecularity);
 result[i*5+2]=vec4(SpecularLight,fRoughness); result[i*5+3]=vec4(DiffuseLight,GetSpecularBaseModifier()); result[i*5+4]=vec4(AmbientLight,1.0);
}
"""
	var source:=RDShaderSource.new(); source.source_compute=code
	var spirv:=rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty(): failure=spirv.compile_error_compute; return {}
	var shader:=rd.shader_create_from_spirv(spirv); var pipeline:=rd.compute_pipeline_create(shader)
	pipelines[quality]={"shader":shader,"pipeline":pipeline}; return pipelines[quality]
func execute(catalog,quality: int,inputs: PackedFloat32Array) -> PackedFloat32Array:
	var program:=compile(catalog,quality)
	if program.is_empty(): return PackedFloat32Array()
	var count:=inputs.size()/52; var source:=inputs.to_byte_array()
	var input:=rd.storage_buffer_create(source.size(),source); var output:=rd.storage_buffer_create(count*80)
	var a:=RDUniform.new(); a.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; a.binding=0; a.add_id(input)
	var b:=RDUniform.new(); b.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; b.binding=1; b.add_id(output)
	var bindings:=rd.uniform_set_create([a,b],program.shader,0)
	var list:=rd.compute_list_begin(); rd.compute_list_bind_compute_pipeline(list,program.pipeline); rd.compute_list_bind_uniform_set(list,bindings,0); rd.compute_list_dispatch(list,count,1,1); rd.compute_list_end(); rd.submit(); rd.sync()
	last_debug=rd.buffer_get_data(output).to_float32_array(); var result:=PackedFloat32Array()
	for index in count: result.append_array(last_debug.slice(index*20,index*20+4))
	for rid in [bindings,input,output]: rd.free_rid(rid)
	return result
func close() -> void:
	if rd==null: return
	for row in pipelines.values(): rd.free_rid(row.pipeline); rd.free_rid(row.shader)
	pipelines.clear(); rd.free(); rd=null
