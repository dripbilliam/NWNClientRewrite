// Main-thread original physical selection/removal walk. State stays in the
// caller's dictionaries and is re-read after inline callbacks. No eager action
// plan, retained scene pointer, cached lifetime decision or worker mutation.
namespace visual_selection {
GDExtensionPtrUtilityFunction identity=nullptr;
GDExtensionInterfaceArrayOperatorIndexConst array_element=nullptr;
GDExtensionPtrBuiltInMethod array_size=nullptr;
GDExtensionPtrBuiltInMethod array_append=nullptr;
GDExtensionInterfaceVariantGetNamed get_named=nullptr;
GDExtensionInterfaceVariantGetObjectInstanceId object_id=nullptr;
GDExtensionInterfaceDictionaryOperatorIndexConst dictionary_element=nullptr;
GDExtensionPtrBuiltInMethod dictionary_has=nullptr;
struct SnapshotArray {
 alignas(8) uint8_t raw[8];
 SnapshotArray(){ptr_constructor(GDEXTENSION_VARIANT_TYPE_ARRAY,0)(raw,nullptr);}
 ~SnapshotArray(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_ARRAY)(raw);}
 SnapshotArray(const SnapshotArray&)=delete;
 void append(const Var& value){const GDExtensionConstTypePtr args[]={value.data};array_append(raw,args,nullptr,1);}
 Var publish(){Var out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_ARRAY](out.data,raw);return out;}
};
struct List {
 Var value;alignas(8) uint8_t raw[8];
 explicit List(Var source):value(source){if(value.type()!=GDEXTENSION_VARIANT_TYPE_ARRAY)throw std::runtime_error("Visual selection list must be Array");to[GDEXTENSION_VARIANT_TYPE_ARRAY](raw,value.data);}
 ~List(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_ARRAY)(raw);}
 List(const List&)=delete;
 int64_t length()const{GDExtensionInt count=0;array_size(const_cast<uint8_t*>(raw),nullptr,&count,0);return count;}
 Var entry(int64_t index)const{if(index<0||index>=length())throw std::runtime_error("Visual selection list changed outside its physical iterator");const auto* result=array_element(raw,index);if(!result)throw std::runtime_error("Visual selection entry unavailable");return Var(result);}
};
bool same(const Var& a,const Var& b){GDExtensionBool result=0;const GDExtensionConstTypePtr args[]={a.data,b.data};identity(&result,args,2);return result!=0;}
// Invocation-local canonical-owner snapshot only. No remembered admission,
// lifetime, host, runtime or state. Generic/custom bound callbacks retain their
// script path. Membership, state projection and type discovery are THREE walks,
// matching the retained filter/map/type insertion order before any selection.
bool lookup(const Var& dictionary,const Var& name,Var& out){
 if(dictionary.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Visual snapshot requires dictionary ownership maps");
 destroy(out.data);GDExtensionBool valid=0;get_keyed(dictionary.data,name.data,out.data,&valid);return valid!=0;
}
int64_t script_integer(const Var& value){
 if(value.type()==GDEXTENSION_VARIANT_TYPE_INT)return value.integer();
 if(value.type()==GDEXTENSION_VARIANT_TYPE_BOOL)return value.boolean()?1:0;
 const auto n=value.number();if(!std::isfinite(n)||n<-9223372036854775808.0||n>=9223372036854775808.0)throw std::runtime_error("Visual snapshot integer is out of range");
 return static_cast<int64_t>(n);
}
// Borrow scalar slots only inside this callback-free proof. The strong state
// handle and its private Dictionary copy keep the container alive; every slot
// is consumed immediately. No borrowed slot crosses a callback or is retained.
struct StateFields {
 alignas(8) uint8_t raw[8];
 explicit StateFields(const Var& state){if(state.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Selection proof state must be Dictionary");to[GDEXTENSION_VARIANT_TYPE_DICTIONARY](raw,const_cast<uint8_t*>(state.data));}
 ~StateFields(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY)(raw);}
 StateFields(const StateFields&)=delete;
 GDExtensionConstVariantPtr field(const char* name)const{
  const auto& label=key(name);const GDExtensionConstTypePtr args[]={label.data};GDExtensionBool present=0;dictionary_has(const_cast<uint8_t*>(raw),args,&present,1);
  // Godot's const index operator logs an engine error for missing fields, so
  // an optional proof must establish presence before borrowing a scalar slot.
  if(!present)throw std::runtime_error(std::string("Selection proof state field unavailable: ")+name);
  auto* value=dictionary_element(raw,label.data);if(!value)throw std::runtime_error("Selection proof dictionary slot is unavailable");return value;
 }
 static int64_t integer(GDExtensionConstVariantPtr value){
  const auto kind=get_type(value);
  if(kind==GDEXTENSION_VARIANT_TYPE_INT){int64_t out;to[kind](&out,const_cast<void*>(value));return out;}
  if(kind==GDEXTENSION_VARIANT_TYPE_BOOL){GDExtensionBool out;to[kind](&out,const_cast<void*>(value));return out?1:0;}
  if(kind!=GDEXTENSION_VARIANT_TYPE_FLOAT)throw std::runtime_error("Selection proof integer field must be numeric");
  double out;to[kind](&out,const_cast<void*>(value));if(!std::isfinite(out)||out<-9223372036854775808.0||out>=9223372036854775808.0)throw std::runtime_error("Selection proof integer field is out of range");return static_cast<int64_t>(out);
 }
 int64_t integer(const char* name)const{return integer(field(name));}
 bool flag(const char* name)const{
  auto value=field(name);const auto kind=get_type(value);
  if(kind==GDEXTENSION_VARIANT_TYPE_BOOL){GDExtensionBool out;to[kind](&out,const_cast<void*>(value));return out!=0;}
  if(kind==GDEXTENSION_VARIANT_TYPE_FLOAT){double out;to[kind](&out,const_cast<void*>(value));return out!=0;}
  return integer(value)!=0;
 }
};
bool no_actions(const Var& states){
 struct Competitor {Var state;int64_t kind,scope;bool attached,closed;};
 List effects(states);std::vector<Competitor> competitors;std::array<int64_t,256> selected;selected.fill(-1);
 for(int64_t index=0;index<effects.length();++index){
  auto state=effects.entry(index);StateFields fields(state);if(fields.flag("finishedF4"))continue;
  const auto visual=fields.integer("visualF8")&65535;
  // Preserve observable selected-object/view-gate calls and diagnostics by
  // taking the full original walk whenever either boundary may be touched.
  if(visual==182||((visual-242)&65535)<=2||fields.flag("field110"))return false;
  const auto scope=fields.integer("scope10c")&255;const auto attached=fields.flag("attached114");
  if(scope==0){if(!attached)return false;continue;}
  const auto kind=fields.integer("programType10d")&255;
  const auto row=static_cast<int64_t>(competitors.size());
  competitors.push_back({state,kind,scope,attached,kind==4&&fields.flag("closedEc")});
  auto& chosen=selected[static_cast<size_t>(kind)];if(chosen<0||scope<=competitors[static_cast<size_t>(chosen)].scope)chosen=row;
 }
 for(const auto& row:competitors){
  const auto& chosen=competitors[static_cast<size_t>(selected[static_cast<size_t>(row.kind)])];
  if(same(row.state,chosen.state)){if(row.closed||!row.attached)return false;}
  else if(row.attached)return false;
 }
 return true;
}
void call_no_actions(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=1){error->error=count<1?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=1;new_nil(result);return;}
 try{auto out=Var::dictionary();set(out,"no_actions_proven",Var::boolean(no_actions(Var(args[0]))));new_copy(result,out.data);}
 catch(const std::exception& reason){auto out=Var::dictionary();set(out,"error",Var::text(reason.what()));new_copy(result,out.data);}
}
Var snapshot(const Var& candidates,int64_t actor,int64_t token,const Var& desired,const Var& records,const Var& dummies,bool dummy_closed){
 SnapshotArray selected,states,types;List members(candidates);Name state_name("state");
 for(int64_t index=0;index<members.length();++index){
  auto entry=members.entry(index);
  if(get(entry,"areaVisual").boolean()||script_integer(get(entry,"actor"))!=actor||script_integer(get(entry,"privateToken"))!=token)continue;
  auto runtime=get(entry,"runtime");if(runtime.nil()||(runtime.type()==GDEXTENSION_VARIANT_TYPE_OBJECT&&!instance_from_id(object_id(runtime.data))))continue;
  Var host,record;bool bound=false;
  if(token!=0){bound=!dummy_closed&&lookup(dummies,Var::integer(actor),host)&&script_integer(get(host,"token"))==token;}
  else if(lookup(desired,Var::integer(actor),host)&&lookup(records,get(entry,"id"),record)){
   auto object=get(host,"object");Var lifetime;
   const auto actual=lookup(object,key("nativeLifetime"),lifetime)?script_integer(lifetime):0;
   bound=actual==script_integer(get(record,"lifetime"));
  }
  if(bound)selected.append(entry);
 }
 List admitted(selected.publish());
 for(int64_t index=0;index<admitted.length();++index){
  auto runtime=get(admitted.entry(index),"runtime");Var state;destroy(state.data);GDExtensionBool valid=0;
  get_named(runtime.data,state_name.data,state.data,&valid);
  if(!valid||state.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Visual snapshot runtime state is unavailable");
  states.append(state);
 }
 List projected(states.publish());std::array<bool,256> seen{};
 for(int64_t index=0;index<projected.length();++index){
  const auto kind=script_integer(get(projected.entry(index),"programType10d"))&255;
  if(!seen[static_cast<size_t>(kind)]){seen[static_cast<size_t>(kind)]=true;types.append(Var::integer(kind));}
 }
 bool proven=false;
 // A partial/custom diagnostic state may support projection without the
 // complete selector schema. Unprovable means the retained full walk, never
 // permission to skip an effect; allocation failures remain explicit errors.
 try{proven=no_actions(states.publish());}catch(const std::runtime_error&){proven=false;}
 auto out=Var::dictionary();set(out,"selected",selected.publish());set(out,"states",states.publish());set(out,"types",types.publish());set(out,"no_actions_proven",Var::boolean(proven));return out;
}
void call_snapshot(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=7){error->error=count<7?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=7;new_nil(result);return;}
 try{auto out=snapshot(Var(args[0]),Var(args[1]).integer(),Var(args[2]).integer(),Var(args[3]),Var(args[4]),Var(args[5]),Var(args[6]).boolean());new_copy(result,out.data);}
 catch(const std::exception& reason){auto out=Var::dictionary();set(out,"error",Var::text(reason.what()));new_copy(result,out.data);}
}
int64_t type(const Var& effect){return i(effect,"programType10d")&255;}
bool flag(const Var& effect,const char* field){return get(effect,field).boolean();}
struct Context {
 Var providers;int64_t attempts=0;
 explicit Context(const Var& p):providers(p){}
 Var call(const char* name,std::initializer_list<Var> args={}){++attempts;return invoke(providers,name,args);}
};
void select(const Var& actor,int64_t kind,Context& p){
 if(flag(actor,"suppressed108"))return;
 kind&=255;Var chosen;int64_t priority=255;
 {
  List effects(get(actor,"visuals80"));
  // Array iteration is live, just like the retained script walk. Copy each
  // dictionary handle before callbacks; never retain a borrowed element slot.
  for(int64_t index=0;index<effects.length();++index){
   auto effect=effects.entry(index);if(flag(effect,"finishedF4")||type(effect)!=kind)continue;
   const auto visual=i(effect,"visualF8")&65535;
   if((visual==182||((visual-242)&65535)<=2)&&get(actor,"id").number()!=p.call("selectedObjectId1406ac1c0").number())continue;
   const auto scope=i(effect,"scope10c")&255;
   if(scope==0){
    if(flag(effect,"field110")&&!p.call("viewGate1407dadb0").boolean()){if(flag(effect,"attached114"))p.call("detach",{effect});continue;}
    if(!flag(effect,"attached114"))p.call("attach",{effect});
   }else if(scope<=priority){chosen=effect;priority=scope;}
  }
 }
 // Reacquire the second-pass list, including a callback replacing the Array.
 List effects(get(actor,"visuals80"));
 for(int64_t index=0;index<effects.length();++index){
  auto effect=effects.entry(index);if(flag(effect,"finishedF4")||type(effect)!=kind||(i(effect,"scope10c")&255)==0)continue;
  if(same(effect,chosen)){
   if(type(effect)==4){
    if(flag(effect,"field110")&&!p.call("viewGate1407dadb0").boolean()){
     if(flag(effect,"attached114")&&!flag(effect,"closedEc"))p.call("stop",{effect,Var::integer(0)});
     continue;
    }
    if(flag(effect,"closedEc"))p.call("start",{effect});
   }
   if(!flag(effect,"attached114"))p.call("attach",{effect});
  }else if(flag(effect,"attached114"))p.call("detach",{effect});
 }
}
void detach(const Var& actor,const Var& current,Context& p){
 List initial(get(actor,"visuals80"));
 for(int64_t index=initial.length()-1;index>=0;--index){
  List effects(get(actor,"visuals80"));auto candidate=effects.entry(index);
  if(type(current)==7)continue;
  const auto kind=type(candidate);
  if(type(current)!=kind||same(candidate,current)||(i(candidate,"scope10c")&255)==0||flag(candidate,"finishedF4"))continue;
  if(flag(candidate,"attached114"))p.call("detach",{candidate});
  return;
 }
}
void call_select(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=3){error->error=count<3?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=3;new_nil(result);return;}
 Context p{Var(args[2])};
 try{const Var actor(args[0]),kind(args[1]);select(actor,kind.integer(),p);auto out=Var::dictionary();set(out,"callback_attempts",Var::integer(p.attempts));new_copy(result,out.data);}
 catch(const std::exception& reason){auto out=Var::dictionary();set(out,"error",Var::text(reason.what()));set(out,"callback_attempts",Var::integer(p.attempts));set(out,"partial",Var::boolean(p.attempts>0));new_copy(result,out.data);}
}
void call_detach(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=3){error->error=count<3?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=3;new_nil(result);return;}
 Context p{Var(args[2])};
 try{const Var actor(args[0]),current(args[1]);detach(actor,current,p);auto out=Var::dictionary();set(out,"callback_attempts",Var::integer(p.attempts));new_copy(result,out.data);}
 catch(const std::exception& reason){auto out=Var::dictionary();set(out,"error",Var::text(reason.what()));set(out,"callback_attempts",Var::integer(p.attempts));set(out,"partial",Var::boolean(p.attempts>0));new_copy(result,out.data);}
}
bool bind(GDExtensionInterfaceGetProcAddress address){
 const auto utility=reinterpret_cast<GDExtensionInterfaceVariantGetPtrUtilityFunction>(address("variant_get_ptr_utility_function"));
 array_element=reinterpret_cast<GDExtensionInterfaceArrayOperatorIndexConst>(address("array_operator_index_const"));if(!utility||!array_element)return false;
 get_named=reinterpret_cast<GDExtensionInterfaceVariantGetNamed>(address("variant_get_named"));
 object_id=reinterpret_cast<GDExtensionInterfaceVariantGetObjectInstanceId>(address("variant_get_object_instance_id"));
 dictionary_element=reinterpret_cast<GDExtensionInterfaceDictionaryOperatorIndexConst>(address("dictionary_operator_index_const"));
 // Install this schema's names before asset workers or frame callbacks can
 // use the shared key table. Proof/snapshot hot paths only look these up.
 for(const auto* field:{"areaVisual","actor","privateToken","runtime","id","token","object","nativeLifetime","lifetime","selected","states","types","no_actions_proven","finishedF4","visualF8","field110","scope10c","attached114","programType10d","closedEc"})key(field);
 Name name("is_same"),size_name("size"),append_name("append"),has_name("has");identity=utility(name.data,1409423524);array_size=builtin_method(GDEXTENSION_VARIANT_TYPE_ARRAY,size_name.data,3173160232);array_append=builtin_method(GDEXTENSION_VARIANT_TYPE_ARRAY,append_name.data,3316032543);dictionary_has=builtin_method(GDEXTENSION_VARIANT_TYPE_DICTIONARY,has_name.data,3680194679);return identity&&array_size&&array_append&&get_named&&object_id&&dictionary_element&&dictionary_has;
}
template<class Property>void register_methods(const Name& name,Property property){
 Name select_name("visual_select"),detach_name("visual_detach_competing"),empty(""),actor("actor"),kind("kind"),current("current"),providers("providers");auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);
 GDExtensionPropertyInfo select_args[]={property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,actor),property(GDEXTENSION_VARIANT_TYPE_INT,kind),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,providers)};
 GDExtensionClassMethodArgumentMetadata metadata[3]{};GDExtensionClassMethodInfo method{};method.name=select_name.data;method.call_func=call_select;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL|GDEXTENSION_METHOD_FLAG_STATIC;method.has_return_value=true;method.return_value_info=&ret;method.argument_count=3;method.arguments_info=select_args;method.arguments_metadata=metadata;register_method(library,name.data,&method);
 GDExtensionPropertyInfo detach_args[]={property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,actor),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,current),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,providers)};
 method.name=detach_name.data;method.call_func=call_detach;method.arguments_info=detach_args;register_method(library,name.data,&method);
 Name snapshot_name("visual_snapshot"),candidates("candidates"),actor_id("actor_id"),token("token"),desired("desired"),records("records"),dummies("dummies"),dummy_closed("dummy_closed");
 GDExtensionPropertyInfo snapshot_args[]={property(GDEXTENSION_VARIANT_TYPE_ARRAY,candidates),property(GDEXTENSION_VARIANT_TYPE_INT,actor_id),property(GDEXTENSION_VARIANT_TYPE_INT,token),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,desired),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,records),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,dummies),property(GDEXTENSION_VARIANT_TYPE_BOOL,dummy_closed)};
 GDExtensionClassMethodArgumentMetadata snapshot_metadata[7]{};method.name=snapshot_name.data;method.call_func=call_snapshot;method.argument_count=7;method.arguments_info=snapshot_args;method.arguments_metadata=snapshot_metadata;register_method(library,name.data,&method);
 Name proof_name("visual_no_actions_proof"),states("states");GDExtensionPropertyInfo proof_args[]={property(GDEXTENSION_VARIANT_TYPE_ARRAY,states)};
 method.name=proof_name.data;method.call_func=call_no_actions;method.argument_count=1;method.arguments_info=proof_args;register_method(library,name.data,&method);
}
}
