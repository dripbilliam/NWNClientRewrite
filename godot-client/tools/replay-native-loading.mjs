// Offline transport replay only. Native Godot selects/decodes/builds everything.
// No game network/installed resolver module is imported. The sole socket is a
// private IPv4 loopback transport to the owned Godot child.
import fs from 'node:fs/promises';import path from 'node:path';import os from 'node:os';import net from 'node:net';import {spawn} from 'node:child_process';import {createHash,randomBytes} from 'node:crypto';import {fileURLToPath} from 'node:url';
import {ackKey,ackKinds,frameKinds} from './native-loading-recording.mjs';
import {selectGeneration} from './native-loading-selection.mjs';
import {movementEventKinds,validMovementEvent,MovementReplayClock} from './native-movement-recording.mjs';
import {replayFinishAcknowledgment} from './perf140/driver/replay_control.mjs';
import {engineReadReportAcceptance} from './perf140/driver/engine_read_acceptance.mjs';
import {terrainHeightAcceptance,terrainHeightMode} from './perf140/driver/terrain_height_acceptance.mjs';
import {readReplayClientCapsule,validateReplayCapsuleOptions,readReplayProductionSelection,validateReplayProductionOptions} from './native_parity/performance/replay_client_capsule.mjs';
import {resolveReplayDisplay,applyReplayDisplay,verifyProductionReplayWindow} from './native_parity/performance/replay_display.mjs';
import {NativeReplayDiagnostics} from './native-replay-diagnostics.mjs';
import {deriveReplayCameraExpectation,verifyReplayCameraEvidence,verifyReplayProjection} from './native-replay-camera-evidence.mjs';
import {createReadStream} from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url),featureManifest=require('./native-feature-manifest.cjs');
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const arg=name=>process.argv.find(x=>x.startsWith('--'+name+'='))?.slice(name.length+3);
const productionSelection=await readReplayProductionSelection(arg('production-selection'),arg('production-selection-sha256'),project);
if(productionSelection&&(arg('client-capsule')||arg('client-capsule-sha256')))throw Error('Choose production or legacy capsule selection');
const clientCapsule=productionSelection??readReplayClientCapsule(arg('client-capsule'),arg('client-capsule-sha256'),project);
if(productionSelection)validateReplayProductionOptions(productionSelection,arg,project);else validateReplayCapsuleOptions(clientCapsule,arg);
const debuggerVm=process.argv.includes('--debugger-vm-fields');
if(debuggerVm&&(!process.argv.includes('--debugger')||!clientCapsule))throw Error('VM crash localization requires the pinned capsule and owned debugger replay');
const sourceProject=clientCapsule?.sourceProject??(arg('source-project')?path.resolve(arg('source-project')):project);
const profiling=arg('profiling')??productionSelection?.profiling??'true';
const renderingMethod=arg('rendering-method')??'forward_plus';
if(!['forward_plus','mobile'].includes(renderingMethod))throw Error('Unsupported explicit replay rendering method');
if(!['true','false'].includes(profiling))throw Error('Invalid explicit profiling policy');
const observeProfile=arg('observe-profile')??'false';
if(!['true','false'].includes(observeProfile)||observeProfile==='true'&&profiling!=='true')throw Error('Profile observations require explicit detailed profiling');
const particleEngineReads=arg('particle-engine-reads')??'ordinary';
if(!['ordinary','eligibility','full'].includes(particleEngineReads))throw Error('Invalid synchronous particle engine-read mode');
const terrainHeight=terrainHeightMode(arg('terrain-height'));
const tcpNoDelay=arg('tcp-no-delay')??'false';
if(!['true','false'].includes(tcpNoDelay))throw Error('Invalid loopback TCP policy');
const directory=path.resolve(arg('capture')??'');if(!arg('capture'))throw Error('Explicit sealed native loading recording required');
const run=arg('run')??'native-loading-replay-'+Date.now();if(!/^[a-z0-9-]+$/.test(run))throw Error('Invalid replay name');
if((await fs.readdir(path.join(project,'reports'))).some(name=>name.startsWith(run+'.')))throw Error('Existing replay artifacts are preserved; use a fresh run label');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
export async function readRecording(root){
 const manifest=JSON.parse(await fs.readFile(path.join(root,'recording.json'),'utf8'));
 if(manifest.version!==1||manifest.complete!==true||!Array.isArray(manifest.catalogs))throw Error('Loading recording is incomplete or unsupported');
 const timeline=await fs.readFile(path.join(root,'timeline.jsonl'));if(timeline.length>256*1024*1024||sha(timeline)!==manifest.timelineSha256)throw Error('Loading timeline checksum/bound differs');
 const catalogs=new Set();for(const item of manifest.catalogs){if(!/^catalog-[0-9]+$/.test(item.directory))throw Error('Invalid catalog directory');const bytes=await fs.readFile(path.join(root,item.directory,'manifest.json'));if(sha(bytes)!==item.sha256)throw Error('Catalog manifest checksum differs');const data=JSON.parse(bytes);if(data.complete!==true||data.version!==2)throw Error('Incomplete native resources');catalogs.add(item.directory);}
 let sequence=0,at=-1;const records=[];for(const line of timeline.toString('utf8').trim().split('\n')){
  if(Buffer.byteLength(line)>1024*1024+4096)throw Error('Replay frame exceeds bound');const row=JSON.parse(line);
  if(!Number.isSafeInteger(row.sequence)||row.sequence<=sequence||!Number.isFinite(row.at)||row.at<at)throw Error('Invalid replay ordering');sequence=row.sequence;at=row.at;
  if(row.kind==='frame'){if(!frameKinds.has(row.value?.kind))throw Error('Unsupported native frame');if(row.value.kind==='setup'&&!catalogs.has(row.value.resourceSources?.recordedCatalog))throw Error('Setup references an unknown captured catalog');}
  else if(row.kind==='acknowledgement'){if(!ackKinds.has(row.value?.kind))throw Error('Unsupported native acknowledgement');}
  else if(movementEventKinds.has(row.kind)){if(manifest.metadata?.movementTiming!==true||!validMovementEvent(row.kind,row.value))throw Error('Invalid movement timing event');}
  else if(!['view','baseline'].includes(row.kind))throw Error('Unsupported recording event');records.push(row);
 }
 if(records.length!==manifest.events)throw Error('Recording event count differs');return{manifest,records};
}
if(process.argv.includes('--verify-only')){const result=await readRecording(directory);console.log(JSON.stringify({complete:true,events:result.records.length,catalogs:result.manifest.catalogs.length,networkConnections:0}));process.exit(0);}
const opened=await readRecording(directory),manifest=opened.manifest,records=arg('generation')?selectGeneration(opened.records,Number(arg('generation'))):opened.records;
const movementTiming=process.argv.includes('--movement-timing'),movementClock=new MovementReplayClock();
if(movementTiming&&manifest.metadata?.movementTiming!==true)throw Error('Movement timing replay requires a movement capture');
const cameraExpectation=productionSelection&&movementTiming?deriveReplayCameraExpectation(records,productionSelection.cameraPolicy.fovDegrees):null;
if(cameraExpectation?.status==='unavailable')throw Error('Production camera/motion expectation unavailable: '+cameraExpectation.errors.join('; '));
const sourceSha256={};async function pinSources(folder){for(const entry of await fs.readdir(folder,{withFileTypes:true})){const file=path.join(folder,entry.name);if(entry.isDirectory())await pinSources(file);else if(/\.(gd|cpp|hpp|gdextension)$/.test(entry.name))sourceSha256[path.relative(sourceProject,file)]=sha(await fs.readFile(file));}}
await pinSources(path.join(sourceProject,'systems'));await pinSources(path.join(sourceProject,'native'));for(const name of ['project.godot','native_live_world.gd','native_session_world.gd'])sourceSha256[name]=sha(await fs.readFile(path.join(sourceProject,name)));
const driverSources={};for(const name of ['replay-native-loading.mjs','native-replay-diagnostics.mjs','native-replay-camera-evidence.mjs','native-loading-recording.mjs','native-loading-selection.mjs','native-movement-recording.mjs','perf140/driver/replay_control.mjs','perf140/driver/engine_read_acceptance.mjs','perf140/driver/terrain_height_acceptance.mjs','native_parity/performance/replay_client_capsule.mjs','native_parity/performance/replay_display.mjs','native-window-screen.ps1','native-render-configuration.cjs'])driverSources[name]=sha(await fs.readFile(path.join(project,'tools',name)));
if(productionSelection)for(const name of ['native-production-selection.cjs','native-feature-manifest.cjs','native-client-flags.cjs','native-loading-pipeline.cjs','native-performance-runtime.cjs','native-engine-runtime.cjs'])driverSources[name]=sha(await fs.readFile(path.join(project,'tools',name)));
const engineMode=arg('engine')??(productionSelection?'production-selection':clientCapsule?'client-capsule':'debug');if(!['debug','release','custom-pristine','custom-patched','custom-scene','custom-builtin','client-capsule','production-selection'].includes(engineMode)||Boolean(clientCapsule)!==['client-capsule','production-selection'].includes(engineMode)||Boolean(productionSelection)!==(engineMode==='production-selection'))throw Error('Invalid explicit engine mode');
let engineFile=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),runtimeRoot=sourceProject,releasePackage=null,releaseReceipt=null;
if(clientCapsule)engineFile=clientCapsule.engine;
let customDescriptor=null;
let sceneEngineFiles={};
if(engineMode==='custom-scene'||engineMode==='custom-builtin'){
 const label=arg('custom-engine-descriptor'),validLabel=engineMode==='custom-scene'?/^engine-scene-[a-z0-9-]+$/:/^engine-(builtin|pushed)-[a-z0-9-]+$/;if(!validLabel.test(label??'')&&!(engineMode==='custom-builtin'&&label==='engine-synchronous-particle-reads-v2'))throw Error('Explicit optional-builtin engine descriptor required');
 customDescriptor=path.join(project,'.cache/native-140fps/render-agent',label,'engine-descriptor.json');const d=JSON.parse(await fs.readFile(customDescriptor)),entry=d.engines?.candidate,base=d.engines?.baseline;
 if(d.version!==1||d.retainedPairedEnginesUnchanged!==true||d.sharedOutputsUnchanged!==true||entry?.buildExitCode!==0||entry?.sourceUnchanged!==true||!path.resolve(entry.path).startsWith(path.dirname(customDescriptor)+path.sep)||sha(await fs.readFile(entry.path))!==entry.sha256||sha(await fs.readFile(entry.buildReceipt))!==entry.buildReceiptSha256||sha(await fs.readFile(entry.invocation))!==entry.invocationSha256)throw Error('Scene-read private engine proof differs');
 if(d.resolvedFeatures?.vulkan!==true||d.resolvedFeatures?.opengl3!==true||d.resolvedFeatures?.disable_path_overrides!==false||entry.compilerSha256!==base?.compilerSha256||JSON.stringify(entry.arguments)!==JSON.stringify(base?.arguments)||sha(await fs.readFile(d.moduleManifest))!==d.moduleManifestSha256||sha(await fs.readFile(d.sourceManifest))!==d.sourceManifestSha256)throw Error('Scene-read private engine source/build policy differs');
 const module=JSON.parse(await fs.readFile(d.moduleManifest));for(const p of module.pins)if(sha(await fs.readFile(path.join(module.module,p.relative)))!==p.sha256)throw Error('Scene-read builtin module source differs');
 sceneEngineFiles={engineBuild:entry.buildReceipt,engineInvocation:entry.invocation,engineSource:d.sourceManifest,sceneModule:d.moduleManifest};for(let i=0;i<module.pins.length;i++)sceneEngineFiles['sceneModule'+i]=path.join(module.module,module.pins[i].relative);
 engineFile=entry.path;
}else if(engineMode.startsWith('custom-')){
 const label=arg('custom-engine-descriptor');if(!/^engine-rd-[a-z0-9-]+$/.test(label??''))throw Error('An explicit private engine A/B descriptor is required');
 customDescriptor=path.join(project,'.cache/native-140fps/render-agent',label,'engine-ab-descriptor.json');const descriptor=JSON.parse(await fs.readFile(customDescriptor)),state=engineMode.slice(7),entry=descriptor.engines?.[state];
 if(descriptor.version!==1||entry?.buildExitCode!==0||entry?.sourceUnchanged!==true||entry?.sourceState!==state||!path.resolve(entry.path).startsWith(path.dirname(customDescriptor)+path.sep)||sha(await fs.readFile(entry.path))!==entry.sha256||sha(await fs.readFile(entry.buildReceipt))!==entry.buildReceiptSha256)throw Error('Private engine build proof differs');
 if(descriptor.resolvedFeatures?.vulkan!==true||descriptor.resolvedFeatures?.opengl3!==true||descriptor.resolvedFeatures?.disable_path_overrides!==false)throw Error('Private engine runtime features differ');
 engineFile=entry.path;
}
if(engineMode==='release'){
 const label=arg('release-package');if(!/^release-pack-[a-z0-9-]+$/.test(label??''))throw Error('Release requires an explicit private sibling PCK package');
 releaseReceipt=path.join(project,'.cache/native-140fps/root',label,'receipt.json');releasePackage=JSON.parse(await fs.readFile(releaseReceipt));
 if(!releasePackage.success||path.resolve(releasePackage.sourceProject)!==sourceProject||sha(await fs.readFile(releasePackage.sourceManifest.file))!==releasePackage.sourceManifest.sha256)throw Error('Release package source differs');
 for(const pin of releasePackage.runtimePins){if(sha(await fs.readFile(path.join(releasePackage.runtime,pin.relative)))!==pin.sha256)throw Error('Release package runtime differs');}
 engineFile=releasePackage.engine;runtimeRoot=releasePackage.runtime;
 if(sha(await fs.readFile(engineFile))!=='d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562')throw Error('Verified release engine differs');
}
const runtimeFiles={engine:engineFile,kernel:path.join(runtimeRoot,'.cache/native-kernel/nwn-particle-kernel.dll'),kernelManifest:path.join(sourceProject,'.cache/native-kernel/build-manifest.json'),resourceIndex:path.join(runtimeRoot,'.cache/native-resource-index/nwn-resource-index.dll'),resourceIndexManifest:path.join(sourceProject,'.cache/native-resource-index/build-manifest.json')};
if(clientCapsule)runtimeFiles.clientCapsuleManifest=path.resolve(arg(productionSelection?'production-selection':'client-capsule'));
Object.assign(runtimeFiles,sceneEngineFiles);
if(releasePackage){runtimeFiles.pack=releasePackage.pack;runtimeFiles.packageReceipt=releaseReceipt;}
if(customDescriptor)runtimeFiles.customDescriptor=customDescriptor;
async function hashRuntime(file){try{const digest=createHash('sha256');for await(const chunk of createReadStream(file))digest.update(chunk);return digest.digest('hex');}catch(error){if(error.code==='ENOENT')return null;throw error;}}
const runtimeSha256={};for(const [name,file]of Object.entries(runtimeFiles))runtimeSha256[name]=await hashRuntime(file);
const nativeReport=path.join(project,'reports',run+'.native.json'),reportPath=path.join(project,'reports',run+'.json'),profilePath=path.join(project,'reports',run+'.performance.jsonl');
for(const file of[nativeReport,reportPath]){try{await fs.access(file);throw Error('Replay output already exists');}catch(e){if(e.code!=='ENOENT')throw e;}}
const temporary=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-native-loading-replay-')),token=randomBytes(32).toString('hex');
const productionPreferenceWorking=productionSelection?require('./native-production-selection.cjs').createPreferenceWorkingCopies(productionSelection,path.join(temporary,'userdata')):null;
const externalCache=arg('cache-directory');
if(externalCache){if(!path.isAbsolute(externalCache))throw Error('Benchmark cache must be an explicit absolute directory');for(const root of[project,sourceProject].map(folder=>path.dirname(folder))){const relative=path.relative(root,path.resolve(externalCache));if(relative===''||!relative.startsWith('..'+path.sep)&&relative!=='..'&&!path.isAbsolute(relative))throw Error('Benchmark cache must remain outside source workspaces');}}
const preparedCache=externalCache?path.resolve(externalCache):path.join(temporary,'prepared');
const cacheInitiallyEmpty=(await fs.readdir(preparedCache).catch(error=>{if(error.code==='ENOENT')return[];throw error;})).length===0;
const report={success:false,timelineDelivered:false,offline:true,gameNetworkConnections:0,renderingPrepared:false,capture:directory,recordingSha256:manifest.timelineSha256,mode:process.argv.includes('--paced')?'original-timing':'acknowledgement-paced',events:records.length,milestones:[],rejectedActions:0,preparedCache,cacheInitiallyEmpty,preparedCacheExternallyManaged:Boolean(externalCache)};
if(clientCapsule)report.clientCapsule=clientCapsule.evidence;
if(productionSelection)report.productionSelection=productionSelection.evidence;
if(productionPreferenceWorking)report.productionPreferences=productionPreferenceWorking;
let startupFeatures=null;
function observeProductionFeatures(value,final=false){
 if(!startupFeatures)return;
 startupFeatures.nativeStartup=value;startupFeatures.verification=featureManifest.verifyNativeObservation(startupFeatures,value,{requireObservedThread:final});
 if(startupFeatures.verification.status==='rejected')throw Error('Production native features rejected: '+startupFeatures.verification.errors.join('; '));
 if(startupFeatures.replayCameraPolicy&&value.presentation?.replay_fov_policy!=='preferences')throw Error('Native production replay FOV policy unavailable or ignored');
}
function observeProductionWorld(state,scope){
 if(!startupFeatures||!state?.drive_collision_configuration||!state?.focus_lighting)return;
 startupFeatures.worldSelections=featureManifest.worldSelection(state,scope);startupFeatures.worldVerification=featureManifest.verifyWorldSelection(startupFeatures,startupFeatures.worldSelections);
 if(startupFeatures.worldVerification.status==='rejected')throw Error('Production native owners rejected: '+startupFeatures.worldVerification.errors.join('; '));
}
report.movementReplay={enabled:movementTiming,inputs:0,accepted:0,rejected:0,samples:0,packets:0,dispatches:0,failures:[],scope:'Offline input decisions through ordinary native prediction, with original host delivery gaps. Reliable packet bytes are retained as evidence, not sent to a game server. No UDP retransmission or full NetworkPeer emulation.'};
const productionMovementExpected=new Map(productionSelection&&movementTiming?records.filter(row=>row.kind==='movement-input').map(row=>[row.sequence,row.value.operation]):[]),productionMovementSeen=new Set();
if(productionSelection&&movementTiming){
 const operations={};for(const operation of productionMovementExpected.values())operations[operation]=(operations[operation]??0)+1;
 report.movementReplay.prediction={expected:productionMovementExpected.size,expectedOperations:operations,acceptedOperations:{},firstInputMs:null,lastInputMs:null,lastResultMs:null,scope:'Actual current native ordinary-prediction decisions; input section is distinct from the later steady quiet window'};
}
function productionMovementResult(value){
 if(!productionSelection||!movementTiming)return;
 const expected=productionMovementExpected.get(value.inputSequence);
 if(expected===undefined||productionMovementSeen.has(value.inputSequence)||value.outcome?.accepted!==true||value.outcome.operation!==expected)throw Error('Production movement prediction receipt missing, repeated, rejected or operation differs');
 productionMovementSeen.add(value.inputSequence);const p=report.movementReplay.prediction;p.acceptedOperations[expected]=(p.acceptedOperations[expected]??0)+1;p.lastResultMs=performance.now()-started;
}
function productionInputPhase(){return !productionSelection||!movementTiming?null:report.movementReplay.prediction.firstInputMs===null?'before-input':productionMovementSeen.size===productionMovementExpected.size?'post-input-quiet':'recorded-input-section';}
if(movementTiming)report.mode='original-timing-with-loading-gates';
report.selectedGeneration=arg('generation')?Number(arg('generation')):null;
report.benchmarkClone=manifest.benchmarkClone??null;
report.sourceProject=sourceProject;report.driverSha256=sha(await fs.readFile(fileURLToPath(import.meta.url)));
report.profilingRequested=profiling==='true';report.runtimeFiles=runtimeFiles;report.runtimeSha256=runtimeSha256;report.engineRequested=engineMode;
report.particleEngineReadsRequested=particleEngineReads;
report.terrainHeightRequested=terrainHeight;
report.profileObservationPolicy={enabled:observeProfile==='true',intervalMs:2000,maximum:1000,maximumBytes:32*1024*1024,scope:'Bounded detached native profile records retained by the offline host; written after child-exit handling, with actual exit state recorded. Overlapping windows are not unique hitch counts.'};
const profileObservations=[];let profileObservationAt=-Infinity,profileObservationBytes=0;
const fpsObservations=[];let fpsObservationAt=-Infinity;
report.debuggerRequested=process.argv.includes('--debugger');
report.debuggerVmFieldsRequested=debuggerVm;
report.tcpNoDelayRequested=tcpNoDelay==='true';
report.measurementDurationMs=arg('duration-ms')?Number(arg('duration-ms')):null;
if(report.measurementDurationMs!==null&&(!Number.isFinite(report.measurementDurationMs)||report.measurementDurationMs<1000||report.measurementDurationMs>3600000))throw Error('Invalid offline measurement duration');
report.steadyDurationMs=arg('steady-ms')?Number(arg('steady-ms')):null;
if(report.steadyDurationMs!==null&&(!Number.isFinite(report.steadyDurationMs)||report.steadyDurationMs<1000||report.steadyDurationMs>60000||report.measurementDurationMs!==null||process.argv.includes('--interactive')))throw Error('Invalid steady measurement window');
let socket,child,childClosed,started=0,cursor=0,ready=false,ending=false,timer,profileAt=0,lastObservation;
const nativeStdoutDiagnostics=new NativeReplayDiagnostics(),nativeStderrDiagnostics=new NativeReplayDiagnostics();
const acks=new Set();const send=value=>{if(['finish','finish-ack'].includes(value.kind)){report.protocolControl??=[];report.protocolControl.push({boundary:'send',kind:value.kind,connection:value.connection,writable:!!socket&&!socket.destroyed&&!socket.writableEnded,queuedBytes:socket?.writableLength??null});}if(socket&&!socket.destroyed)socket.write(JSON.stringify(value)+'\n');};
function pump(){
 if(!ready||ending)return;
 while(cursor<records.length){const row=records[cursor];
  if(movementTiming&&!movementClock.ready(row,performance.now()-started))return;
  if(row.kind==='acknowledgement'){if(!acks.has(ackKey(row.value)))return;if(movementTiming)movementClock.consume(row,performance.now()-started);cursor++;continue;}
  if(process.argv.includes('--paced')&&performance.now()-started<row.at)return;
  if(movementTiming)movementClock.consume(row,performance.now()-started);
  cursor++;
  if(row.kind==='baseline')continue;
  if(row.kind==='movement-input'){if(movementTiming){report.movementReplay.inputs++;if(productionSelection){const p=report.movementReplay.prediction;p.firstInputMs??=performance.now()-started;p.lastInputMs=performance.now()-started;}send({kind:'replay-movement-input',connection:row.value.connection,generation:row.value.generation,areaId:row.value.areaId,inputSequence:row.sequence,value:row.value});}continue;}
  if(row.kind==='movement-sample'){report.movementReplay.samples++;continue;}
  if(row.kind==='movement-dispatch'){report.movementReplay.dispatches++;continue;}
  if(row.kind==='network-game-packet'){report.movementReplay.packets++;continue;}
  if(row.kind==='view'){send({kind:'replay-view',connection:row.value.connection??lastConnection,value:row.value});continue;}
  const value=structuredClone(row.value);lastConnection=value.connection??lastConnection;
  if(value.kind==='setup'){value.resourceSources.recordedCatalog=path.join(directory,value.resourceSources.recordedCatalog);value.serverLabel='OFFLINE RECORDING';}
  send(value);
 }
 report.timelineDelivered=true;
 if(lastObservation?.state?.object_visuals_complete&&!report.settledAt)report.settledAt=performance.now();
 if(report.settledAt&&performance.now()-report.settledAt>Number(arg('settle-ms')??5000)&&!process.argv.includes('--interactive')){
  if(report.steadyDurationMs===null)void finish();
  else if(!report.steadyRequestedAt){report.steadyRequestedAt=performance.now();send({kind:'begin-performance-window',connection:lastConnection,generation:lastObservation.generation,areaId:lastObservation.areaId});}
  else if(report.steadyStartedAt&&performance.now()-report.steadyStartedAt>=report.steadyDurationMs){report.steadyCompleted=true;void finish();}
  else if(!report.steadyStartedAt&&performance.now()-report.steadyRequestedAt>10000)void finish('Native steady window did not acknowledge');
 }
}
let lastConnection=0;
async function finish(reason,nativeFinished=false){
 if(ending)return;ending=true;clearInterval(timer);if(reason)report.failure=reason;
 report.movementReplay.timing=movementClock.snapshot();
 if(child&&child.exitCode===null){if(!nativeFinished)send({kind:'finish',connection:lastConnection});await new Promise(resolve=>{const t=setTimeout(resolve,120000);child.once('exit',()=>{clearTimeout(t);resolve();});});}
 if(child&&child.exitCode===null){report.failure??='Owned replay child did not finish; preserved';child.unref();}
 if(child&&child.exitCode!==null){
  report.nativeLogStreamsClosed=await new Promise(resolve=>{const deadline=setTimeout(()=>resolve(false),2000);childClosed.then(()=>{clearTimeout(deadline);resolve(true);});});
  if(!report.nativeLogStreamsClosed)report.failure??='Native log streams did not close after child exit';
 }
 socket?.destroy();server.close();report.lastObservation=lastObservation;
 if(productionSelection){
  const file=path.join(project,'reports',run+'.fps.jsonl'),bytes=Buffer.from(fpsObservations.map(row=>JSON.stringify(row)).join('\n')+'\n');
  await fs.writeFile(file,bytes,{flag:'wx'});
  report.fpsObservations={file,samples:fpsObservations.length,sha256:sha(bytes),headless:process.argv.includes('--headless'),scope:'Existing native Engine FPS observations sampled at most every 2 seconds, with actual input phase; rolling FPS, not independent frame intervals. Headless values are not graphical performance.'};
 }
 if(observeProfile==='true'){
  const file=path.join(project,'reports',run+'.performance.jsonl');
  const bytes=Buffer.from(profileObservations.join('\n')+'\n');
  await fs.writeFile(file,bytes,{flag:'wx'});report.profileObservations={file,samples:profileObservations.length,sha256:sha(bytes),writtenAfterChildExit:child?.exitCode!==null};
 }
 try{const native=JSON.parse(await fs.readFile(nativeReport,'utf8'));report.native=native;report.diagnosticPreviewEnabled=native.diagnostic_preview_policy?.enabled??null;report.success=!report.failure&&report.timelineDelivered&&native.workers_remaining===0&&native.protocol_finish_ack===true&&native.object_visuals_complete===true;}catch{report.failure??='Native replay result missing';}
 report.sourceSha256=sourceSha256;report.sourceUnchanged=true;for(const[name,digest]of Object.entries(sourceSha256))if(sha(await fs.readFile(path.join(sourceProject,name)))!==digest)report.sourceUnchanged=false;
 report.driverSources=driverSources;report.driverUnchanged=sha(await fs.readFile(fileURLToPath(import.meta.url)))===report.driverSha256;for(const[name,digest]of Object.entries(driverSources))if(sha(await fs.readFile(path.join(project,'tools',name)))!==digest)report.driverUnchanged=false;report.sourceUnchanged&&=report.driverUnchanged;
 report.nativeDiagnostics={stdout:nativeStdoutDiagnostics.snapshot(),stderr:nativeStderrDiagnostics.snapshot()};
 report.engineOrLifetimeError=report.nativeDiagnostics.stdout.detected||report.nativeDiagnostics.stderr.detected||/SCRIPT ERROR|^ERROR:|ObjectDB.*leak|resources still in use/m.test(report.errors??'');
 if(report.engineOrLifetimeError){report.failure??='Native engine/lifetime diagnostics observed';report.success=false;}
 if(process.argv.includes('--debugger')){const text=await fs.readFile(path.join(project,'reports',run+'.cdb.log'),'utf8').catch(()=>'');report.debuggerArmed=/^LOADING_REPLAY_ARMED\r?$/m.test(text);report.nativeException=/^LOADING_REPLAY_EXCEPTION\r?$/m.test(text);if(!report.debuggerArmed||report.nativeException)report.success=false;}
 report.runtimeUnchanged=true;for(const [name,file]of Object.entries(runtimeFiles))if(await hashRuntime(file)!==runtimeSha256[name])report.runtimeUnchanged=false;
 if(clientCapsule&&!productionSelection)report.clientCapsule.preferencesSha256AtExit=sha(await fs.readFile(clientCapsule.manifest.settings.file));
 if(productionSelection){
  try{await readReplayProductionSelection(arg('production-selection'),arg('production-selection-sha256'),project);}catch(error){report.failure??=error.message;report.success=false;}
  try{if(report.native?.runtime_features)observeProductionFeatures(report.native.runtime_features,true);observeProductionWorld(report.native?.world,{connection:lastConnection,generation:lastObservation?.generation,areaId:lastObservation?.areaId});}catch(error){report.failure??=error.message;}
  report.productionFeatures=startupFeatures;
  if(startupFeatures?.verification?.status!=='observed'||startupFeatures?.worldVerification?.status!=='observed'){report.failure??='Production startup/thread/world owners were not observed';report.success=false;}
  if(report.failure)report.success=false;
  if(movementTiming){report.movementReplay.prediction.verified=productionMovementExpected.size>0&&productionMovementSeen.size===productionMovementExpected.size&&report.movementReplay.rejected===0;if(!report.movementReplay.prediction.verified){report.failure??='Production replay did not accept every recorded ordinary-prediction operation';report.success=false;}}
  const expected={particles:productionSelection.preferences.expected.particles,particleCollision:productionSelection.preferences.expected.particleCollision,viewport:productionSelection.preferences.expected.viewport};
  for(const row of records)if(row.kind==='view'){if(typeof row.value.particles==='boolean')expected.particles=row.value.particles;if(typeof row.value.particle_collision==='boolean')expected.particleCollision=row.value.particle_collision;if(Array.isArray(row.value.size))expected.viewport=row.value.size;}
  report.productionPreferences.verification=require('./native-production-selection.cjs').verifyPreferenceObservation(productionSelection,productionPreferenceWorking,report.native?.runtime_features?.presentation,{...expected,headless:report.native?.presentation_state?.headless===true});
  for(const name of ['render','layout'])report.productionPreferences[name].finalSha256=await hashRuntime(productionPreferenceWorking[name].file);
  if(report.productionPreferences.verification.status!=='observed'){report.failure??='Isolated production preference/viewport evidence rejected';report.success=false;}
  report.productionCameraVerification=cameraExpectation?verifyReplayCameraEvidence(cameraExpectation,report.native):verifyReplayProjection(report.native?.runtime_features?.presentation?.camera,productionSelection.cameraPolicy.fovDegrees);
  if(report.productionCameraVerification.status!=='observed'){report.failure??='Actual production camera/terminal-motion evidence rejected';report.success=false;}
 }
 report.renderingMethodMatched=report.native?.presentation_state?.headless===true||report.native?.presentation_state?.method===renderingMethod;
 if(!report.renderingMethodMatched){report.success=false;report.failure??='Explicit rendering method did not match the actual renderer';}
 if(clientCapsule&&report.native?.presentation_state?.headless!==true){
  const window=report.native?.startup_window;
  report.secondaryMonitorVerified=Number.isInteger(window?.screen)&&Number.isInteger(window?.primary)&&window.screen!==window.primary;
  if(!report.secondaryMonitorVerified){report.success=false;report.failure??='Client capsule replay opened on the primary monitor';}
 }
 const observedProfiling=report.native?.presentation_state?.detailed_profiling;
 report.profilingMatched=typeof observedProfiling==='boolean'?observedProfiling===report.profilingRequested:null;
 if(report.profilingMatched===false||!report.profilingRequested&&report.profilingMatched!==true){report.success=false;report.failure??='Explicit profiling policy was not verified';}
 report.particleEngineReads=engineReadReportAcceptance(particleEngineReads,report.native);
 if(!report.particleEngineReads.verified){report.success=false;report.failure??='Explicit synchronous particle read route was not verified';}
 report.terrainHeight=terrainHeightAcceptance(terrainHeight,report.native?.world?.surface);
 if(!report.terrainHeight.verified){report.success=false;report.failure??='Explicit terrain height route was not verified';}
 report.success=report.success&&report.sourceUnchanged&&report.runtimeUnchanged&&!report.engineOrLifetimeError&&report.exit===0;
 if(movementTiming)report.success=report.success&&report.movementReplay.inputs>0&&report.movementReplay.accepted===report.movementReplay.inputs&&report.movementReplay.rejected===0;
 if(report.steadyDurationMs!==null)report.success=report.success&&report.steadyCompleted===true&&report.native?.performance_window?.steady===true;
 if(report.steadyDurationMs!==null&&report.native?.presentation_state?.headless===false){
  if(productionSelection){
   report.productionWindowVerification=verifyProductionReplayWindow(report.native,currentDisplay);
   report.secondaryMonitorVerified=report.productionWindowVerification.status==='observed';
  }else{
   const begin=report.native?.performance_window?.view_begin,end=report.native?.perf140_view_end,start=report.native?.startup_window;
   report.secondaryMonitorVerified=Number.isInteger(begin?.screen)&&Number.isInteger(end?.screen)&&Number.isInteger(start?.screen)&&Number.isInteger(start?.primary)&&begin.screen===end.screen&&end.screen===start.screen&&end.screen!==start.primary;
  }
  if(!report.secondaryMonitorVerified){report.success=false;report.failure??='Offline benchmark did not remain on its secondary monitor';}
 }
 if(report.measurementDurationMs!==null){
  const world=report.native?.world??{},objectErrors=Object.values(world.failed_objects??{}).map(row=>row.error??row),errors=[...(world.errors??[]),...objectErrors];
  report.measurement={completed:report.measurementCompleted===true,requestedMs:report.measurementDurationMs,playableAtMs:world.playable_ms??null,readyAtEnd:world.ready??false,completeWorld:world.object_visuals_complete??false,captureGaps:errors.filter(row=>String(row.reason??'').startsWith('Unrecorded native resource:')),otherWorldErrors:errors.filter(row=>!String(row.reason??'').startsWith('Unrecorded native resource:')),scope:'Bounded loading observation; partial timeline/missing capture bytes do not constitute complete-world or full-replay acceptance'};
 }
 if(child?.exitCode!==null){if(report.preparedCacheExternallyManaged)report.preparedCachePreserved=true;else try{const owned=await fs.realpath(temporary),cache=await fs.realpath(report.preparedCache);if(path.dirname(cache)!==owned||path.basename(cache)!=='prepared'||!path.basename(owned).startsWith('nwn-native-loading-replay-'))throw Error('Replay cache ownership differs');await fs.rm(cache,{recursive:true});report.preparedCacheRemoved=true;}catch(error){if(error.code!=='ENOENT')report.cacheCleanup=error.message;}}
 await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\n',{flag:'wx'});await fs.unlink(path.join(temporary,'ticket.json')).catch(()=>{});await fs.rmdir(temporary).catch(()=>{});
 console.log(JSON.stringify({success:report.success,failure:report.failure,report:reportPath,gameNetworkConnections:0}));process.exit(report.success?0:1);
}
const server=net.createServer(client=>{
 report.loopbackPeers??=[];
 const peer={number:report.loopbackPeers.length+1,accepted:!socket,readyAtConnect:ready,remoteAddress:client.remoteAddress,remotePort:client.remotePort,connectedAtMs:performance.now()-started,receivedBytes:0,handshake:false};
 if(report.loopbackPeers.length<16)report.loopbackPeers.push(peer);
 if(socket){client.destroy();return;}socket=client;client.setNoDelay(tcpNoDelay==='true');let buffered='';
 client.on('error',error=>{report.localTransportError={code:error.code??null,syscall:error.syscall??null,elapsedMs:performance.now()-started};});
 client.on('end',()=>{report.localTransportEnd={elapsedMs:performance.now()-started,ending};});
 client.on('close',hadError=>{peer.closedAtMs=performance.now()-started;peer.hadError=hadError;report.localTransportClosed={hadError,elapsedMs:performance.now()-started,ending};});
 client.on('data',data=>{peer.receivedBytes+=data.length;buffered+=data.toString('utf8');if(buffered.length>1024*1024){void finish('Replay client frame exceeds bound');return;}let at;while((at=buffered.indexOf('\n'))>=0){const line=buffered.slice(0,at);buffered=buffered.slice(at+1);try{const value=JSON.parse(line);
  if(!ready){if(value.kind!=='hello'||value.token!==token)throw Error('Replay handshake differs');if(productionSelection)observeProductionFeatures(value.runtimeFeatures);peer.handshake=true;ready=true;started=performance.now();send({kind:'browser-closed',connection:0});pump();continue;}
  if(productionSelection&&value.runtimeFeatures)observeProductionFeatures(value.runtimeFeatures);
  if(value.kind==='performance-window-ready'){if(!report.steadyRequestedAt||value.success!==true){void finish('Native steady window rejected or unsolicited');return;}report.steadyStartedAt=performance.now();report.steadyNative=value;}
  else if(ackKinds.has(value.kind)){acks.add(ackKey(value));report.milestones.push({...value,elapsedMs:performance.now()-started});}
  else if(value.kind==='observed'){
   lastObservation=value;
   if(productionSelection&&Number.isFinite(value.fps)&&performance.now()-fpsObservationAt>=2000&&fpsObservations.length<1000){
    fpsObservationAt=performance.now();fpsObservations.push({elapsedMs:fpsObservationAt-started,generation:value.generation,areaId:value.areaId,fps:value.fps,ready:value.state?.ready,pending_batches:value.state?.pending_batches,entities:value.state?.entities,inputWindowPhase:productionInputPhase(),predictionInputs:report.movementReplay.inputs,predictionResults:productionMovementSeen.size});
   }
   if(productionSelection&&value.state?.ready)observeProductionWorld(value.state,{connection:value.connection,generation:value.generation,areaId:value.areaId});
   if(observeProfile==='true'){
    if(value.frame_profile?.metrics&&performance.now()-profileObservationAt>=2000){
     profileObservationAt=performance.now();
     const line=JSON.stringify({elapsedMs:profileObservationAt-started,generation:value.generation,areaId:value.areaId,fps:value.fps,ready:value.state?.ready,pending_batches:value.state?.pending_batches,entities:value.state?.entities,frame_profile:value.frame_profile,...(productionSelection?{inputWindowPhase:productionInputPhase(),predictionInputs:report.movementReplay.inputs,predictionResults:productionMovementSeen.size}:{})});
     const bytes=Buffer.byteLength(line)+1;
     if(profileObservations.length<1000&&profileObservationBytes+bytes<=32*1024*1024){profileObservations.push(line);profileObservationBytes+=bytes;}else report.profileObservationLimitReached=true;
    }
   }else if(value.frame_profile?.metrics&&performance.now()-profileAt>2000){profileAt=performance.now();void fs.appendFile(profilePath,JSON.stringify({at:Date.now(),elapsedMs:profileAt-started,frame_profile:value.frame_profile,state:value.state,fps:value.fps})+'\n');}
  }
  else if(value.kind==='movement-replay-result'){productionMovementResult(value);if(value.outcome?.accepted)report.movementReplay.accepted++;else{report.movementReplay.rejected++;if(report.movementReplay.failures.length<32)report.movementReplay.failures.push({inputSequence:value.inputSequence,outcome:value.outcome});}}
  else if(value.kind==='finished'){report.protocolControl??=[];report.protocolControl.push({boundary:'received',kind:'finished',connectionPresent:Object.hasOwn(value,'connection'),connection:value.connection,admittedConnection:lastConnection});send(replayFinishAcknowledgment(value,lastConnection));if(!ending)void finish(undefined,true);}
  else if(!['browser-observed','ui-ready'].includes(value.kind))report.rejectedActions++;
  pump();
 }catch(error){void finish(error.message);}}});
});
await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
const ticket=path.join(temporary,'ticket.json');await fs.writeFile(ticket,JSON.stringify({host:'127.0.0.1',port:server.address().port,token,...(productionSelection?{featureSelection:productionSelection.featureSelection}:{})}),{flag:'wx'});
const args=[...(engineMode==='release'?[]:['--path',sourceProject]),'--rendering-method',renderingMethod,'--rendering-driver','vulkan',...(process.argv.includes('--headless')?['--headless']:[]),...(arg('screen')?['--screen',arg('screen')]:[]),'--log-file',path.join(project,'reports',run+'.engine.log'),'--script','res://native_session_world.gd','--','--ticket='+ticket,'--report='+nativeReport,'--prepared-cache='+report.preparedCache,'--profile='+profiling,'--profile-control='+path.join(project,'reports',run+'.profile-control.json'),'--offline-replay=true'];
if(productionPreferenceWorking)args.push('--render-preferences='+productionPreferenceWorking.render.file,'--menu-layout='+productionPreferenceWorking.layout.file);
// A private opt-in probe may also disable small-packet buffering in the native
// loopback peer. The native project must explicitly implement/read it back.
if(tcpNoDelay==='true')args.push('--tcp-no-delay=true');
report.renderingMethodRequested=renderingMethod;
if(movementTiming)args.push('--movement-timing=true');
if(tcpNoDelay==='true')args.push('--protocol-no-delay=true');
const nativeLighting=arg('native-lighting')??'godot',nativeHistory=arg('native-light-history')??'0',nativeOutput=arg('native-surface-output')??'false';
if(!['godot','enhanced'].includes(nativeLighting)||!['0','1'].includes(nativeHistory)||!['true','false'].includes(nativeOutput))throw Error('Invalid native lighting replay mode');
if((nativeHistory==='1'||nativeOutput==='true')&&nativeLighting!=='enhanced')throw Error('Native lighting research requires enhanced lighting');
if(nativeOutput==='true'&&nativeHistory!=='1')throw Error('Native surface replay requires native light history');
if(nativeLighting==='enhanced')args.push('--native-lighting=enhanced');
if(nativeHistory==='1')args.push('--native-light-history');
if(nativeOutput==='true')args.push('--native-surface-output=true');
for(const field of ['mask','midpoint','intensity','vibrance'])if(arg('native-postprocess-'+field)!==undefined)args.push('--native-postprocess-'+field+'='+arg('native-postprocess-'+field));
report.nativeLightingRequested=nativeLighting;report.nativeLightHistoryRequested=nativeHistory==='1';report.nativeSurfaceOutputRequested=nativeOutput==='true';
if(arg('render-thread')){
 if(!['safe','separate'].includes(arg('render-thread')))throw Error('Invalid render thread mode');
 args.unshift('--render-thread',arg('render-thread'));
}
report.renderThreadRequested=arg('render-thread')??'default';
if(arg('material-prewarm')){
 if(!['true','false'].includes(arg('material-prewarm')))throw Error('Invalid material prewarm mode');
 args.push('--material-prewarm='+arg('material-prewarm'));
}
report.materialPrewarmRequested=arg('material-prewarm')??'default';
if(arg('static-parts')){
 if(!['compact','separate'].includes(arg('static-parts')))throw Error('Invalid static Part layout');
 args.push('--static-parts='+arg('static-parts'));
}
report.staticPartsRequested=arg('static-parts')??'default';
if(arg('profile-summary')){
 if(!['main','worker'].includes(arg('profile-summary')))throw Error('Invalid frame summary policy');
 args.push('--profile-summary='+arg('profile-summary'));
}
report.profileSummaryRequested=arg('profile-summary')??'default';
if(process.argv.includes('--preview')&&process.argv.includes('--no-preview'))throw Error('Choose either preview or no-preview');
args.push('--capture-preview='+process.argv.includes('--preview'));
if(arg('animation-keys')){
 if(!['gd','compiled'].includes(arg('animation-keys')))throw Error('Invalid animation key validation mode');
 args.push('--animation-keys='+arg('animation-keys'));
}
report.animationKeysRequested=arg('animation-keys')??'default';
if(arg('ascii-key-write')){
 if(!['arrays','typed'].includes(arg('ascii-key-write')))throw Error('Invalid ASCII key write mode');
 args.push('--ascii-key-write='+arg('ascii-key-write'));
}
report.asciiKeyWriteRequested=arg('ascii-key-write')??'default';
if(arg('ui-data-retirement')){
 if(!['worker','main'].includes(arg('ui-data-retirement')))throw Error('Invalid UI raw-data retirement mode');
 args.push('--ui-data-retirement='+arg('ui-data-retirement'));
}
report.uiDataRetirementRequested=arg('ui-data-retirement')??'default';
if(arg('prepared-cache-write')){
 if(!['sync','disabled','deferred'].includes(arg('prepared-cache-write')))throw Error('Invalid prepared cache write mode');
 args.push('--prepared-cache-write='+arg('prepared-cache-write'));
}
report.preparedCacheWriteRequested=arg('prepared-cache-write')??'default';
if(arg('prepared-cache-lock')){
 if(!['global','path'].includes(arg('prepared-cache-lock')))throw Error('Invalid prepared cache publication lock mode');
 args.push('--prepared-cache-lock='+arg('prepared-cache-lock'));
}
report.preparedCacheLockRequested=arg('prepared-cache-lock')??'default';
if(arg('skin-preparation')){
 if(!['main','worker'].includes(arg('skin-preparation')))throw Error('Invalid skin preparation mode');
 args.push('--skin-preparation='+arg('skin-preparation'));
}
report.skinPreparationRequested=arg('skin-preparation')??'default';
if(arg('clip-preparation')){
 if(!['main','worker'].includes(arg('clip-preparation')))throw Error('Invalid clip preparation mode');
 args.push('--clip-preparation='+arg('clip-preparation'));
}
report.clipPreparationRequested=arg('clip-preparation')??'default';
if(arg('entry-prefetch')){
 if(!['true','false'].includes(arg('entry-prefetch')))throw Error('Invalid entry prefetch mode');
 args.push('--entry-prefetch='+arg('entry-prefetch'));
}
report.entryPrefetchRequested=arg('entry-prefetch')??'default';
if(arg('ancestor-preparation')){
 if(!['true','false'].includes(arg('ancestor-preparation')))throw Error('Invalid ancestor preparation mode');
 args.push('--ancestor-preparation='+arg('ancestor-preparation'));
}
report.ancestorPreparationRequested=arg('ancestor-preparation')??'default';
if(arg('raster-conversion')){
 if(!['gd','compiled'].includes(arg('raster-conversion')))throw Error('Invalid raster conversion mode');
 args.push('--raster-conversion='+arg('raster-conversion'));
}
report.rasterConversionRequested=arg('raster-conversion')??'default';
if(arg('ancestor-share')){
 if(!['1','2'].includes(arg('ancestor-share')))throw Error('Invalid per-root ancestor share');
 args.push('--ancestor-share='+arg('ancestor-share'));
}
report.ancestorShareRequested=arg('ancestor-share')??'default';
if(arg('mesh-preparation')){
 if(!['main','worker'].includes(arg('mesh-preparation')))throw Error('Invalid mesh preparation mode');
 args.push('--mesh-preparation='+arg('mesh-preparation'));
}
report.meshPreparationRequested=arg('mesh-preparation')??'default';
if(arg('icon-model-reuse')){
 if(!['true','false'].includes(arg('icon-model-reuse')))throw Error('Invalid icon model reuse mode');
 args.push('--icon-model-reuse='+arg('icon-model-reuse'));
}
report.iconModelReuseRequested=arg('icon-model-reuse')??'default';
if(arg('retirement-physics')){
 if(!['scan','inherit'].includes(arg('retirement-physics')))throw Error('Invalid retirement physics mode');
 args.push('--retirement-physics='+arg('retirement-physics'));
}
report.retirementPhysicsRequested=arg('retirement-physics')??'default';
report.diagnosticPreviewRequested=process.argv.includes('--preview');
report.diagnosticPreviewEnabled=null; // Verify actual native policy, including older baselines.
if(arg('particle-random')){if(!['script','native'].includes(arg('particle-random')))throw Error('Invalid private particle random mode');args.push('--particle-random='+arg('particle-random'));}
report.particleRandomRequested=arg('particle-random')??'script';
if(arg('particle-clocks')){if(!['script','native'].includes(arg('particle-clocks')))throw Error('Invalid private particle clock mode');args.push('--particle-clocks='+arg('particle-clocks'));}
report.particleClocksRequested=arg('particle-clocks')??'script';
if(arg('particle-pose-leases')){if(!['off','managed'].includes(arg('particle-pose-leases')))throw Error('Invalid private particle pose-lease mode');args.push('--particle-pose-leases='+arg('particle-pose-leases'));}
report.particlePoseLeasesRequested=arg('particle-pose-leases')??'off';
if(arg('particle-common')){if(!['off','retained'].includes(arg('particle-common')))throw Error('Invalid private particle common-input mode');args.push('--particle-common='+arg('particle-common'));}
report.particleCommonRequested=arg('particle-common')??'off';
if(arg('particle-scene-snapshot')){if(!['off','eligibility','full'].includes(arg('particle-scene-snapshot')))throw Error('Invalid private scene snapshot mode');args.push('--particle-scene-snapshot='+arg('particle-scene-snapshot'));}
report.particleSceneSnapshotRequested=arg('particle-scene-snapshot')??'off';
if(arg('static-emitter-route')){if(!['off','enabled'].includes(arg('static-emitter-route')))throw Error('Invalid static emitter route mode');args.push('--static-emitter-route='+arg('static-emitter-route'));}
report.staticEmitterRouteRequested=arg('static-emitter-route')??'off';
if(arg('raster-cache-write')){if(!['default','deferred'].includes(arg('raster-cache-write')))throw Error('Invalid raster cache write mode');args.push('--raster-cache-write='+arg('raster-cache-write'));}
report.rasterCacheWriteRequested=arg('raster-cache-write')??'default';
if(arg('model-float-stream')){if(!['scalar','bulk'].includes(arg('model-float-stream')))throw Error('Invalid model float stream mode');args.push('--model-float-stream='+arg('model-float-stream'));}
report.modelFloatStreamRequested=arg('model-float-stream')??'scalar';
if(arg('light-input-registry')){if(!['extension','builtin',...(productionSelection?['script']:[])].includes(arg('light-input-registry')))throw Error('Invalid light registry mode');args.push('--light-input-registry='+arg('light-input-registry'));}
report.lightInputRegistryRequested=arg('light-input-registry')??'extension';
if(arg('light-input-fields')){if(!['pull','published'].includes(arg('light-input-fields')))throw Error('Invalid light field publication mode');args.push('--light-input-fields='+arg('light-input-fields'));}
report.lightInputFieldsRequested=arg('light-input-fields')??'pull';
if(arg('particle-eligibility')){if(!['off','managed'].includes(arg('particle-eligibility')))throw Error('Invalid managed particle eligibility mode');args.push('--particle-eligibility='+arg('particle-eligibility'));}
report.particleEligibilityRequested=arg('particle-eligibility')??'off';
if(arg('particle-inputs')){if(!['ordinary','typed'].includes(arg('particle-inputs')))throw Error('Invalid particle input boundary mode');args.push('--particle-inputs='+arg('particle-inputs'));}
report.particleInputsRequested=arg('particle-inputs')??'ordinary';
if(arg('particle-pose-slots')){if(!['ordinary','indexed'].includes(arg('particle-pose-slots')))throw Error('Invalid particle pose-slot mode');args.push('--particle-pose-slots='+arg('particle-pose-slots'));}
report.particlePoseSlotsRequested=arg('particle-pose-slots')??'ordinary';
if(arg('generated-light-manual')){if(!['original','retained'].includes(arg('generated-light-manual')))throw Error('Invalid generated-light manual publication mode');args.push('--generated-light-manual='+arg('generated-light-manual'));}
report.generatedLightManualRequested=arg('generated-light-manual')??'original';
if(arg('drive-collision')){if(!['legacy','indexed'].includes(arg('drive-collision')))throw Error('Invalid drive collision mode');args.push('--drive-collision='+arg('drive-collision'));}
let collisionRegistryDefault=null;
try{
 const collisionRegistryBytes=await fs.readFile(path.join(sourceProject,'systems/native_data/client_feature_registry.json'));
 collisionRegistryDefault=JSON.parse(collisionRegistryBytes).features?.find(row=>row.name==='drive-collision')?.default;
 if(!['legacy','indexed'].includes(collisionRegistryDefault))throw Error('Source drive collision registry default is invalid');
 sourceSha256['systems/native_data/client_feature_registry.json']=sha(collisionRegistryBytes);
}catch(error){if(error.code!=='ENOENT')throw error;}
// Historical pinned sources may predate the registry; omission there is unknown,
// never silently reported as the current application's collision default.
report.driveCollisionRequested=arg('drive-collision')??collisionRegistryDefault;
if(arg('drive-clear')){if(!['script','native'].includes(arg('drive-clear'))||arg('drive-clear')==='native'&&arg('drive-collision')!=='indexed')throw Error('Invalid compiled drive clear route');args.push('--drive-clear='+arg('drive-clear'));}
report.driveClearRequested=arg('drive-clear')??'script';
args.push('--terrain-height='+terrainHeight);
if(productionSelection){
 args.unshift(...productionSelection.engineArguments);args.push(...productionSelection.flags,'--replay-fov-policy=preferences');
 report.replayCameraPolicy=productionSelection.cameraPolicy;report.recordedTerminalCameraExpectation=cameraExpectation;
 report.nativeLightingRequested=productionSelection.renderConfiguration.lighting;report.nativeLightHistoryRequested=productionSelection.renderConfiguration.light_history;report.nativeSurfaceOutputRequested=productionSelection.renderConfiguration.surface_output;report.renderThreadRequested=productionSelection.renderThread;
 report.lightInputRegistryRequested=productionSelection.featureSelection['light-input-registry'].value;report.driveCollisionRequested=productionSelection.featureSelection['drive-collision'].value;
 startupFeatures=featureManifest.createStartupManifest({run,project:sourceProject,runtime:productionSelection.runtime,options:productionSelection.performanceOptions,renderConfiguration:productionSelection.renderConfiguration,engineAndNativeArguments:args});
 startupFeatures.replayCameraPolicy=productionSelection.cameraPolicy;
}else if(clientCapsule){
 if(!arg('render-thread'))args.unshift('--render-thread','separate');
 args.push(...clientCapsule.flags);
 report.nativeLightingRequested='enhanced';report.nativeLightHistoryRequested=true;report.nativeSurfaceOutputRequested=true;report.renderThreadRequested='separate';
 report.particleRandomRequested='native';report.particleClocksRequested='native';report.particlePoseLeasesRequested='managed';report.lightInputRegistryRequested='builtin';report.driveCollisionRequested='indexed';
}
let currentDisplay;
try{currentDisplay=await resolveReplayDisplay({capsule:clientCapsule,headless:process.argv.includes('--headless'),requested:arg('screen'),project});}
catch(error){await finish(error.message);}
if(currentDisplay)report.replayDisplay=currentDisplay;
let executable=runtimeFiles.engine,launchArgs=applyReplayDisplay(args,currentDisplay);
if(process.argv.includes('--debugger')){
 const commands=path.join(project,'reports',run+'.cdb.txt');
 // Exact pinned release layout: GDScriptFunction begins with name/source
 // StringNames; StringName::_Data::name starts at +8 and contains UTF-32 data.
 // Inspect only on the known Array::is_empty fault RVA, not arbitrary failures.
 // Bounded code identity only: no object/packet/environment or full memory dump.
 const vm=debuggerVm?';r;.if (@rip == godot_windows_template_release_x86_64+0x2d3a5e3) { .echo GDS_FUNCTION_UTF32;dd poi(poi(@rdi)+8) L40;.echo GDS_SOURCE_UTF32;dd poi(poi(@rdi+8)+8) L60;.echo GDS_RECEIVER_VARIANT;dd @rcx-8 L6;.echo GDS_BYTECODE_CURSOR;dd @rbp+0x88 L1;.echo GDS_BYTECODE_WINDOW;dd poi(@rdi+0x2d8)+4*dwo(@rbp+0x88)-0x40 L20;.echo GDS_VM_IDENTITY_END; }':'';
 const trap='.echo LOADING_REPLAY_EXCEPTION;.exr -1;.ecxr;kv'+vm+';~* k;q';
 await fs.writeFile(commands,[...['av','0xc0000374','0xc0000409','0xc000001d'].map(code=>'sxe -c "'+trap+'" '+code),'.echo LOADING_REPLAY_ARMED','g'].join('\n')+'\n',{flag:'wx'});
 launchArgs=['-hd','-G','-sins','-y',path.join(project,'.tools'),'-logo',path.join(project,'reports',run+'.cdb.log'),'-cf',commands,executable,...launchArgs];executable='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe';
}
// Explicit child policy prevents a previously selected private experiment from
// leaking into a later ordinary/off comparison through the caller environment.
child=spawn(executable,launchArgs,{windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,...(clientCapsule?.environment??{}),NWN_PARTICLE_READS:particleEngineReads},...(engineMode==='release'?{cwd:path.dirname(engineFile)}:{})});
childClosed=new Promise(resolve=>child.once('close',resolve));
child.stdout.once('end',()=>nativeStdoutDiagnostics.end());child.stderr.once('end',()=>nativeStderrDiagnostics.end());
const launchStarted=performance.now();
child.stdout.on('data',data=>{nativeStdoutDiagnostics.write(data);report.output=((report.output??'')+data).slice(-5000);});child.stderr.on('data',data=>{nativeStderrDiagnostics.write(data);report.errors=((report.errors??'')+data).slice(-12000);});child.once('error',error=>void finish(error.message));child.once('exit',code=>{report.exit=code;if(!ending)void finish(code===0?null:'Replay child failed');});
timer=setInterval(()=>{if(!ready&&performance.now()-launchStarted>90000)void finish('Owned replay startup handshake exceeded 90-second deadline');else if(ready&&report.measurementDurationMs!==null&&performance.now()-started>=report.measurementDurationMs){report.measurementCompleted=true;void finish();}else if(ready&&performance.now()-started>Math.max(300000,(records.at(-1)?.at??0)+120000)&&!(report.timelineDelivered&&process.argv.includes('--interactive')))void finish('Offline replay exceeded deadline');else pump();},10);
