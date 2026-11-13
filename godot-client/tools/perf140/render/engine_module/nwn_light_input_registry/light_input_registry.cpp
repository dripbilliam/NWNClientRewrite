#include "light_input_registry.h"
#include "core/object/class_db.h"
#include "core/os/thread.h"
#include "scene/3d/node_3d.h"
#include <algorithm>
#include <cmath>

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
 entries.erase(found);order.erase(std::remove(order.begin(),order.end(),id),order.end());++membership_generation;
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
  auto [found,inserted]=entries.try_emplace(id);bool published=found->second.published;
  found->second=Entry();found->second.id=id;found->second.source=source;found->second.published=published;
  if(inserted)order.push_back(id);++membership_generation;return inspect();
 }
 if(operation==1){
  if(polling)return failure("Native light input registry poll is reentrant");
  polling=true;Dictionary result=poll(input);polling=false;return result;
 }
 if(operation==2){int64_t id=0;if(!required(input,"id",field,error)||!identity(field,id,error))return failure(error);erase(id);return inspect();}
 if(operation==3)return inspect();
 if(operation==4){for(auto &[id,entry]:entries)entry.published=false;pending_removed.clear();++membership_generation;return inspect();}
 if(operation==8){entries.clear();order.clear();pending_removed.clear();closed=true;++membership_generation;return inspect();}
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
  if(eligible){
   props=node->get(props_name);error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);
   eligible=props.get_type()==Variant::DICTIONARY&&Dictionary(props).size()>0;
   if(eligible){bool enhanced=false;if(!boolean(node->get_meta(enhanced_name,false),enhanced,error))return failure(error);eligible=enhanced;}
   if(eligible){double radius=0;if(!field_number(props,"radius",0,radius,error))return failure(error);error=callback_boundary(id);if(!error.is_empty())return failure(error);eligible=!(radius>=1000);}
  }
  if(!eligible){if(entry.published){removed.append(id);entry.published=false;}continue;}
  const Vector3 position=node->get_global_transform().origin;
  Variant state=node->get(state_name);error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);
  double range=0;if(!field_number(state,"range",0,range,error))return failure(error);
  error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);
  if(!entry.has_row||view_changed||!entry.position_known||entry.position!=position||entry.range!=range){
   entry.in_view=true;for(const Plane &plane:planes){const double distance=double(plane.distance_to(position));if(distance>range){entry.in_view=false;break;}}
   entry.range=range;++tests_now;
  }
  const int64_t owner=entry.source&&ObjectDB::get_instance(ObjectID(uint64_t(entry.source)))?entry.source:0;
  int64_t priority=0;if(!integer(node->get_meta(priority_name,int64_t(0)),priority,error))return failure(error);
  Variant revision_value=node->get(revision_name);error=callback_boundary(id);if(!error.is_empty())return failure(error);
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
 for(int64_t id:tombstones)entries.erase(id);
 if(!tombstones.empty())order.erase(std::remove_if(order.begin(),order.end(),[&](int64_t id){return entries.find(id)==entries.end();}),order.end());
 ++polls;input_rows+=rows_now;reused+=reused_now;view_tests+=tests_now;
 Dictionary out;out[SNAME("rows")]=rows;out[SNAME("removed")]=removed;out[SNAME("retired")]=retired;out[SNAME("reused")]=reused_now;out[SNAME("view_tests")]=tests_now;out[SNAME("polls")]=polls;return out;
}
void NwnBuiltinLightInputRegistry::_bind_methods(){ClassDB::bind_method(D_METHOD("dispatch","operation","input"),&NwnBuiltinLightInputRegistry::dispatch);}
