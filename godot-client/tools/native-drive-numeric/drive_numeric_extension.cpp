// Optional isolated data-only GDExtension. Never include/register this through
// the shared particle DLL. Build privately and accept frozen oracles first.
#include "gdextension_interface.h"
#include "drive_clear_kernel.hpp"
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <array>
#include <cstdint>
#include <limits>
#include <mutex>
#include <string>
#include <vector>
namespace {
constexpr const char* CLASS="NwnDriveNumericBatch";
constexpr const char* SCHEMA="nwn-drive-numeric-v1";
GDExtensionClassLibraryPtr library;
GDExtensionInterfaceVariantNewNil new_nil;
GDExtensionInterfaceVariantNewCopy new_copy;
GDExtensionInterfaceVariantDestroy destroy;
GDExtensionInterfaceVariantGetType get_type;
GDExtensionInterfaceVariantGetKeyed get_keyed;
GDExtensionInterfaceVariantSetKeyed set_keyed;
GDExtensionInterfaceVariantGetIndexed get_indexed;
GDExtensionInterfaceVariantCall variant_call;
GDExtensionInterfaceVariantConstruct construct;
GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
GDExtensionInterfaceGetVariantToTypeConstructor to_type;
GDExtensionInterfaceVariantGetPtrDestructor destructor;
GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin_method;
GDExtensionInterfaceVariantGetPtrOperatorEvaluator operator_evaluator;
GDExtensionInterfaceStringNameNewWithUtf8Chars name_new;
GDExtensionInterfaceStringNewWithUtf8Chars string_new;
GDExtensionInterfaceStringToUtf8Chars string_utf8;
GDExtensionInterfaceClassdbConstructObject3 construct_object;
GDExtensionInterfaceObjectSetInstance set_instance;
GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;
GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
GDExtensionVariantFromTypeConstructorFunc from[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};
GDExtensionTypeFromVariantConstructorFunc to[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};
struct Name{alignas(8) uint8_t data[8]{};explicit Name(const char* text){name_new(data,text);}~Name(){destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(data);}Name(const Name&)=delete;};
struct Var{
 alignas(8) uint8_t data[24]{};
 Var(){new_nil(data);}explicit Var(GDExtensionConstVariantPtr source){new_copy(data,source);}Var(const Var& other){new_copy(data,other.data);}Var(Var&& other)noexcept{new_copy(data,other.data);}~Var(){destroy(data);}
 Var& operator=(const Var& other){if(this!=&other){destroy(data);new_copy(data,other.data);}return *this;}
 GDExtensionVariantType type()const{return get_type(data);}
 static Var integer(int64_t value){Var out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_INT](out.data,&value);return out;}
 static Var boolean(bool value){GDExtensionBool v=value;Var out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_BOOL](out.data,&v);return out;}
 static Var text(const char* value){alignas(8)uint8_t raw[8]{};string_new(raw,value);Var out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_STRING](out.data,raw);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(raw);return out;}
 static Var container(GDExtensionVariantType type){Var out;destroy(out.data);GDExtensionCallError error{};construct(type,out.data,nullptr,0,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("Container construction failed");return out;}
 int64_t integer()const{if(type()!=GDEXTENSION_VARIANT_TYPE_INT)throw std::runtime_error("Integer required");int64_t out=0;to[type()](&out,const_cast<uint8_t*>(data));return out;}
 bool boolean()const{if(type()!=GDEXTENSION_VARIANT_TYPE_BOOL)throw std::runtime_error("Boolean required");GDExtensionBool out=0;to[type()](&out,const_cast<uint8_t*>(data));return out!=0;}
 double number()const{if(type()==GDEXTENSION_VARIANT_TYPE_FLOAT){double out=0;to[type()](&out,const_cast<uint8_t*>(data));return out;}if(type()==GDEXTENSION_VARIANT_TYPE_INT)return static_cast<double>(integer());throw std::runtime_error("Numeric query value required");}
 std::string text()const{if(type()!=GDEXTENSION_VARIANT_TYPE_STRING)throw std::runtime_error("String required");alignas(8)uint8_t raw[8]{};to[type()](raw,const_cast<uint8_t*>(data));const auto count=string_utf8(raw,nullptr,0);std::string value(static_cast<size_t>(count),'\0');string_utf8(raw,value.data(),count);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(raw);return value;}
};
Var key(const char* field){Name name(field);Var out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_STRING_NAME](out.data,name.data);return out;}
Var get(const Var& input,const char* field){if(input.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Dictionary required");const auto name=key(field);Var out;destroy(out.data);GDExtensionBool valid=0;get_keyed(input.data,name.data,out.data,&valid);if(!valid)throw std::runtime_error("Required field absent");return out;}
void put(Var& output,const char* field,const Var& value){const auto name=key(field);GDExtensionBool valid=0;set_keyed(output.data,name.data,value.data,&valid);if(!valid)throw std::runtime_error("Result assignment failed");}
Var call(const Var& input,const char* method,const std::vector<const Var*>& values={}){Name name(method);std::vector<GDExtensionConstVariantPtr> args;for(auto* value:values)args.push_back(value->data);Var out;destroy(out.data);GDExtensionCallError error{};variant_call(const_cast<uint8_t*>(input.data),name.data,args.data(),static_cast<GDExtensionInt>(args.size()),out.data,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("Builtin call failed");return out;}
Var at(const Var& rows,int64_t index){Var out;destroy(out.data);GDExtensionBool valid=0,oob=0;get_indexed(rows.data,index,out.data,&valid,&oob);if(!valid||oob)throw std::runtime_error("Triangle index unavailable");return out;}
Var output(bool supported){auto out=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);put(out,"version",Var::integer(1));put(out,"schema",Var::text(SCHEMA));put(out,"supported",Var::boolean(supported));return out;}
Var unsupported(const char* reason){auto out=output(false);put(out,"reason",Var::text(reason));return out;}
void schema(const Var& input){if(get(input,"version").integer()!=1||get(input,"schema").text()!=SCHEMA)throw std::runtime_error("Unsupported numeric schema");}
using V2=drive_clear_kernel::V2;
GDExtensionPtrOperatorEvaluator subtract,add,multiply;
GDExtensionPtrBuiltInMethod dot,length_squared,distance_squared;
bool math_ready=false,registered=false;
struct Math{
 V2 sub(const V2&a,const V2&b)const{V2 out{};subtract(a.data(),b.data(),out.data());return out;}
 V2 add(const V2&a,const V2&b)const{V2 out{};::add(a.data(),b.data(),out.data());return out;}
 V2 mul(const V2&a,double scale)const{V2 out{};multiply(a.data(),&scale,out.data());return out;}
 double dot(const V2&a,const V2&b)const{double out=0;const GDExtensionConstTypePtr args[]={b.data()};::dot(const_cast<float*>(a.data()),args,&out,1);return out;}
 double length_squared(const V2&a)const{double out=0;::length_squared(const_cast<float*>(a.data()),nullptr,&out,0);return out;}
 double distance_squared(const V2&a,const V2&b)const{double out=0;const GDExtensionConstTypePtr args[]={b.data()};::distance_squared(const_cast<float*>(a.data()),args,&out,1);return out;}
};
template<size_t N>std::array<float,N> vector(const Var& value,GDExtensionVariantType type){if(value.type()!=type)throw std::runtime_error("Typed vector required");std::array<float,N> out{};to[type](out.data(),const_cast<uint8_t*>(value.data));for(float v:out)drive_clear_kernel::finite(v);return out;}
struct Owner{
 std::mutex mutex;drive_clear_kernel::Batch batch;
 Var configure(const Var& input){
  batch.clear();schema(input);if(!math_ready)return unsupported("Engine math unavailable");
  const auto rows=get(input,"triangles");if(rows.type()!=GDEXTENSION_VARIANT_TYPE_ARRAY)throw std::runtime_error("Triangle array required");
  const auto tile=get(input,"tile").boolean();const auto bound=get(input,"maximum_bytes").integer();
  auto size=call(rows,"size");const auto count=size.integer();
  if(bound<1||bound>64*1024*1024||count<0||count>2000000||static_cast<uint64_t>(bound)<sizeof(drive_clear_kernel::Batch)||static_cast<uint64_t>(count)>(static_cast<uint64_t>(bound)-sizeof(drive_clear_kernel::Batch))/sizeof(drive_clear_kernel::Face))throw std::runtime_error("Numeric payload exceeds bound");
  std::vector<drive_clear_kernel::Face> faces;faces.reserve(static_cast<size_t>(count));
  for(int64_t index=0;index<count;++index){const auto row=at(rows,index);drive_clear_kernel::Face face;face.a=vector<3>(get(row,"a"),GDEXTENSION_VARIANT_TYPE_VECTOR3);face.b=vector<3>(get(row,"b"),GDEXTENSION_VARIANT_TYPE_VECTOR3);face.c=vector<3>(get(row,"c"),GDEXTENSION_VARIANT_TYPE_VECTOR3);face.minimum=vector<3>(get(row,"min"),GDEXTENSION_VARIANT_TYPE_VECTOR3);face.maximum=vector<3>(get(row,"max"),GDEXTENSION_VARIANT_TYPE_VECTOR3);if(tile)face.walk=get(row,"walk").boolean();faces.push_back(face);}
  batch.configure(std::move(faces),tile,static_cast<size_t>(bound));auto out=output(true);put(out,"faces",Var::integer(static_cast<int64_t>(batch.faces.size())));put(out,"payload_bytes",Var::integer(static_cast<int64_t>(batch.payload_bytes())));put(out,"tile",Var::boolean(tile));return out;
 }
 Var query(const Var& input,bool tile){
  schema(input);if(!math_ready)return unsupported("Engine math unavailable");const auto a=vector<2>(get(input,"a"),GDEXTENSION_VARIANT_TYPE_VECTOR2),b=vector<2>(get(input,"b"),GDEXTENSION_VARIANT_TYPE_VECTOR2);const double radius=get(input,"radius").number(),low=get(input,"low").number(),high=get(input,"high").number();auto out=output(true);
  if(tile){const auto result=batch.floor(a,b,radius,low,high,Math{});auto intervals=Var::container(GDEXTENSION_VARIANT_TYPE_ARRAY);for(const auto& span:result.intervals){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_VECTOR2](value.data,const_cast<float*>(span.data()));call(intervals,"append",{&value});}put(out,"blocked",Var::boolean(result.blocked));put(out,"intervals",intervals);}
  else put(out,"blocked",Var::boolean(batch.obstacle(a,b,radius,low,high,Math{})));
  return out;
 }
};
std::string module_path(){
 HMODULE module=nullptr;
 if(!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,reinterpret_cast<LPCWSTR>(&module_path),&module))return {};
 std::array<wchar_t,32768> path{};
 const DWORD size=GetModuleFileNameW(module,path.data(),static_cast<DWORD>(path.size()));
 if(size==0||size>=path.size())return {};
 const int bytes=WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,path.data(),static_cast<int>(size),nullptr,0,nullptr,nullptr);
 if(bytes<=0)return {};
 std::string result(static_cast<size_t>(bytes),'\0');
 if(WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,path.data(),static_cast<int>(size),result.data(),bytes,nullptr,nullptr)!=bytes)return {};
 return result;
}
Var capability(){auto out=output(math_ready);put(out,"abi",Var::integer(1));put(out,"float_bytes",Var::integer(sizeof(float)));put(out,"double_bytes",Var::integer(sizeof(double)));put(out,"math",Var::text("engine-vector2-f32-strict-f64"));put(out,"floor",Var::boolean(true));put(out,"obstacle",Var::boolean(true));put(out,"height",Var::boolean(false));put(out,"module_path",Var::text(module_path().c_str()));return out;}
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name(CLASS);auto object=construct_object(base.data);if(!object)return nullptr;auto* owner=new Owner();set_instance(object,name.data,owner);if(notify){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);const auto what=Var::integer(0);call(value,"notification",{&what});}return object;}
void free_owner(void*,GDExtensionClassInstancePtr instance){delete static_cast<Owner*>(instance);}
void dispatch(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=2){error->error=count<2?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=2;new_nil(result);return;}
 try{auto& owner=*static_cast<Owner*>(instance);std::lock_guard<std::mutex> guard(owner.mutex);const Var operation(args[0]),input(args[1]);auto out=output(false);switch(operation.integer()){case 0:out=capability();break;case 1:out=owner.configure(input);break;case 2:out=owner.query(input,true);break;case 3:out=owner.query(input,false);break;case 5:schema(input);owner.batch.clear();out=output(true);break;case 6:schema(input);out=output(true);put(out,"configured",Var::boolean(owner.batch.configured));put(out,"payload_bytes",Var::integer(static_cast<int64_t>(owner.batch.payload_bytes())));break;default:out=unsupported("Operation unsupported; height remains on script");break;}new_copy(result,out.data);}
 catch(const std::exception& failure){auto out=unsupported(failure.what());new_copy(result,out.data);}
}
void initialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 Name dot_name("dot"),length_name("length_squared"),distance_name("distance_squared_to");subtract=operator_evaluator(GDEXTENSION_VARIANT_OP_SUBTRACT,GDEXTENSION_VARIANT_TYPE_VECTOR2,GDEXTENSION_VARIANT_TYPE_VECTOR2);add=operator_evaluator(GDEXTENSION_VARIANT_OP_ADD,GDEXTENSION_VARIANT_TYPE_VECTOR2,GDEXTENSION_VARIANT_TYPE_VECTOR2);multiply=operator_evaluator(GDEXTENSION_VARIANT_OP_MULTIPLY,GDEXTENSION_VARIANT_TYPE_VECTOR2,GDEXTENSION_VARIANT_TYPE_FLOAT);dot=builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,dot_name.data,3819070308LL);length_squared=builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,length_name.data,466405837LL);distance_squared=builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,distance_name.data,3819070308LL);math_ready=subtract&&add&&multiply&&dot&&length_squared&&distance_squared&&sizeof(float)==4&&sizeof(double)==8&&std::numeric_limits<float>::is_iec559&&std::numeric_limits<double>::is_iec559;
 Name name(CLASS),base("RefCounted"),method("dispatch"),empty(""),operation("operation"),input("input");alignas(8)uint8_t hint[8]{};string_new(hint,"");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free_owner;register_class(library,name.data,base.data,&info);registered=true;
 const auto property=[&](GDExtensionVariantType type,Name& value){GDExtensionPropertyInfo p{};p.type=type;p.name=value.data;p.class_name=empty.data;p.hint_string=hint;p.usage=6;return p;};auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);GDExtensionPropertyInfo arguments[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo m{};m.name=method.data;m.call_func=dispatch;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=2;m.arguments_info=arguments;m.arguments_metadata=metadata;register_method(library,name.data,&m);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(hint);
}
void deinitialize(void*,GDExtensionInitializationLevel level){if(level==GDEXTENSION_INITIALIZATION_SCENE&&registered){Name name(CLASS);unregister_class(library,name.data);registered=false;math_ready=false;}}
}
extern "C" __declspec(dllexport) GDExtensionBool nwn_drive_numeric_init(GDExtensionInterfaceGetProcAddress address,GDExtensionClassLibraryPtr own_library,GDExtensionInitialization* init){
 library=own_library;
#define API(target,type,name) target=reinterpret_cast<type>(address(name));if(!target)return false
 API(new_nil,GDExtensionInterfaceVariantNewNil,"variant_new_nil");API(new_copy,GDExtensionInterfaceVariantNewCopy,"variant_new_copy");API(destroy,GDExtensionInterfaceVariantDestroy,"variant_destroy");API(get_type,GDExtensionInterfaceVariantGetType,"variant_get_type");API(get_keyed,GDExtensionInterfaceVariantGetKeyed,"variant_get_keyed");API(set_keyed,GDExtensionInterfaceVariantSetKeyed,"variant_set_keyed");API(get_indexed,GDExtensionInterfaceVariantGetIndexed,"variant_get_indexed");API(variant_call,GDExtensionInterfaceVariantCall,"variant_call");API(construct,GDExtensionInterfaceVariantConstruct,"variant_construct");API(from_type,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor");API(to_type,GDExtensionInterfaceGetVariantToTypeConstructor,"get_variant_to_type_constructor");API(destructor,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor");API(builtin_method,GDExtensionInterfaceVariantGetPtrBuiltinMethod,"variant_get_ptr_builtin_method");API(operator_evaluator,GDExtensionInterfaceVariantGetPtrOperatorEvaluator,"variant_get_ptr_operator_evaluator");API(name_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars");API(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");API(string_utf8,GDExtensionInterfaceStringToUtf8Chars,"string_to_utf8_chars");API(construct_object,GDExtensionInterfaceClassdbConstructObject3,"classdb_construct_object3");API(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance");API(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass6,"classdb_register_extension_class6");API(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");API(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");
#undef API
 for(int index=1;index<GDEXTENSION_VARIANT_TYPE_VARIANT_MAX;++index){from[index]=from_type(static_cast<GDExtensionVariantType>(index));to[index]=to_type(static_cast<GDExtensionVariantType>(index));}
 init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=nullptr;return true;
}
