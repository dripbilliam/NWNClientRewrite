// PRIVATE, DEFAULT-OFF prototype. Scene API use stays on the initialization
// main thread. No engine, shared extension, global registration list or worker
// code is modified by this library.
#include "abi.hpp"
namespace {
enum Status:int64_t { DONE=0, EVENTS=1, BEFORE=2, REENTRANT=3, AFTER=4, ERROR_AFTER=5 };
struct EventPod { double time=0;GDExtensionConstVariantPtr name=nullptr; };
bool numeric_raw(GDExtensionConstVariantPtr value,double&out){if(!value)return false;const auto t=get_type(value);if(t==GDEXTENSION_VARIANT_TYPE_FLOAT){out=0;to[t](&out,const_cast<void*>(value));return true;}if(t==GDEXTENSION_VARIANT_TYPE_INT){int64_t n=0;to[t](&n,const_cast<void*>(value));out=static_cast<double>(n);return true;}if(t==GDEXTENSION_VARIANT_TYPE_BOOL){GDExtensionBool b=0;to[t](&b,const_cast<void*>(value));out=b?1.0:0.0;return true;}return false;}
bool prepare_events(const Var&source,std::vector<EventPod>&out){
 if(source.type()!=GDEXTENSION_VARIANT_TYPE_ARRAY)return false;
 const auto count=size(source);if(count>65536)return false;out.reserve(static_cast<size_t>(count));
 Raw array(source,GDEXTENSION_VARIANT_TYPE_ARRAY);
 for(int64_t i=0;i<count;++i){
  auto row_ptr=array_at(array.data,i);if(!row_ptr||get_type(row_ptr)!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return false;
  Var row(row_ptr);if(!has(row,keys->time)||!has(row,keys->name))return false;Raw dict(row,GDEXTENSION_VARIANT_TYPE_DICTIONARY);
  auto time=dictionary_at(dict.data,keys->time.data),name=dictionary_at(dict.data,keys->name.data);double at_time=0;
  if(!numeric_raw(time,at_time)||!name)return false;
  auto kind=get_type(name);if(kind!=GDEXTENSION_VARIANT_TYPE_STRING&&kind!=GDEXTENSION_VARIANT_TYPE_STRING_NAME)return false;
  // Pointers are call-local only. source retains every row, and all following
  // work is POD/string computation without opaque scene/script callbacks.
  out.push_back({static_cast<double>(static_cast<float>(at_time)),name});
 }
 return true;
}
Var event_name(GDExtensionConstVariantPtr source){
 if(get_type(source)==GDEXTENSION_VARIANT_TYPE_STRING)return Var(source);
 Var result;destroy(result.data);GDExtensionCallError error{};const GDExtensionConstVariantPtr args[]={source};construct(GDEXTENSION_VARIANT_TYPE_STRING,result.data,args,1,&error);
 if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("StringName event conversion failed");return result;
}
template<class Emit>void event_interval(const std::vector<EventPod>&source,double from_value,double to_value,int64_t flags,Emit&&emit){
 double from_value32=static_cast<double>(static_cast<float>(from_value)),to_value32=static_cast<double>(static_cast<float>(to_value));
 if(flags&2){from_value32=-1e9;to_value32=1e9;flags&=~int64_t(2);}
 if(flags&1){
  if(to_value32>from_value32){event_interval(source,from_value32,-1e9,flags,emit);from_value32=1e9;}
  for(auto it=source.rbegin();it!=source.rend();++it)if(it->time>=to_value32&&from_value32>it->time)emit(it->name);
 }else{
  if(from_value32>to_value32){event_interval(source,from_value32,1e9,flags,emit);from_value32=-1e9;}
  for(const auto&row:source)if(to_value32>=row.time&&row.time>from_value32)emit(row.name);
 }
}
bool safe_interval(double before,double after){return !(before < -1e9||before>1e9||after < -1e9||after>1e9);}
struct Batch {
 bool running=false;int64_t cursor=0,status=DONE;std::string reason;
 Var output,continuation;
 uint64_t calls=0,models=0,advances=0,empty=0,intervals=0,event_rows=0,fallbacks=0,post_fallbacks=0,reentrant=0,failures=0;
 void reset(){output.nil();continuation.nil();reason.clear();cursor=0;status=DONE;}
 int64_t before(const char*why){reason=why;status=BEFORE;++fallbacks;return status;}
 int64_t after(const Var&model,const Var&player,double previous,double length,int64_t serial,int64_t index,const char*why){
  continuation=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
  put(continuation,"cursor",Var::integer(cursor));put(continuation,"model_index",Var::integer(index));put(continuation,"model",model);put(continuation,"player",player);
  put(continuation,"before",Var::real(previous));put(continuation,"length",Var::real(length));put(continuation,"serial",Var::integer(serial));
  reason=why;status=AFTER;++post_fallbacks;return status;
 }
 void event(GDExtensionConstVariantPtr name,const Var&model,int64_t index,int64_t serial){const auto text=event_name(name);append(output,text);append(output,Var::integer(serial));append(output,model);append(output,Var::integer(index));++event_rows;}
 int64_t step(const Var&entry,const Var&indices,double delta){
  if(running){++reentrant;return REENTRANT;}
  if(GetCurrentThreadId()!=main_thread){reason="Animation batch requires the main thread";++failures;return ERROR_AFTER;}
  reset();++calls;running=true;struct Guard{Batch&value;~Guard(){value.running=false;}}guard{*this};
  bool advanced_current=false;Var old_model,old_player;double previous=0,length=0;int64_t serial=0;
  try{
   if(!plain(entry)||indices.type()!=GDEXTENSION_VARIANT_TYPE_ARRAY)return before("Unsupported entry/index container");
   // Match Array iteration's live index and retained container. Never retain
   // an element pointer across advance(), or cache entry.models across models.
   while(cursor<size(indices)){
    advanced_current=false;old_model.nil();old_player.nil();
    const auto index_value=at(indices,cursor);if(index_value.type()!=GDEXTENSION_VARIANT_TYPE_INT)return before("Unsupported model index type");
    const auto index=index_value.integer();const auto current_models=get(entry,keys->models);
    if(current_models.type()!=GDEXTENSION_VARIANT_TYPE_ARRAY||index<0||index>=size(current_models))return before("Unsupported live model array/index");
    old_model=at(current_models,index);if(!plain(old_model))return before("Unsupported model dictionary");
    if(has(old_model,keys->native_owner))return before("Native animation owner requires the original script path");
    if(!has(old_model,keys->player))return before("Missing original player field");
    old_player=get(old_model,keys->player);++models;
    if(old_player.type()==GDEXTENSION_VARIANT_TYPE_NIL){++cursor;continue;}
    auto player=player_object(old_player);if(!player||scripted(player))return before("Unsupported or scripted AnimationPlayer");
    const auto identity=object_id(player);const GDExtensionConstTypePtr advance_args[]={&delta};
    if(!playing(player)||empty_animation(player)){
     ptrcall(advance_bind,player,advance_args,nullptr);++advances;
     // Original branch immediately continues, even if this callback starts
     // a new clip or deletes the formerly inactive player.
     ++cursor;continue;
    }
    previous=clock_value(position_bind,player);length=clock_value(length_bind,player);
    const auto serial_value=has(old_model,keys->serial)?get(old_model,keys->serial):Var::integer(0);
    if(serial_value.type()!=GDEXTENSION_VARIANT_TYPE_INT)return before("Unsupported play serial conversion");serial=serial_value.integer();
    ptrcall(advance_bind,player,advance_args,nullptr);++advances;advanced_current=true;
    if(!alive(player,identity)){reason="Active AnimationPlayer was freed during advance";status=ERROR_AFTER;++failures;return status;}
    if(scripted(player))return after(old_model,old_player,previous,length,serial,index,"Player script changed after advance");
    const bool still_playing=playing(player);const bool named=still_playing&&!empty_animation(player);
    double speed=0;const auto speed_value=get(old_model,keys->speed);
    if(!speed_value.numeric(speed))return after(old_model,old_player,previous,length,serial,index,"Unsupported post-advance speed");
    const double current=named?clock_value(position_bind,player):(speed>=0?length:0.0);
    if(!safe_interval(previous,current))return after(old_model,old_player,previous,length,serial,index,"Outside native interval sentinel bounds");
    if(!has(old_model,keys->clip))return after(old_model,old_player,previous,length,serial,index,"Missing post-advance clip field");
    const auto clip=get(old_model,keys->clip);
    if(clip.type()!=GDEXTENSION_VARIANT_TYPE_STRING&&clip.type()!=GDEXTENSION_VARIANT_TYPE_STRING_NAME)return after(old_model,old_player,previous,length,serial,index,"Unsupported clip key");
    Var source;bool has_events=false;
    if(has(old_model,keys->events)){
     const auto map=get(old_model,keys->events);
     if(map.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return after(old_model,old_player,previous,length,serial,index,"Unsupported post-advance event map");
     if(has(map,clip)){source=get(map,clip);has_events=true;}
    }
    std::vector<EventPod> pod;
    if(has_events&&!prepare_events(source,pod))return after(old_model,old_player,previous,length,serial,index,"Unsupported post-advance event rows");
    put(old_model,keys->last_time,Var::real(current));
    if(!has_events||pod.empty())++empty;
    else{
     ++intervals;
     event_interval(pod,previous,current,speed<0?1:0,[&](GDExtensionConstVariantPtr name){event(name,old_model,index,serial);});
    }
    advanced_current=false;++cursor;
   }
   status=output.type()==GDEXTENSION_VARIANT_TYPE_NIL?DONE:EVENTS;return status;
  }catch(const std::exception&failure){
   // Canonical metadata is preflighted before appending this model's rows.
   // Unexpected allocator/ABI failures after a scene mutation are explicit;
   // never restart that model, discard a completed prefix or hide an error.
   reason=failure.what();++failures;status=ERROR_AFTER;
   if(!advanced_current&&output.type()==GDEXTENSION_VARIANT_TYPE_NIL)return before("Unsupported input before scene work");
   return status;
  }
 }
 Var take_events(){if(running)return Var();Var value(output);output.nil();return value;}
 Var take_continuation(){if(running)return Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);Var value=continuation.type()==GDEXTENSION_VARIANT_TYPE_NIL?Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY):Var(continuation);continuation.nil();put(value,"cursor",Var::integer(cursor));put(value,"status",Var::integer(status));put(value,"reason",Var::text(reason.c_str()));return value;}
 Var inspect(){auto value=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);put(value,"running",Var::boolean(running));put(value,"status",Var::integer(status));put(value,"cursor",Var::integer(cursor));put(value,"reason",Var::text(reason.c_str()));
  for(const auto&row:std::vector<std::pair<const char*,uint64_t>>{{"calls",calls},{"models",models},{"advances",advances},{"empty_models",empty},{"interval_models",intervals},{"event_rows",event_rows},{"fallbacks",fallbacks},{"post_fallbacks",post_fallbacks},{"reentrant",reentrant},{"failures",failures}})put(value,row.first,Var::integer(static_cast<int64_t>(row.second)));return value;
 }
};
Var probe_events(const Var&source,double previous,double current,int64_t flags){auto result=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);std::vector<EventPod> pod;
 const bool supported=safe_interval(previous,current)&&prepare_events(source,pod);put(result,"supported",Var::boolean(supported));Var events=Var::container(GDEXTENSION_VARIANT_TYPE_ARRAY);
 if(supported)event_interval(pod,previous,current,flags,[&](GDExtensionConstVariantPtr value){append(events,event_name(value));});put(result,"events",events);return result;}
