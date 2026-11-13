// Main-thread physical Part hierarchy, matching MdlNode::AnimateHierarchy
// (0x14004fe90). Generic ports are retained for original instruction oracles;
// the private production mode performs the existing no-motion Part arithmetic
// directly, avoiding a script/native boundary and temporary port map per Part.
// This owns no scene pointers, clocks, run/event scheduling or persistent state.
namespace model_hierarchy {
struct Walk {
 Var context,providers;float previous,time,weight,scale;bool generic=false,partial=false,prepared=false;int64_t controls=0,empty=0;
 std::vector<std::string> diagnostics;
 model_control::Allocations allocations;bool trace_allocations=false;
 Walk(const Var& c,const Var& p,float a,float b,float d,float s):context(c),providers(p),previous(a),time(b),weight(d),scale(s),generic(has(p,"control")),trace_allocations(has(p,"allocations")&&get(p,"allocations").boolean()){}
 void diagnose(const char* text){if(std::find(diagnostics.begin(),diagnostics.end(),text)==diagnostics.end())diagnostics.emplace_back(text);}
 void control(const Var& node,Var& part){
  if(generic){partial=true;++controls;invoke(providers,"control",{node,part,Var::number(previous),Var::number(time),Var::number(weight)});return;}
  const auto flags=word32(node,"flags98");
  if(flags&128){diagnose("native animated-vertex solver unavailable");return;}
  ++controls;
  if(i(node,"controllerCount80")==0)++empty;
  else{const auto result=model_control::apply(node,get(part,"view"),get(part,"fields"),time,weight,scale,trace_allocations?&allocations:nullptr);partial=true;set(part,"view",get(result,"view"));}
  if(flags&256)diagnose("native dangly solver unavailable");
 }
 void light(Var& part){
  if(generic){partial=true;auto value=invoke(providers,"light",{part});if(!value.nil()&&i(value,"field8c")==0)invoke(providers,"animateStaticLight",{get(part,"owner50"),value});return;}
  if(engine_string(get(get(part,"source"),"type"))=="light"&&i(part,"field8c")==0&&(!has(part,"light")||get(part,"light").nil()))diagnose("native static-light invalidation unavailable");
 }
 void visit(Var part,const Var& node){
  // Preserve callback-visible context updates, fixed range bounds, live child
  // lookups, rotated physical-ID matching and the original 1000-depth gate.
  partial=true;set(context,"depth",Var::integer(i(context,"depth")+1));
  if(i(part,"dirty60")==0){control(node,part);light(part);}
  if(i(context,"depth")<1000){
   const auto physical_count=i(part,"childCount40");
   for(int64_t index=0;index<physical_count;++index){
    const auto count=i(node,"childCount70");if(count<=0)continue;
    auto child=at(get(part,"children38"),index);
    for(int64_t offset=0;offset<count;++offset){auto candidate=at(get(node,"children68"),(index+offset)%count);if(get(child,"id30").number()==get(candidate,"id34").number()){visit(child,candidate);break;}}
   }
  }
  set(context,"depth",Var::integer(i(context,"depth")-1));
 }
 void visit_prepared(Var part,const model_plan::View& plan,uint32_t index){
  const auto node=plan.node(index);partial=true;set(context,"depth",Var::integer(i(context,"depth")+1));
  if(i(part,"dirty60")==0){
   if(node.flags&128)diagnose("native animated-vertex solver unavailable");
   else{++controls;if(!node.control_count)++empty;else{const auto view=model_plan::apply(plan,node,get(part,"view"),get(part,"fields"),time,weight,scale,trace_allocations?&allocations:nullptr);set(part,"view",view);}if(node.flags&256)diagnose("native dangly solver unavailable");}
   light(part);
  }
  if(i(context,"depth")<1000){const auto physical_count=i(part,"childCount40");for(int64_t n=0;n<physical_count;++n){
   if(!node.child_count)continue;auto child=at(get(part,"children38"),n);
   for(uint32_t offset=0;offset<node.child_count;++offset){const auto candidate_index=plan.child(node.child_first+static_cast<uint32_t>((static_cast<uint64_t>(n)+offset)%node.child_count));const auto candidate=plan.node(candidate_index);if(get(child,"id30").number()==static_cast<double>(candidate.id)){visit_prepared(child,plan,candidate_index);break;}}
  }}
  set(context,"depth",Var::integer(i(context,"depth")-1));
 }
 Var result(const char* error=nullptr)const{
  auto out=Var::dictionary();set(out,"controls",Var::integer(controls));set(out,"empty_controls",Var::integer(empty));set(out,"partial",Var::boolean(partial));set(out,"prepared",Var::boolean(prepared));
  auto rows=array_empty();for(const auto& text:diagnostics)method(rows,"append",{Var::text(text.c_str())});set(out,"diagnostics",rows);
  if(trace_allocations){set(out,"part_arrays",Var::integer(allocations.arrays));set(out,"part_bytes",Var::integer(allocations.bytes));set(out,"part_result_dictionaries",Var::integer(allocations.result_dictionaries));}
  if(error)set(out,"error",Var::text(error));return out;
 }
};
void call(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=8){error->error=count<8?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=8;new_nil(result);return;}
 // All values here are fresh aliases. No borrowed dictionary element survives
 // a callback, and a partially executed traversal must never be replayed.
 const Var previous(args[2]),time(args[3]),weight(args[4]),scale(args[5]);
 try{
  Walk walk{Var(args[6]),Var(args[7]),static_cast<float>(previous.number()),static_cast<float>(time.number()),static_cast<float>(weight.number()),static_cast<float>(scale.number())};
  try{
   if(has(walk.providers,"plan")){
    const auto bytes=get(walk.providers,"plan");if(walk.generic||i(walk.context,"depth")!=0||bytes.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)throw std::runtime_error("Prepared model plan requires private zero-depth hierarchy mode");
    const model_plan::View plan(bytes);walk.prepared=true;walk.visit_prepared(Var(args[0]),plan,0);
   }else walk.visit(Var(args[0]),Var(args[1]));const auto out=walk.result();new_copy(result,out.data);
  }
  catch(const std::exception& reason){const auto out=walk.result(reason.what());new_copy(result,out.data);}
 }catch(const std::exception& reason){auto out=Var::dictionary();set(out,"error",Var::text(reason.what()));set(out,"partial",Var::boolean(false));new_copy(result,out.data);}
}
template<class Property>void register_method_info(const Name& name,Property property){
 Name method_name("model_hierarchy"),empty(""),part("part"),node("node"),previous("previous"),time("time"),weight("weight"),scale("position_scale"),context("context"),providers("providers");auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);
 GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,part),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,node),property(GDEXTENSION_VARIANT_TYPE_FLOAT,previous),property(GDEXTENSION_VARIANT_TYPE_FLOAT,time),property(GDEXTENSION_VARIANT_TYPE_FLOAT,weight),property(GDEXTENSION_VARIANT_TYPE_FLOAT,scale),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,context),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,providers)};
 GDExtensionClassMethodArgumentMetadata metadata[8]{};GDExtensionClassMethodInfo method{};method.name=method_name.data;method.call_func=call;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL|GDEXTENSION_METHOD_FLAG_STATIC;method.has_return_value=true;method.return_value_info=&ret;method.argument_count=8;method.arguments_info=args;method.arguments_metadata=metadata;register_method(library,name.data,&method);
}
}
