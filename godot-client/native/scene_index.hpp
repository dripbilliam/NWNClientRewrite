// Main-thread conservative fixed-root lookup. Tokens/IDs are weak; no borrowed
// scene pointer survives a call. Exact original-face/Part queries are unchanged.
namespace scene_index {
GDExtensionPtrBuiltInMethod intersects_segment;
GDExtensionMethodBindPtr queued_method;
bool bind(){Name name("intersects_segment"),object("Object"),queued("is_queued_for_deletion");intersects_segment=builtin_method(GDEXTENSION_VARIANT_TYPE_AABB,name.data,2048133369);queued_method=class_method(object.data,queued.data,36873697);return intersects_segment&&queued_method;}
using Box=std::array<float,6>;
struct Cell {int64_t x,z;bool operator==(const Cell& b)const{return x==b.x&&z==b.z;}};
struct CellHash {size_t operator()(const Cell& c)const{return std::hash<int64_t>{}(c.x)^(std::hash<int64_t>{}(c.z)<<1);}};
bool overlap(const Box& box,const V3& a,const V3& b){const GDExtensionConstTypePtr args[]={a.data(),b.data()};Var result;destroy(result.data);auto local=box;intersects_segment(local.data(),args,result.data,2);return !result.nil();}
Box read_box(const Var& value){if(value.type()!=GDEXTENSION_VARIANT_TYPE_AABB)throw std::runtime_error("Native index requires an AABB");Box box{};to[GDEXTENSION_VARIANT_TYPE_AABB](box.data(),const_cast<uint8_t*>(value.data));return box;}
struct Root {uint64_t node=0,model=0,order=0;Box broad{},exact{};bool bounded=false;std::vector<Cell> cells;};
struct Owner;
std::unordered_map<uint64_t,Owner*> index_owners;
uint64_t index_serial=0;
struct Owner {
	uint64_t token=++index_serial;
	Owner(){index_owners[token]=this;}
	~Owner(){index_owners.erase(token);}
	Owner(const Owner&)=delete;
 std::unordered_map<uint64_t,Root> roots;
 std::unordered_map<Cell,std::vector<uint64_t>,CellHash> cells,cache;
 std::vector<uint64_t> global;
 uint64_t serial=0,queries=0,candidates=0,cache_hits=0;
 static Cell cell(float x,float z){const double a=std::floor(static_cast<double>(x)/10.0),b=std::floor(static_cast<double>(z)/10.0);if(!std::isfinite(a)||!std::isfinite(b)||std::abs(a)>1e12||std::abs(b)>1e12)throw std::runtime_error("Native index coordinate out of range");return {static_cast<int64_t>(a),static_cast<int64_t>(b)};}
 static bool large(const Cell& a,const Cell& b){return b.x-a.x>1023||b.z-a.z>1023||(b.x-a.x+1)*(b.z-a.z+1)>1024;}
 void erase(uint64_t id){auto found=roots.find(id);if(found==roots.end())return;cache.clear();for(const auto& key:found->second.cells){auto& values=cells.at(key);values.erase(std::remove(values.begin(),values.end(),id),values.end());if(values.empty())cells.erase(key);}global.erase(std::remove(global.begin(),global.end(),id),global.end());roots.erase(found);}
 void put(const Var& input){
  Root root;root.node=static_cast<uint64_t>(get(input,"node").integer());root.model=static_cast<uint64_t>(get(input,"model").integer());const auto model=scene_model::model_owners.find(root.model);if(model==scene_model::model_owners.end()||!model->second->configured)throw std::runtime_error("Native index model token is stale");
  root.order=static_cast<uint64_t>(get(input,"order").integer());erase(root.node);cache.clear();root.bounded=has(input,"bounds");if(root.bounded){root.broad=read_box(get(input,"bounds"));root.exact=read_box(get(input,"exact"));const auto a=cell(root.broad[0],root.broad[2]),b=cell(root.broad[0]+root.broad[3],root.broad[2]+root.broad[5]);if(!large(a,b)){for(auto x=a.x;x<=b.x;++x)for(auto z=a.z;z<=b.z;++z){Cell key{x,z};cells[key].push_back(root.node);root.cells.push_back(key);}}}
  if(root.cells.empty())global.push_back(root.node);roots[root.node]=std::move(root);
 }
 std::vector<uint64_t> select(const V3& a,const V3& b){
  const auto first=cell(a[0],a[2]),last=cell(b[0],b[2]);if(first==last){const auto found=cache.find(first);if(found!=cache.end()){++cache_hits;return found->second;}}
  std::vector<uint64_t> ids;const Cell low{std::min(first.x,last.x),std::min(first.z,last.z)},high{std::max(first.x,last.x),std::max(first.z,last.z)};
  if(large(low,high)){for(const auto& row:roots)ids.push_back(row.first);}else{ids=global;for(auto x=low.x;x<=high.x;++x)for(auto z=low.z;z<=high.z;++z){const auto found=cells.find({x,z});if(found!=cells.end())ids.insert(ids.end(),found->second.begin(),found->second.end());}}
  std::sort(ids.begin(),ids.end(),[&](uint64_t x,uint64_t y){return roots.at(x).order<roots.at(y).order;});ids.erase(std::unique(ids.begin(),ids.end()),ids.end());if(first==last){if(cache.size()>=4096)cache.clear();cache[first]=ids;}return ids;
 }
 bool nearest_ray(const V3& start,V3& end,V3& normal){
  ++queries;const auto a=scene_model::engine(start);auto b=scene_model::engine(end);bool hit=false;
  for(const auto id:select(a,b)){const auto& root=roots.at(id);auto object=instance_from_id(root.node);if(!object||!cast_object(object,node_tag))continue;GDExtensionBool queued=false;ptrcall(queued_method,object,nullptr,&queued);if(queued)continue;
   if(root.bounded&&(!overlap(root.broad,a,b)||!overlap(root.exact,a,b)))continue;const auto model=scene_model::model_owners.find(root.model);if(model==scene_model::model_owners.end())continue;++candidates;
   if(model->second->nearest_ray(start,end,normal)){hit=true;b=scene_model::engine(end);}
  }
  return hit;
 }
 Var nearest(const Var& input){
  const auto start=values<3>(get(input,"start"));auto end=values<3>(get(input,"end"));V3 normal{};
  Var out;if(nearest_ray(start,end,normal)){out=Var::dictionary();set(out,"position",array(end));set(out,"normal",array(normal));}return out;
 }
 void clear(){roots.clear();cells.clear();global.clear();cache.clear();serial=0;}
 Var snapshot(){auto out=Var::dictionary();set(out,"entries",Var::integer(static_cast<int64_t>(roots.size())));set(out,"queries",Var::integer(static_cast<int64_t>(queries)));set(out,"candidates",Var::integer(static_cast<int64_t>(candidates)));set(out,"cache_hits",Var::integer(static_cast<int64_t>(cache_hits)));return out;}
};
}
bool direct_scene_trace(uint64_t terrain,uint64_t statics,const V3& start,V3& end,V3& normal,bool& hit){
 // Zero identifies a verified empty group; stale nonzero tokens must fall back.
 // WOK vertical sampling and batched terrain retain the established GD path.
 if(start[0]==end[0]&&start[1]==end[1])return false;
 const auto a=scene_index::index_owners.find(terrain),b=scene_index::index_owners.find(statics);
 if((terrain&&a==scene_index::index_owners.end())||(statics&&b==scene_index::index_owners.end()))return false;
 hit=false;if(terrain)hit=a->second->nearest_ray(start,end,normal);if(statics)hit=b->second->nearest_ray(start,end,normal)||hit;return true;
}
GDExtensionObjectPtr scene_index_create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnSceneIndex");auto object=construct_object(base.data);set_instance(object,name.data,new scene_index::Owner());if(notify){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{Var::integer(0)});}return object;}
void scene_index_free(void*,GDExtensionClassInstancePtr instance){delete static_cast<scene_index::Owner*>(instance);}
void scene_index_call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){error->error=GDEXTENSION_CALL_OK;if(count!=2){error->error=count<2?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=2;new_nil(result);return;}try{auto& owner=*static_cast<scene_index::Owner*>(instance);Var op(args[0]),input(args[1]),out;switch(op.integer()){case 0:owner.put(input);break;case 1:out=owner.nearest(input);break;case 2:owner.erase(static_cast<uint64_t>(get(input,"node").integer()));break;case 3:owner.clear();break;case 4:out=owner.snapshot();break;case 5:out=Var::integer(static_cast<int64_t>(owner.token));break;default:throw std::runtime_error("Unknown native scene index operation");}new_copy(result,out.data);}catch(const std::exception& err){auto out=Var::dictionary();set(out,"error",Var::text(err.what()));new_copy(result,out.data);}}
template<typename Property>void register_scene_index(const Property& property){Name name("NwnSceneIndex"),base("RefCounted"),method_name("dispatch"),empty(""),operation("operation"),input("input");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=scene_index_create;info.free_instance_func=scene_index_free;register_class(library,name.data,base.data,&info);auto ret=property(GDEXTENSION_VARIANT_TYPE_NIL,empty);ret.usage|=131072;GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo m{};m.name=method_name.data;m.call_func=scene_index_call;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=2;m.arguments_info=args;m.arguments_metadata=metadata;register_method(library,name.data,&m);}
