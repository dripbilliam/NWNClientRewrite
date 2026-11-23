extends RefCounted
# CX Alloy weather lattice, culling, and quad shading from cx_wx_place.glsl,
# cx_wx_hash.glsl, cx_wx_quad.glsl, and cx_wx_shade.glsl. See native/CX-LICENSE.txt.
const GROUP:=64
const CAPACITY:=200000
const DRIP_CAPACITY:=CAPACITY/4
const HEADER:="#version 450\n"+"""
layout(set=0,binding=0,std140) uniform Weather {
 mat4 projection;
 mat4 view;
 mat4 cover;
 vec4 eye_phase;
 vec4 fall_clock;
 vec4 target_count;
 vec4 ambient;
 vec4 sun_direction;
 vec4 sun_color;
 vec4 sky;
} weather;
vec3 unit(vec3 p){ return p*inversesqrt(max(dot(p,p),1e-12)); }
"""
const CULL:="""
layout(local_size_x=64) in;
layout(set=0,binding=1,std430) writeonly buffer Drops { vec4 points[]; };
layout(set=0,binding=2,std430) buffer Command { uint vertices, instances, first, base; };
layout(set=0,binding=3) uniform sampler2D cover_depth;
vec3 hash3(uint n){
 n^=n<<13u; n^=n>>17u; n^=n<<5u;
 uvec3 k=uvec3(n,n*16807u,n*48271u);
 k^=k>>16u; k*=0x7feb352du; k^=k>>15u; k*=0x846ca68bu; k^=k>>16u;
 return vec3(k)/4294967296.0;
}
bool open_sky(vec3 p){
 if(weather.cover[3].w==0.0)return true;
 vec4 projected=weather.cover*vec4(p,1.0);
 vec3 clip=projected.xyz/projected.w;
 if(any(greaterThan(abs(clip.xy),vec2(1.0)))||clip.z<0.0||clip.z>1.0)return true;
 vec2 uv=clip.xy*0.5+0.5;
 ivec2 size=textureSize(cover_depth,0);
 ivec2 pixel=min(ivec2(uv*vec2(size)),size-ivec2(1));
 // The cover viewport uses reverse Z. A larger sample is closer to the sky.
 return clip.z+0.002>=texelFetch(cover_depth,pixel,0).r;
}
bool under_lip(vec3 p,vec3 side,vec3 up){
 return !open_sky(p)&&(open_sky(p+side)||open_sky(p-side)||open_sky(p+up)||open_sky(p-up));
}
void main(){
 uint lattice=gl_GlobalInvocationID.x;
 uint falling=uint(weather.target_count.z);
 if(lattice>=falling+uint(weather.ambient.w))return;
 bool drip=lattice>=falling;
 uint id=drip?lattice-falling:lattice;
 vec3 h=hash3(id*2654435761u+1u);
 vec3 fall=weather.fall_clock.xyz;
 vec3 side=unit(cross(fall,abs(fall.y)<0.99?vec3(0,1,0):vec3(1,0,0)));
 vec3 up=cross(side,fall);
 const float box=52.0;
 float speed=0.75+float(id&3u)*0.125;
 vec3 home=h*box;
 home.z=mod(home.z+weather.eye_phase.w*speed,box);
 vec3 eye=weather.eye_phase.xyz;
 vec3 center=vec3(dot(eye,side),dot(eye,up),dot(eye,fall));
 vec3 q=home+box*floor((center-home)/box+0.5);
 if(weather.target_count.w==2.0){
  float time=weather.fall_clock.w;
  q.xy+=0.5*vec2(sin(time+h.y*6.2832),cos(time*1.5+h.z*6.2832));
 }
 vec3 p=side*q.x+up*q.y+fall*q.z;
 float d=length(eye-p);
 float keep=(1.0-smoothstep(10.0,25.0,d))*(drip?1.0:smoothstep(1.0,3.0,d));
 if(fract(h.z*91.7)>=keep)return;
 vec4 clip=weather.projection*(weather.view*vec4(p,1.0));
 vec2 margin=vec2(abs(weather.projection[0].x),abs(weather.projection[1].y))*0.5;
 if(clip.w<=0.0||any(greaterThan(abs(clip.xy),vec2(clip.w)+margin)))return;
 vec3 feather=p+2.0*(side*(h.y-0.5)+up*(h.z-0.5));
 if(drip?!under_lip(p,side,up):!open_sky(feather))return;
 float seed=0.3+0.7*fract(h.x*7.31);
 float key=min(seed,0.9999)+float(id&3u)+1.0;
 points[atomicAdd(instances,1u)]=vec4(p,drip?-key:key);
}
"""
const VERTEX:="""
layout(set=0,binding=1,std430) readonly buffer Drops { vec4 points[]; };
layout(location=0) out vec2 uv;
layout(location=1) out float view_depth;
layout(location=2) flat out float coverage;
layout(location=3) flat out vec3 scatter;
layout(location=4) flat out float roof_drip;
const vec2 corners[6]=vec2[6](vec2(-1,-1),vec2(1,-1),vec2(1,1),vec2(-1,-1),vec2(1,1),vec2(-1,1));
void main(){
 vec4 point=points[gl_InstanceIndex];
 vec3 to_camera=unit(weather.eye_phase.xyz-point.xyz);
 bool snow=weather.target_count.w==2.0;
 bool drip=point.w<0.0;
 roof_drip=drip?1.0:0.0;
 vec3 side=cross(snow?vec3(0,1,0):weather.fall_clock.xyz,to_camera);
 if(dot(side,side)<1e-10)side=cross(vec3(1,0,0),to_camera);
 side=unit(side);
 vec3 up=unit(cross(to_camera,side));
 float key=abs(point.w)-1.0;
 float speed=0.75+floor(key)*0.125;
 float seed=fract(key);
 vec4 clip=weather.projection*(weather.view*vec4(point.xyz,1.0));
 float pixel=2.0*clip.w/(weather.target_count.y*abs(weather.projection[1].y));
 float length=0.003+(drip?0.0:1.5*12.0*speed/60.0);
 vec2 size=snow?vec2(0.05):max(vec2(0.003,length),vec2(pixel));
 coverage=snow?0.5+0.5*seed:(length*0.003)/(size.x*size.y);
 uv=corners[gl_VertexIndex];
 vec3 p=point.xyz+(side*(uv.x*size.x)+up*(uv.y*size.y))*0.5;
 vec4 v=weather.view*vec4(p,1.0);
 view_depth=-v.z;
 gl_Position=weather.projection*v;
 float g=snow?0.25:0.35;
 float mu=dot(-weather.sun_direction.xyz,to_camera);
 float phase=(1.0-g*g)/pow(max(1.0+g*g-2.0*g*mu,1e-4),1.5);
 scatter=(weather.ambient.rgb+weather.sun_color.rgb*phase)*0.6;
}
"""
const FRAGMENT:="""
layout(set=0,binding=2) uniform sampler2D scene_depth;
layout(location=0) in vec2 uv;
layout(location=1) in float view_depth;
layout(location=2) flat in float coverage;
layout(location=3) flat in vec3 scatter;
layout(location=4) flat in float roof_drip;
layout(location=0) out vec4 color;
void main(){
 bool snow=weather.target_count.w==2.0;
 float radius=length(uv);
 float mask=1.0-smoothstep(snow?0.5:0.85,1.0,radius);
 if(mask<=0.01)discard;
 ivec2 pixel=min(ivec2(gl_FragCoord.xy),textureSize(scene_depth,0)-ivec2(1));
 float d=texelFetch(scene_depth,pixel,0).r;
 mat4 proj=weather.projection;
 float scene_z=(proj[3][2]-d*proj[3][3])/(d*proj[2][3]-proj[2][2]);
 float contact=d>0.0?clamp((-scene_z-view_depth)*6.0,0.0,1.0):1.0;
 float cov=coverage*mask*contact*contact*(snow?1.0:0.7);
 float extinction=snow?0.18:roof_drip>0.0?0.10:0.06;
 float albedo=snow?0.8:0.25;
 // Convert radiance to the current scene carrier before premultiplication.
 vec3 display=pow(max(scatter*albedo,vec3(0.0)),vec3(1.0/2.2));
 vec3 sky=pow(max(weather.sky.rgb,vec3(0.0)),vec3(1.0/2.2));
 color=vec4((display+sky*extinction)*cov,extinction*cov);
}
"""

