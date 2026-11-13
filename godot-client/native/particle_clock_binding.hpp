// Opt-in specialization of the canonical ModelRigs playback getter. Values
// are read at the original per-source callback boundary, never cached across
// sources. Unknown scripts, conversions and changed scripts keep the Callable.
namespace particle_clock_binding {
bool enabled=false,available=false;
GDExtensionMethodBindPtr object_script=nullptr,object_get=nullptr,script_source=nullptr;
GDExtensionInterfaceObjectGetInstanceId object_id=nullptr;
GDExtensionPtrOperatorEvaluator string_equal=nullptr;
void* gdscript_tag=nullptr;
struct StringValue {
 alignas(8) uint8_t data[8];
 explicit StringValue(GDExtensionObjectPtr script){ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING,0)(data,nullptr);ptrcall(script_source,script,nullptr,data);}
 ~StringValue(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING)(data);}
 StringValue(const StringValue&)=delete;
 EngineVar publish()const{EngineVar out;destroy(out.data);from[GDEXTENSION_VARIANT_TYPE_STRING](out.data,const_cast<uint8_t*>(data));return out;}
 bool equals(const StringValue& other)const{GDExtensionBool same=false;string_equal(data,other.data,&same);return same!=0;}
};
EngineVar script_of(GDExtensionObjectPtr object){EngineVar out;ptrcall(object_script,object,nullptr,out.data);return out;}
GDExtensionObjectPtr pointer(const EngineVar& value){if(value.type()!=GDEXTENSION_VARIANT_TYPE_OBJECT)return nullptr;GDExtensionObjectPtr result=nullptr;to[GDEXTENSION_VARIANT_TYPE_OBJECT](&result,const_cast<uint8_t*>(value.data));return result;}
void bind(GDExtensionInterfaceGetProcAddress address){
 Name os_name("OS");auto os_object=global_singleton(os_name.data);if(os_object){EngineVar os;destroy(os.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](os.data,&os_object);auto args=::method(os,"get_cmdline_user_args");enabled=::method(args,"has",{EngineVar::text("--particle-clock-read=native")}).boolean();if(::method(args,"has",{EngineVar::text("--particle-clock-read=reference")}).boolean())enabled=false;}
 if(!enabled||!address)return;
 Name object("Object"),get_script("get_script"),get("get"),script("Script"),get_source("get_source_code"),gdscript("GDScript");
 object_script=class_method(object.data,get_script.data,1214101251);object_get=class_method(object.data,get.data,2760726917);script_source=class_method(script.data,get_source.data,201670096);gdscript_tag=class_tag(gdscript.data);
 object_id=reinterpret_cast<GDExtensionInterfaceObjectGetInstanceId>(address("object_get_instance_id"));
 const auto evaluator=reinterpret_cast<GDExtensionInterfaceVariantGetPtrOperatorEvaluator>(address("variant_get_ptr_operator_evaluator"));
 if(evaluator)string_equal=evaluator(GDEXTENSION_VARIANT_OP_EQUAL,GDEXTENSION_VARIANT_TYPE_STRING,GDEXTENSION_VARIANT_TYPE_STRING);
 available=object_script&&object_get&&script_source&&gdscript_tag&&object_id&&string_equal;
}
bool canonical_source(std::string source){
 source.erase(std::remove(source.begin(),source.end(),'\r'),source.end());source="\n"+source;
 const std::string field="\nvar entities: Dictionary = {}\n";
 if(source.find(field)==std::string::npos)return false;
 const std::string getter="\nfunc playback_state(id: int,model_index: int) -> Dictionary:\n\tif not entities.has(id) or model_index<0 or model_index>=entities[id].models.size(): return {}\n\tvar model: Dictionary=entities[id].models[model_index]\n\treturn {\"clip\":str(model.get(\"clip\",\"\")),\"time\":float(model.get(\"last_time\",0.0)),\"serial\":int(model.get(\"play_serial\",0))}\n";
 const auto start=source.find(getter);if(start==std::string::npos)return false;
 // Reject an additional body statement after the recognized return. Empty
 // lines/comments are harmless; the next actual line must be top-level.
 for(size_t at=start+getter.size();at<source.size();){const auto end=source.find('\n',at);const auto line=source.substr(at,end==std::string::npos?end:end-at);const auto first=line.find_first_not_of(" \t");if(first!=std::string::npos&&line[first]!='#')return first==0;if(end==std::string::npos)break;at=end+1;}
 return true;
}
struct Binding {
 uint64_t owner=0;int64_t model_index=0;EngineVar entity,script;
 Name entities_name{"entities"};
 std::unique_ptr<StringValue> source;
};
std::unique_ptr<Binding> prepare(EngineVar clock){
 if(!enabled||!available||clock.type()!=GDEXTENSION_VARIANT_TYPE_CALLABLE)return {};
 if(engine_string(::method(clock,"get_method"))!="playback_state"||::method(clock,"get_unbound_arguments_count").integer()!=0)return {};
 auto arguments=::method(clock,"get_bound_arguments");if(arguments.type()!=GDEXTENSION_VARIANT_TYPE_ARRAY||::size(arguments)!=2)return {};
 auto entity=::at(arguments,0),index=::at(arguments,1);if(entity.type()!=GDEXTENSION_VARIANT_TYPE_INT||index.type()!=GDEXTENSION_VARIANT_TYPE_INT)return {};
 auto value=::method(clock,"get_object");auto object=pointer(value);if(!object)return {};
 auto script=script_of(object);auto script_object=pointer(script);if(!script_object||!cast_object(script_object,gdscript_tag))return {};
 // Setup-only generic Resource methods cannot dispatch an authored override.
 if(!script_of(script_object).nil())return {};
 if(pointer(::method(script,"get_base_script"))||engine_string(::method(script,"get_path"))!="res://systems/model_rigs.gd")return {};
 auto source=std::make_unique<StringValue>(script_object);if(!canonical_source(engine_string(source->publish())))return {};
 auto binding=std::make_unique<Binding>();binding->owner=object_id(object);binding->model_index=index.integer();binding->entity=entity;binding->script=script;binding->source=std::move(source);return binding;
}
bool lookup(const EngineVar& dictionary,const EngineVar& key_value,EngineVar& value){
 destroy(value.data);GDExtensionBool present=false;get_keyed(dictionary.data,key_value.data,value.data,&present);return present!=0;
}
bool read(const Binding& binding,std::string& clip,double& time){
 auto object=instance_from_id(binding.owner);if(!object)return false;
 auto script=script_of(object);auto script_object=pointer(script);if(!script_object||script_object!=pointer(binding.script))return false;
 // String comparison is native COW-buffer equality for unchanged source;
 // no dynamic call or source parsing is done at the hot boundary.
 StringValue current(script_object);if(!current.equals(*binding.source))return false;
 const GDExtensionConstTypePtr args[]={binding.entities_name.data};EngineVar entities;ptrcall(object_get,object,args,entities.data);
 if(entities.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return false;
 EngineVar entry;if(!lookup(entities,binding.entity,entry)||binding.model_index<0){clip.clear();time=0;return true;}
 if(entry.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return false;
 EngineVar models;if(!lookup(entry,::key("models"),models)||models.type()!=GDEXTENSION_VARIANT_TYPE_ARRAY)return false;
 EngineVar model;destroy(model.data);GDExtensionBool valid=false,oob=false;get_indexed(models.data,binding.model_index,model.data,&valid,&oob);
 if(oob){clip.clear();time=0;return true;}if(!valid||model.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)return false;
 EngineVar next_clip,next_time,serial;const bool has_clip=lookup(model,::key("clip"),next_clip),has_time=lookup(model,::key("last_time"),next_time),has_serial=lookup(model,::key("play_serial"),serial);
 // Preserve the original conversion/error boundary, including serial, even
 // though presentation consumes only clip and time from the returned packet.
 if(has_clip&&next_clip.type()!=GDEXTENSION_VARIANT_TYPE_STRING&&next_clip.type()!=GDEXTENSION_VARIANT_TYPE_STRING_NAME)return false;
 if(has_time&&next_time.type()!=GDEXTENSION_VARIANT_TYPE_FLOAT&&next_time.type()!=GDEXTENSION_VARIANT_TYPE_INT)return false;
 if(has_serial&&serial.type()!=GDEXTENSION_VARIANT_TYPE_INT)return false;
 clip=has_clip?engine_string(next_clip):"";time=has_time?next_time.number():0;return true;
}
}
