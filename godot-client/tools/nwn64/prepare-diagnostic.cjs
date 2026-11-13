'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..'),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const source=JSON.parse(fs.readFileSync(path.join(project,'.cache/native-render-gap/particles/nwn64-hit-coalesce-a/kernel-source-pins.json')));
const out=path.join(project,'.cache/native-render-gap/particles/nwn64-hit-diagnostic-a'),view=path.join(out,'kernel-project');assert(!fs.existsSync(out));fs.mkdirSync(view,{recursive:true});
function one(s,a,b){assert.equal(s.split(a).length-1,1,a.slice(0,60));return s.replace(a,b);}
const pins=source.pins.map(row=>{
 const b=fs.readFileSync(path.join(source.project,row.relative));assert.equal(hash(b),row.sha256);let data=b;
 if(row.relative==='native/particle_compact_bridge.hpp'){
  let text=b.toString();
  text=one(text,'namespace compact_particle {',`namespace compact_particle {
struct HitClearDiagnostic {uint64_t considered=0,accepted=0,bad_record=0,no_slots=0,no_slot=0,not_array=0,aliased=0,not_inline_three=0,generic_items=0,actual_clears=0;std::unordered_map<const Container*,bool> sources,eligible_sources;};
thread_local HitClearDiagnostic hit_clear_diagnostic;`);
  const start=text.indexOf(' bool can_coalesce_hit_clears()const override{'),end=text.indexOf('\n void clear_hit()',start);assert(start>=0&&end>start);
  text=text.slice(0,start)+` bool can_coalesce_hit_clears()const override{
  auto& d=hit_clear_diagnostic;++d.considered;
  if(hit.kind!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||!hit.container){++d.bad_record;return false;}
  d.sources.emplace(hit.container.get(),true);
  if(!hit.container->slots){++d.no_slots;return false;}
  const auto& slots=*hit.container->slots;const auto offset=slots.schema->offsets[static_cast<size_t>(particle_field::normal.index)];
  if(offset<0||static_cast<size_t>(offset)>=slots.values.size()||!(slots.present&(uint64_t{1}<<offset))){++d.no_slot;return false;}
  const auto* normal=&slots.values[static_cast<size_t>(offset)];
  if(normal->kind!=GDEXTENSION_VARIANT_TYPE_ARRAY||!normal->container){++d.not_array;return false;}
  if(normal->container.use_count()!=1){++d.aliased;return false;}
  if(normal->container->number_count!=3){++d.not_inline_three;return false;}
  if(!normal->container->items.empty()){++d.generic_items;return false;}
  ++d.accepted;d.eligible_sources.emplace(hit.container.get(),true);return true;
 }`+text.slice(end);
  text=one(text,'void clear_hit()override{set(hit,particle_field::normal,array(V3{}));}','void clear_hit()override{++hit_clear_diagnostic.actual_clears;set(hit,particle_field::normal,array(V3{}));}');
  data=Buffer.from(text);
 }
 if(row.relative==='native/particle_resident.hpp'){
  let text=b.toString();const anchor='  auto out=EngineVar::dictionary();size_t channel_count=0;for(const auto& clip:clips)channel_count+=clip.second.size();';
  let extra='\n  auto diagnostic=EngineVar::dictionary();const auto& hd=compact_particle::hit_clear_diagnostic;';
  for(const name of ['considered','accepted','bad_record','no_slots','no_slot','not_array','aliased','not_inline_three','generic_items','actual_clears'])extra+='::set(diagnostic,"'+name+'",EngineVar::integer(static_cast<int64_t>(hd.'+name+')));';
  extra+='::set(diagnostic,"sources",EngineVar::integer(static_cast<int64_t>(hd.sources.size())));::set(diagnostic,"eligible_sources",EngineVar::integer(static_cast<int64_t>(hd.eligible_sources.size())));::set(out,"hit_clear_proof",diagnostic);';
  data=Buffer.from(one(text,anchor,anchor+extra));
 }
 const target=path.join(view,row.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,data,{flag:'wx'});return {relative:row.relative,sha256:hash(data),bytes:data.length};
});
fs.writeFileSync(path.join(out,'kernel-source-pins.json'),JSON.stringify({version:1,issue:'NWN-64',project:view,pins,scope:'Diagnostic only: exact candidate guard split into counters, no new behavior, op10extra snapshot; never selected or throughput measured.'},null,2)+'\n',{flag:'wx'});
let test=fs.readFileSync(path.join(project,'tests/nwn64_busy_test.gd'),'utf8');
test=one(test,'\tvar timing: Array=[];','\tvar actual_phase_packets:=0\n\tvar timing: Array=[];');
test=one(test,'results.append(result)','results.append(result);actual_phase_packets+=int(result.has("phases"))');
test=one(test,'\tseed_owner.providers.clear();owners.clear();callbacks.clear()','\tvar diag: Dictionary=owners[0].call("dispatch",10,{},{}).get("hit_clear_proof",{})\n\tseed_owner.providers.clear();owners.clear();callbacks.clear()');
test=one(test,'"benchmark":quantiles(timing)','"actual_profile_phase_packets":actual_phase_packets,"hit_clear_proof":diag,"benchmark":quantiles(timing)');
const file=path.join(project,'tests/nwn64_busy_diagnostic_test.gd');fs.writeFileSync(file,test,{flag:'wx'});
console.log(JSON.stringify({stage:out,sourcePinsSha256:hash(fs.readFileSync(path.join(out,'kernel-source-pins.json'))),testSha256:hash(Buffer.from(test))}));
