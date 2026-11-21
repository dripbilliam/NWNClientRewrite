import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const directory=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const source=path.join(directory,'replay-adapter-v16.cjs');
const output=path.join(directory,'replay-adapter-v17.cjs');
if(fs.existsSync(output))throw Error('Existing V17 retained');
const original=fs.readFileSync(source);let code=original.toString();
const replace=(a,b)=>{if(code.split(a).length!==2)throw Error('V16 adapter seam differs: '+a.slice(0,90));code=code.replace(a,b);};
replace("'--light-dictionary-read=single'].includes(f)","'--light-dictionary-read=single','--particle-core-survey'].includes(f)");
replace("function verifyNative(s,n){",`function coreSurveyUse(core,pacing){
 if(core?.enabled!==true||core.stride!==120||core.capacity!==256||core.clocks_per_frame!==0||!Number.isSafeInteger(core.frame_calls)||core.frame_calls<1||!Number.isSafeInteger(core.samples)||core.samples!==Math.ceil(core.frame_calls/120)||core.dropped_distinct_cores!==0)return false;
 if(!Number.isSafeInteger(core.process_id)||core.process_id<=0||!Number.isSafeInteger(core.frame_thread_id)||core.frame_thread_id<=0||core.frame_thread_id!==core.report_thread_id||core.frame_thread_id!==pacing?.main_thread_policy?.thread_id||pacing.main_thread_policy.available!==true)return false;
 const exactPositive=x=>typeof x==='string'&&/^[1-9][0-9]*$/.test(x)&&BigInt(x)<=9223372036854775807n;
 if(!exactPositive(core.process_creation_100ns_exact)||!exactPositive(core.report_thread_creation_100ns_exact)||core.report_thread_creation_100ns_exact!==pacing.main_thread_policy.expected_creation_100ns_exact)return false;
 const topology=core.topology;
 if(topology?.error!==0||!Array.isArray(topology.rows)||!topology.rows.length)return false;
 const cpus=new Set(),classes=new Set();
 for(const r of topology.rows){if(![r.group,r.logical_processor_index,r.core_index,r.efficiency_class].every(x=>Number.isSafeInteger(x)&&x>=0))return false;const key=r.group+':'+r.logical_processor_index;if(cpus.has(key))return false;cpus.add(key);classes.add(r.efficiency_class);}
 if(classes.size<2||!Array.isArray(core.histogram)||!Array.isArray(core.records)||core.histogram.length>256||core.records.length!==Math.min(core.samples,256))return false;
 let total=0;const seen=new Set();
 for(const r of core.histogram){const key=r.group+':'+r.number;if(!cpus.has(key)||seen.has(key)||!Number.isSafeInteger(r.count)||r.count<1)return false;seen.add(key);total+=r.count;}
 if(total!==core.samples)return false;
 let previous=0,expected=1+120*Math.max(0,core.samples-256);for(const r of core.records){if(!Number.isSafeInteger(r.frame)||r.frame!==expected||r.frame>core.frame_calls||!cpus.has(r.group+':'+r.number))return false;previous=r.frame;expected+=120;}
 return previous===1+120*(core.samples-1);
}
function verifyNative(s,n){`);
replace(" const boundary=g.particle_boundary?.boundary??g.particle_boundary;"," requireUse('--particle-core-survey','coreSurvey',coreSurveyUse(g.core_survey,g.pacing));\n const boundary=g.particle_boundary?.boundary??g.particle_boundary;");
replace("module.exports={readSelection,runtimeFiles,verifyNative};","module.exports={readSelection,runtimeFiles,verifyNative,coreSurveyUse};");
fs.writeFileSync(output,code,{flag:'wx'});
console.log(JSON.stringify({source:{file:source,sha256:sha(original)},output:{file:output,sha256:sha(code)},scope:'Source-only V17 derivative. Original V16 remains unchanged.'}));
