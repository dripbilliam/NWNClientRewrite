'use strict';
// Read JSON only; never exports Tracy or launches native/Godot processes.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const [input,output,minCallArg='1']=process.argv.slice(2);assert(input&&output,'Usage: node tools/nwn64/review-preparation.cjs report.json fresh-output.json [min-call]');
const minCall=Number(minCallArg);assert(Number.isInteger(minCall)&&minCall>=1);
assert(!fs.existsSync(output),'Preserve prior analysis');
const bytes=fs.readFileSync(input),report=JSON.parse(bytes.toString().replace(/^\uFEFF/,''));
assert(report.success,'Do not summarize a failing correctness fixture as acceptance');
const sampler=report.samplers?.[1];assert(sampler?.preparation_subphases===true,'Private sampler engagement is required');
const all=sampler.records.filter(row=>row.preparation_audit);
assert(all.length,'No private preparation records');
const selected=all.filter(row=>row.success&&Number(row.call)>=minCall);
assert(selected.length,'No successful records within requested call coverage');
function stats(values){const sorted=values.map(Number).sort((a,b)=>a-b);assert(sorted.length&&sorted.every(Number.isFinite));return {samples:sorted.length,mean:sorted.reduce((a,b)=>a+b,0)/sorted.length,p50:sorted[Math.ceil(sorted.length*0.5)-1],p95:sorted[Math.ceil(sorted.length*0.95)-1],max:sorted.at(-1)};}
function columns(key){const names=new Set(selected.flatMap(row=>Object.keys(row.preparation_audit[key])));return Object.fromEntries([...names].map(name=>[name,stats(selected.map(row=>row.preparation_audit[key][name]||0))]));}
const phases=columns('phases_ms'),counts=columns('counts');
const disjoint=['eligibility','source_exists','readiness','clock','channels','patch_detonate','emitter_pose','source_pose','source_publish','context','admission','simulation_total'];
const phaseSum=selected.map(row=>disjoint.reduce((sum,name)=>sum+Number(row.preparation_audit.phases_ms[name]||0),0));
const advance=selected.map(row=>Number(row.entry_advance_ms||0));
const safe=selected.map(row=>Number(row.preparation_audit.callback_free_existing_ms));
const noBirth=selected.map(row=>Number(row.preparation_audit.conservative_no_birth_existing_ms));
const groupable=selected.map(row=>Number(row.preparation_audit.groupable_no_birth_existing_ms));
const result={version:1,source:path.resolve(input),sourceSha256:crypto.createHash('sha256').update(bytes).digest('hex'),correctness:{checks:report.checks,success:report.success,packet_digest:report.packet_digest,state_digest:report.state_digest,state:report.state},
 coverage:{retained:all.length,selected:selected.length,minCallRequested:minCall,firstCall:selected[0].call,lastCall:selected.at(-1).call,populations:{registered:stats(selected.map(row=>row.registered)),prepared:stats(selected.map(row=>row.prepared)),culled:stats(selected.map(row=>row.culled)),active_after:stats(selected.map(row=>row.active))}},
 diagnostic_phases_ms:phases,diagnostic_counts:counts,diagnostic_disjoint_advance_subphase_sum_ms:stats(phaseSum),diagnostic_coarse_advance_ms:stats(advance),
 diagnostic_advance_residual_ms:stats(advance.map((value,index)=>value-phaseSum[index])),
 upper_bounds_only_ms:{all_callback_free_existing:stats(safe),conservative_no_birth_existing:stats(noBirth),groupable_no_birth_existing:stats(groupable),impossible_perfect_four_way_groupable_saving:stats(groupable.map(value=>value*0.75)),all_source_pose:phases.source_pose,all_channels:phases.channels},
 caveats:[
  'Selected-frame probes add clock pairs, bookkeeping and bounded map work; absolute wall time is instrumented and not normal throughput.',
  'simulation_total contains existing_prefix and birth_tail. These nested costs are not summed together.',
  'Entry residual includes original loop work plus diagnostic accounting outside subphase timers. It is not a pure original implementation cost.',
  'Classification counts are conservative opportunity census, not worker engagement. Four-way saving is an impossible ideal before copies/dispatch/join/commit.',
  'Repeated IDs do not establish conversion misses; existing per-owner static conversion hits already avoid math.',
  'Constant-hit fractions do not establish constant-publication time. Dynamic and constant channel cost per hit differs.',
  report.scope,
 ]};
fs.mkdirSync(path.dirname(path.resolve(output)),{recursive:true});fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
process.stdout.write(JSON.stringify({output:path.resolve(output),selected:selected.length,firstCall:result.coverage.firstCall,lastCall:result.coverage.lastCall,diagnosticAdvanceMs:result.diagnostic_coarse_advance_ms.mean,channelsMs:phases.channels.mean,sourcePoseMs:phases.source_pose.mean,groupableExistingMs:result.upper_bounds_only_ms.groupable_no_birth_existing.mean})+'\n');
