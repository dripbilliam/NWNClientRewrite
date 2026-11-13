// LightManager::PrioritizeLights / ControlLightsFade, original SHA pinned in
// the independent instruction oracle. SetupLightsForThisPositionAndRadius is
// the main world's sphere collection. Optional supplied candidate/view lists
// remain explicit boundaries; static BSP bake/per-mesh lighting is separate.
namespace light_history {
bool registered=false;
double number(const Var& input,const char* name,double fallback){if(!has(input,name))return fallback;const auto value=get(input,name);return value.type()==GDEXTENSION_VARIANT_TYPE_BOOL?(value.boolean()?1:0):value.number();}
int64_t id_value(const Var& value){const auto n=value.number();if(!std::isfinite(n)||std::trunc(n)!=n||std::abs(n)>9007199254740991.0)throw std::runtime_error("Native light identity is invalid");return static_cast<int64_t>(n);}
struct Light {
 int64_t id=0,owner=0;V3 color{},position{};float radius=0,multiplier=1,fade[2]{},score=0,distance=0;
 int32_t priority=4,override_value=0,dynamic=1;bool affect=true,fading=true,in_view=true;
 void update(const Var& row){
  if(has(row,"color"))color=values<3>(get(row,"color"));if(has(row,"position"))position=values<3>(get(row,"position"));
  radius=static_cast<float>(number(row,"radius",radius));multiplier=static_cast<float>(number(row,"multiplier",multiplier));
  owner=static_cast<int64_t>(number(row,"owner",static_cast<double>(owner)));priority=static_cast<int32_t>(number(row,"priority",priority));override_value=static_cast<int32_t>(number(row,"override",override_value));dynamic=static_cast<int32_t>(number(row,"dynamic",dynamic));
  affect=number(row,"affect",affect?1:0)!=0;fading=number(row,"fading",fading?1:0)!=0;in_view=number(row,"in_view",1)!=0;
  for(auto v:color)if(!std::isfinite(v))throw std::runtime_error("Nonfinite native light color");for(auto v:position)if(!std::isfinite(v))throw std::runtime_error("Nonfinite native light position");if(!std::isfinite(radius)||!std::isfinite(multiplier))throw std::runtime_error("Nonfinite native light range");
 }
 float adjusted_radius(bool enhanced,float cutoff)const{float range=radius;if(range<1000){range=range*multiplier;if(enhanced){const auto peak=std::max(color[2],std::max(color[1],color[0]));if(peak>1)range=range*peak;range=cutoff*range;}}return range;}
 bool collect(const V3& focus,float sphere,bool enhanced,float cutoff)const{
  if((!dynamic&&!affect)||radius<=0||radius>=1000||multiplier<=0||(color[0]==0&&color[1]==0&&color[2]==0))return false;
  const auto x=position[0]-focus[0],y=position[1]-focus[1],z=position[2]-focus[2],range=adjusted_radius(enhanced,cutoff)+sphere;
  return ((y*y+x*x)+z*z)<range*range;
 }
 float speed(bool enhanced,float cutoff)const{
  auto rgb=color;float range=radius;const auto peak=std::max(rgb[2],std::max(rgb[1],rgb[0]));
  if(radius<1000){range=range*multiplier;if(enhanced){if(peak>1){for(auto& v:rgb)v=v/peak;range=range*peak;}range=cutoff*range;}}
  return 10.0f/std::clamp(range*std::max(rgb[2],std::max(rgb[1],rgb[0])),1.0f,10.0f);
 }
 void rank(const V3& focus,int64_t only){
  const V3 d{position[0]-focus[0],position[1]-focus[1],position[2]-focus[2]};distance=std::sqrt((d[0]*d[0]+d[1]*d[1])+d[2]*d[2]);
  const float peak=std::max(std::abs(color[2]),std::max(std::abs(color[1]),std::abs(color[0])));
  if(peak<=0||radius<=0||multiplier<=0)score=100000;
  else if(owner&&owner==only)score=-1;
  else{const auto p=override_value?override_value:priority;const float strength=fading?(multiplier*radius)*peak:20.0f;score=(static_cast<float>(p+1)*distance)/(static_cast<float>(dynamic+4)*(strength+1.0f));}
 }
};
struct Owner {
 std::unordered_map<int64_t,Light> lights;std::array<Light,2> area;bool area_present[2]{},closed=false,enhanced=true;float cutoff=2;
 std::vector<int64_t> active[2],order,registration,collected;int64_t steps=0;Var calls=array_empty();
 Light& lamp(int64_t id){auto it=lights.find(id);if(it==lights.end())throw std::runtime_error("Native light candidate has no physical lamp");return it->second;}
 void updates(const Var& input,bool initial){
  if(has(input,"enhanced"))enhanced=get(input,"enhanced").boolean();if(has(input,"cutoff"))cutoff=f(input,"cutoff");
  if(has(input,"lights")){auto rows=get(input,"lights");if(size(rows)>16384)throw std::runtime_error("Native light input exceeds bounded physical registry");for(int64_t n=0;n<size(rows);++n){auto row=at(rows,n);const auto id=has(row,"id")?id_value(get(row,"id")):n;auto [it,inserted]=lights.try_emplace(id);auto& light=it->second;light.id=id;light.update(row);if(inserted)registration.push_back(id);if(initial||inserted){light.fade[0]=static_cast<float>(number(row,"fade0",0));light.fade[1]=static_cast<float>(number(row,"fade1",0));}}}
  for(int n=0;n<2;++n){const auto name=n==0?"ambient":"diffuse";if(!has(input,name))continue;auto row=get(input,name);area_present[n]=!row.nil();if(area_present[n]){area[n].update(row);if(initial){area[n].fade[0]=static_cast<float>(number(row,"fade0",0));area[n].fade[1]=static_cast<float>(number(row,"fade1",0));}}}
 }
 static bool contains(const std::vector<int64_t>& list,int64_t id){return std::find(list.begin(),list.end(),id)!=list.end();}
 int64_t rank_index(int64_t id)const{const auto it=std::find(order.begin(),order.end(),id);return it==order.end()?-1:static_cast<int64_t>(it-order.begin());}
 void step(const Var& input){
  if(closed)throw std::runtime_error("Native light history is closed");updates(input,false);order.clear();
  const auto only=static_cast<int64_t>(number(input,"only_owner",0));const auto focus=has(input,"focus")?values<3>(get(input,"focus")):V3{};
  if(has(input,"collect_radius")){const auto radius=f(input,"collect_radius");for(auto id:registration)if(lamp(id).collect(focus,radius,enhanced,cutoff))order.push_back(id);}
  else{auto candidates=get(input,"candidates");if(size(candidates)>16384)throw std::runtime_error("Native light candidates exceed bounded physical registry");for(int64_t n=0;n<size(candidates);++n){const auto id=id_value(at(candidates,n));lamp(id);if(contains(order,id))throw std::runtime_error("Duplicate native light candidate");order.push_back(id);}}
  collected=order;
  if(number(input,"sort",1)!=0){for(auto id:order)lamp(id).rank(focus,only);particle_native_sort::sort(order,[&](auto a,auto b){return lamp(a).score<lamp(b).score;});}
  const auto channel=number(input,"channel",0)==0?0:1;auto& old=active[channel];const auto maximum=std::min<uint32_t>(static_cast<uint32_t>(number(input,"maximum",128)),128);const bool head=number(input,"headlight",0)!=0;const float dt=std::max(static_cast<float>(number(input,"delta",1.0/60)),.0001f);
  int32_t slots=static_cast<int32_t>(maximum)-(head?2:0);
  if(only){slots=0;for(auto id:order){if(lamp(id).owner!=only)break;++slots;}slots=std::min(slots,static_cast<int32_t>(maximum));}
  for(int64_t n=static_cast<int64_t>(old.size())-1;n>=0;--n){auto& light=lamp(old[static_cast<size_t>(n)]);const auto index=rank_index(light.id);auto& fade=light.fade[channel];bool remove=index<0;
   if(!remove&&index<slots){if(fade<1)fade=std::min(light.speed(enhanced,cutoff)*dt+fade,1.0f);}
   else if(!remove){if(!light.in_view)remove=true;else{fade=fade-light.speed(enhanced,cutoff)*dt;remove=fade<0;}}
   if(remove){fade=0;old.erase(old.begin()+n);}
  }
  int new_nonfading=0;for(int32_t n=0;n<slots&&n<static_cast<int32_t>(order.size());++n){auto& light=lamp(order[static_cast<size_t>(n)]);if(!light.fading&&!contains(old,light.id)&&(!only||light.owner==only))++new_nonfading;}
  int free=slots-static_cast<int>(old.size());
  for(int64_t n=static_cast<int64_t>(old.size())-1;free<new_nonfading&&n>=0;--n){const auto index=rank_index(old[static_cast<size_t>(n)]);if(index<0||index>=slots){old.erase(old.begin()+n);++free;}} // Native eviction leaves Part fade untouched.
  for(auto id:order){if(static_cast<int64_t>(old.size())>=slots)break;if(contains(old,id))continue;auto& light=lamp(id);old.push_back(id);light.fade[channel]=light.fading?std::min(light.speed(enhanced,cutoff)*dt,1.0f):1.0f;}
  for(int n=0;n<2;++n)if(area_present[n]){auto& light=area[n];auto& fade=light.fade[channel];if(!only||only==light.owner){if(fade<1)fade=std::min(light.speed(enhanced,cutoff)*dt+fade,1.0f);}else fade=std::max(fade-light.speed(enhanced,cutoff)*dt,0.0f);}
  calls=array_empty();auto append=[&](Var row){method(calls,"append",{row});};int slot=0;
  if(head){auto row=Var::dictionary();set(row,"kind",Var::text("headlight"));append(row);slot=2;}
  for(auto id:old){if(slot>=static_cast<int>(maximum))break;auto row=Var::dictionary();set(row,"kind",Var::text("draw"));set(row,"id",Var::integer(id));set(row,"slot",Var::integer(slot++));set(row,"fade",Var::number(lamp(id).fade[channel]));append(row);}
  while(slot<static_cast<int>(maximum)){auto row=Var::dictionary();set(row,"kind",Var::text("disable"));set(row,"slot",Var::integer(slot++));append(row);}++steps;
 }
 static Var ids(const std::vector<int64_t>& rows){auto out=array_empty();for(auto id:rows)method(out,"append",{Var::integer(id)});return out;}
 Var result(bool full)const{
  auto out=Var::dictionary();set(out,"closed",Var::boolean(closed));set(out,"steps",Var::integer(steps));set(out,"calls",calls);set(out,"active0",ids(active[0]));set(out,"active1",ids(active[1]));auto areas=array_empty();for(const auto& light:area)method(areas,"append",{array(std::array<float,2>{light.fade[0],light.fade[1]})});set(out,"area_fades",areas);
  if(full){set(out,"order",ids(order));set(out,"collected",ids(collected));auto rows=array_empty();std::vector<int64_t> sorted;for(const auto& [id,light]:lights)sorted.push_back(id);std::sort(sorted.begin(),sorted.end());for(auto id:sorted){const auto& light=lights.at(id);auto row=Var::dictionary();set(row,"id",Var::integer(id));set(row,"fade0",Var::number(light.fade[0]));set(row,"fade1",Var::number(light.fade[1]));set(row,"score",Var::number(light.score));set(row,"distance",Var::number(light.distance));method(rows,"append",{row});}set(out,"lights",rows);}return out;
 }
 Var operate(int64_t operation,const Var& input){
  if(operation==0){if(closed)throw std::runtime_error("Native light history cannot reopen");lights.clear();active[0].clear();active[1].clear();order.clear();registration.clear();collected.clear();area={};area_present[0]=area_present[1]=false;steps=0;calls=array_empty();updates(input,true);for(int n=0;n<2;++n){const auto name=n==0?"active0":"active1";if(has(input,name)){auto list=get(input,name);for(int64_t j=0;j<size(list);++j){const auto id=id_value(at(list,j));lamp(id);active[n].push_back(id);}}}return result(true);}
  if(operation==1){step(input);return result(number(input,"full",0)!=0);}if(operation==2)return result(true);
  if(operation==3){auto rows=get(input,"ids");for(int64_t n=0;n<size(rows);++n){const auto id=id_value(at(rows,n));for(auto* list:{&active[0],&active[1],&order,&registration,&collected})list->erase(std::remove(list->begin(),list->end(),id),list->end());lights.erase(id);}return result(false);}
  if(operation==8){lights.clear();active[0].clear();active[1].clear();order.clear();registration.clear();collected.clear();calls=array_empty();closed=true;return result(false);}throw std::runtime_error("Unknown native light history operation");
 }
};
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnLightHistory");auto object=construct_object(base.data);auto* owner=new Owner();set_instance(object,name.data,owner);if(notify){Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](v.data,&object);method(v,"notification",{Var::integer(0)});}return object;}
void free(void*,GDExtensionClassInstancePtr instance){delete static_cast<Owner*>(instance);}
void dispatch(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,2,result,error))return;try{const Var operation(args[0]),input(args[1]);const auto out=static_cast<Owner*>(instance)->operate(operation.integer(),input);new_copy(result,out.data);}catch(const std::exception& reason){auto out=Var::dictionary();set(out,"error",Var::text(reason.what()));new_copy(result,out.data);}}
template<class Property>void register_owner(Property property){Name name("NwnLightHistory"),base("RefCounted"),method_name("dispatch"),empty(""),operation("operation"),input("input");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free;register_class(library,name.data,base.data,&info);registered=true;auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo method{};method.name=method_name.data;method.call_func=dispatch;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;method.has_return_value=true;method.return_value_info=&ret;method.argument_count=2;method.arguments_info=args;method.arguments_metadata=metadata;register_method(library,name.data,&method);}
void unregister_owner(){if(registered){Name name("NwnLightHistory");unregister_class(library,name.data);registered=false;}}
}
