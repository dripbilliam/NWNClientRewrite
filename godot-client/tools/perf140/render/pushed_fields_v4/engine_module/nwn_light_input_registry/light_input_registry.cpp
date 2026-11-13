#include "light_input_registry.h"
#include "core/object/class_db.h"
#include "core/os/thread.h"
#include "scene/3d/node_3d.h"
#include <algorithm>
#include <cmath>
#include <limits>

namespace {
Dictionary failure(const String &text) { Dictionary out;out[SNAME("error")]=text;return out; }
bool numeric(const Variant &value,double &out,String &error) {
 if(value.get_type()==Variant::FLOAT){out=double(value);return true;}
 if(value.get_type()==Variant::INT){out=double(int64_t(value));return true;}
 error="Native particle value must be numeric";return false;
}
bool integer(const Variant &value,int64_t &out,String &error) {
 if(value.get_type()!=Variant::INT){error="Native particle value must be integer";return false;}
 out=int64_t(value);return true;
}
bool boolean(const Variant &value,bool &out,String &error) {
 if(value.get_type()==Variant::BOOL){out=bool(value);return true;}
 double number=0;if(!numeric(value,number,error))return false;out=number!=0;return true;
}
bool required(const Variant &input,const StringName &key,Variant &out,String &error) {
 if(input.get_type()!=Variant::DICTIONARY){error="Native particle dictionary required";return false;}
 Dictionary dictionary=input;
 if(!dictionary.has(key)){error="Missing native particle field: "+String(key);return false;}
 out=dictionary[key];return true;
}
bool identity(const Variant &input,int64_t &out,String &error) {
 double number=0;if(!numeric(input,number,error))return false;
 if(!std::isfinite(number)||std::trunc(number)!=number||std::abs(number)>9007199254740991.0){error="Native light identity is invalid";return false;}
 out=int64_t(number);return true;
}
// Fast ordinary Dictionary path, same dynamic has/size fallback/error contract
// for invalid or custom facade values. These are public Variant APIs.
bool has_field(const Variant &input,const StringName &key,bool &out,String &error) {
 if(input.get_type()==Variant::DICTIONARY){out=Dictionary(input).has(key);return true;}
 Variant argument=key;const Variant *arguments[]={&argument};Callable::CallError call_error;
 Variant copy=input;Variant result;copy.callp("has",arguments,1,result,call_error);
 if(call_error.error!=Callable::CallError::CALL_OK){error="Native particle method/provider failed: has";return false;}
 return boolean(result,out,error);
}
bool field_number(const Variant &input,const StringName &key,double fallback,double &out,String &error) {
 bool present=false;if(!has_field(input,key,present,error))return false;
 if(!present){out=fallback;return true;}
 if(input.get_type()!=Variant::DICTIONARY){error="Native particle dictionary required";return false;}
 Variant value=Dictionary(input)[key];
 if(value.get_type()==Variant::BOOL){out=bool(value)?1.0:0.0;return true;}
 return numeric(value,out,error);
}
bool dynamic_size(const Variant &input,int64_t &out,String &error) {
 if(input.get_type()==Variant::ARRAY){out=Array(input).size();return true;}
 if(input.get_type()==Variant::DICTIONARY){out=Dictionary(input).size();return true;}
 Variant copy=input;Callable::CallError call_error;Variant result;copy.callp("size",nullptr,0,result,call_error);
 if(call_error.error!=Callable::CallError::CALL_OK){error="Native particle array size failed";return false;}
 return integer(result,out,error);
}
Node3D *node_from_id(int64_t id) {return Object::cast_to<Node3D>(ObjectDB::get_instance(ObjectID(uint64_t(id))));}
Array native_point(const Vector3 &position) {
 Array out;out.resize(3);out[0]=double(position.x);out[1]=double(-position.z);out[2]=double(position.y);return out;
}
}

