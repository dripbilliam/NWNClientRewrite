// RenderingServer owns scheduling. The bound Callable holds this RefCounted
// owner; it holds the MultiMesh resource, so a queued write cannot outlive its
// GPU buffer. Only atomics cross the presentation/render threads. The upload
// body never touches a Node, generic key cache, GDScript, or borrowed CPU data.
namespace particle_upload {
std::atomic<GDExtensionObjectPtr> server{nullptr};
GDExtensionMethodBindPtr get_buffer,get_device,is_render_thread,update_buffer,resource_rid,schedule_upload;
GDExtensionPtrBuiltInMethod byte_size;
void* multimesh_tag;
bool registered=false;
bool bind(){
 Name rs("RenderingServer"),rd("RenderingDevice"),res("Resource"),mm("MultiMesh"),buffer("multimesh_get_buffer_rd_rid"),device("get_rendering_device"),thread("is_on_render_thread"),update("buffer_update"),rid("get_rid"),size("size"),schedule("call_on_render_thread");
 multimesh_tag=class_tag(mm.data);
 get_buffer=class_method(rs.data,buffer.data,3814569979);get_device=class_method(rs.data,device.data,1405107940);is_render_thread=class_method(rs.data,thread.data,2240911060);update_buffer=class_method(rd.data,update.data,3454956949);resource_rid=class_method(res.data,rid.data,2944877500);
 byte_size=builtin_method(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,size.data,3173160232);
 schedule_upload=class_method(rs.data,schedule.data,1611583062);
 return multimesh_tag&&get_buffer&&get_device&&is_render_thread&&update_buffer&&resource_rid&&byte_size&&schedule_upload;
}
struct Owner {
 Var resource;GDExtensionObjectPtr object=nullptr;uint64_t mesh=0;int64_t capacity=0;
 std::atomic<bool> alive{true};std::atomic<int64_t> sequence{-1},uploads{0},bytes{0};std::atomic<int64_t> error{0};
 void configure(GDExtensionConstVariantPtr value,int64_t vertices){
  // Scene-level extension initialization precedes singleton publication.
  // Configure runs on the main thread after the actual scene has started.
  if(!server.load(std::memory_order_acquire)){Name name("RenderingServer");auto singleton=global_singleton(name.data);if(!singleton){error.store(1000);return;}server.store(singleton,std::memory_order_release);}
  if(!resource.nil()||get_type(value)!=GDEXTENSION_VARIANT_TYPE_OBJECT||vertices<0||vertices>196608||vertices%6){error.store(1001);return;}
  GDExtensionObjectPtr pointer=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&pointer,const_cast<void*>(value));
  if(!pointer||!cast_object(pointer,multimesh_tag)){error.store(1002);return;}
  ptrcall(resource_rid,pointer,nullptr,&mesh);if(!mesh){error.store(1003);return;}
  resource=Var(value);capacity=vertices/6*80;
 }
 void write(GDExtensionConstVariantPtr packet,int64_t next,GDExtensionObjectPtr renderer=nullptr,GDExtensionObjectPtr device=nullptr){
  if(!alive.load(std::memory_order_acquire)||error.load(std::memory_order_acquire)!=0)return;
  if(!mesh||get_type(packet)!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY){error.store(1005);return;}
  if(next<=sequence.load(std::memory_order_relaxed))return;
  if(!renderer){renderer=server.load(std::memory_order_acquire);if(!renderer){error.store(1007);return;}
   GDExtensionBool thread=false;ptrcall(is_render_thread,renderer,nullptr,&thread);if(!thread){error.store(1006);return;}
   ptrcall(get_device,renderer,nullptr,&device);if(!device){error.store(1007);return;}}
  uint64_t buffer=0;const GDExtensionConstTypePtr mesh_args[]={&mesh};ptrcall(get_buffer,renderer,mesh_args,&buffer);if(!buffer){error.store(1008);return;}
  alignas(8) uint8_t data[16];to[GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY](data,const_cast<void*>(packet));
  struct Guard {void* value;~Guard(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(value);}}guard{data};
  int64_t length=0;byte_size(data,nullptr,&length,0);if(length<=0||length>capacity||length%80){error.store(1009);return;}
  int64_t offset=0,result=-1;const GDExtensionConstTypePtr args[]={&buffer,&offset,&length,data};ptrcall(update_buffer,device,args,&result);
  if(result!=0){error.store(result);return;}
  sequence.store(next,std::memory_order_release);uploads.fetch_add(1,std::memory_order_relaxed);bytes.fetch_add(length,std::memory_order_relaxed);
 }
 void upload(const GDExtensionConstVariantPtr* arguments){
  if(!alive.load(std::memory_order_acquire)||error.load(std::memory_order_acquire)!=0)return;
  GDExtensionObjectPtr held=nullptr;
  if(get_type(arguments[0])!=GDEXTENSION_VARIANT_TYPE_OBJECT){error.store(1004);return;}
  to[GDEXTENSION_VARIANT_TYPE_OBJECT](&held,const_cast<void*>(arguments[0]));
  if(held!=object||!mesh||get_type(arguments[1])!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY||get_type(arguments[2])!=GDEXTENSION_VARIANT_TYPE_INT){error.store(1005);return;}
  int64_t next=0;to[GDEXTENSION_VARIANT_TYPE_INT](&next,const_cast<void*>(arguments[2]));if(next<=sequence.load(std::memory_order_relaxed))return;
  write(arguments[1],next);
 }
};
// Registry entries borrow pointers only while a mutex is held. A batch first
// retains the exact RefCounted owner, then looks it up and keeps that reference
// through render completion. No borrowed owner survives its strong reference.
std::mutex registry_mutex;
std::unordered_map<GDExtensionObjectPtr,Owner*> owners;
GDExtensionObjectPtr create(void*,GDExtensionBool notify){
 Name base("RefCounted"),name("NwnParticleUpload");auto object=construct_object(base.data);auto owner=new Owner();owner->object=object;set_instance(object,name.data,owner);
 {std::lock_guard<std::mutex> guard(registry_mutex);owners.emplace(object,owner);}
 if(notify){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{Var::integer(0)});}return object;
}
void free(void*,GDExtensionClassInstancePtr instance){auto* owner=static_cast<Owner*>(instance);{std::lock_guard<std::mutex> guard(registry_mutex);owners.erase(owner->object);}delete owner;}
bool count_ok(GDExtensionInt actual,GDExtensionInt expected,GDExtensionVariantPtr result,GDExtensionCallError* error){error->error=GDEXTENSION_CALL_OK;if(actual==expected)return true;error->error=actual<expected?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=static_cast<int32_t>(expected);new_nil(result);return false;}
void configure(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 if(!count_ok(count,2,result,error))return;auto& owner=*static_cast<Owner*>(instance);
 if(get_type(args[1])!=GDEXTENSION_VARIANT_TYPE_INT)owner.error.store(1010);else{int64_t capacity=0;to[GDEXTENSION_VARIANT_TYPE_INT](&capacity,const_cast<void*>(args[1]));owner.configure(args[0],capacity);}new_nil(result);
}
void upload(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!count_ok(count,3,result,error))return;static_cast<Owner*>(instance)->upload(args);new_nil(result);}
void cancel(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!count_ok(count,0,result,error))return;static_cast<Owner*>(instance)->alive.store(false,std::memory_order_release);new_nil(result);}
void status(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!count_ok(count,0,result,error))return;auto value=Var::integer(static_cast<Owner*>(instance)->error.load(std::memory_order_acquire));new_copy(result,value.data);}
void stats(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 if(!count_ok(count,0,result,error))return;auto& owner=*static_cast<Owner*>(instance);auto out=Var::dictionary();set(out,"uploads",Var::integer(owner.uploads.load()));set(out,"bytes",Var::integer(owner.bytes.load()));set(out,"sequence",Var::integer(owner.sequence.load()));set(out,"error",Var::integer(owner.error.load()));set(out,"alive",Var::boolean(owner.alive.load()));new_copy(result,out.data);
}
struct Batch {
 struct Entry {Var retained,packet;Owner* owner;int64_t sequence;};
 GDExtensionObjectPtr object=nullptr;
 // Main thread alone enqueues. Once submit seals the batch, only the render
 // callback accesses entries; diagnostics inspect atomic counters, never it.
 std::vector<Entry> entries;
 std::unordered_map<Owner*,size_t> indexes;
 std::atomic<int64_t> phase{0},accepted{0},coalesced{0},submitted{0},error{0};
 bool enqueue(const GDExtensionConstVariantPtr* args){
  if(phase.load(std::memory_order_acquire)!=0||error.load()!=0)return false;
  if(get_type(args[0])!=GDEXTENSION_VARIANT_TYPE_OBJECT||get_type(args[1])!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY||get_type(args[2])!=GDEXTENSION_VARIANT_TYPE_INT){error.store(1101);return false;}
  Var retained(args[0]);GDExtensionObjectPtr pointer=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&pointer,retained.data);
  Owner* owner=nullptr;{std::lock_guard<std::mutex> guard(registry_mutex);auto found=owners.find(pointer);if(found!=owners.end())owner=found->second;}
  if(!owner){error.store(1102);return false;}
  int64_t next=0;to[GDEXTENSION_VARIANT_TYPE_INT](&next,const_cast<void*>(args[2]));
  auto found=indexes.find(owner);
  if(found==indexes.end()){indexes.emplace(owner,entries.size());entries.push_back({std::move(retained),Var(args[1]),owner,next});}
  else{auto& entry=entries[found->second];if(next>entry.sequence){entry.packet=Var(args[1]);entry.sequence=next;}coalesced.fetch_add(1);}
  accepted.fetch_add(1);return true;
 }
 bool self(GDExtensionConstVariantPtr value){GDExtensionObjectPtr pointer=nullptr;if(get_type(value)!=GDEXTENSION_VARIANT_TYPE_OBJECT)return false;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&pointer,const_cast<void*>(value));return pointer==object;}
 void submit(GDExtensionConstVariantPtr held){
  if(!self(held)){error.store(1103);return;}
  int64_t open=0;if(!phase.compare_exchange_strong(open,1,std::memory_order_acq_rel))return;
  auto renderer=server.load(std::memory_order_acquire);if(!renderer){error.store(1104);entries.clear();indexes.clear();phase.store(2,std::memory_order_release);return;}
  // Ordinary Object-method Callable bound to self: Godot owns the lifetime of
  // this native target and its immutable packet/resource references in flight.
  Var command;destroy(command.data);const GDExtensionConstVariantPtr args[]={held,key("flush").data};GDExtensionCallError call_error{};
  construct(GDEXTENSION_VARIANT_TYPE_CALLABLE,command.data,args,2,&call_error);
  if(call_error.error!=GDEXTENSION_CALL_OK){new_nil(command.data);error.store(1105);return;}
  command=method(command,"bind",{Var(held)});
  alignas(8) uint8_t raw[16];to[GDEXTENSION_VARIANT_TYPE_CALLABLE](raw,command.data);
  const GDExtensionConstTypePtr arguments[]={raw};ptrcall(schedule_upload,renderer,arguments,nullptr);ptr_destructor(GDEXTENSION_VARIANT_TYPE_CALLABLE)(raw);
 }
 void flush(GDExtensionConstVariantPtr held){
  if(!self(held)||phase.load(std::memory_order_acquire)!=1){error.store(1106);return;}
  auto renderer=server.load(std::memory_order_acquire);GDExtensionObjectPtr device=nullptr;GDExtensionBool thread=false;
  if(renderer){ptrcall(is_render_thread,renderer,nullptr,&thread);if(thread)ptrcall(get_device,renderer,nullptr,&device);}
  if(!thread||!device)error.store(1107);
  else{for(auto& entry:entries)entry.owner->write(entry.packet.data,entry.sequence,renderer,device);submitted.store(static_cast<int64_t>(entries.size()));}
  entries.clear();indexes.clear();phase.store(2,std::memory_order_release);
 }
};
GDExtensionObjectPtr batch_create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnParticleUploadBatch");auto object=construct_object(base.data);auto batch=new Batch();batch->object=object;set_instance(object,name.data,batch);if(notify){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{Var::integer(0)});}return object;}
void batch_free(void*,GDExtensionClassInstancePtr instance){delete static_cast<Batch*>(instance);}
void batch_enqueue(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!count_ok(count,3,result,error))return;auto& batch=*static_cast<Batch*>(instance);bool accepted=false;try{accepted=batch.enqueue(args);}catch(...){batch.error.store(1108);}auto out=Var::boolean(accepted);new_copy(result,out.data);}
void batch_submit(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!count_ok(count,1,result,error))return;auto& batch=*static_cast<Batch*>(instance);try{batch.submit(args[0]);}catch(...){batch.error.store(1109);}new_nil(result);}
void batch_flush(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!count_ok(count,1,result,error))return;static_cast<Batch*>(instance)->flush(args[0]);new_nil(result);}
void batch_stats(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!count_ok(count,0,result,error))return;auto& batch=*static_cast<Batch*>(instance);auto out=Var::dictionary();set(out,"phase",Var::integer(batch.phase.load()));set(out,"accepted",Var::integer(batch.accepted.load()));set(out,"coalesced",Var::integer(batch.coalesced.load()));set(out,"submitted",Var::integer(batch.submitted.load()));set(out,"error",Var::integer(batch.error.load()));new_copy(result,out.data);}
template<typename Property>void register_owner(const Property& property){
 if(!bind())return;Name name("NwnParticleUpload"),base("RefCounted"),empty(""),configure_name("configure"),upload_name("upload"),cancel_name("cancel"),error_name("error"),stats_name("stats"),resource("resource"),capacity("capacity"),keepalive("keepalive"),packet("packet"),sequence("sequence");
 GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free;register_class(library,name.data,base.data,&info);registered=true;
 GDExtensionClassMethodArgumentMetadata metadata[3]{};GDExtensionClassMethodInfo method{};method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;method.arguments_metadata=metadata;
 GDExtensionPropertyInfo init_args[]={property(GDEXTENSION_VARIANT_TYPE_OBJECT,resource),property(GDEXTENSION_VARIANT_TYPE_INT,capacity)};
 method.name=configure_name.data;method.call_func=configure;method.argument_count=2;method.arguments_info=init_args;register_method(library,name.data,&method);
 GDExtensionPropertyInfo upload_args[]={property(GDEXTENSION_VARIANT_TYPE_OBJECT,keepalive),property(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,packet),property(GDEXTENSION_VARIANT_TYPE_INT,sequence)};
 method.name=upload_name.data;method.call_func=upload;method.argument_count=3;method.arguments_info=upload_args;register_method(library,name.data,&method);
 method.name=cancel_name.data;method.call_func=cancel;method.argument_count=0;method.arguments_info=nullptr;register_method(library,name.data,&method);
 auto integer=property(GDEXTENSION_VARIANT_TYPE_INT,empty);method.name=error_name.data;method.call_func=status;method.has_return_value=true;method.return_value_info=&integer;register_method(library,name.data,&method);
 auto dictionary=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);method.name=stats_name.data;method.call_func=stats;method.return_value_info=&dictionary;register_method(library,name.data,&method);
 Name batch_name("NwnParticleUploadBatch"),enqueue_name("enqueue"),submit_name("submit"),flush_name("flush");
 info.create_instance_func=batch_create;info.free_instance_func=batch_free;register_class(library,batch_name.data,base.data,&info);
 auto boolean=property(GDEXTENSION_VARIANT_TYPE_BOOL,empty);method.name=enqueue_name.data;method.call_func=batch_enqueue;method.return_value_info=&boolean;method.argument_count=3;method.arguments_info=upload_args;register_method(library,batch_name.data,&method);
 GDExtensionPropertyInfo held_arg[]={property(GDEXTENSION_VARIANT_TYPE_OBJECT,keepalive)};method.has_return_value=false;method.return_value_info=nullptr;method.argument_count=1;method.arguments_info=held_arg;
 method.name=submit_name.data;method.call_func=batch_submit;register_method(library,batch_name.data,&method);method.name=flush_name.data;method.call_func=batch_flush;register_method(library,batch_name.data,&method);
 method.name=stats_name.data;method.call_func=batch_stats;method.argument_count=0;method.arguments_info=nullptr;method.has_return_value=true;method.return_value_info=&dictionary;register_method(library,batch_name.data,&method);
}
void unregister_owner(){if(registered){Name batch("NwnParticleUploadBatch");unregister_class(library,batch.data);Name name("NwnParticleUpload");unregister_class(library,name.data);registered=false;}server=nullptr;}
} // namespace particle_upload
