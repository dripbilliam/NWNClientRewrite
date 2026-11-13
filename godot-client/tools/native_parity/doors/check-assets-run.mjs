// Isolated actual-resource CPU fixture only. No renderer/game/server launches,
// native builds, shared outputs, original-install writes or process stops.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const source=path.resolve(here,'../../..'),root=path.dirname(source);
const [label,phase]=process.argv.slice(2);
if(!/^check-assets-[a-z0-9-]+$/.test(label??'')||!['stage','local-stage','run'].includes(phase))throw Error('Fresh check-assets label and stage/local-stage/run required');
const directory=path.join(source,'.cache/native-presentation-parity/loading-agent',label),project=path.join(directory,'project');
const engine=path.join(source,'.cache/native-140fps/render-agent/engine-builtin-light-v2/build-1793905781252/binaries/godot.windows.template_release.x86_64.exe');
const engineSha='ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a';
const parentFile=path.join(source,'.cache/native-140fps/root/drive-envelope-fenced-v1/manifest.json');
const parentSha='cce71cea6e3ae8116d4747c97f1e161eed9350cd85386dc372578d9f6d4cdfc1';
const install=path.resolve(root,'../FullDecomp/NwnRootInstall');
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const write=(file,value)=>fs.writeFileSync(file,JSON.stringify(value,null,2)+'\n',{flag:'wx'});
const test=phase==='local-stage'?'tests/native_parity_door_server_test.gd':'tests/native_parity_door_asset_pick_test.gd';
if(phase==='stage'||phase==='local-stage'){
 if(fs.existsSync(directory))throw Error('Existing stage preserved');
 if(sha(fs.readFileSync(engine))!==engineSha||sha(fs.readFileSync(parentFile))!==parentSha)throw Error('Frozen engine/parent changed');
 fs.mkdirSync(project,{recursive:true});
 const queue=[test],seen=new Set(),pins=[];let bytes=0;
 while(queue.length){
  const relative=queue.shift();if(seen.has(relative))continue;seen.add(relative);
  if(!relative.endsWith('.gd')||relative.includes('..')||seen.size>256)throw Error('Unexpected source closure');
  const raw=fs.readFileSync(path.join(source,relative));bytes+=raw.length;if(bytes>4*1024*1024)throw Error('Closure exceeds4MiB');
  const target=path.join(project,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,raw);
  pins.push({relative,sha256:sha(raw),bytes:raw.length});
  for(const match of raw.toString('utf8').matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+\.gd)["']\s*\)|extends\s+["']res:\/\/([^"']+\.gd)["']/g))queue.push(match[1]??match[2]);
 }
 const parent=JSON.parse(fs.readFileSync(parentFile));
 for(const relative of ['native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll']){
  const pin=parent.pins.find(value=>value.relative===relative);if(!pin)throw Error('Missing native pin');
  const raw=fs.readFileSync(path.join(parent.project,relative));if(sha(raw)!==pin.sha256)throw Error('Native source parent bytes differ');
  const target=path.join(project,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,raw);pins.push({...pin});
 }
 const config='config_version=5\n[application]\nconfig/name="Door asset CPU fixture"\nconfig/features=PackedStringArray("4.7")\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
 fs.writeFileSync(path.join(project,'project.godot'),config);pins.push({relative:'project.godot',sha256:sha(config),bytes:Buffer.byteLength(config)});
 fs.mkdirSync(path.join(project,'.godot'),{recursive:true});fs.writeFileSync(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n');
 const keys=[];
 for(const relative of ['data/nwn_base.key','data/nwn_retail.key','lang/en/data/nwn_base_loc.key']){
  const file=path.join(install,relative);if(fs.existsSync(file)){const raw=fs.readFileSync(file);keys.push({file,bytes:raw.length,sha256:sha(raw)});}
 }
 write(path.join(directory,'stage.json'),{success:true,label,project,test,pins,sourceFiles:seen.size,sourceBytes:bytes,engine:{file:engine,sha256:engineSha},parent:{file:parentFile,sha256:parentSha},install:{directory:install,keys},originalWrites:0,sharedWrites:0,nativeBuilds:0});
 console.log(JSON.stringify({success:true,phase,sourceFiles:seen.size,sourceBytes:bytes,receipt:path.join(directory,'stage.json')}));process.exit(0);
}
const output=path.join(directory,'run.json');if(fs.existsSync(output))throw Error('Existing run preserved');
const stage=JSON.parse(fs.readFileSync(path.join(directory,'stage.json')));
const changed=()=>stage.pins.filter(pin=>sha(fs.readFileSync(path.join(project,pin.relative)))!==pin.sha256).map(pin=>pin.relative);
if(changed().length||sha(fs.readFileSync(engine))!==engineSha)throw Error('Engine/staged bytes differ');
const report=path.join(directory,'result.json'),userdata=path.join(directory,'userdata');fs.mkdirSync(userdata,{recursive:true});
const args=['--headless','--path',project,'--script','res://'+test,'--','--report='+report,'--install='+install,'--cache='+path.join(directory,'prepared'),'--prepared-cache-write=sync','--particle-kernel=gd','--particles=false'];
const started=new Date().toISOString();
const child=spawnSync(engine,args,{cwd:root,encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:userdata,LOCALAPPDATA:userdata,NWN_PARTICLE_KERNEL:'gd'}});
const stdout=child.stdout??'',stderr=child.stderr??'';
fs.writeFileSync(path.join(directory,'stdout.log'),stdout,{flag:'wx'});fs.writeFileSync(path.join(directory,'stderr.log'),stderr,{flag:'wx'});
const problems=(stdout+'\n'+stderr).split(/\r?\n/).filter(line=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances leaked|resources still in use|Invalid call/.test(line));
let result;try{result=JSON.parse(fs.readFileSync(report));}catch{}
const sourceChanged=changed(),originalChanged=stage.install.keys.filter(pin=>sha(fs.readFileSync(pin.file))!==pin.sha256).map(pin=>pin.file);
const success=child.status===0&&!child.error&&result?.success===true&&result?.models?.length===2&&!problems.length&&!sourceChanged.length&&!originalChanged.length;
write(output,{success,started,finished:new Date().toISOString(),executable:engine,args,engine:stage.engine,exit:child.status,signal:child.signal,error:child.error?.message??null,problems,sourceChanged,originalChanged,report,result,scope:'Headless functional installed-resource/rig/physics/metadata-cache check only; no GPU/FPS/original GUI/server action outcome'});
console.log(JSON.stringify({success,exit:child.status,checks:result?.checks??0,failures:result?.failures,problems:problems.slice(0,8),error:child.error?.message??null,receipt:output}));process.exit(success?0:1);