Dictionary NwnBuiltinLightInputRegistry::inspect() const {
 Dictionary out;out[SNAME("members")]=int64_t(entries.size());out[SNAME("polls")]=polls;out[SNAME("view_tests")]=view_tests;out[SNAME("input_rows")]=input_rows;out[SNAME("reused")]=reused;out[SNAME("dead")]=dead;out[SNAME("closed")]=closed;return out;
}
void NwnBuiltinLightInputRegistry::erase(int64_t id) {
 auto found=entries.find(id);if(found==entries.end())return;
 if(found->second.published)pending_removed.push_back(id);
 if(found->second.pushed)--cached_members;
 entries.erase(found);order.erase(std::remove(order.begin(),order.end(),id),order.end());++membership_generation;
}
bool NwnBuiltinLightInputRegistry::publication_writer_valid(Entry &entry,Node3D *node) {
 if(entry.writer.is_null())return false;
 // Public C++ getters cannot invoke a replacement script's custom `_get`.
 // Enrollment accepts exact source-bearing GDScript only, not a subtype facade.
 if(Object::cast_to<Script>(node->get_script())!=entry.writer.ptr()||entry.writer->get_source_code()!=entry.writer_source){
  if(entry.pushed)--cached_members;entry.pushed=false;entry.writer.unref();entry.writer_source=String();entry.pushed_properties=Dictionary();entry.pushed_state=Dictionary();++script_revocations;return false;
 }
 // Script identity/source alone misses detach/reattach of that SAME Resource.
 // This declared scalar is reset by a fresh canonical script instance. It is
 // one explicit capability lookup, not a claim of zero reflected work.
 ++capability_reads;const Variant token=node->get(SNAME("_native_input_token"));
 if(token.get_type()!=Variant::INT||int64_t(token)!=entry.token){
  if(entry.pushed)--cached_members;entry.pushed=false;entry.writer.unref();entry.writer_source=String();entry.pushed_properties=Dictionary();entry.pushed_state=Dictionary();++binding_revocations;return false;
 }
 return true;
}
Dictionary NwnBuiltinLightInputRegistry::dispatch(const Variant &operation_value,const Variant &input) {
 // Read-only Node getters use main-thread state. A built-in caller from another
 // thread receives an explicit error; no synthetic row or stale cache is used.
 if(!Thread::is_main_thread())return failure("Native light input registry requires main thread");
 Ref<NwnBuiltinLightInputRegistry> keep_alive(this);
 String error;Variant field;int64_t operation=0;
 if(!integer(operation_value,operation,error))return failure(error);
 if(operation==0){
  if(closed)return failure("Native light input registry is closed");
  int64_t id=0,source=0;
  if(!required(input,"id",field,error)||!identity(field,id,error)||!required(input,"source",field,error)||!identity(field,source,error))return failure(error);
  if(registration_serial==std::numeric_limits<int64_t>::max())return failure("Native light registration token exhausted");
  auto [found,inserted]=entries.try_emplace(id);bool published=found->second.published;
  if(found->second.pushed)--cached_members;
  found->second=Entry();found->second.id=id;found->second.source=source;found->second.published=published;
  found->second.token=++registration_serial;
  if(inserted)order.push_back(id);++membership_generation;return inspect();
 }
 if(operation==1){
  if(polling)return failure("Native light input registry poll is reentrant");
  polling=true;Dictionary result=poll(input);polling=false;return result;
 }
 if(operation==2){int64_t id=0;if(!required(input,"id",field,error)||!identity(field,id,error))return failure(error);erase(id);return inspect();}
 if(operation==3)return inspect();
 if(operation==4){for(auto &[id,entry]:entries)entry.published=false;pending_removed.clear();++membership_generation;return inspect();}
 if(operation==6){
  if(closed)return failure("Native light input registry is closed");
  int64_t id=0;if(!required(input,"id",field,error)||!identity(field,id,error))return failure(error);
  auto found=entries.find(id);Dictionary result;result[SNAME("accepted")]=false;result[SNAME("token")]=int64_t(0);
  if(found==entries.end())return result;
  Variant writer_value,sha_value;if(!required(input,"writer",writer_value,error)||!required(input,"source_sha256",sha_value,error))return failure(error);
  if(sha_value.get_type()!=Variant::STRING)return failure("Native light writer source hash must be String");
  if(writer_value.get_type()!=Variant::OBJECT)return failure("Native light writer must be a Script");
  Ref<Script> writer(Object::cast_to<Script>(writer_value.get_validated_object()));Node3D *node=node_from_id(id);
  if(!node||node->get_class_name()!=SNAME("OmniLight3D")||writer.is_null()||writer->get_class_name()!=SNAME("GDScript")||Object::cast_to<Script>(node->get_script())!=writer.ptr())return result;
  const String source=writer->get_source_code();if(source.is_empty()||source.sha256_text()!=String(sha_value))return result;
  if(registration_serial==std::numeric_limits<int64_t>::max())return failure("Native light registration token exhausted");
  Entry &entry=found->second;if(entry.pushed)--cached_members;entry.pushed=false;entry.token=++registration_serial;entry.publication=-1;entry.writer=writer;entry.writer_source=source;++claims;
  result[SNAME("accepted")]=true;result[SNAME("token")]=entry.token;return result;
 }
 if(operation==5||operation==7){
  if(closed)return failure("Native light input registry is closed");
  int64_t id=0,token=0;if(!required(input,"id",field,error)||!identity(field,id,error)||!required(input,"token",field,error)||!integer(field,token,error))return failure(error);
  auto found=entries.find(id);if(found==entries.end()||token<=0||found->second.token!=token){++stale_packets;return Dictionary();}
  Entry &entry=found->second;
  if(operation==7){if(entry.pushed)--cached_members;entry.pushed=false;++revocations;return Dictionary();}
  Node3D *node=node_from_id(id);if(!node||!publication_writer_valid(entry,node))return Dictionary();
  int64_t publication=0,revision=0;Variant properties,state;
  if(!required(input,"publication",field,error)||!integer(field,publication,error)||!required(input,"revision",field,error)||!integer(field,revision,error)||!required(input,"properties",properties,error)||!required(input,"state",state,error))return failure(error);
  if(publication<=entry.publication){++stale_packets;return Dictionary();}
  if(properties.get_type()!=Variant::DICTIONARY||state.get_type()!=Variant::DICTIONARY)return failure("Native pushed light inputs require owner dictionaries");
  entry.publication=publication;entry.pushed_revision=revision;entry.pushed_properties=properties;entry.pushed_state=state;if(!entry.pushed)++cached_members;entry.pushed=true;++publications;return Dictionary();
 }
 if(operation==9){
  Dictionary result;result[SNAME("cached_members")]=cached_members;result[SNAME("claims")]=claims;result[SNAME("publications")]=publications;result[SNAME("revocations")]=revocations;result[SNAME("stale_packets")]=stale_packets;result[SNAME("script_revocations")]=script_revocations;result[SNAME("binding_revocations")]=binding_revocations;result[SNAME("field_cache_hits")]=field_cache_hits;result[SNAME("reflected_field_reads")]=reflected_field_reads;result[SNAME("capability_reads")]=capability_reads;return result;
 }
 if(operation==8){entries.clear();order.clear();pending_removed.clear();cached_members=0;closed=true;++membership_generation;return inspect();}
 return failure("Unknown native light input registry operation");
}
Dictionary NwnBuiltinLightInputRegistry::poll(const Variant &input) {
 if(closed)return failure("Native light input registry is closed");
 String error;Variant field;bool view_changed=false;
 if(!required(input,"view_changed",field,error)||!boolean(field,view_changed,error)||!required(input,"planes",field,error))return failure(error);
 int64_t count=0;if(!dynamic_size(field,count,error))return failure(error);
 if(count!=0&&count!=6)return failure("Native light registry requires zero or six camera planes");
 std::vector<Plane> planes;
 if(count){
  if(field.get_type()!=Variant::ARRAY)return failure("Native particle array required");
  Array values=field;
  for(int64_t index=0;index<count;++index){if(values[index].get_type()!=Variant::PLANE)return failure("Native light registry camera is not a Plane array");planes.push_back(Plane(values[index]));}
 }
 Array rows,removed,retired;for(int64_t id:pending_removed)removed.append(id);pending_removed.clear();std::vector<int64_t> tombstones;
 int64_t reused_now=0,tests_now=0,rows_now=0;
 // Membership may change through an adversarial script property getter. The
 // old extension has no safe reference contract there. Detect it immediately
 // after each opaque getter; never keep a borrowed pointer/reference alive
 // across an undetected close/erase. Ordinary row/getter order is unchanged.
 const uint64_t generation=membership_generation;
 auto callback_boundary=[&](int64_t id)->String {
  if(closed)return "Native light input registry is closed";
  if(membership_generation!=generation)return "Native light input registry membership changed during property read";
  if(!node_from_id(id))return "Native light input registry light retired during property read";
  return String();
 };
 const size_t member_count=order.size();
 for(size_t member=0;member<member_count;++member){
  const int64_t id=order[member];Entry &entry=entries.at(id);Node3D *node=node_from_id(id);bool eligible=node!=nullptr;Variant props;
  if(!eligible){retired.append(id);tombstones.push_back(id);++dead;}
  if(eligible){Node3D *parent=Object::cast_to<Node3D>(node->get_parent());eligible=node->is_inside_tree()&&(!parent||parent->is_visible_in_tree());}
  const bool pushed=eligible&&entry.pushed&&publication_writer_valid(entry,node);
  if(eligible){
   if(pushed){props=entry.pushed_properties;++field_cache_hits;}else{props=node->get(props_name);++reflected_field_reads;error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);}
   eligible=props.get_type()==Variant::DICTIONARY&&Dictionary(props).size()>0;
   if(eligible){bool enhanced=false;if(!boolean(node->get_meta(enhanced_name,false),enhanced,error))return failure(error);eligible=enhanced;}
   if(eligible){double radius=0;if(!field_number(props,"radius",0,radius,error))return failure(error);error=callback_boundary(id);if(!error.is_empty())return failure(error);eligible=!(radius>=1000);}
  }
  if(!eligible){if(entry.published){removed.append(id);entry.published=false;}continue;}
  const Vector3 position=node->get_global_transform().origin;
  Variant state;if(pushed){state=entry.pushed_state;++field_cache_hits;}else{state=node->get(state_name);++reflected_field_reads;error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);}
  double range=0;if(!field_number(state,"range",0,range,error))return failure(error);
  error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);
  if(!entry.has_row||view_changed||!entry.position_known||entry.position!=position||entry.range!=range){
   entry.in_view=true;for(const Plane &plane:planes){const double distance=double(plane.distance_to(position));if(distance>range){entry.in_view=false;break;}}
   entry.range=range;++tests_now;
  }
  const int64_t owner=entry.source&&ObjectDB::get_instance(ObjectID(uint64_t(entry.source)))?entry.source:0;
  int64_t priority=0;if(!integer(node->get_meta(priority_name,int64_t(0)),priority,error))return failure(error);
  Variant revision_value;if(pushed){revision_value=entry.pushed_revision;++field_cache_hits;}else{revision_value=node->get(revision_name);++reflected_field_reads;error=callback_boundary(id);if(!error.is_empty())return failure(error);}
  int64_t revision=0;if(!integer(revision_value,revision,error))return failure(error);bool changed=!entry.published;
  if(!entry.has_row||entry.revision!=revision){
   Dictionary row;row[SNAME("id")]=id;row[SNAME("owner")]=owner;row[SNAME("position")]=native_point(position);Dictionary properties=props;
   Array default_color;default_color.append(int64_t(0));default_color.append(int64_t(0));default_color.append(int64_t(0));
   row[SNAME("color")]=properties.get("color",default_color);
   const char *destinations[]={"radius","multiplier","priority","dynamic","affect","fading"};
   const char *sources[]={"radius","multiplier","lightpriority","isdynamic","affectdynamic","fadinglight"};
   const int64_t defaults[]={0,1,4,1,1,1};
   for(size_t index=0;index<6;++index)row[StringName(destinations[index])]=properties.get(sources[index],defaults[index]);
   row[SNAME("in_view")]=entry.in_view;entry.row=row;entry.has_row=true;
   entry.revision=revision;entry.position=position;entry.position_known=true;entry.owner=owner;changed=true;
  }
  if(!entry.row.has("override")||entry.priority!=priority){entry.row[SNAME("override")]=priority;entry.priority=priority;changed=true;}
  if(entry.position!=position){entry.row[SNAME("position")]=native_point(position);entry.position=position;changed=true;}
  if(entry.owner!=owner){entry.row[SNAME("owner")]=owner;entry.owner=owner;changed=true;}
  bool prior_view=false;if(!boolean(entry.row["in_view"],prior_view,error))return failure(error);
  if(prior_view!=entry.in_view){entry.row[SNAME("in_view")]=entry.in_view;changed=true;}
  entry.published=true;if(changed){rows.append(entry.row);++rows_now;}else ++reused_now;
 }
 for(int64_t id:tombstones){const auto found=entries.find(id);if(found!=entries.end()&&found->second.pushed)--cached_members;entries.erase(id);}
 if(!tombstones.empty())order.erase(std::remove_if(order.begin(),order.end(),[&](int64_t id){return entries.find(id)==entries.end();}),order.end());
 ++polls;input_rows+=rows_now;reused+=reused_now;view_tests+=tests_now;
 Dictionary out;out[SNAME("rows")]=rows;out[SNAME("removed")]=removed;out[SNAME("retired")]=retired;out[SNAME("reused")]=reused_now;out[SNAME("view_tests")]=tests_now;out[SNAME("polls")]=polls;return out;
}
void NwnBuiltinLightInputRegistry::_bind_methods(){ClassDB::bind_method(D_METHOD("dispatch","operation","input"),&NwnBuiltinLightInputRegistry::dispatch);}
