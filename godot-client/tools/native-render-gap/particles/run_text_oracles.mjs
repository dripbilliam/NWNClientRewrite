import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import os from 'node:os';import {spawn} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),[label,enginePath,expectedHash]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||!/^[a-f0-9]{64}$/.test(expectedHash??''))throw Error('Label, exact engine and SHA required');
const stage=path.join(project,'.cache/native-render-gap/particles',label),engine=path.resolve(enginePath),closure=JSON.parse(fs.readFileSync(path.join(stage,'test-project-receipt.json'))),output=path.join(stage,'focused-v7-a');
if(fs.existsSync(output))throw Error('Retain prior execution evidence');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
if(hash(engine)!==expectedHash)throw Error('Exact engine pin mismatch');
function verify(){for(const pin of closure.pins)if(hash(path.join(closure.project,pin.relative))!==pin.sha256)throw Error('Frozen fixture input changed');}
verify();fs.mkdirSync(output);
const scenarios=[{mode:'legacy',script:'native_render_gap_resident_text_test.gd'},...['native_render_gap_resident_text_test.gd','native_render_gap_hot_parameters_test.gd','native_render_gap_direct_scene_test.gd','bound_native_particle_presentation_test.gd','bound_native_particle_presentation_lifetime_test.gd','bound_native_particle_presentation_scene_test.gd','bound_native_particle_presentation_order_test.gd','bound_native_render_gap_scene_boundary_callbacks_test.gd','native_render_gap_setup_boundary_test.gd','native_render_gap_childless_chunk_test.gd'].map(script=>({mode:'borrow',script}))];
const rows=[];
for(const {mode,script} of scenarios){
 const name=mode+'-'+path.basename(script,'.gd'),report=path.join(output,name+'.json'),log=path.join(output,name+'.engine.log');
 const args=['--headless','--path',closure.project,'--log-file',log,'--script','res://tests/'+script,'--','--particle-scene-boundary=native','--particle-scene-direct=pod','--expect-direct=active','--particle-hot-parameters=bound','--particle-resident-text='+mode,'--report='+report];
 const startedAt=new Date().toISOString(),child=spawn(engine,args,{cwd:closure.project,windowsHide:true,stdio:['ignore','pipe','pipe']});os.setPriority(child.pid,os.constants.priority.PRIORITY_BELOW_NORMAL);
 let stdout='',stderr='';child.stdout.on('data',data=>stdout+=data);child.stderr.on('data',data=>stderr+=data);const timer=setTimeout(()=>child.kill(),30000);
 const {code,signal}=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',(code,signal)=>resolve({code,signal}));});clearTimeout(timer);
 fs.writeFileSync(path.join(output,name+'.stdout.log'),stdout);fs.writeFileSync(path.join(output,name+'.stderr.log'),stderr);
 const text=[stdout,stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):''].join('\n'),errors=text.split(/\r?\n/).filter(line=>/SCRIPT ERROR|Parse Error|(?:^|\s)ERROR:|WARNING:|ObjectDB.*leak|resources still in use|CrashHandler|Unhandled exception/.test(line));
 let result=null;try{result=JSON.parse(fs.readFileSync(report));}catch{}
 const row={mode,script,startedAt,finishedAt:new Date().toISOString(),exit:code,signal,checks:result?.checks??0,failures:result?.failures??[],errors,success:code===0&&!signal&&errors.length===0&&result?.success===true};rows.push(row);console.log(JSON.stringify(row));if(!row.success)break;
}
verify();const result={version:1,success:rows.length===scenarios.length&&rows.every(row=>row.success),checks:rows.reduce((sum,row)=>sum+row.checks,0),engine,engineSha256:expectedHash,binarySha256:closure.binarySha256,sourcePinsUnchanged:true,graphicalProcesses:0,rows,scope:'Real V7 exact engine: same-DLL legacy/borrow private string type/lifetime oracle plus existing state/RNG/geometry/callback/order/sampler/binding regressions in borrowed mode; no FPS claim'};
fs.writeFileSync(path.join(output,'receipt.json'),JSON.stringify(result,null,2)+'\n');if(!result.success)process.exitCode=1;
