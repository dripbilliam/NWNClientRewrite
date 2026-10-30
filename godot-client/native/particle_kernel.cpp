// Native visual arithmetic only. Original coordinates are Z-up, quaternions WXYZ.
// No network, file IO, engine scene mutation or JS. RefCounted native owners
// retain private simulation/controller storage, never borrowed scene pointers.
// ABI sizes are checked against the pinned engine dump by the build script.
#include "gdextension_interface.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace {
GDExtensionClassLibraryPtr library;
GDExtensionInterfaceVariantNewNil new_nil;
GDExtensionInterfaceVariantNewCopy new_copy;
GDExtensionInterfaceVariantDestroy destroy;
GDExtensionInterfaceVariantGetType get_type;
GDExtensionInterfaceVariantGetKeyed get_keyed;
GDExtensionInterfaceVariantGetIndexed get_indexed;
GDExtensionInterfaceVariantSetKeyed set_keyed;
GDExtensionInterfaceVariantSetIndexed set_indexed;
GDExtensionInterfaceVariantCall variant_call;
GDExtensionInterfaceVariantConstruct construct;
GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
GDExtensionInterfaceGetVariantToTypeConstructor to_type;
GDExtensionInterfaceVariantGetPtrConstructor ptr_constructor;
GDExtensionInterfaceVariantGetPtrDestructor ptr_destructor;
GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin_method;
GDExtensionInterfacePackedByteArrayOperatorIndex packed_index;
GDExtensionInterfaceStringNameNewWithUtf8Chars name_new;
GDExtensionInterfaceStringNewWithUtf8Chars string_new;
GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;
GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
GDExtensionVariantFromTypeConstructorFunc from[ GDEXTENSION_VARIANT_TYPE_VARIANT_MAX ];
GDExtensionTypeFromVariantConstructorFunc to[ GDEXTENSION_VARIANT_TYPE_VARIANT_MAX ];
struct Name {
 alignas(8) uint8_t data[8];
 explicit Name(const char* value){name_new(data,value);}
 ~Name(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(data);}
 Name(const Name&)=delete;
};
struct Var {
 alignas(8) uint8_t data[24];
 Var(){new_nil(data);}
 explicit Var(GDExtensionConstVariantPtr source){new_copy(data,source);}
 Var(const Var& v){new_copy(data,v.data);}
 Var(Var&& v) noexcept {new_copy(data,v.data);}
 ~Var(){destroy(data);}
 Var& operator=(const Var& v){if(this!=&v){destroy(data);new_copy(data,v.data);}return *this;}
 static Var number(double n){Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_FLOAT](v.data,&n);return v;}
 static Var integer(int64_t n){Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_INT](v.data,&n);return v;}
 static Var boolean(bool n){GDExtensionBool b=n?1:0;Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_BOOL](v.data,&b);return v;}
 static Var text(const char* value){alignas(8) uint8_t raw[8];string_new(raw,value);Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_STRING](v.data,raw);ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING)(raw);return v;}
 static Var dictionary(){Var v;destroy(v.data);GDExtensionCallError error{};construct(GDEXTENSION_VARIANT_TYPE_DICTIONARY,v.data,nullptr,0,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("Native dictionary construction failed");return v;}
 GDExtensionVariantType type() const{return get_type(data);}
 bool nil() const{return type()==GDEXTENSION_VARIANT_TYPE_NIL;}
 double number() const {
  const auto t=type();if(t==GDEXTENSION_VARIANT_TYPE_FLOAT){double n;to[t](&n,const_cast<uint8_t*>(data));return n;}
  if(t==GDEXTENSION_VARIANT_TYPE_INT){int64_t n;to[t](&n,const_cast<uint8_t*>(data));return static_cast<double>(n);}
  throw std::runtime_error("Native particle value must be numeric");
 }
 int64_t integer() const {if(type()!=GDEXTENSION_VARIANT_TYPE_INT)throw std::runtime_error("Native particle value must be integer");int64_t n;to[GDEXTENSION_VARIANT_TYPE_INT](&n,const_cast<uint8_t*>(data));return n;}
 bool boolean() const {if(type()==GDEXTENSION_VARIANT_TYPE_BOOL){GDExtensionBool n;to[GDEXTENSION_VARIANT_TYPE_BOOL](&n,const_cast<uint8_t*>(data));return n!=0;}return number()!=0;}
};
std::unordered_map<std::string,std::unique_ptr<Var>> keys;
const Var& key(const char* field){auto found=keys.find(field);if(found!=keys.end())return *found->second;Name name(field);auto value=std::make_unique<Var>();destroy(value->data);from[GDEXTENSION_VARIANT_TYPE_STRING_NAME](value->data,name.data);auto* result=value.get();keys.emplace(field,std::move(value));return *result;}
Var get(const Var& v,const char* field){if(v.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Native particle dictionary required");Var out;destroy(out.data);GDExtensionBool valid=0;get_keyed(v.data,key(field).data,out.data,&valid);if(!valid)throw std::runtime_error(std::string("Missing native particle field: ")+field);return out;}
void set(Var& v,const char* field,const Var& value){GDExtensionBool valid=0;set_keyed(v.data,key(field).data,value.data,&valid);if(!valid)throw std::runtime_error("Native particle field mutation failed");}
Var at(const Var& v,int64_t i){if(v.type()!=GDEXTENSION_VARIANT_TYPE_ARRAY)throw std::runtime_error("Native particle array required");Var out;destroy(out.data);GDExtensionBool valid=0,oob=0;get_indexed(v.data,i,out.data,&valid,&oob);if(!valid||oob)throw std::runtime_error("Native particle array index invalid");return out;}
int64_t size(Var& v){Name name("size");Var out;destroy(out.data);GDExtensionCallError err{};variant_call(v.data,name.data,nullptr,0,out.data,&err);if(err.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("Native particle array size failed");return out.integer();}
float f(const Var& v,const char* field){return static_cast<float>(get(v,field).number());}
int64_t i(const Var& v,const char* field){const auto n=get(v,field).number();if(!std::isfinite(n)||n<-2147483648.0||n>2147483647.0)throw std::runtime_error(std::string("Native particle integer field is outside its supported range: ")+field+"="+std::to_string(n));return static_cast<int64_t>(n);}
// Original FountainEmitter::Update compares the complete source-node dword to
// zero (140064d12). Binary MDLs expose unsigned words; ASCII may spell -1.
// Preserve that bit pattern only for this field, without widening signed sizes.
uint32_t word32(const Var& v,const char* field){const auto n=get(v,field).number();if(!std::isfinite(n)||std::trunc(n)!=n||n<-2147483648.0||n>4294967295.0)throw std::runtime_error(std::string("Native particle dword field is outside its supported range: ")+field+"="+std::to_string(n));return static_cast<uint32_t>(static_cast<int64_t>(n));}
using V3=std::array<float,3>;using Q4=std::array<float,4>;
template<size_t N>std::array<float,N> values(const Var& v){std::array<float,N> out{};for(size_t n=0;n<N;++n)out[n]=static_cast<float>(at(v,static_cast<int64_t>(n)).number());return out;}
float mix(float a,float b,float t){return t*b+(1.0f-t)*a;}
Q4 multiply(const Q4& l,const Q4& r){const auto a=l[0],b=l[1],c=l[2],d=l[3],w=r[0],x=r[1],y=r[2],z=r[3];return {((a*w-b*x)-c*y)-d*z,((b*w+a*x)+c*z)-d*y,((a*y-b*z)+c*w)+d*x,((b*y+a*z)-c*x)+d*w};}
V3 axis_x(const Q4& q){const auto w=q[0],x=q[1],y=q[2],z=q[3];return {1.0f-2.0f*(z*z+y*y),2.0f*(x*y+w*z),2.0f*(x*z-w*y)};}
V3 axis_y(const Q4& q){const auto w=q[0],x=q[1],y=q[2],z=q[3];return {2.0f*(x*y-w*z),1.0f-2.0f*(z*z+x*x),2.0f*(w*x+z*y)};}
V3 axis_z(const Q4& q){const auto w=q[0],x=q[1],y=q[2],z=q[3];return {2.0f*(w*y+x*z),2.0f*(y*z-w*x),1.0f-2.0f*(y*y+x*x)};}
V3 cross(const V3& a,const V3& b){return {a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]};}
int32_t cvtt(float n){return std::isfinite(n)&&n>=-2147483648.0f&&n<2147483648.0f?static_cast<int32_t>(n):INT32_MIN;}
float rsqrt(float n){int32_t bits;std::memcpy(&bits,&n,4);bits=0x5f3759df-(bits>>1);float estimate;std::memcpy(&estimate,&bits,4);return (1.5f-((n*0.5f)*estimate)*estimate)*estimate;}
int exponent(double v){uint64_t bits;std::memcpy(&bits,&v,8);return static_cast<int>((bits>>52)&2047);}
double polynomial(double v,bool cosine){const double c[]={0.041666666666666664,-0.0013888888888888887,0.000024801587301587298,-2.755731922398589e-7};const double s[]={-0.16666666666666666,0.008333333333333333,-0.0001984126984126984,0.0000027557319223985893};const auto* p=cosine?c:s;const double square=v*v,fourth=square*square,correction=(p[3]*square+p[2])*fourth+(p[1]*square+p[0]);return cosine?(-0.5*square+1)+correction*fourth:v+correction*(v*square);}
float trig(float input,bool cosine){const double value=input,absolute=std::abs(value);if(!std::isfinite(value)||absolute>=500000)throw std::runtime_error("Unmapped native CRT particle angle");if(!cosine&&absolute<0.0001220703125)return input;if(absolute<=0.7853981633974483){if(absolute<0.0078125&&!cosine)return static_cast<float>(value-(value*value*value)*(1.0/6.0));return static_cast<float>(polynomial(value,cosine));}const int quadrant=static_cast<int>(absolute*0.6366197723675814+0.5);const double first=absolute-1.5707963267341256*quadrant;double reduced=first-6.077100506506192e-11*quadrant;const auto exp=exponent(reduced);if(exponent(absolute)-exp>15){const double next=first-6.077100506303966e-11*quadrant;reduced=next-(2.0222662487959506e-21*quadrant-((first-next)-6.077100506303966e-11*quadrant));}const bool use_cos=cosine?(quadrant&1)==0:(quadrant&1)!=0;double result;if(exp<1010){if(exp<=990)result=use_cos?1:reduced;else result=use_cos?1-(reduced*reduced)*0.5:reduced-((1.0/6.0)*reduced)*(reduced*reduced);}else result=polynomial(reduced,use_cos);const bool negative=cosine?((quadrant+1)&2)!=0:((quadrant>>1)&1)!=static_cast<int>(value<0);return static_cast<float>(negative?-result:result);}
uint32_t color_word(const V3& color,float alpha){return (static_cast<uint32_t>(cvtt(alpha))&255)<<24|(static_cast<uint32_t>(cvtt(color[2]))&255)<<16|(static_cast<uint32_t>(cvtt(color[1]))&255)<<8|(static_cast<uint32_t>(cvtt(color[0]))&255);}
float color_scale(float n){return std::clamp(n,0.0f,1.0f)*255.99000549316406f;}
Var byte_array(const std::vector<uint8_t>& bytes){alignas(8) uint8_t raw[16];ptr_constructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,0)(raw,nullptr);struct Guard{void* ptr;~Guard(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(ptr);}}guard{raw};Name resize("resize");GDExtensionInt length=static_cast<GDExtensionInt>(bytes.size()),error=-1;const GDExtensionConstTypePtr args[]={&length};builtin_method(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,resize.data,848867239)(raw,args,&error,1);if(error!=0)throw std::runtime_error("Native particle buffer allocation failed");if(length)std::memcpy(packed_index(raw,0),bytes.data(),bytes.size());Var out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY](out.data,raw);return out;}
#include "particle_simulation.hpp"
#include "particle_streams.hpp"
void vertex(std::vector<uint8_t>& bytes,int64_t index,uint32_t color,const V3& position,float u,float v,ParticleStreams* streams=nullptr){if(streams){streams->write(index,color,position,u,v);return;}const auto offset=static_cast<size_t>(index)*24;std::memcpy(bytes.data()+offset,&color,4);std::memcpy(bytes.data()+offset+4,position.data(),12);std::memcpy(bytes.data()+offset+16,&u,4);std::memcpy(bytes.data()+offset+20,&v,4);}
#include "particle_vertices.hpp"
void call_build(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;
 if(count!=3){error->error=count<3?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=3;new_nil(result);return;}
 try{Var emitter(args[0]),input(args[1]),atlas(args[2]);auto out=build(emitter,input,atlas.boolean());new_copy(result,out.data);}catch(const std::exception& err){auto out=Var::dictionary();set(out,"error",Var::text(err.what()));new_copy(result,out.data);}
}
void free_instance(void*,GDExtensionClassInstancePtr){}
void call_streams(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;
 if(count!=4){error->error=count<4?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=4;new_nil(result);return;}
 try{Var emitter(args[0]),input(args[1]),atlas(args[2]),retained(args[3]);thread_local ParticleStreams staging;auto out=build(emitter,input,atlas.boolean(),&staging,retained.integer());new_copy(result,out.data);}catch(const std::exception& err){auto out=Var::dictionary();set(out,"error",Var::text(err.what()));new_copy(result,out.data);}
}
bool direct_scene_trace(uint64_t terrain,uint64_t statics,const V3& start,V3& end,V3& normal,bool& hit);
#include "particle_resident.hpp"
#include "scene_geometry.hpp"
#include "scene_model.hpp"
#include "scene_index.hpp"
#include "animation_keys.hpp"
#include "raster_conversion.hpp"
bool bind_pose_api(){ {Name node("Node3D"),global("get_global_transform"),ortho("orthonormalized"),quaternion("get_rotation_quaternion"),scale("get_scale"),basis("basis"),origin("origin"),x("x"),y("y"),z("z");
 node_transform=class_method(node.data,global.data,3229777777);node_tag=class_tag(node.data);basis_orthonormal=builtin_method(GDEXTENSION_VARIANT_TYPE_BASIS,ortho.data,594669093);basis_quaternion=builtin_method(GDEXTENSION_VARIANT_TYPE_BASIS,quaternion.data,4274879941);basis_scale=builtin_method(GDEXTENSION_VARIANT_TYPE_BASIS,scale.data,1776574132);transform_basis=member_getter(GDEXTENSION_VARIANT_TYPE_TRANSFORM3D,basis.data);transform_origin=member_getter(GDEXTENSION_VARIANT_TYPE_TRANSFORM3D,origin.data);basis_columns[0]=member_getter(GDEXTENSION_VARIANT_TYPE_BASIS,x.data);basis_columns[1]=member_getter(GDEXTENSION_VARIANT_TYPE_BASIS,y.data);basis_columns[2]=member_getter(GDEXTENSION_VARIANT_TYPE_BASIS,z.data);
 if(!node_transform||!node_tag||!basis_orthonormal||!basis_quaternion||!basis_scale||!transform_basis||!transform_origin||!basis_columns[0]||!basis_columns[1]||!basis_columns[2])return false;}return true;}
void initialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 if(!bind_pose_api()||!bind_scene_model_api()||!scene_index::bind())return;
 Name name("NwnParticleKernel"),base("RefCounted"),method("vertices"),empty(""),arg0("emitter"),arg1("input"),arg2("atlas_prepared");
 alignas(8) uint8_t hint[8];string_new(hint,"");
 GDExtensionClassCreationInfo6 info{};info.is_abstract=true;info.is_exposed=true;info.is_runtime=true;info.free_instance_func=free_instance;register_class(library,name.data,base.data,&info);
 const auto property=[&](GDExtensionVariantType type,Name& n){GDExtensionPropertyInfo p{};p.type=type;p.name=n.data;p.class_name=empty.data;p.hint_string=hint;p.usage=6;return p;};
 auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);
 GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,arg0),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,arg1),property(GDEXTENSION_VARIANT_TYPE_BOOL,arg2)};
 GDExtensionClassMethodArgumentMetadata metadata[3]{};GDExtensionClassMethodInfo m{};m.name=method.data;m.call_func=call_build;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL|GDEXTENSION_METHOD_FLAG_STATIC;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=3;m.arguments_info=args;m.arguments_metadata=metadata;register_method(library,name.data,&m);
 register_simulation(name,property);
 register_resident(property);
 register_scene_geometry(property);
 register_scene_model(property);
 register_scene_index(property);
 animation_keys::register_validation(name,property);
 raster_conversion::register_conversion(name,property);
 Name stream_method("streams"),capacity_arg("retained_capacity");
 GDExtensionPropertyInfo stream_args[]={args[0],args[1],args[2],property(GDEXTENSION_VARIANT_TYPE_INT,capacity_arg)};
 GDExtensionClassMethodArgumentMetadata stream_metadata[4]{};m.name=stream_method.data;m.call_func=call_streams;m.argument_count=4;m.arguments_info=stream_args;m.arguments_metadata=stream_metadata;register_method(library,name.data,&m);
 ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING)(hint);
}
void deinitialize(void*,GDExtensionInitializationLevel level){if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;keys.clear();Name index("NwnSceneIndex");unregister_class(library,index.data);Name scene("NwnSceneModel");unregister_class(library,scene.data);Name geometry("NwnSceneGeometry");unregister_class(library,geometry.data);Name owner("NwnParticleOwner");unregister_class(library,owner.data);Name name("NwnParticleKernel");unregister_class(library,name.data);}
}
extern "C" __declspec(dllexport) GDExtensionBool nwn_particle_kernel_init(GDExtensionInterfaceGetProcAddress address,GDExtensionClassLibraryPtr lib,GDExtensionInitialization* init){
 library=lib;
#define API(var,type,symbol) var=reinterpret_cast<type>(address(symbol));if(!var)return false
 API(new_nil,GDExtensionInterfaceVariantNewNil,"variant_new_nil");API(new_copy,GDExtensionInterfaceVariantNewCopy,"variant_new_copy");API(destroy,GDExtensionInterfaceVariantDestroy,"variant_destroy");API(get_type,GDExtensionInterfaceVariantGetType,"variant_get_type");API(get_keyed,GDExtensionInterfaceVariantGetKeyed,"variant_get_keyed");API(get_indexed,GDExtensionInterfaceVariantGetIndexed,"variant_get_indexed");API(set_keyed,GDExtensionInterfaceVariantSetKeyed,"variant_set_keyed");API(variant_call,GDExtensionInterfaceVariantCall,"variant_call");API(construct,GDExtensionInterfaceVariantConstruct,"variant_construct");API(from_type,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor");API(to_type,GDExtensionInterfaceGetVariantToTypeConstructor,"get_variant_to_type_constructor");API(ptr_constructor,GDExtensionInterfaceVariantGetPtrConstructor,"variant_get_ptr_constructor");API(ptr_destructor,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor");API(builtin_method,GDExtensionInterfaceVariantGetPtrBuiltinMethod,"variant_get_ptr_builtin_method");API(packed_index,GDExtensionInterfacePackedByteArrayOperatorIndex,"packed_byte_array_operator_index");API(name_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars");API(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");API(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass6,"classdb_register_extension_class6");API(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");API(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");
 API(construct_object,GDExtensionInterfaceClassdbConstructObject3,"classdb_construct_object3");API(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance");API(string_utf8,GDExtensionInterfaceStringToUtf8Chars,"string_to_utf8_chars");
 API(instance_from_id,GDExtensionInterfaceObjectGetInstanceFromId,"object_get_instance_from_id");API(class_method,GDExtensionInterfaceClassdbGetMethodBind,"classdb_get_method_bind");API(ptrcall,GDExtensionInterfaceObjectMethodBindPtrcall,"object_method_bind_ptrcall");API(class_tag,GDExtensionInterfaceClassdbGetClassTag,"classdb_get_class_tag");API(cast_object,GDExtensionInterfaceObjectCastTo,"object_cast_to");API(member_getter,GDExtensionInterfaceVariantGetPtrGetter,"variant_get_ptr_getter");
 API(operator_evaluator,GDExtensionInterfaceVariantGetPtrOperatorEvaluator,"variant_get_ptr_operator_evaluator");
#undef API
 set_indexed=reinterpret_cast<GDExtensionInterfaceVariantSetIndexed>(address("variant_set_indexed"));if(!set_indexed)return false;
 for(int t=1;t<GDEXTENSION_VARIANT_TYPE_VARIANT_MAX;++t){from[t]=from_type(static_cast<GDExtensionVariantType>(t));to[t]=to_type(static_cast<GDExtensionVariantType>(t));}
 if(!animation_keys::bind(address))return false;
 if(!raster_conversion::bind(address))return false;

 init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=nullptr;return true;
}
