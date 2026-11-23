extends RefCounted
# Rain-only volume from CX's cx_vfrain.glsl and cx_vfogsum_cs.glsl.
# The rain-only path integrates each column directly and has no medium
# texture, since it carries no lamp grid, temporal light or fog wall.
const GRID:=Vector3i(96,54,48)
const UNIFORM_BYTES:=256
const SAMPLE=preload("res://systems/native_render/cx_rain_haze_sample.gdshaderinc")
const HEADER:="#version 450\n"+"""
layout(set=0,binding=0,std140) uniform ViewTerms {
 mat4 projection;
 mat4 camera_to_world;
 mat4 cover;
 vec4 depth; // near, far, log(far/near), rain density
 vec4 ambient;
 vec4 sun_direction;
 vec4 sun_share;
} fog;
"""
const INTEGRATE:="""
layout(local_size_x=8,local_size_y=8) in;
layout(set=0,binding=1) uniform sampler2D roof;
layout(set=0,binding=2,rgba16f) writeonly uniform image3D volume;

float exposure(vec3 p){
 if(fog.cover[3].w==0.0)return 1.0;
 vec4 c=fog.cover*vec4(p,1.0);
 vec3 q=c.xyz/c.w;
 if(any(greaterThan(abs(q.xy),vec2(1.0)))||q.z<0.0||q.z>1.0)return 1.0;
 ivec2 size=textureSize(roof,0);
 ivec2 pixel=min(ivec2((q.xy*0.5+0.5)*vec2(size)),size-ivec2(1));
 return q.z+0.002>=texelFetch(roof,pixel,0).r?1.0:0.15;
}

vec3 world_at(vec2 ndc,float depth){
 vec4 centre=fog.projection[2]*(-depth)+fog.projection[3];
 vec2 xy=(ndc*centre.w-centre.xy)/vec2(fog.projection[0].x,fog.projection[1].y);
 return (fog.camera_to_world*vec4(xy,-depth,1.0)).xyz;
}

void main(){
 ivec2 column=ivec2(gl_GlobalInvocationID.xy);
 ivec3 grid=imageSize(volume);
 if(any(greaterThanEqual(column,grid.xy)))return;
 vec2 ndc=(vec2(column)+0.5)*2.0/vec2(grid.xy)-1.0;
 vec3 eye=fog.camera_to_world[3].xyz;
 vec3 origin=world_at(ndc,0.0);
 vec3 ray=world_at(ndc,1.0)-origin;
 float rate=length(ray);
 const float g=0.4;
 float mu=dot(ray/max(rate,1e-6),fog.sun_direction.xyz);
 float phase=(1.0-g*g)/pow(max(1.0+g*g-2.0*g*mu,1e-4),1.5);
 vec3 light=fog.ambient.rgb*(1.0-fog.sun_share.w+fog.sun_share.rgb*phase);
 float transmittance=1.0;
 vec3 scatter=vec3(0.0);
 float d0=fog.depth.x;
 for(int slice=0;slice<grid.z;++slice){
  float d1=fog.depth.x*exp(fog.depth.z*float(slice+1)/float(grid.z));
  vec3 p=origin+ray*(0.5*(d0+d1));
  float d=length(p-eye);
  if(d>10.0){
   float extinction=fog.depth.w*0.005*smoothstep(10.0,25.0,d)*exposure(p);
   float through=exp(-extinction*(d1-d0)*rate);
   scatter+=transmittance*light*(1.0-through);
   transmittance*=through;
  }
  imageStore(volume,ivec3(column,slice),vec4(scatter,transmittance));
  d0=d1;
 }
}
"""
const FULLSCREEN:="#version 450\n"+"""
void main(){
 const vec2 corners[3]=vec2[3](vec2(-1,-1),vec2(3,-1),vec2(-1,3));
 gl_Position=vec4(corners[gl_VertexIndex],0.0,1.0);
}
"""
const COMPOSITE:="""
layout(set=0,binding=1) uniform sampler2D scene_depth;
layout(set=0,binding=2) uniform sampler3D volume;
layout(location=0) out vec4 color;
void main(){
 ivec2 size=textureSize(scene_depth,0);
 ivec2 p=min(ivec2(gl_FragCoord.xy),size-ivec2(1));
 float d=texelFetch(scene_depth,p,0).r;
 mat4 proj=fog.projection;
 float depth=d>0.0?(d*proj[3][3]-proj[3][2])/(d*proj[2][3]-proj[2][2]):fog.depth.y;
 vec4 haze=cx_rain_haze_at(volume,gl_FragCoord.xy/vec2(size),depth,fog.depth.x,1.0/fog.depth.z);
 if(haze.a>=1.0)discard;
 color=cx_rain_haze_display(haze);
}
"""