var cull_shader:=RID()
var initial_command:=PackedInt32Array([6,0,0,0]).to_byte_array()
var cull_pipeline:=RID()
var draw_shader:=RID()
var uniforms:=RID()
var records:=RID()
var indirect:=RID()
var sampler:=RID()
var cull_set:=RID()
var draw_set:=RID()
var bound_depth:=RID()
var bound_cover:=RID()
var pipelines: Dictionary={}
var error:=""

func _shader(rd: RenderingDevice,compute: bool) -> RID:
	var source:=RDShaderSource.new()
	if compute: source.source_compute=HEADER+CULL
	else:
		source.source_vertex=HEADER+VERTEX
		source.source_fragment=HEADER+FRAGMENT
	var spirv:=rd.shader_compile_spirv_from_source(source)
	error=spirv.compile_error_compute+spirv.compile_error_vertex+spirv.compile_error_fragment
	return rd.shader_create_from_spirv(spirv,"CX precipitation cull" if compute else "CX precipitation") if error.is_empty() else RID()

func _binding(kind: int,index: int,rid: RID) -> RDUniform:
	var binding:=RDUniform.new()
	binding.uniform_type=kind
	binding.binding=index
	binding.add_id(rid)
	return binding

func _initialize(rd: RenderingDevice) -> bool:
	cull_shader=_shader(rd,true)
	if not cull_shader.is_valid(): return false
	draw_shader=_shader(rd,false)
	if not draw_shader.is_valid(): return false
	cull_pipeline=rd.compute_pipeline_create(cull_shader)
	uniforms=rd.uniform_buffer_create(304)
	records=rd.storage_buffer_create((CAPACITY+DRIP_CAPACITY)*16)
	indirect=rd.storage_buffer_create(16,initial_command,RenderingDevice.STORAGE_BUFFER_USAGE_DISPATCH_INDIRECT)
	sampler=rd.sampler_create(RDSamplerState.new())
	return cull_pipeline.is_valid() and uniforms.is_valid() and records.is_valid() and indirect.is_valid() and sampler.is_valid()

