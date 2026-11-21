// Bounded isolated CPU/headless checks; no ordinary launches, native builds,
// server connections, process termination, shared writes or full-project copy.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const project=path.resolve(here,'../../..');
const root=path.dirname(project);
const [label,phase]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||!['stage','oracle','controller','scene-gd','scene-native','part-gd','part-native','box-gd','box-native'].includes(phase))throw Error('Fresh label and known phase required');
const directory=path.join(project,'.cache/native-140fps/loading-agent',label),copy=path.join(directory,'project');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
const pinnedEngine=path.join(project,'.cache/native-140fps/render-agent/engine-builtin-light-v2/build-1793905781252/binaries/godot.windows.template_release.x86_64.exe');
const engineSha='ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a';
const parentFile=path.join(project,'.cache/native-140fps/root/drive-envelope-fenced-v1/manifest.json');
const parentSha='cce71cea6e3ae8116d4747c97f1e161eed9350cd85386dc372578d9f6d4cdfc1';
const tests=['tests/native_parity_client_support_test.gd','tests/native_parity_client_support_scene_test.gd','tests/native_parity_support_part_policy_test.gd','tests/native_parity_support_authored_box_test.gd'];
const write=(file,value)=>fs.writeFileSync(file,JSON.stringify(value,null,2)+'\n',{flag:'wx'});
const sourceFile=relative=>{const file=path.resolve(project,relative);if(!file.startsWith(project+path.sep))throw Error('Source escapes project');return file;};
if(phase==='stage'){
 if(fs.existsSync(directory))throw Error('Existing stage/evidence preserved');
 if(sha(fs.readFileSync(parentFile))!==parentSha||sha(fs.readFileSync(pinnedEngine))!==engineSha)throw Error('Pinned parent/engine differs');
 fs.mkdirSync(copy,{recursive:true});
 const pending=[...tests],seen=new Set(),pins=[];let bytes=0;
 while(pending.length){
  const relative=pending.shift();if(seen.has(relative))continue;seen.add(relative);
  if(seen.size>128||relative==='systems/native_data/asset_service.gd')throw Error('Unexpected broad/mutable source closure');
  const raw=fs.readFileSync(sourceFile(relative));bytes+=raw.length;if(bytes>8*1024*1024)throw Error('Source closure exceeds8MiB');
  const file=path.join(copy,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,raw);pins.push({relative,sha256:sha(raw),bytes:raw.length});
  const source=raw.toString('utf8');for(const match of source.matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+\.gd)["']\s*\)|extends\s+["']res:\/\/([^"']+\.gd)["']/g))pending.push(match[1]??match[2]);
 }
 const parent=JSON.parse(fs.readFileSync(parentFile));
 for(const relative of ['native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll']){
  const pin=parent.pins.find(p=>p.relative===relative);if(!pin)throw Error('Missing frozen native pin');
  const raw=fs.readFileSync(path.join(parent.project,relative));if(sha(raw)!==pin.sha256)throw Error('Frozen native bytes differ');
  const file=path.join(copy,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,raw);pins.push({...pin});
 }
 const configuration='config_version=5\n[application]\nconfig/name="SupportFixture '+label+'"\nconfig/features=PackedStringArray("4.7")\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
 fs.writeFileSync(path.join(copy,'project.godot'),configuration);pins.push({relative:'project.godot',sha256:sha(configuration),bytes:Buffer.byteLength(configuration)});
 fs.mkdirSync(path.join(copy,'.godot'),{recursive:true});fs.writeFileSync(path.join(copy,'.godot/global_script_class_cache.cfg'),'list=[]\n');
 const oracle=path.join(here,'capture_client_support_oracle.py');
 const evidence=path.join(project,'tools/native_parity/visibility/evidence/native-presentation-procedures-v2.json');
 const frozenEvidence=path.join(directory,'native-presentation-procedures-v2.json');fs.copyFileSync(evidence,frozenEvidence);
 write(path.join(directory,'stage.json'),{success:true,label,project:copy,engine:{file:pinnedEngine,sha256:engineSha},parent:{file:parentFile,sha256:parentSha},pins,oracle:{file:oracle,sha256:sha(fs.readFileSync(oracle))},evidence:{file:frozenEvidence,source:evidence,sha256:sha(fs.readFileSync(frozenEvidence))},scriptFiles:seen.size,sourceBytes:bytes,sharedWrites:0,nativeBuilds:0,servers:0,scope:'Bounded preload closure, isolated user data, original frozen DLL copy only'});
 console.log(JSON.stringify({success:true,phase,scriptFiles:seen.size,sourceBytes:bytes,receipt:path.join(directory,'stage.json')}));
 process.exit(0);
}
const receiptFile=path.join(directory,phase+'.json');if(fs.existsSync(receiptFile))throw Error('Existing phase receipt preserved');
const stage=JSON.parse(fs.readFileSync(path.join(directory,'stage.json')));
const changed=()=>stage.pins.filter(p=>sha(fs.readFileSync(path.join(copy,p.relative)))!==p.sha256).map(p=>p.relative);
if(changed().length||sha(fs.readFileSync(pinnedEngine))!==engineSha)throw Error('Stage or actual executable changed');
let executable,args,report;
if(phase==='oracle'){
 if(sha(fs.readFileSync(stage.oracle.file))!==stage.oracle.sha256||sha(fs.readFileSync(stage.evidence.file))!==stage.evidence.sha256)throw Error('Oracle/evidence source changed');
 executable=path.join(process.env.SystemRoot??'C:/Windows','py.exe');report=path.join(directory,'original.json');args=['-3',stage.oracle.file,'--output',report,'--evidence',stage.evidence.file];
}else{
 executable=pinnedEngine;report=path.join(directory,phase+'-result.json');
 args=['--headless','--path',copy,'--script','res://'+tests[phase==='controller'?0:phase.startsWith('box-')?3:phase.startsWith('part-')?2:1],'--','--report='+report,phase.endsWith('-native')?'--particle-kernel=compiled':'--particle-kernel=gd'];
 if(phase==='controller'){if(!fs.existsSync(path.join(directory,'original.json')))throw Error('Original instruction corpus required');args.push('--original-corpus='+path.join(directory,'original.json'));}
 if(phase.endsWith('-native'))args.push('--require-compiled-scene');
}
const user=path.join(directory,'userdata',phase);fs.mkdirSync(user,{recursive:true});
const started=new Date().toISOString();
const child=spawnSync(executable,args,{cwd:root,encoding:'utf8',timeout:phase==='oracle'?90000:30000,maxBuffer:2*1024*1024,windowsHide:true,env:{...process.env,APPDATA:user,LOCALAPPDATA:user,NWN_PARTICLE_KERNEL:phase.endsWith('-native')?'compiled':'gd'}});
const stdout=child.stdout??'',stderr=child.stderr??'';fs.writeFileSync(path.join(directory,phase+'.stdout.log'),stdout,{flag:'wx'});fs.writeFileSync(path.join(directory,phase+'.stderr.log'),stderr,{flag:'wx'});
const problems=(stdout+'\n'+stderr).split(/\r?\n/).filter(line=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances leaked|resources still in use|Invalid call/.test(line));
let result=null;try{result=JSON.parse(fs.readFileSync(report,'utf8'));}catch{}
const sourceChanged=changed();
let success=child.status===0&&!child.error&&!problems.length&&!sourceChanged.length;
if(phase==='oracle')success=success&&result?.target==='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'&&result?.cases?.length>0;
else success=success&&result?.success===true&&result?.checks>0&&(phase!=='controller'||result.original_cases>0)&&(!phase.endsWith('-native')||result.native_scene_index===true)&&(phase!=='part-native'||result.compiled_raw_geometry===true);
write(receiptFile,{success,phase,started,finished:new Date().toISOString(),executable,args,engine:stage.engine,exit:child.status,signal:child.signal,error:child.error?.message??null,problems,sourceChanged,result:phase==='oracle'?{cases:result?.cases?.length??0}:result,report,scope:'Functional isolated headless/original-controller checks only; no timing/GPU/server/native-build acceptance'});
console.log(JSON.stringify({success,phase,exit:child.status,problems:problems.slice(0,6),checks:result?.checks??null,originalCases:result?.original_cases??(phase==='oracle'?result?.cases?.length:null),receipt:receiptFile}));
process.exit(success?0:1);
