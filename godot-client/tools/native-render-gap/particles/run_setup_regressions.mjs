import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const project=path.resolve(here,'../../..');
const cache=path.join(project,'.cache/native-render-gap/particles');
const engine=path.join(project,'.cache/native-render-gap/engine/build-1794133858985/godot.windows.template_release.x86_64.exe');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const engineSha256=hash(engine);
if(engineSha256!=='5713d014f2d1a0c7d479720176fbe8081e9e6254c693b9b5b244676f3afafb0d')throw Error('Pinned V4.1 engine changed');
const setup=path.join(cache,'setup-boundary-a');
const childless=path.join(cache,'childless-chunk-a');
const output=path.join(setup,'regressions-v4-1');
if(fs.existsSync(output))throw Error('Retain previous receipts; choose a new stage');
fs.mkdirSync(output);
const bound=JSON.parse(fs.readFileSync(path.join(setup,'bound-regressions.json')));
const setupReceipt=JSON.parse(fs.readFileSync(path.join(setup,'test-project-receipt.json')));
const childReceipt=JSON.parse(fs.readFileSync(path.join(childless,'test-project-c-receipt.json')));
const pins=[...setupReceipt.pins.map(pin=>({file:path.join(setupReceipt.project,pin.relative),sha256:pin.sha256})),...childReceipt.pins.map(pin=>({file:path.join(childReceipt.project,pin.relative),sha256:pin.sha256})),...bound.outputs.map(pin=>({file:path.join(bound.project,pin.relative),sha256:pin.sha256}))];
function verify(){for(const pin of pins)if(hash(pin.file)!==pin.sha256)throw Error('Frozen functional input drift: '+pin.file);}
verify();
const cases=bound.outputs.map(pin=>({name:path.basename(pin.relative,'.gd'),project:bound.project,script:'res://'+pin.relative,binarySha256:setupReceipt.binarySha256}));
cases.push({name:'childless138-v4-1',project:childReceipt.project,script:'res://tests/native_render_gap_childless_chunk_test.gd',binarySha256:childReceipt.binarySha256});
const rows=[];
for(const fixture of cases){
 const report=path.join(output,fixture.name+'.json'),log=path.join(output,fixture.name+'.engine.log');
 const args=['--headless','--path',fixture.project,'--log-file',log,'--script',fixture.script,'--','--particle-scene-boundary=native','--report='+report];
 const startedAt=new Date().toISOString();
 const child=spawn(engine,args,{cwd:fixture.project,windowsHide:true,stdio:['ignore','pipe','pipe']});
 os.setPriority(child.pid,os.constants.priority.PRIORITY_BELOW_NORMAL);
 let stdout='',stderr='';child.stdout.on('data',chunk=>stdout+=chunk);child.stderr.on('data',chunk=>stderr+=chunk);
 const timer=setTimeout(()=>child.kill(),30000);
 const {code,signal}=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',(code,signal)=>resolve({code,signal}));});
 clearTimeout(timer);
 fs.writeFileSync(path.join(output,fixture.name+'.stdout.log'),stdout);fs.writeFileSync(path.join(output,fixture.name+'.stderr.log'),stderr);
 const logs=[stdout,stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):''].join('\n');
 const errors=logs.split(/\r?\n/).filter(line=>/SCRIPT ERROR|Parse Error|(?:^|\s)ERROR:|WARNING:|ObjectDB.*leak|resources still in use|CrashHandler|Unhandled exception/.test(line));
 let result=null;try{result=JSON.parse(fs.readFileSync(report));}catch{}
 const row={...fixture,startedAt,finishedAt:new Date().toISOString(),exit:code,signal,checks:result?.checks??0,failures:result?.failures??[],errors,success:code===0&&!signal&&errors.length===0&&result?.success===true};
 rows.push(row);console.log(JSON.stringify(row));if(!row.success)break;
}
verify();
const receipt={scope:'Existing semantic suites in explicit bound setup mode plus unchanged childless138 on V4.1; strictly headless functional checks, no performance claim',success:rows.length===cases.length&&rows.every(row=>row.success),checks:rows.reduce((total,row)=>total+row.checks,0),engine,engineSha256,sourcePinsVerifiedBeforeAndAfter:true,graphicalProcesses:0,rows};
fs.writeFileSync(path.join(output,'receipt.json'),JSON.stringify(receipt,null,2)+'\n');
if(!receipt.success)process.exitCode=1;
