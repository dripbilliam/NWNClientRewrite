// Offline transport replay only. Native Godot selects/decodes/builds everything.
// No game network/installed resolver module is imported. The sole socket is a
// private IPv4 loopback transport to the owned Godot child.
import fs from 'node:fs/promises';import path from 'node:path';import os from 'node:os';import net from 'node:net';import {spawn} from 'node:child_process';import {createHash,randomBytes} from 'node:crypto';import {fileURLToPath} from 'node:url';
import {ackKey,ackKinds,frameKinds} from './native-loading-recording.mjs';
import {selectGeneration} from './native-loading-selection.mjs';
import {createReadStream} from 'node:fs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const arg=name=>process.argv.find(x=>x.startsWith('--'+name+'='))?.slice(name.length+3);
const sourceProject=arg('source-project')?path.resolve(arg('source-project')):project;
const profiling=arg('profiling')??'true';
if(!['true','false'].includes(profiling))throw Error('Invalid explicit profiling policy');
const directory=path.resolve(arg('capture')??'');if(!arg('capture'))throw Error('Explicit sealed native loading recording required');
const run=arg('run')??'native-loading-replay-'+Date.now();if(!/^[a-z0-9-]+$/.test(run))throw Error('Invalid replay name');
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
  else if(!['view','baseline'].includes(row.kind))throw Error('Unsupported recording event');records.push(row);
 }
 if(records.length!==manifest.events)throw Error('Recording event count differs');return{manifest,records};
}
if(process.argv.includes('--verify-only')){const result=await readRecording(directory);console.log(JSON.stringify({complete:true,events:result.records.length,catalogs:result.manifest.catalogs.length,networkConnections:0}));process.exit(0);}
const opened=await readRecording(directory),manifest=opened.manifest,records=arg('generation')?selectGeneration(opened.records,Number(arg('generation'))):opened.records;
const sourceSha256={};async function pinSources(folder){for(const entry of await fs.readdir(folder,{withFileTypes:true})){const file=path.join(folder,entry.name);if(entry.isDirectory())await pinSources(file);else if(/\.(gd|cpp|hpp|gdextension)$/.test(entry.name))sourceSha256[path.relative(sourceProject,file)]=sha(await fs.readFile(file));}}
await pinSources(path.join(sourceProject,'systems'));await pinSources(path.join(sourceProject,'native'));for(const name of ['project.godot','native_live_world.gd','native_session_world.gd','tools/replay-native-loading.mjs','tools/native-loading-recording.mjs','tools/native-loading-selection.mjs'])sourceSha256[name]=sha(await fs.readFile(path.join(sourceProject,name)));
const runtimeFiles={engine:path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),kernel:path.join(sourceProject,'.cache/native-kernel/nwn-particle-kernel.dll'),kernelManifest:path.join(sourceProject,'.cache/native-kernel/build-manifest.json')};
async function hashRuntime(file){try{const digest=createHash('sha256');for await(const chunk of createReadStream(file))digest.update(chunk);return digest.digest('hex');}catch(error){if(error.code==='ENOENT')return null;throw error;}}
const runtimeSha256={};for(const [name,file]of Object.entries(runtimeFiles))runtimeSha256[name]=await hashRuntime(file);
const nativeReport=path.join(project,'reports',run+'.native.json'),reportPath=path.join(project,'reports',run+'.json'),profilePath=path.join(project,'reports',run+'.performance.jsonl');
for(const file of[nativeReport,reportPath]){try{await fs.access(file);throw Error('Replay output already exists');}catch(e){if(e.code!=='ENOENT')throw e;}}
const temporary=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-native-loading-replay-')),token=randomBytes(32).toString('hex');
const report={success:false,timelineDelivered:false,offline:true,gameNetworkConnections:0,renderingPrepared:false,capture:directory,recordingSha256:manifest.timelineSha256,mode:process.argv.includes('--paced')?'original-timing':'acknowledgement-paced',events:records.length,milestones:[],rejectedActions:0,preparedCache:path.join(temporary,'prepared'),cacheInitiallyEmpty:true};
report.selectedGeneration=arg('generation')?Number(arg('generation')):null;
report.sourceProject=sourceProject;report.driverSha256=sha(await fs.readFile(fileURLToPath(import.meta.url)));
report.profilingRequested=profiling==='true';report.runtimeFiles=runtimeFiles;report.runtimeSha256=runtimeSha256;
report.measurementDurationMs=arg('duration-ms')?Number(arg('duration-ms')):null;
if(report.measurementDurationMs!==null&&(!Number.isFinite(report.measurementDurationMs)||report.measurementDurationMs<1000||report.measurementDurationMs>3600000))throw Error('Invalid offline measurement duration');
report.steadyDurationMs=arg('steady-ms')?Number(arg('steady-ms')):null;
if(report.steadyDurationMs!==null&&(!Number.isFinite(report.steadyDurationMs)||report.steadyDurationMs<1000||report.steadyDurationMs>60000||report.measurementDurationMs!==null||process.argv.includes('--interactive')))throw Error('Invalid steady measurement window');
let socket,child,started=0,cursor=0,ready=false,ending=false,timer,profileAt=0,lastObservation;
const acks=new Set();const send=value=>{if(socket&&!socket.destroyed)socket.write(JSON.stringify(value)+'\n');};
function pump(){
 if(!ready||ending)return;
 while(cursor<records.length){const row=records[cursor];
  if(row.kind==='acknowledgement'){if(!acks.has(ackKey(row.value)))return;cursor++;continue;}
  if(process.argv.includes('--paced')&&performance.now()-started<row.at)return;
  cursor++;
  if(row.kind==='baseline')continue;
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
async function finish(reason){
 if(ending)return;ending=true;clearInterval(timer);if(reason)report.failure=reason;
 if(child&&child.exitCode===null){send({kind:'finish',connection:lastConnection});await new Promise(resolve=>{const t=setTimeout(resolve,120000);child.once('exit',()=>{clearTimeout(t);resolve();});});}
 if(child&&child.exitCode===null){report.failure??='Owned replay child did not finish; preserved';child.unref();}
 socket?.destroy();server.close();report.lastObservation=lastObservation;
 try{const native=JSON.parse(await fs.readFile(nativeReport,'utf8'));report.native=native;report.diagnosticPreviewEnabled=native.diagnostic_preview_policy?.enabled??null;report.success=!report.failure&&report.timelineDelivered&&native.workers_remaining===0&&native.protocol_finish_ack===true&&native.object_visuals_complete===true;}catch{report.failure??='Native replay result missing';}
 report.sourceSha256=sourceSha256;report.sourceUnchanged=true;for(const[name,digest]of Object.entries(sourceSha256))if(sha(await fs.readFile(path.join(sourceProject,name)))!==digest)report.sourceUnchanged=false;
 report.driverUnchanged=sha(await fs.readFile(fileURLToPath(import.meta.url)))===report.driverSha256;report.sourceUnchanged&&=report.driverUnchanged;
 report.engineOrLifetimeError=/SCRIPT ERROR|^ERROR:|ObjectDB.*leak|resources still in use/m.test(report.errors??'');
 if(process.argv.includes('--debugger')){const text=await fs.readFile(path.join(project,'reports',run+'.cdb.log'),'utf8').catch(()=>'');report.debuggerArmed=/^LOADING_REPLAY_ARMED\r?$/m.test(text);report.nativeException=/^LOADING_REPLAY_EXCEPTION\r?$/m.test(text);if(!report.debuggerArmed||report.nativeException)report.success=false;}
 report.runtimeUnchanged=true;for(const [name,file]of Object.entries(runtimeFiles))if(await hashRuntime(file)!==runtimeSha256[name])report.runtimeUnchanged=false;
 const observedProfiling=report.native?.presentation_state?.detailed_profiling;
 report.profilingMatched=typeof observedProfiling==='boolean'?observedProfiling===report.profilingRequested:null;
 if(report.profilingMatched===false||!report.profilingRequested&&report.profilingMatched!==true){report.success=false;report.failure??='Explicit profiling policy was not verified';}
 report.success=report.success&&report.sourceUnchanged&&report.runtimeUnchanged&&!report.engineOrLifetimeError&&report.exit===0;
 if(report.steadyDurationMs!==null)report.success=report.success&&report.steadyCompleted===true&&report.native?.performance_window?.steady===true;
 if(report.measurementDurationMs!==null){
  const world=report.native?.world??{},objectErrors=Object.values(world.failed_objects??{}).map(row=>row.error??row),errors=[...(world.errors??[]),...objectErrors];
  report.measurement={completed:report.measurementCompleted===true,requestedMs:report.measurementDurationMs,playableAtMs:world.playable_ms??null,readyAtEnd:world.ready??false,completeWorld:world.object_visuals_complete??false,captureGaps:errors.filter(row=>String(row.reason??'').startsWith('Unrecorded native resource:')),otherWorldErrors:errors.filter(row=>!String(row.reason??'').startsWith('Unrecorded native resource:')),scope:'Bounded loading observation; partial timeline/missing capture bytes do not constitute complete-world or full-replay acceptance'};
 }
 if(child?.exitCode!==null){try{const owned=await fs.realpath(temporary),cache=await fs.realpath(report.preparedCache);if(path.dirname(cache)!==owned||path.basename(cache)!=='prepared'||!path.basename(owned).startsWith('nwn-native-loading-replay-'))throw Error('Replay cache ownership differs');await fs.rm(cache,{recursive:true});report.preparedCacheRemoved=true;}catch(error){if(error.code!=='ENOENT')report.cacheCleanup=error.message;}}
 await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\n',{flag:'wx'});await fs.unlink(path.join(temporary,'ticket.json')).catch(()=>{});await fs.rmdir(temporary).catch(()=>{});
 console.log(JSON.stringify({success:report.success,failure:report.failure,report:reportPath,gameNetworkConnections:0}));process.exit(report.success?0:1);
}
const server=net.createServer(client=>{
 if(socket){client.destroy();return;}socket=client;let buffered='';client.on('error',()=>{});client.on('data',data=>{buffered+=data.toString('utf8');if(buffered.length>1024*1024){void finish('Replay client frame exceeds bound');return;}let at;while((at=buffered.indexOf('\n'))>=0){const line=buffered.slice(0,at);buffered=buffered.slice(at+1);try{const value=JSON.parse(line);
  if(!ready){if(value.kind!=='hello'||value.token!==token)throw Error('Replay handshake differs');ready=true;started=performance.now();send({kind:'browser-closed',connection:0});pump();continue;}
  if(value.kind==='performance-window-ready'){if(!report.steadyRequestedAt||value.success!==true){void finish('Native steady window rejected or unsolicited');return;}report.steadyStartedAt=performance.now();report.steadyNative=value;}
  else if(ackKinds.has(value.kind)){acks.add(ackKey(value));report.milestones.push({...value,elapsedMs:performance.now()-started});}
  else if(value.kind==='observed'){lastObservation=value;if(value.frame_profile?.metrics&&performance.now()-profileAt>2000){profileAt=performance.now();void fs.appendFile(profilePath,JSON.stringify({at:Date.now(),elapsedMs:profileAt-started,frame_profile:value.frame_profile,state:value.state,fps:value.fps})+'\n');}}
  else if(value.kind==='finished'){send({kind:'finish-ack',connection:value.connection});if(!ending)void finish();}
  else if(!['browser-observed','ui-ready'].includes(value.kind))report.rejectedActions++;
  pump();
 }catch(error){void finish(error.message);}}});
});
await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
const ticket=path.join(temporary,'ticket.json');await fs.writeFile(ticket,JSON.stringify({host:'127.0.0.1',port:server.address().port,token}),{flag:'wx'});
const args=['--path',sourceProject,'--rendering-method','forward_plus','--rendering-driver','vulkan',...(process.argv.includes('--headless')?['--headless']:[]),...(arg('screen')?['--screen',arg('screen')]:[]),'--log-file',path.join(project,'reports',run+'.engine.log'),'--script','res://native_session_world.gd','--','--ticket='+ticket,'--report='+nativeReport,'--prepared-cache='+report.preparedCache,'--profile='+profiling,'--profile-control='+path.join(project,'reports',run+'.profile-control.json'),'--offline-replay=true'];
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
let executable=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),launchArgs=args;
if(process.argv.includes('--debugger')){const commands=path.join(project,'reports',run+'.cdb.txt'),trap='.echo LOADING_REPLAY_EXCEPTION;.exr -1;.ecxr;kv;~* k;q';await fs.writeFile(commands,[...['av','0xc0000374','0xc0000409','0xc000001d'].map(code=>'sxe -c "'+trap+'" '+code),'.echo LOADING_REPLAY_ARMED','g'].join('\n')+'\n',{flag:'wx'});launchArgs=['-hd','-G','-sins','-y',path.join(project,'.tools'),'-logo',path.join(project,'reports',run+'.cdb.log'),'-cf',commands,executable,...args];executable='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe';}
child=spawn(executable,launchArgs,{windowsHide:true,stdio:['ignore','pipe','pipe']});
child.stdout.on('data',data=>{report.output=((report.output??'')+data).slice(-5000);});child.stderr.on('data',data=>{report.errors=((report.errors??'')+data).slice(-12000);});child.once('error',error=>void finish(error.message));child.once('exit',code=>{report.exit=code;if(!ending)void finish(code===0?null:'Replay child failed');});
timer=setInterval(()=>{if(ready&&report.measurementDurationMs!==null&&performance.now()-started>=report.measurementDurationMs){report.measurementCompleted=true;void finish();}else if(ready&&performance.now()-started>Math.max(300000,(records.at(-1)?.at??0)+120000)&&!(report.timelineDelivered&&process.argv.includes('--interactive')))void finish('Offline replay exceeded deadline');else pump();},10);
