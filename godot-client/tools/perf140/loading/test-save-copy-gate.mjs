import fs from 'node:fs';import path from 'node:path';
import {createCapsule,runHeadless,parentDrift,project} from './run-isolated-once.mjs';
import {digest} from './processor-graph.mjs';
const parent=process.argv[2],label=process.argv[3];
if(!/^combined-loading-save-[a-z0-9-]+$/.test(parent??'')||!/^combined-loading-save-gate-[a-z0-9-]+$/.test(label??''))throw Error('Frozen save-gate parent and fresh evidence label required');
const runs=[];
for(const enabled of [false,true]){
 const mode=enabled?'enabled':'disabled',capsule=createCapsule(label+'-'+mode,parent,'native_perf140_loading_save_copy_gate_test.gd');
 const result=await runHeadless(capsule,enabled?['--preparation-save-copy-gate=enabled']:[],25000),sourceDrift=parentDrift(capsule);
 const row={mode,manifestSha256:capsule.manifestSha256,scriptSha256:capsule.scriptSha256,...result,sourceDrift};row.success=result.success&&!sourceDrift.length;
 fs.writeFileSync(path.join(capsule.stage,'receipt.json'),JSON.stringify(row,null,2)+'\n');runs.push(row);if(!row.success)break;
}
const catalog='C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf/catalog-1',captureFile=path.join(catalog,'manifest.json'),captureBefore=digest(fs.readFileSync(captureFile));if(captureBefore!=='1ef50ed518173a2f172f42a935252c0c3500319c2393286a5773f2de3b28e035')throw Error('Sealed capture differs');
let checkpoint;
if(runs.length===2&&runs.every(v=>v.success))for(const enabled of [false,true]){
 const mode=enabled?'pipeline-enabled':'pipeline-disabled',capsule=createCapsule(label+'-'+mode,parent,'native_perf140_loading_static_actor_route_test.gd');
 fs.writeFileSync(path.join(capsule.copy,'tests/native_perf140_loading_processor_capture_test.gd'),fs.readFileSync(path.join(project,'tests/native_perf140_loading_processor_capture_test.gd')));
 const cache=path.join(capsule.stage,'owned-cache');fs.mkdirSync(cache);if(!checkpoint){checkpoint=path.join(capsule.stage,'baseline');fs.mkdirSync(checkpoint);}
 const result=await runHeadless(capsule,['--recorded-catalog='+catalog,'--models=ttu01_w06_01,ttu01_a01_01,ttu01_a01_02,ttu01_a01_03,ttu01_a02_01,ttu01_a02_02,ttu01_a02_03,ttu01_a04_01','--baseline-root='+checkpoint,'--cache-root='+cache,...(enabled?['--preparation-save-copy-gate=enabled','--static-emitter-route=enabled','--model-float-stream=bulk','--raster-cache-write=deferred']:[])],30000),sourceDrift=parentDrift(capsule);
 const row={mode,manifestSha256:capsule.manifestSha256,scriptSha256:capsule.scriptSha256,...result,sourceDrift};row.success=result.success&&!sourceDrift.length;fs.writeFileSync(path.join(capsule.stage,'receipt.json'),JSON.stringify(row,null,2)+'\n');runs.push(row);if(!row.success)break;
}
const captureAfter=digest(fs.readFileSync(captureFile));
const receipt={success:runs.length===4&&runs.every(v=>v.success)&&captureBefore===captureAfter,runs,capture:{before:captureBefore,after:captureAfter,copiedPayloads:0},serverConnections:0,graphics:0,timingClaim:false};
const file=path.join(project,'.cache/native-140fps/loading-agent',label+'-receipt.json');if(fs.existsSync(file))throw Error('Existing evidence preserved');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({file,success:receipt.success,runs:runs.map(v=>({mode:v.mode,success:v.success,checks:v.proof?.checks,failures:v.proof?.failures,error:v.outcome?.error}))}));if(!receipt.success)process.exitCode=1;
