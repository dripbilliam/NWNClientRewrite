// Optional lifetime-bound lookup for the main-thread particle scene pass.
// Cached poses require a current engine dirty proof for their Node3D identity.
namespace particle_pose_handle {
GDExtensionInterfaceObjectGetInstanceBinding get_binding=nullptr;
GDExtensionInterfaceObjectFreeInstanceBinding free_binding=nullptr;
GDExtensionInterfaceObjectGetInstanceId object_id=nullptr;
bool enabled=false,counting=false;
thread_local bool scene_thread=false;
using DirtyProbe = int32_t (*)(GDExtensionObjectPtr,uint32_t,float*,uint32_t);
DirtyProbe dirty_probe=nullptr;
bool dirty_requested=false;

struct PoseMemo {
 particle_pose_cache::Conversion<EnginePose> conversion;
 EnginePose pose{};
 bool valid=false;
};

struct Counts {
 uint64_t bindings=0,pose_hits=0,pose_resolves=0,pose_casts=0,pose_reads=0,source_hits=0,source_resolves=0;
 uint64_t dirty_hits=0,dirty_reads=0,dirty_fallbacks=0;
};
Counts counts;

struct Binding {
 explicit Binding(GDExtensionObjectPtr node):object(node){}
 std::atomic<GDExtensionObjectPtr> object;
 std::atomic<uint32_t> references{1}; // One engine binding plus the attached endpoints.
 Binding* previous=nullptr;
 Binding* next=nullptr;
 std::unique_ptr<PoseMemo> memo;
};
std::mutex bindings_mutex;
Binding* first_binding=nullptr;

void release(Binding* binding){
 if(binding&&binding->references.fetch_sub(1,std::memory_order_acq_rel)==1)delete binding;
}

void* attach(void*,void* object){
 auto* binding=new(std::nothrow) Binding(object);
 if(!binding)return nullptr;
 std::lock_guard<std::mutex> guard(bindings_mutex);
 binding->next=first_binding;
 if(first_binding)first_binding->previous=binding;
 first_binding=binding;
 if(counting&&scene_thread)++counts.bindings;
 return binding;
}

void detach(void*,void*,void* value){
 auto* binding=static_cast<Binding*>(value);
 if(!binding)return;
 {
  std::lock_guard<std::mutex> guard(bindings_mutex);
  binding->object.store(nullptr,std::memory_order_release);
  if(binding->previous)binding->previous->next=binding->next;
  else first_binding=binding->next;
  if(binding->next)binding->next->previous=binding->previous;
 }
 release(binding);
}

const GDExtensionInstanceBindingCallbacks callbacks{attach,detach,nullptr};

class Endpoint {
 uint64_t identity_=0;
 Binding* binding_=nullptr;
public:
 Endpoint()=default;
 Endpoint(const Endpoint&)=delete;
 Endpoint& operator=(const Endpoint&)=delete;
 ~Endpoint(){release(binding_);}

 GDExtensionObjectPtr current(uint64_t identity)const{
  if(!binding_||identity_!=identity)return nullptr;
  const auto node=binding_->object.load(std::memory_order_acquire);
  // ObjectDB can explicitly detach an identity before the binding is freed.
  return node&&object_id(node)==identity?node:nullptr;
 }

 PoseMemo* pose_memo(){
  if(!binding_)return nullptr;
  if(!binding_->memo)binding_->memo.reset(new(std::nothrow) PoseMemo);
  return binding_->memo.get();
 }

