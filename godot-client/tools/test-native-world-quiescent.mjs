// Copied headless correctness gate. No server, native build, live runtime swap,
// benchmark or user profile access. Keep every failed run under its fresh label.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const run=process.argv[2];
if(!/^native-world-quiescent-[a-z0-9-]+$/.test(run??''))throw Error('Supply a fresh native-world-quiescent run label');
const stage=path.join(project,'.cache/native-world-quiescent',run),copy=path.join(stage,'project');
await fs.mkdir(path.dirname(stage),{recursive:true});await fs.mkdir(stage,{recursive:false});await fs.mkdir(copy);
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha=hash(await fs.readFile(engine));
if(engineSha!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing engine; no build or fallback');
const pending=['tests/native_world_quiescent_test.gd'],seen=new Set(),pins=[];let sourceBytes=0;
while(pending.length){
 const relative=pending.shift();if(seen.has(relative))continue;seen.add(relative);
 const source=path.resolve(project,relative);if(!source.startsWith(project+path.sep))throw Error('Source closure escapes project');
 const bytes=await fs.readFile(source);sourceBytes+=bytes.length;if(pins.length>=2000||sourceBytes>32*1024*1024)throw Error('Source closure exceeds bound');
 const target=path.join(copy,relative);await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes,{flag:'wx'});
 if(hash(await fs.readFile(target))!==hash(bytes))throw Error('Copied source differs');
 pins.push({relative,bytes:bytes.length,sha256:hash(bytes)});
 if(relative.endsWith('.gd'))for(const match of bytes.toString().matchAll(/(?:(?:preload|load)\s*\(\s*|extends\s+)["']res:\/\/([^"']+)["']/g))pending.push(match[1]);
}
const guards=[];
for(const relative of ['project.godot','.godot/extension_list.cfg','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json']){
 guards.push({relative,sha256:hash(await fs.readFile(path.join(project,relative)))});
}
await fs.writeFile(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="'+run+'"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',{flag:'wx'});
const appdata=path.join(stage,'appdata'),localdata=path.join(stage,'localappdata');await fs.mkdir(appdata);await fs.mkdir(localdata);
const resultFile=path.join(stage,'result.json'),log=path.join(stage,'engine.log');
const args=['--headless','--max-fps','60','--path',copy,'--log-file',log,'--script','res://tests/native_world_quiescent_test.gd','--','--report='+resultFile];
await fs.writeFile(path.join(stage,'inputs.json'),JSON.stringify({engine,engineSha,args,pins,sourceBytes,guards,deadlineMs:60000,privateAppData:appdata,privateLocalAppData:localdata},null,2)+'\n',{flag:'wx'});
let failure=null,exitCode=null,killed=false,result=null;
const child=spawn(engine,args,{windowsHide:true,env:{...process.env,APPDATA:appdata,LOCALAPPDATA:localdata},stdio:['ignore','pipe','pipe']});
const stdout=[],stderr=[];let outputBytes=0;
for(const [stream,parts]of [[child.stdout,stdout],[child.stderr,stderr]])stream.on('data',bytes=>{parts.push(bytes);outputBytes+=bytes.length;if(outputBytes>2*1024*1024&&!killed){failure='Owned output exceeded bound';killed=true;child.kill();}});
const timer=setTimeout(()=>{failure='Owned correctness gate exceeded declared60s deadline';killed=true;child.kill();},60000);
try{exitCode=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});}catch(error){failure=error.message;}finally{clearTimeout(timer);}
await fs.writeFile(path.join(stage,'stdout.log'),Buffer.concat(stdout));await fs.writeFile(path.join(stage,'stderr.log'),Buffer.concat(stderr));
try{result=JSON.parse(await fs.readFile(resultFile,'utf8'));}catch{failure??='Native result missing';}
const output=Buffer.concat([...stdout,...stderr]).toString()+await fs.readFile(log,'utf8').catch(()=> 'ERROR: missing engine log');
const changedSources=[],changedCopies=[],changedGuards=[];
for(const pin of pins){
 if(hash(await fs.readFile(path.join(project,pin.relative)))!==pin.sha256)changedSources.push(pin.relative);
 if(hash(await fs.readFile(path.join(copy,pin.relative)))!==pin.sha256)changedCopies.push(pin.relative);
}
for(const guard of guards)if(hash(await fs.readFile(path.join(project,guard.relative)))!==guard.sha256)changedGuards.push(guard.relative);
const engineUnchanged=hash(await fs.readFile(engine))===engineSha;
const engineClean=!/SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB.*leak|resources still in use|Unicode parsing error/m.test(output);
const success=exitCode===0&&!failure&&!killed&&result?.success===true&&engineClean&&engineUnchanged&&!changedSources.length&&!changedCopies.length&&!changedGuards.length;
const report={success,run,ownedPid:child.pid,closed:child.exitCode!==null,exitCode,killed,failure,checks:result?.checks??0,failures:result?.failures??[],observations:result?.observations??{},sourcePins:pins,sourceBytes,changedSources,changedCopies,changedGuards,guards,engineClean,engineUnchanged,engineSha,nativeBuilds:0,gpu:false,serverConnections:0,userProfileReads:0,scope:'Actual original/candidate World receivers and pending_plan in copied native headless project. Explicit readiness/combat/visual test doubles; no gameplay or FPS acceptance.'};
const reportFile=path.join(project,'reports',run+'.json');await fs.writeFile(reportFile,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success,run,ownedPid:child.pid,closed:report.closed,exitCode,checks:report.checks,failures:report.failures,failure,engineClean,sourcePins:pins.length,changedSources,changedCopies,changedGuards,nativeBuilds:0,gpu:false,serverConnections:0,reportFile}));
if(!success)process.exitCode=1;
