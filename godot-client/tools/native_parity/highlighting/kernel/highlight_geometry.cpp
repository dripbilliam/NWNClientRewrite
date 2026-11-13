// Independent private GDExtension. No particle/library replacement, Nodes,
// callbacks, engine scene reads, file/network IO or retained input pointers.
#include "gdextension_interface.h"
#include "geometry_math.hpp"
#include <algorithm>
#include <string>
namespace {
GDExtensionClassLibraryPtr library;
GDExtensionInterfaceVariantNewNil new_nil;
GDExtensionInterfaceVariantNewCopy new_copy;
GDExtensionInterfaceVariantDestroy destroy;
GDExtensionInterfaceVariantGetType get_type;
GDExtensionInterfaceVariantSetKeyed set_keyed;
GDExtensionInterfaceVariantConstruct construct;
GDExtensionInterfaceGetVariantFromTypeConstructor get_from;
GDExtensionInterfaceGetVariantToTypeConstructor get_to;
GDExtensionInterfaceVariantGetPtrConstructor get_constructor;
GDExtensionInterfaceVariantGetPtrDestructor get_destructor;
GDExtensionInterfaceVariantGetPtrBuiltinMethod get_method;
GDExtensionInterfaceStringNameNewWithUtf8Chars name_new;
GDExtensionInterfaceStringNewWithUtf8Chars string_new;
GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;
GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
GDExtensionInterfacePackedByteArrayOperatorIndex bytes_mutable;
GDExtensionInterfacePackedByteArrayOperatorIndexConst bytes_read;
GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst floats_read;
GDExtensionInterfacePackedColorArrayOperatorIndexConst colors_read;
GDExtensionInterfaceArrayOperatorIndexConst array_read;
GDExtensionVariantFromTypeConstructorFunc from[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};
GDExtensionTypeFromVariantConstructorFunc to[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};
GDExtensionPtrBuiltInMethod lengths[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};
GDExtensionPtrBuiltInMethod byte_resize;
struct Name {alignas(8) uint8_t raw[8];explicit Name(const char* text){name_new(raw,text);}~Name(){get_destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(raw);}Name(const Name&)=delete;};
struct Var {
 alignas(8)uint8_t raw[24];Var(){new_nil(raw);}explicit Var(GDExtensionConstVariantPtr v){new_copy(raw,v);}Var(const Var& v){new_copy(raw,v.raw);}~Var(){destroy(raw);}
 static Var type(GDExtensionVariantType kind,const void* value){Var out;destroy(out.raw);from[kind](out.raw,const_cast<void*>(value));return out;}
 static Var integer(int64_t value){return type(GDEXTENSION_VARIANT_TYPE_INT,&value);}
 static Var boolean(bool value){GDExtensionBool v=value;return type(GDEXTENSION_VARIANT_TYPE_BOOL,&v);}
 static Var text(const char* value){alignas(8)uint8_t data[8];string_new(data,value);Var out=type(GDEXTENSION_VARIANT_TYPE_STRING,data);get_destructor(GDEXTENSION_VARIANT_TYPE_STRING)(data);return out;}
 static Var dictionary(){Var out;destroy(out.raw);GDExtensionCallError error{};construct(GDEXTENSION_VARIANT_TYPE_DICTIONARY,out.raw,nullptr,0,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("Highlight result dictionary allocation failed");return out;}
};
void put(Var& dictionary,const char* key,const Var& value){Var k=Var::text(key);GDExtensionBool valid=0;set_keyed(dictionary.raw,k.raw,value.raw,&valid);if(!valid)throw std::runtime_error("Highlight result publication failed");}
struct Raw {
 alignas(8)uint8_t raw[64]{};GDExtensionVariantType kind;
 Raw(GDExtensionConstVariantPtr value,GDExtensionVariantType expected):kind(expected){if(get_type(value)!=expected)throw std::runtime_error("Unexpected highlight input type");to[kind](raw,const_cast<void*>(value));}
 ~Raw(){get_destructor(kind)(raw);}Raw(const Raw&)=delete;
 int64_t size()const{GDExtensionInt count=0;lengths[kind](const_cast<uint8_t*>(raw),nullptr,&count,0);return count;}
};
Var packed(const std::vector<uint8_t>& input){
 alignas(8)uint8_t raw[16];get_constructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,0)(raw,nullptr);
 try{const GDExtensionInt size=static_cast<GDExtensionInt>(input.size());const GDExtensionConstTypePtr args[]={&size};GDExtensionInt resized=0;byte_resize(raw,args,&resized,1);if(resized!=0)throw std::runtime_error("Highlight output allocation failed");if(!input.empty())std::memcpy(bytes_mutable(raw,0),input.data(),input.size());Var out=Var::type(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,raw);get_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(raw);return out;}catch(...){get_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(raw);throw;}
}
float scalar(GDExtensionConstVariantPtr input){const auto kind=get_type(input);if(kind!=GDEXTENSION_VARIANT_TYPE_FLOAT&&kind!=GDEXTENSION_VARIANT_TYPE_INT)throw std::runtime_error("Highlight scalar requires a number");double value=0;if(kind==GDEXTENSION_VARIANT_TYPE_FLOAT)to[kind](&value,const_cast<void*>(input));else{int64_t number=0;to[kind](&number,const_cast<void*>(input));value=static_cast<double>(number);}return static_cast<float>(value);}
Var batch(const GDExtensionConstVariantPtr* args){
 Raw shapes(args[0],GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY),poses(args[1],GDEXTENSION_VARIANT_TYPE_ARRAY),colors(args[2],GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY),alphas(args[3],GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY),enabled(args[4],GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);
 const int64_t count=poses.size();if(count<0||count>65536||shapes.size()!=count*6||colors.size()!=count||alphas.size()!=count||enabled.size()!=count)throw std::runtime_error("Highlight batch shape/count mismatch");
 if(get_type(args[5])!=GDEXTENSION_VARIANT_TYPE_VECTOR3)throw std::runtime_error("Highlight camera requires Vector3");nwn_highlight::V3 camera;to[GDEXTENSION_VARIANT_TYPE_VECTOR3](&camera,const_cast<void*>(args[5]));
 std::vector<nwn_highlight::Part> parts(static_cast<size_t>(count));
 for(int64_t index=0;index<count;index++){
  auto& part=parts[static_cast<size_t>(index)];const auto* shape=floats_read(shapes.raw,index*6);std::copy_n(shape,6,part.shape.begin());
  const GDExtensionConstVariantPtr pose=array_read(poses.raw,index);if(get_type(pose)!=GDEXTENSION_VARIANT_TYPE_TRANSFORM3D)throw std::runtime_error("Highlight pose requires Transform3D");to[GDEXTENSION_VARIANT_TYPE_TRANSFORM3D](part.pose.data(),const_cast<void*>(pose));
  std::memcpy(part.color.data(),colors_read(colors.raw,index),16);part.alpha=*floats_read(alphas.raw,index);part.enabled=*bytes_read(enabled.raw,index)!=0;
 }
 const auto frame=nwn_highlight::generate(parts,camera,scalar(args[6]),scalar(args[7]));auto out=Var::dictionary();put(out,"version",Var::integer(1));put(out,"positions",packed(frame.positions));put(out,"attributes",packed(frame.attributes));put(out,"available_parts",Var::integer(frame.available));put(out,"unavailable_parts",Var::integer(frame.unavailable));put(out,"vertices",Var::integer(count*18));put(out,"has_bounds",Var::boolean(frame.bounds));
 std::array<float,6> bounds{{frame.minimum.x,frame.minimum.y,frame.minimum.z,frame.maximum.x-frame.minimum.x,frame.maximum.y-frame.minimum.y,frame.maximum.z-frame.minimum.z}};put(out,"bounds",Var::type(GDEXTENSION_VARIANT_TYPE_AABB,bounds.data()));return out;
}
void call_batch(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;try{if(count!=8)throw std::runtime_error("Highlight batch requires eight arguments");auto out=batch(args);new_copy(result,out.raw);}catch(const std::exception& failure){auto out=Var::dictionary();put(out,"error",Var::text(failure.what()));new_copy(result,out.raw);}
}
void free_instance(void*,GDExtensionClassInstancePtr){}
void initialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;Name name("NwnHighlightGeometry"),base("RefCounted"),method("build"),empty("");alignas(8)uint8_t hint[8];string_new(hint,"");GDExtensionClassCreationInfo6 info{};info.is_abstract=true;info.is_exposed=true;info.is_runtime=true;info.free_instance_func=free_instance;register_class(library,name.raw,base.raw,&info);
 const auto property=[&](GDExtensionVariantType kind,Name& n){GDExtensionPropertyInfo p{};p.type=kind;p.name=n.raw;p.class_name=empty.raw;p.hint_string=hint;p.usage=6;return p;};
 Name shapes("shapes"),poses("poses"),colors("colors"),alphas("alphas"),enabled("enabled"),camera("camera"),pulse("pulse"),intensity("intensity");auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);
 GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,shapes),property(GDEXTENSION_VARIANT_TYPE_ARRAY,poses),property(GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY,colors),property(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,alphas),property(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,enabled),property(GDEXTENSION_VARIANT_TYPE_VECTOR3,camera),property(GDEXTENSION_VARIANT_TYPE_FLOAT,pulse),property(GDEXTENSION_VARIANT_TYPE_FLOAT,intensity)};GDExtensionClassMethodArgumentMetadata metadata[8]{};GDExtensionClassMethodInfo m{};m.name=method.raw;m.call_func=call_batch;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL|GDEXTENSION_METHOD_FLAG_STATIC;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=8;m.arguments_info=args;m.arguments_metadata=metadata;register_method(library,name.raw,&m);get_destructor(GDEXTENSION_VARIANT_TYPE_STRING)(hint);
}
void deinitialize(void*,GDExtensionInitializationLevel level){if(level==GDEXTENSION_INITIALIZATION_SCENE){Name name("NwnHighlightGeometry");unregister_class(library,name.raw);}}
}
extern "C" __declspec(dllexport) GDExtensionBool nwn_highlight_geometry_init(GDExtensionInterfaceGetProcAddress api,GDExtensionClassLibraryPtr lib,GDExtensionInitialization* init){
 library=lib;
#define LOAD(var,type,name) var=reinterpret_cast<type>(api(name));if(!var)return false
 LOAD(new_nil,GDExtensionInterfaceVariantNewNil,"variant_new_nil");LOAD(new_copy,GDExtensionInterfaceVariantNewCopy,"variant_new_copy");LOAD(destroy,GDExtensionInterfaceVariantDestroy,"variant_destroy");LOAD(get_type,GDExtensionInterfaceVariantGetType,"variant_get_type");LOAD(set_keyed,GDExtensionInterfaceVariantSetKeyed,"variant_set_keyed");LOAD(construct,GDExtensionInterfaceVariantConstruct,"variant_construct");LOAD(get_from,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor");LOAD(get_to,GDExtensionInterfaceGetVariantToTypeConstructor,"get_variant_to_type_constructor");LOAD(get_constructor,GDExtensionInterfaceVariantGetPtrConstructor,"variant_get_ptr_constructor");LOAD(get_destructor,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor");LOAD(get_method,GDExtensionInterfaceVariantGetPtrBuiltinMethod,"variant_get_ptr_builtin_method");LOAD(name_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars");LOAD(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");LOAD(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass6,"classdb_register_extension_class6");LOAD(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");LOAD(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");LOAD(bytes_mutable,GDExtensionInterfacePackedByteArrayOperatorIndex,"packed_byte_array_operator_index");LOAD(bytes_read,GDExtensionInterfacePackedByteArrayOperatorIndexConst,"packed_byte_array_operator_index_const");LOAD(floats_read,GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst,"packed_float32_array_operator_index_const");LOAD(colors_read,GDExtensionInterfacePackedColorArrayOperatorIndexConst,"packed_color_array_operator_index_const");LOAD(array_read,GDExtensionInterfaceArrayOperatorIndexConst,"array_operator_index_const");
#undef LOAD
 for(const auto kind:{GDEXTENSION_VARIANT_TYPE_BOOL,GDEXTENSION_VARIANT_TYPE_INT,GDEXTENSION_VARIANT_TYPE_FLOAT,GDEXTENSION_VARIANT_TYPE_STRING,GDEXTENSION_VARIANT_TYPE_VECTOR3,GDEXTENSION_VARIANT_TYPE_AABB,GDEXTENSION_VARIANT_TYPE_TRANSFORM3D,GDEXTENSION_VARIANT_TYPE_DICTIONARY,GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY}){from[kind]=get_from(kind);to[kind]=get_to(kind);if(!from[kind]||!to[kind])return false;}
 Name size("size"),resize("resize");for(const auto kind:{GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY}){lengths[kind]=get_method(kind,size.raw,3173160232);if(!lengths[kind])return false;}byte_resize=get_method(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,resize.raw,848867239);if(!byte_resize)return false;
 init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=nullptr;return true;
}
