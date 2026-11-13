// Private candidate: retained owner-published field dictionaries and immediate-parent
// visibility; exact transform and metadata polls remain live. No cached Node pointers,
// solver/order/distance/room-policy changes. Unknown facades retain prior polling.
namespace light_input_registry {
bool registered=false;
struct Reader {
 Name object_class{"Object"},node_class{"Node"},get_name{"get"},meta_name{"get_meta"},parent_name{"get_parent"},plane_name{"distance_to"};
 Name props_name{"native_properties"},revision_name{"native_properties_revision"},state_name{"native_state"},enhanced_name{"native_enhanced_light"},priority_name{"native_light_priority"};
 GDExtensionMethodBindPtr property=nullptr,metadata=nullptr,parent=nullptr;GDExtensionPtrBuiltInMethod plane_distance=nullptr;
 Reader(){property=class_method(object_class.data,get_name.data,2760726917);metadata=class_method(object_class.data,meta_name.data,3990617847);parent=class_method(node_class.data,parent_name.data,3160264692);plane_distance=builtin_method(GDEXTENSION_VARIANT_TYPE_PLANE,plane_name.data,1047977935);if(!property||!metadata||!parent||!plane_distance)throw std::runtime_error("Native light registry API is absent");}
 Var read(GDExtensionObjectPtr object,const Name& name)const{Var value;const GDExtensionConstTypePtr args[]={name.data};ptrcall(property,object,args,value.data);return value;}
 Var meta(GDExtensionObjectPtr object,const Name& name,const Var& fallback)const{Var value;const GDExtensionConstTypePtr args[]={name.data,fallback.data};ptrcall(metadata,object,args,value.data);return value;}
 GDExtensionObjectPtr get_parent(GDExtensionObjectPtr object)const{GDExtensionObjectPtr value=nullptr;ptrcall(parent,object,nullptr,&value);return value;}
 V3 position(GDExtensionObjectPtr object)const{alignas(8) std::array<float,12> transform{};V3 value{};ptrcall(node_transform,object,nullptr,transform.data());transform_origin(transform.data(),value.data());return value;}
 bool visible(GDExtensionObjectPtr object)const{GDExtensionBool value=false;ptrcall(particle_frame_group::visible_in_tree,object,nullptr,&value);return value!=0;}
 bool inside(GDExtensionObjectPtr object)const{GDExtensionBool value=false;ptrcall(particle_frame_group::inside_tree,object,nullptr,&value);return value!=0;}
 bool in_view(const std::vector<std::array<float,4>>& planes,const V3& point,double radius)const{for(const auto& plane:planes){double distance=0;const GDExtensionConstTypePtr args[]={point.data()};plane_distance(const_cast<float*>(plane.data()),args,&distance,1);if(distance>radius)return false;}return true;}
};
struct Entry {
 int64_t id=0,source=0,revision=-1,owner=0,priority=0;bool published=false,position_known=false,in_view=true;
 V3 position{};double range=-1;Var row;
 bool pushed=false,pushed_inside=false,parent_visible=true,retiring=false;int64_t publication=-1,pushed_revision=-1;Var pushed_properties,pushed_state;
};
struct Owner {
 Reader reader;std::unordered_map<int64_t,Entry> entries;std::vector<int64_t> order,pending_removed;bool closed=false;
 int64_t polls=0,view_tests=0,input_rows=0,reused=0,dead=0,pushes=0,pushed_members=0,stale_pushes=0;bool polling=false;
 std::vector<std::pair<int64_t,Var>> deferred_membership;
 static void append(Var& rows,int64_t id){method(rows,"append",{Var::integer(id)});}
 static bool same(const V3& a,const V3& b){return a[0]==b[0]&&a[1]==b[1]&&a[2]==b[2];}
 void add(const Var& input){
  if(closed)throw std::runtime_error("Native light input registry is closed");if(polling){deferred_membership.emplace_back(0,input);return;}const auto id=light_history::id_value(get(input,"id")),source=light_history::id_value(get(input,"source"));
  auto [it,inserted]=entries.try_emplace(id);const bool published=it->second.published;if(it->second.pushed)--pushed_members;it->second=Entry{};it->second.id=id;it->second.source=source;it->second.published=published;if(inserted)order.push_back(id);
 }
 void erase(int64_t id){if(polling){const auto found=entries.find(id);if(found!=entries.end())found->second.retiring=true;deferred_membership.emplace_back(2,Var::integer(id));return;}const auto it=entries.find(id);if(it==entries.end())return;if(it->second.published)pending_removed.push_back(id);if(it->second.pushed)--pushed_members;entries.erase(it);order.erase(std::remove(order.begin(),order.end(),id),order.end());}
 void push(const Var& input){
  if(closed)throw std::runtime_error("Native light input registry is closed");const auto id=light_history::id_value(get(input,"id"));
  if(polling&&std::any_of(deferred_membership.begin(),deferred_membership.end(),[&](const auto& item){return item.first==0&&light_history::id_value(get(item.second,"id"))==id;})){deferred_membership.emplace_back(5,input);return;}
  const auto it=entries.find(id);if(it==entries.end())return;auto& e=it->second;const auto serial=get(input,"publication").integer();if(serial<=e.publication){++stale_pushes;return;}
  auto props=get(input,"properties"),state=get(input,"state");if(props.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||state.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Native pushed light inputs require owner dictionaries");
  if(!e.pushed)++pushed_members;e.pushed=true;e.publication=serial;e.pushed_revision=get(input,"revision").integer();e.pushed_properties=props;e.pushed_state=state;e.pushed_inside=get(input,"inside").boolean();e.parent_visible=get(input,"parent_visible").boolean();++pushes;
 }
 void flush_deferred(){
  auto pending=std::move(deferred_membership);deferred_membership.clear();
  for(auto& item:pending){if(item.first==0)add(item.second);else if(item.first==2)erase(item.second.integer());else if(item.first==5)push(item.second);}
 }
 Var poll(const Var& input){
  if(polling)throw std::runtime_error("Native light input registry poll is reentrant");polling=true;
  try{auto result=poll_inner(input);polling=false;flush_deferred();return result;}catch(...){polling=false;flush_deferred();throw;}
 }
 Var poll_inner(const Var& input){
  if(closed)throw std::runtime_error("Native light input registry is closed");const bool view_changed=get(input,"view_changed").boolean();auto source_planes=get(input,"planes");std::vector<std::array<float,4>> planes;
  const auto plane_count=size(source_planes);if(plane_count!=0&&plane_count!=6)throw std::runtime_error("Native light registry requires zero or six camera planes");
  for(int64_t n=0;n<plane_count;++n){auto value=at(source_planes,n);if(value.type()!=GDEXTENSION_VARIANT_TYPE_PLANE)throw std::runtime_error("Native light registry camera is not a Plane array");std::array<float,4> plane{};to[GDEXTENSION_VARIANT_TYPE_PLANE](plane.data(),value.data);planes.push_back(plane);}
  auto rows=array_empty(),removed=array_empty(),retired=array_empty();for(auto id:pending_removed)append(removed,id);pending_removed.clear();std::vector<int64_t> tombstones;
  int64_t reused_now=0,tests_now=0,rows_now=0;
  const Var default_false=Var::boolean(false),default_zero=Var::integer(0);
  const auto frame_members=order.size();for(size_t member=0;member<frame_members;++member){const auto id=order[member];
   auto& e=entries.at(id);auto object=instance_from_id(static_cast<uint64_t>(id));bool eligible=object&&cast_object(object,node_tag);Var props;
   if(!eligible){append(retired,id);tombstones.push_back(id);++dead;}
   V3 pushed_position{};bool position_ready=false;
   if(eligible){if(e.pushed){if(e.pushed_inside&&e.parent_visible&&!e.retiring){pushed_position=reader.position(object);position_ready=true;}eligible=instance_from_id(static_cast<uint64_t>(id))==object&&e.pushed_inside&&e.parent_visible&&!e.retiring;}else{const auto parent=reader.get_parent(object);eligible=reader.inside(object)&&(!parent||!cast_object(parent,node_tag)||reader.visible(parent));}}
   if(eligible){props=e.pushed?e.pushed_properties:reader.read(object,reader.props_name);eligible=props.type()==GDEXTENSION_VARIANT_TYPE_DICTIONARY&&size(props)>0&&reader.meta(object,reader.enhanced_name,default_false).boolean();if(eligible)eligible=!(light_history::number(props,"radius",0)>=1000);}
   if(!eligible){if(e.published){append(removed,id);e.published=false;}continue;}
   const auto position=position_ready?pushed_position:reader.position(object);auto state=e.pushed?e.pushed_state:reader.read(object,reader.state_name);const auto range=light_history::number(state,"range",0);
   if(e.row.nil()||view_changed||!e.position_known||!same(e.position,position)||e.range!=range){e.in_view=reader.in_view(planes,position,range);e.range=range;++tests_now;}
   const auto source=e.source?instance_from_id(static_cast<uint64_t>(e.source)):nullptr;const int64_t owner=source?e.source:0;
   const auto priority=reader.meta(object,reader.priority_name,default_zero).integer();const auto revision=e.pushed?e.pushed_revision:reader.read(object,reader.revision_name).integer();bool changed=!e.published;
   if(e.row.nil()||e.revision!=revision){
    e.row=Var::dictionary();set(e.row,"id",Var::integer(id));set(e.row,"owner",Var::integer(owner));set(e.row,"position",array(V3{position[0],-position[2],position[1]}));
    const auto copy=[&](const char* key,const char* source,int64_t fallback){set(e.row,key,has(props,source)?get(props,source):Var::integer(fallback));};
    auto color=array_empty();if(has(props,"color"))color=get(props,"color");else for(int n=0;n<3;++n)method(color,"append",{Var::integer(0)});
    set(e.row,"color",color);copy("radius","radius",0);copy("multiplier","multiplier",1);copy("priority","lightpriority",4);copy("dynamic","isdynamic",1);copy("affect","affectdynamic",1);copy("fading","fadinglight",1);set(e.row,"in_view",Var::boolean(e.in_view));
    e.revision=revision;e.position=position;e.position_known=true;e.owner=owner;changed=true;
   }
   if(!has(e.row,"override")||e.priority!=priority){set(e.row,"override",Var::integer(priority));e.priority=priority;changed=true;}
   if(!same(e.position,position)){set(e.row,"position",array(V3{position[0],-position[2],position[1]}));e.position=position;changed=true;}
   if(e.owner!=owner){set(e.row,"owner",Var::integer(owner));e.owner=owner;changed=true;}
   if(get(e.row,"in_view").boolean()!=e.in_view){set(e.row,"in_view",Var::boolean(e.in_view));changed=true;}
   e.published=true;if(changed){method(rows,"append",{e.row});++rows_now;}else ++reused_now;
  }
  for(auto id:tombstones){const auto found=entries.find(id);if(found!=entries.end()&&found->second.pushed)--pushed_members;entries.erase(id);}
  if(!tombstones.empty())order.erase(std::remove_if(order.begin(),order.end(),[&](int64_t id){return entries.find(id)==entries.end();}),order.end());
  ++polls;input_rows+=rows_now;reused+=reused_now;view_tests+=tests_now;
  auto out=Var::dictionary();set(out,"rows",rows);set(out,"removed",removed);set(out,"retired",retired);set(out,"reused",Var::integer(reused_now));set(out,"view_tests",Var::integer(tests_now));set(out,"polls",Var::integer(polls));return out;
 }
 Var inspect(){auto out=Var::dictionary();set(out,"members",Var::integer(static_cast<int64_t>(entries.size())));set(out,"polls",Var::integer(polls));set(out,"view_tests",Var::integer(view_tests));set(out,"input_rows",Var::integer(input_rows));set(out,"reused",Var::integer(reused));set(out,"dead",Var::integer(dead));set(out,"closed",Var::boolean(closed));set(out,"pushes",Var::integer(pushes));set(out,"pushed_members",Var::integer(pushed_members));set(out,"stale_pushes",Var::integer(stale_pushes));return out;}
 Var operate(int64_t operation,const Var& input){if(operation==0){add(input);return inspect();}if(operation==1)return poll(input);if(operation==2){erase(light_history::id_value(get(input,"id")));return inspect();}if(operation==3)return inspect();if(operation==5){push(input);return Var::dictionary();}if(operation==4){for(auto&[id,e]:entries)e.published=false;pending_removed.clear();return inspect();}if(operation==8){entries.clear();order.clear();pending_removed.clear();deferred_membership.clear();pushed_members=0;closed=true;return inspect();}throw std::runtime_error("Unknown native light input registry operation");}
};
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnLightInputRegistry");auto object=construct_object(base.data);auto* owner=new Owner();set_instance(object,name.data,owner);if(notify){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{Var::integer(0)});}return object;}
void free(void*,GDExtensionClassInstancePtr instance){delete static_cast<Owner*>(instance);}
void call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,2,result,error))return;try{Var operation(args[0]),input(args[1]);auto out=static_cast<Owner*>(instance)->operate(operation.integer(),input);new_copy(result,out.data);}catch(const std::exception& e){auto out=Var::dictionary();set(out,"error",Var::text(e.what()));new_copy(result,out.data);}}
template<class Property>void register_owner(Property property){Name name("NwnLightInputRegistry"),base("RefCounted"),method_name("dispatch"),empty(""),operation("operation"),input("input");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free;register_class(library,name.data,base.data,&info);registered=true;auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo method_info{};method_info.name=method_name.data;method_info.call_func=call;method_info.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;method_info.has_return_value=true;method_info.return_value_info=&ret;method_info.argument_count=2;method_info.arguments_info=args;method_info.arguments_metadata=metadata;register_method(library,name.data,&method_info);}
void unregister_owner(){if(registered){Name name("NwnLightInputRegistry");unregister_class(library,name.data);registered=false;}}
}
