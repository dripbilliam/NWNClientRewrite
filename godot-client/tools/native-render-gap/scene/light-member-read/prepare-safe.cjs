'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../../../..'),label=process.argv[2]??'light-member-read-b',directory=path.join(project,'.cache/native-render-gap/scene',label),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
if(!/^[a-z0-9-]+$/.test(label)||fs.existsSync(directory))throw Error('Fresh safety proposal label required');
const baseFile=path.join(project,'.cache/native-render-gap/scene/light-member-read-a/manifest.json'),base=JSON.parse(fs.readFileSync(baseFile));
for(const item of base.files)if(sha(fs.readFileSync(item.file))!==item.sha256)throw Error('A proposal changed');
const cppBefore=fs.readFileSync(base.files[0].file),hBefore=fs.readFileSync(base.files[1].file);let cpp=cppBefore.toString(),header=hBefore.toString();
function change(text,from,to){if(text.split(from).length!==2)throw Error('Lifetime seam changed '+from.slice(0,120));return text.replace(from,()=>to);}
function c(from,to){cpp=change(cpp,from,to);}function h(from,to){header=change(header,from,to);}
c('#include <cmath>','#include <cmath>\n#include <optional>');
c('bool light_member_indices_requested() {','bool light_input_lifetime_requested() {\n static const bool enabled=OS::get_singleton() && OS::get_singleton()->get_cmdline_user_args().find("--light-input-lifetime=guarded")!=nullptr;\n return enabled;\n}\nbool light_member_indices_requested() {');
c(' if(found->second.published)pending_removed.push_back(id);\n entries.erase(found);order.erase(std::remove(order.begin(),order.end(),id),order.end());++membership_generation;',
' std::optional<Dictionary> retained_row;\n if(light_input_lifetime_requested())retained_row.emplace(found->second.row);\n if(found->second.published)pending_removed.push_back(id);\n entries.erase(found);order.erase(std::remove(order.begin(),order.end(),id),order.end());++membership_generation;\n // Retired payload callbacks run after map/order state is stable.\n retained_row.reset();');
c('  auto [found,inserted]=entries.try_emplace(id);bool published=found->second.published;','  auto [found,inserted]=entries.try_emplace(id);bool published=found->second.published;\n  std::optional<Dictionary> retained_row;if(light_input_lifetime_requested()&&!inserted)retained_row.emplace(found->second.row);');
c('  if(inserted)order.push_back(id);++membership_generation;return inspect();','  if(inserted)order.push_back(id);++membership_generation;retained_row.reset();return inspect();');
c('out[SNAME("plain_member_index_active")]=light_member_indices_requested()&&plain_segment_requested;','out[SNAME("plain_member_index_active")]=light_member_indices_requested()&&plain_segment_requested&&light_input_lifetime_requested();out[SNAME("lifetime_guard_requested")]=light_input_lifetime_requested();out[SNAME("lifetime_staged_rows")]=lifetime_staged_rows;out[SNAME("lifetime_post_checks")]=lifetime_post_checks;out[SNAME("lifetime_detached_releases")]=lifetime_detached_releases;');
c(' if(operation==8){plain_writer.unref();plain_source=String();entries.clear();order.clear();pending_removed.clear();closed=true;++membership_generation;return inspect();}',
' if(operation==8){\n  if(light_input_lifetime_requested()){\n   // Never run payload finalizers inside the active unordered_map clear.\n   std::unordered_map<int64_t,Entry> detached;detached.swap(entries);\n   order.clear();pending_removed.clear();closed=true;++membership_generation;\n   plain_writer.unref();plain_source=String();detached.clear();return inspect();\n  }\n  plain_writer.unref();plain_source=String();entries.clear();order.clear();pending_removed.clear();closed=true;++membership_generation;return inspect();\n }');
c(' const bool member_indices_enabled=light_member_indices_requested()&&plain_segment_requested;',' const bool lifetime_guarded=light_input_lifetime_requested();\n const bool member_indices_enabled=light_member_indices_requested()&&plain_segment_requested&&lifetime_guarded;');
c(' auto scratch_boundary=[&](const Variant &value) { if(member_indices_enabled&&plain_segment_proven&&light_member_scratch_boundary(value)){++plain_member_scratch_barriers;end_plain_segment();} };',
' auto scratch_boundary=[&](const Variant &value) { if(lifetime_guarded&&plain_segment_proven&&light_member_scratch_boundary(value)){if(member_indices_enabled)++plain_member_scratch_barriers;end_plain_segment();} };');
c('  const int64_t id=order[member];Entry &entry=entries.at(id);Node3D *node=node_from_id(id);bool eligible=node!=nullptr;Variant props;GDScriptInstance *plain=nullptr;',
`  const int64_t id=order[member];
  // Copy construction owns the Dictionary container without copying its
  // children or allocating an empty Dictionary. No map Entry survives callbacks.
  std::optional<Entry> staged_entry;
  if(lifetime_guarded){staged_entry.emplace(entries.at(id));++lifetime_staged_rows;}
  Entry &entry=lifetime_guarded?*staged_entry:entries.at(id);
  Node3D *node=node_from_id(id);bool eligible=node!=nullptr;Variant props;GDScriptInstance *plain=nullptr;
  auto guarded_callback=[&]()->String {++lifetime_post_checks;return callback_boundary(id);};
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
  };`);
