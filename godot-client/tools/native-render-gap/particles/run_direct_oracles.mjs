import fs from 'node:fs';import path from 'node:path';import os from 'node:os';import crypto from 'node:crypto';import {spawn} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2],engine=path.resolve(process.argv[3]??''),expectedHash=process.argv[4];
if(!/^[a-z0-9-]+$/.test(label??'')||!/^[a-f0-9]{64}$/.test(expectedHash??''))throw Error('Private label, engine path and exact engine SHA required');
const stage=path.join(project,'.cache/native-render-gap/particles',label),receipt=JSON.parse(fs.readFileSync(path.join(stage,'test-project-receipt.json'))),output=path.join(stage,'full-v6-1-a');
if(fs.existsSync(output))throw Error('Prior test evidence retained');fs.mkdirSync(output);
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
if(hash(engine)!==expectedHash)throw Error('Engine pin mismatch');
function verify(){for(const pin of receipt.pins)if(hash(path.join(receipt.project,pin.relative))!==pin.sha256)throw Error('Frozen functional input drift: '+pin.relative);}
verify();
const scripts=['native_render_gap_direct_scene_test.gd','bound_native_particle_presentation_test.gd','bound_native_particle_presentation_lifetime_test.gd','bound_native_particle_presentation_scene_test.gd','bound_native_particle_presentation_order_test.gd','bound_native_render_gap_scene_boundary_callbacks_test.gd','native_render_gap_setup_boundary_test.gd','native_render_gap_childless_chunk_test.gd'];
if(process.argv[5]==='coarse')scripts.unshift('native_render_gap_coarse_sampler_test.gd');
if(process.argv[5]==='hot')scripts.unshift('native_render_gap_hot_parameters_test.gd');
const rows=[];
outer:for(const mode of ['legacy','pod'])for(const script of scripts){
 const name=mode+'-'+path.basename(script,'.gd'),report=path.join(output,name+'.json'),log=path.join(output,name+'.engine.log');
 const args=['--headless','--path',receipt.project,'--log-file',log,'--script','res://tests/'+script,'--','--particle-scene-boundary=native','--particle-scene-direct='+mode,'--expect-direct='+(mode==='pod'?'active':'legacy'),'--report='+report];
 if(process.argv[5]==='hot')args.push('--particle-hot-parameters=bound');
 const startedAt=new Date().toISOString(),child=spawn(engine,args,{cwd:receipt.project,windowsHide:true,stdio:['ignore','pipe','pipe']});
 os.setPriority(child.pid,os.constants.priority.PRIORITY_BELOW_NORMAL);
 let stdout='',stderr='';child.stdout.on('data',value=>stdout+=value);child.stderr.on('data',value=>stderr+=value);const timer=setTimeout(()=>child.kill(),30000);
 const {code,signal}=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',(code,signal)=>resolve({code,signal}));});clearTimeout(timer);
 fs.writeFileSync(path.join(output,name+'.stdout.log'),stdout);fs.writeFileSync(path.join(output,name+'.stderr.log'),stderr);
 const text=[stdout,stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):''].join('\n'),errors=text.split(/\r?\n/).filter(line=>/SCRIPT ERROR|Parse Error|(?:^|\s)ERROR:|WARNING:|ObjectDB.*leak|resources still in use|CrashHandler|Unhandled exception/.test(line));
 let result=null;try{result=JSON.parse(fs.readFileSync(report));}catch{}
 const row={mode,script,startedAt,finishedAt:new Date().toISOString(),exit:code,signal,checks:result?.checks??0,failures:result?.failures??[],errors,success:code===0&&!signal&&errors.length===0&&result?.success===true};
 rows.push(row);console.log(JSON.stringify(row));if(!row.success)break outer;
}
verify();
const result={scope:'Same real V6.1 engine and private DLL in explicit direct/legacy routes; headless state/geometry/RNG/order/callback/lifetime and separate error-boundary functional proof, no FPS claim',extraMode:process.argv[5]??'none',hotParameterBindingRequested:process.argv[5]==='hot',engine,engineSha256:expectedHash,binarySha256:receipt.binarySha256,sourcePinsUnchanged:true,graphicalProcesses:0,success:rows.length===2*scripts.length&&rows.every(row=>row.success),checks:rows.reduce((total,row)=>total+row.checks,0),rows};
fs.writeFileSync(path.join(output,'receipt.json'),JSON.stringify(result,null,2)+'\n');if(!result.success)process.exitCode=1;
