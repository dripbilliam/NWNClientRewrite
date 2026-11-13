// Experimental compositor consumer. Main-thread submissions retain exact native
// packets; RenderingServer ordering publishes each packet on the render thread.
// No scene Node or presentation entry is inspected by a render callback.
namespace particle_stream_render {
bool registered=false;
GDExtensionMethodBindPtr bind_pipeline,bind_uniform,bind_vertices,draw_vertices,end_list,update,texture_rd,free_resource,push;
bool bind(){
 Name rd("RenderingDevice"),rs("RenderingServer");
 const auto method=[&](const char* name,int64_t hash){Name n(name);return class_method(rd.data,n.data,hash);};
 bind_pipeline=method("draw_list_bind_render_pipeline",4040184819);bind_uniform=method("draw_list_bind_uniform_set",749655778);bind_vertices=method("draw_list_bind_vertex_buffers_format",2008628980);draw_vertices=method("draw_list_draw",4230067973);end_list=method("draw_list_end",3218959716);update=method("buffer_update",3454956949);free_resource=method("free_rid",2722037293);
 push=method("draw_list_set_push_constant",2772371345);
 Name name("texture_get_rd_texture");texture_rd=class_method(rs.data,name.data,2790148051);
 return bind_pipeline&&bind_uniform&&bind_vertices&&draw_vertices&&end_list&&update&&texture_rd&&free_resource&&push;
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
 uint64_t shader=0,sampler=0,buffer=0,fog_buffer=0;int64_t capacity=0,vertex_format=0,framebuffer_format=-1,last_uploaded=-1,last_fog=-1,last_samples=-1;std::array<uint64_t,4> pipelines{};EngineVar buffers;bool debug_no_depth=false,debug_readback=false,native_surface_output=false,batch_ranges=false;float alpha_discard=-1;std::string readback;
 struct Uniform {std::shared_ptr<const particle_presentation::Material> material;uint64_t rid;};std::unordered_map<uint64_t,Uniform> uniforms;
 void configure(const EngineVar& input){
  if(!retained.nil()||!alive.load())throw std::runtime_error("Particle stream renderer configures once");auto source=::get(input,"presentation");if(source.type()!=GDEXTENSION_VARIANT_TYPE_OBJECT)throw std::runtime_error("Particle stream renderer requires native presentation");
  GDExtensionObjectPtr pointer=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&pointer,source.data);std::lock_guard<std::mutex> lock(particle_presentation::registry_mutex);auto found=particle_presentation::registry.find(pointer);if(found==particle_presentation::registry.end())throw std::runtime_error("Particle presentation is absent");retained=source;presentation=found->second;debug_no_depth=::has(input,"debug_no_depth")&&::get(input,"debug_no_depth").boolean();debug_readback=::has(input,"debug_readback")&&::get(input,"debug_readback").boolean();native_surface_output=::has(input,"native_surface_output")&&::get(input,"native_surface_output").boolean();
  if(::has(input,"alpha_discard")){alpha_discard=static_cast<float>(::get(input,"alpha_discard").number());if(!std::isfinite(alpha_discard))throw std::runtime_error("Particle alpha discard must be finite");}
  batch_ranges=::has(input,"batch_ranges")?::get(input,"batch_ranges").boolean():native_surface_output;
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
 void release(){
  Name name("RenderingServer");auto server=global_singleton(name.data);GDExtensionObjectPtr rd=nullptr;GDExtensionBool thread=false;ptrcall(particle_upload::is_render_thread,server,nullptr,&thread);if(!thread)throw std::runtime_error("Particle stream release requires render thread");ptrcall(particle_upload::get_device,server,nullptr,&rd);
  if(rd){for(auto& row:uniforms)discard(rd,row.second.rid);uniforms.clear();for(auto& pipeline:pipelines)discard(rd,pipeline);discard(rd,buffer);discard(rd,fog_buffer);discard(rd,sampler);discard(rd,shader);}buffers=EngineVar();
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
layout(set=0,binding=1,std140) uniform SceneFog{vec4 color_density;vec4 depth;} scene_fog;
layout(push_constant,std430) uniform Params{mat4 projection;mat4 view;} params;
void main(){vec4 view=params.view*vec4(position_in,1.0);gl_Position=params.projection*view;
fog_amount=scene_fog.depth.w==3.0?(-view.z-scene_fog.depth.x)*scene_fog.depth.z:0.0;tint=color_in;uv=uv_in;}
)glsl"));
   property(source,"source_fragment",EngineVar::text(R"glsl(#version 450
layout(location=0) in vec4 tint;layout(location=1) in vec2 uv;layout(location=2) in float fog_amount;
layout(set=0,binding=0) uniform sampler2D original_texture;
layout(set=0,binding=1,std140) uniform SceneFog{vec4 color_density;vec4 depth;} scene_fog;
layout(constant_id=0) const bool additive=false;layout(constant_id=1) const float alpha_discard=-1.0;
layout(location=0) out vec4 result;
void main(){result=texture(original_texture,uv)*tint;if(alpha_discard>=0.0&&result.a<=alpha_discard)discard;
float amount=clamp(fog_amount,0.0,1.0);if(additive)result.a*=1.0-amount;else result.rgb=mix(result.rgb,scene_fog.color_density.rgb,amount);}
)glsl"));
  }
  auto spirv=::method(device,"shader_compile_spirv_from_source",{source,EngineVar::boolean(true)});
  for(const char* property_name:{"compile_error_vertex","compile_error_fragment"}){auto message=::method(spirv,"get",{EngineVar::text(property_name)});if(!engine_string(message).empty())throw std::runtime_error(engine_string(message));}
  shader=rid_value(::method(device,"shader_create_from_spirv",{spirv,EngineVar::text("NWN shared particle stream")}));if(!shader)throw std::runtime_error("Shared particle shader creation failed");
  auto fog_data=WritableBytes(32).publish();fog_buffer=rid_value(::method(device,"uniform_buffer_create",{EngineVar::integer(32),fog_data,EngineVar::integer(0)}));if(!fog_buffer)throw std::runtime_error("Shared particle fog buffer allocation failed");
  auto state=object_resource("RDSamplerState");for(const char* p:{"mag_filter","min_filter","mip_filter"})property(state,p,EngineVar::integer(1));for(const char* p:{"repeat_u","repeat_v","repeat_w"})property(state,p,EngineVar::integer(0));sampler=rid_value(::method(device,"sampler_create",{state}));
  auto attributes=::array_empty();const std::array<int64_t,3> formats{36,105,102},offsets{0,4,16};for(size_t i=0;i<3;++i){auto attribute=object_resource("RDVertexAttribute");property(attribute,"binding",EngineVar::integer(0));property(attribute,"location",EngineVar::integer(static_cast<int64_t>(i)));property(attribute,"format",EngineVar::integer(formats[i]));property(attribute,"offset",EngineVar::integer(offsets[i]));property(attribute,"stride",EngineVar::integer(24));::method(attributes,"append",{attribute});}
  vertex_format=::method(device,"vertex_format_create",{typed_array(attributes,GDEXTENSION_VARIANT_TYPE_OBJECT,"RDVertexAttribute")}).integer();
 }
 static EngineVar object_resource(const char* name){return particle_stream_render::object(name);}
 uint64_t pipeline(EngineVar& device,int index,int64_t samples){
  auto& result=pipelines[static_cast<size_t>(index)];if(result)return result;
  auto raster=object_resource("RDPipelineRasterizationState");property(raster,"cull_mode",EngineVar::integer(index&1?0:1));
  auto multisample=object_resource("RDPipelineMultisampleState");property(multisample,"sample_count",EngineVar::integer(samples));
  auto depth=object_resource("RDPipelineDepthStencilState");property(depth,"enable_depth_test",EngineVar::boolean(!debug_no_depth));property(depth,"enable_depth_write",EngineVar::boolean(false));property(depth,"depth_compare_operator",EngineVar::integer(6));
  auto attachment=object_resource("RDPipelineColorBlendStateAttachment");property(attachment,"enable_blend",EngineVar::boolean(true));property(attachment,"src_color_blend_factor",EngineVar::integer(6));property(attachment,"dst_color_blend_factor",EngineVar::integer(index&2?1:7));property(attachment,"src_alpha_blend_factor",EngineVar::integer(1));property(attachment,"dst_alpha_blend_factor",EngineVar::integer(index&2?1:7));
  auto attachments=::array_empty();::method(attachments,"append",{attachment});auto blend=object_resource("RDPipelineColorBlendState");property(blend,"attachments",typed_array(attachments,GDEXTENSION_VARIANT_TYPE_OBJECT,"RDPipelineColorBlendStateAttachment"));
  auto constants=::array_empty();if(native_surface_output){for(int n=0;n<2;++n){auto value=object_resource("RDPipelineSpecializationConstant");property(value,"constant_id",EngineVar::integer(n));property(value,"value",n==0?EngineVar::boolean((index&2)!=0):EngineVar::number(alpha_discard));::method(constants,"append",{value});}}
  result=rid_value(::method(device,"render_pipeline_create",{rid(shader),EngineVar::integer(framebuffer_format),EngineVar::integer(vertex_format),EngineVar::integer(5),raster,multisample,depth,blend,EngineVar::integer(0),EngineVar::integer(0),typed_array(constants,GDEXTENSION_VARIANT_TYPE_OBJECT,"RDPipelineSpecializationConstant")}));if(!result)throw std::runtime_error("Shared particle pipeline creation failed");return result;
 }
 uint64_t uniform(EngineVar& device,const std::shared_ptr<const particle_presentation::Material>& material){
  const auto found=uniforms.find(material->rid);if(found!=uniforms.end())return found->second.rid;
  Name rs("RenderingServer");auto server=global_singleton(rs.data);uint64_t texture=0;GDExtensionBool srgb=!native_surface_output;const GDExtensionConstTypePtr args[]={&material->rid,&srgb};ptrcall(texture_rd,server,args,&texture);if(!texture)throw std::runtime_error("Shared particle source texture is unavailable");
  auto entry=object_resource("RDUniform");property(entry,"uniform_type",EngineVar::integer(1));property(entry,"binding",EngineVar::integer(0));::method(entry,"add_id",{rid(sampler)});::method(entry,"add_id",{rid(texture)});auto list=::array_empty();::method(list,"append",{entry});auto fog=object_resource("RDUniform");property(fog,"uniform_type",EngineVar::integer(7));property(fog,"binding",EngineVar::integer(1));::method(fog,"add_id",{rid(fog_buffer)});::method(list,"append",{fog});auto result=rid_value(::method(device,"uniform_set_create",{typed_array(list,GDEXTENSION_VARIANT_TYPE_OBJECT,"RDUniform"),rid(shader),EngineVar::integer(0)}));if(!result)throw std::runtime_error("Shared particle texture binding creation failed");uniforms.emplace(material->rid,Uniform{material,result});return result;
 }
 void draw(EngineVar device,const EngineVar& framebuffer,const EngineVar& matrix,int64_t samples){
  last_draws.store(0);last_vertices.store(0);
  if(!alive.load()||error.load())return;std::shared_ptr<const particle_presentation::Packet> frame;{std::lock_guard<std::mutex> lock(mutex);frame=ready;}if(!frame||!frame->count||frame->ranges.empty())return;
  if(frame->native_surface_output!=native_surface_output)throw std::runtime_error("Shared particle frame and renderer use different color carriers");
  for(const auto& range:frame->ranges)if(range.count&&(!range.material||!range.material->rid||(range.material->lighting&&!native_surface_output)))throw std::runtime_error("Shared raster candidate requires retained unlit or original CPU-tinted materials");
  if(samples<0||samples>6)throw std::runtime_error("Shared particle multisample mode is invalid");Raw projection(matrix,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);auto matrix_copy=matrix;if(::size(matrix_copy)!=128)throw std::runtime_error("Shared particle projection must contain projection and view matrices");
  GDExtensionObjectPtr rd=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&rd,device.data);Name server_name("RenderingServer");auto server=global_singleton(server_name.data);GDExtensionBool thread=false;ptrcall(particle_upload::is_render_thread,server,nullptr,&thread);if(!thread||!rd)throw std::runtime_error("Particle stream drawing requires the render thread");
  if(!shader)initialize(device);
  if(last_fog!=frame->generation){WritableBytes bytes_data(32);std::memcpy(bytes_data.data,frame->fog.data(),32);auto values=bytes_data.publish();Raw data(values,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);const int64_t offset=0,length=32;int64_t status=-1;const GDExtensionConstTypePtr args[]={&fog_buffer,&offset,&length,data.data};ptrcall(update,rd,args,&status);if(status)throw std::runtime_error("Shared particle scene fog upload failed");last_fog=frame->generation;}
  const auto format=::method(device,"framebuffer_get_format",{framebuffer}).integer();if(format!=framebuffer_format||samples!=last_samples){for(auto& p:pipelines)discard(rd,p);framebuffer_format=format;last_samples=samples;}
  if(frame->count>capacity){discard(rd,buffer);capacity=std::max<int64_t>(1024,std::max(capacity*2,frame->count));auto empty=WritableBytes(0).publish();buffer=rid_value(::method(device,"vertex_buffer_create",{EngineVar::integer(capacity*24),empty,EngineVar::integer(0)}));if(!buffer)throw std::runtime_error("Shared particle vertex buffer allocation failed");auto list=::array_empty();::method(list,"append",{rid(buffer)});buffers=typed_array(list,GDEXTENSION_VARIANT_TYPE_RID);last_uploaded=-1;}
  if(last_uploaded!=frame->vertex_generation){Raw data(frame->vertices,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);const int64_t offset=0,length=frame->count*24;int64_t status=-1;const GDExtensionConstTypePtr args[]={&buffer,&offset,&length,data.data};ptrcall(update,rd,args,&status);if(status)throw std::runtime_error("Shared particle vertex buffer upload failed");last_uploaded=frame->vertex_generation;++uploads;bytes.fetch_add(length);if(debug_readback&&readback.empty()){auto actual=::method(device,"buffer_get_data",{rid(buffer),EngineVar::integer(0),EngineVar::integer(length)});auto expected=frame->vertices;auto a=::method(actual,"hex_encode"),b=::method(expected,"hex_encode");std::lock_guard<std::mutex> lock(mutex);readback=engine_string(a)==engine_string(b)?"exact":"mismatch";}}
  // Resolve all cold pipeline/texture state before opening a draw list.
  for(const auto& range:frame->ranges)if(range.count){pipeline(device,(range.material->additive?2:0)|(range.material->two_sided?1:0),samples);uniform(device,range.material);}
  auto begin=::method(device,"draw_list_begin",{framebuffer,EngineVar::integer(0)});const auto list=begin.integer();struct End{GDExtensionObjectPtr rd;~End(){ptrcall(end_list,rd,nullptr,nullptr);}}end{rd};
  Raw vertex_buffers(buffers,GDEXTENSION_VARIANT_TYPE_ARRAY);EngineVar offsets_variant;destroy(offsets_variant.data);GDExtensionCallError err{};construct(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,offsets_variant.data,nullptr,0,&err);::method(offsets_variant,"resize",{EngineVar::integer(1)});Raw offsets(offsets_variant,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY);auto* offset=particle_counters::packed_write(offsets.data,0);
  uint64_t bound_pipeline=0,bound_texture=0;int64_t frame_draws=0,frame_vertices=0;
  for(size_t at=0;at<frame->ranges.size();){const auto& range=frame->ranges[at++];if(!range.count)continue;const auto index=(range.material->additive?2:0)|(range.material->two_sided?1:0);const auto p=pipelines[static_cast<size_t>(index)],texture=uniforms.at(range.material->rid).rid;int64_t count=range.count;
   // Preserve painter order and exact vertex coverage. Never join across a
   // hidden-source gap, zero range, sampler or pipeline-state boundary.
   if(batch_ranges)while(at<frame->ranges.size()){const auto& next=frame->ranges[at];if(!next.count||next.first!=range.first+count||((next.material->additive?2:0)|(next.material->two_sided?1:0))!=index||uniforms.at(next.material->rid).rid!=texture)break;count+=next.count;++at;}
   if(p!=bound_pipeline){const GDExtensionConstTypePtr args[]={&list,&p};ptrcall(bind_pipeline,rd,args,nullptr);bound_pipeline=p;bound_texture=0;const int64_t length=128;const GDExtensionConstTypePtr constants[]={&list,projection.data,&length};ptrcall(push,rd,constants,nullptr);}
   if(texture!=bound_texture){const int64_t set=0;const GDExtensionConstTypePtr args[]={&list,&texture,&set};ptrcall(bind_uniform,rd,args,nullptr);bound_texture=texture;}
   *offset=range.first*24;const GDExtensionConstTypePtr vertex_args[]={&list,&vertex_format,&count,vertex_buffers.data,offsets.data};ptrcall(bind_vertices,rd,vertex_args,nullptr);
   const GDExtensionBool indexed=false;const int64_t instances=1,procedural=0;const GDExtensionConstTypePtr draw_args[]={&list,&indexed,&instances,&procedural};ptrcall(draw_vertices,rd,draw_args,nullptr);++frame_draws;frame_vertices+=count;
  }draws.fetch_add(frame_draws);drawn_vertices.fetch_add(frame_vertices);last_draws.store(frame_draws);last_vertices.store(frame_vertices);generation.store(frame->generation);
 }
 EngineVar stats(){auto out=EngineVar::dictionary();::set(out,"alive",EngineVar::boolean(alive.load()));::set(out,"error",EngineVar::integer(error.load()));::set(out,"submissions",EngineVar::integer(submissions.load()));::set(out,"uploads",EngineVar::integer(uploads.load()));::set(out,"bytes",EngineVar::integer(bytes.load()));::set(out,"draws",EngineVar::integer(draws.load()));::set(out,"vertices",EngineVar::integer(drawn_vertices.load()));::set(out,"last_draws",EngineVar::integer(last_draws.load()));::set(out,"last_vertices",EngineVar::integer(last_vertices.load()));::set(out,"native_surface_output",EngineVar::boolean(native_surface_output));::set(out,"batch_ranges",EngineVar::boolean(batch_ranges));::set(out,"generation",EngineVar::integer(generation.load()));{std::lock_guard<std::mutex> lock(mutex);::set(out,"pending",EngineVar::integer(static_cast<int64_t>(pending.size())));::set(out,"failure",EngineVar::text(failure.c_str()));::set(out,"debug_readback",EngineVar::text(readback.c_str()));}return out;}
};
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnParticleStreamRender");auto object=construct_object(base.data);auto owner=new Owner();owner->object=object;set_instance(object,name.data,owner);if(notify){EngineVar value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);::method(value,"notification",{EngineVar::integer(0)});}return object;}
void free(void*,GDExtensionClassInstancePtr instance){delete static_cast<Owner*>(instance);}
void dispatch(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,2,result,error))return;auto& owner=*static_cast<Owner*>(instance);try{EngineVar op(args[0]),input(args[1]);auto out=EngineVar::dictionary();switch(op.integer()){case 0:owner.configure(input);break;case 1:owner.submit();break;case 2:out=owner.stats();break;case 3:owner.cancel();break;default:throw std::runtime_error("Unknown particle stream render operation");}new_copy(result,out.data);}catch(const std::exception& err){auto out=EngineVar::dictionary();::set(out,"error",EngineVar::text(err.what()));new_copy(result,out.data);}}
void accept(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,2,result,error))return;auto& owner=*static_cast<Owner*>(instance);try{EngineVar sequence(args[1]);owner.accept(sequence.integer());}catch(const std::exception& err){owner.fail(err.what());}new_nil(result);}
void release(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,2,result,error))return;auto& owner=*static_cast<Owner*>(instance);try{owner.release();}catch(const std::exception& err){owner.fail(err.what());}new_nil(result);}
void draw(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,4,result,error))return;auto& owner=*static_cast<Owner*>(instance);try{EngineVar device(args[0]),framebuffer(args[1]),matrix(args[2]),samples(args[3]);owner.draw(device,framebuffer,matrix,samples.integer());}catch(const std::exception& err){owner.fail(err.what());}new_nil(result);}
template<typename Property>void register_owner(const Property& p){
 if(!bind())return;Name name("NwnParticleStreamRender"),base("RefCounted"),empty("");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free;register_class(library,name.data,base.data,&info);registered=true;
 const auto method=[&](const char* label,GDExtensionClassMethodCall call,std::vector<GDExtensionPropertyInfo> args,bool returns){Name method_name(label);auto ret=p(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);GDExtensionClassMethodArgumentMetadata metadata[4]{};GDExtensionClassMethodInfo m{};m.name=method_name.data;m.call_func=call;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.argument_count=static_cast<uint32_t>(args.size());m.arguments_info=args.data();m.arguments_metadata=metadata;m.has_return_value=returns;m.return_value_info=returns?&ret:nullptr;register_method(library,name.data,&m);};
 Name operation("operation"),input("input"),self("keepalive"),sequence("sequence"),rd("device"),framebuffer("framebuffer"),matrix("matrix"),samples("samples");method("dispatch",dispatch,{p(GDEXTENSION_VARIANT_TYPE_INT,operation),p(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)},true);const std::vector<GDExtensionPropertyInfo> callback{p(GDEXTENSION_VARIANT_TYPE_OBJECT,self),p(GDEXTENSION_VARIANT_TYPE_INT,sequence)};method("accept",accept,callback,false);method("release",release,callback,false);method("draw",draw,{p(GDEXTENSION_VARIANT_TYPE_OBJECT,rd),p(GDEXTENSION_VARIANT_TYPE_RID,framebuffer),p(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,matrix),p(GDEXTENSION_VARIANT_TYPE_INT,samples)},false);
}
void unregister_owner(){if(registered){Name name("NwnParticleStreamRender");unregister_class(library,name.data);registered=false;}}
} // namespace particle_stream_render