c('   if(eligible){double radius=0;if(!field_number(props,"radius",0,radius,error))return failure(error);if(!plain){error=callback_boundary(id);if(!error.is_empty())return failure(error);}eligible=!(radius>=1000);}',
`   if(eligible){
    const bool scratch=lifetime_guarded&&light_member_scratch_boundary(props);
    double radius=0;const bool numeric_ok=field_number(props,"radius",0,radius,error);
    if(scratch){
     const String callback_error=guarded_callback();if(!callback_error.is_empty())return failure(callback_error);
     node=node_from_id(id);plain=nullptr; // Next reflected read selects current ScriptInstance.
    }
    if(!numeric_ok)return failure(error);
    if(!plain&&!scratch){error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);}
    eligible=!(radius>=1000);
   }`);
c('  if(!eligible){if(entry.published){removed.append(id);entry.published=false;}continue;}',
'  if(!eligible){if(entry.published){removed.append(id);entry.published=false;}error=commit_entry();if(!error.is_empty())return failure(error);continue;}');
c('  double range=0;if(!field_number(state,"range",0,range,error))return failure(error);\n  if(!plain){error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);}',
`  const bool state_scratch=lifetime_guarded&&light_member_scratch_boundary(state);
  double range=0;const bool range_ok=field_number(state,"range",0,range,error);
  if(state_scratch){
   const String callback_error=guarded_callback();if(!callback_error.is_empty())return failure(callback_error);
   node=node_from_id(id);plain=nullptr;
  }
  if(!range_ok)return failure(error);
  if(!plain&&!state_scratch){error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);}`);
c('   row[SNAME("in_view")]=entry.in_view;entry.row=row;entry.has_row=true;',
'   row[SNAME("in_view")]=entry.in_view;\n   if(lifetime_guarded){error=guarded_callback();if(!error.is_empty())return failure(error);node=node_from_id(id);plain=nullptr;}\n   entry.row=row;entry.has_row=true;');
for(const [from,to]of [
 ['entry.row[SNAME("override")]=priority;entry.priority=priority;','entry.row[SNAME("override")]=priority;if(lifetime_guarded){error=guarded_callback();if(!error.is_empty())return failure(error);}entry.priority=priority;'],
 ['entry.row[SNAME("position")]=native_point(position);entry.position=position;','entry.row[SNAME("position")]=native_point(position);if(lifetime_guarded){error=guarded_callback();if(!error.is_empty())return failure(error);}entry.position=position;'],
 ['entry.row[SNAME("owner")]=owner;entry.owner=owner;','entry.row[SNAME("owner")]=owner;if(lifetime_guarded){error=guarded_callback();if(!error.is_empty())return failure(error);}entry.owner=owner;'],
 ['entry.row[SNAME("in_view")]=entry.in_view;changed=true;','entry.row[SNAME("in_view")]=entry.in_view;if(lifetime_guarded){error=guarded_callback();if(!error.is_empty())return failure(error);}changed=true;']
])c(from,to);
c('  if(member_indices_enabled&&plain_segment_proven&&entry.row.is_read_only()){++plain_member_scratch_barriers;end_plain_segment();}\n  bool prior_view=false;if(!boolean(entry.row["in_view"],prior_view,error))return failure(error);',
`  const bool row_scratch=lifetime_guarded&&entry.row.is_read_only();
  if(row_scratch){if(member_indices_enabled&&plain_segment_proven)++plain_member_scratch_barriers;end_plain_segment();}
  bool prior_view=false;const bool view_ok=boolean(entry.row["in_view"],prior_view,error);
  if(row_scratch){const String callback_error=guarded_callback();if(!callback_error.is_empty())return failure(callback_error);}
  if(!view_ok)return failure(error);`);