 void retain(uint64_t identity,GDExtensionObjectPtr node){
  auto* binding=static_cast<Binding*>(get_binding(node,library,&callbacks));
  if(binding==binding_)return;
  if(binding)binding->references.fetch_add(1,std::memory_order_relaxed);
  release(binding_);
  binding_=binding;
  identity_=identity;
 }
};

bool active(){return enabled&&scene_thread;}
bool dirty_active(){return dirty_probe&&active();}

void bind(GDExtensionInterfaceGetProcAddress address){
 scene_thread=true;
 Name os_name("OS");
 auto object=global_singleton(os_name.data);
 if(!object)return;
 EngineVar os;destroy(os.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](os.data,&object);
 const auto mode=engine_string(::method(os,"get_environment",{EngineVar::text("NWN_PARTICLE_POSE_HANDLES")}));
 counting=mode=="retained-counters"||mode=="legacy-counters";
 if(!mode.empty()&&mode!="retained"&&mode!="retained-counters")return;
 get_binding=reinterpret_cast<GDExtensionInterfaceObjectGetInstanceBinding>(address("object_get_instance_binding"));
 free_binding=reinterpret_cast<GDExtensionInterfaceObjectFreeInstanceBinding>(address("object_free_instance_binding"));
 object_id=reinterpret_cast<GDExtensionInterfaceObjectGetInstanceId>(address("object_get_instance_id"));
 enabled=get_binding&&free_binding&&object_id;
 const auto reuse=engine_string(::method(os,"get_environment",{EngineVar::text("NWN_PARTICLE_POSE_REUSE")}));
 dirty_requested=reuse.empty()||reuse=="dirty";
 if(!enabled||!dirty_requested)return;
 Name class_name("ClassDB");
 auto singleton=global_singleton(class_name.data);
 if(!singleton)return;
 EngineVar classdb;destroy(classdb.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](classdb.data,&singleton);
 const auto node=EngineVar::text("Node3D"),marker=EngineVar::text("NWN_PARTICLE_POSE_DIRTY_ABI");
 if(!::method(classdb,"class_has_integer_constant",{node,marker}).boolean())return;
 if(::method(classdb,"class_get_integer_constant",{node,marker}).integer()!=1)return;
 dirty_probe=reinterpret_cast<DirtyProbe>(address("nwn_particle_pose_dirty_v1"));
}

void unbind(){
 enabled=false;
 dirty_probe=nullptr;
 // Scene workers have stopped at extension deinitialization. Remove our
 // callbacks from nodes that may outlive this library, without holding our
 // list lock while the engine calls detach().
 for(;;){
  GDExtensionObjectPtr object=nullptr;
  {
   std::lock_guard<std::mutex> guard(bindings_mutex);
   if(!first_binding)break;
   object=first_binding->object.load(std::memory_order_acquire);
  }
  free_binding(object,library);
 }
 scene_thread=false;
}

GDExtensionObjectPtr pose_node(uint64_t identity,Endpoint* endpoint){
 const bool retained=endpoint&&active();
 const bool measured=counting&&scene_thread;
 if(retained){
  if(auto object=endpoint->current(identity)){
   if(measured)++counts.pose_hits;
   return object;
  }
 }
 if(measured)++counts.pose_resolves;
 auto object=instance_from_id(identity);
 if(!object)return nullptr;
 if(measured)++counts.pose_casts;
 if(!cast_object(object,node_tag))return nullptr;
 if(retained)endpoint->retain(identity,object);
 return object;
}

bool source_exists(uint64_t identity,const Endpoint& endpoint){
 const bool measured=counting&&scene_thread;
 if(active()&&endpoint.current(identity)){
  if(measured)++counts.source_hits;
  return true;
 }
 if(measured)++counts.source_resolves;
 return instance_from_id(identity)!=nullptr;
}

void record_pose_read(){if(counting&&scene_thread)++counts.pose_reads;}

template<class Convert>
const EnginePose* read_if_proven(uint64_t identity,GDExtensionObjectPtr node,PoseMemo& memo,
 particle_pose_cache::Conversion<EnginePose>& owner_cache, std::array<float,12>& transform,Convert&& convert){
 const auto result=dirty_probe(node,memo.valid?0U:1U,transform.data(),static_cast<uint32_t>(transform.size()));
 if(result==1){
  ++owner_cache.hits;
  if(counting)++counts.dirty_hits;
  return &memo.pose;
 }
 memo.valid=false;
 if(result==-1){if(counting)++counts.dirty_fallbacks;return nullptr;}
 if(result!=0)throw std::runtime_error("Native dirty particle pose probe violates ABI1");
 if(counting){++counts.pose_reads;++counts.dirty_reads;}
 const auto previous=memo.conversion.conversions;
 memo.pose=memo.conversion.read(identity,transform,std::forward<Convert>(convert));
 memo.valid=memo.conversion.valid();
 if(previous==memo.conversion.conversions)++owner_cache.hits;
 else ++owner_cache.conversions;
 return &memo.pose;
}

void inspect(EngineVar& out){
 ::set(out,"dirty_pose_probe_requested",EngineVar::boolean(dirty_requested));
 ::set(out,"dirty_pose_probe_active",EngineVar::boolean(dirty_active()));
 ::set(out,"retained_pose_handles",EngineVar::boolean(active()));
 ::set(out,"retained_pose_handles_measured",EngineVar::boolean(counting&&scene_thread));
 const auto field=[&](const char* name,uint64_t value){::set(out,name,EngineVar::integer(static_cast<int64_t>(value)));};
 field("retained_pose_bindings",counts.bindings);
 field("retained_pose_hits",counts.pose_hits);field("pose_object_resolutions",counts.pose_resolves);
 field("pose_type_resolutions",counts.pose_casts);field("live_pose_transforms",counts.pose_reads);
 field("retained_source_hits",counts.source_hits);field("source_object_resolutions",counts.source_resolves);
 field("dirty_pose_hits",counts.dirty_hits);field("dirty_pose_reads",counts.dirty_reads);field("dirty_pose_fallbacks",counts.dirty_fallbacks);
}
}
