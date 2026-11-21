// Read-only extraction of existing observations; this runs no new benchmark.
import fs from 'node:fs';
import path from 'node:path';
const [input,output]=process.argv.slice(2);
const rows=fs.readFileSync(input,'utf8').replace(/^\uFEFF/,'').trim().split(/\r?\n/).map(JSON.parse);
const mean=values=>values.reduce((a,b)=>a+b,0)/values.length;
const result={source:path.resolve(input),observations:rows.length,limitations:[
 'Rolling 240-frame windows overlap. These are diagnostic means of window means, not independent samples.',
 'Culled/prepared counts describe observation frames. No per-culled-emitter phase timings were recorded.',
 'The uniform-work estimate is a scenario, not a measured removable-cost fraction. Callback/controller/pose costs differ by emitter.',
 'Per-emitter detailed profiling adds clock-read overhead. Profile-off benefit requires later matched tests.'
],areas:[]};
const names=['presentation','eligibility_clock','eligibility_checks','source_checks','clock_boundary','other_loop','controls','pose','admission','simulation','geometry'];
for(const generation of [...new Set(rows.filter(r=>r.ready).map(r=>r.generation))].sort()){
 const selected=rows.filter(r=>r.ready&&r.generation===generation&&r.frame_profile?.frames>=240);
 if(!selected.length)continue;
 const metrics_ms={};
 for(const name of [...names.map(n=>(n==='presentation'?'particle_frame_native_':'particle_native_')+n+'_ms'),'callback_rigs','actor_animation','actor_attachments','actor_skin']){
  const values=selected.filter(r=>r.frame_profile.metrics[name]).map(r=>r.frame_profile.metrics[name].mean);
  if(values.length)metrics_ms[name]=mean(values);
 }
 const counts=selected.map(r=>{const n=r.shared_particles.native;return{at:r.at,registered:n.registered,prepared:n.prepared,culled:n.culled,fraction:n.prepared?n.culled/n.prepared:null}});
 const fractions=counts.map(r=>r.fraction).filter(v=>v!==null);
 const pre=['eligibility_clock','controls','pose'].reduce((sum,k)=>sum+(metrics_ms['particle_native_'+k+'_ms']??0),0);
 result.areas.push({generation,windows:selected.length,metrics_ms,count_means:Object.fromEntries(['registered','prepared','culled'].map(k=>[k,mean(counts.map(r=>r[k]))])),culled_fraction_mean:mean(fractions),culled_fraction_range:[Math.min(...fractions),Math.max(...fractions)],pre_admission_parent_plus_controls_pose_ms:pre,uniform_work_scenario_culled_pre_admission_ms:pre*mean(fractions),counts});
}
fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');
for(const area of result.areas){const {counts,...brief}=area;console.log(JSON.stringify(brief));}
console.log('Retained particle metric names: '+Object.keys(rows.at(-1).frame_profile?.metrics??{}).filter(k=>k.includes('particle_frame_native_')).join(','));
