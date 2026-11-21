// Isolated text-source gate. No server connections, native builds or UI input.
import fs from 'node:fs';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
const output=path.resolve(process.argv[2]??'');
const manifest=JSON.parse(fs.readFileSync(path.join(output,'source-manifest.json'),'utf8'));
const sha=b=>createHash('sha256').update(b).digest('hex');
const source=manifest.source,project=manifest.project;
const allowed=path.join(source,'.cache/native-presentation-parity/root');
if(!output.startsWith(allowed+path.sep)||project!==path.join(output,'project'))throw Error('Private root snapshot required');
const engine=path.join(source,'.cache/native-140fps/render-agent/engine-builtin-light-v2/build-1793905781252/binaries/godot.windows.template_release.x86_64.exe');
if(sha(fs.readFileSync(engine))!=='ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a')throw Error('Engine pin mismatch');
const scripts=process.argv.slice(3);
if(!scripts.length||scripts.some(v=>!/^res:\/\/(tests\/[^/]+\.gd|native_session_world\.gd)$/.test(v)))throw Error('Explicit known local test path required');
const nativeDll=path.join(project,'.cache/native-kernel/nwn-particle-kernel.dll');
if(fs.existsSync(nativeDll)&&sha(fs.readFileSync(nativeDll))!=='672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea')throw Error('Private native library pin mismatch');
if(scripts.includes('res://tests/visual_phases_test.gd')){
 const retained=[];
 for(const group of ['control','update']){
  const relative=`backups/animations/native-visual-phase-${group}-observations.json`,from=path.join(path.dirname(source),relative),target=path.join(output,relative),bytes=fs.readFileSync(from);
  fs.mkdirSync(path.dirname(target),{recursive:true});
  if(fs.existsSync(target)){if(sha(fs.readFileSync(target))!==sha(bytes))throw Error('Retained oracle mismatch');}else fs.writeFileSync(target,bytes,{flag:'wx'});
  retained.push({source:from,target,sha256:sha(bytes),bytes:bytes.length});
 }
 fs.writeFileSync(path.join(output,'retained-original-records.json'),JSON.stringify(retained,null,2)+'\n');
}
const results=[];
for(const script of scripts){
 const name=path.basename(script,'.gd'),log=path.join(output,name+'.engine.log');
 const extra=script==='res://tests/visual_phases_test.gd'?['--',`--oracle=${path.join(output,'phase-oracle.json')}`,`--report=${path.join(output,'phase-checks.json')}`]:[];
 const args=['--headless','--path',project,'--log-file',log,...(script==='res://native_session_world.gd'?['--check-only']:[]),'--script',script,...extra];
 const began=Date.now(),child=spawn(engine,args,{cwd:project,windowsHide:true,stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='',timedOut=false;
 child.stdout.on('data',b=>stdout+=b);child.stderr.on('data',b=>stderr+=b);
 const timer=setTimeout(()=>{timedOut=true;child.kill();},45000);
 const terminal=await new Promise(resolve=>{child.on('error',error=>resolve({error:String(error)}));child.on('close',(exitCode,signal)=>resolve({exitCode,signal}));});
 clearTimeout(timer);
 fs.writeFileSync(path.join(output,name+'.stdout.log'),stdout);fs.writeFileSync(path.join(output,name+'.stderr.log'),stderr);
 const engineLog=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
 const problems=(stdout+'\n'+stderr+'\n'+engineLog).split(/\r?\n/).filter(v=>/SCRIPT ERROR|Parse Error|ERROR:|WARNING:.*leak|FAIL |failures[" ]*:[ ]*[1-9]/i.test(v));
 const result={script,pid:child.pid,args,...terminal,timedOut,milliseconds:Date.now()-began,problems,success:terminal.exitCode===0&&!timedOut&&!problems.length,stdout};results.push(result);
 console.log(JSON.stringify({script,pid:child.pid,...terminal,timedOut,problems,stdout}));
}
const changed=manifest.pins.filter(p=>!fs.existsSync(path.join(source,p.relative))||sha(fs.readFileSync(path.join(source,p.relative)))!==p.sha256).map(p=>p.relative);
const receipt={version:1,scope:'Isolated local correctness/compile checks only, no FPS or live-server validation',engine,results,sourceChangedSinceSnapshot:changed};
fs.writeFileSync(path.join(output,'root-checks.json'),JSON.stringify(receipt,null,2)+'\n');
if(results.some(r=>!r.success))process.exitCode=1;
