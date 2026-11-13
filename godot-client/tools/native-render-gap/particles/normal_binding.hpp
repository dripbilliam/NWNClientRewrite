// Included inside resident after private record and numeric-array helpers.
// The Bridge retains its original hit Var. Only a location is cached here.
namespace normal_binding {
bool requested=false;
struct Counts {uint64_t bridges=0,accesses=0,hits=0,resolutions=0,creates=0,negative_reads=0,uncacheable=0;};
thread_local Counts counts;
void bind(){Name os_name("OS");auto object=global_singleton(os_name.data);if(!object)return;EngineVar os;destroy(os.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](os.data,&object);auto args=::method(os,"get_cmdline_user_args");requested=::method(args,"has",{EngineVar::text("--particle-hit-normal=bound")}).boolean();if(::method(args,"has",{EngineVar::text("--particle-hit-normal=legacy")}).boolean())requested=false;}
struct Location {
 std::weak_ptr<Container> identity;
 Container* address=nullptr;Var* value=nullptr;uint64_t revision=0;
 bool initialized=false;Counts* metrics=nullptr;
 explicit Location(Counts* value_metrics=nullptr):metrics(value_metrics){}
 Var* locate(const Var& record,bool create){
  if(metrics)++metrics->accesses;
  if(record.kind!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Native owner record required");
  auto* current=record.container.get();
  if(current->shape_uncacheable){if(metrics)++metrics->uncacheable;return field_value(record,particle_field::normal,create);}
  const bool same=initialized&&address==current&&!identity.owner_before(record.container)&&!record.container.owner_before(identity);
  if(same&&revision==current->shape_revision&&(value||!create)){if(metrics)++metrics->hits;return value;}
  // Resolve before installing any cache state. A missing read never creates;
  // a later write must still resolve with create=true at that later boundary.
  auto* next=field_value(record,particle_field::normal,create);
  identity=record.container;address=current;revision=current->shape_revision;value=next;initialized=true;
  if(metrics){++metrics->resolutions;if(create)++metrics->creates;}
  return next;
 }
 const Var& read(const Var& record){auto* next=locate(record,false);if(!next){if(metrics)++metrics->negative_reads;throw std::runtime_error("Missing native owner field: normal");}return *next;}
 void write(Var& record,const V3& vector){set_array_value(*locate(record,true),array(vector));}
};
EngineVar oracle(){
 auto out=EngineVar::dictionary(),rows=::array_empty();bool success=true;int64_t checks=0;
 const auto check=[&](bool result,const char* message){++checks;success=success&&result;auto row=EngineVar::dictionary();::set(row,"success",EngineVar::boolean(result));::set(row,"message",EngineVar::text(message));::method(rows,"append",{row});};
 auto hit=Var::dictionary();Counts metrics;Location slot(&metrics);bool missing=false;
 try{slot.read(hit);}catch(const std::runtime_error& e){missing=std::string(e.what())=="Missing native owner field: normal";}
 check(missing&&hit.container->fields.empty()&&!hit.container->slots,"Missing first read throws without materializing a key or schema");
 slot.write(hit,V3{});check(values<3>(slot.read(hit))==V3{}&&hit.container->slots->present!=0,"Later first write creates at its actual boundary after negative read");
 set(hit,particle_field::normal,Var());check(slot.read(hit).nil(),"Present NIL remains distinct from missing and is not value-cached");
 slot.write(hit,V3{1,2,3});auto alias=hit;set(alias,particle_field::normal,array(V3{4,5,6}));check(values<3>(slot.read(hit))==V3{4,5,6},"Existing aliased slot overwrite is read freshly");
 auto alternate=Var::dictionary();set(alternate,particle_field::normal,array(V3{7,8,9}));check(values<3>(slot.read(alternate))==V3{7,8,9}&&values<3>(slot.read(hit))==V3{4,5,6},"Replacement and original hit identities never share stale locations");
 auto mixed=Var::dictionary();set(mixed,particle_field::flags,Var::integer(3));Location mapped;mapped.write(mixed,V3{2,3,4});auto* stable=mapped.locate(mixed,false);check(mixed.container->fields.count("normal")==1,"Normal falls back to the map when another schema owns fixed slots");
 for(int n=0;n<256;++n){const auto name=std::string("normal_location_")+std::to_string(n);set(mixed,name.c_str(),Var::integer(n));}
 check(mapped.locate(mixed,false)==stable&&values<3>(mapped.read(mixed))==V3{2,3,4},"Map rehash/shape changes retain current element identity");
 mixed.container->shape_revision=UINT64_MAX;set(mixed,"saturate",Var::integer(1));mapped.write(mixed,V3{9,8,7});check(mixed.container->shape_uncacheable&&values<3>(mapped.read(mixed))==V3{9,8,7},"Saturated shape revision fails closed to the original lookup");
 auto invalid=Var::integer(4);bool invalid_read=false,invalid_write=false;try{slot.read(invalid);}catch(const std::runtime_error& e){invalid_read=std::string(e.what())=="Native owner record required";}try{slot.write(invalid,V3{});}catch(const std::runtime_error& e){invalid_write=std::string(e.what())=="Native owner record required";}
 check(invalid_read&&invalid_write&&values<3>(slot.read(hit))==V3{4,5,6},"Failed record validation does not install a partial binding");
 Counts foreign_metrics;Location foreign(&foreign_metrics);foreign.read(hit);auto other_control=hit;other_control.container=std::shared_ptr<Container>(hit.container.get(),[](Container*){});const auto before=foreign_metrics.resolutions;foreign.read(other_control);check(foreign_metrics.resolutions==before+1,"Same-address different control-block identity must rebind");
 auto owner_state=Var::dictionary();set(owner_state,particle_field::hit1f0,hit);auto captured=get(owner_state,particle_field::hit1f0);Location captured_slot;captured_slot.read(captured);set(owner_state,particle_field::hit1f0,alternate);captured_slot.write(captured,V3{3,2,1});check(values<3>(get(get(owner_state,particle_field::hit1f0),particle_field::normal))==V3{7,8,9}&&values<3>(get(captured,particle_field::normal))==V3{3,2,1},"Captured hit retains original lifetime/alias semantics after owner hit replacement");
 Name classdb_name("ClassDB");auto classdb_object=global_singleton(classdb_name.data);EngineVar classdb;destroy(classdb.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](classdb.data,&classdb_object);auto engine=::method(classdb,"instantiate",{EngineVar::text("RefCounted")});const auto id=::method(engine,"get_instance_id").integer();
 auto retire=Var::dictionary();set(retire,"sentinel",Var::opaque(engine));engine=EngineVar();Location retired;retired.write(retire,V3{});retire=Var::dictionary();check(instance_from_id(static_cast<uint64_t>(id))==nullptr,"Binding does not retain old Containers or delay engine-object destruction");retired.write(retire,V3{6,5,4});check(values<3>(retired.read(retire))==V3{6,5,4},"Expired location refreshes before any pointer dereference");
 ::set(out,"success",EngineVar::boolean(success));::set(out,"checks",EngineVar::integer(checks));::set(out,"rows",rows);return out;
}
EngineVar inspect(const EngineVar& input){auto out=EngineVar::dictionary();const auto c=counts;::set(out,"enabled",EngineVar::boolean(requested));::set(out,"bridges",EngineVar::integer(static_cast<int64_t>(c.bridges)));::set(out,"accesses",EngineVar::integer(static_cast<int64_t>(c.accesses)));::set(out,"hits",EngineVar::integer(static_cast<int64_t>(c.hits)));::set(out,"resolutions",EngineVar::integer(static_cast<int64_t>(c.resolutions)));::set(out,"creates",EngineVar::integer(static_cast<int64_t>(c.creates)));::set(out,"negative_reads",EngineVar::integer(static_cast<int64_t>(c.negative_reads)));::set(out,"uncacheable",EngineVar::integer(static_cast<int64_t>(c.uncacheable)));::set(out,"scope",EngineVar::text("Calling-thread Bridge-local normal field locations only; values and captured hit lifetime are unchanged. Default OFF."));if(::has(input,"oracle")&&::get(input,"oracle").boolean())::set(out,"oracle",oracle());return out;}
}
