// Isolated native tile-fog owner/material gate. No network, GPU or native build.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),root=path.dirname(source),[label,phase]=process.argv.slice(2);
if(!/^native-tile-fog-[a-z0-9-]+$/.test(label??'')||!['stage','run'].includes(phase))throw Error('Fresh native-tile-fog label and stage/run required');
const folder=path.join(source,'.cache/native-presentation-parity/loading-agent',label),project=path.join(folder,'project'),test='tests/native_tile_fog_test.gd',sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const parentFile=path.join(source,'.cache/native-presentation-parity/loading-agent/parity-launch-seven-fixes-v2/manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
if(sha(fs.readFileSync(parentFile))!=='c82135844d8e779d8dc930f89a9eb626317844b0e65d921633f1461169f8b59b')throw Error('Compatible engine witness differs');
if(phase==='stage'){
 if(fs.existsSync(folder))throw Error('Existing evidence preserved');fs.mkdirSync(project,{recursive:true});
 const pins=[],seen=new Set(),queue=[test];let bytes=0;
 while(queue.length){const relative=queue.shift();if(seen.has(relative))continue;seen.add(relative);if(relative.includes('..')||seen.size>700)throw Error('Unexpected bounded literal closure');
  const file=path.join(source,relative),raw=fs.readFileSync(file);bytes+=raw.length;if(bytes>8*1024*1024)throw Error('Source closure exceeds8MiB');
  const to=path.join(project,relative);fs.mkdirSync(path.dirname(to),{recursive:true});fs.writeFileSync(to,raw);pins.push({relative,source:file,sha256:sha(raw)});
  if(relative.endsWith('.gd'))for(const match of raw.toString('utf8').matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']\s*\)|extends\s+["']res:\/\/([^"']+)["']/g))queue.push(match[1]??match[2]);
 }
 const config='config_version=5\n[application]\nconfig/name="Native tile fog actual owner CPU gate"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';fs.writeFileSync(path.join(project,'project.godot'),config);pins.push({relative:'project.godot',sha256:sha(config)});
 fs.mkdirSync(path.join(project,'.godot'),{recursive:true});fs.writeFileSync(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n');
 fs.writeFileSync(path.join(folder,'stage.json'),JSON.stringify({label,project,test,pins,bytes,engine:parent.engine,parent:{file:parentFile,sha256:sha(fs.readFileSync(parentFile))},serverConnections:0,gpuDraws:0,nativeBuilds:0},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({stage:true,pins:pins.length,bytes,folder}));process.exit(0);
}
const stage=JSON.parse(fs.readFileSync(path.join(folder,'stage.json'))),output=path.join(folder,'run.json');if(fs.existsSync(output))throw Error('Existing receipt preserved');
const changed=()=>stage.pins.filter(p=>sha(fs.readFileSync(path.join(project,p.relative)))!==p.sha256).map(p=>p.relative);
if(changed().length||sha(fs.readFileSync(stage.engine.path))!==stage.engine.sha256)throw Error('Staged source or engine differs');
const home=path.join(folder,'userdata'),report=path.join(folder,'result.json');fs.mkdirSync(home,{recursive:true});
const args=['--headless','--log-file',path.join(folder,'engine.log'),'--path',project,'--script','res://'+stage.test,'--','--report='+report];
const started=new Date().toISOString(),child=spawnSync(stage.engine.path,args,{cwd:root,encoding:'utf8',windowsHide:true,timeout:15000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home,NWN_PARTICLE_KERNEL:'gd'}});
const stdout=child.stdout??'',stderr=child.stderr??'';fs.writeFileSync(path.join(folder,'stdout.log'),stdout,{flag:'wx'});fs.writeFileSync(path.join(folder,'stderr.log'),stderr,{flag:'wx'});
const errors=(stdout+'\n'+stderr).split(/\r?\n/).filter(l=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances leaked|resources still in use|Invalid call/.test(l));let result=null;try{result=JSON.parse(fs.readFileSync(report));}catch{}
const sourceChanged=changed(),liveSourceChanged=stage.pins.filter(p=>p.source&&sha(fs.readFileSync(p.source))!==p.sha256).map(p=>p.relative),success=child.status===0&&!child.error&&!errors.length&&result?.success===true&&!sourceChanged.length;
fs.writeFileSync(output,JSON.stringify({success,started,finished:new Date().toISOString(),exit:child.status,error:child.error?.message??null,errors,result,stage:{file:path.join(folder,'stage.json'),sha256:sha(fs.readFileSync(path.join(folder,'stage.json')))},sourceChanged,liveSourceChanged,serverConnections:0,gpuDraws:0,nativeBuilds:0},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success,checks:result?.checks,failures:result?.failures,exit:child.status,error:child.error?.message??null,errors,liveSourceChanged,receipt:output}));process.exit(success?0:1);