var compute_shader:=RID()
var render_shader:=RID()
var compute_pipeline:=RID()
var sampler:=RID()
var parameters:=RID()
var volume:=RID()
var integrate_set:=RID()
var composite_set:=RID()
var bound_roof:=RID()
var bound_depth:=RID()
var pipelines: Dictionary={}
var previous:=PackedByteArray()
var cover_bake:=-1
var builds:=0
var error:=""

func _shader(rd: RenderingDevice,compute: bool) -> RID:
	var source:=RDShaderSource.new()
	if compute: source.source_compute=HEADER+INTEGRATE
	else:
		source.source_vertex=FULLSCREEN
		source.source_fragment=HEADER+SAMPLE.code+COMPOSITE
	var spirv:=rd.shader_compile_spirv_from_source(source)
	error=spirv.compile_error_compute+spirv.compile_error_vertex+spirv.compile_error_fragment
	return rd.shader_create_from_spirv(spirv,"CX rain volume" if compute else "CX rain veil") if error.is_empty() else RID()

func _initialize(rd: RenderingDevice) -> bool:
	compute_shader=_shader(rd,true)
	if not compute_shader.is_valid(): return false
	render_shader=_shader(rd,false)
	if not render_shader.is_valid(): return false
	compute_pipeline=rd.compute_pipeline_create(compute_shader)
	parameters=rd.uniform_buffer_create(UNIFORM_BYTES)
	var format:=RDTextureFormat.new()
	format.texture_type=RenderingDevice.TEXTURE_TYPE_3D
	format.format=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.width=GRID.x
	format.height=GRID.y
	format.depth=GRID.z
	format.usage_bits=RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	volume=rd.texture_create(format,RDTextureView.new())
	var filter:=RDSamplerState.new()
	filter.mag_filter=RenderingDevice.SAMPLER_FILTER_LINEAR
	filter.min_filter=RenderingDevice.SAMPLER_FILTER_LINEAR
	filter.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	filter.repeat_v=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	filter.repeat_w=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler=rd.sampler_create(filter)
	return compute_pipeline.is_valid() and parameters.is_valid() and volume.is_valid() and sampler.is_valid()

func _binding(kind: int,index: int,resource: RID) -> RDUniform:
	var binding:=RDUniform.new()
	binding.uniform_type=kind
	binding.binding=index
	if kind==RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE: binding.add_id(sampler)
	binding.add_id(resource)
	return binding

func _pipeline(rd: RenderingDevice,format: int,samples: int) -> RID:
	if pipelines.has(format): return pipelines[format]
	var blend:=RDPipelineColorBlendStateAttachment.new()
	blend.enable_blend=true
	blend.src_color_blend_factor=RenderingDevice.BLEND_FACTOR_ONE
	blend.dst_color_blend_factor=RenderingDevice.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
	blend.src_alpha_blend_factor=RenderingDevice.BLEND_FACTOR_ZERO
	blend.dst_alpha_blend_factor=RenderingDevice.BLEND_FACTOR_ONE
	var colors:=RDPipelineColorBlendState.new()
	colors.attachments=[blend]
	var msaa:=RDPipelineMultisampleState.new()
	msaa.sample_count=samples
	var pipeline:=rd.render_pipeline_create(render_shader,format,-1,RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
		RDPipelineRasterizationState.new(),msaa,RDPipelineDepthStencilState.new(),colors)
	if pipeline.is_valid(): pipelines[format]=pipeline
	return pipeline

