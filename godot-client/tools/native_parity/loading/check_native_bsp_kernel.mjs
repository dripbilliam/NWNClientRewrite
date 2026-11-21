// Private CPU-only native BSP extension + immutable source/original oracle.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
import {selectClientLaunchEngine,verifyClientLaunchEngine} from './client_launch_engine.mjs';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),root=path.dirname(source),[label,phase]=process.argv.slice(2),sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
if(!/^native-bsp-kernel-[a-z0-9-]+$/.test(label??'')||!['stage','run'].includes(phase))throw Error('Fresh native-bsp-kernel label and stage/run required');
const folder=path.join(source,'.cache/native-presentation-parity/loading-agent',label),project=path.join(folder,'project'),missing=path.join(folder,'missing-project'),test='tests/native_bsp_kernel_test.gd',missingTest='tests/native_bsp_kernel_unavailable_test.gd';
if(phase==='stage'){
 if(fs.existsSync(folder))throw Error('Existing evidence preserved');fs.mkdirSync(project,{recursive:true});fs.mkdirSync(missing,{recursive:true});
 const pins=[],seen=new Set(),queue=[test,missingTest];let bytes=0;
 const stageFile=(relative,raw,from,both=false)=>{const to=path.join(project,relative);fs.mkdirSync(path.dirname(to),{recursive:true});fs.writeFileSync(to,raw);pins.push({relative,source:from,sha256:sha(raw)});if(both){const other=path.join(missing,relative);fs.mkdirSync(path.dirname(other),{recursive:true});fs.writeFileSync(other,raw);}};
 while(queue.length){const relative=queue.shift();if(seen.has(relative))continue;seen.add(relative);if(relative.includes('..')||seen.size>50)throw Error('Unexpected bounded source closure');const file=path.join(source,relative),raw=fs.readFileSync(file);bytes+=raw.length;if(bytes>1024*1024)throw Error('Source closure exceeds1MiB');stageFile(relative,raw,file,true);
  if(relative.endsWith('.gd'))for(const match of raw.toString('utf8').matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']\s*\)|extends\s+["']res:\/\/([^"']+)["']/g))queue.push(match[1]??match[2]);
 }
 const buildFile=path.join(source,'.cache/native-presentation-parity/loading-agent/bsp-collector-kernel-build-v3/build.json'),buildRaw=fs.readFileSync(buildFile),build=JSON.parse(buildRaw);
 if(build.exit_code!==0||build.source_changed.length||sha(fs.readFileSync(build.binary))!==build.binary_sha256||sha(fs.readFileSync(build.descriptor))!==build.descriptor_sha256||build.sources.some(p=>sha(fs.readFileSync(p.source))!==p.sha256||sha(fs.readFileSync(p.file))!==p.sha256))throw Error('Separate kernel build/source pin differs');
 stageFile('.cache/bsp-collector-kernel/nwn-bsp-collector.dll',fs.readFileSync(build.binary),build.binary);stageFile('native/bsp_collector.gdextension',fs.readFileSync(build.descriptor),build.descriptor);
 const corpusFile=path.join(source,'.cache/native-presentation-parity/loading-agent/native-collector-oracle-v4/corpus.json'),corpusRaw=fs.readFileSync(corpusFile),corpus=JSON.parse(corpusRaw);
 if(corpus.binary_sha256!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'||corpus.source_sha256!==sha(fs.readFileSync(path.join(source,'tools/native_parity/visibility/capture_bsp_collector_oracle.py'))))throw Error('Original oracle/source pin differs');stageFile('original-corpus.json',corpusRaw,corpusFile);
 const config='config_version=5\n[application]\nconfig/name="Native BSP separate POD kernel original oracle"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';stageFile('project.godot',Buffer.from(config),null,true);
 for(const p of [project,missing]){fs.mkdirSync(path.join(p,'.godot'),{recursive:true});fs.writeFileSync(path.join(p,'.godot/global_script_class_cache.cfg'),'list=[]\n');}
 fs.writeFileSync(path.join(folder,'stage.json'),JSON.stringify({label,project,missing,test,missingTest,pins,bytes,engine:selectClientLaunchEngine(source),build:{file:buildFile,sha256:sha(buildRaw),binary_sha256:build.binary_sha256},serverConnections:0,gpuDraws:0,sharedNativeBuilds:0},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({stage:true,pins:pins.length,bytes,folder}));process.exit(0);
}
const stageFile=path.join(folder,'stage.json'),stage=JSON.parse(fs.readFileSync(stageFile)),output=path.join(folder,'run.json');if(fs.existsSync(output))throw Error('Existing receipt preserved');verifyClientLaunchEngine(stage.engine);
const changed=()=>stage.pins.filter(p=>sha(fs.readFileSync(path.join(project,p.relative)))!==p.sha256).map(p=>p.relative);
if(changed().length||sha(fs.readFileSync(stage.build.file))!==stage.build.sha256)throw Error('Staged source or build differs');
const started=new Date().toISOString(),runs=[];
for(const [tag,runProject,script] of [['native',project,test],['missing',missing,missingTest]]){
 const home=path.join(folder,'userdata-'+tag),report=path.join(folder,'result-'+tag+'.json');fs.mkdirSync(home,{recursive:true});
 const args=['--headless','--log-file',path.join(folder,'engine-'+tag+'.log'),'--path',runProject,'--script','res://'+script,'--','--report='+report,'--oracle='+path.join(project,'original-corpus.json')];
 const child=spawnSync(stage.engine.path,args,{cwd:root,encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home,NWN_PARTICLE_KERNEL:'gd'}}),stdout=child.stdout??'',stderr=child.stderr??'';fs.writeFileSync(path.join(folder,'stdout-'+tag+'.log'),stdout,{flag:'wx'});fs.writeFileSync(path.join(folder,'stderr-'+tag+'.log'),stderr,{flag:'wx'});
 const errors=(stdout+'\n'+stderr).split(/\r?\n/).filter(l=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances leaked|resources still in use|Invalid call/.test(l));let result=null;try{result=JSON.parse(fs.readFileSync(report));}catch{}runs.push({tag,exit:child.status,error:child.error?.message??null,errors,result,success:child.status===0&&!child.error&&!errors.length&&result?.success===true});
}
const sourceChanged=changed(),liveSourceChanged=stage.pins.filter(p=>p.source&&sha(fs.readFileSync(p.source))!==p.sha256).map(p=>p.relative),success=runs.every(r=>r.success)&&!sourceChanged.length&&!liveSourceChanged.length;
fs.writeFileSync(output,JSON.stringify({success,started,finished:new Date().toISOString(),runs,stage:{file:stageFile,sha256:sha(fs.readFileSync(stageFile))},sourceChanged,liveSourceChanged,serverConnections:0,gpuDraws:0,sharedNativeBuilds:0},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success,runs:runs.map(r=>({tag:r.tag,checks:r.result?.checks,failures:r.result?.failures,exit:r.exit,error:r.error,errors:r.errors})),liveSourceChanged,receipt:output}));process.exit(success?0:1);