GDExtensionMethodBindPtr notification_bind;
GDExtensionObjectPtr create(void*,GDExtensionBool notify){Name base("RefCounted"),name(CLASS);auto object=construct_object(base.data);if(!object)return nullptr;auto *batch=new Batch();set_instance(object,name.data,batch);if(notify){int64_t what=0;GDExtensionBool reversed=0;const GDExtensionConstTypePtr args[]={&what,&reversed};ptrcall(notification_bind,object,args,nullptr);}return object;}
void free_batch(void*,GDExtensionClassInstancePtr value){delete static_cast<Batch*>(value);}
void invoke(void*userdata,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr*args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError*error){
 error->error=GDEXTENSION_CALL_OK;auto &batch=*static_cast<Batch*>(instance);const auto op=static_cast<int64_t>(reinterpret_cast<intptr_t>(userdata));
 try{Var out;switch(op){case 1:if(count!=3)throw std::runtime_error("step argument count");{Var delta(args[2]);double seconds=0;if(!delta.numeric(seconds))throw std::runtime_error("step delta type");out=Var::integer(batch.step(Var(args[0]),Var(args[1]),seconds));}break;
  case 2:out=batch.take_events();break;case 3:out=batch.take_continuation();break;case 4:out=batch.inspect();break;
  case 5:if(count!=4)throw std::runtime_error("probe argument count");{Var before(args[1]),after(args[2]),flags(args[3]);double from_value=0,to_value=0;if(!before.numeric(from_value)||!after.numeric(to_value))throw std::runtime_error("probe clock types");out=probe_events(Var(args[0]),from_value,to_value,flags.integer());}break;
  default:throw std::runtime_error("Unknown private animation operation");}new_copy(result,out.data);
 }catch(const std::exception&failure){batch.reason=failure.what();++batch.failures;const auto out=Var::integer(ERROR_AFTER);new_copy(result,out.data);}
}
void method(const char *name,int64_t op,GDExtensionVariantType returned,std::vector<std::pair<const char*,GDExtensionVariantType>> arguments){
 Name cls(CLASS),method_name(name),empty;alignas(8)uint8_t hint[8]{};string_new(hint,"");std::vector<std::unique_ptr<Name>> names;std::vector<GDExtensionPropertyInfo> info;
 auto property=[&](GDExtensionVariantType type,void *field){GDExtensionPropertyInfo p{};p.type=type;p.name=field;p.class_name=empty.data;p.hint_string=hint;p.usage=6;return p;};
 for(const auto &arg:arguments){names.push_back(std::make_unique<Name>(arg.first));info.push_back(property(arg.second,names.back()->data));}
 auto ret=property(returned,empty.data);if(returned==GDEXTENSION_VARIANT_TYPE_NIL)ret.usage|=131072;
 std::vector<GDExtensionClassMethodArgumentMetadata> metadata(arguments.size());GDExtensionClassMethodInfo m{};m.name=method_name.data;m.method_userdata=reinterpret_cast<void*>(static_cast<intptr_t>(op));m.call_func=invoke;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=static_cast<uint32_t>(arguments.size());m.arguments_info=info.data();m.arguments_metadata=metadata.data();register_method(library,cls.data,&m);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(hint);
}
GDExtensionMethodBindPtr bind(const char *cls,const char *name,int64_t hash){Name c(cls),n(name);return method_bind(c.data,n.data,hash);}
GDExtensionPtrBuiltInMethod builtin(GDExtensionVariantType type,const char *name,int64_t hash){Name n(name);return builtin_method(type,n.data,hash);}
void initialize(void*,GDExtensionInitializationLevel level){if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;main_thread=GetCurrentThreadId();
 advance_bind=bind("AnimationMixer","advance",373806689);is_playing_bind=bind("AnimationPlayer","is_playing",36873697);current_bind=bind("AnimationPlayer","get_current_animation",2002593661);position_bind=bind("AnimationPlayer","get_current_animation_position",1740695150);length_bind=bind("AnimationPlayer","get_current_animation_length",1740695150);script_bind=bind("Object","get_script",1214101251);notification_bind=bind("Object","notification",4023243586);
 array_size=builtin(GDEXTENSION_VARIANT_TYPE_ARRAY,"size",3173160232);array_append=builtin(GDEXTENSION_VARIANT_TYPE_ARRAY,"append",3316032543);dict_has=builtin(GDEXTENSION_VARIANT_TYPE_DICTIONARY,"has",3680194679);dict_typed=builtin(GDEXTENSION_VARIANT_TYPE_DICTIONARY,"is_typed",3918633141);dict_read_only=builtin(GDEXTENSION_VARIANT_TYPE_DICTIONARY,"is_read_only",3918633141);name_empty=builtin(GDEXTENSION_VARIANT_TYPE_STRING_NAME,"is_empty",3918633141);Name valid("is_instance_valid"),player("AnimationPlayer");valid_instance=get_utility(valid.data,996128841);player_tag=class_tag(player.data);
 if(!advance_bind||!is_playing_bind||!current_bind||!position_bind||!length_bind||!script_bind||!notification_bind||!array_size||!array_append||!dict_has||!dict_typed||!dict_read_only||!name_empty||!valid_instance||!player_tag)return;
 keys=std::make_unique<Keys>();Name cls(CLASS),base("RefCounted");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=create;info.free_instance_func=free_batch;register_class(library,cls.data,base.data,&info);registered=true;
 method("step",1,GDEXTENSION_VARIANT_TYPE_INT,{{"entry",GDEXTENSION_VARIANT_TYPE_DICTIONARY},{"indices",GDEXTENSION_VARIANT_TYPE_ARRAY},{"delta",GDEXTENSION_VARIANT_TYPE_FLOAT}});
 method("take_events",2,GDEXTENSION_VARIANT_TYPE_NIL,{});method("take_continuation",3,GDEXTENSION_VARIANT_TYPE_DICTIONARY,{});method("inspect",4,GDEXTENSION_VARIANT_TYPE_DICTIONARY,{});
 method("probe_events",5,GDEXTENSION_VARIANT_TYPE_DICTIONARY,{{"events",GDEXTENSION_VARIANT_TYPE_ARRAY},{"before",GDEXTENSION_VARIANT_TYPE_FLOAT},{"after",GDEXTENSION_VARIANT_TYPE_FLOAT},{"flags",GDEXTENSION_VARIANT_TYPE_INT}});
}
void deinitialize(void*,GDExtensionInitializationLevel level){if(level==GDEXTENSION_INITIALIZATION_SCENE){if(registered){Name cls(CLASS);unregister_class(library,cls.data);registered=false;}keys.reset();}}
}
extern "C" __declspec(dllexport) GDExtensionBool nwn_rig_animation_batch_init(GDExtensionInterfaceGetProcAddress address,GDExtensionClassLibraryPtr own_library,GDExtensionInitialization*init){library=own_library;
#define API(target,type,name) target=reinterpret_cast<type>(address(name));if(!target)return false
 API(new_nil,GDExtensionInterfaceVariantNewNil,"variant_new_nil");API(new_copy,GDExtensionInterfaceVariantNewCopy,"variant_new_copy");API(destroy,GDExtensionInterfaceVariantDestroy,"variant_destroy");API(get_type,GDExtensionInterfaceVariantGetType,"variant_get_type");API(from_type,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor");API(to_type,GDExtensionInterfaceGetVariantToTypeConstructor,"get_variant_to_type_constructor");API(construct,GDExtensionInterfaceVariantConstruct,"variant_construct");API(destructor,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor");API(builtin_method,GDExtensionInterfaceVariantGetPtrBuiltinMethod,"variant_get_ptr_builtin_method");API(name_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars");API(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");API(dictionary_at,GDExtensionInterfaceDictionaryOperatorIndexConst,"dictionary_operator_index_const");API(set_keyed,GDExtensionInterfaceVariantSetKeyed,"variant_set_keyed");API(array_at,GDExtensionInterfaceArrayOperatorIndexConst,"array_operator_index_const");API(construct_object,GDExtensionInterfaceClassdbConstructObject3,"classdb_construct_object3");API(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance");API(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass6,"classdb_register_extension_class6");API(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");API(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");API(method_bind,GDExtensionInterfaceClassdbGetMethodBind,"classdb_get_method_bind");API(ptrcall,GDExtensionInterfaceObjectMethodBindPtrcall,"object_method_bind_ptrcall");API(object_id,GDExtensionInterfaceObjectGetInstanceId,"object_get_instance_id");API(object_from_id,GDExtensionInterfaceObjectGetInstanceFromId,"object_get_instance_from_id");API(class_tag,GDExtensionInterfaceClassdbGetClassTag,"classdb_get_class_tag");API(cast_to,GDExtensionInterfaceObjectCastTo,"object_cast_to");API(get_utility,GDExtensionInterfaceVariantGetPtrUtilityFunction,"variant_get_ptr_utility_function");
 API(get_keyed,GDExtensionInterfaceVariantGetKeyed,"variant_get_keyed");
#undef API
 for(int index=1;index<GDEXTENSION_VARIANT_TYPE_VARIANT_MAX;++index){from[index]=from_type(static_cast<GDExtensionVariantType>(index));to[index]=to_type(static_cast<GDExtensionVariantType>(index));}
 init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=nullptr;return true;
}
