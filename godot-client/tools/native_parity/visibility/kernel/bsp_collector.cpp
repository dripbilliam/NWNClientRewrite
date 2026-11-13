// Separate read-only POD extension. No Nodes, clock sampling, callbacks,
// renderer/registry authority, retained inputs, files or network operations.
#include "gdextension_interface.h"
#include "bsp_math.hpp"
#include <algorithm>
namespace {
GDExtensionClassLibraryPtr library;
GDExtensionInterfaceVariantNewNil new_nil;GDExtensionInterfaceVariantNewCopy new_copy;GDExtensionInterfaceVariantDestroy destroy;
GDExtensionInterfaceVariantGetType get_type;GDExtensionInterfaceVariantSetKeyed set_keyed;GDExtensionInterfaceVariantConstruct construct;
GDExtensionInterfaceGetVariantFromTypeConstructor get_from;GDExtensionInterfaceGetVariantToTypeConstructor get_to;
GDExtensionInterfaceVariantGetPtrConstructor get_constructor;GDExtensionInterfaceVariantGetPtrDestructor get_destructor;GDExtensionInterfaceVariantGetPtrBuiltinMethod get_method;
GDExtensionInterfaceStringNameNewWithUtf8Chars name_new;GDExtensionInterfaceStringNewWithUtf8Chars string_new;
GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst floats_read;GDExtensionInterfacePackedInt32ArrayOperatorIndexConst ints_read;GDExtensionInterfacePackedInt64ArrayOperatorIndexConst longs_read;
GDExtensionInterfacePackedInt32ArrayOperatorIndex ints_write;GDExtensionInterfacePackedInt64ArrayOperatorIndex longs_write;
GDExtensionVariantFromTypeConstructorFunc from[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};GDExtensionTypeFromVariantConstructorFunc to[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};
GDExtensionPtrBuiltInMethod lengths[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{},resizes[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};
struct Name {alignas(8)uint8_t raw[8];explicit Name(const char* value){name_new(raw,value);}~Name(){get_destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(raw);}Name(const Name&)=delete;};
struct Var {
 alignas(8)uint8_t raw[24];Var(){new_nil(raw);}Var(const Var& other){new_copy(raw,other.raw);}~Var(){destroy(raw);}
 static Var type(GDExtensionVariantType kind,const void* value){Var out;destroy(out.raw);from[kind](out.raw,const_cast<void*>(value));return out;}
 static Var integer(int64_t value){return type(GDEXTENSION_VARIANT_TYPE_INT,&value);}
 static Var boolean(bool value){GDExtensionBool b=value;return type(GDEXTENSION_VARIANT_TYPE_BOOL,&b);}
 static Var text(const char* value){alignas(8)uint8_t raw[8];string_new(raw,value);Var out=type(GDEXTENSION_VARIANT_TYPE_STRING,raw);get_destructor(GDEXTENSION_VARIANT_TYPE_STRING)(raw);return out;}
 static Var dictionary(){Var out;destroy(out.raw);GDExtensionCallError error{};construct(GDEXTENSION_VARIANT_TYPE_DICTIONARY,out.raw,nullptr,0,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("BSP result allocation");return out;}
};
void put(Var& dict,const char* name,const Var& value){Var key=Var::text(name);GDExtensionBool valid=0;set_keyed(dict.raw,key.raw,value.raw,&valid);if(!valid)throw std::runtime_error("BSP result publication");}
struct Raw {
 alignas(8)uint8_t raw[64]{};GDExtensionVariantType kind;
 Raw(GDExtensionConstVariantPtr value,GDExtensionVariantType expected):kind(expected){if(get_type(value)!=expected)throw std::runtime_error("BSP packed input type");to[kind](raw,const_cast<void*>(value));}
 ~Raw(){get_destructor(kind)(raw);}Raw(const Raw&)=delete;
 int64_t size()const{GDExtensionInt n=0;lengths[kind](const_cast<uint8_t*>(raw),nullptr,&n,0);return n;}
};
int64_t integer(GDExtensionConstVariantPtr value){if(get_type(value)!=GDEXTENSION_VARIANT_TYPE_INT)throw std::runtime_error("BSP integer input type");int64_t v=0;to[GDEXTENSION_VARIANT_TYPE_INT](&v,const_cast<void*>(value));return v;}
template<class T>Var packed(const std::vector<T>& values,GDExtensionVariantType kind){
 alignas(8)uint8_t raw[16];get_constructor(kind,0)(raw,nullptr);
 try{GDExtensionInt size=static_cast<GDExtensionInt>(values.size()),error=0;const GDExtensionConstTypePtr args[]={&size};resizes[kind](raw,args,&error,1);if(error!=0)throw std::runtime_error("BSP packed output allocation");if(size){void* data=kind==GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY?static_cast<void*>(ints_write(raw,0)):static_cast<void*>(longs_write(raw,0));std::memcpy(data,values.data(),values.size()*sizeof(T));}Var out=Var::type(kind,raw);get_destructor(kind)(raw);return out;}catch(...){get_destructor(kind)(raw);throw;}
}
Var collect(const GDExtensionConstVariantPtr* args){
 Raw planes(args[0],GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY),topology(args[1],GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY),vertices(args[2],GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY),ranges(args[3],GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY),tiles(args[4],GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY),frustum(args[7],GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY);
 const int64_t n=tiles.size(),root=integer(args[5]),low=integer(args[8]);if(n<1||n>nwn_bsp::max_nodes||planes.size()!=n*4||topology.size()!=n*3||ranges.size()!=n*2||vertices.size()>12000000||frustum.size()>nwn_bsp::max_planes*4||frustum.size()%4||root<0||root>=n||low<0||low>4294967295ll)throw std::runtime_error("BSP packed input shape");
 if(get_type(args[6])!=GDEXTENSION_VARIANT_TYPE_VECTOR3)throw std::runtime_error("BSP native camera type");std::array<float,3> camera{};to[GDEXTENSION_VARIANT_TYPE_VECTOR3](camera.data(),const_cast<void*>(args[6]));
 static const float empty=0.f;
 const nwn_bsp::Input input{floats_read(planes.raw,0),ints_read(topology.raw,0),vertices.size()?floats_read(vertices.raw,0):&empty,ints_read(ranges.raw,0),longs_read(tiles.raw,0),static_cast<int>(n),static_cast<int>(vertices.size()),static_cast<int>(root),camera,frustum.size()?floats_read(frustum.raw,0):&empty,static_cast<int>(frustum.size()/4),static_cast<uint32_t>(low)};
 const auto output=nwn_bsp::Collector(input).collect();auto out=Var::dictionary();put(out,"available",Var::boolean(true));put(out,"version",Var::integer(1));put(out,"node_ids",packed(output.nodes,GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY));put(out,"plane_counts",packed(output.plane_counts,GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY));put(out,"tile_nodes",packed(output.tile_nodes,GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY));put(out,"tile_tokens",packed(output.tiles,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY));put(out,"delta_t_word",Var::integer(output.delta_word));return out;
}
void call_collect(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){error->error=GDEXTENSION_CALL_OK;try{if(count!=9)throw std::runtime_error("BSP collect requires nine POD arguments");auto out=collect(args);new_copy(result,out.raw);}catch(const std::exception& failure){auto out=Var::dictionary();put(out,"available",Var::boolean(false));put(out,"error",Var::text(failure.what()));new_copy(result,out.raw);}}
void free_instance(void*,GDExtensionClassInstancePtr){}
void initialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;Name name("NwnBspCollector"),base("RefCounted"),method("collect"),empty("");alignas(8)uint8_t hint[8];string_new(hint,"");GDExtensionClassCreationInfo6 info{};info.is_abstract=true;info.is_exposed=true;info.is_runtime=true;info.free_instance_func=free_instance;register_class(library,name.raw,base.raw,&info);
 const auto property=[&](GDExtensionVariantType kind,Name& n){GDExtensionPropertyInfo p{};p.type=kind;p.name=n.raw;p.class_name=empty.raw;p.hint_string=hint;p.usage=6;return p;};
 Name planes("split_planes"),topology("topology"),vertices("split_vertices"),ranges("vertex_ranges"),tiles("tile_membership"),root("root"),camera("native_camera"),frustum("camera_planes"),low("snapshot_low");auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);
 GDExtensionPropertyInfo arguments[]={property(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,planes),property(GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY,topology),property(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,vertices),property(GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY,ranges),property(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,tiles),property(GDEXTENSION_VARIANT_TYPE_INT,root),property(GDEXTENSION_VARIANT_TYPE_VECTOR3,camera),property(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,frustum),property(GDEXTENSION_VARIANT_TYPE_INT,low)};GDExtensionClassMethodArgumentMetadata metadata[9]{};GDExtensionClassMethodInfo method_info{};method_info.name=method.raw;method_info.call_func=call_collect;method_info.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL|GDEXTENSION_METHOD_FLAG_STATIC;method_info.has_return_value=true;method_info.return_value_info=&ret;method_info.argument_count=9;method_info.arguments_info=arguments;method_info.arguments_metadata=metadata;register_method(library,name.raw,&method_info);get_destructor(GDEXTENSION_VARIANT_TYPE_STRING)(hint);
}
void deinitialize(void*,GDExtensionInitializationLevel level){if(level==GDEXTENSION_INITIALIZATION_SCENE){Name name("NwnBspCollector");unregister_class(library,name.raw);}}
}
extern "C" __declspec(dllexport)GDExtensionBool nwn_bsp_collector_init(GDExtensionInterfaceGetProcAddress api,GDExtensionClassLibraryPtr lib,GDExtensionInitialization* init){
 library=lib;
#define LOAD(var,type,key) var=reinterpret_cast<type>(api(key));if(!var)return false
 LOAD(new_nil,GDExtensionInterfaceVariantNewNil,"variant_new_nil");LOAD(new_copy,GDExtensionInterfaceVariantNewCopy,"variant_new_copy");LOAD(destroy,GDExtensionInterfaceVariantDestroy,"variant_destroy");LOAD(get_type,GDExtensionInterfaceVariantGetType,"variant_get_type");LOAD(set_keyed,GDExtensionInterfaceVariantSetKeyed,"variant_set_keyed");LOAD(construct,GDExtensionInterfaceVariantConstruct,"variant_construct");LOAD(get_from,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor");LOAD(get_to,GDExtensionInterfaceGetVariantToTypeConstructor,"get_variant_to_type_constructor");LOAD(get_constructor,GDExtensionInterfaceVariantGetPtrConstructor,"variant_get_ptr_constructor");LOAD(get_destructor,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor");LOAD(get_method,GDExtensionInterfaceVariantGetPtrBuiltinMethod,"variant_get_ptr_builtin_method");LOAD(name_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars");LOAD(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");LOAD(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass6,"classdb_register_extension_class6");LOAD(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");LOAD(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");LOAD(floats_read,GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst,"packed_float32_array_operator_index_const");LOAD(ints_read,GDExtensionInterfacePackedInt32ArrayOperatorIndexConst,"packed_int32_array_operator_index_const");LOAD(longs_read,GDExtensionInterfacePackedInt64ArrayOperatorIndexConst,"packed_int64_array_operator_index_const");LOAD(ints_write,GDExtensionInterfacePackedInt32ArrayOperatorIndex,"packed_int32_array_operator_index");LOAD(longs_write,GDExtensionInterfacePackedInt64ArrayOperatorIndex,"packed_int64_array_operator_index");
#undef LOAD
 for(const auto kind:{GDEXTENSION_VARIANT_TYPE_BOOL,GDEXTENSION_VARIANT_TYPE_INT,GDEXTENSION_VARIANT_TYPE_STRING,GDEXTENSION_VARIANT_TYPE_DICTIONARY,GDEXTENSION_VARIANT_TYPE_VECTOR3,GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY}){from[kind]=get_from(kind);to[kind]=get_to(kind);if(!from[kind]||!to[kind])return false;}
 Name size("size"),resize("resize");for(const auto kind:{GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY}){lengths[kind]=get_method(kind,size.raw,3173160232);resizes[kind]=get_method(kind,resize.raw,848867239);if(!lengths[kind]||!resizes[kind])return false;}
 init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=nullptr;return true;
}
