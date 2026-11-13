// Included after scene_model.hpp so the existing operator getter is available.
namespace drive_clear_bridge {
using V2=drive_clear_kernel::V2;
GDExtensionPtrOperatorEvaluator subtract,add,multiply;
GDExtensionPtrBuiltInMethod dot,length_squared,distance_squared;
bool ready=false;
Var field_name(const char* value){Name name(value);Var key;destroy(key.data);from[GDEXTENSION_VARIANT_TYPE_STRING_NAME](key.data,name.data);return key;}
Var read(const Var& input,const char* field){
 if(input.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Drive dictionary required");
 const auto key=field_name(field);Var value;destroy(value.data);GDExtensionBool valid=0;get_keyed(input.data,key.data,value.data,&valid);if(!valid)throw std::runtime_error("Drive field unavailable");return value;
}
void write(Var& output,const char* field,const Var& value){const auto key=field_name(field);GDExtensionBool valid=0;set_keyed(output.data,key.data,value.data,&valid);if(!valid)throw std::runtime_error("Drive result failed");}
Var unsupported(const char* reason){auto out=Var::dictionary();write(out,"supported",Var::boolean(false));write(out,"reason",Var::text(reason));return out;}
template<size_t N>std::array<float,N> vector(const Var& value,GDExtensionVariantType type){if(value.type()!=type)throw std::runtime_error("Drive vector type unsupported");std::array<float,N> out{};to[type](out.data(),const_cast<uint8_t*>(value.data));for(float x:out)drive_clear_kernel::finite(x);return out;}
struct Math{
 V2 sub(const V2&a,const V2&b)const{V2 out{};subtract(a.data(),b.data(),out.data());return out;}
 V2 add(const V2&a,const V2&b)const{V2 out{};drive_clear_bridge::add(a.data(),b.data(),out.data());return out;}
 V2 mul(const V2&a,double scale)const{V2 out{};multiply(a.data(),&scale,out.data());return out;}
 double dot(const V2&a,const V2&b)const{double out=0;const GDExtensionConstTypePtr args[]={b.data()};drive_clear_bridge::dot(const_cast<float*>(a.data()),args,&out,1);return out;}
 double length_squared(const V2&a)const{double out=0;drive_clear_bridge::length_squared(const_cast<float*>(a.data()),nullptr,&out,0);return out;}
 double distance_squared(const V2&a,const V2&b)const{double out=0;const GDExtensionConstTypePtr args[]={b.data()};drive_clear_bridge::distance_squared(const_cast<float*>(a.data()),args,&out,1);return out;}
};
}
bool bind_drive_clear_math(){
 drive_clear_bridge::subtract=operator_evaluator(GDEXTENSION_VARIANT_OP_SUBTRACT,GDEXTENSION_VARIANT_TYPE_VECTOR2,GDEXTENSION_VARIANT_TYPE_VECTOR2);
 drive_clear_bridge::add=operator_evaluator(GDEXTENSION_VARIANT_OP_ADD,GDEXTENSION_VARIANT_TYPE_VECTOR2,GDEXTENSION_VARIANT_TYPE_VECTOR2);
 drive_clear_bridge::multiply=operator_evaluator(GDEXTENSION_VARIANT_OP_MULTIPLY,GDEXTENSION_VARIANT_TYPE_VECTOR2,GDEXTENSION_VARIANT_TYPE_FLOAT);
 Name dot_name("dot"),length_name("length_squared"),distance_name("distance_squared_to");
 drive_clear_bridge::dot=builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,dot_name.data,3819070308LL);
 drive_clear_bridge::length_squared=builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,length_name.data,466405837LL);
 drive_clear_bridge::distance_squared=builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,distance_name.data,3819070308LL);
 drive_clear_bridge::ready=drive_clear_bridge::subtract&&drive_clear_bridge::add&&drive_clear_bridge::multiply&&drive_clear_bridge::dot&&drive_clear_bridge::length_squared&&drive_clear_bridge::distance_squared;return drive_clear_bridge::ready;
}
Var configure_drive_batch(drive_clear_kernel::Batch& batch,const Var& input){
 using namespace drive_clear_bridge;
 batch.clear();
 try{
  if(!ready)return unsupported("Drive engine math unavailable");
  auto rows=read(input,"triangles");if(rows.type()!=GDEXTENSION_VARIANT_TYPE_ARRAY)throw std::runtime_error("Drive triangle array required");
  const auto kind=read(input,"tile");if(kind.type()!=GDEXTENSION_VARIANT_TYPE_BOOL)throw std::runtime_error("Drive mode required");
  const auto bound=read(input,"maximum_bytes").integer();if(bound<1||bound>128*1024*1024)throw std::runtime_error("Drive payload budget invalid");
  const auto count=size(rows);if(count<0||count>2000000||static_cast<uint64_t>(bound)<sizeof(drive_clear_kernel::Batch)||static_cast<uint64_t>(count)>(static_cast<uint64_t>(bound)-sizeof(drive_clear_kernel::Batch))/sizeof(drive_clear_kernel::Face))throw std::runtime_error("Drive payload exceeds budget");
  std::vector<drive_clear_kernel::Face> faces;faces.reserve(static_cast<size_t>(count));
  for(int64_t i=0;i<count;++i){const auto row=at(rows,i);drive_clear_kernel::Face face;
   face.a=vector<3>(read(row,"a"),GDEXTENSION_VARIANT_TYPE_VECTOR3);face.b=vector<3>(read(row,"b"),GDEXTENSION_VARIANT_TYPE_VECTOR3);face.c=vector<3>(read(row,"c"),GDEXTENSION_VARIANT_TYPE_VECTOR3);
   face.minimum=vector<3>(read(row,"min"),GDEXTENSION_VARIANT_TYPE_VECTOR3);face.maximum=vector<3>(read(row,"max"),GDEXTENSION_VARIANT_TYPE_VECTOR3);
   if(kind.boolean()){const auto walk=read(row,"walk");if(walk.type()!=GDEXTENSION_VARIANT_TYPE_BOOL)throw std::runtime_error("Drive walk classification missing");face.walk=walk.boolean();}
   faces.push_back(face);
  }
  batch.configure(std::move(faces),kind.boolean(),static_cast<size_t>(bound));auto out=Var::dictionary();write(out,"supported",Var::boolean(true));write(out,"faces",Var::integer(static_cast<int64_t>(batch.faces.size())));write(out,"payload_bytes",Var::integer(static_cast<int64_t>(batch.payload_bytes())));return out;
 }catch(const std::exception& e){batch.clear();return unsupported(e.what());}
}
Var query_drive_batch(const drive_clear_kernel::Batch& batch,const Var& input,bool tile){
 using namespace drive_clear_bridge;
 try{
  if(!ready)return unsupported("Drive engine math unavailable");
  const auto a=vector<2>(read(input,"a"),GDEXTENSION_VARIANT_TYPE_VECTOR2),b=vector<2>(read(input,"b"),GDEXTENSION_VARIANT_TYPE_VECTOR2);
  const double radius=read(input,"radius").number(),zlow=read(input,"low").number(),zhigh=read(input,"high").number();auto out=Var::dictionary();
  if(tile){const auto result=batch.floor(a,b,radius,zlow,zhigh,Math{});Var intervals;destroy(intervals.data);GDExtensionCallError error{};construct(GDEXTENSION_VARIANT_TYPE_ARRAY,intervals.data,nullptr,0,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("Drive result array failed");
   Name append("append");for(const auto& span:result.intervals){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_VECTOR2](value.data,const_cast<float*>(span.data()));GDExtensionConstVariantPtr args[]={value.data};Var ignored;destroy(ignored.data);variant_call(intervals.data,append.data,args,1,ignored.data,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("Drive result append failed");}
   write(out,"blocked",Var::boolean(result.blocked));write(out,"intervals",intervals);
  }else write(out,"blocked",Var::boolean(batch.obstacle(a,b,radius,zlow,zhigh,Math{})));
  write(out,"supported",Var::boolean(true));return out;
 }catch(const std::exception& e){return unsupported(e.what());}
}
