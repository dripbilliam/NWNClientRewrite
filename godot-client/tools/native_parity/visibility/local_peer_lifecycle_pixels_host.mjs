// Actual original Prelude only. Credentials arrive on private stdin, never a
// file/argv/renderer message. All source objects remain canonical server DTOs.
import fs from 'node:fs/promises';import path from 'node:path';import crypto from 'node:crypto';import net from 'node:net';import {spawn} from 'node:child_process';import {fileURLToPath} from 'node:url';
import {createInstalledNetworkSession} from '../../../../electron/installed_network_session.mjs';
import {publicCdKey,NetworkLoginIdentity} from '../../../../electron/network_login_identity.mjs';
import {playerRosterHeader} from '../../../../src/network_player_roster.js';
import {guiPanelHeaderForHost} from '../../../../src/network_gui_panel_access.js';
import {RawCombatEvents} from '../../raw-combat-events.cjs';import {RawWorldDeltas} from '../../raw-world-deltas.cjs';import {rawWorldFrames} from '../../raw-world-frames.cjs';
import {RawTileVisibility} from '../../raw-tile-visibility.cjs';import {RawCreatureVisibilityPermission} from '../../raw-creature-visibility-permission.cjs';import {NativeClockBridge} from '../../native-clock-bridge.cjs';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),workspace=path.dirname(source),label=process.argv[2];
if(!/^local-peer-lifecycle-pixels-[a-z0-9-]+$/.test(label??''))throw Error('Fresh explicit peer lifecycle label required');
const folder=path.join(source,'.cache/native-presentation-parity/root',label),stage=JSON.parse(await fs.readFile(path.join(folder,'stage.json'))),output=path.join(folder,'local-run.json'),nativeReport=path.join(folder,'native-result.json'),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
try{await fs.access(output);throw Error('Existing receipt preserved');}catch(e){if(e.code!=='ENOENT')throw e;}
if(stage.test!=='tests/native_local_peer_lifecycle_pixels_test.gd'||stage.parent.sha256!=='8dc208537d602078c588f49e59dd4a81aed9b90c38b2a02a2326b1515db3f3e7')throw Error('Exact V6 fixture required');
for(const p of stage.pins)if(hash(await fs.readFile(path.join(stage.project,p.relative)))!==p.sha256)throw Error('Staged production source differs');
for(const p of [...stage.harness,...stage.protocolPins])if(hash(await fs.readFile(p.file))!==p.sha256)throw Error('Pinned host/protocol source differs');
if(hash(await fs.readFile(stage.engine.file))!==stage.engine.sha256)throw Error('Pinned engine differs');
const chunks=[];let size=0;for await(const b of process.stdin){chunks.push(b);if((size+=b.length)>8192)throw Error('Private input bound exceeded');}
let credentials;const privateBytes=Buffer.concat(chunks);try{credentials=JSON.parse(privateBytes.toString('utf8'));}finally{privateBytes.fill(0);for(const b of chunks)b.fill(0);}
if(typeof credentials?.main?.cdKey!=='string'||typeof credentials?.peer?.cdKey!=='string')throw Error('Both protected holders are required');
const publicIds=[publicCdKey(credentials.main.cdKey),publicCdKey(credentials.peer.cdKey)];if(publicIds.some(v=>v.length!==8)||publicIds[0]===publicIds[1])throw Error('Two distinct existing protected local identities required');
// A second identity holder is retained in protected buffers for the actual
// reconnect; no saved secret or plaintext copy is introduced.
const peerIdentity=new NetworkLoginIdentity(credentials.peer);credentials.peer.cdKey='';
const report={success:false,started:new Date().toISOString(),endpoint:'127.0.0.1:5121',module:'Prelude',protectedServerPid:40664,capsule:stage.parent,publicIdentities:publicIds,publicConnections:0,nativeBuilds:0,newCredentialFiles:0,serverModuleChanges:0,peerEvents:[],rendererEvents:[],phases:[],diagnostics:[],scope:'Actual two-account unchanged original Prelude. Production V6 native renderer A observes canonical server-known peer B join/leave/rejoin, real admission/alpha/Registry and old-reference retirement. No same-ID reuse or original-client pixels/FPS/public gameplay claim.'};
let session,peerSession,peerMetadata,child,server,socket,authenticated=false,closing=false,catalogReady=false,setupSent=false,rawPending=null,rawSerial=0,interval,deadline,childExit,peerArea=-1,stageName='baseline',working=false,peerIds=[],serverPin,completed=false;
const stdout=[],stderr=[],deltas=new RawWorldDeltas(),raw=new RawCombatEvents(),project=(world,actor)=>world.entityDisclosures.transportRow(actor,raw.object(actor)),tiles=new RawTileVisibility(project),permissions=new RawCreatureVisibilityPermission(project);
const encode=v=>JSON.stringify(v,(_k,x)=>typeof x==='bigint'?{native64:String(x)}:x)+'\n';
const send=v=>{if(socket&&!socket.destroyed)socket.write(encode({connection:0,...v}));};
const clock=new NativeClockBridge({send:(frame,line)=>{if(!authenticated)return{status:'unavailable'};socket.write(line);return{status:'accepted'};},isCurrent:(value,connection)=>!closing&&value===session&&connection===0});
let finishResolve;const finished=new Promise(r=>finishResolve=r);
async function end(reason){if(closing)return;closing=true;if(reason)report.failure=reason;send({kind:reason?'finish':'peer-lifecycle-finish'});finishResolve();}
const wait=async(predicate,limit=40000)=>{const until=Date.now()+limit;while(!predicate()){if(closing||Date.now()>until)throw Error('Original local peer state deadline exceeded');await new Promise(r=>setTimeout(r,40));}};
function sources(current){const archives=[],seen=new Set();for(const e of [...current.resourceResult.resolved].reverse()){if(e.kind==='nwsync')throw Error('Unexpected network content in installed Prelude');if(!['nwm','hak'].includes(e.kind))continue;if(typeof e.resource!=='string')throw Error('Original archive lacks native file path');const file=path.resolve(e.resource);if(seen.has(file.toLowerCase()))continue;seen.add(file.toLowerCase());archives.push({path:file,priority:e.kind==='nwm'?23000000:30000000});}const tlk=current.resourceResult.resolved.find(e=>e.kind==='tlk');return{install:stage.install.directory,archives,nwsync:[],customTlk:tlk?{name:tlk.name,path:tlk.resource}:null,profileDirectory:path.join(folder,'protocol-main'),modsDirectory:path.join(folder,'empty-mods'),disabledMods:[]};}
function row(object){return session.world.entityDisclosures.transportRow(object,{...raw.object(object),nativeActorNameState:session.world.nativeActorNameTransport(object),nativeClockOwner:session.world.nativeClockOwnerTransport(object)});}
function peerInMain(){const player=[...session.world.players.values()].find(p=>p.name==='NativeLifecyclePeer');const id=[player?.objectId,player?.character?.id].find(id=>session.world.registry.get(id)?.objectType===5);const object=session.world.registry.get(id);return object&&!object.replicationRemoved&&object.areaId===session.world.areaId?{playerId:player.playerId,id,object}:null;}
function publish(){if(!catalogReady||rawPending||!session?.resourceResult?.ready)return;const area=session.world.registry.get(session.world.areaId)?.state;if(!area?.tiles)return;const data={area,objects:[...session.world.registry.objects.values()].map(row),controlledId:session.world.localObjectId,actorNameHistory:session.world.nativeActorNameHistory(),entry:session.world.entry,time:session.world.time,module:session.world.module,inventory:{inventories:[...session.world.inventories],containers:[...session.world.containers],store:session.world.store,windows:session.world.inventoryWindows.snapshot()},ui:{...playerRosterHeader(session.world),guiPanelAccess:guiPanelHeaderForHost(session.world,session.areaGeneration),scriptTargeting:session.world.scriptTargeting,scriptTargetingData:session.world.scriptTargetingData,party:session.world.party,quickbar:session.world.quickbar,journal:{entries:[...session.world.journal.entries],worldEntries:[...session.world.journal.worldEntries],loaded:session.world.journal.loaded},barter:session.world.barter,mapPins:[...session.world.mapPins],partyInviteNotice:session.world.partyInviteNotice,playerAttitudes:[...session.world.playerAttitudes],partyListRevision:session.world.partyListRevision}};const serial=++rawSerial,generation=session.areaGeneration,changed=deltas.plan({connection:0,generation,serial,data});if(!changed)return;for(const frame of rawWorldFrames({connection:0,generation,serial,data:changed}))socket.write(frame);rawPending={connection:0,generation,serial};report.rawUpdates??={full:0,delta:0,removals:0};report.rawUpdates[changed.bridgeMode]++;report.rawUpdates.removals+=changed.removedObjectIds.length;}
async function startPeer(rejoin){
 const loginIdentity=peerIdentity.forPortal('');
 const made=await createInstalledNetworkSession({install:stage.install.directory,userDirectory:path.join(folder,rejoin?'protocol-peer-rejoin':'protocol-peer'),cacheDirectory:path.join(folder,'content-peer'),modsDirectory:path.join(folder,'empty-mods'),disabledMods:[],host:'127.0.0.1',port:5121,name:'NativeLifecyclePeer',loginIdentity,onDiagnostic:d=>{if(report.diagnostics.length<96)report.diagnostics.push({owner:'peer',code:d.code});}});
 peerSession=made.session;peerMetadata=made.metadata;peerArea=-1;peerSession.portalTransfer.prepare=()=>{throw Error('Portal travel forbidden in local lifecycle fixture');};
 peerSession.on('state',state=>report.phases.push({owner:rejoin?'peer-rejoin':'peer',phase:state.phase}));
 const character=await fs.readFile(path.join(stage.install.directory,'data/lcv/fighter.bic'));try{const digest=hash(character);if(report.peerCharacterSha256&&report.peerCharacterSha256!==digest)throw Error('Installed peer BIC changed');report.peerCharacterSha256=digest;await peerSession.selectCharacter(character);}finally{character.fill(0);}
 await peerSession.connect({host:'127.0.0.1',port:5121,expectedServerPublicKey:Buffer.from(serverPin,'base64'),metadata:made.metadata,timeout:40000});
 await wait(()=>peerSession.phase==='playing'&&peerSession.world.registry.get(peerSession.world.localObjectId)?.objectType===5);
 await wait(()=>peerInMain()!==null);const known=peerInMain();peerIds.push(known.id);
 report.peerEvents.push({kind:rejoin?'rejoin':'join',at:Date.now(),playerId:known.playerId,id:known.id,peerControlledId:peerSession.world.localObjectId,areaId:session.world.areaId,areaGeneration:session.areaGeneration,source:row(known.object)});
 stageName=rejoin?'rejoin':'join';publish();send({kind:'peer-lifecycle-phase',phase:stageName,id:known.id,afterSerial:rawPending?.serial??deltas.base?.serial??1});
}
async function command(m){
 if(!authenticated){if(m.kind!=='hello'||m.token!==token)throw Error('Private native handshake failed');authenticated=true;return;}
 if(m.kind==='catalog-ready'){catalogReady=true;return;}
 if(m.kind==='raw-world-accepted'){if(rawPending&&deltas.acknowledge(m))rawPending=null;return;}
 if(m.kind==='area-ready'){if(!session.areaReadySent)await session.areaReady(m.generation);return;}
 if(m.kind==='finished'){report.nativeFinished=m.success===true;send({kind:'finish-ack'});return;}
 if(m.kind==='failed')throw Error('Actual renderer failed');
 if(m.kind!=='peer-lifecycle-observed')return;
 report.rendererEvents.push(m);if(m.failures?.length)throw Error('Actual renderer lifecycle assertions failed');
 if(m.phase!==stageName)throw Error('Renderer lifecycle boundary order differs');
 if(m.phase==='baseline'){stageName='peer-starting';void startPeer(false).catch(e=>end(e.message));}
 else if(m.phase==='join'){
  stageName='peer-leaving';await peerSession.disconnect();await wait(()=>!peerInMain());const rosterLeftAt=Date.now();await wait(()=>{const old=session.world.registry.get(peerIds[0]);return !old||old.replicationRemoved;},25000);report.objectRetirementAfterRosterMs=Date.now()-rosterLeftAt;
  const old=session.world.registry.get(peerIds[0]);if(old&&!old.replicationRemoved)throw Error('Peer account left but actual client-known object remains live');
  report.peerEvents.push({kind:'leave',at:Date.now(),id:peerIds[0],registryPresent:Boolean(old),replicationRemoved:old?.replicationRemoved??null,rosterPresent:[...session.world.players.values()].some(p=>p.name==='NativeLifecyclePeer')});
  stageName='leave';publish();send({kind:'peer-lifecycle-phase',phase:'leave',id:peerIds[0],afterSerial:rawPending?.serial??deltas.base?.serial??1});
 }else if(m.phase==='leave'){stageName='peer-rejoining';void startPeer(true).catch(e=>end(e.message));}
 else if(m.phase==='rejoin'){completed=true;report.sameNumericIdReused=peerIds[0]===peerIds[1];await end();}
}
const token=crypto.randomBytes(32).toString('hex'),ticket=path.join(folder,'local-ticket.json');
try{
 const log=await fs.readFile(path.join(workspace,'runtime-logs/local-multiplayer-server/logs/nwengineLog.txt'),'utf8');serverPin=log.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];if(!serverPin||!log.includes('Loading Module: Prelude'))throw Error('Original Prelude public identity/module not proven');
 let queue=Promise.resolve();server=net.createServer(client=>{if(socket){client.destroy();return;}socket=client;let pending='';client.on('data',b=>{pending+=b.toString('utf8');if(Buffer.byteLength(pending)>1048576){void end('Native frame bound exceeded');return;}let i;while((i=pending.indexOf('\n'))>=0){const line=pending.slice(0,i);pending=pending.slice(i+1);queue=queue.then(()=>command(JSON.parse(line))).catch(e=>end(e.message));}});client.on('error',()=>{void end('Private loopback bridge error');});});
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});await fs.writeFile(ticket,JSON.stringify({host:'127.0.0.1',port:server.address().port,token}),{flag:'wx'});
 const userdata=path.join(folder,'userdata-local');await fs.mkdir(userdata,{recursive:true});
 const args=['--path',stage.project,'--screen','0','--script','res://'+stage.test,'--','--ticket='+ticket,'--report='+nativeReport,'--prepared-cache='+path.join(folder,'prepared-local'),'--prepared-cache-write=sync','--particle-kernel=compiled','--particles=false','--native-lighting=enhanced','--native-surface-output=true','--native-light-history','--native-overhead-clocks=true','--particle-random=native','--particle-clocks=native','--particle-pose-leases=managed','--light-input-registry=builtin','--drive-collision=indexed','--highlight=native-bounds','--native-postprocess-mask=28','--native-postprocess-midpoint=0.4','--native-postprocess-intensity=0.15','--native-postprocess-vibrance=0.7','--capture-preview=false','--material-prewarm=false'];
 child=spawn(stage.engine.file,args,{cwd:workspace,windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,APPDATA:userdata,LOCALAPPDATA:userdata,NWN_PARTICLE_KERNEL:'compiled'}});report.childPid=child.pid;report.nativeArgs=args;child.stdout.on('data',b=>stdout.push(b));child.stderr.on('data',b=>stderr.push(b));
 childExit=new Promise(resolve=>{child.once('error',e=>{void end('Scoped renderer child failed');resolve(null);});child.once('exit',code=>{if(!closing)void end('Scoped renderer exited before lifecycle completed');resolve(code);});});
 await wait(()=>authenticated,20000);
 const made=await createInstalledNetworkSession({install:stage.install.directory,userDirectory:path.join(folder,'protocol-main'),cacheDirectory:path.join(folder,'content-main'),modsDirectory:path.join(folder,'empty-mods'),disabledMods:[],host:'127.0.0.1',port:5121,name:'NativeLifecycleMain',credentials:credentials.main,onDiagnostic:d=>{if(report.diagnostics.length<96)report.diagnostics.push({owner:'main',code:d.code});}});credentials=null;session=made.session;session.portalTransfer.prepare=()=>{throw Error('Portal travel forbidden in local lifecycle fixture');};report.clockAttach=clock.attach(session,0);
 session.on('state',state=>{report.phases.push({owner:'main',phase:state.phase});send({kind:'lobby',state:{...state,connected:!session.closed}});});
 session.on('message',({message,areaGeneration})=>{if(closing)return;if(stageName==='peer-leaving'&&message.kind==='object-updates'){report.departureRecords??=[];for(const r of message.records??[])if(r.id===peerIds[0]&&report.departureRecords.length<32)report.departureRecords.push({action:r.action,id:r.id,remove:r.remove??null,at:Date.now()});}for(const frame of tiles.frames(session.world,message,areaGeneration,0))send(frame);for(const frame of permissions.frames(session.world,message,areaGeneration,0))send(frame);if(['dialog-entry','dialog-replies','dialog-selected','dialog-close','server-speech'].includes(message.kind))send({kind:'ui-protocol',generation:areaGeneration,message});});
 const bic=await fs.readFile(path.join(stage.install.directory,'data/lcv/wizard.bic'));try{report.mainCharacterSha256=hash(bic);await session.selectCharacter(bic);}finally{bic.fill(0);}
 await session.connect({host:'127.0.0.1',port:5121,expectedServerPublicKey:Buffer.from(serverPin,'base64'),metadata:made.metadata,timeout:40000});
 interval=setInterval(async()=>{if(closing||working)return;working=true;try{
  clock.flush(session,0);
  if(session.resourceResult?.ready&&!setupSent){setupSent=true;report.resourceSources=sources(session);send({kind:'setup',interactive:true,install:stage.install.directory,moduleName:'Prelude',serverLabel:'127.0.0.1:5121',resourceSources:report.resourceSources});}
  if(peerSession&&!peerSession.closed&&peerSession.resourceResult?.ready&&peerSession.world.registry.get(peerSession.world.areaId)?.state?.tiles&&peerArea!==peerSession.areaGeneration){peerArea=peerSession.areaGeneration;await peerSession.areaReady(peerArea);}
  publish();
  if(session.phase==='playing'&&stageName==='baseline')send({kind:'peer-lifecycle-phase',phase:'baseline',afterSerial:rawPending?.serial??deltas.base?.serial??1});
 }catch(e){await end(e.message);}finally{working=false;}},120);
 deadline=setTimeout(()=>{void end('Bounded original-server peer lifecycle timed out');},150000);
 await finished;report.nativeExit=await Promise.race([childExit,new Promise(resolve=>setTimeout(()=>resolve('preserved-after-timeout'),20000))]);
 try{report.native=JSON.parse(await fs.readFile(nativeReport));}catch{}
 report.problems=Buffer.concat([...stdout,...stderr]).toString('utf8').split(/\r?\n/).filter(line=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances leaked|resources still in use|Invalid call/.test(line));
 report.sourceChanged=[];for(const p of stage.pins)if(hash(await fs.readFile(path.join(stage.project,p.relative)))!==p.sha256)report.sourceChanged.push(p.relative);
 report.protocolChanged=[];for(const p of [...stage.harness,...stage.protocolPins])if(hash(await fs.readFile(p.file))!==p.sha256)report.protocolChanged.push(p.file);
 report.success=!report.failure&&completed&&report.nativeExit===0&&report.native?.success===true&&report.native?.clean_exit===true&&!report.problems.length&&!report.sourceChanged.length&&!report.protocolChanged.length&&report.rendererEvents.map(v=>v.phase).join(',')==='baseline,join,leave,rejoin';
}catch(e){await end(e.message);report.failure??=e.message;}
finally{
 clearInterval(interval);clearTimeout(deadline);clock.retire(session,0);peerIdentity.dispose();await peerSession?.disconnect().catch(()=>{});await session?.disconnect().catch(()=>{});
 if(credentials){credentials.main.cdKey='';credentials.peer.cdKey='';}
 socket?.destroy();server?.close();if(child&&child.exitCode===null){report.preservedChildPid=child.pid;child.stdout.destroy();child.stderr.destroy();child.unref();}
 await fs.unlink(ticket).catch(e=>{if(e.code!=='ENOENT')throw e;});await fs.writeFile(path.join(folder,'local-stdout.log'),Buffer.concat(stdout),{flag:'wx'});await fs.writeFile(path.join(folder,'local-stderr.log'),Buffer.concat(stderr),{flag:'wx'});
 report.images=[];for(const name of await fs.readdir(folder))if(name.endsWith('.png'))report.images.push({file:path.join(folder,name),sha256:hash(await fs.readFile(path.join(folder,name)))});report.finished=new Date().toISOString();report.stage={file:path.join(folder,'stage.json'),sha256:hash(await fs.readFile(path.join(folder,'stage.json')))};await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,failure:report.failure,checks:report.native?.peer_lifecycle?.checks,nativeExit:report.nativeExit,preservedChildPid:report.preservedChildPid,receipt:output}));
}
if(!report.success)process.exitCode=1;
