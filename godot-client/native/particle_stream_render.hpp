// Experimental compositor consumer. Main-thread submissions retain exact native
// packets; RenderingServer ordering publishes each packet on the render thread.
// No scene Node or presentation entry is inspected by a render callback.
namespace particle_stream_render {
bool registered=false;
GDExtensionMethodBindPtr bind_pipeline,bind_uniform,bind_vertices,draw_vertices,end_list,update,texture_rd,free_resource,push,valid_uniform;
bool bind(){
 Name rd("RenderingDevice"),rs("RenderingServer");
 const auto method=[&](const char* name,int64_t hash){Name n(name);return class_method(rd.data,n.data,hash);};
 bind_pipeline=method("draw_list_bind_render_pipeline",4040184819);bind_uniform=method("draw_list_bind_uniform_set",749655778);bind_vertices=method("draw_list_bind_vertex_buffers_format",2008628980);draw_vertices=method("draw_list_draw",4230067973);end_list=method("draw_list_end",3218959716);update=method("buffer_update",3454956949);free_resource=method("free_rid",2722037293);
 push=method("draw_list_set_push_constant",2772371345);
 valid_uniform=method("uniform_set_is_valid",3521089500);
 Name name("texture_get_rd_texture");texture_rd=class_method(rs.data,name.data,2790148051);
 return bind_pipeline&&bind_uniform&&bind_vertices&&draw_vertices&&end_list&&update&&texture_rd&&free_resource&&push&&valid_uniform;
}
EngineVar rid(uint64_t value){EngineVar out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_RID](out.data,&value);return out;}
uint64_t rid_value(const EngineVar& value){if(value.type()!=GDEXTENSION_VARIANT_TYPE_RID)throw std::runtime_error("Particle GPU operation did not return RID");uint64_t out=0;to[GDEXTENSION_VARIANT_TYPE_RID](&out,const_cast<uint8_t*>(value.data));return out;}
EngineVar object(const char* type){Name name(type);auto pointer=construct_object(name.data);if(!pointer)throw std::runtime_error("Particle GPU helper class is absent");EngineVar out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](out.data,&pointer);::method(out,"notification",{EngineVar::integer(0)});if(::method(out,"unreference").boolean())throw std::runtime_error("Particle helper lost its owning Variant reference");return out;}
void property(EngineVar& value,const char* name,const EngineVar& input){::method(value,"set",{EngineVar::text(name),input});}
EngineVar typed_array(EngineVar values,GDExtensionVariantType type,const char* name=""){
 Name class_name(name);EngineVar klass;destroy(klass.data);from[GDEXTENSION_VARIANT_TYPE_STRING_NAME](klass.data,class_name.data);auto kind=EngineVar::integer(type);EngineVar script,out;destroy(out.data);const GDExtensionConstVariantPtr args[]={values.data,kind.data,klass.data,script.data};GDExtensionCallError error{};construct(GDEXTENSION_VARIANT_TYPE_ARRAY,out.data,args,4,&error);if(error.error)throw std::runtime_error("Particle GPU typed-array construction failed");return out;
}
struct Raw {alignas(8) uint8_t data[16]{};GDExtensionVariantType type;uint32_t reserved=0;Raw(const EngineVar& value,GDExtensionVariantType next):type(next){to[type](data,const_cast<uint8_t*>(value.data));}~Raw(){ptr_destructor(type)(data);}Raw(const Raw&)=delete;};
struct Owner {
 GDExtensionObjectPtr object=nullptr;EngineVar retained;particle_presentation::Owner* presentation=nullptr;
 std::mutex mutex;std::unordered_map<int64_t,std::shared_ptr<const particle_presentation::Packet>> pending;std::shared_ptr<const particle_presentation::Packet> ready;
 std::atomic<bool> alive{true};std::atomic<int64_t> error{0},submissions{0},uploads{0},bytes{0},draws{0},drawn_vertices{0},generation{0},last_draws{0},last_vertices{0};std::string failure;
 // GPU state below belongs exclusively to the render thread.
 uint64_t shader=0,sampler=0,buffer=0,fog_buffer=0;int64_t capacity=0,vertex_format=0,framebuffer_format=-1,last_uploaded=-1,last_samples=-1;std::array<uint64_t,6> pipelines{};EngineVar buffers;bool debug_no_depth=false,debug_readback=false,native_surface_output=false,batch_ranges=false;float alpha_discard=-1;std::string readback;
 std::string cx_fog_code;
 std::array<float,32> uploaded_fog{};
 bool fog_uploaded=false;
 uint64_t empty_depth=0,empty_haze=0,depth_set=0,sampled_depth=0,sampled_haze=0,haze_sampler=0;
 uint64_t sun_buffer=0;
 std::array<uint64_t,4> sampled_sun{};
 std::array<uint8_t,40*sizeof(float)> uploaded_sun{};
 uint64_t omni_buffer=0,sampled_omni_atlas=0;
 size_t omni_capacity=0;
 std::vector<uint8_t> uploaded_omni,staged_omni;
 uint64_t record_set=0,index_buffer=0,light_buffer=0;
 cx_particle::DrawOrder cx_order;
 std::atomic<int64_t> index_bytes{0},last_sorted_groups{0};
 size_t light_capacity=0;
 std::vector<uint8_t> uploaded_lights;
 std::atomic<int64_t> light_upload_bytes{0},last_point_lights{0};
 uint64_t cluster_shader=0,cluster_pipeline=0,cluster_set=0,cluster_buffer=0;
 size_t cluster_capacity=0;
 bool cluster_dirty=true;
 std::array<uint8_t,112> cluster_view{};
 std::atomic<int64_t> cluster_builds{0},last_grid_cells{0};
 bool cx_records=false;
 struct Uniform {std::shared_ptr<const particle_presentation::Material> material;uint64_t rid;};std::unordered_map<uint64_t,Uniform> uniforms;
 void configure(const EngineVar& input){
  if(!retained.nil()||!alive.load())throw std::runtime_error("Particle stream renderer configures once");auto source=::get(input,"presentation");if(source.type()!=GDEXTENSION_VARIANT_TYPE_OBJECT)throw std::runtime_error("Particle stream renderer requires native presentation");
  GDExtensionObjectPtr pointer=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&pointer,source.data);std::lock_guard<std::mutex> lock(particle_presentation::registry_mutex);auto found=particle_presentation::registry.find(pointer);if(found==particle_presentation::registry.end())throw std::runtime_error("Particle presentation is absent");retained=source;presentation=found->second;debug_no_depth=::has(input,"debug_no_depth")&&::get(input,"debug_no_depth").boolean();debug_readback=::has(input,"debug_readback")&&::get(input,"debug_readback").boolean();native_surface_output=::has(input,"native_surface_output")&&::get(input,"native_surface_output").boolean();
  if(::has(input,"alpha_discard")){alpha_discard=static_cast<float>(::get(input,"alpha_discard").number());if(!std::isfinite(alpha_discard))throw std::runtime_error("Particle alpha discard must be finite");}
  batch_ranges=::has(input,"batch_ranges")?::get(input,"batch_ranges").boolean():native_surface_output;
  cx_records=::has(input,"cx_records")&&::get(input,"cx_records").boolean();
  if(cx_records){
   if(!native_surface_output)throw std::runtime_error("CX particle records require native surface output");
   Name name("ResourceLoader");
   auto loader_object=global_singleton(name.data);
   EngineVar loader;
   destroy(loader.data);
   from[GDEXTENSION_VARIANT_TYPE_OBJECT](loader.data,&loader_object);
   for(const char* path:{"res://systems/native_render/cx_fog_common.gdshaderinc","res://systems/native_render/cx_rain_haze_sample.gdshaderinc"}){
    auto include=::method(loader,"load",{EngineVar::text(path)});
    if(include.nil())throw std::runtime_error("CX particle fog shader include could not load");
    auto code=engine_string(::method(include,"get_code"));
    if(code.empty())throw std::runtime_error("CX particle fog shader include is empty");
    cx_fog_code+=code+"\n";
   }
   presentation->enable_cx_records();
  }
 }
 void fail(const char* text){std::lock_guard<std::mutex> lock(mutex);failure=text;error.store(1,std::memory_order_release);}
 void schedule(const char* name,int64_t sequence){
  Name server_name("RenderingServer");auto server=global_singleton(server_name.data);if(!server)throw std::runtime_error("RenderingServer is absent");EngineVar self;destroy(self.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](self.data,&object);
  EngineVar command;destroy(command.data);auto method=EngineVar::text(name);const GDExtensionConstVariantPtr args[]={self.data,method.data};GDExtensionCallError err{};construct(GDEXTENSION_VARIANT_TYPE_CALLABLE,command.data,args,2,&err);if(err.error)throw std::runtime_error("Particle stream render callback construction failed");command=::method(command,"bind",{self,EngineVar::integer(sequence)});
  Raw callback(command,GDEXTENSION_VARIANT_TYPE_CALLABLE);const GDExtensionConstTypePtr params[]={callback.data};ptrcall(particle_upload::schedule_upload,server,params,nullptr);
 }
 void submit(){
  if(!alive.load()||error.load())return;if(!presentation||presentation->running)throw std::runtime_error("Particle stream submission requires a completed main-thread frame");auto frame=presentation->packet;if(!frame)throw std::runtime_error("Particle stream has no completed native frame");
  {std::lock_guard<std::mutex> lock(mutex);if(pending.find(frame->generation)!=pending.end())return;pending.emplace(frame->generation,frame);}schedule("accept",frame->generation);++submissions;
 }
 void accept(int64_t sequence){std::lock_guard<std::mutex> lock(mutex);auto found=pending.find(sequence);if(found==pending.end())return;if(alive.load())ready=found->second;pending.erase(found);}
 void discard(GDExtensionObjectPtr rd,uint64_t& resource){if(resource){const GDExtensionConstTypePtr args[]={&resource};ptrcall(free_resource,rd,args,nullptr);resource=0;}}
 bool depth_binding_valid(GDExtensionObjectPtr rd)const{
  if(!depth_set)return false;
  GDExtensionBool valid=false;
  const GDExtensionConstTypePtr args[]={&depth_set};
  ptrcall(valid_uniform,rd,args,&valid);
  return valid;
 }
 void release(){
  Name name("RenderingServer");auto server=global_singleton(name.data);GDExtensionObjectPtr rd=nullptr;GDExtensionBool thread=false;ptrcall(particle_upload::is_render_thread,server,nullptr,&thread);if(!thread)throw std::runtime_error("Particle stream release requires render thread");ptrcall(particle_upload::get_device,server,nullptr,&rd);
  if(rd){
   for(auto& row:uniforms)discard(rd,row.second.rid);
   uniforms.clear();
   for(auto& pipeline:pipelines)discard(rd,pipeline);
   if(depth_binding_valid(rd))discard(rd,depth_set);
   discard(rd,empty_depth);discard(rd,empty_haze);discard(rd,haze_sampler);discard(rd,record_set);
   discard(rd,cluster_set);discard(rd,cluster_pipeline);discard(rd,cluster_shader);discard(rd,cluster_buffer);
   discard(rd,light_buffer);discard(rd,omni_buffer);discard(rd,index_buffer);discard(rd,buffer);discard(rd,fog_buffer);discard(rd,sun_buffer);discard(rd,sampler);discard(rd,shader);
  }
  buffers=EngineVar();
  {std::lock_guard<std::mutex> lock(mutex);ready.reset();pending.clear();}retained=EngineVar();presentation=nullptr;
 }
 void cancel(){if(alive.exchange(false))schedule("release",0);}
 void initialize(EngineVar& device){
  auto source=object_resource("RDShaderSource");
  property(source,"source_vertex",EngineVar::text("#version 450\nlayout(location=0) in vec4 color_in;layout(location=1) in vec3 position_in;layout(location=2) in vec2 uv_in;layout(location=0) out vec4 tint;layout(location=1) out vec2 uv;layout(location=2) out vec3 view_position;layout(push_constant,std430) uniform Params{mat4 projection;mat4 view;} params;void main(){vec4 view=params.view*vec4(position_in,1.0);gl_Position=params.projection*view;view_position=view.xyz;tint=color_in;uv=uv_in;}"));
  // Match Forward+ depth/exponential fog, including half storage and its
  // source-alpha blend treatment for both normal and additive materials.
  property(source,"source_fragment",EngineVar::text("#version 450\nlayout(location=0) in vec4 tint;layout(location=1) in vec2 uv;layout(location=2) in vec3 view_position;layout(set=0,binding=0) uniform sampler2D original_texture;layout(set=0,binding=1,std140) uniform SceneFog{vec4 color_density;vec4 depth;} scene_fog;layout(location=0) out vec4 result;void main(){result=texture(original_texture,uv)*tint;if(scene_fog.depth.w!=0.0){float distance=length(view_position);float amount=scene_fog.depth.w==1.0?pow(smoothstep(scene_fog.depth.x,scene_fog.depth.y,distance),scene_fog.depth.z)*scene_fog.color_density.a:1.0-exp(min(0.0,-distance*scene_fog.color_density.a));vec4 fog=vec4(scene_fog.color_density.rgb*amount,1.0-amount);fog=vec4(unpackHalf2x16(packHalf2x16(fog.rg)),unpackHalf2x16(packHalf2x16(fog.ba)));result.rgb=result.rgb*fog.a+fog.rgb;}}"));
  if(native_surface_output){
   // Retail vsparticle/fsparticle: raw texture/tint, view-depth fog amount
   // interpolated before clamping, and additive alpha fade. Not Godot fog.
   property(source,"source_vertex",EngineVar::text(R"glsl(#version 450
layout(location=0) in vec4 color_in;layout(location=1) in vec3 position_in;layout(location=2) in vec2 uv_in;
layout(location=0) out vec4 tint;layout(location=1) out vec2 uv;layout(location=2) out float fog_amount;
layout(location=3) out float view_depth;
layout(location=4) flat out float particle_softness;
layout(location=5) out vec3 particle_light;
layout(set=0,binding=1,std140) uniform SceneFog{vec4 color_density;vec4 depth;} scene_fog;
layout(push_constant,std430) uniform Params{mat4 projection;mat4 view;} params;
void main(){vec4 view=params.view*vec4(position_in,1.0);gl_Position=params.projection*view;
view_depth=-view.z;fog_amount=scene_fog.depth.w==3.0?(view_depth-scene_fog.depth.x)*scene_fog.depth.z:0.0;tint=color_in;uv=uv_in;particle_softness=4.0;particle_light=vec3(1.0);}
)glsl"));
   if(cx_records){
    auto vertex_source=cx_particle::light_shader_prefix(2,2)+cx_particle::vertex_shader;
    property(source,"source_vertex",EngineVar::text(vertex_source.c_str()));
   }
   auto fragment=std::string("#version 450\n");
   if(cx_records)fragment+="#define CX_FOG\n"+cx_fog_code+"\n";
   fragment+=R"glsl(
layout(location=0) in vec4 tint;layout(location=1) in vec2 uv;
#ifdef CX_FOG
layout(location=2) in vec3 fog_world;
layout(location=6) flat in vec3 fog_eye;
#else
layout(location=2) in float fog_amount;
#endif
layout(location=3) in float view_depth;
layout(location=4) flat in float particle_softness;
layout(location=5) in vec3 particle_light;
layout(set=0,binding=0) uniform sampler2D original_texture;
layout(set=0,binding=1,std140) uniform SceneFog{
 vec4 color_density;
 vec4 depth;
#ifdef CX_FOG
 vec4 origin;
 vec4 sky;
 vec4 layer;
 vec4 sun;
 vec4 sun_color;
 vec4 rain_haze; // inverse target size, near depth, inverse log depth range
#endif
} scene_fog;
layout(set=1,binding=0) uniform sampler2D scene_depth;
#ifdef CX_FOG
layout(set=1,binding=1) uniform sampler3D rain_haze;
#endif
layout(push_constant,std430) uniform Params{mat4 projection;mat4 view;} params;
layout(constant_id=0) const bool additive=false;layout(constant_id=1) const float alpha_discard=-1.0;
layout(constant_id=2) const bool cx_depth_curve=false;
layout(location=0) out vec4 result;
void main(){result=texture(original_texture,uv)*tint;if(alpha_discard>=0.0&&result.a<=alpha_discard)discard;
// Native surface output carries gamma-encoded RGB. Decode, apply the linear
// light, and re-encode by folding the two powers into the light multiplier.
if(cx_depth_curve&&!additive&&alpha_discard<0.0)result.rgb*=pow(max(particle_light,vec3(0.0)),vec3(1.0/2.2));
if((cx_depth_curve||(!additive&&alpha_discard<0.0))&&particle_softness>0.0){
 ivec2 pixel=min(ivec2(gl_FragCoord.xy),textureSize(scene_depth,0)-ivec2(1));
 float depth=texelFetch(scene_depth,pixel,0).r;
 if(depth>0.0){
  mat4 proj=params.projection;
  float scene_z=(proj[3][2]-depth*proj[3][3])/(depth*proj[2][3]-proj[2][2]);
  float fade=clamp((-scene_z-view_depth)*particle_softness,0.0,1.0);
  result.a*=cx_depth_curve?fade*fade:fade;
 }
}
vec3 fog_color=scene_fog.color_density.rgb;
#ifdef CX_FOG
float amount=cx_fog_amount(scene_fog.depth.w,scene_fog.depth.xz,scene_fog.origin,scene_fog.layer.xy,fog_world,view_depth);
if(!additive)fog_color=cx_fog_display_color(fog_color,scene_fog.sky,scene_fog.sun,scene_fog.sun_color.rgb,fog_world-fog_eye,amount);
#else
float amount=clamp(fog_amount,0.0,1.0);
#endif
if(additive)result.a*=1.0-amount;else result.rgb=mix(result.rgb,fog_color,amount);
#ifdef CX_FOG
if(scene_fog.rain_haze.x>0.0){
 vec4 haze=cx_rain_haze_at(rain_haze,gl_FragCoord.xy*scene_fog.rain_haze.xy,view_depth,scene_fog.rain_haze.z,scene_fog.rain_haze.w);
 if(additive)result.a*=haze.a;
 else if(haze.a<1.0)result.rgb=result.rgb*haze.a+cx_rain_haze_display(haze).rgb;
}
#endif
}
)glsl";
   property(source,"source_fragment",EngineVar::text(fragment.c_str()));
  }
  auto spirv=::method(device,"shader_compile_spirv_from_source",{source,EngineVar::boolean(true)});
  for(const char* property_name:{"compile_error_vertex","compile_error_fragment"}){auto message=::method(spirv,"get",{EngineVar::text(property_name)});if(!engine_string(message).empty())throw std::runtime_error(engine_string(message));}
  shader=rid_value(::method(device,"shader_create_from_spirv",{spirv,EngineVar::text("NWN shared particle stream")}));if(!shader)throw std::runtime_error("Shared particle shader creation failed");
  const auto fog_size=cx_records?sizeof(uploaded_fog):8*sizeof(float);
  auto fog_data=WritableBytes(fog_size).publish();
  fog_buffer=rid_value(::method(device,"uniform_buffer_create",{EngineVar::integer(fog_size),fog_data,EngineVar::integer(0)}));
  if(!fog_buffer)throw std::runtime_error("Shared particle fog buffer allocation failed");
  if(cx_records){
   WritableBytes neutral_sun(uploaded_sun.size());
   std::memcpy(neutral_sun.data,uploaded_sun.data(),uploaded_sun.size());
   sun_buffer=rid_value(::method(device,"uniform_buffer_create",{EngineVar::integer(uploaded_sun.size()),neutral_sun.publish(),EngineVar::integer(0)}));
   if(!sun_buffer)throw std::runtime_error("CX particle sun fit allocation failed");
  }
  auto state=object_resource("RDSamplerState");for(const char* p:{"mag_filter","min_filter","mip_filter"})property(state,p,EngineVar::integer(1));for(const char* p:{"repeat_u","repeat_v","repeat_w"})property(state,p,EngineVar::integer(0));sampler=rid_value(::method(device,"sampler_create",{state}));
  if(cx_records){
   for(const char* p:{"repeat_u","repeat_v","repeat_w"})property(state,p,EngineVar::integer(2)); // clamp to edge
   haze_sampler=rid_value(::method(device,"sampler_create",{state}));
   vertex_format=-1;
   return;
  }
  auto attributes=::array_empty();const std::array<int64_t,3> formats{36,105,102},offsets{0,4,16};for(size_t i=0;i<3;++i){auto attribute=object_resource("RDVertexAttribute");property(attribute,"binding",EngineVar::integer(0));property(attribute,"location",EngineVar::integer(static_cast<int64_t>(i)));property(attribute,"format",EngineVar::integer(formats[i]));property(attribute,"offset",EngineVar::integer(offsets[i]));property(attribute,"stride",EngineVar::integer(24));::method(attributes,"append",{attribute});}
  vertex_format=::method(device,"vertex_format_create",{typed_array(attributes,GDEXTENSION_VARIANT_TYPE_OBJECT,"RDVertexAttribute")}).integer();
 }
 void upload_fog(GDExtensionObjectPtr rd,const particle_presentation::Packet& frame,const std::array<float,4>& haze){
  const auto base_size=sizeof(frame.fog);
  const auto length=static_cast<int64_t>(cx_records?sizeof(uploaded_fog):base_size);
  const auto* extension=uploaded_fog.data()+frame.fog.size();
  if(fog_uploaded&&!std::memcmp(uploaded_fog.data(),frame.fog.data(),base_size)
   &&(!cx_records||(!std::memcmp(extension,frame.cx_fog.data(),sizeof(frame.cx_fog))
    &&!std::memcmp(extension+frame.cx_fog.size(),haze.data(),sizeof(haze)))))return;
  WritableBytes packed(length);
  std::memcpy(packed.data,frame.fog.data(),base_size);
  if(cx_records){
   std::memcpy(packed.data+base_size,frame.cx_fog.data(),sizeof(frame.cx_fog));
   std::memcpy(packed.data+base_size+sizeof(frame.cx_fog),haze.data(),sizeof(haze));
  }
  const int64_t offset=0;
  int64_t status=-1;
  const GDExtensionConstTypePtr args[]={&fog_buffer,&offset,&length,packed.raw};
  ptrcall(update,rd,args,&status);
  if(status)throw std::runtime_error("Shared particle scene fog upload failed");
  std::memcpy(uploaded_fog.data(),packed.data,length);
  fog_uploaded=true;
 }
 static EngineVar object_resource(const char* name){return particle_stream_render::object(name);}
 static int pipeline_index(const particle_presentation::Material& material){
  return (material.punch_through?4:material.additive?2:0)|(material.two_sided?1:0);
 }
 uint64_t pipeline(EngineVar& device,int index,int64_t samples){
  auto& result=pipelines[static_cast<size_t>(index)];if(result)return result;
  auto raster=object_resource("RDPipelineRasterizationState");property(raster,"cull_mode",EngineVar::integer(index&1?0:1));
  auto multisample=object_resource("RDPipelineMultisampleState");property(multisample,"sample_count",EngineVar::integer(samples));
  auto depth=object_resource("RDPipelineDepthStencilState");property(depth,"enable_depth_test",EngineVar::boolean(!debug_no_depth));property(depth,"enable_depth_write",EngineVar::boolean((index&4)!=0));property(depth,"depth_compare_operator",EngineVar::integer(6));
  auto attachment=object_resource("RDPipelineColorBlendStateAttachment");property(attachment,"enable_blend",EngineVar::boolean(true));property(attachment,"src_color_blend_factor",EngineVar::integer(6));property(attachment,"dst_color_blend_factor",EngineVar::integer(index&2?1:7));property(attachment,"src_alpha_blend_factor",EngineVar::integer(1));property(attachment,"dst_alpha_blend_factor",EngineVar::integer(index&2?1:7));
  auto attachments=::array_empty();::method(attachments,"append",{attachment});auto blend=object_resource("RDPipelineColorBlendState");property(blend,"attachments",typed_array(attachments,GDEXTENSION_VARIANT_TYPE_OBJECT,"RDPipelineColorBlendStateAttachment"));
  auto constants=::array_empty();
  if(native_surface_output){
   const std::array<EngineVar,4> values{
    EngineVar::boolean((index&2)!=0),EngineVar::number(index&4?0.2f:alpha_discard),
    EngineVar::boolean(cx_records),EngineVar::boolean((index&6)==0)
   };
   for(int n=0;n<(cx_records?4:3);++n){
    auto value=object_resource("RDPipelineSpecializationConstant");
    property(value,"constant_id",EngineVar::integer(n));
    property(value,"value",values[n]);
    ::method(constants,"append",{value});
   }
  }
  result=rid_value(::method(device,"render_pipeline_create",{rid(shader),EngineVar::integer(framebuffer_format),EngineVar::integer(vertex_format),EngineVar::integer(5),raster,multisample,depth,blend,EngineVar::integer(0),EngineVar::integer(0),typed_array(constants,GDEXTENSION_VARIANT_TYPE_OBJECT,"RDPipelineSpecializationConstant")}));if(!result)throw std::runtime_error("Shared particle pipeline creation failed");return result;
 }
 uint64_t uniform(EngineVar& device,const std::shared_ptr<const particle_presentation::Material>& material){
  const auto found=uniforms.find(material->rid);if(found!=uniforms.end())return found->second.rid;
  Name rs("RenderingServer");auto server=global_singleton(rs.data);uint64_t texture=0;GDExtensionBool srgb=!native_surface_output;const GDExtensionConstTypePtr args[]={&material->rid,&srgb};ptrcall(texture_rd,server,args,&texture);if(!texture)throw std::runtime_error("Shared particle source texture is unavailable");
  auto entry=object_resource("RDUniform");property(entry,"uniform_type",EngineVar::integer(1));property(entry,"binding",EngineVar::integer(0));::method(entry,"add_id",{rid(sampler)});::method(entry,"add_id",{rid(texture)});auto list=::array_empty();::method(list,"append",{entry});auto fog=object_resource("RDUniform");property(fog,"uniform_type",EngineVar::integer(7));property(fog,"binding",EngineVar::integer(1));::method(fog,"add_id",{rid(fog_buffer)});::method(list,"append",{fog});auto result=rid_value(::method(device,"uniform_set_create",{typed_array(list,GDEXTENSION_VARIANT_TYPE_OBJECT,"RDUniform"),rid(shader),EngineVar::integer(0)}));if(!result)throw std::runtime_error("Shared particle texture binding creation failed");uniforms.emplace(material->rid,Uniform{material,result});return result;
 }
 bool has_soft_draw(){
  if(!alive.load()||error.load()||!native_surface_output||debug_no_depth||alpha_discard>=0.0f)return false;
  std::lock_guard<std::mutex> lock(mutex);
  return ready&&std::any_of(ready->ranges.begin(),ready->ranges.end(),[this](const auto& range){
   return range.count&&range.material&&(cx_records||!range.material->additive);
  });
 }
 uint64_t empty_sample(EngineVar& device,uint64_t& empty,bool volume){
  if(empty)return empty;
  auto format=object_resource("RDTextureFormat");
  property(format,"format",EngineVar::integer(99)); // DATA_FORMAT_R32_SFLOAT
  property(format,"usage_bits",EngineVar::integer(1)); // TEXTURE_USAGE_SAMPLING_BIT
  if(volume)property(format,"texture_type",EngineVar::integer(2)); // TEXTURE_TYPE_3D
  WritableBytes zero(4);std::memset(zero.data,0,4);
  auto data=::array_empty();::method(data,"append",{zero.publish()});
  empty=rid_value(::method(device,"texture_create",{format,object_resource("RDTextureView"),typed_array(data,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)}));
  if(!empty)throw std::runtime_error("Particle neutral sample texture allocation failed");
  return empty;
 }
 void upload_sun(GDExtensionObjectPtr rd,const EngineVar& sun){
  const int64_t length=uploaded_sun.size();
  const std::array<uint8_t,40*sizeof(float)> neutral{};
  const uint8_t* data=neutral.data();
  std::optional<Raw> packed;
  if(::has(sun,"uniforms")){
   auto value=::get(sun,"uniforms");
   if(value.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY||::size(value)!=length)throw std::runtime_error("CX particle sun fit payload has invalid layout");
   packed.emplace(value,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);
   data=packed_bytes_read(packed->data,0);
  }
  if(!std::memcmp(uploaded_sun.data(),data,length))return;
  WritableBytes bytes_to_upload(length);
  std::memcpy(bytes_to_upload.data,data,length);
  const int64_t offset=0;
  int64_t status=-1;
  const GDExtensionConstTypePtr args[]={&sun_buffer,&offset,&length,bytes_to_upload.raw};
  ptrcall(update,rd,args,&status);
  if(status)throw std::runtime_error("CX particle sun fit upload failed");
  std::memcpy(uploaded_sun.data(),data,length);
 }
 void bind_depth_source(EngineVar& device,GDExtensionObjectPtr rd,uint64_t source,uint64_t haze,std::array<uint64_t,4> sun,uint64_t omni_atlas){
  if(!source)source=empty_sample(device,empty_depth,false);
  if(cx_records){
   if(!haze)haze=empty_sample(device,empty_haze,true);
   for(auto& fit:sun)if(!fit)fit=empty_sample(device,empty_depth,false);
   if(!omni_atlas)omni_atlas=empty_sample(device,empty_depth,false);
  }
  if(depth_binding_valid(rd)){
   if(sampled_depth==source&&sampled_haze==haze&&sampled_sun==sun&&sampled_omni_atlas==omni_atlas)return;
   discard(rd,depth_set);
  }
  auto depth=object_resource("RDUniform");
  property(depth,"uniform_type",EngineVar::integer(1));
  property(depth,"binding",EngineVar::integer(0));
  ::method(depth,"add_id",{rid(sampler)});::method(depth,"add_id",{rid(source)});
  auto list=::array_empty();::method(list,"append",{depth});
  if(cx_records){
   auto atmosphere=object_resource("RDUniform");
   property(atmosphere,"uniform_type",EngineVar::integer(1)); // SAMPLER_WITH_TEXTURE
   property(atmosphere,"binding",EngineVar::integer(1));
   ::method(atmosphere,"add_id",{rid(haze_sampler)});::method(atmosphere,"add_id",{rid(haze)});
   ::method(list,"append",{atmosphere});
   for(size_t i=0;i<sun.size();++i){
    auto map=object_resource("RDUniform");
    property(map,"uniform_type",EngineVar::integer(1));
    property(map,"binding",EngineVar::integer(i<2?i+2:i+3));
    ::method(map,"add_id",{rid(sampler)});::method(map,"add_id",{rid(sun[i])});
    ::method(list,"append",{map});
   }
   auto fits=object_resource("RDUniform");
   property(fits,"uniform_type",EngineVar::integer(7));
   property(fits,"binding",EngineVar::integer(4));
   ::method(fits,"add_id",{rid(sun_buffer)});
   ::method(list,"append",{fits});
   auto local=object_resource("RDUniform");
   property(local,"uniform_type",EngineVar::integer(1));
   property(local,"binding",EngineVar::integer(7));
   ::method(local,"add_id",{rid(sampler)});::method(local,"add_id",{rid(omni_atlas)});
   ::method(list,"append",{local});
  }
  depth_set=rid_value(::method(device,"uniform_set_create",{typed_array(list,GDEXTENSION_VARIANT_TYPE_OBJECT,"RDUniform"),rid(shader),EngineVar::integer(1)}));
  if(!depth_set)throw std::runtime_error("Particle scene depth binding failed");
  sampled_depth=source;
  sampled_haze=haze;
  sampled_sun=sun;
  sampled_omni_atlas=omni_atlas;
 }
 void allocate_stream(EngineVar& device,GDExtensionObjectPtr rd,const particle_presentation::Packet& frame){
  discard(rd,record_set);
  discard(rd,index_buffer);
  discard(rd,buffer);
  capacity=std::max<int64_t>(1024,std::max(capacity*2,frame.count));
  // Keep the allocation on a complete quad even when it grew by doubling.
  capacity=(capacity+5)/6*6;
  auto length=EngineVar::integer(static_cast<int64_t>(frame.raster_bytes(capacity)));
  auto empty=WritableBytes(0).publish();
  auto flags=EngineVar::integer(0);
  if(cx_records){
   buffer=rid_value(::method(device,"storage_buffer_create",{length,empty,flags,flags}));
   index_buffer=rid_value(::method(device,"storage_buffer_create",{EngineVar::integer(capacity/6*4),empty,flags,flags}));
   if(!buffer||!index_buffer)throw std::runtime_error("CX particle record or draw order buffer allocation failed");
   cx_order.generation=-1;
  }else{
   buffer=rid_value(::method(device,"vertex_buffer_create",{length,empty,flags}));
   if(!buffer)throw std::runtime_error("Shared particle vertex buffer allocation failed");
   auto list=::array_empty();::method(list,"append",{rid(buffer)});
   buffers=typed_array(list,GDEXTENSION_VARIANT_TYPE_RID);
  }
  last_uploaded=-1;
 }
 void upload_cx_lighting(EngineVar& device,GDExtensionObjectPtr rd,EngineVar input){
  constexpr auto header=cx_particle::light_header_floats*sizeof(float);
  constexpr auto stride=cx_particle::light_record_floats*sizeof(float);
  if(!input.nil()&&input.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)
   throw std::runtime_error("CX particle lighting requires packed float records");
  int64_t length=input.nil() ? 0 : ::size(input);
  if(!length){
   if(uploaded_lights.size()==header&&std::all_of(uploaded_lights.begin(),uploaded_lights.end(),[](uint8_t v){return v==0;}))return;
   WritableBytes empty(header);
   std::memset(empty.data,0,header);
   input=empty.publish();
   length=header;
  }
  if(length<static_cast<int64_t>(header)||(length-header)%stride)
   throw std::runtime_error("CX particle light records have an invalid size");
  Raw packed(input,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);
  const auto* data=packed_bytes_read(packed.data,0);
  if(uploaded_lights.size()==static_cast<size_t>(length)&&!std::memcmp(uploaded_lights.data(),data,length))return;
  float count=0;
  std::memcpy(&count,data+header-sizeof(count),sizeof(count));
  if(count!=static_cast<float>((length-header)/stride))
   throw std::runtime_error("CX particle lighting count does not match its records");
  // Colors and the sun can change without invalidating the sphere lists.
  if(uploaded_lights.size()!=static_cast<size_t>(length))cluster_dirty=true;
  for(size_t offset=header;!cluster_dirty&&offset<static_cast<size_t>(length);offset+=stride){
   if(std::memcmp(uploaded_lights.data()+offset,data+offset,4*sizeof(float)))cluster_dirty=true;
  }
  if(static_cast<size_t>(length)>light_capacity){
   discard(rd,record_set);
   discard(rd,cluster_set);
   discard(rd,light_buffer);
   light_capacity=std::max(static_cast<size_t>(length),light_capacity*2);
   auto empty=WritableBytes(0).publish();
   auto flags=EngineVar::integer(0);
   light_buffer=rid_value(::method(device,"storage_buffer_create",{EngineVar::integer(light_capacity),empty,flags,flags}));
   if(!light_buffer)throw std::runtime_error("CX particle lighting buffer allocation failed");
  }
  const int64_t offset=0;
  int64_t status=-1;
  const GDExtensionConstTypePtr args[]={&light_buffer,&offset,&length,packed.data};
  ptrcall(update,rd,args,&status);
  if(status)throw std::runtime_error("CX particle lighting buffer upload failed");
  uploaded_lights.assign(data,data+length);
  last_point_lights.store(static_cast<int64_t>(count));
  light_upload_bytes.fetch_add(length);
 }
 bool has_omni_shadow_draw(){
  if(!cx_records||!alive.load())return false;
  std::shared_ptr<const particle_presentation::Packet> frame;
  {std::lock_guard<std::mutex> lock(mutex);frame=ready;}
  if(!frame||!frame->count||frame->cx_lighting.nil())return false;
  auto value=frame->cx_lighting;
  if(value.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY||::size(value)<48)return false;
  Raw packed(value,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);
  float count=0;
  std::memcpy(&count,packed_bytes_read(packed.data,0)+7*sizeof(float),sizeof(count));
  return count>0&&std::any_of(frame->ranges.begin(),frame->ranges.end(),[](const auto& range){
   return range.count&&range.material&&!range.material->additive&&!range.material->punch_through;
  });
 }
 uint64_t upload_cx_omni(EngineVar& device,GDExtensionObjectPtr rd,const EngineVar& shadow_inputs){
  constexpr size_t header=16,atlas_stride=96,record_stride=96,id_bytes=sizeof(uint64_t);
  constexpr size_t light_header=cx_particle::light_header_floats*sizeof(float);
  constexpr size_t light_stride=cx_particle::light_record_floats*sizeof(float);
  auto& next=staged_omni;
  next.assign(header,0);
  uint64_t atlas=0;
  if(::has(shadow_inputs,"omni_atlas")&&uploaded_lights.size()>=light_header){
   auto data=::get(shadow_inputs,"omni_atlas");
   auto rows=::get(data,"omni");
   if(rows.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY||::size(rows)%atlas_stride)throw std::runtime_error("CX omni shadow records have an invalid layout");
   const auto row_count=static_cast<size_t>(::size(rows))/atlas_stride;
   const auto light_count=static_cast<uint32_t>((uploaded_lights.size()-light_header)/light_stride);
   Raw packed(rows,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);
   const auto* shadow_data=row_count?packed_bytes_read(packed.data,0):nullptr;
   for(uint32_t index=0;index<light_count;++index){
    uint64_t id=0;
    std::memcpy(&id,uploaded_lights.data()+light_header+(index+1)*light_stride-id_bytes,id_bytes);
    if(!id)continue;
    for(size_t row=0;row<row_count;++row){
     const auto* shadow=shadow_data+row*atlas_stride;
     if(std::memcmp(&id,shadow,id_bytes))continue;
     if(next.size()==header)next.resize(header+light_count*record_stride);
     std::memcpy(next.data()+header+index*record_stride,shadow+id_bytes,atlas_stride-id_bytes);
     break;
    }
   }
   if(next.size()>header){
    atlas=rid_value(::get(data,"atlas"));
    if(atlas)std::memcpy(next.data(),&light_count,sizeof(light_count));
    else next.resize(header);
   }
  }
  if(next==uploaded_omni)return atlas;
  if(next.size()>omni_capacity){
   discard(rd,record_set);
   discard(rd,omni_buffer);
   omni_capacity=std::max(omni_capacity*2,next.size());
   auto flags=EngineVar::integer(0);
   omni_buffer=rid_value(::method(device,"storage_buffer_create",{EngineVar::integer(omni_capacity),WritableBytes(0).publish(),flags,flags}));
   if(!omni_buffer)throw std::runtime_error("CX omni shadow record buffer allocation failed");
  }
  WritableBytes packed(next.size());
  std::memcpy(packed.data,next.data(),next.size());
  const int64_t offset=0,length=static_cast<int64_t>(next.size());
  int64_t status=-1;
  const GDExtensionConstTypePtr args[]={&omni_buffer,&offset,&length,packed.raw};
  ptrcall(update,rd,args,&status);
  if(status)throw std::runtime_error("CX omni shadow records upload failed");
  uploaded_omni.swap(next);
  return atlas;
 }
 template<size_t N>uint64_t storage_binding(EngineVar& device,uint64_t program,int set,const std::array<uint64_t,N>& bindings){
  auto rows=::array_empty();
  for(size_t binding=0;binding<bindings.size();++binding){
   auto uniform=object_resource("RDUniform");
   property(uniform,"uniform_type",EngineVar::integer(8)); // UNIFORM_TYPE_STORAGE_BUFFER
   property(uniform,"binding",EngineVar::integer(binding));
   ::method(uniform,"add_id",{rid(bindings[binding])});
   ::method(rows,"append",{uniform});
  }
  return rid_value(::method(device,"uniform_set_create",{
   typed_array(rows,GDEXTENSION_VARIANT_TYPE_OBJECT,"RDUniform"),rid(program),EngineVar::integer(set)
  }));
 }
 void bind_cx_records(EngineVar& device){
  if(record_set)return;
  record_set=storage_binding(device,shader,2,std::array{buffer,index_buffer,light_buffer,cluster_buffer,omni_buffer});
  if(!record_set)throw std::runtime_error("CX particle record buffer binding failed");
 }
 void initialize_cluster(EngineVar& device){
  auto source=object_resource("RDShaderSource");
  auto compute_source=cx_particle::light_shader_prefix(0,0)+cx_particle::grid_shader;
  property(source,"source_compute",EngineVar::text(compute_source.c_str()));
  auto spirv=::method(device,"shader_compile_spirv_from_source",{source,EngineVar::boolean(true)});
  auto message=engine_string(::method(spirv,"get",{EngineVar::text("compile_error_compute")}));
  if(!message.empty())throw std::runtime_error(message);
  cluster_shader=rid_value(::method(device,"shader_create_from_spirv",{spirv,EngineVar::text("CX particle light grid")}));
  if(!cluster_shader)throw std::runtime_error("CX particle light-grid shader creation failed");
  cluster_pipeline=rid_value(::method(device,"compute_pipeline_create",{rid(cluster_shader),::array_empty()}));
  if(!cluster_pipeline)throw std::runtime_error("CX particle light-grid pipeline creation failed");
 }
 void build_cx_grid(EngineVar& device,GDExtensionObjectPtr rd,const WritableBytes& view,bool lit_draw){
  const auto count=static_cast<size_t>(last_point_lights.load());
  const auto needed=cx_particle::grid_bytes(lit_draw?count:0);
  if(needed>cluster_capacity){
   discard(rd,record_set);
   discard(rd,cluster_set);
   discard(rd,cluster_buffer);
   cluster_capacity=needed;
   auto flags=EngineVar::integer(0);
   cluster_buffer=rid_value(::method(device,"storage_buffer_create",{EngineVar::integer(needed),WritableBytes(0).publish(),flags,flags}));
   if(!cluster_buffer)throw std::runtime_error("CX particle light-grid allocation failed");
   cluster_dirty=true;
  }
  if(!lit_draw||!count)return;
  if(!cluster_dirty&&!std::memcmp(cluster_view.data(),view.data,cluster_view.size()))return;
  if(!cluster_pipeline)initialize_cluster(device);
  if(!cluster_set)cluster_set=storage_binding(device,cluster_shader,0,std::array{light_buffer,cluster_buffer});
  if(!cluster_set)throw std::runtime_error("CX particle light-grid binding failed");
  std::array<float,16> projection{};
  std::memcpy(projection.data(),view.data,sizeof(projection));
  // Godot uses reverse-Z. Recover the same view depths as the soft-particle
  // fragment shader, using the covered depth interval in clip space.
  const float near=(projection[15]-projection[14])/(projection[11]-projection[10]);
  const float far=projection[14]/projection[10];
  std::array<float,4> depth{};
  const bool axis_aligned=projection[1]==0&&projection[2]==0&&projection[3]==0
   &&projection[4]==0&&projection[6]==0&&projection[7]==0;
  if(axis_aligned&&near>0&&far>near&&std::isfinite(far)&&projection[0]!=0&&projection[5]!=0){
   const auto step=std::log(far/near)/cx_particle::grid_z;
   if(step>0&&std::isfinite(step))depth={near,far,step,1.0f/step};
  }
  WritableBytes params(128);
  std::memcpy(params.data,view.data,cluster_view.size());
  std::memcpy(params.data+cluster_view.size(),depth.data(),sizeof(depth));
  auto list=::method(device,"compute_list_begin");
  if(!list.integer())throw std::runtime_error("CX particle light-grid recording failed");
  ::method(device,"compute_list_bind_compute_pipeline",{list,rid(cluster_pipeline)});
  ::method(device,"compute_list_bind_uniform_set",{list,rid(cluster_set),EngineVar::integer(0)});
  ::method(device,"compute_list_set_push_constant",{list,params.publish(),EngineVar::integer(128)});
  ::method(device,"compute_list_dispatch",{list,EngineVar::integer((cx_particle::grid_cells+cx_particle::grid_group-1)/cx_particle::grid_group),EngineVar::integer(1),EngineVar::integer(1)});
  ::method(device,"compute_list_end");
  std::memcpy(cluster_view.data(),view.data,cluster_view.size());
  cluster_dirty=false;
  last_grid_cells.store(depth[0]>0?cx_particle::grid_cells:0);
  ++cluster_builds;
 }
 static V3 view_eye(const Raw& projection){
  std::array<float,16> transform{};
  std::memcpy(transform.data(),packed_bytes_read(projection.data,0)+64,64);
  const V3 x{transform[0],transform[1],transform[2]},y{transform[4],transform[5],transform[6]},
     z{transform[8],transform[9],transform[10]},t{transform[12],transform[13],transform[14]};
  const auto dot=[](const V3& a,const V3& b){return (a[0]*b[0]+a[1]*b[1])+a[2]*b[2];};
  const auto row0=cross(y,z),row1=cross(z,x),row2=cross(x,y);
  const auto determinant=dot(row0,x);
  if(!std::isfinite(determinant)||std::abs(determinant)<1e-12f)
   throw std::runtime_error("CX particle view transform is singular");
  return {-dot(row0,t)/determinant,-dot(row1,t)/determinant,-dot(row2,t)/determinant};
 }
 void upload_cx_order(GDExtensionObjectPtr rd,const particle_presentation::Packet& frame,const V3& eye){
  if(cx_order.generation==frame.generation&&(!cx_order.sorted_groups||cx_order.eye==eye))return;
  cx_order.build(frame,eye,batch_ranges);
  last_sorted_groups.store(static_cast<int64_t>(cx_order.sorted_groups));
  if(cx_order.indices.empty())return;
  const int64_t offset=0,length=static_cast<int64_t>(cx_order.indices.size()*sizeof(uint32_t));
  WritableBytes packed(static_cast<size_t>(length));
  std::memcpy(packed.data,cx_order.indices.data(),static_cast<size_t>(length));
  int64_t status=-1;
  const GDExtensionConstTypePtr args[]={&index_buffer,&offset,&length,packed.raw};
  ptrcall(update,rd,args,&status);
  if(status)throw std::runtime_error("CX particle draw order buffer upload failed");
  index_bytes.fetch_add(length);
 }
 void draw(EngineVar device,const EngineVar& framebuffer,const EngineVar& matrix,int64_t samples,uint64_t depth,uint64_t haze,const std::array<float,4>& haze_terms,const EngineVar& sun){
  last_draws.store(0);last_vertices.store(0);
  if(!alive.load()||error.load())return;std::shared_ptr<const particle_presentation::Packet> frame;{std::lock_guard<std::mutex> lock(mutex);frame=ready;}if(!frame||!frame->count||frame->ranges.empty())return;
  if(frame->native_surface_output!=native_surface_output)throw std::runtime_error("Shared particle frame and renderer use different color carriers");
  if(frame->cx_records!=cx_records)throw std::runtime_error("Particle frame and renderer use different geometry formats");
  for(const auto& range:frame->ranges)if(range.count&&(!range.material||!range.material->rid||(range.material->lighting&&!native_surface_output)))throw std::runtime_error("Shared raster candidate requires retained unlit or original CPU-tinted materials");
  if(samples<0||samples>6)throw std::runtime_error("Shared particle multisample mode is invalid");Raw projection(matrix,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);auto matrix_copy=matrix;if(::size(matrix_copy)!=128)throw std::runtime_error("Shared particle projection must contain projection and view matrices");
  GDExtensionObjectPtr rd=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&rd,device.data);Name server_name("RenderingServer");auto server=global_singleton(server_name.data);GDExtensionBool thread=false;ptrcall(particle_upload::is_render_thread,server,nullptr,&thread);if(!thread||!rd)throw std::runtime_error("Particle stream drawing requires the render thread");
  if(!shader)initialize(device);
  std::array<uint64_t,4> sun_depths{};
  if(cx_records){
   upload_sun(rd,sun);
   const std::array<const char*,4> names{"near","far","moving_near","moving_far"};
   for(size_t i=0;i<names.size();++i)if(::has(sun,names[i]))sun_depths[i]=rid_value(::get(sun,names[i]));
  }
  if(cx_records)upload_cx_lighting(device,rd,frame->cx_lighting);
  const uint64_t omni_atlas=cx_records?upload_cx_omni(device,rd,sun):0;
  if(native_surface_output)bind_depth_source(device,rd,depth,haze,sun_depths,omni_atlas);
  upload_fog(rd,*frame,haze_terms);
  const auto format=::method(device,"framebuffer_get_format",{framebuffer}).integer();if(format!=framebuffer_format||samples!=last_samples){for(auto& p:pipelines)discard(rd,p);framebuffer_format=format;last_samples=samples;}
  if(frame->count>capacity)allocate_stream(device,rd,*frame);
  if(last_uploaded!=frame->vertex_generation){Raw data(frame->vertices,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);const int64_t offset=0,length=static_cast<int64_t>(frame->raster_bytes(frame->count));int64_t status=-1;const GDExtensionConstTypePtr args[]={&buffer,&offset,&length,data.data};ptrcall(update,rd,args,&status);if(status)throw std::runtime_error("Shared particle buffer upload failed");last_uploaded=frame->vertex_generation;++uploads;bytes.fetch_add(length);if(debug_readback&&readback.empty()){auto actual=::method(device,"buffer_get_data",{rid(buffer),EngineVar::integer(0),EngineVar::integer(length)});auto expected=frame->vertices;auto a=::method(actual,"hex_encode"),b=::method(expected,"hex_encode");std::lock_guard<std::mutex> lock(mutex);readback=engine_string(a)==engine_string(b)?"exact":"mismatch";}}
  V3 eye{};
  if(cx_records){
   eye=view_eye(projection);
   upload_cx_order(rd,*frame,eye);
  }
  const auto& draw_ranges=cx_records?cx_order.draws:frame->ranges;
  // Resolve all cold pipeline/texture state before opening a draw list.
  for(const auto& range:draw_ranges)if(range.count){pipeline(device,pipeline_index(*range.material),samples);uniform(device,range.material);}
  std::optional<WritableBytes> record_push;
  std::optional<Raw> vertex_buffers,offsets;
  int64_t* offset=nullptr;
  if(cx_records){
   record_push.emplace(128);
   const auto* original=packed_bytes_read(projection.data,0);
   std::memcpy(record_push->data,original,64);
   for(size_t row=0;row<3;++row)for(size_t column=0;column<4;++column)
    std::memcpy(record_push->data+64+(row*4+column)*4,original+64+(column*4+row)*4,4);
   std::memcpy(record_push->data+116,eye.data(),12);
   const bool lit_draw=std::any_of(draw_ranges.begin(),draw_ranges.end(),[](const auto& range){
    return range.count&&!range.material->additive&&!range.material->punch_through;
   });
   build_cx_grid(device,rd,*record_push,lit_draw);
   bind_cx_records(device);
  }else{
   vertex_buffers.emplace(buffers,GDEXTENSION_VARIANT_TYPE_ARRAY);
   EngineVar offsets_variant;destroy(offsets_variant.data);GDExtensionCallError err{};
   construct(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,offsets_variant.data,nullptr,0,&err);
   ::method(offsets_variant,"resize",{EngineVar::integer(1)});
   offsets.emplace(offsets_variant,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY);
   offset=particle_counters::packed_write(offsets->data,0);
  }
  auto begin=::method(device,"draw_list_begin",{framebuffer,EngineVar::integer(0)});const auto list=begin.integer();struct End{GDExtensionObjectPtr rd;~End(){ptrcall(end_list,rd,nullptr,nullptr);}}end{rd};
  uint64_t bound_pipeline=0,bound_texture=0;int64_t frame_draws=0,frame_vertices=0;
  for(size_t at=0;at<draw_ranges.size();){const auto& range=draw_ranges[at++];if(!range.count)continue;const auto index=pipeline_index(*range.material);const auto p=pipelines[static_cast<size_t>(index)],texture=uniforms.at(range.material->rid).rid;int64_t count=range.count;
   // Preserve painter order and exact vertex coverage. Never join across a
   // hidden-source gap, zero range, sampler or pipeline-state boundary.
   if(batch_ranges&&!cx_records)while(at<draw_ranges.size()){const auto& next=draw_ranges[at];if(!next.count||next.first!=range.first+count||pipeline_index(*next.material)!=index||uniforms.at(next.material->rid).rid!=texture)break;count+=next.count;++at;}
   if(p!=bound_pipeline){
    const GDExtensionConstTypePtr args[]={&list,&p};ptrcall(bind_pipeline,rd,args,nullptr);
    bound_pipeline=p;bound_texture=0;
    if(cx_records){const int64_t set=2;const GDExtensionConstTypePtr record_args[]={&list,&record_set,&set};ptrcall(bind_uniform,rd,record_args,nullptr);}
    else{const int64_t length=128;const GDExtensionConstTypePtr constants[]={&list,projection.data,&length};ptrcall(push,rd,constants,nullptr);}
    if(native_surface_output){const int64_t set=1;const GDExtensionConstTypePtr depth_args[]={&list,&depth_set,&set};ptrcall(bind_uniform,rd,depth_args,nullptr);}
   }
   if(texture!=bound_texture){const int64_t set=0;const GDExtensionConstTypePtr args[]={&list,&texture,&set};ptrcall(bind_uniform,rd,args,nullptr);bound_texture=texture;}
   if(cx_records){
    const auto first=static_cast<uint32_t>(range.first);
    std::memcpy(record_push->data+112,&first,4);
    const int64_t length=128;const GDExtensionConstTypePtr constants[]={&list,record_push->raw,&length};ptrcall(push,rd,constants,nullptr);
   }else{
    *offset=range.first*24;
    const GDExtensionConstTypePtr vertex_args[]={&list,&vertex_format,&count,vertex_buffers->data,offsets->data};
    ptrcall(bind_vertices,rd,vertex_args,nullptr);
   }
   const GDExtensionBool indexed=false;const int64_t instances=1,procedural=cx_records?count:0;
   const GDExtensionConstTypePtr draw_args[]={&list,&indexed,&instances,&procedural};ptrcall(draw_vertices,rd,draw_args,nullptr);
   ++frame_draws;frame_vertices+=count;
  }draws.fetch_add(frame_draws);drawn_vertices.fetch_add(frame_vertices);last_draws.store(frame_draws);last_vertices.store(frame_vertices);generation.store(frame->generation);
 }
 EngineVar stats(){
  auto out=EngineVar::dictionary();
  ::set(out,"alive",EngineVar::boolean(alive.load()));::set(out,"error",EngineVar::integer(error.load()));
  ::set(out,"submissions",EngineVar::integer(submissions.load()));::set(out,"uploads",EngineVar::integer(uploads.load()));::set(out,"bytes",EngineVar::integer(bytes.load()));
  ::set(out,"draws",EngineVar::integer(draws.load()));::set(out,"vertices",EngineVar::integer(drawn_vertices.load()));
  ::set(out,"last_draws",EngineVar::integer(last_draws.load()));::set(out,"last_vertices",EngineVar::integer(last_vertices.load()));
  ::set(out,"native_surface_output",EngineVar::boolean(native_surface_output));::set(out,"batch_ranges",EngineVar::boolean(batch_ranges));::set(out,"generation",EngineVar::integer(generation.load()));
  if(cx_records){
   ::set(out,"index_upload_bytes",EngineVar::integer(index_bytes.load()));
   ::set(out,"last_sorted_groups",EngineVar::integer(last_sorted_groups.load()));
   ::set(out,"light_upload_bytes",EngineVar::integer(light_upload_bytes.load()));
   ::set(out,"last_point_lights",EngineVar::integer(last_point_lights.load()));
   ::set(out,"light_cluster_builds",EngineVar::integer(cluster_builds.load()));
   ::set(out,"light_cluster_cells",EngineVar::integer(last_grid_cells.load()));
  }
  std::lock_guard<std::mutex> lock(mutex);
  ::set(out,"pending",EngineVar::integer(static_cast<int64_t>(pending.size())));
  ::set(out,"failure",EngineVar::text(failure.c_str()));::set(out,"debug_readback",EngineVar::text(readback.c_str()));
  return out;
 }
};
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnParticleStreamRender");auto object=construct_object(base.data);auto owner=new Owner();owner->object=object;set_instance(object,name.data,owner);if(notify){EngineVar value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);::method(value,"notification",{EngineVar::integer(0)});}return object;}
void free(void*,GDExtensionClassInstancePtr instance){delete static_cast<Owner*>(instance);}
void dispatch(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,2,result,error))return;auto& owner=*static_cast<Owner*>(instance);try{EngineVar op(args[0]),input(args[1]);auto out=EngineVar::dictionary();switch(op.integer()){case 0:owner.configure(input);break;case 1:owner.submit();break;case 2:out=owner.stats();break;case 3:owner.cancel();break;default:throw std::runtime_error("Unknown particle stream render operation");}new_copy(result,out.data);}catch(const std::exception& err){auto out=EngineVar::dictionary();::set(out,"error",EngineVar::text(err.what()));new_copy(result,out.data);}}
void accept(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,2,result,error))return;auto& owner=*static_cast<Owner*>(instance);try{EngineVar sequence(args[1]);owner.accept(sequence.integer());}catch(const std::exception& err){owner.fail(err.what());}new_nil(result);}
void release(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,2,result,error))return;auto& owner=*static_cast<Owner*>(instance);try{owner.release();}catch(const std::exception& err){owner.fail(err.what());}new_nil(result);}
void draw(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 if(!particle_upload::count_ok(count,8,result,error))return;
 auto& owner=*static_cast<Owner*>(instance);
 try{
  EngineVar device(args[0]),framebuffer(args[1]),matrix(args[2]),samples(args[3]),depth(args[4]),haze(args[5]),terms(args[6]),sun(args[7]);
  if(terms.type()!=GDEXTENSION_VARIANT_TYPE_VECTOR4)throw std::runtime_error("CX rain haze requires four view sampling terms");
  std::array<float,4> values{};
  to[GDEXTENSION_VARIANT_TYPE_VECTOR4](values.data(),terms.data);
  owner.draw(device,framebuffer,matrix,samples.integer(),rid_value(depth),rid_value(haze),values,sun);
 }catch(const std::exception& err){owner.fail(err.what());}
 new_nil(result);
}
void has_soft_draw(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt,GDExtensionVariantPtr result,GDExtensionCallError*){auto& owner=*static_cast<Owner*>(instance);auto answer=EngineVar::boolean(owner.has_soft_draw());new_copy(result,answer.data);}
void has_omni_shadow_draw(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt,GDExtensionVariantPtr result,GDExtensionCallError*){
 auto answer=EngineVar::boolean(static_cast<Owner*>(instance)->has_omni_shadow_draw());new_copy(result,answer.data);
}
template<typename Property>void register_owner(const Property& p){
 if(!bind())return;Name name("NwnParticleStreamRender"),base("RefCounted"),empty("");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free;register_class(library,name.data,base.data,&info);registered=true;
 const auto method=[&](const char* label,GDExtensionClassMethodCall call,std::vector<GDExtensionPropertyInfo> args,bool returns,GDExtensionVariantType type=GDEXTENSION_VARIANT_TYPE_DICTIONARY){Name method_name(label);auto ret=p(type,empty);GDExtensionClassMethodArgumentMetadata metadata[8]{};GDExtensionClassMethodInfo m{};m.name=method_name.data;m.call_func=call;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.argument_count=static_cast<uint32_t>(args.size());m.arguments_info=args.data();m.arguments_metadata=metadata;m.has_return_value=returns;m.return_value_info=returns?&ret:nullptr;register_method(library,name.data,&m);};
 Name operation("operation"),input("input"),self("keepalive"),sequence("sequence"),rd("device"),framebuffer("framebuffer"),matrix("matrix"),samples("samples"),depth("depth"),haze("rain_haze"),haze_terms("rain_haze_terms"),sun("sun_shadow");
 method("dispatch",dispatch,{p(GDEXTENSION_VARIANT_TYPE_INT,operation),p(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)},true);
 const std::vector<GDExtensionPropertyInfo> callback{p(GDEXTENSION_VARIANT_TYPE_OBJECT,self),p(GDEXTENSION_VARIANT_TYPE_INT,sequence)};method("accept",accept,callback,false);method("release",release,callback,false);
 method("draw",draw,{p(GDEXTENSION_VARIANT_TYPE_OBJECT,rd),p(GDEXTENSION_VARIANT_TYPE_RID,framebuffer),p(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,matrix),p(GDEXTENSION_VARIANT_TYPE_INT,samples),p(GDEXTENSION_VARIANT_TYPE_RID,depth),p(GDEXTENSION_VARIANT_TYPE_RID,haze),p(GDEXTENSION_VARIANT_TYPE_VECTOR4,haze_terms),p(GDEXTENSION_VARIANT_TYPE_DICTIONARY,sun)},false);
 method("has_soft_draw",has_soft_draw,{},true,GDEXTENSION_VARIANT_TYPE_BOOL);
 method("has_omni_shadow_draw",has_omni_shadow_draw,{},true,GDEXTENSION_VARIANT_TYPE_BOOL);
}
void unregister_owner(){if(registered){Name name("NwnParticleStreamRender");unregister_class(library,name.data);registered=false;}}
} // namespace particle_stream_render
