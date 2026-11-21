// Experimental presentation-thread frame owner. Registration retains exact
// native owners/providers; per-frame scene order is explicit, never hash order.
// Consumers run synchronously before the next emitter, preserving callback
// observations and RNG order. This does not introduce a worker/render thread.
namespace particle_frame_group {
GDExtensionMethodBindPtr visible_in_tree,inside_tree,can_process;
GDExtensionPtrBuiltInMethod callable_valid;
bool registered=false;
bool valid_callable(const EngineVar& value){
 if(value.type()!=GDEXTENSION_VARIANT_TYPE_CALLABLE)return false;
 alignas(8) uint8_t raw[16];to[GDEXTENSION_VARIANT_TYPE_CALLABLE](raw,const_cast<uint8_t*>(value.data));GDExtensionBool valid=false;callable_valid(raw,nullptr,&valid,0);ptr_destructor(GDEXTENSION_VARIANT_TYPE_CALLABLE)(raw);return valid!=0;
}
bool eligible(int64_t id,bool allow_boundary=true){
 bool result=false;if(allow_boundary&&particle_scene_boundary::eligible(id,result))return result;
 auto node=instance_from_id(static_cast<uint64_t>(id));if(!node||!cast_object(node,node_tag))return false;
 GDExtensionBool inside=false,visible=false,process=false;ptrcall(inside_tree,node,nullptr,&inside);if(!inside)return false;ptrcall(visible_in_tree,node,nullptr,&visible);if(!visible)return false;ptrcall(can_process,node,nullptr,&process);return process!=0;
}
// Render visibility is independent of whether the simulation tree can process.
// Pausing retains the last picture; hiding an ancestor must still hide it.
bool visible(int64_t id){
 auto node=instance_from_id(static_cast<uint64_t>(id));if(!node||!cast_object(node,node_tag))return false;
 GDExtensionBool inside=false,shown=false;ptrcall(inside_tree,node,nullptr,&inside);if(!inside)return false;ptrcall(visible_in_tree,node,nullptr,&shown);return shown!=0;
}
struct Entry {
 int64_t id=0;EngineVar retained,input,providers,receiver,fallback,clock,static_clip;
 resident::Owner* owner=nullptr;bool enabled=true,detonate=false;double elapsed=0,clip_length=0;int64_t frames=0;
};
struct Owner {
 std::unordered_map<int64_t,std::shared_ptr<Entry>> entries;std::vector<int64_t> order;
 EngineVar common;
 bool closed=false,running=false;int64_t frames=0,processed=0,skipped=0,failures=0;
 void add(const EngineVar& config){
  if(closed)throw std::runtime_error("Particle group registration requires an open group");
  const auto id=::get(config,"id").integer();if(entries.find(id)!=entries.end())throw std::runtime_error("Particle group identity already registered");
  auto entry=std::make_shared<Entry>();entry->id=id;
  if(::has(config,"owner")&&!::get(config,"owner").nil()){
   // Retain before looking up the private instance. The registry itself owns
   // no engine objects; the entry keeps this pointer valid until removal.
   entry->retained=::get(config,"owner");if(entry->retained.type()!=GDEXTENSION_VARIANT_TYPE_OBJECT)throw std::runtime_error("Particle group owner must be an object");
   GDExtensionObjectPtr object=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&object,entry->retained.data);
   {std::lock_guard<std::mutex> guard(resident::owner_registry_mutex);auto found=resident::owner_registry.find(object);if(found!=resident::owner_registry.end())entry->owner=found->second;}
   if(!entry->owner||!entry->owner->configured||!entry->owner->compact_records||!entry->owner->typed_frame||!entry->owner->pose_id)throw std::runtime_error("Particle group requires a configured typed owner with native poses");
   auto input=::get(config,"input");entry->input=::method(input,"duplicate",{EngineVar::boolean(true)});entry->static_clip=::has(input,"clip")?::get(input,"clip"):EngineVar::text("");entry->providers=::get(config,"providers");entry->receiver=::get(config,"receiver");
   if(!valid_callable(entry->receiver))throw std::runtime_error("Particle group requires its synchronous consumer");
   if(::has(config,"clock"))entry->clock=::get(config,"clock");
   entry->elapsed=::has(config,"elapsed")?::get(config,"elapsed").number():0;
   entry->clip_length=::has(config,"clip_length")?::get(config,"clip_length").number():0;
  }else{entry->fallback=::get(config,"fallback");if(!valid_callable(entry->fallback))throw std::runtime_error("Particle group fallback is not callable");}
  if(::has(config,"enabled"))entry->enabled=::get(config,"enabled").boolean();
  entries.emplace(id,entry);order.push_back(id);
 }
 void erase(int64_t id){entries.erase(id);order.erase(std::remove(order.begin(),order.end(),id),order.end());}
 void set_order(EngineVar ids){
  if(running)throw std::runtime_error("Particle group order changes require a frame boundary");
  if(ids.type()!=GDEXTENSION_VARIANT_TYPE_ARRAY||::size(ids)!=static_cast<int64_t>(entries.size()))throw std::runtime_error("Particle group order must cover every registered identity");
  std::vector<int64_t> next;std::unordered_map<int64_t,bool> seen;next.reserve(entries.size());
  for(int64_t n=0;n<::size(ids);++n){const auto id=::at(ids,n).integer();if(entries.find(id)==entries.end()||!seen.emplace(id,true).second)throw std::runtime_error("Particle group order has an absent or duplicate identity");next.push_back(id);}order=std::move(next);
 }
 void control(const EngineVar& config){
  const auto id=::get(config,"id").integer();auto found=entries.find(id);if(found==entries.end())return;auto& entry=*found->second;
  if(::has(config,"enabled"))entry.enabled=::get(config,"enabled").boolean();
  if(::has(config,"detonate")&&::get(config,"detonate").boolean())entry.detonate=true;
  if(!entry.owner)return;
  for(const auto* field:{"culling","draw_enabled","source_flags","wind_token","capacity"})if(::has(config,field))::set(entry.input,field,::get(config,field));
  if(::has(config,"flags")){auto patch=EngineVar::dictionary();::set(patch,"flags",::get(config,"flags"));::set(entry.input,"patch",patch);}
  if(::has(config,"scene_indices"))::set(entry.input,"scene_indices",::get(config,"scene_indices"));
  if(::has(config,"clock"))entry.clock=::get(config,"clock");
 }
 EngineVar frame(const EngineVar& input,const EngineVar* identity=nullptr){
  if(closed||running)throw std::runtime_error("Particle group is closed or already in a frame");
  struct Scope {bool& value;explicit Scope(bool& v):value(v){value=true;}~Scope(){value=false;}}scope(running);
  const auto delta=::get(input,"delta").number();const bool profile=::has(input,"profile")&&::get(input,"profile").boolean();auto view=::get(input,"view");
  const auto frame_order=identity?std::vector<int64_t>{identity->integer()}:order;auto errors=::array_empty();int64_t count=0,omitted=0;
  using Clock=std::chrono::steady_clock;
  for(const auto id:frame_order){
   if(closed)break;auto found=entries.find(id);if(found==entries.end())continue;
   auto entry=found->second; // A synchronous callback may remove this entry.
   if(!entry->enabled||!eligible(id)){++omitted;continue;}
   if(!entry->owner){if(valid_callable(entry->fallback)){::method(entry->fallback,"call",{EngineVar::number(delta)});++entry->frames;++count;}else ++omitted;continue;}
   if(!instance_from_id(entry->owner->source_id)){++omitted;continue;}
   const auto began=profile?Clock::now():Clock::time_point{};EngineVar output;
   double prepare_ms=0,dispatch_ms=0;
   try{
    entry->elapsed+=delta;double time=entry->elapsed;
    if(valid_callable(entry->clock)){
     auto clock=::method(entry->clock,"call");if(clock.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Particle group clock must return a dictionary");
     ::set(entry->input,"clip",::has(clock,"clip")?::get(clock,"clip"):EngineVar::text(""));time=::has(clock,"time")?::get(clock,"time").number():0;
    }else{::set(entry->input,"clip",entry->static_clip);if(entry->clip_length>0){time=std::fmod(time,entry->clip_length);if(time<0)time+=entry->clip_length;}}
    ::set(entry->input,"time",EngineVar::number(time));::set(entry->input,"delta",EngineVar::number(delta));::set(entry->input,"profile",EngineVar::boolean(profile));::set(entry->input,"view",view);::set(entry->input,"detonate",EngineVar::boolean(entry->detonate));
    if(::has(input,"scene_indices"))::set(entry->input,"scene_indices",::get(input,"scene_indices"));else ::method(entry->input,"erase",{::key("scene_indices")});
    const auto dispatch=profile?Clock::now():Clock::time_point{};if(profile)prepare_ms=std::chrono::duration<double,std::milli>(dispatch-began).count();
    output=entry->owner->frame(entry->input,entry->providers);if(profile)dispatch_ms=std::chrono::duration<double,std::milli>(Clock::now()-dispatch).count();
    entry->detonate=false;::method(entry->input,"erase",{::key("patch")});
    if(::has(output,"capacity"))::set(entry->input,"capacity",::get(output,"capacity"));
   }catch(const std::exception& error){output=EngineVar::dictionary();::set(output,"error",EngineVar::text(error.what()));entry->enabled=false;entry->detonate=false;++failures;auto row=EngineVar::dictionary();::set(row,"id",EngineVar::integer(id));::set(row,"error",EngineVar::text(error.what()));::method(errors,"append",{row});}
   // Preserve publication/counter observations before the next emitter or
   // fallback consumes the shared RNG/services. No deferred consumer phase.
   if(valid_callable(entry->receiver)){auto accepted=::method(entry->receiver,"call",{output,EngineVar::number(entry->elapsed),EngineVar::number(prepare_ms),EngineVar::number(dispatch_ms)});if(accepted.type()==GDEXTENSION_VARIANT_TYPE_BOOL&&!accepted.boolean())entry->enabled=false;}
   else entry->enabled=false;
   ++entry->frames;++count;
  }
  ++frames;processed+=count;skipped+=omitted;auto out=EngineVar::dictionary();::set(out,"processed",EngineVar::integer(count));::set(out,"skipped",EngineVar::integer(omitted));::set(out,"errors",errors);return out;
 }
 EngineVar stats(const EngineVar& input)const{auto out=EngineVar::dictionary();::set(out,"registered",EngineVar::integer(static_cast<int64_t>(entries.size())));::set(out,"frames",EngineVar::integer(frames));::set(out,"processed",EngineVar::integer(processed));::set(out,"skipped",EngineVar::integer(skipped));::set(out,"failures",EngineVar::integer(failures));::set(out,"closed",EngineVar::boolean(closed));if(::has(input,"id")){auto found=entries.find(::get(input,"id").integer());if(found!=entries.end()){::set(out,"elapsed",EngineVar::number(found->second->elapsed));::set(out,"entry_frames",EngineVar::integer(found->second->frames));}}return out;}
 void prepare(const EngineVar& input){if(closed||running)throw std::runtime_error("Particle frame preparation requires an open frame boundary");common=input;}
 EngineVar ordered_frame(const EngineVar& input){if(common.nil()||!::has(common,"delta"))return EngineVar::dictionary();auto identity=::get(input,"id");return frame(common,&identity);}
 void close(){closed=true;entries.clear();order.clear();common=EngineVar();}
};
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnParticleFrameGroup");auto object=construct_object(base.data);auto owner=new Owner();set_instance(object,name.data,owner);if(notify){EngineVar value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{EngineVar::integer(0)});}return object;}
void free(void*,GDExtensionClassInstancePtr instance){delete static_cast<Owner*>(instance);}
void call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 if(!particle_upload::count_ok(count,2,result,error))return;
 try{auto& owner=*static_cast<Owner*>(instance);EngineVar operation(args[0]),input(args[1]);auto out=EngineVar::dictionary();switch(operation.integer()){case 0:owner.add(input);break;case 1:owner.erase(::get(input,"id").integer());break;case 2:out=owner.frame(input);break;case 3:owner.set_order(::get(input,"ids"));break;case 4:owner.control(input);break;case 5:owner.close();break;case 6:out=owner.stats(input);break;case 7:owner.prepare(input);break;case 8:out=owner.ordered_frame(input);break;default:throw std::runtime_error("Unknown particle frame-group operation");}new_copy(result,out.data);}catch(const std::exception& failure){auto out=EngineVar::dictionary();::set(out,"error",EngineVar::text(failure.what()));new_copy(result,out.data);}
}
template<typename Property>void register_owner(const Property& property){
 Name node("Node"),node3d("Node3D"),visible("is_visible_in_tree"),inside("is_inside_tree"),process("can_process"),valid("is_valid");
 visible_in_tree=class_method(node3d.data,visible.data,36873697);inside_tree=class_method(node.data,inside.data,36873697);can_process=class_method(node.data,process.data,36873697);callable_valid=builtin_method(GDEXTENSION_VARIANT_TYPE_CALLABLE,valid.data,3918633141);if(!visible_in_tree||!inside_tree||!can_process||!callable_valid)return;
 Name name("NwnParticleFrameGroup"),base("RefCounted"),method_name("dispatch"),empty(""),operation("operation"),input("input");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free;register_class(library,name.data,base.data,&info);registered=true;
 auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo method{};method.name=method_name.data;method.call_func=call;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;method.has_return_value=true;method.return_value_info=&ret;method.argument_count=2;method.arguments_info=args;method.arguments_metadata=metadata;register_method(library,name.data,&method);
}
void unregister_owner(){if(registered){Name name("NwnParticleFrameGroup");unregister_class(library,name.data);registered=false;}}
} // namespace particle_frame_group
