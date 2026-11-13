// Focused actual World/Motion/physical-Part CPU integration; no area service,
// server, graphics, shared native build, or live process interaction.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),root=path.dirname(source),[label,phase]=process.argv.slice(2);
if(!/^bridge-world-motion-[a-z0-9-]+$/.test(label??'')||!['stage','run'].includes(phase))throw Error('Fresh bridge-world-motion label and stage/run required');
const actualAssets=process.argv.includes('--actual-assets');
const folder=path.join(source,'.cache/native-presentation-parity/loading-agent',label),project=path.join(folder,'project'),test=actualAssets?'tests/native_parity_bridge_actual_asset_test.gd':'tests/native_parity_bridge_world_motion_test.gd';
const parentFile=path.join(source,'.cache/native-presentation-parity/loading-agent/parity-launch-seven-fixes-v2/manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
if(sha(fs.readFileSync(parentFile))!=='c82135844d8e779d8dc930f89a9eb626317844b0e65d921633f1461169f8b59b')throw Error('Compatible engine/native source parent differs');
if(phase==='stage'){
 if(fs.existsSync(folder))throw Error('Existing stage preserved');fs.mkdirSync(project,{recursive:true});
 const pins=[],seen=new Set(),queue=[test];let bytes=0;
 while(queue.length){const relative=queue.shift();if(seen.has(relative))continue;seen.add(relative);if(relative.includes('..')||seen.size>700)throw Error('Unexpected literal closure');
  const file=path.join(source,relative),raw=fs.readFileSync(file);bytes+=raw.length;if(bytes>8*1024*1024)throw Error('Source closure exceeds bound');
  const to=path.join(project,relative);fs.mkdirSync(path.dirname(to),{recursive:true});fs.writeFileSync(to,raw);pins.push({relative,source:file,sha256:sha(raw)});
  if(relative.endsWith('.gd'))for(const match of raw.toString('utf8').matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']\s*\)|extends\s+["']res:\/\/([^"']+)["']/g))queue.push(match[1]??match[2]);
 }
 const relative='.cache/native-kernel/nwn-particle-kernel.dll',raw=fs.readFileSync(path.join(parent.project,relative));if(sha(raw)!==parent.nativeBinary.sha256)throw Error('Compatible DLL differs');
 fs.mkdirSync(path.join(project,'.cache/native-kernel'),{recursive:true});fs.writeFileSync(path.join(project,relative),raw);pins.push({relative,source:path.join(parent.project,relative),sha256:sha(raw)});
 const config='config_version=5\n[application]\nconfig/name="Bridge actual World Motion CPU integration"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';fs.writeFileSync(path.join(project,'project.godot'),config);pins.push({relative:'project.godot',sha256:sha(config)});
 fs.mkdirSync(path.join(project,'.godot'),{recursive:true});fs.writeFileSync(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n');
 const assetsManifest=actualAssets?path.join(source,'.cache/native-presentation-parity/loading-agent/bridge-live-assets-v1/manifest.json'):null;
 const assets=assetsManifest?JSON.parse(fs.readFileSync(assetsManifest)):null;
 if(assetsManifest&&sha(fs.readFileSync(assetsManifest))!=='e56d7625dad070cd0ed1a534c52740787d7145fad61d237c3ccb54c1f39b8f57')throw Error('Recovered asset proof differs');
 fs.writeFileSync(path.join(folder,'stage.json'),JSON.stringify({label,project,test,pins,bytes,assetsManifest,assets,parent:{file:parentFile,sha256:sha(fs.readFileSync(parentFile))},engine:parent.engine,nativeBinary:parent.nativeBinary,sharedWrites:0,serverConnections:0,nativeBuilds:0,gpuDraws:0},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({stage:true,pins:pins.length,bytes,folder}));process.exit(0);
}
const stage=JSON.parse(fs.readFileSync(path.join(folder,'stage.json'))),output=path.join(folder,'run.json');if(fs.existsSync(output))throw Error('Existing run preserved');
const changed=()=>stage.pins.filter(pin=>sha(fs.readFileSync(path.join(project,pin.relative)))!==pin.sha256).map(pin=>pin.relative);
if(changed().length||sha(fs.readFileSync(stage.engine.path))!==stage.engine.sha256)throw Error('Source or engine changed');
const results=[];
for(const mode of ['gd','compiled']){
 const directory=path.join(folder,mode);fs.mkdirSync(directory,{recursive:true});const report=path.join(directory,'result.json'),home=path.join(directory,'userdata');fs.mkdirSync(home,{recursive:true});
 const args=['--headless','--log-file',path.join(directory,'engine.log'),'--path',project,'--script','res://'+stage.test,'--','--report='+report,'--particle-kernel='+mode,...(mode==='compiled'?['--existing-kernel']:[])];
 if(stage.assetsManifest)args.push('--assets-manifest='+stage.assetsManifest,'--cache='+path.join(directory,'prepared'),'--prepared-cache-write=sync');
 const started=new Date().toISOString(),child=spawnSync(stage.engine.path,args,{cwd:root,encoding:'utf8',windowsHide:true,timeout:25000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home,NWN_PARTICLE_KERNEL:mode}});
 const stdout=child.stdout??'',stderr=child.stderr??'';fs.writeFileSync(path.join(directory,'stdout.log'),stdout,{flag:'wx'});fs.writeFileSync(path.join(directory,'stderr.log'),stderr,{flag:'wx'});
 let result=null;try{result=JSON.parse(fs.readFileSync(report));}catch{}
 const errors=(stdout+'\n'+stderr).split(/\r?\n/).filter(line=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances leaked|resources still in use|Invalid call/.test(line));
 const success=child.status===0&&!child.error&&!errors.length&&result?.success===true;
 const proof={mode,success,started,finished:new Date().toISOString(),exit:child.status,error:child.error?.message??null,errors,result};results.push(proof);fs.writeFileSync(path.join(directory,'run.json'),JSON.stringify(proof,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({mode,success,checks:result?.checks,failures:result?.failures,exit:child.status,errors,error:child.error?.message??null}));if(!success)break;
}
const sourceChanged=changed(),success=results.length===2&&results.every(row=>row.success)&&!sourceChanged.length;
fs.writeFileSync(output,JSON.stringify({success,stage:{file:path.join(folder,'stage.json'),sha256:sha(fs.readFileSync(path.join(folder,'stage.json')))},results,sourceChanged,serverConnections:0,nativeBuilds:0,gpuDraws:0},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success,completed:results.length,receipt:output}));process.exit(success?0:1);
