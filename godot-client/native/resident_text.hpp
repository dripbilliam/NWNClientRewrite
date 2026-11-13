// Included inside resident. This only borrows private string storage; it
// neither borrows EngineVar internals nor changes the engine Variant route.
bool nonempty_text(const Var& value);
namespace resident_text {
bool borrowed=false;
thread_local uint64_t legacy_reads=0,borrowed_reads=0;
bool read_legacy(const Var& value);
bool read_borrowed(const Var& value);
void bind(){
 Name os_name("OS");auto object=global_singleton(os_name.data);if(!object)return;
 EngineVar os;destroy(os.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](os.data,&object);
 auto args=::method(os,"get_cmdline_user_args");
 borrowed=::method(args,"has",{EngineVar::text("--particle-resident-text=borrow")}).boolean();
 if(::method(args,"has",{EngineVar::text("--particle-resident-text=legacy")}).boolean())borrowed=false;
}
EngineVar inspect(){
 auto out=EngineVar::dictionary();
 ::set(out,"borrowed",EngineVar::boolean(borrowed));
 ::set(out,"counter_scope",EngineVar::text("calling-thread"));
 ::set(out,"legacy_reads",EngineVar::integer(static_cast<int64_t>(legacy_reads)));
 ::set(out,"borrowed_reads",EngineVar::integer(static_cast<int64_t>(borrowed_reads)));
 return out;
}
EngineVar component_oracle(){
 struct Restore {uint64_t legacy,borrow;~Restore(){legacy_reads=legacy;borrowed_reads=borrow;}} restore{legacy_reads,borrowed_reads};
 auto out=EngineVar::dictionary(),rows=::array_empty();bool success=true;int64_t checks=0;
 const auto check=[&](bool pass,const char* message){++checks;success=success&&pass;auto row=EngineVar::dictionary();::set(row,"message",EngineVar::text(message));::set(row,"success",EngineVar::boolean(pass));::method(rows,"append",{row});};
 struct Observation {bool value=false;std::string error;};
 const auto observe=[](const Var& value,bool mode){Observation result;try{result.value=mode?read_borrowed(value):read_legacy(value);}catch(const std::exception& error){result.error=error.what();}return result;};
 const auto compare=[&](const Var& value,const char* message){const auto before=observe(value,false),after=observe(value,true);check(before.value==after.value&&before.error==after.error,message);return before;};
 for(const auto* text:{"","x","long private resource name exceeding small string storage","\xc3\xa9"}){
  auto value=Var::text(text);const auto before=value.string;const auto observation=compare(value,"Private string result and error match");
  check(observation.error.empty()&&observation.value==!before.empty()&&value.string==before,"String contents remain current and unchanged");
 }
 auto embedded=Var::text("");embedded.string=std::string("\0",1);check(compare(embedded,"Embedded zero byte preserves resident length semantics").value,"A stored zero byte is still a nonempty private string");
 for(const auto& value:{Var(),Var::boolean(false),Var::integer(0),Var::number(0),Var::dictionary(),array_empty()}){
  const auto result=compare(value,"Invalid resident type has the same error");check(result.error=="Native particle resource name must be String","Invalid types retain the exact STRING error");
 }
 auto current=Var::text("");check(!observe(current,true).value,"Borrow reads current empty value");current.string="changed";check(observe(current,true).value,"Borrow reads a later current overwrite");current.string.clear();check(!observe(current,true).value,"Borrow never caches string contents");
 const auto main_legacy=legacy_reads,main_borrow=borrowed_reads;const bool selected=borrowed;std::array<bool,2> worker_success{};std::array<std::thread,2> workers;
 for(size_t index=0;index<workers.size();++index)workers[index]=std::thread([&,index](){
  try{auto text=Var::text("worker value");bool valid=legacy_reads==0&&borrowed_reads==0;
   for(int n=0;n<16;++n)valid=read_legacy(text)&&read_borrowed(text)&&valid;
   valid=nonempty_text(text)&&valid;
   worker_success[index]=valid&&legacy_reads==static_cast<uint64_t>(16+(selected?0:1))&&borrowed_reads==static_cast<uint64_t>(16+(selected?1:0))&&borrowed==selected;
  }catch(...){worker_success[index]=false;}
 });
 for(auto& worker:workers)worker.join();
 check(worker_success[0]&&worker_success[1],"Distinct worker reads use isolated counters and immutable startup selection");
 check(legacy_reads==main_legacy&&borrowed_reads==main_borrow,"Worker reads do not modify calling-thread diagnostics");
 Name classdb_name("ClassDB");auto classdb_object=global_singleton(classdb_name.data);EngineVar classdb;destroy(classdb.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](classdb.data,&classdb_object);
 auto engine_object=::method(classdb,"instantiate",{EngineVar::text("RefCounted")});const auto id=::method(engine_object,"get_instance_id").integer();
 check(::method(engine_object,"get_reference_count").integer()==1,"Oracle starts with one balanced engine reference");
 auto opaque=Var::opaque(engine_object);engine_object=EngineVar();const auto errors=compare(opaque,"Opaque object STRING errors agree");
 check(!errors.error.empty()&&instance_from_id(static_cast<uint64_t>(id))!=nullptr,"Neither string route destroys the supplied opaque value");
 opaque=Var();check(instance_from_id(static_cast<uint64_t>(id))==nullptr,"No borrowed or copied string state delays opaque-object retirement");
 check(legacy_reads>restore.legacy&&borrowed_reads>restore.borrow,"Both actual string branches are observed");
 ::set(out,"success",EngineVar::boolean(success));::set(out,"checks",EngineVar::integer(checks));::set(out,"cases",rows);return out;
}
}
