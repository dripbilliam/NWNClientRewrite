// PRIVATE, UNCOMPILED prototype. Separate library/class; no product registration.
// Godot iterator semantics and native arithmetic are separate acceptance gates.
#include "abi.hpp"
#include "coarse_prefix_core.hpp"
#include <optional>
#include <stdexcept>
namespace {
GDExtensionInterfaceVariantIterInit cursor_iter_init;
GDExtensionInterfaceVariantIterNext cursor_iter_next;
GDExtensionInterfaceVariantIterGet cursor_iter_get;
GDExtensionInterfaceDictionaryOperatorIndexConst dictionary_at;
GDExtensionInterfaceArrayOperatorIndexConst array_at;
GDExtensionInterfaceVariantGetPtrUtilityFunction get_utility;
GDExtensionPtrUtilityFunction same_utility;
bool registered=false;DWORD initialization_thread=0;
// These are pure builtins on an already-typed container, before any keyed or
// indexed access. Readonly scratch and typed coercion remain on script.
bool plain(const Var&value){const auto type=value.type();if(type!=GDEXTENSION_VARIANT_TYPE_DICTIONARY&&type!=GDEXTENSION_VARIANT_TYPE_ARRAY)return false;return !call(value,"is_read_only").boolean()&&!call(value,"is_typed").boolean();}
struct Raw {
 alignas(8) uint8_t data[64]{};
 GDExtensionVariantType type;bool readable=false;
 explicit Raw(GDExtensionConstVariantPtr value,GDExtensionVariantType wanted):type(wanted){if(get_type(value)!=type)throw std::runtime_error("Raw container type differs");to[type](data,const_cast<void*>(value));const Var container(value);readable=plain(container);}
 ~Raw(){destructor(type)(data);}
 Raw(const Raw&)=delete;
};
bool same(const Var&a,const Var&b){GDExtensionBool value=0;const GDExtensionConstTypePtr args[]={a.data,b.data};same_utility(&value,args,2);return value!=0;}
GDExtensionConstVariantPtr find(const Raw&dict,const Var&name){if(!dict.readable)throw std::runtime_error("Guarded Dictionary element read refused");return dictionary_at(dict.data,name.data);}
GDExtensionConstVariantPtr indexed(const Raw&array,int64_t index){if(!array.readable)throw std::runtime_error("Guarded Array element read refused");return array_at(array.data,index);}
GDExtensionConstVariantPtr field(const Raw&dict,const char*name){const auto k=key(name);return find(dict,k);}
int64_t size(const Var&value){return call(value,"size").integer();}
bool number(GDExtensionConstVariantPtr value,double&out){
 if(!value)return false;
 const auto type=get_type(value);
 if(type==GDEXTENSION_VARIANT_TYPE_FLOAT){to[type](&out,const_cast<void*>(value));return true;}
 if(type==GDEXTENSION_VARIANT_TYPE_INT){int64_t integer=0;to[type](&integer,const_cast<void*>(value));out=static_cast<double>(integer);return true;}
 if(type==GDEXTENSION_VARIANT_TYPE_BOOL){GDExtensionBool boolean=0;to[type](&boolean,const_cast<void*>(value));out=boolean?1.0:0.0;return true;}
 return false;
}
bool numeric_truth(GDExtensionConstVariantPtr value,bool&out){double numeric=0;if(!number(value,numeric))return false;out=numeric!=0;return true;}
Var raw_copy(GDExtensionConstVariantPtr value){return value?Var(value):Var();}
Var status(const char*name){auto value=output(true);put(value,"status",Var::text(name));return value;}
Var capability(){auto value=output(same_utility!=nullptr);put(value,"status",Var::text("capabilities"));put(value,"abi",Var::integer(1));put(value,"incremental",Var::boolean(true));put(value,"retained_original_iterator",Var::boolean(true));put(value,"sticky_fallback",Var::boolean(true));put(value,"activation_accepted",Var::boolean(false));return value;}
struct Cursor {
 Var origin,iterator; // Exactly the original for-loop container and counter key.
 coarse_static_prefix::Query query;
 bool started=false,more=false,yielded=false,script_only=false,finished=false,running=false;
 int64_t calls=0,scanned=0,skipped=0,admitted=0,fallback_keys=0,retention_failures=0,ordinal=-1;
 void close(){started=false;finished=true;more=false;yielded=false;script_only=true;origin=Var();iterator=Var();}
 Var begin(const Var&input){
  if(started)return unsupported("Cursor already started; close it explicitly");
  const auto groups=get(input,"groups"),from=get(input,"from"),to_value=get(input,"to");
  if(groups.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||!plain(groups)||from.type()!=GDEXTENSION_VARIANT_TYPE_VECTOR3||to_value.type()!=GDEXTENSION_VARIANT_TYPE_VECTOR3)return unsupported("Begin requires Dictionary and Vector3 inputs");
  double radius=0;const Raw root(input.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY);if(!number(field(root,"radius"),radius))return unsupported("Radius conversion stays on the original script");
  to[GDEXTENSION_VARIANT_TYPE_VECTOR3](query.from.data(),const_cast<uint8_t*>(from.data));to[GDEXTENSION_VARIANT_TYPE_VECTOR3](query.to.data(),const_cast<uint8_t*>(to_value.data));query.radius=radius;
  origin=groups;iterator=Var();GDExtensionBool valid=0;destroy(iterator.data);more=cursor_iter_init(origin.data,iterator.data,&valid)!=0;
  if(!valid){close();return unsupported("Original Dictionary iteration unavailable");}
  started=true;finished=false;yielded=false;script_only=false;ordinal=-1;calls=scanned=skipped=admitted=fallback_keys=retention_failures=0;
  return status("ready");
 }
 // Checks use public is_same identity, never private Dictionary memory layouts.
 // Lost retention could make old caller-local destruction observable; in that
 // case advance only the key and make the remainder execute original script.
 bool prior_retained(const Var&input,const Var&live_models_bounds){
  const Raw args(input.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY);
  auto key_ptr=field(args,"prior_key"),group_ptr=field(args,"prior_group"),bounds_ptr=field(args,"prior_bounds"),states_ptr=field(args,"prior_states");
  if(!key_ptr||!group_ptr||!bounds_ptr||!states_ptr||!plain(origin))return false;
  if((get_type(key_ptr)!=GDEXTENSION_VARIANT_TYPE_STRING&&get_type(key_ptr)!=GDEXTENSION_VARIANT_TYPE_STRING_NAME)||get_type(group_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||get_type(bounds_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||get_type(states_ptr)!=GDEXTENSION_VARIANT_TYPE_ARRAY)return false;
  if(!plain(raw_copy(group_ptr))||!plain(raw_copy(bounds_ptr))||!plain(raw_copy(states_ptr))||!plain(live_models_bounds))return false;
  const Var prior_key(key_ptr);if(!same(prior_key,iterator))return false;
  const Raw original(origin.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY);const auto held_group_ptr=find(original,iterator);
  if(!held_group_ptr||get_type(held_group_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||get_type(group_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return false;
  const Var held_group(held_group_ptr),prior_group(group_ptr);if(!plain(held_group)||!same(held_group,prior_group))return false;
  const Raw held(held_group.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY);const auto held_bounds=field(held,"bounds");
  if(!held_bounds||get_type(held_bounds)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||get_type(bounds_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||!plain(raw_copy(held_bounds))||!same(raw_copy(held_bounds),raw_copy(bounds_ptr)))return false;
  const Raw models_bounds(live_models_bounds.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY);const auto held_states=find(models_bounds,iterator);
  return held_states&&get_type(held_states)==GDEXTENSION_VARIANT_TYPE_ARRAY&&get_type(states_ptr)==GDEXTENSION_VARIANT_TYPE_ARRAY&&plain(raw_copy(held_states))&&same(raw_copy(held_states),raw_copy(states_ptr));
 }
 Var yielded_status(const char*name,const Var&key_value,const char*reason=nullptr){auto value=status(name);put(value,"key",key_value);put(value,"ordinal",Var::integer(ordinal));put(value,"scanned",Var::integer(scanned));put(value,"script_only",Var::boolean(script_only));if(reason)put(value,"reason",Var::text(reason));yielded=true;return value;}
 Var fallback(const Var&key_value,const char*reason){script_only=true;++fallback_keys;return yielded_status("fallback",key_value,reason);}
 Var next(const Var&input){
  ++calls;if(!started||finished)return status("done");
  const Raw args(input.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY);const auto groups_ptr=field(args,"groups"),models_ptr=field(args,"models"),model_bounds_ptr=field(args,"model_bounds");
  if(!groups_ptr||!models_ptr||!model_bounds_ptr||get_type(groups_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||get_type(models_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||get_type(model_bounds_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return unsupported("Resume requires live Dictionary properties; preserve current key for original continuation");
  const Var groups(groups_ptr),models(models_ptr),model_bounds(model_bounds_ptr);
  // Replacement can make origin cursor-only-owned; preserve original final-local destruction order by falling back before any skip.
  if(!plain(groups)||!plain(models)||!plain(model_bounds)||!same(groups,origin))script_only=true;
  if(yielded){if(!script_only&&!prior_retained(input,model_bounds)){script_only=true;++retention_failures;}GDExtensionBool valid=0;more=cursor_iter_next(origin.data,iterator.data,&valid)!=0;if(!valid)return unsupported("Original iterator continuation invalid");yielded=false;}
  const Raw live_groups(groups.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY),live_models(models.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY),live_bounds(model_bounds.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY);
  while(more){
   GDExtensionBool valid=0;Var current;destroy(current.data);cursor_iter_get(origin.data,iterator.data,current.data,&valid);if(!valid)return unsupported("Original iterator key unavailable");++ordinal;
   if(script_only)return fallback(current,"Sticky original-script continuation");
   if(current.type()!=GDEXTENSION_VARIANT_TYPE_STRING&&current.type()!=GDEXTENSION_VARIANT_TYPE_STRING_NAME)return fallback(current,"Noncanonical key uses original script");
   const auto group_ptr=find(live_groups,current);if(!group_ptr||get_type(group_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return fallback(current,"Current group replacement or missing key uses original script");
   const Var group_value(group_ptr);if(!plain(group_value))return fallback(current,"Readonly or typed group uses original script");const Raw group(group_value.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY);const auto bounds_ptr=field(group,"bounds");
   if(!bounds_ptr||get_type(bounds_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return fallback(current,"Non-Dictionary bounds use original script");
   const Var bounds_value(bounds_ptr);if(!plain(bounds_value))return fallback(current,"Readonly or typed bounds use original script");const Raw bounds(bounds_value.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY);
   if(size(bounds_value)==0){++scanned;++skipped;}
   else {
    coarse_static_prefix::Group numeric;const auto model_ptr=find(live_models,current);numeric.model_exists=model_ptr!=nullptr;
    if(model_ptr){if(get_type(model_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return fallback(current,"Model coercion uses original script");const Var model(model_ptr);if(!plain(model))return fallback(current,"Readonly or typed model uses original script");numeric.model_empty=size(model)==0;const Raw data(model.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY);numeric.model_error=field(data,"error")!=nullptr;}
    const auto states_ptr=find(live_bounds,current);if(states_ptr&&get_type(states_ptr)!=GDEXTENSION_VARIANT_TYPE_ARRAY)return fallback(current,"State collection conversion uses original script");
    Var states_value=states_ptr?Var(states_ptr):Var::container(GDEXTENSION_VARIANT_TYPE_ARRAY);
    if(!plain(states_value))return fallback(current,"Readonly or typed states use original script");
    if(numeric.model_exists&&!numeric.model_empty&&!numeric.model_error){
     const Raw states(states_value.data,GDEXTENSION_VARIANT_TYPE_ARRAY);const auto count=size(states_value);if(count<0||count>16384)return fallback(current,"State bound uses original script");numeric.states.reserve(static_cast<size_t>(count));
     for(int64_t index=0;index<count;++index){const auto state_ptr=indexed(states,index);if(!state_ptr||get_type(state_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return fallback(current,"State getters use original script");const Var state_value(state_ptr);if(!plain(state_value))return fallback(current,"Readonly or typed state uses original script");const Raw state(state_value.data,GDEXTENSION_VARIANT_TYPE_DICTIONARY);coarse_static_prefix::State item;const auto pending=field(state,"pending");if(pending&&!numeric_truth(pending,item.pending))return fallback(current,"State truth conversion uses original script");if(item.pending){++scanned;finished=true;return yielded_status("unready",current);}const auto radius=field(state,"radius");item.radius_present=radius!=nullptr;if(radius&&!number(radius,item.radius))return fallback(current,"State radius conversion uses original script");numeric.states.push_back(item);}
    }
    const char*names[]={"min_x","min_y","max_x","max_y"};for(size_t index=0;index<4;++index)if(!number(field(bounds,names[index]),numeric.bounds[index]))return fallback(current,"Bounds conversion uses original script");
    ++scanned;const auto result=coarse_static_prefix::evaluate(query,std::vector<coarse_static_prefix::Group>{std::move(numeric)});
    if(!result.ready){finished=true;return yielded_status("unready",current);}
    if(!result.rows.empty()){++admitted;auto value=yielded_status("admit",current);put(value,"group",group_value);put(value,"bounds",bounds_value);put(value,"states",states_value);put(value,"pending",Var::boolean(result.rows[0].pending));Var expansion;destroy(expansion.data);double number_value=result.rows[0].expansion;from[GDEXTENSION_VARIANT_TYPE_FLOAT](expansion.data,&number_value);put(value,"expansion",expansion);return value;}
    ++skipped;
   }
   GDExtensionBool advance_valid=0;more=cursor_iter_next(origin.data,iterator.data,&advance_valid)!=0;if(!advance_valid)return unsupported("Original iterator changed while scanning");
  }
  finished=true;return status("done");
 }
 Var statistics(){auto value=status("statistics");put(value,"native_cursor_calls",Var::integer(calls));put(value,"scanned",Var::integer(scanned));put(value,"skipped",Var::integer(skipped));put(value,"admitted",Var::integer(admitted));put(value,"admit",Var::integer(admitted));put(value,"native_admit",Var::integer(admitted));put(value,"native_scanned",Var::integer(scanned));put(value,"fallback_keys",Var::integer(fallback_keys));put(value,"fallback",Var::integer(fallback_keys));put(value,"retention_failures",Var::integer(retention_failures));put(value,"script_only",Var::boolean(script_only));return value;}
};
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name(CLASS);auto object=construct_object(base.data);if(!object)return nullptr;auto*owner=new Cursor();set_instance(object,name.data,owner);if(notify){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);const auto what=Var::integer(0);call(value,"notification",{&what});}return object;}
void free_cursor(void*,GDExtensionClassInstancePtr value){delete static_cast<Cursor*>(value);}
void dispatch(void*,GDExtensionClassInstancePtr value,const GDExtensionConstVariantPtr*args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError*error){
 error->error=GDEXTENSION_CALL_OK;if(count!=2){error->error=count<2?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=2;new_nil(result);return;}if(GetCurrentThreadId()!=initialization_thread){auto out=unsupported("Cursor operations require the extension scene-initialization thread");new_copy(result,out.data);return;}auto&owner=*static_cast<Cursor*>(value);
 if(owner.running){auto out=unsupported("Reentrant cursor operation requires original-script handling");new_copy(result,out.data);return;}
 owner.running=true;struct Guard{Cursor&owner;~Guard(){owner.running=false;}}guard{owner};
 try{const Var operation(args[0]),input(args[1]);if(!plain(input)){auto out=unsupported("Readonly, typed or non-Dictionary operation envelope; no field was read");new_copy(result,out.data);return;}Var out;switch(operation.integer()){case 0:out=capability();break;case 1:out=owner.begin(input);break;case 2:out=owner.next(input);break;case 5:owner.close();out=status("closed");break;case 6:out=owner.statistics();break;default:out=unsupported("Unsupported cursor operation");}new_copy(result,out.data);}catch(const std::exception&failure){auto out=unsupported(failure.what());new_copy(result,out.data);}
}
void initialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;initialization_thread=GetCurrentThreadId();Name same_name("is_same");same_utility=get_utility(same_name.data,1409423524);if(!same_utility)return;
 Name name(CLASS),base("RefCounted"),method("dispatch"),empty(""),operation("operation"),input("input");alignas(8)uint8_t hint[8]{};string_new(hint,"");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free_cursor;register_class(library,name.data,base.data,&info);registered=true;
 const auto property=[&](GDExtensionVariantType type,Name&value){GDExtensionPropertyInfo p{};p.type=type;p.name=value.data;p.class_name=empty.data;p.hint_string=hint;p.usage=6;return p;};auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);GDExtensionPropertyInfo arguments[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo m{};m.name=method.data;m.call_func=dispatch;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=2;m.arguments_info=arguments;m.arguments_metadata=metadata;register_method(library,name.data,&m);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(hint);
}
void deinitialize(void*,GDExtensionInitializationLevel level){if(level==GDEXTENSION_INITIALIZATION_SCENE&&registered){Name name(CLASS);unregister_class(library,name.data);registered=false;}}
}
extern "C" __declspec(dllexport) GDExtensionBool nwn_static_prefix_cursor_init(GDExtensionInterfaceGetProcAddress address,GDExtensionClassLibraryPtr own_library,GDExtensionInitialization*init){
 library=own_library;
#define API(target,type,name) target=reinterpret_cast<type>(address(name));if(!target)return false
 API(new_nil,GDExtensionInterfaceVariantNewNil,"variant_new_nil");API(new_copy,GDExtensionInterfaceVariantNewCopy,"variant_new_copy");API(destroy,GDExtensionInterfaceVariantDestroy,"variant_destroy");API(get_type,GDExtensionInterfaceVariantGetType,"variant_get_type");API(get_keyed,GDExtensionInterfaceVariantGetKeyed,"variant_get_keyed");API(set_keyed,GDExtensionInterfaceVariantSetKeyed,"variant_set_keyed");API(get_indexed,GDExtensionInterfaceVariantGetIndexed,"variant_get_indexed");API(variant_call,GDExtensionInterfaceVariantCall,"variant_call");API(construct,GDExtensionInterfaceVariantConstruct,"variant_construct");API(from_type,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor");API(to_type,GDExtensionInterfaceGetVariantToTypeConstructor,"get_variant_to_type_constructor");API(destructor,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor");API(builtin_method,GDExtensionInterfaceVariantGetPtrBuiltinMethod,"variant_get_ptr_builtin_method");API(operator_evaluator,GDExtensionInterfaceVariantGetPtrOperatorEvaluator,"variant_get_ptr_operator_evaluator");API(name_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars");API(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");API(string_utf8,GDExtensionInterfaceStringToUtf8Chars,"string_to_utf8_chars");API(construct_object,GDExtensionInterfaceClassdbConstructObject3,"classdb_construct_object3");API(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance");API(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass6,"classdb_register_extension_class6");API(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");API(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");API(cursor_iter_init,GDExtensionInterfaceVariantIterInit,"variant_iter_init");API(cursor_iter_next,GDExtensionInterfaceVariantIterNext,"variant_iter_next");API(cursor_iter_get,GDExtensionInterfaceVariantIterGet,"variant_iter_get");API(dictionary_at,GDExtensionInterfaceDictionaryOperatorIndexConst,"dictionary_operator_index_const");API(array_at,GDExtensionInterfaceArrayOperatorIndexConst,"array_operator_index_const");API(get_utility,GDExtensionInterfaceVariantGetPtrUtilityFunction,"variant_get_ptr_utility_function");
#undef API
 for(int index=1;index<GDEXTENSION_VARIANT_TYPE_VARIANT_MAX;++index){from[index]=from_type(static_cast<GDExtensionVariantType>(index));to[index]=to_type(static_cast<GDExtensionVariantType>(index));}init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=nullptr;return true;
}
