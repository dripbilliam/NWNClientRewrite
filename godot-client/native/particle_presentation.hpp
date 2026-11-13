// Experimental scene presentation owner. The accepted per-emitter renderer is
// unchanged. All admitted emitters simulate before any geometry is generated;
// active quads write directly into one immutable, 24-byte-stride frame packet.
// Native rendering-device submission is a separate, still-unaccepted stage.
namespace particle_presentation {
using NativeOwner=resident::Owner;
using Clock=std::chrono::steady_clock;
#include "particle_frame_sampler.hpp"
bool registered=false;
struct Material {EngineVar texture;uint64_t rid=0;bool additive=false,two_sided=false,lighting=false;};
struct Owner;
std::mutex registry_mutex;std::unordered_map<GDExtensionObjectPtr,Owner*> registry;
struct Controls {
 std::string clip;float time=0,delta=0;int64_t source_flags=-1;
 bool culling=true,draw_enabled=true,detonate=false,profile=false,original_admission=false,animate=true,childless_chunk_admission=false;
 uint64_t wind_token=0,terrain_index=0,static_index=0;bool direct_scene=false;
 EngineVar patch;float explicit_radius=-1;
};
struct Step {
 NativeOwner* owner=nullptr;const EngineVar* providers=nullptr;Controls controls;EnginePose pose;
 std::optional<NativeOwner::View> camera;
 bool prepared=false,culled=false,checked=false,animation_invoked=false,updated=false;float radius=0;int chunk_proof=0;
 uint64_t direct_queries=0,direct_hits=0;double controls_ms=0,pose_ms=0,admission_ms=0,simulation_ms=0,geometry_ms=0,collision_ms=0;
 void context(resident::Context& value){
  value.state=&owner->state;value.providers=providers;value.allocations=&owner->allocations;value.camera=camera?&camera->position:nullptr;value.native_pose=&pose;
  value.profile=controls.profile;value.missing_chunks=&owner->missing_chunks;value.wind_token=(owner->compact_state.flags&4)?controls.wind_token:0;value.direct_scene=controls.direct_scene;value.terrain_index=controls.terrain_index;value.static_index=controls.static_index;
 }
 void advance(NativeOwner& value,const EngineVar& services,const std::optional<NativeOwner::View>& view,size_t& reject_plane){
  if(!value.configured||!value.compact_records||!value.typed_frame||!value.pose_id)throw std::runtime_error("Native presentation requires a configured typed owner with native poses");
  owner=&value;providers=&services;camera=view;prepared=false;culled=false;checked=false;animation_invoked=false;updated=false;radius=0;chunk_proof=0;direct_queries=direct_hits=0;controls_ms=pose_ms=admission_ms=simulation_ms=geometry_ms=collision_ms=0;
  resident::FieldKeyScope fields(owner->field_keys);auto phase=controls.profile?Clock::now():Clock::time_point{};
  const auto finish=[&](double& duration){if(controls.profile){const auto now=Clock::now();duration=std::chrono::duration<double,std::milli>(now-phase).count();phase=now;}};
  owner->sample(controls.clip,controls.time);finish(controls_ms);
  if(!controls.patch.nil()){
   auto names=::method(controls.patch,"keys");for(int64_t n=0;n<::size(names);++n){const auto name=engine_string(::at(names,n));resident::set(owner->state,name.c_str(),resident::Var(::get(controls.patch,name.c_str())));resident::compact_particle::apply_emitter_field(owner->compact_state,owner->state,{name.c_str(),resident::field_index(name.c_str())});}
  }
  if(owner->use_parameters&&owner->parameter_has(resident::hot_parameters::DETONATE)&&owner->parameter_integer(resident::hot_parameters::DETONATE)!=0){resident::set(owner->state,particle_field::detonate108,owner->parameter_get(resident::hot_parameters::DETONATE));owner->compact_state.detonate108=static_cast<int32_t>(owner->parameter_integer(resident::hot_parameters::DETONATE));resident::set_int(owner->parameters,"detonate",0);}
  if(controls.detonate){resident::set_int(owner->state,particle_field::detonate108,1);owner->compact_state.detonate108=1;}
  pose=owner->read_pose();const auto source=owner->source_id==owner->pose_id?pose:owner->read_pose(true);
  auto& emitter=owner->compact_state;if(!emitter.source.present)throw std::runtime_error("Native owner record required");
  emitter.source.position=source.position;emitter.source.quaternion=source.quaternion;emitter.source.adjustedScale=source.scale;owner->typed_source_pose=true;
  if(std::abs(emitter.birthRate)>32768||owner->allocations>32768)throw std::runtime_error("Native particle instance exceeds explicit allocation limit");finish(pose_ms);
  resident::Context ctx;context(ctx);resident::ContextScope scope(ctx);
  if(emitter.flags&4){if(!controls.wind_token)throw std::runtime_error("Native scene wind token is absent");scene_wind::owner(controls.wind_token);}
  const auto* wind=ctx.wind_token?&scene_wind::owner(ctx.wind_token):nullptr;
  const bool known_wind=!wind||wind->points.empty();
  if(controls.childless_chunk_admission&&emitter.chunk&&known_wind&&camera&&controls.culling&&controls.source_flags>=0)chunk_proof=owner->childless_chunk_proof();
  const bool childless=chunk_proof==1||chunk_proof==2;
  checked=known_wind&&(!emitter.chunk||childless)&&camera&&controls.culling&&controls.source_flags>=0;
  if(checked){
   if(controls.original_admission){
    radius=controls.explicit_radius>=0?controls.explicit_radius:owner->radius(controls.source_flags,wind?wind->wind:V3{})*std::max(1.0f,pose.maximum_scale);
    // Native leaf admission tests cached radius+20c and tries the previous
    // rejecting plane first. The caller owns broad-phase leaf membership.
    if(std::isfinite(radius)&&radius>=0){const V3 point{pose.position[0],pose.position[2],-pose.position[1]};for(size_t n=0;n<6;++n){const auto index=(reject_plane+n)%6,at=index*4;const auto& p=camera->planes;const float distance=((point[0]*p[at]-p[at+3])+point[1]*p[at+1])+point[2]*p[at+2];if(distance-radius>0){culled=true;reject_plane=index;break;}}}
   }else culled=owner->culled(*camera,pose.position,controls.source_flags,std::max(1.0f,pose.maximum_scale),radius,wind?wind->wind:V3{});
  }
  finish(admission_ms);
  if(!culled&&controls.animate){
   animation_invoked=true;updated=!((emitter.source.present&&emitter.source.instance.present&&1>emitter.source.instance.fade)||(emitter.instance.present&&1>emitter.instance.fade));
   resident::compact_particle::Bridge bridge(owner->state,owner->compact_extras);
   resident::compact_particle::animate(emitter,owner->compact_pool,controls.delta,pose.position,pose.quaternion,owner->kind,bridge);owner->typed_simulated=true;
  }
  finish(simulation_ms);direct_queries=ctx.direct_queries;direct_hits=ctx.direct_hits;collision_ms=ctx.collision_ms;prepared=true;
 }
 int64_t vertices()const{
  const auto& emitter=owner->compact_state;if(!prepared||culled||emitter.chunk||!controls.draw_enabled)return 0;
  const auto count=static_cast<int64_t>(owner->compact_pool.active.size())-(emitter.renderMode1a8==3?1:0);
  const bool faded=(emitter.source.present&&emitter.source.instance.present&&1>emitter.source.instance.fade)||(emitter.instance.present&&1>emitter.instance.fade);
  if(count<1||emitter.lifeExp==0||faded)return 0;if(count>32768)throw std::runtime_error("Native compact vertex allocation limit");return count*6;
 }
 void geometry(::ParticleStreams::DirectRange& target,const V3& tint=V3{1,1,1}){
  if(!prepared||culled)throw std::runtime_error("Native presentation geometry requires an admitted update");
  resident::FieldKeyScope fields(owner->field_keys);resident::Context ctx;context(ctx);resident::ContextScope scope(ctx);const auto began=controls.profile?Clock::now():Clock::time_point{};
  if(owner->compact_state.chunk){resident::compact_particle::Bridge bridge(owner->state,owner->compact_extras);resident::compact_particle::render_chunks(owner->compact_state,owner->compact_pool,bridge);}
  else{
   const resident::compact_particle::Draw draw{owner->compact_state.source.adjustedScale,camera?camera->camera:Q4{1,0,0,0},tint};
   ::ParticleStreams::DirectScope range(owner->staging,target);resident::compact_particle::build(owner->compact_state,owner->compact_pool,draw,&owner->staging,0);
  }
  if(controls.profile)geometry_ms=std::chrono::duration<double,std::milli>(Clock::now()-began).count();
 }
};
struct Entry {
 int64_t id=0;EngineVar retained,providers,clock,fallback,readiness;uint8_t clock_route=0;NativeOwner* owner=nullptr;Controls controls;Step step;
 std::shared_ptr<const Material> material;
 bool enabled=true,source_animating=false;double elapsed=0,clip_length=0;std::string static_clip;uint64_t source_key=0;int16_t node_order=0;float distance=0;
 int64_t frames=0,culling_checks=0,culled_frames=0,culling_fallbacks=0,peak_active=0,published_vertices=0,direct_queries=0,direct_hits=0;
};
struct Range {int64_t id=0,first=0,count=0;float distance=0;V3 minimum{},maximum{};bool chunk=false;std::shared_ptr<const Material> material;};
struct SceneSpan {int64_t id=0,first=0,count=0;};
struct SceneBytes {
 alignas(8) uint8_t raw[16]{};int64_t length=0;
 explicit SceneBytes(const EngineVar& value){if(value.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)throw std::runtime_error("Native scene source is not packed bytes");to[GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY](raw,const_cast<uint8_t*>(value.data));auto retained=value;length=::size(retained);}
 ~SceneBytes(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(raw);}
 int64_t size()const{return length;}
 const uint8_t* data()const{return packed_bytes_read(raw,0);}
 SceneBytes(const SceneBytes&)=delete;
};
struct SceneBatch {EngineVar instances;std::shared_ptr<const Material> material;std::vector<SceneSpan> spans;int64_t count=0;V3 minimum{},maximum{};};
struct Packet {EngineVar vertices;std::vector<Range> ranges;std::vector<SceneBatch> scene_batches;int64_t count=0,generation=0,vertex_generation=0,visible_vertices=0,scene_vertices=0;bool native_surface_output=false;std::array<float,8> fog{0,0,0,0,0,1,1,0};};
// Read at the original per-emitter boundary: a preceding callback can mutate
// this Dictionary. One keyed read preserves absent versus explicit nil.
bool animation_enabled(const EngineVar& common,const EngineVar* bound_key=nullptr){
 EngineVar value;destroy(value.data);GDExtensionBool present=false;get_keyed(common.data,bound_key ? bound_key->data : ::key("animating").data,value.data,&present);return !present||value.boolean();
}
struct Owner {
 FrameSampler sampler;FrameSampler::Invocation* sampling_context=nullptr;bool setup_boundary=false;uint64_t animating_key_binds=0,clock_validity_dispatches=0,static_noncallable_uses=0,static_null_callable_uses=0;
 GDExtensionObjectPtr identity=nullptr;
 std::unordered_map<int64_t,std::unique_ptr<Entry>> entries;std::vector<int64_t> order;
 std::vector<Entry*> frame_entries;bool order_dirty=true;
 void refresh_order(){
  if(!order_dirty)return;std::vector<Entry*> next;next.reserve(order.size());for(const auto id:order)next.push_back(entries.at(id).get());frame_entries.swap(next);order_dirty=false;
 }std::shared_ptr<const Packet> packet,canonical_packet;
 EngineVar retained_counters;particle_counters::Owner* counters=nullptr;
 bool closed=false,running=false;int64_t generation=0;size_t reject_plane=0;int64_t prepared=0,culled=0,active=0,fallbacks=0;
 void bind_counters(const EngineVar& input){
  if(running||closed)throw std::runtime_error("Native counter binding requires an open frame boundary");auto value=::get(input,"counters");if(value.type()!=GDEXTENSION_VARIANT_TYPE_OBJECT)throw std::runtime_error("Native presentation requires native counters");GDExtensionObjectPtr pointer=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&pointer,value.data);std::lock_guard<std::mutex> lock(particle_counters::registry_mutex);auto found=particle_counters::registry.find(pointer);if(found==particle_counters::registry.end())throw std::runtime_error("Native particle counters are absent");retained_counters=value;counters=found->second;
 }
 void add(const EngineVar& config){
  if(closed||running)throw std::runtime_error("Native presentation registration requires an open frame boundary");const auto id=::get(config,"id").integer();if(entries.find(id)!=entries.end())throw std::runtime_error("Native presentation identity is already registered");
  order_dirty=true;auto entry=std::make_unique<Entry>();entry->id=id;
  if(!::has(config,"owner")||::get(config,"owner").nil()){
   entry->fallback=::get(config,"fallback");if(!particle_frame_group::valid_callable(entry->fallback))throw std::runtime_error("Native presentation fallback requires a callable");entries.emplace(id,std::move(entry));order.push_back(id);control(config);return;
  }
  entry->retained=::get(config,"owner");entry->providers=::get(config,"providers");
  if(entry->retained.type()!=GDEXTENSION_VARIANT_TYPE_OBJECT)throw std::runtime_error("Native presentation owner is not an object");GDExtensionObjectPtr object=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&object,entry->retained.data);
  {std::lock_guard<std::mutex> guard(resident::owner_registry_mutex);auto found=resident::owner_registry.find(object);if(found!=resident::owner_registry.end())entry->owner=found->second;}
  if(!entry->owner||!entry->owner->configured||!entry->owner->compact_records||!entry->owner->typed_frame||!entry->owner->pose_id)throw std::runtime_error("Native presentation requires a configured typed owner with native poses");
  for(const auto& current:entries)if(current.second->owner==entry->owner)throw std::runtime_error("Native presentation requires private emitter owners");
  entry->source_key=entry->owner->source_id;if(::has(config,"source_key"))entry->source_key=static_cast<uint64_t>(::get(config,"source_key").integer());
  if(::has(config,"node_order"))entry->node_order=static_cast<int16_t>(::get(config,"node_order").integer());
  if(::has(config,"clip"))entry->static_clip=engine_string(::get(config,"clip"));entry->controls.clip=entry->static_clip;
  if(::has(config,"clip_length"))entry->clip_length=::get(config,"clip_length").number();if(::has(config,"clock")){entry->clock=::get(config,"clock");entry->clock_route=setup_clock_route::classify(entry->clock);}
  if(::has(config,"ready")){entry->readiness=::get(config,"ready");if(!particle_frame_group::valid_callable(entry->readiness))throw std::runtime_error("Native particle readiness requires a callable");}
  if(::has(config,"elapsed"))entry->elapsed=::get(config,"elapsed").number();entries.emplace(id,std::move(entry));order.push_back(id);control(config);
 }
 void control(const EngineVar& config){
  if(running)throw std::runtime_error("Native presentation controls require a frame boundary");auto found=entries.find(::get(config,"id").integer());if(found==entries.end())return;auto& entry=*found->second;auto& c=entry.controls;
  if(::has(config,"enabled"))entry.enabled=::get(config,"enabled").boolean();if(::has(config,"culling"))c.culling=::get(config,"culling").boolean();if(::has(config,"draw_enabled"))c.draw_enabled=::get(config,"draw_enabled").boolean();
  if(::has(config,"childless_chunk_admission"))c.childless_chunk_admission=::get(config,"childless_chunk_admission").boolean();
  if(::has(config,"source_flags"))c.source_flags=::get(config,"source_flags").integer();if(::has(config,"wind_token"))c.wind_token=static_cast<uint64_t>(::get(config,"wind_token").integer());
  if(::has(config,"patch")){auto patch=::get(config,"patch");c.patch=::method(patch,"duplicate",{EngineVar::boolean(true)});}if(::has(config,"detonate")&&::get(config,"detonate").boolean())c.detonate=true;
  if(::has(config,"original_admission"))c.original_admission=::get(config,"original_admission").boolean();if(::has(config,"admission_radius"))c.explicit_radius=::f(config,"admission_radius");
  if(::has(config,"clock")){entry.clock=::get(config,"clock");entry.clock_route=setup_clock_route::classify(entry.clock);}
  if(::has(config,"source_animating"))entry.source_animating=::get(config,"source_animating").boolean();
  if(::has(config,"texture")){
   auto material=std::make_shared<Material>();material->texture=::get(config,"texture");
   if(material->texture.type()!=GDEXTENSION_VARIANT_TYPE_OBJECT)throw std::runtime_error("Particle draw material requires a Texture2D");
   GDExtensionObjectPtr texture=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&texture,material->texture.data);Name texture_name("Texture2D");
   if(!texture||!cast_object(texture,class_tag(texture_name.data)))throw std::runtime_error("Particle draw material requires a Texture2D");
   auto rid=::method(material->texture,"get_rid");to[GDEXTENSION_VARIANT_TYPE_RID](&material->rid,rid.data);
   material->additive=::has(config,"additive")&&::get(config,"additive").boolean();material->two_sided=::has(config,"two_sided")&&::get(config,"two_sided").boolean();material->lighting=::has(config,"lighting")&&::get(config,"lighting").boolean();entry.material=std::move(material);
  }
 }
 void erase(int64_t id){if(running)throw std::runtime_error("Native presentation removal requires a frame boundary");order_dirty=true;frame_entries.clear();entries.erase(id);order.erase(std::remove(order.begin(),order.end(),id),order.end());}
 void set_order(const EngineVar& input){
  if(running)throw std::runtime_error("Native presentation order requires a frame boundary");auto ids=::get(input,"ids");if(::size(ids)!=static_cast<int64_t>(entries.size()))throw std::runtime_error("Native presentation order must cover every identity");std::vector<int64_t> next;std::unordered_map<int64_t,bool> seen;
  for(int64_t n=0;n<::size(ids);++n){const auto id=::at(ids,n).integer();if(entries.find(id)==entries.end()||!seen.emplace(id,true).second)throw std::runtime_error("Native presentation order has an absent or duplicate identity");next.push_back(id);}order=std::move(next);order_dirty=true;
 }
 static bool less(const Entry* a,const Entry* b){
  if(a->distance<=b->distance){if(a->distance<b->distance)return true;if(a->source_key&&a->source_key==b->source_key)return a->node_order<b->node_order;}return false;
 }
 void sparse_phase(size_t index){auto* invocation=sampling_context;if(sampler.coarse_phases&&invocation&&invocation->profile_seen&&!invocation->profile){invocation->points[index]=Clock::now();invocation->phase_mask|=uint32_t(1)<<index;++sampler.phase_clock_reads;}}
 EngineVar frame(const EngineVar& common){
  if(closed||running)throw std::runtime_error("Native presentation is closed or already running");struct Scope{bool& value;explicit Scope(bool& next):value(next){value=true;}~Scope(){value=false;}}scope(running);
  const bool native_surface_output=::has(common,"native_surface_output")&&::get(common,"native_surface_output").boolean();
  emitter_lighting::Snapshot lighting;const bool sampled_lighting=native_surface_output&&::has(common,"lighting");if(sampled_lighting)lighting.load(::get(common,"lighting"));if(sampler.coarse_phases&&sampling_context)sampling_context->lighting_rows=static_cast<uint64_t>(lighting.lights.size());
  packet.reset();prepared=culled=active=fallbacks=0;const auto delta=::get(common,"delta").number();const bool profile=::has(common,"profile")&&::get(common,"profile").boolean();if(sampling_context){sampling_context->profile_seen=true;sampling_context->profile=profile;}
  if(::has(common,"initial_reject_plane")){const auto index=::get(common,"initial_reject_plane").integer();if(index<0||index>=6)throw std::runtime_error("Native presentation reject plane is invalid");reject_plane=static_cast<size_t>(index);}
  std::optional<NativeOwner::View> camera;if(::has(common,"view"))camera=NativeOwner::view(::get(common,"view"));if(!camera)throw std::runtime_error("Native presentation requires a complete camera packet");
  bool direct_scene=false;uint64_t terrain=0,statics=0;if(::has(common,"scene_indices")){auto ids=::get(common,"scene_indices");if(::size(ids)!=2)throw std::runtime_error("Native particle scene requires two group identities");terrain=static_cast<uint64_t>(::at(ids,0).integer());statics=static_cast<uint64_t>(::at(ids,1).integer());direct_scene=true;}
  sparse_phase(0);
  std::array<double,3> boundary_ms{};
  std::array<double,7> phases{};const auto loop_begin=profile?Clock::now():Clock::time_point{};
  const EngineVar* animating_key=nullptr;
  refresh_order();std::vector<Entry*> drawing;drawing.reserve(entries.size());
  for(auto* current:frame_entries){auto& entry=*current;const auto id=entry.id;
   const auto eligibility_begin=profile?Clock::now():Clock::time_point{};
   bool direct_eligible=false,direct_source_exists=false,bypass_boundary=false;
   const bool fused=!profile&&entry.enabled&&entry.owner&&particle_scene_boundary::eligible_source(id,entry.owner->source_id,direct_eligible,direct_source_exists,bypass_boundary);
   if(!entry.enabled||!(fused?direct_eligible:particle_frame_group::eligible(id,!bypass_boundary))){if(profile)boundary_ms[0]+=std::chrono::duration<double,std::milli>(Clock::now()-eligibility_begin).count();continue;}
   if(profile)boundary_ms[0]+=std::chrono::duration<double,std::milli>(Clock::now()-eligibility_begin).count();
   if(!entry.owner){if(sampler.coarse_phases&&sampling_context)++sampling_context->fallbacks;::method(entry.fallback,"call",{EngineVar::number(delta)});++fallbacks;continue;}
   const auto source_begin=profile?Clock::now():Clock::time_point{};
   const bool source_exists=fused?direct_source_exists:instance_from_id(entry.owner->source_id)!=nullptr;
   if(profile)boundary_ms[1]+=std::chrono::duration<double,std::milli>(Clock::now()-source_begin).count();
   if(!source_exists)continue;
   // Chunk templates arrive asynchronously. Match the established early
   // return (no time/RNG/physics advance), then discard this cold probe once
   // ready. Ready effects have no per-emitter script readiness callback.
   if(!entry.readiness.nil()){if(sampler.coarse_phases&&sampling_context)++sampling_context->readiness;if(!::method(entry.readiness,"call").boolean())continue;entry.readiness=EngineVar();}
   entry.elapsed+=delta;auto& next=entry.step.controls;next=entry.controls;next.delta=static_cast<float>(delta);next.profile=profile;next.clip=entry.static_clip;if(setup_boundary&&!animating_key){animating_key=&::key("animating");++animating_key_binds;}next.animate=animation_enabled(common,animating_key)||(entry.source_key&&entry.source_animating);double time=entry.elapsed;
   const auto clock_begin=profile?Clock::now():Clock::time_point{};
   bool actor_clock=false;if(!setup_boundary||entry.clock_route==2){++clock_validity_dispatches;actor_clock=particle_frame_group::valid_callable(entry.clock);}else if(entry.clock_route==1)++static_null_callable_uses;else ++static_noncallable_uses;
   if(actor_clock){if(sampler.coarse_phases&&sampling_context)++sampling_context->clocks;auto sampled=::method(entry.clock,"call");if(sampled.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Native presentation clock must return a dictionary");next.clip=::has(sampled,"clip")?engine_string(::get(sampled,"clip")):"";time=::has(sampled,"time")?::get(sampled,"time").number():0;}
   else if(entry.clip_length>0){time=std::fmod(time,entry.clip_length);if(time<0)time+=entry.clip_length;}
   if(profile)boundary_ms[2]+=std::chrono::duration<double,std::milli>(Clock::now()-clock_begin).count();
   next.time=static_cast<float>(time);next.direct_scene=direct_scene;next.terrain_index=terrain;next.static_index=statics;
   entry.step.advance(*entry.owner,entry.providers,camera,reject_plane);entry.controls.patch=EngineVar();entry.controls.detonate=false;++prepared;
   if(profile){phases[1]+=entry.step.controls_ms;phases[2]+=entry.step.pose_ms;phases[3]+=entry.step.admission_ms;phases[4]+=entry.step.simulation_ms;}
   entry.direct_queries+=static_cast<int64_t>(entry.step.direct_queries);entry.direct_hits+=static_cast<int64_t>(entry.step.direct_hits);
   if(entry.step.checked)++entry.culling_checks;else if(next.culling)++entry.culling_fallbacks;
   if(entry.step.culled){++entry.culled_frames;++culled;continue;}++entry.frames;entry.published_vertices=entry.step.vertices();
   active+=static_cast<int64_t>(entry.owner->compact_pool.active.size());entry.peak_active=std::max(entry.peak_active,static_cast<int64_t>(entry.owner->compact_pool.active.size()));
   if(!entry.owner->compact_pool.active.empty()){const auto& point=entry.source_key?entry.owner->compact_state.source.position:entry.step.pose.position;const auto d=subtract(camera->position,point);entry.distance=(d[0]*d[0]+d[1]*d[1])+d[2]*d[2];drawing.push_back(&entry);}
  }
  sparse_phase(1);
  const auto packing_begin=profile?Clock::now():Clock::time_point{};if(profile)phases[0]=std::chrono::duration<double,std::milli>(packing_begin-loop_begin).count()-phases[1]-phases[2]-phases[3]-phases[4];
  // Match the original's separate sorted drawing pass. The original partial
  // equal-distance comparator/sort must be checked against its captured corpus.
  particle_native_sort::sort(drawing,less);
  const bool scene_instances=!native_surface_output&&::has(common,"scene_instances")&&::get(common,"scene_instances").boolean();
  int64_t total=0,all_vertices=0;for(const auto* entry:drawing){const auto count=entry->step.vertices();if(count>16777216-all_vertices)throw std::runtime_error("Native shared particle frame exceeds explicit allocation limit");all_vertices+=count;if(!scene_instances||!entry->material||!entry->material->lighting)total+=count;}
  WritableBytes bytes(static_cast<size_t>(total)*24);auto next=std::make_shared<Packet>();next->count=total;next->visible_vertices=total;next->generation=++generation;next->vertex_generation=next->generation;next->ranges.reserve(drawing.size());int64_t offset=0;
  next->native_surface_output=native_surface_output;
  if(::has(common,"fog")){auto fog=::get(common,"fog");if(::size(fog)!=8)throw std::runtime_error("Native particle fog requires eight finite scene values");for(int64_t n=0;n<8;++n){const auto value=static_cast<float>(::at(fog,n).number());if(!std::isfinite(value))throw std::runtime_error("Native particle fog contains a nonfinite scene value");next->fog[static_cast<size_t>(n)]=value;}const float mode=next->fog[7];if(next->native_surface_output?(mode!=0&&mode!=3):(mode!=0&&mode!=1&&mode!=2))throw std::runtime_error("Native particle fog mode does not match its color carrier");}
  // Preserve sorted range order. Only consecutive equal scene materials are
  // combined, with a new shard before the existing MultiMesh capacity limit.
  std::vector<int64_t> scene_for_entry(drawing.size(),-1);int64_t current_scene=-1;
  if(scene_instances)for(size_t n=0;n<drawing.size();++n){const auto* entry=drawing[n];const auto count=entry->step.vertices();if(!count)continue;const auto& material=entry->material;if(!material||!material->lighting){current_scene=-1;continue;}
   const auto equal=[&](const SceneBatch& batch){return batch.material->rid==material->rid&&batch.material->additive==material->additive&&batch.material->two_sided==material->two_sided&&batch.count+count<=196608;};
   if(current_scene<0||!equal(next->scene_batches[static_cast<size_t>(current_scene)])){current_scene=static_cast<int64_t>(next->scene_batches.size());SceneBatch batch;batch.material=material;next->scene_batches.push_back(std::move(batch));}scene_for_entry[n]=current_scene;next->scene_batches[static_cast<size_t>(current_scene)].count+=count;next->scene_vertices+=count;
  }
  std::vector<std::unique_ptr<WritableBytes>> scene_bytes;std::vector<int64_t> scene_offsets(next->scene_batches.size(),0);for(const auto& batch:next->scene_batches)scene_bytes.push_back(std::make_unique<WritableBytes>(static_cast<size_t>(batch.count/6)*80));
  for(size_t n=0;n<drawing.size();++n){auto* entry=drawing[n];const auto count=entry->step.vertices();if(!entry->owner->compact_state.chunk&&!entry->controls.draw_enabled)continue;
   V3 tint{1,1,1};if(native_surface_output&&count&&((entry->owner->compact_state.flags&8)!=0)){if(!sampled_lighting)throw std::runtime_error("Original lit particles require a CPU lighting snapshot");tint=lighting.sample(entry->owner->compact_state.position1e0);}
   if(scene_for_entry[n]>=0){const auto index=static_cast<size_t>(scene_for_entry[n]);auto& batch=next->scene_batches[index];auto& written=scene_offsets[index];::ParticleStreams::DirectRange target{scene_bytes[index]->data+static_cast<size_t>(written/6)*80,count,0,true};entry->step.geometry(target);if(profile)phases[5]+=entry->step.geometry_ms;if(target.written!=count)throw std::runtime_error("Native scene instance range is incomplete");
    const auto& a=entry->owner->staging.minimum;const auto& b=entry->owner->staging.maximum;if(!written){batch.minimum=a;batch.maximum=b;}else for(size_t axis=0;axis<3;++axis){batch.minimum[axis]=std::min(batch.minimum[axis],a[axis]);batch.maximum[axis]=std::max(batch.maximum[axis],b[axis]);}batch.spans.push_back({entry->id,written,count});written+=count;continue;
   }
   ::ParticleStreams::DirectRange target{count?bytes.data+static_cast<size_t>(offset)*24:nullptr,count};entry->step.geometry(target,tint);if(profile)phases[5]+=entry->step.geometry_ms;
   if(!entry->owner->compact_state.chunk&&target.written!=count)throw std::runtime_error("Native shared particle range is incomplete");
   Range range{entry->id,offset,count,entry->distance,entry->owner->staging.minimum,entry->owner->staging.maximum,entry->owner->compact_state.chunk,entry->material};next->ranges.push_back(range);offset+=count;
  }
  if(offset!=total)throw std::runtime_error("Native shared particle frame count mismatch");for(size_t n=0;n<scene_bytes.size();++n){if(scene_offsets[n]!=next->scene_batches[n].count)throw std::runtime_error("Native scene batch count mismatch");next->scene_batches[n].instances=scene_bytes[n]->publish();}next->vertices=bytes.publish();canonical_packet=next;packet=std::move(next);
  sparse_phase(2);
  const auto counters_begin=profile?Clock::now():Clock::time_point{};
  if(counters)for(const auto* current:frame_entries){const auto& entry=*current;const auto id=entry.id;if(!entry.owner)continue;
   // A chunk callback may retire a scene node during this frame. Membership
   // removal is deferred, while its fixed counter record is removed now.
   if(counters->entries.find(id)==counters->entries.end())continue;
   const auto simulated=static_cast<int64_t>(entry.frames>0);const std::array<int64_t,particle_counters::fields> values{simulated,static_cast<int64_t>(entry.owner->compact_pool.active.size()),entry.published_vertices,0,simulated,0,simulated,0,entry.owner->constant_hits,entry.owner->sampled_channels,entry.culling_checks,entry.culled_frames,static_cast<int64_t>(entry.culled_frames>0),static_cast<int64_t>(entry.step.culled),entry.culling_fallbacks};if(!counters->store(id,values.data()))throw std::runtime_error("Native presentation counters are closed");}
  sparse_phase(3);
  auto result=summary();if(profile){auto measured=EngineVar::dictionary();
   const std::array<const char*,7> names{"particle_native_eligibility_clock_ms","particle_native_controls_ms","particle_native_pose_ms","particle_native_admission_ms","particle_native_simulation_ms","particle_native_geometry_ms","particle_native_pack_sort_ms"};
   phases[6]=std::chrono::duration<double,std::milli>(counters_begin-packing_begin).count()-phases[5];
   for(size_t n=0;n<phases.size();++n)::set(measured,names[n],EngineVar::number(phases[n]));
   ::set(measured,"particle_native_eligibility_checks_ms",EngineVar::number(boundary_ms[0]));
   ::set(measured,"particle_native_source_checks_ms",EngineVar::number(boundary_ms[1]));
   ::set(measured,"particle_native_clock_boundary_ms",EngineVar::number(boundary_ms[2]));
   ::set(measured,"particle_native_other_loop_ms",EngineVar::number(phases[0]-boundary_ms[0]-boundary_ms[1]-boundary_ms[2]));
   ::set(measured,"particle_native_counters_summary_ms",EngineVar::number(std::chrono::duration<double,std::milli>(Clock::now()-counters_begin).count()));::set(result,"phases",measured);
  }return result;
 }
 EngineVar summary()const{auto out=EngineVar::dictionary();::set(out,"registered",EngineVar::integer(static_cast<int64_t>(entries.size())));::set(out,"prepared",EngineVar::integer(prepared));::set(out,"fallbacks",EngineVar::integer(fallbacks));::set(out,"culled",EngineVar::integer(culled));::set(out,"active",EngineVar::integer(active));::set(out,"vertices",EngineVar::integer(packet?packet->visible_vertices+packet->scene_vertices:0));::set(out,"scene_vertices",EngineVar::integer(packet?packet->scene_vertices:0));::set(out,"scene_batches",EngineVar::integer(packet?static_cast<int64_t>(packet->scene_batches.size()):0));::set(out,"bytes",EngineVar::integer(packet?packet->count*24+packet->scene_vertices/6*80:0));::set(out,"draws",EngineVar::integer(packet?static_cast<int64_t>(packet->ranges.size()+packet->scene_batches.size()):0));::set(out,"generation",EngineVar::integer(generation));::set(out,"closed",EngineVar::boolean(closed));return out;}
 EngineVar refresh_visibility(){
  if(closed||running)throw std::runtime_error("Native visibility publication requires an open main-thread frame boundary");
  if(!canonical_packet)return summary();
  // Borrow immutable geometry from the last complete simulation frame. Never
  // sample controls, advance clocks/RNG/physics, or invoke geometry callbacks.
  const auto& source=*canonical_packet;auto next=std::make_shared<Packet>();
  next->vertices=source.vertices;next->count=source.count;next->vertex_generation=source.vertex_generation;next->fog=source.fog;next->native_surface_output=source.native_surface_output;
  std::unordered_map<int64_t,bool> visibility;
  const auto shown=[&](int64_t id){auto cached=visibility.find(id);if(cached!=visibility.end())return cached->second;const auto entry=entries.find(id);const bool value=entry!=entries.end()&&entry->second->enabled&&particle_frame_group::visible(id);visibility.emplace(id,value);return value;};
  for(const auto& range:source.ranges)if(shown(range.id)){next->ranges.push_back(range);next->visible_vertices+=range.count;}
  for(const auto& batch:source.scene_batches){
   int64_t count=0;for(const auto& span:batch.spans)if(shown(span.id))count+=span.count;if(!count)continue;
   SceneBatch visible;visible.material=batch.material;visible.count=count;visible.minimum=batch.minimum;visible.maximum=batch.maximum;
   if(count==batch.count){visible.instances=batch.instances;visible.spans=batch.spans;}
   else{
    SceneBytes bytes(batch.instances);if(bytes.size()!=batch.count/6*80)throw std::runtime_error("Native visibility scene source length is invalid");
    WritableBytes selected(static_cast<size_t>(count/6)*80);int64_t written=0;
    for(const auto& span:batch.spans)if(shown(span.id)){
     if(span.first<0||span.count<0||span.first%6||span.count%6||span.first+span.count>batch.count)throw std::runtime_error("Native visibility scene source range is invalid");
     std::memcpy(selected.data+static_cast<size_t>(written/6)*80,bytes.data()+static_cast<size_t>(span.first/6)*80,static_cast<size_t>(span.count/6)*80);
     visible.spans.push_back({span.id,written,span.count});written+=span.count;
    }
    if(written!=count)throw std::runtime_error("Native visibility scene publication is incomplete");visible.instances=selected.publish();
   }
   next->scene_vertices+=count;next->scene_batches.push_back(std::move(visible));
  }
  next->generation=++generation;packet=std::move(next);return summary();
 }
 EngineVar scene_frame()const{
  // Internal render consumer: these immutable packed arrays are borrowed
  // read-only and retained by queued GPU uploads. Cold inspect() never exposes
  // this storage for mutation and therefore needs no per-frame deep copy.
  auto out=EngineVar::dictionary();::set(out,"generation",EngineVar::integer(packet?packet->generation:0));auto rows=::array_empty();
  if(packet)for(const auto& batch:packet->scene_batches){auto row=EngineVar::dictionary();const auto key=std::to_string(batch.material->rid)+":"+(batch.material->additive?"1":"0")+(batch.material->two_sided?"1":"0");::set(row,"material_key",EngineVar::text(key.c_str()));::set(row,"texture",batch.material->texture);::set(row,"additive",EngineVar::boolean(batch.material->additive));::set(row,"two_sided",EngineVar::boolean(batch.material->two_sided));::set(row,"count",EngineVar::integer(batch.count));::set(row,"buffer",batch.instances);::set(row,"bounds",::array(std::array<float,6>{batch.minimum[0],batch.minimum[1],batch.minimum[2],batch.maximum[0]-batch.minimum[0],batch.maximum[1]-batch.minimum[1],batch.maximum[2]-batch.minimum[2]}));::method(rows,"append",{row});}::set(out,"batches",rows);return out;
 }
 void configure_sampler(const EngineVar& input){
  if(closed||running)throw std::runtime_error("Frame sampler/setup changes require an open frame boundary");
  if(input.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Sparse frame sampler requires a dictionary");
  const bool next_setup=::has(input,"setup_boundary")?::get(input,"setup_boundary").boolean():setup_boundary;
  const bool reset=::has(input,"reset")&&::get(input,"reset").boolean();sampler.configure(input);setup_boundary=next_setup;if(reset)animating_key_binds=clock_validity_dispatches=static_noncallable_uses=static_null_callable_uses=0;
 }
 EngineVar sampler_info()const{
  auto out=sampler.inspect();::set(out,"setup_boundary",EngineVar::boolean(setup_boundary));::set(out,"animating_key_binds",EngineVar::integer(static_cast<int64_t>(animating_key_binds)));::set(out,"clock_validity_dispatches",EngineVar::integer(static_cast<int64_t>(clock_validity_dispatches)));::set(out,"static_noncallable_uses",EngineVar::integer(static_cast<int64_t>(static_noncallable_uses)));::set(out,"static_null_callable_uses",EngineVar::integer(static_cast<int64_t>(static_null_callable_uses)));int64_t routes[3]{};for(const auto& pair:entries)if(pair.second->owner)++routes[pair.second->clock_route];::set(out,"compiled_noncallable_entries",EngineVar::integer(routes[0]));::set(out,"compiled_null_callable_entries",EngineVar::integer(routes[1]));::set(out,"live_callable_entries",EngineVar::integer(routes[2]));return out;
 }
 EngineVar timed_frame(const EngineVar& input){
  if(!sampler.enabled||!sampler.select(entries.size()))return frame(input);
  FrameSampler::Invocation invocation;auto* previous=sampling_context;sampling_context=&invocation;auto* previous_external=resident::external_call_counts;if(sampler.coarse_phases)resident::external_call_counts=&invocation.external;
  struct Restore{FrameSampler::Invocation*& slot;FrameSampler::Invocation* previous;resident::ExternalCallCounts* previous_external;~Restore(){slot=previous;resident::external_call_counts=previous_external;}}restore{sampling_context,previous,previous_external};
  FrameSampler::Sample sample;sample.call=sampler.calls;sample.setup=setup_boundary;sample.boundary=particle_scene_boundary::enabled;const auto began=Clock::now();
  const auto finish=[&](bool success){const auto ended=Clock::now();sample.wall_ms=std::chrono::duration<double,std::milli>(ended-began).count();sample.success=success;sample.phase_complete=invocation.phase_mask==15;if(sample.phase_complete){auto prior=began;for(size_t index=0;index<4;++index){sample.phases[index]=std::chrono::duration<double,std::milli>(invocation.points[index]-prior).count();prior=invocation.points[index];}sample.phases[4]=std::chrono::duration<double,std::milli>(ended-prior).count();}sample.external=invocation.external;sample.clocks=invocation.clocks;sample.readiness=invocation.readiness;sample.fallbacks=invocation.fallbacks;sample.lighting_rows=invocation.lighting_rows;sample.generation=generation;sample.registered=static_cast<int64_t>(entries.size());sample.prepared=prepared;sample.culled=culled;sample.active=active;sampler.record(invocation,sample);};
  try{auto out=frame(input);finish(true);return out;}catch(...){finish(false);throw;}
 }
 EngineVar chunk_census()const{
  auto out=EngineVar::dictionary(),rows=::array_empty();int64_t counts[6]{};
  for(const auto id:order){const auto& entry=*entries.at(id);if(!entry.owner||!entry.owner->compact_state.chunk)continue;const auto proof=entry.owner->childless_chunk_proof();++counts[proof];auto row=EngineVar::dictionary();
   ::set(row,"id",EngineVar::integer(id));::set(row,"resource",EngineVar::text(resident::get(entry.owner->state,particle_field::chunkName).string.c_str()));::set(row,"proof",EngineVar::integer(proof));::set(row,"active",EngineVar::integer(static_cast<int64_t>(entry.owner->compact_pool.active.size())));::set(row,"free",EngineVar::integer(static_cast<int64_t>(entry.owner->compact_pool.free.size())));::set(row,"source_flags",EngineVar::integer(entry.controls.source_flags));::set(row,"requested",EngineVar::boolean(entry.controls.childless_chunk_admission));::set(row,"last_checked",EngineVar::boolean(entry.step.checked));::set(row,"last_culled",EngineVar::boolean(entry.step.culled));::set(row,"last_proof",EngineVar::integer(entry.step.chunk_proof));::method(rows,"append",{row});}
  ::set(out,"entries",rows);const char* names[]={"unsupported","empty_active","all_active_children_nil","missing_metadata","unknown_view","nonnull_child"};for(size_t index=0;index<6;++index)::set(out,names[index],EngineVar::integer(counts[index]));return out;
 }
 EngineVar entry_info(int64_t id)const{
  auto out=EngineVar::dictionary();auto found=entries.find(id);if(found==entries.end())return out;const auto& e=*found->second;::set(out,"fast",EngineVar::boolean(e.owner!=nullptr));if(!e.owner)return out;
  const auto number=[&](const char* name,int64_t value){::set(out,name,EngineVar::integer(value));};number("frames",e.frames);number("active",static_cast<int64_t>(e.owner->compact_pool.active.size()));number("free",static_cast<int64_t>(e.owner->compact_pool.free.size()));number("allocated",e.owner->allocations);number("constant_hits",e.owner->constant_hits);number("sampled_channels",e.owner->sampled_channels);number("vertices",e.published_vertices);number("peak_active",e.peak_active);number("culling_checks",e.culling_checks);number("culled_frames",e.culled_frames);number("culling_fallbacks",e.culling_fallbacks);number("direct_scene_queries",e.direct_queries);number("direct_scene_hits",e.direct_hits);::set(out,"culled",EngineVar::boolean(e.step.culled));::set(out,"radius",EngineVar::number(e.step.radius));::set(out,"elapsed",EngineVar::number(e.elapsed));::set(out,"pending_detonate",EngineVar::boolean(e.controls.detonate));::set(out,"pending_patch",EngineVar::boolean(!e.controls.patch.nil()));::set(out,"childless_chunk_admission",EngineVar::boolean(e.controls.childless_chunk_admission));::set(out,"chunk_proof",EngineVar::integer(e.step.chunk_proof));return out;
 }
 EngineVar inspect()const{
  auto out=summary();auto layout=EngineVar::dictionary();::set(layout,"entry",EngineVar::integer(sizeof(Entry)));::set(layout,"step",EngineVar::integer(sizeof(Step)));::set(layout,"controls",EngineVar::integer(sizeof(Controls)));::set(layout,"range",EngineVar::integer(sizeof(Range)));::set(layout,"packet",EngineVar::integer(sizeof(Packet)));::set(out,"native_layout_bytes",layout);
  if(packet){
   // Packed-array Variants share an engine wrapper: script indexed writes can
   // mutate that wrapper even when the native Frame is const. Cold inspection
   // exports its own packed-array object; render consumers retain Packet
   // directly instead of round-tripping through this diagnostic copy.
   auto bytes=packet->vertices;::set(out,"buffer",::method(bytes,"duplicate"));
   auto ranges=::array_empty();for(const auto& range:packet->ranges){auto row=EngineVar::dictionary();::set(row,"id",EngineVar::integer(range.id));::set(row,"first",EngineVar::integer(range.first));::set(row,"count",EngineVar::integer(range.count));::set(row,"distance",EngineVar::number(range.distance));::set(row,"chunk",EngineVar::boolean(range.chunk));::set(row,"bounds",::array(std::array<float,6>{range.minimum[0],range.minimum[1],range.minimum[2],range.maximum[0]-range.minimum[0],range.maximum[1]-range.minimum[1],range.maximum[2]-range.minimum[2]}));::method(ranges,"append",{row});}::set(out,"ranges",ranges);
  }
  auto diagnostics=::array_empty();for(const auto id:order){
   if(!entries.at(id)->owner){auto row=entry_info(id);::set(row,"id",EngineVar::integer(id));::method(diagnostics,"append",{row});continue;}
   const auto& entry=*entries.at(id);auto row=EngineVar::dictionary();::set(row,"id",EngineVar::integer(id));::set(row,"elapsed",EngineVar::number(entry.elapsed));::set(row,"frames",EngineVar::integer(entry.frames));
   ::set(row,"active",EngineVar::integer(static_cast<int64_t>(entry.owner->compact_pool.active.size())));::set(row,"free",EngineVar::integer(static_cast<int64_t>(entry.owner->compact_pool.free.size())));::set(row,"allocated",EngineVar::integer(entry.owner->allocations));
   ::set(row,"constant_hits",EngineVar::integer(entry.owner->constant_hits));::set(row,"sampled_channels",EngineVar::integer(entry.owner->sampled_channels));::set(row,"culling_checks",EngineVar::integer(entry.culling_checks));::set(row,"culled_frames",EngineVar::integer(entry.culled_frames));::set(row,"culling_fallbacks",EngineVar::integer(entry.culling_fallbacks));
   ::set(row,"culled",EngineVar::boolean(entry.step.culled));::set(row,"radius",EngineVar::number(entry.step.radius));::set(row,"animation_invoked",EngineVar::boolean(entry.step.animation_invoked));::set(row,"updated",EngineVar::boolean(entry.step.updated));
   ::set(row,"direct_scene_queries",EngineVar::integer(static_cast<int64_t>(entry.step.direct_queries)));::set(row,"direct_scene_hits",EngineVar::integer(static_cast<int64_t>(entry.step.direct_hits)));::set(row,"legacy_position_bytes",EngineVar::integer(static_cast<int64_t>(entry.owner->staging.positions.size())));::set(row,"legacy_attribute_bytes",EngineVar::integer(static_cast<int64_t>(entry.owner->staging.attributes.size())));::method(diagnostics,"append",{row});
  }::set(out,"emitters",diagnostics);return out;
 }
 // NWN_COLD_ADMISSION_POLICY_SURVEY_V1
 // Cold-only admission policy observation. Does not refresh Nodes, clocks,
 // controllers, wind services, simulation, geometry, radius/reject-plane caches.
 EngineVar admission_policy_survey()const{
  if(running)throw std::runtime_error("Cold admission survey requires a frame boundary");
  auto out=EngineVar::dictionary(),rows=::array_empty();
  int64_t examined=0,prepared_count=0,current_culled=0,native_current_rejects=0,scaled_rejects=0,conservative_rejects=0,extra_current=0,extra_scaled=0,negative_life=0,negative_radius=0,scale_expanded=0;
  for(const auto id:order){
   const auto& entry=*entries.at(id);auto row=EngineVar::dictionary();
   const auto integer=[&](const char* name,int64_t value){::set(row,name,EngineVar::integer(value));};
   const auto boolean=[&](const char* name,bool value){::set(row,name,EngineVar::boolean(value));};
   const auto number=[&](const char* name,float value){if(std::isfinite(value))::set(row,name,EngineVar::number(value));else ::set(row,name,EngineVar::text(std::isnan(value)?"NaN":value<0?"-Infinity":"Infinity"));};
   integer("id",id);boolean("enabled",entry.enabled);boolean("has_owner",entry.owner!=nullptr);
   if(!entry.owner){::method(rows,"append",{row});continue;}
   const auto& step=entry.step;const auto& owner=*entry.owner;const auto& emitter=owner.compact_state;
   ++examined;if(step.prepared)++prepared_count;if(step.culled)++current_culled;
   boolean("prepared",step.prepared);boolean("current_checked",step.checked);boolean("current_culled",step.culled);boolean("animation_invoked",step.animation_invoked);boolean("updated",step.updated);
   integer("pose_id",static_cast<int64_t>(owner.pose_id));integer("source_id",static_cast<int64_t>(owner.source_id));integer("source_flags",step.controls.source_flags);integer("emitter_flags",emitter.flags);integer("kind",owner.kind);integer("render_mode",emitter.renderMode1a8);
   integer("active",static_cast<int64_t>(owner.compact_pool.active.size()));integer("free",static_cast<int64_t>(owner.compact_pool.free.size()));integer("allocated",owner.allocations);boolean("chunk",emitter.chunk);
   number("birth_rate",emitter.birthRate);number("life_exp",emitter.lifeExp);number("velocity",emitter.velocity);number("random_velocity",emitter.randomVelocity);number("mass",emitter.mass);
   number("size_start",emitter.sizeStart);number("size_end",emitter.sizeEnd);number("size_start_y",emitter.sizeStartY);number("size_end_y",emitter.sizeEndY);number("x_size",emitter.xSize);number("y_size",emitter.ySize);
   number("last_radius",step.radius);number("pose_scale",step.pose.scale);number("pose_maximum_scale",step.pose.maximum_scale);number("source_scale",emitter.source.adjustedScale);::set(row,"pose_position",::array(step.pose.position));
   if(emitter.lifeExp<0)++negative_life;
   const auto* wind=((emitter.flags&4)&&step.controls.wind_token)?&scene_wind::owner(step.controls.wind_token):nullptr;
   const bool known_wind=!wind||wind->points.empty();boolean("known_wind",known_wind);
   // This recomputes the analytic sphere from CURRENT retained controller
   // fields. Original cached +0x20c, source prior-view and BSP placement may
   // differ, so it is explicitly a hypothetical policy comparison.
   int chunk_proof=emitter.chunk?1:0;
   if(emitter.chunk){for(auto* particle:owner.compact_pool.active){const auto found=owner.compact_extras.find(particle);if(found==owner.compact_extras.end()){chunk_proof=3;break;}if(!found->second.native_chunk){chunk_proof=4;break;}if(!found->second.child.nil()){chunk_proof=5;break;}chunk_proof=2;}}
   integer("current_chunk_proof",chunk_proof);
   const bool child_geometry_known=!emitter.chunk||chunk_proof==1||chunk_proof==2;
   const bool can_compare=step.prepared&&step.camera&&step.controls.source_flags>=0&&known_wind&&child_geometry_known;
   boolean("policy_comparable",can_compare);
   if(can_compare){
    resident::FieldKeyScope fields(owner.field_keys);
    const auto ambient=wind?wind->wind:V3{};const float analytic=owner.radius(step.controls.source_flags,ambient),scale=std::max(1.0f,step.pose.maximum_scale),scaled=analytic*scale;
    number("analytic_current_controller_radius",analytic);number("analytic_scaled_radius",scaled);::set(row,"ambient_wind",::array(ambient));
    if(analytic<0)++negative_radius;if(scale>1)++scale_expanded;
    const V3 point{step.pose.position[0],step.pose.position[2],-step.pose.position[1]};
    const auto rejected=[&](float radius){bool result=false;for(size_t n=0;n<6;++n){const size_t at=n*4;const auto& p=step.camera->planes;const float distance=((point[0]*p[at]-p[at+3])+point[1]*p[at+1])+point[2]*p[at+2];if(distance-radius>0){result=true;break;}}return result;};
    const bool native_reject=rejected(analytic),scaled_reject=rejected(scaled);float bound=0;const bool conservative_reject=owner.culled(*step.camera,step.pose.position,step.controls.source_flags,scale,bound,ambient);
    boolean("hypothetical_native_current_reject",native_reject);boolean("hypothetical_scaled_reject",scaled_reject);boolean("conservative_recomputed_reject",conservative_reject);number("conservative_recomputed_radius",bound);
    if(native_reject)++native_current_rejects;if(scaled_reject)++scaled_rejects;if(conservative_reject)++conservative_rejects;if(native_reject&&!conservative_reject)++extra_current;if(scaled_reject&&!conservative_reject)++extra_scaled;
    if(emitter.chunk)::set(row,"chunk_scope",EngineVar::text("Analytic policy only. A live child-Gob radius contribution is not reconstructed; check authoritative child metadata before using this comparison."));
   }
   ::method(rows,"append",{row});
  }
  ::set(out,"rows",rows);const auto integer=[&](const char* name,int64_t value){::set(out,name,EngineVar::integer(value));};
  integer("registered",static_cast<int64_t>(entries.size()));integer("examined",examined);integer("prepared",prepared_count);integer("current_culled",current_culled);integer("native_current_rejects",native_current_rejects);integer("scaled_rejects",scaled_rejects);integer("conservative_rejects",conservative_rejects);integer("extra_current_policy_admitted",extra_current);integer("extra_scaled_policy_admitted",extra_scaled);integer("negative_life",negative_life);integer("negative_analytic_radius",negative_radius);integer("scale_expanded",scale_expanded);
  ::set(out,"scope",EngineVar::text("Cold retained last-Step/current-state policy survey; no Node/controller/clock/simulation calls or cache writes. Last Step radius precedes its simulation; recomputed policies use the current post-simulation pool. Native-current comparisons are hypothetical: they do not reconstruct original cached +0x20c, prior model view/controller gates, live child-Gob spheres or BSP leaf traversal. Unknown/live-child chunk metadata is excluded from policy comparisons."));return out;
 }

 void close(){if(running)throw std::runtime_error("Native presentation close requires a frame boundary");closed=true;packet.reset();canonical_packet.reset();frame_entries.clear();order_dirty=true;entries.clear();order.clear();counters=nullptr;retained_counters=EngineVar();}
};
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnParticlePresentation");auto object=construct_object(base.data);auto owner=new Owner();owner->identity=object;set_instance(object,name.data,owner);{std::lock_guard<std::mutex> lock(registry_mutex);registry.emplace(object,owner);}if(notify){EngineVar value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{EngineVar::integer(0)});}return object;}
void free(void*,GDExtensionClassInstancePtr instance){auto* owner=static_cast<Owner*>(instance);{std::lock_guard<std::mutex> lock(registry_mutex);registry.erase(owner->identity);}delete owner;}
void call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 if(!particle_upload::count_ok(count,2,result,error))return;
 try{auto& owner=*static_cast<Owner*>(instance);EngineVar operation(args[0]),input(args[1]);auto out=EngineVar::dictionary();switch(operation.integer()){case 0:owner.add(input);break;case 1:out=owner.timed_frame(input);break;case 2:out=owner.inspect();break;case 3:owner.erase(::get(input,"id").integer());break;case 4:owner.control(input);break;case 5:owner.close();break;case 6:owner.set_order(input);break;case 7:out=owner.summary();break;case 8:owner.bind_counters(input);break;case 9:out=owner.scene_frame();break;case 10:out=owner.entry_info(::get(input,"id").integer());break;case 11:out=owner.refresh_visibility();break;case 12:out=emitter_lighting::inspect(input);break;case 13:out=particle_scene_boundary::inspect();break;case 14:out=owner.chunk_census();break;case 15:owner.configure_sampler(input);out=owner.sampler_info();break;case 16:out=owner.sampler_info();break;case 17:out=owner.admission_policy_survey();break;case 18:{auto rows=::array_empty();for(const auto& pair:owner.entries)if(pair.second->owner){auto row=pair.second->owner->hot_parameter_info();::set(row,"id",EngineVar::integer(pair.first));::method(rows,"append",{row});}::set(out,"owners",rows);break;}case 19:out=resident::hot_parameters::component_oracle();break;case 20:out=resident::resident_text::component_oracle();break;case 21:out=resident::resident_text::inspect();break;case 22:{auto rows=::array_empty();for(const auto& pair:owner.entries)if(pair.second->owner){auto row=pair.second->owner->empty_clip_info();::set(row,"id",EngineVar::integer(pair.first));::method(rows,"append",{row});}::set(out,"owners",rows);break;}default:throw std::runtime_error("Unknown native particle presentation operation");}new_copy(result,out.data);}catch(const std::exception& failure){auto out=EngineVar::dictionary();::set(out,"error",EngineVar::text(failure.what()));new_copy(result,out.data);}
}
template<typename Property>void register_owner(const Property& property){
 setup_clock_route::bind();
 Name name("NwnParticlePresentation"),base("RefCounted"),method_name("dispatch"),empty(""),operation("operation"),input("input");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free;register_class(library,name.data,base.data,&info);registered=true;
 auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo method{};method.name=method_name.data;method.call_func=call;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;method.has_return_value=true;method.return_value_info=&ret;method.argument_count=2;method.arguments_info=args;method.arguments_metadata=metadata;register_method(library,name.data,&method);
}
void unregister_owner(){if(registered){Name name("NwnParticlePresentation");unregister_class(library,name.data);registered=false;}}
} // namespace particle_presentation
