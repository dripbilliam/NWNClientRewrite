import fs from 'node:fs';import path from 'node:path';import {digest} from './processor-graph.mjs';
import {createCapsule,runHeadless,parentDrift,project} from './run-isolated-once.mjs';import {runFixedHeadless} from './run-fixed-engine-once.mjs';
const parent=process.argv[2],label=process.argv[3],fixed=process.argv[4]?{file:process.argv[4],sha256:process.argv[5]}:null;
if(!/^combined-loading-accounting-[a-z0-9-]+$/.test(parent??'')||!/^combined-loading-accounting-gate-[a-z0-9-]+$/.test(label??''))throw Error('Frozen accounting parent/fresh gate label required');
if(fixed&&(!path.isAbsolute(fixed.file)||!/^[0-9a-f]{64}$/.test(fixed.sha256??'')))throw Error('Exact fixed executable path/SHA required');
const catalog='C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf/catalog-1',captureFile=path.join(catalog,'manifest.json'),before=digest(fs.readFileSync(captureFile));
if(before!=='1ef50ed518173a2f172f42a935252c0c3500319c2393286a5773f2de3b28e035')throw Error('Sealed catalog differs');
const runs=[];
for(const enabled of [false,true]){
 const capsule=createCapsule(label+'-'+(enabled?'borrowed':'original'),parent,'native_perf140_loading_accounting_borrow_test.gd');
 const args=['--recorded-catalog='+catalog,'--models=ttu01_w06_01,ttu01_a01_01,ttu01_a01_02,ttu01_a01_03,ttu01_a02_01,ttu01_a02_02,ttu01_a02_03,ttu01_a04_01',...(enabled?['--resource-accounting-access=borrowed']:[])];
 const result=fixed?await runFixedHeadless(capsule,args,40000,'process',fixed):await runHeadless(capsule,args,40000),sourceDrift=parentDrift(capsule);
 const row={mode:enabled?'borrowed':'original',manifestSha256:capsule.manifestSha256,scriptSha256:capsule.scriptSha256,...result,sourceDrift};row.success=result.success&&!sourceDrift.length;
 fs.writeFileSync(path.join(capsule.stage,'receipt.json'),JSON.stringify(row,null,2)+'\n');runs.push(row);if(!row.success)break;
}
const after=digest(fs.readFileSync(captureFile)),receipt={success:runs.length===2&&runs.every(v=>v.success)&&before===after,runs,capture:{before,after,copiedPayloads:0},graphics:0,serverConnections:0,timingClaim:false};
const file=path.join(project,'.cache/native-140fps/loading-agent',label+'-receipt.json');if(fs.existsSync(file))throw Error('Existing evidence preserved');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({file,success:receipt.success,runs:runs.map(v=>({mode:v.mode,success:v.success,checks:v.proof?.checks,failures:v.proof?.failures,error:v.outcome?.error}))}));if(!receipt.success)process.exitCode=1;
