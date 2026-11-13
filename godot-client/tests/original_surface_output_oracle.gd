extends "res://tests/original_standard_light_oracle.gd"
# Test-only unchanged original transfer/fog/gamma/tonemap functions. Explicit
# input boundary is a linear surface RGBA, fog RGBA(amount), gamma-space
# background RGB and Gamma. No source payload is retained in the receipt.
func function_source(text: String,name: String) -> String:
	var pattern:=RegEx.new(); pattern.compile("(?:void|float|vec3|vec4)\\s+"+name+"\\s*\\([^)]*\\)\\s*\\{")
	var result:=""
	for match_value in pattern.search_all(text):
		var at:=match_value.get_end(); var depth:=1
		while at<text.length() and depth>0:
			if text[at]=="{": depth+=1
			elif text[at]=="}": depth-=1
			at+=1
		if depth!=0: failure="Original function boundary is incomplete: "+name; return ""
		result+=text.substr(match_value.get_start(),at-match_value.get_start())+"\n"
	if result.is_empty(): failure="Original function not found: "+name
	return result
func compile(catalog,quality: int) -> Dictionary:
	if pipelines.has(quality): return pipelines[quality]
	if rd==null: rd=RenderingServer.create_local_rendering_device()
	if rd==null: failure="Original output oracle requires a local GPU device"; return {}
	var code:="#version 450\n#define SHADER_TYPE 2\n#define POSTPROCESSING 0\n#define GAMMA_CORRECTION 1\nfloat sqr(float value){return value*value;}\n"
	code+=load_source(catalog,"inc_config")
	code+=function_source(load_source(catalog,"inc_common"),"RevertColorSpace")
	code+=load_source(catalog,"inc_fog").replace("varying ","")
	code+=load_source(catalog,"inc_postpr_gam")
	code+=load_source(catalog,"inc_tonemap")
	if not failure.is_empty(): return {}
	code+="""
layout(local_size_x=1,local_size_y=1,local_size_z=1)in;
layout(set=0,binding=0,std430)readonly buffer Inputs{vec4 data[];};
layout(set=0,binding=1,std430)writeonly buffer Outputs{vec4 result[];};
void main(){
 uint i=gl_GlobalInvocationID.x; uint at=i*3;
 vec4 color=data[at]; color.rgb=RevertColorSpace(color.rgb);
 fogColor=vec4(data[at+1].rgb,1.0); fFogFragCoord=data[at+1].a;
 ApplyFog(color);
 color.rgb=mix(data[at+2].rgb,color.rgb,color.a);
 Gamma=data[at+2].a; FS_PostProcess_Gamma(color);
 ApplyColorTonemap(color.rgb); result[i]=color;
}
"""
	var source:=RDShaderSource.new(); source.source_compute=code
	var spirv:=rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty(): failure=spirv.compile_error_compute; return {}
	var shader:=rd.shader_create_from_spirv(spirv); var pipeline:=rd.compute_pipeline_create(shader)
	pipelines[quality]={"shader":shader,"pipeline":pipeline}; return pipelines[quality]
func input_stride() -> int: return 12
func execute(catalog,_quality: int,inputs: PackedFloat32Array) -> PackedFloat32Array:
	var program:=compile(catalog,0)
	if program.is_empty(): return PackedFloat32Array()
	var count:=inputs.size()/input_stride(); var source:=inputs.to_byte_array()
	var input:=rd.storage_buffer_create(source.size(),source); var output:=rd.storage_buffer_create(count*16)
	var a:=RDUniform.new(); a.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; a.binding=0; a.add_id(input)
	var b:=RDUniform.new(); b.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; b.binding=1; b.add_id(output)
	var bindings:=rd.uniform_set_create([a,b],program.shader,0)
	var list:=rd.compute_list_begin(); rd.compute_list_bind_compute_pipeline(list,program.pipeline); rd.compute_list_bind_uniform_set(list,bindings,0); rd.compute_list_dispatch(list,count,1,1); rd.compute_list_end(); rd.submit(); rd.sync()
	var result:=rd.buffer_get_data(output).to_float32_array()
	for rid in [bindings,input,output]: rd.free_rid(rid)
	return result
