// SOURCE-ONLY integration adapter, not built/staged. Included after Var/API
// helpers inside the private particle kernel. The verified pure kernel and
// <thread> must be included OUTSIDE that translation unit's anonymous namespace.
namespace terrain_height_native {
GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst float64_read=nullptr;
bool registered=false;
constexpr size_t input_bound=16*1024*1024;
void bind(GDExtensionInterfaceGetProcAddress address){float64_read=reinterpret_cast<GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst>(address("packed_float64_array_operator_index_const"));}
// Do not populate the unrelated shared worker dictionary-key cache.
Var field(const char*name){Name key_name(name);Var key_value;destroy(key_value.data);from[GDEXTENSION_VARIANT_TYPE_STRING_NAME](key_value.data,key_name.data);return key_value;}
Var read(const Var&source,const char*name){if(source.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Height configure dictionary required");const auto key_value=field(name);Var out;destroy(out.data);GDExtensionBool valid=0;get_keyed(source.data,key_value.data,out.data,&valid);if(!valid)throw std::runtime_error("Height configure field unavailable");return out;}
void write(Var&target,const char*name,const Var&value){const auto key_value=field(name);GDExtensionBool valid=0;set_keyed(target.data,key_value.data,value.data,&valid);if(!valid)throw std::runtime_error("Height diagnostic publication failed");}
Var unavailable(int64_t reason){auto out=Var::dictionary();write(out,"supported",Var::boolean(false));write(out,"reason",Var::integer(reason));return out;}
template<GDExtensionVariantType Type>struct Packed {
 alignas(8) uint8_t data[16];
 explicit Packed(const Var&value){to[Type](data,const_cast<uint8_t*>(value.data));}
 ~Packed(){ptr_destructor(Type)(data);}
 Packed(const Packed&)=delete;Packed&operator=(const Packed&)=delete;
};
struct Owner {
 enum class State:int64_t{fresh=0,configured=1,retired=2};
 const std::thread::id thread=std::this_thread::get_id();
 drive_height_kernel::Batch batch;
 State state=State::fresh;
 uint64_t configurations=0,queries=0,unsupported_queries=0;
 int64_t last_failure=0;
 bool on_owner_thread()const{return thread==std::this_thread::get_id();}
 size_t payload_bytes()const{return sizeof(Owner)+batch.payload_bytes()-sizeof(drive_height_kernel::Batch);}
 Var configure(const Var&input){
  if(!on_owner_thread())return unavailable(2);
  if(state!=State::fresh)return unavailable(1);
  ++configurations;
  // Failed configuration is terminal too: no old handle can be rebound.
  state=State::retired;
  try{
   if(!float64_read||!packed_bytes_read){last_failure=3;return unavailable(3);}
   auto numbers=read(input,"faces"),mask=read(input,"walk");
   if(numbers.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY||mask.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)throw std::runtime_error("Height numeric stream type invalid");
   const auto limit=read(input,"maximum_bytes").integer();
   const int64_t count=size(numbers),flags=size(mask);
   if(limit<1||limit>128*1024*1024||count<0||count%10||flags<0||flags!=count/10||static_cast<uint64_t>(count)>input_bound/sizeof(double)||static_cast<uint64_t>(count)*sizeof(double)+static_cast<uint64_t>(flags)>input_bound)throw std::runtime_error("Height numeric stream dimensions/bounds invalid");
   const size_t overhead=sizeof(Owner)-sizeof(drive_height_kernel::Batch);
   if(static_cast<uint64_t>(limit)<=overhead)throw std::runtime_error("Height owner exceeds payload bound");
   std::vector<drive_height_kernel::SourceFace> faces;faces.reserve(static_cast<size_t>(flags));
   {
    // Own these immutable packed references while borrowing their numeric
    // data. No pointer survives mutation, an engine call or this scope.
    const Packed<GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY> packed_numbers(numbers);
    const Packed<GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY> packed_mask(mask);
    const double*values=count?float64_read(packed_numbers.data,0):nullptr;
    const uint8_t*walk=flags?packed_bytes_read(packed_mask.data,0):nullptr;
    if((count&&!values)||(flags&&!walk))throw std::runtime_error("Height numeric stream unavailable");
    for(int64_t index=0;index<flags;++index){if(walk[index]>1)throw std::runtime_error("Height walk classification invalid");drive_height_kernel::SourceFace value;const auto base=index*10;
     for(size_t corner=0;corner<3;++corner)for(size_t axis=0;axis<2;++axis)value.points[corner][axis]=values[base+static_cast<int64_t>(corner*2+axis)];
     for(size_t axis=0;axis<3;++axis)value.normal[axis]=values[base+6+static_cast<int64_t>(axis)];
     value.constant=values[base+9];value.walkable=walk[index]!=0;faces.push_back(value);
    }
   }
   batch.configure(faces,static_cast<size_t>(limit)-overhead);state=State::configured;
   auto out=Var::dictionary();write(out,"supported",Var::boolean(true));write(out,"faces",Var::integer(static_cast<int64_t>(batch.size())));write(out,"payload_bytes",Var::integer(static_cast<int64_t>(payload_bytes())));return out;
  }catch(const drive_height_kernel::Unsupported&){last_failure=5;batch.clear();state=State::retired;return unavailable(5);}
   catch(const std::exception&){last_failure=4;batch.clear();state=State::retired;return unavailable(4);}
 }
 Var query(const Var&x,const Var&y){
  if(!on_owner_thread())return {};
  ++queries;
  if(state!=State::configured){++unsupported_queries;return {};}
  try{return Var::number(batch.height(x.number(),y.number()).height);}
  catch(const std::exception&){++unsupported_queries;last_failure=6;return {};}
 }
 void retire(){if(!on_owner_thread())return;batch.clear();state=State::retired;}
 Var snapshot()const{
  if(!on_owner_thread())return unavailable(2);
  auto out=Var::dictionary();write(out,"state",Var::integer(static_cast<int64_t>(state)));write(out,"faces",Var::integer(static_cast<int64_t>(batch.size())));write(out,"payload_bytes",Var::integer(static_cast<int64_t>(payload_bytes())));write(out,"configurations",Var::integer(static_cast<int64_t>(configurations)));write(out,"queries",Var::integer(static_cast<int64_t>(queries)));write(out,"unsupported_queries",Var::integer(static_cast<int64_t>(unsupported_queries)));write(out,"last_failure",Var::integer(last_failure));return out;
 }
};
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnTerrainHeight");auto object=construct_object(base.data);auto*owner=new Owner();set_instance(object,name.data,owner);if(notify){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{Var::integer(0)});}return object;}
void free_owner(void*,GDExtensionClassInstancePtr instance){delete static_cast<Owner*>(instance);}
bool arity(GDExtensionInt count,int expected,GDExtensionVariantPtr result,GDExtensionCallError*error){error->error=GDEXTENSION_CALL_OK;if(count==expected)return true;error->error=count<expected?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=expected;new_nil(result);return false;}
void configure_call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError*error){if(!arity(count,1,result,error))return;try{Var input(args[0]);auto value=static_cast<Owner*>(instance)->configure(input);new_copy(result,value.data);}catch(const std::exception&){new_nil(result);}}
void query_call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError*error){if(!arity(count,2,result,error))return;try{Var x(args[0]),y(args[1]);auto value=static_cast<Owner*>(instance)->query(x,y);new_copy(result,value.data);}catch(const std::exception&){new_nil(result);}}
void retire_call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError*error){if(!arity(count,0,result,error))return;static_cast<Owner*>(instance)->retire();new_nil(result);}
void snapshot_call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError*error){if(!arity(count,0,result,error))return;try{auto value=static_cast<Owner*>(instance)->snapshot();new_copy(result,value.data);}catch(const std::exception&){new_nil(result);}}
template<typename Property>void register_owner(const Property&property){
 if(!float64_read)return;
 Name name("NwnTerrainHeight"),base("RefCounted"),empty(""),input("input"),x("x"),y("y");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free_owner;register_class(library,name.data,base.data,&info);registered=true;
 auto ret=property(GDEXTENSION_VARIANT_TYPE_NIL,empty);ret.usage|=131072;
 GDExtensionPropertyInfo configure_args[]={property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata configure_metadata[1]{};
 Name configure_name("configure");GDExtensionClassMethodInfo m{};m.name=configure_name.data;m.call_func=configure_call;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=1;m.arguments_info=configure_args;m.arguments_metadata=configure_metadata;register_method(library,name.data,&m);
 GDExtensionPropertyInfo query_args[]={property(GDEXTENSION_VARIANT_TYPE_FLOAT,x),property(GDEXTENSION_VARIANT_TYPE_FLOAT,y)};GDExtensionClassMethodArgumentMetadata query_metadata[2]{};
 Name query_name("query");m.name=query_name.data;m.call_func=query_call;m.argument_count=2;m.arguments_info=query_args;m.arguments_metadata=query_metadata;register_method(library,name.data,&m);
 Name retire_name("retire");m.name=retire_name.data;m.call_func=retire_call;m.argument_count=0;m.arguments_info=nullptr;m.arguments_metadata=nullptr;register_method(library,name.data,&m);
 Name snapshot_name("snapshot");m.name=snapshot_name.data;m.call_func=snapshot_call;register_method(library,name.data,&m);
}
void unregister_owner(){if(!registered)return;Name name("NwnTerrainHeight");unregister_class(library,name.data);registered=false;float64_read=nullptr;}
}