func _pipeline(rd: RenderingDevice,format: int,samples: int) -> RID:
	if pipelines.has(format): return pipelines[format]
	var blend:=RDPipelineColorBlendStateAttachment.new()
	blend.enable_blend=true
	blend.src_color_blend_factor=RenderingDevice.BLEND_FACTOR_ONE
	blend.dst_color_blend_factor=RenderingDevice.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
	blend.src_alpha_blend_factor=RenderingDevice.BLEND_FACTOR_ONE
	blend.dst_alpha_blend_factor=RenderingDevice.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
	var colors:=RDPipelineColorBlendState.new()
	colors.attachments=[blend]
	var depth:=RDPipelineDepthStencilState.new()
	depth.enable_depth_test=true
	depth.depth_compare_operator=RenderingDevice.COMPARE_OP_GREATER_OR_EQUAL
	var msaa:=RDPipelineMultisampleState.new()
	msaa.sample_count=samples
	var pipeline:=rd.render_pipeline_create(draw_shader,format,-1,RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
		RDPipelineRasterizationState.new(),msaa,depth,colors)
	if pipeline.is_valid(): pipelines[format]=pipeline
	return pipeline

func draw(rd: RenderingDevice,target: Dictionary,depth: RID,matrices: PackedFloat32Array,eye: Vector3,weather: Dictionary,cover: Dictionary) -> bool:
	if not error.is_empty(): return false
	var kind: int=weather.kind
	var count:=clampi(int(CAPACITY*weather.density*(0.5 if kind==2 else 1.0)),0,CAPACITY)
	var drips:=clampi(int(DRIP_CAPACITY*weather.get("drip_wetness",0.0)),0,DRIP_CAPACITY) if kind!=2 and not cover.is_empty() else 0
	if count+drips==0:return true
	if not depth.is_valid():
		error="CX precipitation requires a resolved scene depth texture"
		return false
	if not cull_pipeline.is_valid() and not _initialize(rd):
		if error.is_empty(): error="CX precipitation GPU initialization failed"
		return false
	var roof: RID=cover.get("depth",depth)
	if roof!=bound_cover or not rd.uniform_set_is_valid(cull_set):
		if rd.uniform_set_is_valid(cull_set): rd.free_rid(cull_set)
		var sample:=_binding(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,3,sampler)
		sample.add_id(roof)
		cull_set=rd.uniform_set_create([
			_binding(RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER,0,uniforms),
			_binding(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,1,records),
			_binding(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,2,indirect),
			sample
		],cull_shader,0)
		bound_cover=roof
	if depth!=bound_depth or not rd.uniform_set_is_valid(draw_set):
		if rd.uniform_set_is_valid(draw_set): rd.free_rid(draw_set)
		var sample:=_binding(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,2,sampler)
		sample.add_id(depth)
		draw_set=rd.uniform_set_create([
			_binding(RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER,0,uniforms),
			_binding(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,1,records),
			sample
		],draw_shader,0)
		bound_depth=depth
	var pipeline:=_pipeline(rd,rd.framebuffer_get_format(target.rid),target.samples)
	if not pipeline.is_valid() or not draw_set.is_valid() or not cull_set.is_valid():
		error="CX precipitation GPU binding failed"
		return false
	var fall: Vector3=weather.fall
	var packed:=matrices.duplicate()
	var cover_matrix: Projection=cover.get("matrix",Projection(Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO))
	for column: Vector4 in [cover_matrix.x,cover_matrix.y,cover_matrix.z,cover_matrix.w]:
		packed.append_array(PackedFloat32Array([column.x,column.y,column.z,column.w]))
	packed.append_array(PackedFloat32Array([eye.x,eye.y,eye.z,weather.phase,fall.x,fall.y,fall.z,weather.clock,
		target.size.x,target.size.y,count,kind]))
	var ambient: Vector3=weather.ambient
	packed.append_array(PackedFloat32Array([ambient.x,ambient.y,ambient.z,drips]))
	for vector: Vector3 in [weather.sun_direction,weather.sun_color,weather.sky]:
		packed.append_array(PackedFloat32Array([vector.x,vector.y,vector.z,0.0]))
	if rd.buffer_update(uniforms,0,304,packed.to_byte_array())!=OK or rd.buffer_update(indirect,0,16,initial_command)!=OK:
		error="CX precipitation GPU upload failed"
		return false
	var compute:=rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute,cull_pipeline)
	rd.compute_list_bind_uniform_set(compute,cull_set,0)
	rd.compute_list_dispatch(compute,ceili(float(count+drips)/GROUP),1,1)
	rd.compute_list_end()
	var list:=rd.draw_list_begin(target.rid)
	rd.draw_list_bind_render_pipeline(list,pipeline)
	rd.draw_list_bind_uniform_set(list,draw_set,0)
	rd.draw_list_draw_indirect(list,false,indirect,0)
	rd.draw_list_end()
	return true

func release(rd: RenderingDevice) -> void:
	if rd.uniform_set_is_valid(draw_set): rd.free_rid(draw_set)
	if rd.uniform_set_is_valid(cull_set): rd.free_rid(cull_set)
	for pipeline in pipelines.values(): rd.free_rid(pipeline)
	for handle in [cull_pipeline,sampler,indirect,records,uniforms,draw_shader,cull_shader]:
		if handle.is_valid(): rd.free_rid(handle)
	pipelines.clear()
