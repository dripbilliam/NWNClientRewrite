// Private exact historical NPC-model fixture over immutable V5 production bytes.
// No login/server/build/current production fallback or performance measurement.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {verifyClientLaunchEngine} from '../loading/client_launch_engine.mjs';
import {verifyClientLaunchDisplay} from '../loading/client_launch_proofs.mjs';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),[label,phase]=process.argv.slice(2);
if(!/^claddath-ghost-v5-[a-z0-9-]+$/.test(label??'')||!['stage','parse','assets','run'].includes(phase))throw Error('Fresh owned label and stage/parse/assets/run required');
const hash=raw=>crypto.createHash('sha256').update(raw).digest('hex'),capsuleFile=path.join(source,'.cache/native-presentation-parity/loading-agent/parity-launch-seven-fixes-v5/manifest.json'),capsuleRaw=await fs.readFile(capsuleFile);
if(hash(capsuleRaw)!=='8f3aa790475964504558c2be9e7e61f84c5725f5e6e5c106e7f150fa12bc6b2a')throw Error('Immutable V5 differs');
const capsule=JSON.parse(capsuleRaw),folder=path.join(source,'.cache/native-presentation-parity/loading-agent',label),project=path.join(folder,'project'),stageFile=path.join(folder,'stage.json');
verifyClientLaunchEngine(capsule.engine);verifyClientLaunchDisplay(capsule.launch.display);
const capsuleChanges=async()=>{const changed=[];for(const pin of capsule.pins)if(hash(await fs.readFile(path.join(capsule.project,pin.relative)))!==pin.sha256)changed.push(pin.relative);return changed;};
if(phase==='stage'){
 if((await capsuleChanges()).length)throw Error('Capsule source changed');
 await fs.mkdir(folder,{recursive:false});await fs.mkdir(project);const pins=[];
 for(const pin of capsule.pins){
  if(pin.relative==='project.godot')continue;const from=path.join(capsule.project,pin.relative),raw=await fs.readFile(from),to=path.join(project,pin.relative);
  await fs.mkdir(path.dirname(to),{recursive:true});await fs.writeFile(to,raw,{flag:'wx'});pins.push({relative:pin.relative,source:from,sha256:pin.sha256});
 }
 const tests=['tests/native_claddath_ghost_highlight_test.gd','tests/native_parity_highlight_registry_actor_render_test.gd'];
 for(const relative of tests){const from=path.join(source,relative),raw=await fs.readFile(from),to=path.join(project,relative);if(relative===tests[1]&&hash(raw)!=='9c73f3a598d08e9882295b6bc80c6475c09abe5677b9f3da54aaa81b83fe83c5')throw Error('Original helper fixture differs');await fs.mkdir(path.dirname(to),{recursive:true});await fs.writeFile(to,raw,{flag:'wx'});pins.push({relative,source:from,sha256:hash(raw),fixture:true});}
 const evidenceFile=path.join(source,'.cache/native-presentation-parity/loading-agent/claddath-ghost-assets-v1/evidence.json'),evidenceRaw=await fs.readFile(evidenceFile);
 if(hash(evidenceRaw)!=='8f9e41482a28c0e3e0af1d7416669aa89a88db6634f0f2086222a8e2483c762f')throw Error('Historical NPC/model evidence differs');
 const screen=capsule.launch.display.screen,config='config_version=5\n[application]\nconfig/name="Historical Claddath Fleshwarp native highlight"\n[display]\nwindow/size/viewport_width=1200\nwindow/size/viewport_height=900\nwindow/size/no_focus=true\nwindow/size/initial_position_type=3\nwindow/size/initial_screen='+screen+'\nwindow/vsync/vsync_mode=1\n[rendering]\nrenderer/rendering_method="forward_plus"\n';
 await fs.writeFile(path.join(project,'project.godot'),config,{flag:'wx'});pins.push({relative:'project.godot',sha256:hash(config),fixture:true});
 await fs.mkdir(path.join(project,'.godot'),{recursive:true});if(!pins.some(pin=>pin.relative==='.godot/global_script_class_cache.cfg'))await fs.writeFile(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n',{flag:'wx'});
 const stage={capsule:{file:capsuleFile,sha256:hash(capsuleRaw)},project,pins,engine:capsule.engine,display:capsule.launch.display,evidence:{file:evidenceFile,sha256:hash(evidenceRaw)},evidenceValue:JSON.parse(evidenceRaw),entry:tests[0],install:path.resolve(source,'../../FullDecomp/NwnRootInstall'),expectedChecks:{assets:6,run:27},serverConnections:0,nativeBuilds:0,performanceClaim:false};
 await fs.writeFile(stageFile,JSON.stringify(stage,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({staged:true,folder,pins:pins.length,screen,entry:tests[0]}));process.exit(0);
}
const stageRaw=await fs.readFile(stageFile),stage=JSON.parse(stageRaw),receipt=path.join(folder,phase+'.json');
try{await fs.access(receipt);throw Error('Existing receipt preserved');}catch(error){if(error.code!=='ENOENT')throw error;}
if(phase==='run'&&!process.argv.includes('--graphics-authorized'))throw Error('Root-coordinated explicit graphics authorization required');
const changed=async()=>{const names=[];for(const pin of stage.pins){if(hash(await fs.readFile(path.join(project,pin.relative)))!==pin.sha256||pin.source&&hash(await fs.readFile(pin.source))!==pin.sha256)names.push(pin.relative);}return names;};
if(stage.capsule.sha256!==hash(capsuleRaw)||(await changed()).length||(await capsuleChanges()).length||hash(await fs.readFile(stage.evidence.file))!==stage.evidence.sha256)throw Error('Staged fixture/capsule/evidence changed');
const userdata=path.join(folder,phase+'-userdata');await fs.mkdir(userdata);const report=path.join(folder,phase+'-result.json');
const args=[...(phase==='parse'?['--headless','--check-only']:phase==='assets'?['--headless']:['--render-thread','separate','--rendering-method','forward_plus','--screen',String(stage.display.screen)]),'--log-file',path.join(folder,phase+'.engine.log'),'--path',project,'--script','res://'+stage.entry,'--','--report='+report,'--install='+stage.install,'--expected-screen='+stage.display.screen,'--highlight-kernel=compiled','--particle-kernel=compiled','--model-storage=native',...(phase==='assets'?['--asset-only']:[])];
const child=spawn(stage.engine.path,args,{cwd:project,windowsHide:true,env:{...process.env,APPDATA:userdata,LOCALAPPDATA:userdata,NWN_PARTICLE_KERNEL:'compiled'}});console.log(JSON.stringify({started:true,pid:child.pid,phase,folder}));let stdout='',stderr='',timedOut=false;child.stdout.on('data',raw=>stdout+=raw);child.stderr.on('data',raw=>stderr+=raw);
const timer=setTimeout(()=>{timedOut=true;child.kill();},120000),closed=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',(code,signal)=>resolve({code,signal}));});clearTimeout(timer);
await fs.writeFile(path.join(folder,phase+'.stdout.log'),stdout,{flag:'wx'});await fs.writeFile(path.join(folder,phase+'.stderr.log'),stderr,{flag:'wx'});
let result=null;try{result=JSON.parse(await fs.readFile(report));}catch{}
const errors=(stdout+'\n'+stderr).split(/\r?\n/).filter(line=>/^ERROR:|SCRIPT ERROR|Parse Error|ObjectDB.*leak|resources still in use/.test(line)),sourceChanged=await changed(),capsuleChanged=await capsuleChanges();
const originalChanged=[];for(const pin of stage.evidenceValue.keyPins)if(hash(await fs.readFile(pin.file))!==pin.sha256)originalChanged.push(pin.file);
const success=closed.code===0&&!timedOut&&!errors.length&&!sourceChanged.length&&!capsuleChanged.length&&!originalChanged.length&&(phase==='parse'||result?.success===true&&result?.checks===stage.expectedChecks[phase]);
const proof={success,...closed,phase,timedOut,stage:{file:stageFile,sha256:hash(stageRaw)},capsule:stage.capsule,evidence:stage.evidence,engine:stage.engine,display:stage.display,args,errors,sourceChanged,capsuleChanged,originalChanged,result,serverConnections:0,nativeBuilds:0,performanceClaim:false};
await fs.writeFile(receipt,JSON.stringify(proof,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success,phase,checks:result?.checks,failures:result?.failures,errors,sourceChanged,capsuleChanged,originalChanged,receipt}));process.exitCode=success?0:1;
