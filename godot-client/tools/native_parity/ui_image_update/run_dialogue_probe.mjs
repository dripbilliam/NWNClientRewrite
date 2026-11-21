// Actual full NPC dialogue acceptance from the immutable 363-check fixture.
// Private copies only. No production UI, shared imports or native rebuild.
import fs from 'node:fs/promises';import path from 'node:path';import crypto from 'node:crypto';import {spawn} from 'node:child_process';import {fileURLToPath} from 'node:url';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),[label,role,descriptorArg]=process.argv.slice(2);
if(!/^image-dialogue-[a-z0-9-]+$/.test(label??'')||!['baseline','candidate'].includes(role)||!descriptorArg)throw Error('Fresh image-dialogue label baseline/candidate explicit private engine descriptor required');
const hash=v=>crypto.createHash('sha256').update(v).digest('hex'),descriptorFile=path.resolve(descriptorArg),descriptorBytes=await fs.readFile(descriptorFile),descriptor=JSON.parse(descriptorBytes),engine=descriptor.engines[role];
if(hash(await fs.readFile(engine.path))!==engine.sha256)throw Error('Engine binary drift');
const parent=path.join(source,'.cache/native-presentation-parity/loading-agent/conversation-integrated-pixels-required-v2'),stageFile=path.join(parent,'stage.json'),stageRaw=await fs.readFile(stageFile),stage=JSON.parse(stageRaw);
if(hash(stageRaw)!=='d64b73a2f24f5fc6172d94e0391d5fea0b9e337d2a47d0491cd2e5df30f39588')throw Error('Full dialogue fixture parent changed');
const folder=path.join(source,'.cache/native-presentation-parity/particles-agent',label),project=path.join(folder,'project');await fs.mkdir(folder,{recursive:false});await fs.mkdir(project);const pins=[];
for(const pin of stage.pins){
 const original=path.join(stage.project,pin.relative),raw=await fs.readFile(original);if(hash(raw)!==pin.sha256)throw Error('Frozen parent differs: '+pin.relative);let bytes=raw;
 if(pin.relative===stage.test){
  if(pin.sha256!=='0119af473e33cfe5be84c4dcae063f25a3590d6e6aca4225a026276e1999d509')throw Error('Full required pixel fixture differs');
  let code=raw.toString('utf8');
  const oldMonitor='root.current_screen==2 and root.unfocusable';if(code.split(oldMonitor).length!==2)throw Error('Monitor assertion changed');
  code=code.replace(oldMonitor,'root.current_screen==1 and root.current_screen!=DisplayServer.get_primary_screen() and root.unfocusable').replace('secondary2 without activation','nonprimary1 without activation');
  const start='func inspect(tag: String,visible_only: bool=false) -> void:';if(code.split(start).length!==2)throw Error('Inspect timing seam changed');
  code=code.replace(start,start+'\n\tvar phase_began:=Time.get_ticks_usec()').replace('states.append({"tag":tag,','states.append({"tag":tag,"fixture_phase_us":Time.get_ticks_usec()-phase_began,');bytes=Buffer.from(code);
 }else if(pin.relative==='project.godot'){
  let code=raw.toString('utf8');if(!code.includes('window/size/initial_screen=2'))throw Error('Initial screen configuration changed');bytes=Buffer.from(code.replace('window/size/initial_screen=2','window/size/initial_screen=1'));
 }
 const dest=path.join(project,pin.relative);await fs.mkdir(path.dirname(dest),{recursive:true});await fs.writeFile(dest,bytes,{flag:'wx'});pins.push({relative:pin.relative,parent_sha256:pin.sha256,sha256:hash(bytes),source:original});
}
await fs.mkdir(path.join(project,'.godot'),{recursive:true});await fs.writeFile(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n');
for(const pin of stage.resourcePins??[])if(hash(await fs.readFile(pin.file))!==pin.sha256)throw Error('Original profile override changed');
const parseOnly=process.argv.includes('--check-only');
const userdata=path.join(folder,'userdata');await fs.mkdir(userdata);const report=path.join(folder,'result.json'),args=[...(parseOnly?['--headless','--check-only']:['--render-thread','separate','--rendering-method','forward_plus','--screen','1']),'--log-file',path.join(folder,'engine.log'),'--path',project,'--script','res://'+stage.test,'--','--report='+report,'--install='+stage.install,'--cache='+path.join(folder,'prepared'),'--prepared-cache-write=sync','--particle-kernel=gd',...(stage.override?['--override='+stage.override]:[])];
const proof={label,role,parent_stage:stageFile,parent_sha256:hash(stageRaw),project,pins,engine,engine_descriptor:descriptorFile,engine_descriptor_sha256:hash(descriptorBytes),args,network_connections:0,native_builds:0,performance_claim:false,latency_scope:'Functional whole-dialogue fixture phases including image readback/comparison, not FPS or render timing',started:new Date().toISOString()};await fs.writeFile(path.join(folder,'stage.json'),JSON.stringify(proof,null,2));
const child=spawn(engine.path,args,{cwd:project,windowsHide:true,env:{...process.env,APPDATA:userdata,LOCALAPPDATA:userdata}});console.log(JSON.stringify({started:true,pid:child.pid,folder,role}));let stdout='',stderr='';child.stdout.on('data',v=>stdout+=v);child.stderr.on('data',v=>stderr+=v);const started=Date.now(),closed=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',(code,signal)=>resolve({code,signal}));});
await fs.writeFile(path.join(folder,'stdout.log'),stdout);await fs.writeFile(path.join(folder,'stderr.log'),stderr);let result=null;try{result=JSON.parse(await fs.readFile(report));}catch{}
const errors=(stdout+'\n'+stderr).split(/\r?\n/).filter(v=>/^ERROR:|SCRIPT ERROR|Parse Error|leaked|resources still in use/.test(v)),changed=[];for(const pin of pins){if(hash(await fs.readFile(path.join(project,pin.relative)))!==pin.sha256)changed.push(pin.relative);if(hash(await fs.readFile(pin.source))!==pin.parent_sha256)changed.push(pin.source);}
const resourceChanged=[];for(const pin of stage.resourcePins??[])if(hash(await fs.readFile(pin.file))!==pin.sha256)resourceChanged.push(pin.file);
const out={...proof,...closed,parseOnly,wall_ms:Date.now()-started,finished:new Date().toISOString(),errors,result,source_changed:changed,resource_changed:resourceChanged,engine_changed:hash(await fs.readFile(engine.path))!==engine.sha256};out.success=closed.code===0&&(parseOnly||result?.success===true)&&!errors.length&&!changed.length&&!resourceChanged.length&&!out.engine_changed;await fs.writeFile(path.join(folder,'run.json'),JSON.stringify(out,null,2));console.log(JSON.stringify({success:out.success,error_count:errors.length,errors:[...new Set(errors)],checks:result?.checks,failures:result?.failures,...closed,wall_ms:out.wall_ms,receipt:path.join(folder,'run.json')}));process.exitCode=out.success?0:1;
