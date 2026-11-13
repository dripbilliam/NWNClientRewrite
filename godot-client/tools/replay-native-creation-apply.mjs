// Exact first-snapshot startup diagnosis. No game peer/session/resolver imports.
// The only socket is private loopback IPC to this tool's own headless Godot child.
import fs from 'node:fs/promises';import path from 'node:path';import net from 'node:net';import crypto from 'node:crypto';import {spawn}from'node:child_process';import{fileURLToPath}from'node:url';
import captureReader from './native-creation-apply-capture.cjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),arg=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3),hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
if(!arg('capture'))throw Error('An explicit exact retained creation apply ledger is required');
const file=path.resolve(arg('capture')),opened=await captureReader.readCreationCapture(file),{setup,connection,serial,generation}=opened.identity,original=opened.original;
const modules=(setup.resourceSources?.archives??[]).filter(row=>path.basename(row.path).toLowerCase()==='prelude.nwm'||path.basename(row.path).toLowerCase()==='prelude.mod');
const modulePins={};
if(!modules.length){
 // Vanilla multiplayer can send all area data over the wire and mount only
 // installed base resources. Preserve that captured empty archive list.
 if((setup.resourceSources?.archives??[]).length||typeof setup.resourceSources?.profileDirectory!=='string')throw Error('Captured setup has no verified owned module provenance');
 const fixtureModule=path.join(path.dirname(setup.resourceSources.profileDirectory),'modules','Prelude.mod');
 const digest=hash(await fs.readFile(fixtureModule));if(digest!==original.creationVaultFixture.moduleSha256)throw Error('Authored diagnostic server module changed');modulePins[fixtureModule]=digest;
}
for(const module of modules){const digest=hash(await fs.readFile(module.path));if(digest!==original.creationVaultFixture.moduleSha256)throw Error('Captured module source changed');modulePins[module.path]=digest;}
if(process.argv.includes('--verify-only')){console.log(JSON.stringify({success:true,sha256:opened.sha256,objects:opened.identity.objects,connection,serial,generation,gameNetworkConnections:0}));process.exit(0);}
const run=arg('run')??'native-creation-apply-replay-'+Date.now();if(!/^native-creation-[a-z0-9-]+$/.test(run))throw Error('Invalid owned replay name');
const reportPath=path.join(project,'reports',run+'.json'),nativePath=path.join(project,'reports',run+'.native.json'),log=path.join(project,'reports',run+'.engine.log');
for(const item of[reportPath,nativePath])try{await fs.access(item);throw Error('Replay output exists; preserve it');}catch(error){if(error.code!=='ENOENT')throw error;}
const pins={};async function pin(folder){for(const row of await fs.readdir(folder,{withFileTypes:true})){const item=path.join(folder,row.name);if(row.isDirectory())await pin(item);else if(/\.(gd|gdshader|json)$/.test(row.name))pins[path.relative(project,item)]=hash(await fs.readFile(item));}}
await pin(path.join(project,'systems'));for(const item of['project.godot','native_live_world.gd','native_session_world.gd','tools/replay-native-creation-apply.mjs','tools/native-creation-apply-capture.cjs','tools/native-world-radial-capture.cjs'])pins[item]=hash(await fs.readFile(path.join(project,item)));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe');if(hash(await fs.readFile(engine))!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unapproved existing Godot runtime');
const runtimeFiles=['.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json'],runtime={};for(const item of runtimeFiles)runtime[item]=hash(await fs.readFile(path.join(project,item)));
const directory=path.join(project,'.cache/creation-apply-replay',run);await fs.mkdir(path.dirname(directory),{recursive:true});await fs.mkdir(directory,{recursive:false});
const token=crypto.randomBytes(32).toString('hex'),ticket=path.join(directory,'ticket.json');
let socket,child,ready=false,ending=false,resolveDone,timer;
const done=new Promise(resolve=>resolveDone=resolve),report={success:false,offline:true,gameNetworkConnections:0,gpu:false,nativeBuilds:0,capture:file,captureSha256:opened.sha256,ledgerSha256:opened.ledgerSha256,originalReportSha256:opened.reportSha256,moduleSourceSha256:modulePins,objects:opened.identity.objects,connection,serial,generation,milestones:[],sourceSha256:pins,runtimeSha256:runtime,scope:'Exact first captured raw startup submission and ACK/clean shutdown only. Partial initial snapshot is not world completeness, gameplay outcomes, original pixels or an FPS benchmark.'};
const send=value=>{if(socket&&!socket.destroyed)socket.write(JSON.stringify(value)+'\n');};
async function finish(reason){
 if(ending)return;ending=true;clearTimeout(timer);if(reason)report.failure=reason;
 if(child&&child.exitCode===null){send({kind:'finish',connection});await new Promise(resolve=>{const limit=setTimeout(resolve,10000);child.once('exit',()=>{clearTimeout(limit);resolve();});});if(child.exitCode===null){report.forcedOwnedStop=true;child.kill();await new Promise(resolve=>{const limit=setTimeout(resolve,3000);child.once('exit',()=>{clearTimeout(limit);resolve();});});}}
 socket?.destroy();server.close();
 try{report.native=JSON.parse(await fs.readFile(nativePath,'utf8'));}catch{report.failure??='Native startup replay final report missing';}
 report.sourceUnchanged=true;for(const[name,digest]of Object.entries(pins))if(hash(await fs.readFile(path.join(project,name)))!==digest)report.sourceUnchanged=false;
 report.runtimeUnchanged=true;for(const[name,digest]of Object.entries(runtime))if(hash(await fs.readFile(path.join(project,name)))!==digest)report.runtimeUnchanged=false;
 const engineLog=await fs.readFile(log,'utf8').catch(()=>'');report.cleanEngine=!/SCRIPT ERROR|^ERROR:|^WARNING:|ObjectDB instances leaked|resources still in use/m.test(engineLog+'\n'+(report.errors??''));
 report.captureUnchanged=await captureReader.readCreationCapture(file).then(value=>value.sha256===opened.sha256&&value.ledgerSha256===opened.ledgerSha256&&value.reportSha256===opened.reportSha256).catch(()=>false);
 report.moduleSourcesUnchanged=true;for(const[name,digest]of Object.entries(modulePins))if(await fs.readFile(name).then(hash).catch(()=>null)!==digest)report.moduleSourcesUnchanged=false;
 report.snapshotAccepted=report.rawAcknowledged===true&&report.cleanEngine;
 report.lifecycleCompleted=report.native?.workers_remaining===0&&report.native?.protocol_finish_ack===true&&!report.forcedOwnedStop;
 report.gameplayAccepted=report.native?.success===true;
 report.expectedPartialValidationExit=report.exit===1&&report.native?.exit_acceptance?.mode==='gameplay-validation'&&report.native?.exit_acceptance?.gameplay_success===false&&report.native?.exit_acceptance?.success===false&&report.native?.success===false&&!report.native?.failure;
 report.success=!report.failure&&report.snapshotAccepted&&report.lifecycleCompleted&&report.sourceUnchanged&&report.runtimeUnchanged&&report.captureUnchanged&&report.moduleSourcesUnchanged&&(report.exit===0||report.expectedPartialValidationExit);
 if(child?.exitCode!==null)await fs.unlink(ticket).catch(()=>{});
 await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,failure:report.failure,rawAcknowledged:report.rawAcknowledged,cleanEngine:report.cleanEngine,sourceUnchanged:report.sourceUnchanged,runtimeUnchanged:report.runtimeUnchanged,report:reportPath}));resolveDone();
}
const server=net.createServer(client=>{
 if(socket){client.destroy();return;}socket=client;let buffer='';
 client.on('error',error=>{report.socketError=error.code;if(!ending)void finish('Owned offline native socket error');});client.on('close',()=>{if(!ending)void finish('Owned offline native socket closed early');});
 client.on('data',bytes=>{buffer+=bytes.toString('utf8');if(Buffer.byteLength(buffer)>1024*1024){void finish('Owned native command exceeds bound');return;}let at;while((at=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,at);buffer=buffer.slice(at+1);try{
  const value=JSON.parse(line);if(!ready){if(value.kind!=='hello'||value.token!==token)throw Error('Owned replay handshake differs');ready=true;send({kind:'session-reset',connection});send({kind:'browser-closed',connection});socket.write(opened.value.setupFrame);continue;}
  if(value.kind==='catalog-ready'&&value.connection===connection&&!report.framesSubmitted){report.milestones.push({kind:value.kind,at:Date.now()});report.framesSubmitted=true;for(const text of opened.value.rawFrames)socket.write(text);}
  else if(value.kind==='raw-world-accepted'&&value.connection===connection&&value.serial===serial&&value.generation===generation){report.milestones.push({kind:value.kind,at:Date.now()});report.rawAcknowledged=true;void finish();}
  else if(value.kind==='finished'){send({kind:'finish-ack',connection:value.connection});if(!ending)void finish('Native ended before snapshot acknowledgment');}
  else if(value.kind==='failure')void finish(String(value.reason??'Native startup failure'));
 }catch(error){void finish(error.message);}}});
});
await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
await fs.writeFile(ticket,JSON.stringify({host:'127.0.0.1',port:server.address().port,token}),{flag:'wx'});
child=spawn(engine,['--headless','--max-fps','60','--path',project,'--log-file',log,'--script','res://native_session_world.gd','--','--ticket='+ticket,'--report='+nativePath,'--prepared-cache='+path.join(directory,'prepared'),'--offline-replay=true','--settings-check=true','--creation-phase-trace=true','--capture-preview=false','--profile=false'],{cwd:project,windowsHide:true,stdio:['ignore','pipe','pipe']});
child.stdout.on('data',bytes=>report.output=((report.output??'')+bytes.toString()).slice(-12000));child.stderr.on('data',bytes=>report.errors=((report.errors??'')+bytes.toString()).slice(-12000));child.on('error',()=>void finish('Owned replay engine failed to start'));child.on('exit',code=>{report.exit=code;if(!ending)void finish('Owned replay engine exited before completion');});
timer=setTimeout(()=>void finish('Owned first-snapshot replay60s deadline'),60000);await done;process.exitCode=report.success?0:1;
