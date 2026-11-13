// Isolated manual trial: original login/protocol owners, copied candidate renderer.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {Script} from 'node:vm';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [capsule,run]=process.argv.slice(2);
const movementRecording=process.argv.slice(4).includes('--record-movement');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
if(!/^native-dense-light-input-[a-z0-9-]+$/.test(capsule??'')||!/^native-manual-light-input-[a-z0-9-]+$/.test(run??''))throw Error('Supply a light input capsule and fresh manual trial name');
const stage=path.join(project,'.cache/native-render-trials',run),copy=path.join(stage,'renderer');
if(fs.existsSync(stage))throw Error('Existing trial is preserved');
const sourceReceipt=path.join(project,'.cache/native-dense-area',capsule,'candidate-sources.json');
const r=JSON.parse(fs.readFileSync(sourceReceipt));
if(!r.isolatedBuildFinalized||r.variant!=='candidate'||r.sourceProject!==path.join(project,'.cache/native-dense-area',capsule,'candidate'))throw Error('Candidate build not finalized');
if(hash(fs.readFileSync(path.join(project,'systems/native_render/focus_lighting.gd')))!==r.baselineFocusSha256)throw Error('Ordinary lighting owner changed');
fs.mkdirSync(copy,{recursive:true});
const trialPins=[];
for(const pin of r.sourcePins){
 const source=path.join(r.sourceProject,pin.relative),bytes=fs.readFileSync(source);
 if(hash(bytes)!==pin.finalSha256)throw Error('Candidate source differs: '+pin.relative);
 const destination=path.join(copy,pin.relative);
 fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,bytes);
 trialPins.push({relative:pin.relative,sha256:hash(bytes)});
}
// Remove benchmark-only entry/config overrides. These are the ordinary current
// entries, including saved settings, Main Menu and click-to-activate behavior.
const entryOverrides=[];
for(const relative of ['native_live_world.gd','native_session_world.gd','project.godot']){
 const bytes=fs.readFileSync(path.join(project,relative));fs.writeFileSync(path.join(copy,relative),bytes);
 const sha256=hash(bytes);trialPins.find(p=>p.relative===relative).sha256=sha256;
 entryOverrides.push({relative,sha256,reason:'Ordinary manual session entry; no benchmark config or forced unfocus'});
}
const normalize=b=>b.toString().replaceAll('\r\n','\n');
const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('Trial overlay boundary differs');return s.replace(a,b);};
for(const relative of ['systems/native_data/movement_timing.gd','tools/native-movement-recording.mjs','tools/native-loading-recording.mjs','tools/native-loading-writer.mjs','tools/replay-native-loading.mjs','tools/native-loading-selection.mjs','tools/perf140/driver/replay_control.mjs']){
 const bytes=fs.readFileSync(path.join(project,relative));fs.mkdirSync(path.dirname(path.join(copy,relative)),{recursive:true});fs.writeFileSync(path.join(copy,relative),bytes);
 const pin=trialPins.find(p=>p.relative===relative);if(pin)pin.sha256=hash(bytes);else trialPins.push({relative,sha256:hash(bytes)});
 entryOverrides.push({relative,sha256:hash(bytes),reason:'Current optional movement capture/replay helpers; no shared native rebuild'});
}
if(movementRecording){
 let live=normalize(fs.readFileSync(path.join(copy,'native_live_world.gd')));
 live=once(live,'\t\tif not presentation_stats.failed_objects.is_empty():','\t\tif args.get("record-movement","")=="true":label.text+="\\nRECORDING: movement + network timing"\n\t\tif not presentation_stats.failed_objects.is_empty():');
 const rootBoundary='\tFrameProfile.finish("root_camera",phase_began)';
 live=once(live,rootBoundary,rootBoundary+'\n\tif args.get("record-movement","")=="true" and world.ready_for_control():\n\t\tvar movement_sample: Dictionary=preload("res://systems/native_data/movement_timing.gd").sample(keyboard_context(),keyboard,native_text_connection(),epoch,world.area_id)\n\t\tif not movement_sample.is_empty():send(movement_sample)');
 let session=normalize(fs.readFileSync(path.join(copy,'native_session_world.gd')));
 const sendBoundary='\tif not scoped.has("connection"): scoped.connection=session_connection';
 session=once(session,sendBoundary,sendBoundary+'\n\tif args.get("record-movement","")=="true" and scoped.get("kind")=="drive" and is_instance_valid(world):\n\t\tscoped.movementTrace=preload("res://systems/native_data/movement_timing.gd").sample(keyboard_context(),keyboard,session_connection,epoch,world.area_id)');
 for(const [relative,text]of [['native_live_world.gd',live],['native_session_world.gd',session]]){
  fs.writeFileSync(path.join(copy,relative),text);trialPins.find(p=>p.relative===relative).sha256=hash(Buffer.from(text));
  entryOverrides.push({relative,sha256:hash(Buffer.from(text)),reason:'Optional native movement/frame diagnostic projection only; original prediction and authoritative receive methods unchanged'});
 }
}
const originalBootstrap=path.join(project,'tools/native-session-bootstrap.cjs'),originalHost=path.join(project,'tools/native-session-host.cjs');
const originalBootstrapBytes=fs.readFileSync(originalBootstrap),originalHostBytes=fs.readFileSync(originalHost);
const hostWrapper=path.join(stage,'host-wrapper.cjs'),bootstrapWrapper=path.join(stage,'bootstrap-wrapper.cjs');
const metadata={project:copy,capsule,run,movementRecording,scope:'Isolated manual light input trial; original saved settings, login and protocol owners; no automated connection.'};
const injection='report.nativeRenderProjectOverlay='+JSON.stringify(metadata)+';\n ';
let host=once(normalize(originalHostBytes),"const executable=runtimeSelection.executable,nativeArgs=[...(engineRuntime==='editor'?['--path',project]:[])",injection+"const executable=runtimeSelection.executable,nativeArgs=[...(engineRuntime==='editor'?['--path',"+JSON.stringify(copy)+"]:[])");
if(movementRecording){
 host=once(host,"const {NativeLoadingRecording}=await import('./native-loading-recording.mjs')","const {MovementTimingRecording:NativeLoadingRecording}=await import('./native-movement-recording.mjs')");
 const attach="session=current;setupSession=null;catalogReady=false;snapshotGeneration=-1;rawPending=null;worldDeltas.reset();send({kind:'session-reset'});";
 host=once(host,attach,attach+'loadingRecording?.attach(current,connection);');
 host=once(host,'loadingRecording?.acknowledgement(message);','loadingRecording?.dispatch(message);loadingRecording?.acknowledgement(message);');
 host=once(host,'try{const message=JSON.parse(line);creationBridge',"try{const message=JSON.parse(line);if(authenticated&&message.kind==='movement-sample'){if(message.connection===lobby.connection)loadingRecording?.movementSample(message);continue;}if(authenticated)loadingRecording?.input(message);creationBridge");
 host=once(host,"if(recordLoading)nativeArgs.push('--prepared-cache='","if(!recordLoading)throw Error('Movement timing trial requires --record-loading');nativeArgs.push('--record-movement=true');\n if(recordLoading)nativeArgs.push('--prepared-cache='");
}
const bootstrap=once(normalize(originalBootstrapBytes),"path.join(__dirname,'native-session-host.cjs')",JSON.stringify(hostWrapper));
new Script(host,{filename:originalHost});new Script(bootstrap,{filename:originalBootstrap});
function wrapper(file,original,bytes,code){
 const originalSha256=hash(bytes);
 const content="const fs=require('node:fs'),crypto=require('node:crypto'),Module=require('node:module'),path=require('node:path');\nconst original="+JSON.stringify(original)+";\nif(crypto.createHash('sha256').update(fs.readFileSync(original)).digest('hex')!=="+JSON.stringify(originalSha256)+")throw Error('Original trial owner changed');\nconst owner=new Module(original,module);owner.filename=original;owner.paths=Module._nodeModulePaths(path.dirname(original));owner._compile("+JSON.stringify(code)+",original);\n";
 fs.writeFileSync(file,content,{flag:'wx'});
 return {file,sha256:hash(Buffer.from(content)),original,originalSha256,compiledTextSha256:hash(Buffer.from(code))};
}
const wrappers=[wrapper(hostWrapper,originalHost,originalHostBytes,host),wrapper(bootstrapWrapper,originalBootstrap,originalBootstrapBytes,bootstrap)];
const manifest={version:1,kind:'private-light-input-manual-trial',run,capsule,movementRecording,rendererProject:copy,sourceReceipt:{file:sourceReceipt,sha256:hash(fs.readFileSync(sourceReceipt))},trialPins,entryOverrides,wrappers,bootstrapWrapper,automatedConnections:0,sharedNativeBuilds:0,scope:metadata.scope};
const file=path.join(stage,'overlay.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,file,bootstrapWrapper,rendererProject:copy}));
