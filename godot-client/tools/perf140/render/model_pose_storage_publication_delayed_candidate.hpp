// Private delayed-observation candidate: changing inputs retain original
// setters without cache getters. Repeated inputs need two output witnesses.
namespace model_pose_storage {
bool registered=false;
GDExtensionMethodBindPtr set_position=nullptr,set_quaternion=nullptr,set_scale=nullptr,set_albedo=nullptr,set_emission=nullptr,set_feature=nullptr,set_transparency=nullptr;
GDExtensionMethodBindPtr get_transform=nullptr,get_scale=nullptr,get_rotation_order=nullptr;
struct Material {Var retained;std::array<float,4> color{};bool hint=false,native_shader=false;};
struct Part {
 std::array<uint8_t,0x240> values{},fields{};std::vector<uint32_t> children;std::vector<Material> materials;Var rig_key;
 int64_t id=0,rig=0,dynamic=0;uint64_t object=0,light=0;int kind=0;bool manual=false;
 std::array<uint32_t,8> published_source{};std::array<float,12> published_transform{};std::array<float,3> published_scale{};GDExtensionInt published_order=0;bool publication_known=false,publication_stable=false,publication_source_seen=false;
 void field(int64_t offset,int64_t count)const{if(offset<0||offset>=0x240||count<1||count>4||offset+count*4>0x240||fields[static_cast<size_t>(offset)]!=count)throw std::runtime_error("Native pose field does not match its private storage");}
};
struct EmitterField {int64_t offset=0,width=0;bool byte=false;std::string name;};
uint64_t object_id(Var object){return static_cast<uint64_t>(method(object,"get_instance_id").integer());}
GDExtensionObjectPtr node(uint64_t id){auto object=instance_from_id(id);if(!object||!cast_object(object,node_tag))throw std::runtime_error("Native pose scene binding is no longer alive");return object;}
GDExtensionObjectPtr material(const Var& value){GDExtensionObjectPtr object=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&object,const_cast<uint8_t*>(value.data));if(!object)throw std::runtime_error("Native pose material is absent");return object;}
double srgb(double value){return value<0.04045?value*0.0773993808:std::pow(value*0.9478672986+0.0521327014,2.4);}
Var color_variant(const std::array<float,4>& value){auto copy=value;Var out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_COLOR](out.data,copy.data());return out;}
struct Owner {
 std::vector<Part> parts;std::vector<EmitterField> emitter_fields;uint32_t root=0;bool configured=false,closed=false,running=false,close_requested=false;
 int64_t revision=0,apply_calls=0,publish_calls=0,snapshot_arrays=0,read_arrays=0,writes=0,controls=0,empty=0;float scale=1,time_value=0,weight_value=1;
 int64_t publication_live_checks=0,publication_getters=0,publication_skips=0,publication_setter_writes=0,publication_captures=0,publication_ineligible=0,publication_observation_deferrals=0;
 std::vector<std::string> diagnostics;
 void diagnose(const char* value){if(std::find(diagnostics.begin(),diagnostics.end(),value)==diagnostics.end())diagnostics.emplace_back(value);}
 void configure(const Var& input){
  if(configured||closed)throw std::runtime_error("Native pose storage configures once");auto records=get(input,"parts"),binding=get(input,"binding");const auto count=size(records),root_index=i(input,"root");
  if(count<=0||count>1000000||size(binding)!=count||root_index<0||root_index>=count)throw std::runtime_error("Native pose topology is invalid");std::vector<Part> next;next.reserve(static_cast<size_t>(count));
  for(int64_t index=0;index<count;++index){auto record=at(records,index);Part part;part.id=static_cast<int64_t>(get(record,"id30").number());part.rig_key=at(binding,index);part.rig=part.rig_key.integer();part.dynamic=i(record,"field8c");part.manual=i(record,"dirty60")!=0;part.object=object_id(get(record,"object"));node(part.object);
   auto source=get(record,"source");const auto kind=engine_string(get(source,"type"));part.kind=kind=="trimesh"?1:kind=="light"?2:kind=="emitter"?3:0;
   auto light=has(record,"light")?get(record,"light"):Var();if(part.kind==2&&!light.nil()&&method(light,"has_method",{Var::text("publish_native_light")}).boolean())part.light=object_id(light);
   const auto view=get(record,"view");if(view.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)throw std::runtime_error("Native pose initial Part is not packed storage");raster_conversion::Bytes bytes(view.data);if(bytes.size()!=part.values.size())throw std::runtime_error("Native pose initial Part size is invalid");std::memcpy(part.values.data(),bytes.data(),part.values.size());
   auto fields=get(record,"fields"),field_keys=method(fields,"keys");for(int64_t n=0;n<size(field_keys);++n){const auto key_value=at(field_keys,n);const auto offset=key_value.integer();Var width;destroy(width.data);GDExtensionBool valid=0;get_keyed(fields.data,key_value.data,width.data,&valid);const auto components=width.integer();if(!valid||offset<0||offset>=0x240||components<1||components>4||offset+components*4>0x240)throw std::runtime_error("Native pose field layout is invalid");part.fields[static_cast<size_t>(offset)]=static_cast<uint8_t>(components);}
   auto children=get(source,"children");for(int64_t n=0;n<size(children);++n){const auto child=at(children,n).integer();if(child<0||child>=count)throw std::runtime_error("Native pose physical child is invalid");part.children.push_back(static_cast<uint32_t>(child));}
   auto materials=get(record,"materials");for(int64_t n=0;n<size(materials);++n){const auto row=at(materials,n);Material m;m.retained=get(row,"material");material(m.retained);const auto color=get(row,"color");to[GDEXTENSION_VARIANT_TYPE_COLOR](m.color.data(),const_cast<uint8_t*>(color.data));m.hint=get(row,"hint").boolean();m.native_shader=method(m.retained,"has_method",{Var::text("publish_native_pose")}).boolean();part.materials.push_back(std::move(m));}next.push_back(std::move(part));
  }
  auto emitters=get(input,"emitter_fields"),emitter_keys=method(emitters,"keys");for(int64_t n=0;n<size(emitter_keys);++n){const auto key_value=at(emitter_keys,n);Var name;destroy(name.data);GDExtensionBool valid=0;get_keyed(emitters.data,key_value.data,name.data,&valid);if(!valid)throw std::runtime_error("Native pose emitter mapping is invalid");EmitterField f;f.name=engine_string(name);f.offset=key_value.type()==GDEXTENSION_VARIANT_TYPE_INT?key_value.integer():std::stoll(engine_string(key_value));f.byte=f.name.rfind("percent",0)==0||f.name=="detonate";f.width=f.name.rfind("color",0)==0?3:1;if(f.offset<0||f.offset+f.width*4>0x240)throw std::runtime_error("Native pose emitter offset is invalid");emitter_fields.push_back(std::move(f));}
  parts=std::move(next);root=static_cast<uint32_t>(root_index);configured=true;revision=1;
 }
 void open()const{if(!configured||closed)throw std::runtime_error("Native pose storage is closed or unconfigured");}
 void mark(const Var& manual,bool update_state){if(!update_state)return;for(auto& part:parts){Var value;destroy(value.data);GDExtensionBool valid=0;get_keyed(manual.data,part.rig_key.data,value.data,&valid);part.manual=valid!=0;}}
 __declspec(noinline) void control(Part& part,const model_plan::View& plan,const model_plan::Node& animation){
  if(animation.flags&128){diagnose("native animated-vertex solver unavailable");return;}++controls;
  if(!animation.control_count)++empty;else{auto next=part.values;model_plan::update(plan,animation,next.data(),time_value,weight_value,scale,[&](int64_t offset,int64_t width){part.field(offset,width);});part.values=next;}
  if(animation.flags&256)diagnose("native dangly solver unavailable");
 }
 void visit(uint32_t index,const model_plan::View& plan,uint32_t animation_index,uint32_t depth){
  auto& part=parts.at(index);const auto animation=plan.node(animation_index);if(!part.manual){control(part,plan,animation);if(part.kind==2&&!part.dynamic&&!part.light)diagnose("native static-light invalidation unavailable");}
  if(depth<1000)for(size_t n=0;n<part.children.size();++n){if(!animation.child_count)continue;const auto child=part.children[n];for(uint32_t offset=0;offset<animation.child_count;++offset){const auto candidate=plan.child(animation.child_first+static_cast<uint32_t>((n+offset)%animation.child_count));if(parts[child].id==plan.node(candidate).id){visit(child,plan,candidate,depth+1);break;}}}
 }
 static void invalidate_publication(Part& part){part.publication_known=false;part.publication_stable=false;part.publication_source_seen=false;}
 static bool same_transform(const std::array<float,12>& a,const std::array<float,12>& b){return std::memcmp(a.data(),b.data(),sizeof(float)*a.size())==0;}
 static bool source_words(const uint8_t* source,std::array<uint32_t,8>& words){
  for(size_t index=0;index<words.size();++index){const auto offset=16+index*4;const float value=model_control::read(source,offset);if(!std::isfinite(value))return false;std::memcpy(&words[index],source+offset,4);}
  const double scalar=model_control::read(source,44);double quaternion_norm=0;for(size_t index=0;index<4;++index){const double value=model_control::read(source,28+index*4);quaternion_norm+=value*value;}
  return scalar>0&&quaternion_norm>1e-20&&std::isfinite(quaternion_norm);
 }
 static bool supported_transform(const std::array<float,12>& value){
  for(float component:value)if(!std::isfinite(component))return false;
  const double determinant=static_cast<double>(value[0])*(static_cast<double>(value[4])*value[8]-static_cast<double>(value[5])*value[7])-static_cast<double>(value[1])*(static_cast<double>(value[3])*value[8]-static_cast<double>(value[5])*value[6])+static_cast<double>(value[2])*(static_cast<double>(value[3])*value[7]-static_cast<double>(value[4])*value[6]);
  const float native_determinant=value[0]*(value[4]*value[8]-value[5]*value[7])-value[1]*(value[3]*value[8]-value[5]*value[6])+value[2]*(value[3]*value[7]-value[4]*value[6]);
  return std::isfinite(determinant)&&std::abs(determinant)>1e-20&&std::isfinite(native_determinant)&&std::abs(native_determinant)>1e-20f;
 }
 bool observe_publication(Part& part,std::array<float,12>& transform,std::array<float,3>& current_scale,GDExtensionInt& order){
  // A node retired by the last original setter's notification must not acquire
  // a new cache-only lifetime error. The next real setter keeps its old check.
  auto object=instance_from_id(part.object);if(!object||!cast_object(object,node_tag))return false;
  ptrcall(get_transform,object,nullptr,transform.data());++publication_getters;
  if(!supported_transform(transform))return false;
  ptrcall(get_scale,object,nullptr,current_scale.data());++publication_getters;
  ptrcall(get_rotation_order,object,nullptr,&order);++publication_getters;
  return std::all_of(current_scale.begin(),current_scale.end(),[](float component){return std::isfinite(component);});
 }
 bool reuse_publication(Part& part,const std::array<uint32_t,8>& source,const std::array<float,3>& requested_scale){
  if(!part.publication_known||!part.publication_stable||part.published_source!=source)return false;
  ++publication_live_checks;std::array<float,12> transform{};std::array<float,3> current_scale{};GDExtensionInt order=0;
  auto object=instance_from_id(part.object);if(!object||!cast_object(object,node_tag))return false;
  ptrcall(get_transform,object,nullptr,transform.data());++publication_getters;
  // A changed external matrix takes the original setter path before any
  // cache-only decomposition of possibly unsupported external geometry.
  if(!same_transform(transform,part.published_transform))return false;
  ptrcall(get_scale,object,nullptr,current_scale.data());++publication_getters;
  ptrcall(get_rotation_order,object,nullptr,&order);++publication_getters;
  // Same-matrix set_transform/set_basis can change hidden scale caches.
  if(!same_transform(transform,part.published_transform)||current_scale!=part.published_scale||current_scale!=requested_scale||order!=part.published_order)return false;
  ++publication_skips;return true;
 }
 void retain_publication(Part& part,const std::array<uint32_t,8>& source,const std::array<float,3>& requested_scale){
  std::array<float,12> transform{};std::array<float,3> current_scale{};GDExtensionInt order=0;
  if(!observe_publication(part,transform,current_scale,order)||current_scale!=requested_scale){invalidate_publication(part);return;}
  const bool stable=part.publication_known&&part.published_source==source&&same_transform(part.published_transform,transform)&&part.published_scale==current_scale&&part.published_order==order;
  part.published_source=source;part.published_transform=transform;part.published_scale=current_scale;part.published_order=order;part.publication_known=true;part.publication_stable=stable;++publication_captures;
 }
 void publish(const Var& input){
  ++publish_calls;const auto scope=get(input,"scope");std::array<double,3> tint{};const bool scoped=!scope.nil();if(scoped)for(size_t n=0;n<3;++n)tint[n]=at(scope,static_cast<int64_t>(n)).number();
  auto manual=get(input,"manual");for(auto& part:parts){if(close_requested)break;{Var value;destroy(value.data);GDExtensionBool valid=0;get_keyed(manual.data,part.rig_key.data,value.data,&valid);if(valid){invalidate_publication(part);continue;}}const auto* p=part.values.data();const std::array<float,3> position{model_control::read(p,16),model_control::read(p,24),-model_control::read(p,20)},size_value{model_control::read(p,44),model_control::read(p,44),model_control::read(p,44)};const std::array<float,4> q{model_control::read(p,32),model_control::read(p,40),-model_control::read(p,36),model_control::read(p,28)};
   std::array<uint32_t,8> source{};const bool eligible=source_words(p,source);const bool repeated_source=eligible&&part.publication_source_seen&&part.published_source==source;if(!eligible){invalidate_publication(part);++publication_ineligible;}
   if(!eligible||!reuse_publication(part,source,size_value)){
    const GDExtensionConstTypePtr pos_args[]={position.data()},q_args[]={q.data()},scale_args[]={size_value.data()};ptrcall(set_position,node(part.object),pos_args,nullptr);++publication_setter_writes;if(close_requested)break;ptrcall(set_quaternion,node(part.object),q_args,nullptr);++publication_setter_writes;if(close_requested)break;ptrcall(set_scale,node(part.object),scale_args,nullptr);++publication_setter_writes;if(close_requested)break;
    if(eligible){if(repeated_source)retain_publication(part,source,size_value);else{part.published_source=source;part.publication_source_seen=true;part.publication_known=false;part.publication_stable=false;++publication_observation_deferrals;}}
   }
   if(part.kind==1){const float alpha=std::clamp(model_control::read(p,168),0.0f,1.0f);const double red=scoped?tint[0]:model_control::read(p,128),green=scoped?tint[1]:model_control::read(p,132),blue=scoped?tint[2]:model_control::read(p,136);const std::array<float,4> emission{static_cast<float>(srgb(red)),static_cast<float>(srgb(green)),static_cast<float>(srgb(blue)),1.0f};GDExtensionInt feature=0;GDExtensionBool enabled=(red!=0||green!=0||blue!=0)?1:0;
    for(auto& m:part.materials){const std::array<float,4> color{scoped?static_cast<float>(red):m.color[0],scoped?static_cast<float>(green):m.color[1],scoped?static_cast<float>(blue):m.color[2],alpha};GDExtensionInt transparency=(m.hint||alpha<1)?1:0;const GDExtensionConstTypePtr color_args[]={color.data()},enabled_args[]={&feature,&enabled},emission_args[]={emission.data()},transparency_args[]={&transparency};const auto object=material(m.retained);if(m.native_shader){method(m.retained,"publish_native_pose",{color_variant(color),color_variant(emission),Var::boolean(transparency==1)});if(close_requested)break;continue;}ptrcall(set_albedo,object,color_args,nullptr);if(close_requested)break;ptrcall(set_feature,object,enabled_args,nullptr);if(close_requested)break;ptrcall(set_emission,object,emission_args,nullptr);if(close_requested)break;ptrcall(set_transparency,object,transparency_args,nullptr);if(close_requested)break;}
   }else if(part.kind==2){auto target=part.light?instance_from_id(part.light):nullptr;if(!target){diagnose("native animated-light renderer binding unavailable");continue;}Var light;destroy(light.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](light.data,&target);method(light,"publish_native_light",{color_variant({model_control::read(p,104),model_control::read(p,108),model_control::read(p,112),1.0f}),Var::number(model_control::read(p,116)),Var::number(model_control::read(p,124)),Var::number(model_control::read(p,128)),Var::number(model_control::read(p,168))});}
  }
 }
 void finish_close(){closed=true;parts.clear();emitter_fields.clear();}
 void close(){if(running)close_requested=true;else finish_close();}
 Var result(bool full=true)const{auto out=Var::dictionary();set(out,"revision",Var::integer(revision));set(out,"closed",Var::boolean(closed||close_requested));set(out,"scale",Var::number(scale));if(full){set(out,"apply_calls",Var::integer(apply_calls));set(out,"publish_calls",Var::integer(publish_calls));set(out,"snapshot_arrays",Var::integer(snapshot_arrays));set(out,"read_arrays",Var::integer(read_arrays));set(out,"writes",Var::integer(writes));set(out,"parts",Var::integer(static_cast<int64_t>(parts.size())));set(out,"part_state_bytes",Var::integer(static_cast<int64_t>(parts.size()*0x240)));}if(!diagnostics.empty()){auto rows=array_empty();for(const auto& text:diagnostics)method(rows,"append",{Var::text(text.c_str())});set(out,"diagnostics",rows);}return out;}
 Var operate(int64_t operation,const Var& input){
  if(operation==8){close();return result();}if(operation==0){configure(input);return result();}if(operation==7){auto out=result();set(out,"publication_live_checks",Var::integer(publication_live_checks));set(out,"publication_getters",Var::integer(publication_getters));set(out,"publication_skips",Var::integer(publication_skips));set(out,"publication_setter_writes",Var::integer(publication_setter_writes));set(out,"publication_captures",Var::integer(publication_captures));set(out,"publication_ineligible",Var::integer(publication_ineligible));set(out,"publication_observation_deferrals",Var::integer(publication_observation_deferrals));return out;}open();
  if(operation==5){auto out=Var::dictionary();set(out,"revision",Var::integer(revision));if(has(input,"since")&&i(input,"since")==revision)return out;auto views=array_empty(),dirty=array_empty();for(const auto& part:parts){WritableBytes bytes(part.values.size());std::memcpy(bytes.data,part.values.data(),part.values.size());method(views,"append",{bytes.publish()});method(dirty,"append",{Var::integer(part.manual?1:0)});++snapshot_arrays;}set(out,"views",views);set(out,"dirty",dirty);return out;}
  if(operation==3||operation==4||operation==6){const auto index=i(input,"index");if(index<0||static_cast<size_t>(index)>=parts.size())throw std::runtime_error("Native pose Part index is invalid");auto& part=parts[static_cast<size_t>(index)];if(operation==6){auto out=Var::dictionary();if(part.kind!=3)return out;for(const auto& f:emitter_fields){if(f.byte)set(out,f.name.c_str(),Var::integer(part.values[static_cast<size_t>(f.offset)]));else if(f.width==1)set(out,f.name.c_str(),Var::number(model_control::read(part.values.data(),f.offset)));else set(out,f.name.c_str(),array(V3{model_control::read(part.values.data(),f.offset),model_control::read(part.values.data(),f.offset+4),model_control::read(part.values.data(),f.offset+8)}));}return out;}
   const auto offset=i(input,"offset");if(operation==3){auto values=get(input,"values");const auto count=size(values);part.field(offset,count);for(int64_t n=0;n<count;++n)model_control::write(part.values.data(),offset+n*4,static_cast<float>(at(values,n).number()));++writes;++revision;return result();}
   const auto count=i(input,"count");part.field(offset,count);auto values=array_empty();for(int64_t n=0;n<count;++n)method(values,"append",{Var::number(model_control::read(part.values.data(),offset+n*4))});++read_arrays;auto out=Var::dictionary();set(out,"values",values);return out;
  }
  if(operation!=1&&operation!=2)throw std::runtime_error("Unknown native pose storage operation");if(running)throw std::runtime_error("Native pose storage is already publishing");
  struct Scope {Owner& owner;explicit Scope(Owner& o):owner(o){owner.running=true;}~Scope(){owner.running=false;if(owner.close_requested)owner.finish_close();}}guard(*this);
  const bool profile=get(input,"profile").boolean();using Clock=std::chrono::steady_clock;auto began=profile?Clock::now():Clock::time_point{};double manual_ms=0,evaluate_ms=0,publish_ms=0;
  diagnostics.clear();if(operation==1){++revision;time_value=static_cast<float>(get(input,"time").number());weight_value=static_cast<float>(get(input,"weight").number());scale=static_cast<float>(get(input,"scale").number());}mark(get(input,"manual"),operation==1);const auto before=controls,before_empty=empty;
  if(profile){auto now=Clock::now();manual_ms=std::chrono::duration<double,std::milli>(now-began).count();began=now;}
  if(operation==1){const auto bytes=get(input,"plan");if(bytes.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)throw std::runtime_error("Native pose requires prepared numeric keys");const model_plan::View plan(bytes);time_value=static_cast<float>(get(input,"time").number());weight_value=static_cast<float>(get(input,"weight").number());scale=static_cast<float>(get(input,"scale").number());++apply_calls;visit(root,plan,0,1);}
  if(profile){auto now=Clock::now();evaluate_ms=std::chrono::duration<double,std::milli>(now-began).count();began=now;}
  publish(input);if(profile)publish_ms=std::chrono::duration<double,std::milli>(Clock::now()-began).count();auto out=result(false);set(out,"controls",Var::integer(controls-before));set(out,"empty_controls",Var::integer(empty-before_empty));if(profile){set(out,"manual_ms",Var::number(manual_ms));set(out,"evaluate_ms",Var::number(evaluate_ms));set(out,"publish_ms",Var::number(publish_ms));}return out;
 }
};
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnModelPoseStorage");auto object=construct_object(base.data);auto* owner=new Owner();set_instance(object,name.data,owner);if(notify){Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](v.data,&object);method(v,"notification",{Var::integer(0)});}return object;}
void free(void*,GDExtensionClassInstancePtr instance){delete static_cast<Owner*>(instance);}
void dispatch(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,2,result,error))return;try{const Var operation(args[0]),input(args[1]);const auto out=static_cast<Owner*>(instance)->operate(operation.integer(),input);new_copy(result,out.data);}catch(const std::exception& reason){auto out=static_cast<Owner*>(instance)->result(false);set(out,"error",Var::text(reason.what()));set(out,"partial",Var::boolean(true));new_copy(result,out.data);}}
template<class Property>void register_owner(Property property){
 Name node_name("Node3D"),material_name("BaseMaterial3D"),pos("set_position"),quat("set_quaternion"),scale_name("set_scale"),albedo("set_albedo"),emission("set_emission"),feature("set_feature"),transparency("set_transparency");set_position=class_method(node_name.data,pos.data,3460891852);set_quaternion=class_method(node_name.data,quat.data,1727505552);set_scale=class_method(node_name.data,scale_name.data,3460891852);set_albedo=class_method(material_name.data,albedo.data,2920490490);set_emission=class_method(material_name.data,emission.data,2920490490);set_feature=class_method(material_name.data,feature.data,2819288693);set_transparency=class_method(material_name.data,transparency.data,3435651667);if(!set_position||!set_quaternion||!set_scale||!set_albedo||!set_emission||!set_feature||!set_transparency)return;
 Name transform_getter("get_transform"),scale_getter("get_scale"),order_getter("get_rotation_order");get_transform=class_method(node_name.data,transform_getter.data,3229777777);get_scale=class_method(node_name.data,scale_getter.data,3360562783);get_rotation_order=class_method(node_name.data,order_getter.data,916939469);if(!get_transform||!get_scale||!get_rotation_order)return;
 Name name("NwnModelPoseStorage"),base("RefCounted"),method_name("dispatch"),empty(""),operation("operation"),input("input");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free;register_class(library,name.data,base.data,&info);registered=true;
 auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo method{};method.name=method_name.data;method.call_func=dispatch;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;method.has_return_value=true;method.return_value_info=&ret;method.argument_count=2;method.arguments_info=args;method.arguments_metadata=metadata;register_method(library,name.data,&method);
}
void unregister_owner(){if(registered){Name name("NwnModelPoseStorage");unregister_class(library,name.data);registered=false;}}
}
