// Included inside resident, after private Container/field access definitions.
// Cache private field locations, never values. Weak control-block ownership
// prevents address ABA without retaining old objects or delaying destruction.
namespace hot_parameters {
bool requested=false;
enum Key : size_t { DETONATE=0,SIZE_MID=1,SIZE_MID_Y=2,COUNT=3 };
constexpr const char* names[COUNT]={"detonate","sizemid","sizemid_y"};
void bind(){Name os_name("OS");auto object=global_singleton(os_name.data);if(!object)return;EngineVar os;destroy(os.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](os.data,&object);auto args=::method(os,"get_cmdline_user_args");requested=::method(args,"has",{EngineVar::text("--particle-hot-parameters=bound")}).boolean();if(::method(args,"has",{EngineVar::text("--particle-hot-parameters=legacy")}).boolean())requested=false;}
struct Field {
 std::weak_ptr<Container> identity;
 Container* address=nullptr;Var* value=nullptr;const char* bound_name=nullptr;uint64_t revision=0;
 bool initialized=false;
 uint64_t reads=0,hits=0,rebinds=0,absent=0,uncacheable=0;
 Var* read(const Var& record,const char* name){
  ++reads;
  if(record.kind!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Native owner record required");
  auto* current=record.container.get();
  if(current->shape_uncacheable){++uncacheable;return field_value(record,name);}
  const bool same=initialized&&bound_name==name&&address==current&&!identity.owner_before(record.container)&&!record.container.owner_before(identity);
  if(same&&revision==current->shape_revision){++hits;if(!value)++absent;return value;}
  // Resolve before changing cache: a thrown validation cannot install partial
  // bindings. References survive unordered_map rehash; all shape changes are
  // revised at their only mutator. The current Var owns this container now.
  auto* next=field_value(record,name);
  identity=record.container;address=current;bound_name=name;revision=current->shape_revision;value=next;initialized=true;++rebinds;if(!value)++absent;return value;
 }
};
struct Bindings {std::array<Field,COUNT> fields;};
// Isolated native component oracle. Uses exactly the live private mutators and
// binding, never a second implementation. No Nodes or runtime owner is altered.
EngineVar component_oracle(){
 auto out=EngineVar::dictionary(),rows=::array_empty();bool success=true;int64_t checks=0;
 const auto check=[&](bool result,const char* message){++checks;success=success&&result;auto row=EngineVar::dictionary();::set(row,"success",EngineVar::boolean(result));::set(row,"message",EngineVar::text(message));::method(rows,"append",{row});};
 auto record=Var::dictionary();Field field;
 check(field.read(record,names[DETONATE])==nullptr&&record.container->fields.empty(),"Missing binding does not materialize a key");
 const auto miss_revision=record.container->shape_revision;set(record,names[DETONATE],Var());
 check(record.container->shape_revision>miss_revision&&field.read(record,names[DETONATE])!=nullptr&&field.read(record,names[DETONATE])->nil(),"Absent-to-present NIL insertion invalidates a negative binding");
 const auto present_revision=record.container->shape_revision;set(record,names[DETONATE],Var::integer(37));
 check(record.container->shape_revision==present_revision&&field.read(record,names[DETONATE])->integer()==37,"Existing overwrite keeps shape but current value is fresh");
 const auto* stable=field.read(record,names[DETONATE]);
 for(int index=0;index<256;++index){const auto name=std::string("binding_oracle_")+std::to_string(index);set(record,name.c_str(),Var::integer(index));}
 check(field.read(record,names[DETONATE])==stable&&stable->integer()==37,"Rehash/new fields rebind without invalidating references");
 auto alias=record;set(alias,names[DETONATE],Var::integer(49));
 check(field.read(record,names[DETONATE])->integer()==49,"Aliased overwrite reads the current field");
 auto foreign=Var::dictionary();set(foreign,names[DETONATE],Var::integer(71));
 check(field.read(foreign,names[DETONATE])->integer()==71&&field.read(record,names[DETONATE])->integer()==49,"Foreign owner identity never reuses another location");
 Field missing_slot;auto schema=Var::dictionary();check(missing_slot.read(schema,particle_field::flags.name)==nullptr,"Missing schema field is initially absent");set(schema,particle_field::flags,Var::integer(3));
 check(missing_slot.read(schema,particle_field::flags.name)->integer()==3&&schema.container->slots->present!=0,"Slot allocation/present mutation revises missing bindings");
 Field expired;std::weak_ptr<Container> weak;
 {auto temporary=Var::dictionary();set(temporary,names[DETONATE],Var::integer(88));weak=temporary.container;check(expired.read(temporary,names[DETONATE])->integer()==88,"Temporary location binds");}
 check(weak.expired(),"Binding retains no Container lifetime");
 check(expired.read(foreign,names[DETONATE])->integer()==71,"Expired control-block binding refreshes before dereference");
 auto saturated=Var::dictionary();set(saturated,names[DETONATE],Var::integer(1));Field overflow;overflow.read(saturated,names[DETONATE]);saturated.container->shape_revision=UINT64_MAX;set(saturated,"overflow_new_key",Var::integer(0));set(saturated,names[DETONATE],Var::integer(9));
 check(saturated.container->shape_uncacheable&&overflow.read(saturated,names[DETONATE])->integer()==9&&overflow.uncacheable==1,"Revision overflow fails closed to fresh lookup");
 Name classdb_name("ClassDB");auto classdb_object=global_singleton(classdb_name.data);EngineVar classdb;destroy(classdb.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](classdb.data,&classdb_object);
 auto engine_object=::method(classdb,"instantiate",{EngineVar::text("RefCounted")});const auto id=::method(engine_object,"get_instance_id").integer();
 check(::method(engine_object,"get_reference_count").integer()==1,"Oracle starts with one balanced engine-object reference");
 auto object_record=Var::dictionary();set(object_record,"sentinel",Var::opaque(engine_object));Field object_field;object_field.read(object_record,names[DETONATE]);engine_object=EngineVar();
 check(instance_from_id(static_cast<uint64_t>(id))!=nullptr,"Container is the last native engine-object owner");
 object_record=Var::dictionary();
 check(instance_from_id(static_cast<uint64_t>(id))==nullptr,"Weak field binding does not delay engine-object destruction on replacement");
 check(object_field.read(object_record,names[DETONATE])==nullptr,"Replacement generation has no stale field value");
 ::set(out,"success",EngineVar::boolean(success));::set(out,"checks",EngineVar::integer(checks));::set(out,"cases",rows);return out;
}
}