func draw(rd: RenderingDevice,target: Dictionary,depth_buffer: RID,projection: Projection,camera: Transform3D,weather: Dictionary,cover: Dictionary) -> Vector4:
	if not error.is_empty(): return Vector4.ZERO
	var near_z:=1.0
	var far_z:=projection.w.z/projection.z.z
	if not is_finite(far_z) or far_z<=10.0 or not depth_buffer.is_valid(): return Vector4.ZERO
	var log_depth:=log(far_z/near_z)
	if not compute_pipeline.is_valid() and not _initialize(rd):
		if error.is_empty(): error="CX rain volume creation failed"
		return Vector4.ZERO
	var roof: RID=cover.get("depth",depth_buffer)
	var rebuild: bool=bound_roof!=roof or not rd.uniform_set_is_valid(integrate_set)
	if rebuild:
		if rd.uniform_set_is_valid(integrate_set): rd.free_rid(integrate_set)
		integrate_set=rd.uniform_set_create([
			_binding(RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER,0,parameters),
			_binding(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,1,roof),
			_binding(RenderingDevice.UNIFORM_TYPE_IMAGE,2,volume)
		],compute_shader,0)
		bound_roof=roof
	if bound_depth!=depth_buffer or not rd.uniform_set_is_valid(composite_set):
		if rd.uniform_set_is_valid(composite_set): rd.free_rid(composite_set)
		composite_set=rd.uniform_set_create([
			_binding(RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER,0,parameters),
			_binding(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,1,depth_buffer),
			_binding(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,2,volume)
		],render_shader,0)
		bound_depth=depth_buffer
	var pipeline:=_pipeline(rd,rd.framebuffer_get_format(target.rid),target.samples)
	if not pipeline.is_valid() or not integrate_set.is_valid() or not composite_set.is_valid():
		error="CX rain volume binding failed"
		return Vector4.ZERO
	var packed:=PackedFloat32Array()
	var roof_matrix: Projection=cover.get("matrix",Projection(Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO))
	for matrix: Projection in [projection,Projection(camera),roof_matrix]:
		for column: Vector4 in [matrix.x,matrix.y,matrix.z,matrix.w]:
			packed.append_array(PackedFloat32Array([column.x,column.y,column.z,column.w]))
	var ambient: Vector3=weather.get("veil_ambient",weather.ambient)
	var sun: Vector3=weather.sun_direction
	var share: Vector4=weather.get("veil_sun",Vector4.ZERO)
	packed.append_array(PackedFloat32Array([near_z,far_z,log_depth,weather.density,ambient.x,ambient.y,ambient.z,0,
		sun.x,sun.y,sun.z,0,share.x,share.y,share.z,share.w]))
	var bytes:=packed.to_byte_array()
	var roof_bake: int=cover.get("bakes",0)
	if rebuild or bytes!=previous or roof_bake!=cover_bake:
		if rd.buffer_update(parameters,0,UNIFORM_BYTES,bytes)!=OK:
			error="CX rain volume upload failed"
			return Vector4.ZERO
		var compute:=rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute,compute_pipeline)
		rd.compute_list_bind_uniform_set(compute,integrate_set,0)
		rd.compute_list_dispatch(compute,ceili(GRID.x/8.0),ceili(GRID.y/8.0),1)
		rd.compute_list_end()
		previous=bytes
		cover_bake=roof_bake
		builds+=1
	var list:=rd.draw_list_begin(target.rid)
	rd.draw_list_bind_render_pipeline(list,pipeline)
	rd.draw_list_bind_uniform_set(list,composite_set,0)
	rd.draw_list_draw(list,false,1,3)
	rd.draw_list_end()
	return Vector4(1.0/target.size.x,1.0/target.size.y,near_z,1.0/log_depth)

func release(rd: RenderingDevice) -> void:
	if rd.uniform_set_is_valid(integrate_set): rd.free_rid(integrate_set)
	if rd.uniform_set_is_valid(composite_set): rd.free_rid(composite_set)
	for pipeline in pipelines.values(): rd.free_rid(pipeline)
	for handle in [compute_pipeline,parameters,volume,sampler,render_shader,compute_shader]:
		if handle.is_valid(): rd.free_rid(handle)