c('  entry.published=true;if(changed){rows.append(entry.row);++rows_now;}else ++reused_now;',
'  entry.published=true;error=commit_entry();if(!error.is_empty())return failure(error);if(changed){rows.append(entry.row);++rows_now;}else ++reused_now;');
c(' for(int64_t id:tombstones)entries.erase(id);',
` for(int64_t id:tombstones){
  if(!lifetime_guarded){entries.erase(id);continue;}
  std::optional<Entry> detached;
  {auto current=entries.find(id);if(current!=entries.end()){detached.emplace(current->second);entries.erase(current);}}
  // The expected retired Node need not exist; only registry mutation is invalid.
  detached.reset();
  if(closed)return failure("Native light input registry is closed");
  if(membership_generation!=generation)return failure("Native light input registry membership changed during property read");
 }`);
h(' int64_t plain_member_index_reads=0,plain_member_index_proofs=0,plain_member_scratch_barriers=0;',
' int64_t plain_member_index_reads=0,plain_member_index_proofs=0,plain_member_scratch_barriers=0;\n int64_t lifetime_staged_rows=0,lifetime_post_checks=0,lifetime_detached_releases=0;');
const dSource=fs.readFileSync(path.join(project,'.cache/native-render-gap/scene/light-dictionary-read-a/engine-module/light_input_registry.cpp'),'utf8'),dStart=dSource.indexOf('bool field_number('),dEnd=dSource.indexOf('bool dynamic_size(',dStart);if(!cpp.includes(dSource.slice(dStart,dEnd)))throw Error('Accepted D helper changed');
fs.mkdirSync(path.join(directory,'engine-module'),{recursive:true});const files=[];
for(const [index,name,text,bytes]of [[0,'light_input_registry.cpp',cpp,cppBefore],[1,'light_input_registry.h',header,hBefore]]){const file=path.join(directory,'engine-module',name);fs.writeFileSync(file,text,{flag:'wx'});files.push({relative:base.files[index].relative,original:base.files[index].file,originalSha256:sha(bytes),file,sha256:sha(Buffer.from(text))});}
const manifest={version:1,created:new Date().toISOString(),directory,base:{file:baseFile,sha256:sha(fs.readFileSync(baseFile)),preserved:true},files,flags:{correctnessControl:'--light-input-lifetime=guarded',candidate:'--light-member-read=indices',prerequisites:['--light-input-read=typed','--light-input-proof=segments','--light-input-lifetime=guarded']},defaultOff:true,acceptedDictionaryHelperUnchanged:true,scope:'Private source-only B correctness control plus independent indexed-reader candidate. Guarded mode owns a per-row Entry copy, detaches payloads before active map mutation, validates immediately after readonly scratch/row writes/releases, and uses freshly resolved Node/current reflected ScriptInstance for the rest of a callback-affected row. No equivalence claim for V9 destructive reentry, which was unsafe.',requiredTests:['Guarded control vs guarded+indices same-engine actual values/outputs/callback order','Readonly radius/range scratch finalizers: reorder, set_script, free Node, close, erase/rebind','Readonly published-row in_view scratch finalizers before further Entry touch','Published row replacement finalizers close/erase/free/replace Script','Reentrant erase/close/rebind payload destruction outside active map','Retired Node tombstone finalizers mutate registry safely','Existing D/canonical/segment/legacy benign regressions','Default-off V9 functional behavior retained','Actual cold guard staging/release/use counters','Guard overhead separate from indexed ROI, matched same-engine performance only'],runtimeExecuted:false};
fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({directory,files:files.map(({relative,sha256})=>({relative,sha256})),runtimeExecuted:false}));
