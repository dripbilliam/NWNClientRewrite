// Two phase, fresh isolated CPU-only motion notification and retained native-oracle checks.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),root=path.dirname(source),[label,phase]=process.argv.slice(2);
if(!/^motion-position-boundary-[a-z0-9-]+$/.test(label??'')||!['stage','run'].includes(phase))throw Error('Fresh motion-position-boundary label and stage/run required');
const folder=path.join(source,'.cache/native-presentation-parity/loading-agent',label),project=path.join(folder,'project'),stageFile=path.join(folder,'stage.json');
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const parentFile=path.join(source,'.cache/native-presentation-parity/loading-agent/parity-launch-seven-fixes-v3/manifest.json');
if(sha(fs.readFileSync(parentFile))!=='9ac19296443bbef4e6115956cd3349952d8c1246ea85a1cff0ccaab6905bad59')throw Error('Immutable approved parent differs');
if(phase==='stage'){
 if(fs.existsSync(folder))throw Error('Existing stage preserved');
 const parent=JSON.parse(fs.readFileSync(parentFile)),engine={path:parent.engine.path,sha256:parent.engine.sha256};
 if(engine.sha256!=='62f54a7f7ff4638987730a246833cea4054779e7cb2a333bb5921fd5b0aea6dc'||sha(fs.readFileSync(engine.path))!==engine.sha256)throw Error('Approved engine differs');
 fs.mkdirSync(project,{recursive:true});
 const pins=[];
 const copy=(from,to)=>{const raw=fs.readFileSync(from);fs.mkdirSync(path.dirname(to),{recursive:true});fs.writeFileSync(to,raw,{flag:'wx'});pins.push({source:from,target:to,sha256:sha(raw),bytes:raw.length});};
 for(const relative of ['systems/network_motion.gd','tests/native_motion_position_boundary_test.gd','tests/network_motion_test.gd'])copy(path.join(source,relative),path.join(project,relative));
 for(const name of ['native-network-motion-observations.json','native-network-facing-observations.json','native-network-facing-stalls-observations.json','native-network-gait-observations.json'])copy(path.join(root,'backups/animations',name),path.join(folder,'backups/animations',name));
 const config='config_version=5\n[application]\nconfig/name="Isolated native motion position boundary"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
 fs.writeFileSync(path.join(project,'project.godot'),config,{flag:'wx'});
 fs.mkdirSync(path.join(project,'.godot'));fs.writeFileSync(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n',{flag:'wx'});
 const backupFile=path.join(source,'.cache/native-presentation-parity/loading-agent/motion-boundary-recovery-before-v1/network_motion.gd');
 fs.writeFileSync(stageFile,JSON.stringify({label,project,engine,parent:{file:parentFile,sha256:sha(fs.readFileSync(parentFile))},backup:{file:backupFile,sha256:sha(fs.readFileSync(backupFile))},pins,configSha256:sha(config),extensions:0,autoloads:0,assets:0,serverConnections:0,nativeBuilds:0,gpuDraws:0},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({staged:true,label,pins:pins.length,bytes:pins.reduce((total,pin)=>total+pin.bytes,0),stageFile}));
 process.exit(0);
}
const stage=JSON.parse(fs.readFileSync(stageFile)),output=path.join(folder,'run.json');
if(fs.existsSync(output))throw Error('Existing run preserved');
const changed=()=>stage.pins.filter(pin=>sha(fs.readFileSync(pin.source))!==pin.sha256||sha(fs.readFileSync(pin.target))!==pin.sha256).map(pin=>pin.source);
if(changed().length||sha(fs.readFileSync(stage.engine.path))!==stage.engine.sha256||sha(fs.readFileSync(path.join(project,'project.godot')))!==stage.configSha256)throw Error('Source/engine/config differs');
const results=[];
for(const [name,test] of [['boundary','native_motion_position_boundary_test.gd'],['native-oracle','network_motion_test.gd']]){
 const directory=path.join(folder,name);fs.mkdirSync(directory);const report=path.join(directory,'result.json'),home=path.join(directory,'userdata');fs.mkdirSync(home);
 const args=['--headless','--log-file',path.join(directory,'engine.log'),'--path',project,'--script','res://tests/'+test,'--','--report='+report];
 const started=new Date().toISOString(),child=spawnSync(stage.engine.path,args,{cwd:root,windowsHide:true,encoding:'utf8',timeout:20000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home}});
 const stdout=child.stdout??'',stderr=child.stderr??'';fs.writeFileSync(path.join(directory,'stdout.log'),stdout,{flag:'wx'});fs.writeFileSync(path.join(directory,'stderr.log'),stderr,{flag:'wx'});
 let result=null;try{result=JSON.parse(fs.readFileSync(report));}catch{}
 const errors=(stdout+'\n'+stderr).split(/\r?\n/).filter(line=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances (?:were )?leaked|resources still in use|Invalid call/.test(line));
 const success=child.status===0&&!child.error&&!errors.length&&result?.success===true;
 const proof={name,success,started,finished:new Date().toISOString(),exit:child.status,error:child.error?.message??null,errors,result};results.push(proof);
 fs.writeFileSync(path.join(directory,'run.json'),JSON.stringify(proof,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({name,success,checks:result?.checks,failures:result?.failures,exit:child.status,errors,error:child.error?.message??null}));
 if(!success)break;
}
const sourceChanged=changed(),success=results.length===2&&results.every(row=>row.success)&&!sourceChanged.length;
fs.writeFileSync(output,JSON.stringify({success,stage:{file:stageFile,sha256:sha(fs.readFileSync(stageFile))},engine:stage.engine,results,sourceChanged,extensions:0,autoloads:0,assets:0,serverConnections:0,nativeBuilds:0,gpuDraws:0},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success,receipt:output}));process.exit(success?0:1);
