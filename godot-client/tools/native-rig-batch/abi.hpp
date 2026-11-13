#pragma once
// Private optional library. Official GDExtension ABI only; no engine layouts.
#include "gdextension_interface.h"
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <array>
#include <cmath>
#include <cstdint>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>
namespace {
constexpr const char *CLASS="NwnRigAnimationBatch";
GDExtensionClassLibraryPtr library;
GDExtensionInterfaceVariantNewNil new_nil;
GDExtensionInterfaceVariantNewCopy new_copy;
GDExtensionInterfaceVariantDestroy destroy;
GDExtensionInterfaceVariantGetType get_type;
GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
GDExtensionInterfaceGetVariantToTypeConstructor to_type;
GDExtensionInterfaceVariantConstruct construct;
GDExtensionInterfaceVariantGetPtrDestructor destructor;
GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin_method;
GDExtensionInterfaceStringNameNewWithUtf8Chars name_new;
GDExtensionInterfaceStringNewWithUtf8Chars string_new;
GDExtensionInterfaceDictionaryOperatorIndexConst dictionary_at;
GDExtensionInterfaceVariantGetKeyed get_keyed;
GDExtensionInterfaceVariantSetKeyed set_keyed;
GDExtensionInterfaceVariantGetPtrUtilityFunction get_utility;
GDExtensionInterfaceArrayOperatorIndexConst array_at;
GDExtensionInterfaceClassdbConstructObject3 construct_object;
GDExtensionInterfaceObjectSetInstance set_instance;
GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;
GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
GDExtensionInterfaceClassdbGetMethodBind method_bind;
GDExtensionInterfaceObjectMethodBindPtrcall ptrcall;
GDExtensionInterfaceObjectGetInstanceId object_id;
GDExtensionInterfaceObjectGetInstanceFromId object_from_id;
GDExtensionInterfaceClassdbGetClassTag class_tag;
GDExtensionInterfaceObjectCastTo cast_to;
GDExtensionVariantFromTypeConstructorFunc from[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};
GDExtensionTypeFromVariantConstructorFunc to[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};
struct Name {
 alignas(8) uint8_t data[8]{};
 explicit Name(const char *text=""){name_new(data,text);}
 ~Name(){destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(data);}
 Name(const Name&)=delete;
};
struct Var {
 alignas(8) uint8_t data[24]{};
 Var(){new_nil(data);} explicit Var(GDExtensionConstVariantPtr p){new_copy(data,p);}
 Var(const Var& v){new_copy(data,v.data);} Var(Var&&v)noexcept{new_copy(data,v.data);}
 ~Var(){destroy(data);}
 Var&operator=(const Var&v){if(this!=&v){destroy(data);new_copy(data,v.data);}return *this;}
 void nil(){destroy(data);new_nil(data);}
 GDExtensionVariantType type()const{return get_type(data);}
 static Var integer(int64_t n){Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_INT](v.data,&n);return v;}
 static Var real(double n){Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_FLOAT](v.data,&n);return v;}
 static Var boolean(bool n){GDExtensionBool b=n;Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_BOOL](v.data,&b);return v;}
 static Var key(const char *text){Name n(text);Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_STRING_NAME](v.data,n.data);return v;}
 static Var text(const char *text){alignas(8)uint8_t s[8]{};string_new(s,text);Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_STRING](v.data,s);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(s);return v;}
 static Var container(GDExtensionVariantType type){Var v;destroy(v.data);GDExtensionCallError e{};construct(type,v.data,nullptr,0,&e);if(e.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("Container construction failed");return v;}
 int64_t integer()const{if(type()!=GDEXTENSION_VARIANT_TYPE_INT)throw std::runtime_error("Integer required");int64_t n=0;to[type()](&n,const_cast<uint8_t*>(data));return n;}
 bool numeric(double&n)const{if(type()==GDEXTENSION_VARIANT_TYPE_FLOAT){n=0;to[type()](&n,const_cast<uint8_t*>(data));return true;}if(type()==GDEXTENSION_VARIANT_TYPE_INT){n=static_cast<double>(integer());return true;}if(type()==GDEXTENSION_VARIANT_TYPE_BOOL){GDExtensionBool b=0;to[type()](&b,const_cast<uint8_t*>(data));n=b?1.0:0.0;return true;}return false;}
};
struct Raw {
 alignas(8)uint8_t data[64]{};GDExtensionVariantType type;
 explicit Raw(const Var&v,GDExtensionVariantType t):type(t){if(v.type()!=t)throw std::runtime_error("Container type differs");to[type](data,const_cast<uint8_t*>(v.data));}
 ~Raw(){destructor(type)(data);}Raw(const Raw&)=delete;
};
GDExtensionPtrBuiltInMethod array_size,array_append,dict_has,dict_typed,dict_read_only,name_empty;
GDExtensionPtrUtilityFunction valid_instance;
int64_t size(const Var&v){Raw r(v,GDEXTENSION_VARIANT_TYPE_ARRAY);int64_t n=0;array_size(r.data,nullptr,&n,0);return n;}
Var at(const Var&v,int64_t index){Raw r(v,GDEXTENSION_VARIANT_TYPE_ARRAY);if(index<0||index>=size(v))throw std::runtime_error("Array index unavailable");auto p=array_at(r.data,index);if(!p)throw std::runtime_error("Array row unavailable");return Var(p);}
bool has(const Var&v,const Var&key){Raw r(v,GDEXTENSION_VARIANT_TYPE_DICTIONARY);GDExtensionBool present=0;const GDExtensionConstTypePtr args[]={key.data};dict_has(r.data,args,&present,1);return present!=0;}
Var get(const Var&v,const Var&key){Var result;destroy(result.data);GDExtensionBool valid=0;get_keyed(v.data,key.data,result.data,&valid);return result;}
bool plain(const Var&v){if(v.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return false;Raw r(v,GDEXTENSION_VARIANT_TYPE_DICTIONARY);GDExtensionBool typed=0,read_only=0;dict_typed(r.data,nullptr,&typed,0);dict_read_only(r.data,nullptr,&read_only,0);return !typed&&!read_only;}
void put(Var&dict,const Var&key,const Var&value){GDExtensionBool valid=0;set_keyed(dict.data,key.data,value.data,&valid);if(!valid)throw std::runtime_error("Dictionary assignment failed");}
void put(Var&dict,const char *key,const Var&value){const auto k=Var::key(key);put(dict,k,value);}
void append(Var&array,const Var&value){if(array.type()==GDEXTENSION_VARIANT_TYPE_NIL)array=Var::container(GDEXTENSION_VARIANT_TYPE_ARRAY);Raw r(array,GDEXTENSION_VARIANT_TYPE_ARRAY);const GDExtensionConstTypePtr args[]={value.data};array_append(r.data,args,nullptr,1);}
struct Keys {
 Var models=Var::key("models"),native_owner=Var::key("native_owner"),player=Var::key("player"),serial=Var::key("play_serial"),speed=Var::key("speed"),clip=Var::key("clip"),events=Var::key("events"),last_time=Var::key("last_time"),time=Var::key("time"),name=Var::key("name");
};
std::unique_ptr<Keys> keys;
GDExtensionMethodBindPtr advance_bind,is_playing_bind,current_bind,position_bind,length_bind,script_bind;
void *player_tag=nullptr;DWORD main_thread=0;bool registered=false;
bool alive(GDExtensionObjectPtr object,GDObjectInstanceID id){return id!=0&&object_from_id(id)==object;}
bool playing(GDExtensionObjectPtr object){GDExtensionBool result=0;ptrcall(is_playing_bind,object,nullptr,&result);return result!=0;}
bool empty_animation(GDExtensionObjectPtr object){Name result;ptrcall(current_bind,object,nullptr,result.data);GDExtensionBool empty=0;name_empty(result.data,nullptr,&empty,0);return empty!=0;}
bool valid_object(const Var&v){GDExtensionBool result=0;const GDExtensionConstTypePtr args[]={v.data};valid_instance(&result,args,1);return result!=0;}
bool scripted(GDExtensionObjectPtr object){Var result;ptrcall(script_bind,object,nullptr,result.data);return result.type()!=GDEXTENSION_VARIANT_TYPE_NIL&&(result.type()!=GDEXTENSION_VARIANT_TYPE_OBJECT||valid_object(result));}
double clock_value(GDExtensionMethodBindPtr bind,GDExtensionObjectPtr object){double result=0;ptrcall(bind,object,nullptr,&result);return result;}
GDExtensionObjectPtr player_object(const Var&v){if(v.type()!=GDEXTENSION_VARIANT_TYPE_OBJECT||!valid_object(v))return nullptr;GDExtensionObjectPtr object=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&object,const_cast<uint8_t*>(v.data));if(!object)return nullptr;const auto id=object_id(object);return alive(object,id)&&cast_to(object,player_tag)==object?object:nullptr;}
} // private namespace
