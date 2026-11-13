#include "light_input_registry.h"
#include "core/object/class_db.h"
#include "core/os/thread.h"
#include "core/os/os.h"
#include "core/config/engine.h"
#include "scene/3d/node_3d.h"
#include "core/variant/variant_internal.h"
#include <algorithm>
#include <cmath>
#include <optional>

namespace {
// NWN_LIGHT_MEMBER_INDICES_E. Poll-local layout only; never member values.
bool light_input_lifetime_requested() {
 static const bool enabled=OS::get_singleton() && OS::get_singleton()->get_cmdline_user_args().find("--light-input-lifetime=guarded")!=nullptr;
 return enabled;
}
bool light_member_indices_requested() {
 static const bool enabled=OS::get_singleton() && OS::get_singleton()->get_cmdline_user_args().find("--light-member-read=indices")!=nullptr;
 return enabled;
}
struct LightMemberIndexSegment {
 int values[3]={-1,-1,-1};
 void invalidate() { for(int &value:values)value=-1; }
 ~LightMemberIndexSegment() { invalidate(); }
};
bool light_member_scratch_boundary(const Variant &value) {
 // A nonconst read-only Dictionary read may destroy its prior scratch Object.
 // Inspect only the built-in container header; no child value is borrowed.
 return value.get_type()==Variant::DICTIONARY && VariantInternal::get_dictionary(&value)->is_read_only();
}

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
// NWN_LIGHT_DICTIONARY_SINGLE_READ_A. Main-thread polling only; no values cached.
struct LightDictionaryReadStats {
 uint64_t reads=0,missing=0,read_only_fallbacks=0,typed_key_fallbacks=0;
};
thread_local LightDictionaryReadStats light_dictionary_read_stats;
bool light_dictionary_single_requested() {
 static const bool enabled=OS::get_singleton() && OS::get_singleton()->get_cmdline_user_args().find("--light-dictionary-read=single")!=nullptr;
 return enabled;
}

bool field_number(const Variant &input,const StringName &key,double fallback,double &out,String &error) {
 if(light_dictionary_single_requested() && input.get_type()==Variant::DICTIONARY){
  const Dictionary dictionary=input;
  const bool read_only=dictionary.is_read_only(),typed_key=dictionary.is_typed_key();
  if(!read_only && !typed_key){
   ++light_dictionary_read_stats.reads;
   const Variant *found=dictionary.getptr(key);
   if(!found){++light_dictionary_read_stats.missing;out=fallback;return true;}
   // Retain the original Variant copy/refcount hooks. No borrowed value or
   // source pointer is used after this copy; numeric/bool/error rules stay old.
   Variant value=*found;
   if(value.get_type()==Variant::BOOL){out=bool(value)?1.0:0.0;return true;}
   return numeric(value,out,error);
  }
  // has() and getptr() use different typed-key validation diagnostics. Also,
  // old nonconst operator[] writes read-only scratch (possibly destroying a
  // RefCounted). Preserve both old paths after this local Dictionary expires.
  if(read_only)++light_dictionary_read_stats.read_only_fallbacks;
  if(typed_key)++light_dictionary_read_stats.typed_key_fallbacks;
 }
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
 std::optional<Dictionary> retained_row;
 if(light_input_lifetime_requested())retained_row.emplace(found->second.row);
 if(found->second.published)pending_removed.push_back(id);
 entries.erase(found);order.erase(std::remove(order.begin(),order.end(),id),order.end());++membership_generation;
 // Retired payload callbacks run after map/order state is stable.
 retained_row.reset();
}
NwnBuiltinLightInputRegistry::NwnBuiltinLightInputRegistry() {
 for (const String &argument : OS::get_singleton()->get_cmdline_user_args()) {
  if (argument == "--light-input-read=typed") plain_requested = true;
  if (argument == "--light-input-proof=segments") plain_segment_requested = true;
 }
}
bool NwnBuiltinLightInputRegistry::plain_schema_valid(int *member_indices) {
 if (plain_writer.is_null() || plain_writer->get_base_script().is_valid() || plain_writer->get_script_instance() != nullptr) return false;
 const auto &members = plain_writer->debug_get_member_indices();
 const StringName names[] = {props_name, state_name, revision_name};
 const Variant::Type types[] = {Variant::DICTIONARY, Variant::DICTIONARY, Variant::INT};
 int current_indices[3]={-1,-1,-1};
 for (int index = 0; index < 3; ++index) {
  const auto *member = members.getptr(names[index]);
  if (!member || member->getter || member->property_info.type != types[index]) return false;
  if(member_indices){if(member->index<0)return false;current_indices[index]=member->index;}
 }
 // Commit only after all three current compiled members passed the old proof.
 if(member_indices){for(int index=0;index<3;++index)member_indices[index]=current_indices[index];++plain_member_index_proofs;}
 return true;
}
Dictionary NwnBuiltinLightInputRegistry::enroll_plain_reader(const Variant &input) {
 Dictionary result; result[SNAME("accepted")] = false;
 if (closed) return failure("Native light input registry is closed");
 if (polling) return failure("Native light typed reader enrollment during polling");
 String error; Variant script_value, hash_value;
 if (!required(input, "script", script_value, error) || !required(input, "sha256", hash_value, error)) return failure(error);
 if (script_value.get_type() != Variant::OBJECT || hash_value.get_type() != Variant::STRING) return result;
 GDScript *script = Object::cast_to<GDScript>(script_value);
 if (!script || script->get_script_instance() != nullptr || script->get_base_script().is_valid()) return result;
 const String source = script->get_source_code();
 if (source.is_empty() || source.sha256_text() != String(hash_value)) return result;
 Ref<GDScript> previous_writer = plain_writer; const String previous_source = plain_source;
 plain_writer = Ref<GDScript>(script); plain_source = source;
 if (!plain_schema_valid()) { plain_writer = previous_writer; plain_source = previous_source; return result; }
 ++plain_claims; result[SNAME("accepted")] = true; return result;
}
GDScriptInstance *NwnBuiltinLightInputRegistry::plain_reader(Node3D *node,int *member_indices) {
 if (!plain_requested || plain_writer.is_null() || Engine::get_singleton()->is_editor_hint()) return nullptr;
 // Public native Script identity query; unknown/subclass facades never have
 // their authored properties queried here and keep the original poll body.
 if (Object::cast_to<GDScript>(node->get_script()) != plain_writer.ptr()) return nullptr;
 const String source = plain_writer->get_source_code();
 if (source.ptr() != plain_source.ptr() || source.length() != plain_source.length()) { ++plain_source_rejections; return nullptr; }
 // Revalidate the compiled schema too: source can be restored without reload
 // after an earlier compiled getter edit. Text/COW identity alone is not proof.
 ++plain_schema_checks;
 if (!plain_schema_valid(member_indices)) { ++plain_schema_rejections; return nullptr; }
 ScriptInstance *instance = node->get_script_instance();
 if (!instance || instance->is_placeholder() || instance->get_language() != GDScriptLanguage::get_singleton()) return nullptr;
 return static_cast<GDScriptInstance *>(instance);
}

GDScriptInstance *NwnBuiltinLightInputRegistry::plain_reader_segment(Node3D *node, bool &proven,int *member_indices) {
 auto invalidate = [&]() { if(member_indices)for(int index=0;index<3;++index)member_indices[index]=-1; if (proven) ++plain_segment_invalidations; proven = false; };
 if (!plain_requested || plain_writer.is_null() || Engine::get_singleton()->is_editor_hint()) { invalidate(); return nullptr; }
 // Every node still supplies its actual current Script and ScriptInstance.
 // Unknown/subclass/placeholder/language paths close the pure segment before
 // the original reflected getter is invoked. No instance/value is retained.
 if (Object::cast_to<GDScript>(node->get_script()) != plain_writer.ptr()) { invalidate(); return nullptr; }
 ScriptInstance *instance = node->get_script_instance();
 if (!instance || instance->is_placeholder() || instance->get_language() != GDScriptLanguage::get_singleton()) { invalidate(); return nullptr; }
 GDScriptInstance *reader = static_cast<GDScriptInstance *>(instance);
 if (reader->get_script().ptr() != plain_writer.ptr()) { invalidate(); return nullptr; }
 if (proven) { ++plain_segment_reuses; return reader; }
 // Reuse the exact B source/COW and current compiled-schema proof, including
 // restored text with stale compiled getters. No cross-poll proof survives.
 reader = plain_reader(node,member_indices);
 if (!reader) { invalidate(); return nullptr; }
 proven = true; ++plain_segment_proofs; return reader;
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
  std::optional<Dictionary> retained_row;if(light_input_lifetime_requested()&&!inserted)retained_row.emplace(found->second.row);
  found->second=Entry();found->second.id=id;found->second.source=source;found->second.published=published;
  if(inserted)order.push_back(id);++membership_generation;retained_row.reset();return inspect();
 }
 if(operation==1){
  if(polling)return failure("Native light input registry poll is reentrant");
  polling=true;Dictionary result=poll(input);polling=false;return result;
 }
 if(operation==2){int64_t id=0;if(!required(input,"id",field,error)||!identity(field,id,error))return failure(error);erase(id);return inspect();}
 if(operation==3)return inspect();
 if(operation==6 && plain_requested)return enroll_plain_reader(input);
 if(operation==9 && plain_requested){Dictionary out;out[SNAME("plain_member_index_requested")]=light_member_indices_requested();out[SNAME("plain_member_index_active")]=light_member_indices_requested()&&plain_segment_requested&&light_input_lifetime_requested();out[SNAME("lifetime_guard_requested")]=light_input_lifetime_requested();out[SNAME("unchanged_fast_rows_total")]=unchanged_fast_rows_total;out[SNAME("lifetime_staged_rows")]=lifetime_staged_rows;out[SNAME("lifetime_post_checks")]=lifetime_post_checks;out[SNAME("lifetime_detached_releases")]=lifetime_detached_releases;out[SNAME("plain_member_index_reads")]=plain_member_index_reads;out[SNAME("plain_member_index_proofs")]=plain_member_index_proofs;out[SNAME("plain_member_scratch_barriers")]=plain_member_scratch_barriers;out[SNAME("dictionary_single_requested")]=light_dictionary_single_requested();out[SNAME("dictionary_single_reads")]=int64_t(light_dictionary_read_stats.reads);out[SNAME("dictionary_single_missing")]=int64_t(light_dictionary_read_stats.missing);out[SNAME("dictionary_single_read_only_fallbacks")]=int64_t(light_dictionary_read_stats.read_only_fallbacks);out[SNAME("dictionary_single_typed_key_fallbacks")]=int64_t(light_dictionary_read_stats.typed_key_fallbacks);out[SNAME("plain_claims")]=plain_claims;out[SNAME("plain_rows")]=plain_rows;out[SNAME("plain_field_reads")]=plain_field_reads;out[SNAME("plain_schema_checks")]=plain_schema_checks;out[SNAME("plain_source_rejections")]=plain_source_rejections;out[SNAME("plain_schema_rejections")]=plain_schema_rejections;out[SNAME("plain_segment_proofs")]=plain_segment_proofs;out[SNAME("plain_segment_reuses")]=plain_segment_reuses;out[SNAME("plain_segment_invalidations")]=plain_segment_invalidations;return out;}
 if(operation==4){for(auto &[id,entry]:entries)entry.published=false;pending_removed.clear();++membership_generation;return inspect();}
 if(operation==8){
  if(light_input_lifetime_requested()){
   // Never run payload finalizers inside the active unordered_map clear.
   std::unordered_map<int64_t,Entry> detached;detached.swap(entries);
   order.clear();pending_removed.clear();closed=true;++membership_generation;
   plain_writer.unref();plain_source=String();detached.clear();return inspect();
  }
  plain_writer.unref();plain_source=String();entries.clear();order.clear();pending_removed.clear();closed=true;++membership_generation;return inspect();
 }
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
 int64_t reused_now=0,tests_now=0,rows_now=0,unchanged_fast_rows=0;
 // Membership may change through an adversarial script property getter. The
 // old extension has no safe reference contract there. Detect it immediately
 // after each opaque getter; never keep a borrowed pointer/reference alive
 // across an undetected close/erase. Ordinary row/getter order is unchanged.
 const uint64_t generation=membership_generation;
 bool plain_segment_proven=false;
 const bool lifetime_guarded=light_input_lifetime_requested();
 const bool member_indices_enabled=light_member_indices_requested()&&plain_segment_requested&&lifetime_guarded;
 const bool reuse_unchanged=plain_requested&&plain_segment_requested&&lifetime_guarded&&light_dictionary_single_requested()&&
   OS::get_singleton()->get_cmdline_user_args().find("--light-input-unchanged=reference")==nullptr;
 LightMemberIndexSegment member_indices; // destructor also clears on every error/return.
 LightMemberIndexSegment unchanged_indices;
 auto end_plain_segment=[&]() { unchanged_indices.invalidate();if(member_indices_enabled)member_indices.invalidate(); if(plain_segment_proven){plain_segment_proven=false;++plain_segment_invalidations;} };
 auto scratch_boundary=[&](const Variant &value) { if(lifetime_guarded&&plain_segment_proven&&light_member_scratch_boundary(value)){if(member_indices_enabled)++plain_member_scratch_barriers;end_plain_segment();} };
 auto callback_boundary=[&](int64_t id)->String {
  // Opaque authored access ends the callback-free proof segment, including
  // callbacks that keep registry membership unchanged but reload a Script.
  end_plain_segment();
  if(closed)return "Native light input registry is closed";
  if(membership_generation!=generation)return "Native light input registry membership changed during property read";
  if(!node_from_id(id))return "Native light input registry light retired during property read";
  return String();
 };
 // Canonical reads have no authored getters. If all current inputs and the
 // published container still match, retain the existing Entry rather than
 // copying its Dictionary ownership and assigning it back for every frame.
 // Read-only/typed containers and changed rows keep the full lifetime path.
 const Variant radius_key=SNAME("radius"),range_key=SNAME("range"),override_key=SNAME("override"),in_view_key=SNAME("in_view");
 auto unchanged_number=[&](const Dictionary *dictionary,const Variant &key,double fallback,double &value)->bool {
  ++light_dictionary_read_stats.reads;const Variant *field=dictionary->getptr(key);
  if(!field){++light_dictionary_read_stats.missing;value=fallback;return true;}
  // Only immediate numeric values are borrowed, with no calls or releases of
  // authored objects. Unsupported values keep the complete original error path.
  if(field->get_type()==Variant::FLOAT){value=double(*field);return true;}
  if(field->get_type()==Variant::INT){value=double(int64_t(*field));return true;}
  if(field->get_type()==Variant::BOOL){value=bool(*field)?1.0:0.0;return true;}
  return false;
 };
 auto unchanged=[&](int64_t id,const Entry &entry)->bool {
  if(!entry.published||!entry.has_row||!entry.position_known||entry.row.is_read_only()||entry.row.is_typed_key())return false;
  Node3D *node=node_from_id(id);
  if(!node||!node->is_inside_tree())return false;
  Node3D *parent=Object::cast_to<Node3D>(node->get_parent());
  if(parent&&!parent->is_visible_in_tree())return false;
  GDScriptInstance *reader=plain_reader_segment(node,plain_segment_proven,member_indices_enabled?member_indices.values:nullptr);
  if(!reader)return false;
  Variant properties,state,revision;
  if(member_indices_enabled){
   properties=reader->debug_get_member_by_index(member_indices.values[0]);
   state=reader->debug_get_member_by_index(member_indices.values[1]);
   revision=reader->debug_get_member_by_index(member_indices.values[2]);plain_member_index_reads+=3;
  }else{
   // The existing segment proof certified this exact compiled schema and
   // current instance. Resolve its three plain member locations once within
   // the callback-free segment, never across a poll or opaque boundary.
   if(unchanged_indices.values[0]<0){
    const auto &members=plain_writer->debug_get_member_indices();
    const StringName names[]={props_name,state_name,revision_name};
    for(int index=0;index<3;++index){const auto *value=members.getptr(names[index]);if(!value||value->getter||value->index<0){unchanged_indices.invalidate();return false;}unchanged_indices.values[index]=value->index;}
   }
   properties=reader->debug_get_member_by_index(unchanged_indices.values[0]);
   state=reader->debug_get_member_by_index(unchanged_indices.values[1]);
   revision=reader->debug_get_member_by_index(unchanged_indices.values[2]);
  }
  plain_field_reads+=3;
  if(properties.get_type()!=Variant::DICTIONARY||state.get_type()!=Variant::DICTIONARY||revision.get_type()!=Variant::INT)return false;
  const Dictionary *props=VariantInternal::get_dictionary(&properties),*values=VariantInternal::get_dictionary(&state);
  if(props->is_empty()||props->is_read_only()||props->is_typed_key()||values->is_read_only()||values->is_typed_key())return false;
  String unused;bool enhanced=false;double radius=0,range=0;int64_t priority=0;
  if(!boolean(node->get_meta(enhanced_name,false),enhanced,unused)||!enhanced||
    !unchanged_number(props,radius_key,0,radius)||radius>=1000||
    !unchanged_number(values,range_key,0,range)||range!=entry.range||
    !integer(node->get_meta(priority_name,int64_t(0)),priority,unused)||priority!=entry.priority||
    int64_t(revision)!=entry.revision||node->get_global_transform().origin!=entry.position)return false;
  const int64_t owner=entry.source&&ObjectDB::get_instance(ObjectID(uint64_t(entry.source)))?entry.source:0;
  if(owner!=entry.owner||!entry.row.getptr(override_key))return false;
  const Variant *previous_view=entry.row.getptr(in_view_key);bool prior_view=false;
  if(!previous_view||!boolean(*previous_view,prior_view,unused)||prior_view!=entry.in_view)return false;
  if(view_changed){bool in_view=true;for(const Plane &plane:planes){if(double(plane.distance_to(entry.position))>range){in_view=false;break;}}
   if(in_view!=entry.in_view)return false;++tests_now;
  }
  ++plain_rows;return true;
 };
 const size_t member_count=order.size();
 for(size_t member=0;member<member_count;++member){
  const int64_t id=order[member];
  if(reuse_unchanged&&unchanged(id,entries.at(id))){++reused_now;++unchanged_fast_rows;++unchanged_fast_rows_total;continue;}
  // Copy construction owns the Dictionary container without copying its
  // children or allocating an empty Dictionary. No map Entry survives callbacks.
  std::optional<Entry> staged_entry;
  if(lifetime_guarded){staged_entry.emplace(entries.at(id));++lifetime_staged_rows;}
  Entry &entry=lifetime_guarded?*staged_entry:entries.at(id);
  Node3D *node=node_from_id(id);bool eligible=node!=nullptr;Variant props,state;GDScriptInstance *plain=nullptr;
  bool may_release_authored=false;
  auto guarded_callback=[&]()->String {may_release_authored=true;++lifetime_post_checks;return callback_boundary(id);};
  auto release_row_locals=[&]()->String {
   if(!lifetime_guarded||!may_release_authored)return String();
   // A pure canonical row still has Dict/Dict owners in its current instance
   // and a committed row owner in the map. Opaque boundaries can detach them.
   // Release all detached locals outside any map/Entry/Node access, then check
   // before the next order lookup. The Entry reference is not used afterward.
   end_plain_segment();props=Variant();state=Variant();staged_entry.reset();
   ++lifetime_post_checks;return callback_boundary(id);
  };
  auto commit_entry=[&]()->String {
   if(!lifetime_guarded)return String();
   if(closed)return "Native light input registry is closed";
   if(membership_generation!=generation)return "Native light input registry membership changed during property read";
   std::optional<Dictionary> detached_row;
   {
    auto current=entries.find(id);
    if(current==entries.end())return "Native light input registry membership changed during property read";
    if(current->second.row.id()!=entry.row.id())detached_row.emplace(current->second.row);
    // Both old and new containers have owners while map storage is replaced.
    current->second=entry;
   }
   if(detached_row){
    end_plain_segment();++lifetime_detached_releases;
    detached_row.reset(); // Outside map storage/iterator lifetime.
    return guarded_callback();
   }
   return String();
  };
  if(!eligible){retired.append(id);tombstones.push_back(id);++dead;}
  if(eligible){Node3D *parent=Object::cast_to<Node3D>(node->get_parent());eligible=node->is_inside_tree()&&(!parent||parent->is_visible_in_tree());}
  if(eligible){
   plain=plain_segment_requested?plain_reader_segment(node,plain_segment_proven,member_indices_enabled?member_indices.values:nullptr):plain_reader(node);
   if(plain){++plain_rows;if(member_indices_enabled&&plain_segment_proven){props=plain->debug_get_member_by_index(member_indices.values[0]);++plain_member_index_reads;}else plain->get(props_name,props);++plain_field_reads;}
   else{if(lifetime_guarded)may_release_authored=true;props=node->get(props_name);error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);}
   scratch_boundary(props);
   eligible=props.get_type()==Variant::DICTIONARY&&Dictionary(props).size()>0;
   if(eligible){bool enhanced=false;if(!boolean(node->get_meta(enhanced_name,false),enhanced,error))return failure(error);eligible=enhanced;}
   if(eligible){
    const bool scratch=lifetime_guarded&&light_member_scratch_boundary(props);
    double radius=0;const bool numeric_ok=field_number(props,"radius",0,radius,error);
    if(scratch){
     const String callback_error=guarded_callback();if(!callback_error.is_empty())return failure(callback_error);
     node=node_from_id(id);plain=nullptr; // Next reflected read selects current ScriptInstance.
    }
    if(!numeric_ok)return failure(error);
    if(!plain&&!scratch){error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);}
    eligible=!(radius>=1000);
   }
  }
  if(!eligible){if(entry.published){removed.append(id);entry.published=false;}error=commit_entry();if(!error.is_empty())return failure(error);error=release_row_locals();if(!error.is_empty())return failure(error);continue;}
  const Vector3 position=node->get_global_transform().origin;
  if(plain){if(member_indices_enabled&&plain_segment_proven){state=plain->debug_get_member_by_index(member_indices.values[1]);++plain_member_index_reads;}else plain->get(state_name,state);++plain_field_reads;}
  else{if(lifetime_guarded)may_release_authored=true;state=node->get(state_name);error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);}
  scratch_boundary(state);
  const bool state_scratch=lifetime_guarded&&light_member_scratch_boundary(state);
  double range=0;const bool range_ok=field_number(state,"range",0,range,error);
  if(state_scratch){
   const String callback_error=guarded_callback();if(!callback_error.is_empty())return failure(callback_error);
   node=node_from_id(id);plain=nullptr;
  }
  if(!range_ok)return failure(error);
  if(!plain&&!state_scratch){error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);}
  if(!entry.has_row||view_changed||!entry.position_known||entry.position!=position||entry.range!=range){
   entry.in_view=true;for(const Plane &plane:planes){const double distance=double(plane.distance_to(position));if(distance>range){entry.in_view=false;break;}}
   entry.range=range;++tests_now;
  }
  const int64_t owner=entry.source&&ObjectDB::get_instance(ObjectID(uint64_t(entry.source)))?entry.source:0;
  int64_t priority=0;if(!integer(node->get_meta(priority_name,int64_t(0)),priority,error))return failure(error);
  Variant revision_value;
  if(plain){if(member_indices_enabled&&plain_segment_proven){revision_value=plain->debug_get_member_by_index(member_indices.values[2]);++plain_member_index_reads;}else plain->get(revision_name,revision_value);++plain_field_reads;}
  else{if(lifetime_guarded)may_release_authored=true;revision_value=node->get(revision_name);error=callback_boundary(id);if(!error.is_empty())return failure(error);}
  int64_t revision=0;if(!integer(revision_value,revision,error))return failure(error);bool changed=!entry.published;
  if(!entry.has_row||entry.revision!=revision){
   end_plain_segment(); // Replacement can destroy authored RefCounted values.
   Dictionary row;row[SNAME("id")]=id;row[SNAME("owner")]=owner;row[SNAME("position")]=native_point(position);Dictionary properties=props;
   Array default_color;default_color.append(int64_t(0));default_color.append(int64_t(0));default_color.append(int64_t(0));
   row[SNAME("color")]=properties.get("color",default_color);
   const char *destinations[]={"radius","multiplier","priority","dynamic","affect","fading"};
   const char *sources[]={"radius","multiplier","lightpriority","isdynamic","affectdynamic","fadinglight"};
   const int64_t defaults[]={0,1,4,1,1,1};
   for(size_t index=0;index<6;++index)row[StringName(destinations[index])]=properties.get(sources[index],defaults[index]);
   row[SNAME("in_view")]=entry.in_view;
   if(lifetime_guarded){error=guarded_callback();if(!error.is_empty())return failure(error);node=node_from_id(id);plain=nullptr;}
   entry.row=row;entry.has_row=true;
   entry.revision=revision;entry.position=position;entry.position_known=true;entry.owner=owner;changed=true;
  }
  if(!entry.row.has("override")||entry.priority!=priority){end_plain_segment();entry.row[SNAME("override")]=priority;if(lifetime_guarded){error=guarded_callback();if(!error.is_empty())return failure(error);}entry.priority=priority;changed=true;}
  if(entry.position!=position){end_plain_segment();entry.row[SNAME("position")]=native_point(position);if(lifetime_guarded){error=guarded_callback();if(!error.is_empty())return failure(error);}entry.position=position;changed=true;}
  if(entry.owner!=owner){end_plain_segment();entry.row[SNAME("owner")]=owner;if(lifetime_guarded){error=guarded_callback();if(!error.is_empty())return failure(error);}entry.owner=owner;changed=true;}
  const bool row_scratch=lifetime_guarded&&entry.row.is_read_only();
  if(row_scratch){if(member_indices_enabled&&plain_segment_proven)++plain_member_scratch_barriers;end_plain_segment();}
  bool prior_view=false;const bool view_ok=boolean(entry.row["in_view"],prior_view,error);
  if(row_scratch){const String callback_error=guarded_callback();if(!callback_error.is_empty())return failure(callback_error);}
  if(!view_ok)return failure(error);
  if(prior_view!=entry.in_view){end_plain_segment();entry.row[SNAME("in_view")]=entry.in_view;if(lifetime_guarded){error=guarded_callback();if(!error.is_empty())return failure(error);}changed=true;}
  entry.published=true;error=commit_entry();if(!error.is_empty())return failure(error);if(changed){rows.append(entry.row);++rows_now;}else ++reused_now;
  error=release_row_locals();if(!error.is_empty())return failure(error);
 }
 if(member_indices_enabled)end_plain_segment();
 for(int64_t id:tombstones){
  if(!lifetime_guarded){entries.erase(id);continue;}
  std::optional<Entry> detached;
  {auto current=entries.find(id);if(current!=entries.end()){detached.emplace(current->second);entries.erase(current);}}
  // The expected retired Node need not exist; only registry mutation is invalid.
  detached.reset();
  if(closed)return failure("Native light input registry is closed");
  if(membership_generation!=generation)return failure("Native light input registry membership changed during property read");
 }
 if(!tombstones.empty())order.erase(std::remove_if(order.begin(),order.end(),[&](int64_t id){return entries.find(id)==entries.end();}),order.end());
 ++polls;input_rows+=rows_now;reused+=reused_now;view_tests+=tests_now;
 Dictionary out;out[SNAME("rows")]=rows;out[SNAME("removed")]=removed;out[SNAME("retired")]=retired;out[SNAME("reused")]=reused_now;out[SNAME("view_tests")]=tests_now;out[SNAME("polls")]=polls;out[SNAME("unchanged_fast_rows")]=unchanged_fast_rows;return out;
}
void NwnBuiltinLightInputRegistry::_bind_methods(){ClassDB::bind_method(D_METHOD("dispatch","operation","input"),&NwnBuiltinLightInputRegistry::dispatch);}
