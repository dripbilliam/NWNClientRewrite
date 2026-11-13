// Owned copied headless project. No build, server, GPU or interactive profile.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const run=process.argv.find(s=>s.startsWith('--run='))?.slice(6);
if(!/^native-reference-admission-[a-z0-9-]+$/.test(run??''))throw Error('A fresh native-reference-admission run label is required');
const stage=path.join(project,'.cache','native-reference-admission',run),copy=path.join(stage,'project');
await fs.mkdir(path.dirname(stage),{recursive:true});await fs.mkdir(stage,{recursive:false});await fs.mkdir(copy);
const digest=b=>crypto.createHash('sha256').update(b).digest('hex');
const engine=path.join(project,'.tools','Godot_v4.7.2-stable_win64.exe'),engineHash=digest(await fs.readFile(engine));
if(engineHash!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected installed engine; no fallback/build');
const pending=['tests/native_reference_admission_test.gd'],pins=[],seen=new Set();let sourceBytes=0;
while(pending.length){
 const relative=pending.shift();if(seen.has(relative))continue;seen.add(relative);
 const source=path.resolve(project,relative);if(!source.startsWith(project+path.sep))throw Error('Dependency escapes project');
 const bytes=await fs.readFile(source);sourceBytes+=bytes.length;if(sourceBytes>32*1024*1024||seen.size>2000)throw Error('Copied closure bound exceeded');
 const target=path.join(copy,relative);await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes,{flag:'wx'});
 pins.push({relative,sha256:digest(bytes),bytes:bytes.length});
 if(relative.endsWith('.gd'))for(const match of bytes.toString('utf8').matchAll(/(?:(?:preload|load)\s*\(\s*|extends\s+)["']res:\/\/([^"']+)["']/g))pending.push(match[1]);
}
const guards=[];
for(const relative of ['project.godot','.godot/extension_list.cfg','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json']){
 const bytes=await fs.readFile(path.join(project,relative)).catch(error=>{if(error.code==='ENOENT')return null;throw error;});guards.push({relative,sha256:bytes===null?null:digest(bytes)});
}
await fs.writeFile(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="'+run+'"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',{flag:'wx'});
const fixture=path.join(stage,'fixture');await fs.mkdir(fixture);await fs.writeFile(path.join(fixture,'known.mdl'),'# present authored root; payload decoding intentionally outside this gate\n',{flag:'wx'});
const resultFile=path.join(stage,'result.json'),log=path.join(stage,'engine.log'),stdout=path.join(stage,'stdout.log'),stderr=path.join(stage,'stderr.log');
const args=['--headless','--max-fps','60','--path',copy,'--log-file',log,'--script','res://tests/native_reference_admission_test.gd','--','--fixture='+fixture,'--report='+resultFile];
await fs.writeFile(path.join(stage,'inputs.json'),JSON.stringify({engine,engineHash,args,pins,guards,sourceBytes,deadlineMs:60000},null,2)+'\n',{flag:'wx'});
let result=null,failure=null,exitCode=null,ownedPid=null,killed=false,output='';
const child=spawn(engine,args,{windowsHide:true,stdio:['ignore','pipe','pipe']});ownedPid=child.pid;
const out=[],err=[];let byteCount=0;
for(const [stream,parts]of [[child.stdout,out],[child.stderr,err]])stream.on('data',b=>{parts.push(b);byteCount+=b.length;if(byteCount>2*1024*1024&&!killed){failure='Owned output exceeded bound';killed=true;child.kill();}});
const timer=setTimeout(()=>{failure='Owned headless deadline exceeded60s';killed=true;child.kill();},60000);
try{exitCode=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});}catch(error){failure=error.message;}finally{clearTimeout(timer);await fs.writeFile(stdout,Buffer.concat(out));await fs.writeFile(stderr,Buffer.concat(err));}
try{result=JSON.parse(await fs.readFile(resultFile,'utf8'));}catch{failure??='No native result';}
output=Buffer.concat(out).toString('utf8')+Buffer.concat(err).toString('utf8')+await fs.readFile(log,'utf8').catch(()=> 'ERROR: engine log missing');
const changedSources=[],changedCopies=[],changedGuards=[];
for(const pin of pins){if(digest(await fs.readFile(path.join(project,pin.relative)))!==pin.sha256)changedSources.push(pin.relative);if(digest(await fs.readFile(path.join(copy,pin.relative)))!==pin.sha256)changedCopies.push(pin.relative);}
for(const guard of guards){const bytes=await fs.readFile(path.join(project,guard.relative)).catch(error=>{if(error.code==='ENOENT')return null;throw error;});if((bytes===null?null:digest(bytes))!==guard.sha256)changedGuards.push(guard.relative);}
const engineUnchanged=digest(await fs.readFile(engine))===engineHash,engineClean=!/SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB.*leak|resources still in use|Unicode parsing error/m.test(output);
const success=exitCode===0&&!failure&&!killed&&result?.success===true&&engineClean&&engineUnchanged&&!changedSources.length&&!changedCopies.length&&!changedGuards.length;
const receipt={success,run,ownedPid,exitCode,killed,failure,checks:result?.checks??0,failures:result?.failures??[],observations:result?.observations??{},engineClean,engineUnchanged,changedSources,changedCopies,changedGuards,sourcePins:pins.length,pins,guards,serverConnections:0,gpu:false,nativeBuilds:0,profileOrKeyReads:0,scope:'Actual reference admission path in copied headless source closure; no worker/render/server or performance acceptance'};
await fs.writeFile(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success,run,checks:receipt.checks,failures:receipt.failures,failure,engineClean,changedSources,changedGuards,receipt:path.join(stage,'receipt.json')}));
if(!success)process.exitCode=1;
