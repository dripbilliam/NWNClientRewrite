// World diagnostics retain IDs and fixed integer records, never Nodes,
// particle owners, or render resources. Main-thread updates replace the GD
// per-field delta loop; snapshots cross the engine boundary only on request.
namespace particle_counters {
constexpr size_t fields=15;
GDExtensionInterfacePackedInt64ArrayOperatorIndex packed_write;
GDExtensionInterfacePackedInt64ArrayOperatorIndexConst packed_read;
GDExtensionPtrBuiltInMethod packed_size,packed_resize;
bool registered=false;
struct Owner {
 GDExtensionObjectPtr identity=nullptr;
 std::unordered_map<int64_t,std::array<int64_t,fields>> entries;
 std::array<int64_t,fields> sums{};bool closed=false;int64_t error=0;
 bool insert(int64_t id){if(closed)return false;return entries.emplace(id,std::array<int64_t,fields>{}).second;}
 static void delta(int64_t& sum,int64_t next,int64_t prior){
  // Match the engine's two's-complement integer counters without C++ signed
  // overflow; ordinary counts are nonnegative and well below this boundary.
  uint64_t result=static_cast<uint64_t>(sum)+static_cast<uint64_t>(next)-static_cast<uint64_t>(prior);std::memcpy(&sum,&result,8);
 }
 void store_record(std::array<int64_t,fields>& record,const int64_t* values){for(size_t n=0;n<fields;++n){delta(sums[n],values[n],record[n]);record[n]=values[n];}}
 bool store(int64_t id,const int64_t* values){if(closed)return false;auto found=entries.find(id);if(found==entries.end()){error=1201;return false;}store_record(found->second,values);return true;}
 // A scene callback may remove this record before the ordered presentation
 // pass reaches it. Skip that source without looking the same id up twice.
 template<class MakeValues>bool store_if_present(int64_t id,MakeValues&& make_values){auto found=entries.find(id);if(found==entries.end())return true;if(closed)return false;const auto values=make_values();store_record(found->second,values.data());return true;}
 bool update(int64_t id,GDExtensionConstVariantPtr packet){
  if(closed)return false;auto found=entries.find(id);if(found==entries.end()){error=1201;return false;}
  if(get_type(packet)!=GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY){error=1202;return false;}
  alignas(8) uint8_t raw[16];to[GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY](raw,const_cast<void*>(packet));
  struct Guard {void* raw;~Guard(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY)(raw);}}guard{raw};
  int64_t count=0;packed_size(raw,nullptr,&count,0);if(count!=static_cast<int64_t>(fields)){error=1203;return false;}
  const auto* values=packed_read(raw,0);if(!values){error=1204;return false;}
  return store(id,values);
 }
 bool erase(int64_t id){if(closed)return false;auto found=entries.find(id);if(found==entries.end())return false;for(size_t n=0;n<fields;++n)delta(sums[n],0,found->second[n]);entries.erase(found);return true;}
 Var snapshot()const{
  alignas(8) uint8_t raw[16];ptr_constructor(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,0)(raw,nullptr);
  struct Guard {void* raw;~Guard(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY)(raw);}}guard{raw};
  int64_t count=fields,result=-1;const GDExtensionConstTypePtr args[]={&count};packed_resize(raw,args,&result,1);if(result!=0)throw std::runtime_error("Native particle counter snapshot allocation failed");
  std::copy(sums.begin(),sums.end(),packed_write(raw,0));Var out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY](out.data,raw);return out;
 }
};
std::mutex registry_mutex;std::unordered_map<GDExtensionObjectPtr,Owner*> registry;
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnParticleCounters");auto object=construct_object(base.data);auto owner=new Owner();owner->identity=object;set_instance(object,name.data,owner);{std::lock_guard<std::mutex> lock(registry_mutex);registry.emplace(object,owner);}if(notify){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{Var::integer(0)});}return object;}
void free(void*,GDExtensionClassInstancePtr instance){auto* owner=static_cast<Owner*>(instance);{std::lock_guard<std::mutex> lock(registry_mutex);registry.erase(owner->identity);}delete owner;}
bool id(const GDExtensionConstVariantPtr* args,int64_t& result){if(get_type(args[0])!=GDEXTENSION_VARIANT_TYPE_INT)return false;to[GDEXTENSION_VARIANT_TYPE_INT](&result,const_cast<void*>(args[0]));return true;}
void insert(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,1,result,error))return;int64_t key=0;auto out=Var::boolean(id(args,key)&&static_cast<Owner*>(instance)->insert(key));new_copy(result,out.data);}
void update(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,2,result,error))return;int64_t key=0;auto out=Var::boolean(id(args,key)&&static_cast<Owner*>(instance)->update(key,args[1]));new_copy(result,out.data);}
void erase(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,1,result,error))return;int64_t key=0;auto out=Var::boolean(id(args,key)&&static_cast<Owner*>(instance)->erase(key));new_copy(result,out.data);}
void snapshot(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,0,result,error))return;auto out=static_cast<Owner*>(instance)->snapshot();new_copy(result,out.data);}
void close(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,0,result,error))return;auto& owner=*static_cast<Owner*>(instance);owner.closed=true;owner.entries.clear();owner.sums={};new_nil(result);}
void status(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,0,result,error))return;auto out=Var::integer(static_cast<Owner*>(instance)->error);new_copy(result,out.data);}
template<typename Property>void register_owner(const Property& property){
 if(!packed_write||!packed_read)return;Name array_name("PackedInt64Array"),size_name("size"),resize_name("resize");packed_size=builtin_method(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,size_name.data,3173160232);packed_resize=builtin_method(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,resize_name.data,848867239);if(!packed_size||!packed_resize)return;
 Name name("NwnParticleCounters"),base("RefCounted"),empty(""),insert_name("register_id"),update_name("update"),erase_name("remove_id"),snapshot_name("snapshot"),close_name("close"),error_name("error"),identity("identity"),values("values");
 GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free;register_class(library,name.data,base.data,&info);registered=true;
 GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,identity),property(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,values)};auto boolean=property(GDEXTENSION_VARIANT_TYPE_BOOL,empty);
 GDExtensionClassMethodInfo method{};method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;method.arguments_metadata=metadata;method.has_return_value=true;method.return_value_info=&boolean;method.arguments_info=args;method.argument_count=1;
 method.name=insert_name.data;method.call_func=insert;register_method(library,name.data,&method);method.name=erase_name.data;method.call_func=erase;register_method(library,name.data,&method);
 method.name=update_name.data;method.call_func=update;method.argument_count=2;register_method(library,name.data,&method);
 auto packed=property(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,empty);method.name=snapshot_name.data;method.call_func=snapshot;method.argument_count=0;method.arguments_info=nullptr;method.return_value_info=&packed;register_method(library,name.data,&method);
 auto integer=property(GDEXTENSION_VARIANT_TYPE_INT,empty);method.name=error_name.data;method.call_func=status;method.return_value_info=&integer;register_method(library,name.data,&method);
 method.name=close_name.data;method.call_func=close;method.has_return_value=false;method.return_value_info=nullptr;register_method(library,name.data,&method);
}
void unregister_owner(){if(registered){Name name("NwnParticleCounters");unregister_class(library,name.data);registered=false;}}
} // namespace particle_counters
