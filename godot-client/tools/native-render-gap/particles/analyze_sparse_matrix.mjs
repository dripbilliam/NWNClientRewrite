import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const output=path.join(project,'.cache/native-render-gap/particles/sparse-matrix-v5-a.json');
if(fs.existsSync(output))throw Error('Previous evidence retained');
const mean=values=>values.length?values.reduce((sum,value)=>sum+value,0)/values.length:0;
const stats=records=>{const values=records.map(row=>row.wall_ms).sort((a,b)=>a-b);return {n:values.length,mean_ms:mean(values),p50_ms:values[Math.floor((values.length-1)*.5)]??0,p95_ms:values[Math.floor((values.length-1)*.95)]??0,max_ms:values.at(-1)??0};};
const rows=[];
for(const variant of ['control','setup','boundary','childless']){
 const file=path.join(project,'reports','render-gap-sample-'+variant+'-v5-a-a.native.json'),bytes=fs.readFileSync(file),document=JSON.parse(bytes);
 const sample=document.render_gap.particle_sample,survey=document.render_gap.admission_survey;
 const retained=sample.records.filter(row=>row.success),full=retained.filter(row=>row.registered===1829&&row.prepared===1829);
 const categories={};
 for(const row of survey.rows){
  const key=(row.chunk?'chunk':'sprite')+'/'+String(row.source_flags);
  const group=categories[key]??= {members:0,active:0,birth_rate_zero:0,empty_active:0,current_checked:0,current_culled:0,native_reject:0,conservative_reject:0,policy_comparable:0,padding_extra_admitted:0,unchecked_native_reject:0,unchecked_native_reject_active:0,childless_proofs:{}};
  ++group.members;group.active+=Number(row.active??0);group.birth_rate_zero+=row.birth_rate===0?1:0;group.empty_active+=row.active===0?1:0;
  group.current_checked+=row.current_checked?1:0;group.current_culled+=row.current_culled?1:0;
  const proof=String(row.current_chunk_proof??0);group.childless_proofs[proof]=(group.childless_proofs[proof]??0)+1;
  if(row.policy_comparable){++group.policy_comparable;group.native_reject+=row.hypothetical_native_current_reject?1:0;group.conservative_reject+=row.conservative_recomputed_reject?1:0;
   group.padding_extra_admitted+=row.hypothetical_native_current_reject&&!row.conservative_recomputed_reject?1:0;
   if(row.hypothetical_native_current_reject&&!row.current_checked){++group.unchecked_native_reject;group.unchecked_native_reject_active+=Number(row.active??0);}
  }
 }
 const {records,...sampleCounters}=sample,{rows:surveyRows,...surveyCounters}=survey;
 rows.push({variant,file,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),success:document.success,performanceAccepted:document.performance_accepted,sampleCounters,all_successful_samples:stats(retained),full1829_samples:stats(full),full_registered_samples:stats(retained.filter(row=>row.registered===1829)),first_call:retained[0]?.call,last_call:retained.at(-1)?.call,surveyCounters,categories});
}
const receipt={scope:'Retained profile-OFF native particle sparse wall samples and cold policy comparisons across sequential variants; no new runtime, no causal FPS claim',rows,limitations:['This is one sequential four-case matrix, not a randomized repeated causal timing experiment.','Full-1829 filtering removes early loading population differences but does not match every simulation state or scheduling event.','Cold policy recalculation uses post-simulation retained state; original cached radius/BSP/model clock gates are not reconstructed.','Node getters, clocks, RNG and callbacks are not skipped by the setup/direct boundary proposals.']};
fs.writeFileSync(output,JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify(rows.map(row=>({variant:row.variant,all:row.all_successful_samples,full:row.full1829_samples,counters:row.sampleCounters,survey:row.surveyCounters,categories:row.categories})),null,2));
