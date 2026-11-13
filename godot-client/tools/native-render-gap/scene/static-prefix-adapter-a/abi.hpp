// Optional isolated data-only GDExtension. Never include/register this through
// the shared particle DLL. Build privately and accept frozen oracles first.
#include "gdextension_interface.h"
#include <stdexcept>
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
constexpr const char* CLASS="NwnStaticPrefixCursor";
constexpr const char* SCHEMA="nwn-static-prefix-cursor-v1";
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

} // private ABI namespace, reopened by cursor_extension.cpp
