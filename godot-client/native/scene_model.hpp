// A model's fixed physical mesh list with live weak Node3D identities. No scene
// pointers, engine resources or borrowed geometry survive a dispatch. Copies of
// immutable faces are private; current Part poses are read on every query.
GDExtensionInterfaceVariantGetPtrOperatorEvaluator operator_evaluator;
GDExtensionPtrOperatorEvaluator transform_point,basis_point;
GDExtensionPtrBuiltInMethod transform_inverse,basis_transpose,vector_normalize;
bool bind_scene_model_api(){
 Name inverse("affine_inverse"),transpose("transposed"),normalize("normalized");
 transform_inverse=builtin_method(GDEXTENSION_VARIANT_TYPE_TRANSFORM3D,inverse.data,3816817146);
 basis_transpose=builtin_method(GDEXTENSION_VARIANT_TYPE_BASIS,transpose.data,594669093);
 vector_normalize=builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR3,normalize.data,1776574132);
 transform_point=operator_evaluator(GDEXTENSION_VARIANT_OP_MULTIPLY,GDEXTENSION_VARIANT_TYPE_TRANSFORM3D,GDEXTENSION_VARIANT_TYPE_VECTOR3);
 basis_point=operator_evaluator(GDEXTENSION_VARIANT_OP_MULTIPLY,GDEXTENSION_VARIANT_TYPE_BASIS,GDEXTENSION_VARIANT_TYPE_VECTOR3);
 return transform_inverse&&basis_transpose&&vector_normalize&&transform_point&&basis_point;
}
namespace scene_model {
struct Owner;
std::unordered_map<uint64_t,Owner*> model_owners;
uint64_t model_serial=0;
using Matrix=std::array<float,12>;
V3 engine(const V3& p){return {p[0],p[2],-p[1]};}
V3 native(const V3& p){return {p[0],-p[2],p[1]};}
V3 transformed(const Matrix& pose,const V3& p){V3 out{};transform_point(pose.data(),p.data(),out.data());return out;}
struct Part {
 uint64_t node=0;
 std::vector<scene_geometry::Face> faces;
 V3 low{},high{};
 Matrix pose{},inverse{};
 std::array<float,9> normals{};
 bool cached=false;
 bool update(){
  auto object=instance_from_id(node);if(!object||!cast_object(object,node_tag))return false;
  Matrix current{};ptrcall(node_transform,object,nullptr,current.data());
  if(!cached||std::memcmp(current.data(),pose.data(),sizeof(Matrix))!=0){
   pose=current;transform_inverse(pose.data(),nullptr,inverse.data(),0);
   std::array<float,9> basis{};transform_basis(inverse.data(),basis.data());basis_transpose(basis.data(),nullptr,normals.data(),0);cached=true;
  }return true;
 }
 bool overlaps(const V3& start,const V3& end)const{
  for(size_t axis=0;axis<3;++axis)if(std::max(start[axis],end[axis])<low[axis]||std::min(start[axis],end[axis])>high[axis])return false;return true;
 }
};
struct Owner {
	uint64_t token=++model_serial;
	Owner(){model_owners[token]=this;}
	~Owner(){model_owners.erase(token);}
	Owner(const Owner&)=delete;
 std::vector<Part> parts;
 bool configured=false;
 void configure(const Var& input){
  configured=false;parts.clear();auto rows=get(input,"parts");const auto count=size(rows);if(count>1048576)throw std::runtime_error("Native model collision part count exceeds capacity");
  std::vector<Part> next;next.reserve(static_cast<size_t>(count));
  for(int64_t n=0;n<count;++n){const auto row=at(rows,n);const auto geometry_token=static_cast<uint64_t>(get(row,"geometry").integer());const auto found=scene_geometry::geometry_owners.find(geometry_token);
   if(found==scene_geometry::geometry_owners.end()||!found->second->configured)throw std::runtime_error("Native model collision geometry identity is stale");
   Part part;part.node=static_cast<uint64_t>(get(row,"node").integer());part.faces=found->second->faces;part.low=values<3>(get(row,"low"));part.high=values<3>(get(row,"high"));next.push_back(std::move(part));
  }parts.swap(next);configured=true;
 }
 bool nearest_ray(const V3& start,V3& limit,V3& normal){
  if(!configured)throw std::runtime_error("Native model collision before configuration");
  const auto a=engine(start);auto b=engine(limit);bool found=false;
  for(auto& part:parts){
   if(!part.update())continue;
   const auto local_start=native(transformed(part.inverse,a));auto local_end=native(transformed(part.inverse,b));if(!part.overlaps(local_start,local_end))continue;
   V3 local_normal{};if(!scene_geometry::Owner::nearest_faces(part.faces,local_start,local_end,local_normal))continue;
   b=transformed(part.pose,engine(local_end));limit=native(b);V3 transformed_normal{},unit{};const auto n=engine(local_normal);basis_point(part.normals.data(),n.data(),transformed_normal.data());vector_normalize(transformed_normal.data(),nullptr,unit.data(),0);normal=native(unit);found=true;
  }
  return found;
 }
 Var nearest(const Var& input){
  const auto start=values<3>(get(input,"start"));auto limit=values<3>(get(input,"end"));V3 normal{};
  Var out;if(nearest_ray(start,limit,normal)){out=Var::dictionary();set(out,"position",array(limit));set(out,"normal",array(normal));}return out;
 }
};
}
GDExtensionObjectPtr scene_model_create(void*,GDExtensionBool notify){
 Name base("RefCounted"),name("NwnSceneModel");auto object=construct_object(base.data);auto owner=new scene_model::Owner();set_instance(object,name.data,owner);
 if(notify){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{Var::integer(0)});}return object;
}
void scene_model_free(void*,GDExtensionClassInstancePtr instance){delete static_cast<scene_model::Owner*>(instance);}
void scene_model_call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=2){error->error=count<2?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=2;new_nil(result);return;}
 try{auto& owner=*static_cast<scene_model::Owner*>(instance);Var operation(args[0]),input(args[1]),out;switch(operation.integer()){case 0:owner.configure(input);break;case 1:out=owner.nearest(input);break;case 2:if(!owner.configured)throw std::runtime_error("Native model identity before configuration");out=Var::integer(static_cast<int64_t>(owner.token));break;default:throw std::runtime_error("Unknown native model collision operation");}new_copy(result,out.data);}
 catch(const std::exception& err){auto out=Var::dictionary();set(out,"error",Var::text(err.what()));new_copy(result,out.data);}
}
template<typename Property>void register_scene_model(const Property& property){
 Name name("NwnSceneModel"),base("RefCounted"),method_name("dispatch"),empty(""),operation("operation"),input("input");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=scene_model_create;info.free_instance_func=scene_model_free;register_class(library,name.data,base.data,&info);
 auto ret=property(GDEXTENSION_VARIANT_TYPE_NIL,empty);ret.usage|=131072;GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo m{};m.name=method_name.data;m.call_func=scene_model_call;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=2;m.arguments_info=args;m.arguments_metadata=metadata;register_method(library,name.data,&m);
}
