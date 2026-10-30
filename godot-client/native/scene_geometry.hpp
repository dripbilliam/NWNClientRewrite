// Private immutable collision data. This replaces interpreter/Variant work per
// face, not Scene membership or the original BSP. Physical face order and the
// polyhit231810 FLOAT operation order are retained; /fp:strict forbids fusion.
namespace scene_geometry {
struct Face { std::array<V3,3> vertices; V3 normal; float constant; bool excluded; };
struct Owner;
std::unordered_map<uint64_t,Owner*> geometry_owners;
uint64_t geometry_serial=0;
double element(const Var& sequence,int64_t index){
 Var out;destroy(out.data);GDExtensionBool valid=0,oob=0;get_indexed(sequence.data,index,out.data,&valid,&oob);
 if(!valid||oob)throw std::runtime_error("Native collision array index invalid");return out.number();
}
struct Owner {
 uint64_t token=++geometry_serial;
 std::vector<Face> faces;
 bool configured=false;
 Owner(){geometry_owners[token]=this;}
 ~Owner(){geometry_owners.erase(token);}
 Owner(const Owner&)=delete;
 void configure(const Var& input){
  configured=false;faces.clear();auto vertices=get(input,"vertices"),indices=get(input,"indices"),planes=get(input,"planes"),types=get(input,"types");
  const auto vertex_count=size(vertices),index_count=size(indices),plane_count=size(planes),type_count=size(types);
  if(vertex_count%3||index_count%3||plane_count!=index_count/3*4)throw std::runtime_error("Native collision array dimensions invalid");
  std::vector<Face> next;next.reserve(static_cast<size_t>(index_count/3));
  for(int64_t at=0;at<index_count;at+=3){
   Face face{};const auto index=at/3;
   for(int64_t corner=0;corner<3;++corner){const auto raw=element(indices,at+corner);if(!std::isfinite(raw)||raw<0||raw>=static_cast<double>(vertex_count/3)||std::trunc(raw)!=raw)throw std::runtime_error("Native collision vertex index invalid");const auto offset=static_cast<int64_t>(raw)*3;
    for(int64_t axis=0;axis<3;++axis)face.vertices[static_cast<size_t>(corner)][static_cast<size_t>(axis)]=static_cast<float>(element(vertices,offset+axis));}
   for(int64_t axis=0;axis<3;++axis)face.normal[static_cast<size_t>(axis)]=static_cast<float>(element(planes,index*4+axis));
   face.constant=static_cast<float>(element(planes,index*4+3));face.excluded=index<type_count&&(static_cast<int64_t>(element(types,index))&63)==30;next.push_back(face);
  }
  faces.swap(next);configured=true;
 }
 // Every intermediate is a FLOAT, including the distinct distance_start/distance_end dot orders.
 static bool hit(const Face& f,const V3& start,const V3& end,V3& point){
  const auto& n=f.normal;const float distance_start=((n[1]*start[1]+n[0]*start[0])+n[2]*start[2])+f.constant;
  if(distance_start<0)return false;
  const float distance_end=((n[0]*end[0]+n[1]*end[1])+n[2]*end[2])+f.constant;
  if(distance_end>0||distance_start==distance_end)return false;
  const float t=distance_start/(distance_start-distance_end),a=1.0f-t;
  point={a*start[0]+t*end[0],a*start[1]+t*end[1],t*end[2]+a*start[2]};
  for(size_t i=0;i<3;++i){V3 d{},p{};for(size_t axis=0;axis<3;++axis){d[axis]=f.vertices[(i+1)%3][axis]-f.vertices[i][axis];p[axis]=point[axis]-f.vertices[i][axis];}
   const float x=d[1]*p[2]-p[1]*d[2],z=d[0]*p[1]-d[1]*p[0],y=p[0]*d[2]-d[0]*p[2];
   if(!((y*n[1]+x*n[0])+z*n[2]>=0))return false;
  }return true;
 }
 static bool nearest_faces(const std::vector<Face>& source,const V3& start,V3& end,V3& normal){
  bool found=false;for(const auto& face:source){if(face.excluded)continue;V3 point{};if(hit(face,start,end,point)){end=point;normal=face.normal;found=true;}}return found;
 }
 Var nearest(const Var& input) const {
  if(!configured)throw std::runtime_error("Native collision query before configuration");
  const auto start=values<3>(get(input,"start"));auto end=values<3>(get(input,"end"));V3 normal{};const bool found=nearest_faces(faces,start,end,normal);
  Var out;if(found){out=Var::dictionary();set(out,"position",array(end));set(out,"normal",array(normal));}return out;
 }
};
}
GDExtensionObjectPtr scene_geometry_create(void*,GDExtensionBool notify){
 Name base("RefCounted"),name("NwnSceneGeometry");auto object=construct_object(base.data);auto owner=new scene_geometry::Owner();set_instance(object,name.data,owner);
 if(notify){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{Var::integer(0)});}return object;
}
void scene_geometry_free(void*,GDExtensionClassInstancePtr instance){delete static_cast<scene_geometry::Owner*>(instance);}
void scene_geometry_call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=2){error->error=count<2?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=2;new_nil(result);return;}
 try{auto& owner=*static_cast<scene_geometry::Owner*>(instance);Var operation(args[0]),input(args[1]),out;switch(operation.integer()){case 0:owner.configure(input);break;case 1:out=owner.nearest(input);break;case 2:if(!owner.configured)throw std::runtime_error("Native collision identity before configuration");out=Var::integer(static_cast<int64_t>(owner.token));break;default:throw std::runtime_error("Unknown native collision operation");}new_copy(result,out.data);}
 catch(const std::exception& err){auto out=Var::dictionary();set(out,"error",Var::text(err.what()));new_copy(result,out.data);}
}
template<typename Property>void register_scene_geometry(const Property& property){
 Name name("NwnSceneGeometry"),base("RefCounted"),method_name("dispatch"),empty(""),operation("operation"),input("input");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=scene_geometry_create;info.free_instance_func=scene_geometry_free;register_class(library,name.data,base.data,&info);
 auto ret=property(GDEXTENSION_VARIANT_TYPE_NIL,empty);ret.usage|=131072;GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo m{};m.name=method_name.data;m.call_func=scene_geometry_call;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=2;m.arguments_info=args;m.arguments_metadata=metadata;register_method(library,name.data,&m);
}
