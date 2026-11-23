// Opt-in main-thread fixed Part state and pose publication. Snapshots allocate
// only on explicit reads. Nodes are weak IDs; material resources are retained.
namespace model_pose_storage {
bool registered=false;
GDExtensionMethodBindPtr set_position=nullptr,set_quaternion=nullptr,set_scale=nullptr,set_albedo=nullptr,set_emission=nullptr,set_feature=nullptr,set_transparency=nullptr;
struct Material {Var retained;std::array<float,4> color{};bool hint=false,native_shader=false;};
struct Part {
 std::array<uint8_t,0x240> values{},fields{};std::vector<uint32_t> children;std::vector<Material> materials;Var rig_key;
 int64_t id=0,rig=0,dynamic=0;uint64_t object=0,light=0;int kind=0;bool manual=false;
 void field(int64_t offset,int64_t count)const{if(offset<0||offset>=0x240||count<1||count>4||offset+count*4>0x240||fields[static_cast<size_t>(offset)]!=count)throw std::runtime_error("Native pose field does not match its private storage");}
};
struct EmitterField {int64_t offset=0,width=0;bool byte=false;std::string name;};
enum TransformChannel : uint8_t {position_channel=1,rotation_channel=2,scale_channel=4,all_channels=7};
struct BoundControl {
 uint32_t part;
 model_plan::Node animation;
};
struct Publication {
 uint32_t part;
 uint8_t channels;
};
struct BoundClip {
 // Keep the immutable byte array alive while View borrows its tables.
 Var source;
 model_plan::View plan;
 std::vector<BoundControl> controls;
 std::vector<Publication> publications;
 explicit BoundClip(const Var& bytes):source(bytes),plan(source){}
};
uint64_t object_id(Var object){return static_cast<uint64_t>(method(object,"get_instance_id").integer());}
GDExtensionObjectPtr node(uint64_t id){auto object=instance_from_id(id);if(!object||!cast_object(object,node_tag))throw std::runtime_error("Native pose scene binding is no longer alive");return object;}
GDExtensionObjectPtr material(const Var& value){GDExtensionObjectPtr object=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&object,const_cast<uint8_t*>(value.data));if(!object)throw std::runtime_error("Native pose material is absent");return object;}
double srgb(double value){return value<0.04045?value*0.0773993808:std::pow(value*0.9478672986+0.0521327014,2.4);}
Var color_variant(const std::array<float,4>& value){auto copy=value;Var out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_COLOR](out.data,copy.data());return out;}
struct Owner {
 std::vector<Part> parts;std::vector<EmitterField> emitter_fields;uint32_t root=0;bool configured=false,closed=false,running=false,close_requested=false;
 std::unordered_map<const uint8_t*,std::unique_ptr<BoundClip>> bound_clips;
 bool sparse_channels=false,has_manual=false,full_publish_pending=false,has_publication_callbacks=false;
 int64_t binding_builds=0,transform_writes=0;
 int64_t revision=0,apply_calls=0,publish_calls=0,snapshot_arrays=0,read_arrays=0,writes=0,controls=0,empty=0;float scale=1,time_value=0,weight_value=1;
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
  sparse_channels=has(input,"sparse_channels")&&get(input,"sparse_channels").boolean();
  full_publish_pending=true;
  has_manual=std::any_of(parts.begin(),parts.end(),[](const Part& part){return part.manual;});
  has_publication_callbacks=std::any_of(parts.begin(),parts.end(),[](const Part& part){return part.kind==2||!part.materials.empty();});
 }
 void open()const{if(!configured||closed)throw std::runtime_error("Native pose storage is closed or unconfigured");}
 static bool manually_owned(const Var& manual,const Part& part){
  Var value;destroy(value.data);GDExtensionBool valid=0;
  get_keyed(manual.data,part.rig_key.data,value.data,&valid);
  return valid!=0;
 }
 void mark(const Var& manual,bool manual_empty){
  if(manual_empty&&!has_manual)return;
  has_manual=false;
  for(auto& part:parts){
   const bool was_manual=part.manual;
   part.manual=!manual_empty&&manually_owned(manual,part);
   full_publish_pending|=was_manual&&!part.manual;
   has_manual|=part.manual;
  }
 }
 __declspec(noinline) void control(Part& part,const model_plan::View& plan,const model_plan::Node& animation){
  if(animation.flags&128){diagnose("native animated-vertex solver unavailable");return;}++controls;
  if(!animation.control_count)++empty;else{auto next=part.values;model_plan::update(plan,animation,next.data(),time_value,weight_value,scale,[&](int64_t offset,int64_t width){part.field(offset,width);});part.values=next;}
  if(animation.flags&256)diagnose("native dangly solver unavailable");
 }
 void bind_node(BoundClip& clip,uint32_t index,uint32_t animation_index,uint32_t depth,std::vector<uint8_t>& channels)const{
  const auto& part=parts.at(index);
  const auto animation=clip.plan.node(animation_index);
  clip.controls.push_back({index,animation});
  if(sparse_channels&&!(animation.flags&128)){
   for(uint32_t n=0;n<animation.control_count;++n){
    const auto c=clip.plan.controller(animation.control_first+n);
    const auto width=c.flags&15;
    if(c.offset==16&&width==3)channels[index]|=position_channel;
    if(c.offset==28&&width==4)channels[index]|=rotation_channel;
    if(c.offset==44&&width==1)channels[index]|=scale_channel;
   }
  }
  // Preserve stock sibling lookup order, including duplicate controller IDs.
  if(depth>=1000||!animation.child_count)return;
  for(size_t n=0;n<part.children.size();++n){
   const auto child=part.children[n];
   for(uint32_t offset=0;offset<animation.child_count;++offset){
    const auto candidate=clip.plan.child(animation.child_first+static_cast<uint32_t>((n+offset)%animation.child_count));
    if(parts[child].id!=clip.plan.node(candidate).id)continue;
    bind_node(clip,child,candidate,depth+1,channels);
    break;
   }
  }
 }
 const BoundClip& binding(const Var& bytes){
  if(bytes.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)throw std::runtime_error("Native pose requires prepared numeric keys");
  const raster_conversion::Bytes storage(bytes.data);
  const auto* identity=storage.data();
  const auto found=bound_clips.find(identity);
  if(found!=bound_clips.end())return *found->second;
  auto clip=std::make_unique<BoundClip>(bytes);
  std::vector<uint8_t> channels(sparse_channels?parts.size():0);
  bind_node(*clip,root,0,1,channels);
  if(sparse_channels){
   for(size_t index=0;index<parts.size();++index){
    const auto& part=parts[index];
    auto mask=channels[index];
    // Godot reconstructs the local basis through the quaternion setter and
    // the stored scale. Keep their publication order when either is animated.
    if(mask&(rotation_channel|scale_channel))mask|=rotation_channel|scale_channel;
    if(mask||part.kind==2||!part.materials.empty())clip->publications.push_back({static_cast<uint32_t>(index),mask});
   }
  }
  ++binding_builds;
  return *bound_clips.emplace(identity,std::move(clip)).first->second;
 }
 void evaluate(const BoundClip& clip){
  ++apply_calls;
  for(const auto& entry:clip.controls){
   auto& part=parts[entry.part];
   if(part.manual)continue;
   control(part,clip.plan,entry.animation);
   if(part.kind==2&&!part.dynamic&&!part.light)diagnose("native static-light invalidation unavailable");
  }
 }
 void publish_transform(const Part& part,uint8_t channels){
  if(channels==0)return;
  const auto* p=part.values.data();
  if(channels&position_channel){
   const std::array<float,3> value{model_control::read(p,16),model_control::read(p,24),-model_control::read(p,20)};
   const GDExtensionConstTypePtr args[]={value.data()};
   ptrcall(set_position,node(part.object),args,nullptr);++transform_writes;
   if(close_requested)return;
  }
  if(channels&rotation_channel){
   const std::array<float,4> value{model_control::read(p,32),model_control::read(p,40),-model_control::read(p,36),model_control::read(p,28)};
   const GDExtensionConstTypePtr args[]={value.data()};
   ptrcall(set_quaternion,node(part.object),args,nullptr);++transform_writes;
   if(close_requested)return;
  }
  if(channels&scale_channel){
   const auto scale_value=model_control::read(p,44);
   const std::array<float,3> value{scale_value,scale_value,scale_value};
   const GDExtensionConstTypePtr args[]={value.data()};
   ptrcall(set_scale,node(part.object),args,nullptr);++transform_writes;
  }
 }
 void publish(const Var& input,const Var& manual,bool manual_empty,const BoundClip* clip){
  ++publish_calls;const auto scope=get(input,"scope");std::array<double,3> tint{};const bool scoped=!scope.nil();if(scoped)for(size_t n=0;n<3;++n)tint[n]=at(scope,static_cast<int64_t>(n)).number();
  const bool consult_manual=!manual_empty||has_publication_callbacks;
  const auto publish_part=[&](Part& part,uint8_t channels){
   if(consult_manual&&manually_owned(manual,part))return;
   publish_transform(part,channels);
   if(close_requested)return;
   const auto* p=part.values.data();
   if(part.kind==1){const float alpha=std::clamp(model_control::read(p,168),0.0f,1.0f);const double red=scoped?tint[0]:model_control::read(p,128),green=scoped?tint[1]:model_control::read(p,132),blue=scoped?tint[2]:model_control::read(p,136);const std::array<float,4> emission{static_cast<float>(srgb(red)),static_cast<float>(srgb(green)),static_cast<float>(srgb(blue)),1.0f};GDExtensionInt feature=0;GDExtensionBool enabled=(red!=0||green!=0||blue!=0)?1:0;
    for(auto& m:part.materials){const std::array<float,4> color{scoped?static_cast<float>(red):m.color[0],scoped?static_cast<float>(green):m.color[1],scoped?static_cast<float>(blue):m.color[2],alpha};GDExtensionInt transparency=(m.hint||alpha<1)?1:0;const GDExtensionConstTypePtr color_args[]={color.data()},enabled_args[]={&feature,&enabled},emission_args[]={emission.data()},transparency_args[]={&transparency};const auto object=material(m.retained);if(m.native_shader){method(m.retained,"publish_native_pose",{color_variant(color),color_variant(emission),Var::boolean(transparency==1)});if(close_requested)break;continue;}ptrcall(set_albedo,object,color_args,nullptr);if(close_requested)break;ptrcall(set_feature,object,enabled_args,nullptr);if(close_requested)break;ptrcall(set_emission,object,emission_args,nullptr);if(close_requested)break;ptrcall(set_transparency,object,transparency_args,nullptr);if(close_requested)break;}
   }else if(part.kind==2){auto target=part.light?instance_from_id(part.light):nullptr;if(!target){diagnose("native animated-light renderer binding unavailable");return;}Var light;destroy(light.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](light.data,&target);method(light,"publish_native_light",{color_variant({model_control::read(p,104),model_control::read(p,108),model_control::read(p,112),1.0f}),Var::number(model_control::read(p,116)),Var::number(model_control::read(p,124)),Var::number(model_control::read(p,128)),Var::number(model_control::read(p,168))});}
  };
  if(clip){
   for(const auto& row:clip->publications){if(close_requested)break;publish_part(parts[row.part],row.channels);}
  }else{
   for(auto& part:parts){if(close_requested)break;publish_part(part,all_channels);}
  }
 }
 void finish_close(){closed=true;bound_clips.clear();parts.clear();emitter_fields.clear();}
 void close(){if(running)close_requested=true;else finish_close();}
 Var result(bool full=true)const{auto out=Var::dictionary();set(out,"revision",Var::integer(revision));set(out,"closed",Var::boolean(closed||close_requested));set(out,"scale",Var::number(scale));if(full){set(out,"apply_calls",Var::integer(apply_calls));set(out,"publish_calls",Var::integer(publish_calls));set(out,"snapshot_arrays",Var::integer(snapshot_arrays));set(out,"read_arrays",Var::integer(read_arrays));set(out,"writes",Var::integer(writes));set(out,"parts",Var::integer(static_cast<int64_t>(parts.size())));set(out,"part_state_bytes",Var::integer(static_cast<int64_t>(parts.size()*0x240)));set(out,"binding_builds",Var::integer(binding_builds));set(out,"transform_writes",Var::integer(transform_writes));set(out,"sparse_channels",Var::boolean(sparse_channels));}if(!diagnostics.empty()){auto rows=array_empty();for(const auto& text:diagnostics)method(rows,"append",{Var::text(text.c_str())});set(out,"diagnostics",rows);}return out;}
 Var operate(int64_t operation,const Var& input){
  if(operation==8){close();return result();}if(operation==0){configure(input);return result();}if(operation==7)return result();open();
  if(operation==5){auto out=Var::dictionary();set(out,"revision",Var::integer(revision));if(has(input,"since")&&i(input,"since")==revision)return out;auto views=array_empty(),dirty=array_empty();for(const auto& part:parts){WritableBytes bytes(part.values.size());std::memcpy(bytes.data,part.values.data(),part.values.size());method(views,"append",{bytes.publish()});method(dirty,"append",{Var::integer(part.manual?1:0)});++snapshot_arrays;}set(out,"views",views);set(out,"dirty",dirty);return out;}
  if(operation==3||operation==4||operation==6){const auto index=i(input,"index");if(index<0||static_cast<size_t>(index)>=parts.size())throw std::runtime_error("Native pose Part index is invalid");auto& part=parts[static_cast<size_t>(index)];if(operation==6){auto out=Var::dictionary();if(part.kind!=3)return out;for(const auto& f:emitter_fields){if(f.byte)set(out,f.name.c_str(),Var::integer(part.values[static_cast<size_t>(f.offset)]));else if(f.width==1)set(out,f.name.c_str(),Var::number(model_control::read(part.values.data(),f.offset)));else set(out,f.name.c_str(),array(V3{model_control::read(part.values.data(),f.offset),model_control::read(part.values.data(),f.offset+4),model_control::read(part.values.data(),f.offset+8)}));}return out;}
   const auto offset=i(input,"offset");if(operation==3){auto values=get(input,"values");const auto count=size(values);part.field(offset,count);for(int64_t n=0;n<count;++n)model_control::write(part.values.data(),offset+n*4,static_cast<float>(at(values,n).number()));full_publish_pending=true;++writes;++revision;return result();}
   const auto count=i(input,"count");part.field(offset,count);auto values=array_empty();for(int64_t n=0;n<count;++n)method(values,"append",{Var::number(model_control::read(part.values.data(),offset+n*4))});++read_arrays;auto out=Var::dictionary();set(out,"values",values);return out;
  }
  if(operation!=1&&operation!=2)throw std::runtime_error("Unknown native pose storage operation");if(running)throw std::runtime_error("Native pose storage is already publishing");
  struct Scope {Owner& owner;explicit Scope(Owner& o):owner(o){owner.running=true;}~Scope(){owner.running=false;if(owner.close_requested)owner.finish_close();}}guard(*this);
  const bool profile=get(input,"profile").boolean();using Clock=std::chrono::steady_clock;auto began=profile?Clock::now():Clock::time_point{};double manual_ms=0,evaluate_ms=0,publish_ms=0;
  diagnostics.clear();
  auto manual=get(input,"manual");
  const bool manual_empty=size(manual)==0;
  if(operation==1){
   ++revision;
   time_value=static_cast<float>(get(input,"time").number());
   weight_value=static_cast<float>(get(input,"weight").number());
   scale=static_cast<float>(get(input,"scale").number());
   mark(manual,manual_empty);
  }
  const auto before=controls,before_empty=empty;
  if(profile){auto now=Clock::now();manual_ms=std::chrono::duration<double,std::milli>(now-began).count();began=now;}
  const BoundClip* clip=nullptr;
  if(operation==1){clip=&binding(get(input,"plan"));evaluate(*clip);}
  if(profile){auto now=Clock::now();evaluate_ms=std::chrono::duration<double,std::milli>(now-began).count();began=now;}
  const bool full_publication=!sparse_channels||full_publish_pending;
  full_publish_pending=false;
  publish(input,manual,manual_empty,full_publication?nullptr:clip);
  if(profile)publish_ms=std::chrono::duration<double,std::milli>(Clock::now()-began).count();auto out=result(false);set(out,"controls",Var::integer(controls-before));set(out,"empty_controls",Var::integer(empty-before_empty));if(profile){set(out,"manual_ms",Var::number(manual_ms));set(out,"evaluate_ms",Var::number(evaluate_ms));set(out,"publish_ms",Var::number(publish_ms));}return out;
 }
};
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnModelPoseStorage");auto object=construct_object(base.data);auto* owner=new Owner();set_instance(object,name.data,owner);if(notify){Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](v.data,&object);method(v,"notification",{Var::integer(0)});}return object;}
void free(void*,GDExtensionClassInstancePtr instance){delete static_cast<Owner*>(instance);}
void dispatch(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){if(!particle_upload::count_ok(count,2,result,error))return;try{const Var operation(args[0]),input(args[1]);const auto out=static_cast<Owner*>(instance)->operate(operation.integer(),input);new_copy(result,out.data);}catch(const std::exception& reason){auto out=static_cast<Owner*>(instance)->result(false);set(out,"error",Var::text(reason.what()));set(out,"partial",Var::boolean(true));new_copy(result,out.data);}}
template<class Property>void register_owner(Property property){
 Name node_name("Node3D"),material_name("BaseMaterial3D"),pos("set_position"),quat("set_quaternion"),scale_name("set_scale"),albedo("set_albedo"),emission("set_emission"),feature("set_feature"),transparency("set_transparency");set_position=class_method(node_name.data,pos.data,3460891852);set_quaternion=class_method(node_name.data,quat.data,1727505552);set_scale=class_method(node_name.data,scale_name.data,3460891852);set_albedo=class_method(material_name.data,albedo.data,2920490490);set_emission=class_method(material_name.data,emission.data,2920490490);set_feature=class_method(material_name.data,feature.data,2819288693);set_transparency=class_method(material_name.data,transparency.data,3435651667);if(!set_position||!set_quaternion||!set_scale||!set_albedo||!set_emission||!set_feature||!set_transparency)return;
 Name name("NwnModelPoseStorage"),base("RefCounted"),method_name("dispatch"),empty(""),operation("operation"),input("input");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free;register_class(library,name.data,base.data,&info);registered=true;
 auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo method{};method.name=method_name.data;method.call_func=dispatch;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;method.has_return_value=true;method.return_value_info=&ret;method.argument_count=2;method.arguments_info=args;method.arguments_metadata=metadata;register_method(library,name.data,&method);
}
void unregister_owner(){if(registered){Name name("NwnModelPoseStorage");unregister_class(library,name.data);registered=false;}}
}
