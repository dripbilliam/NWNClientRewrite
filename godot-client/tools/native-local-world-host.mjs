// Owned Prelude functional check. This process owns protocol only. Rendering
// modules are rejected before import; original assets never cross its wire.
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import net from 'node:net';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {registerHooks} from 'node:module';
import {fileURLToPath} from 'node:url';
import {submitNativeDialogReply} from './native-dialog-input.mjs';
import {parseErf} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project),loadedModules=new Set();
registerHooks({resolve(specifier,context,next){const value=next(specifier,context);if(specifier==='three'||specifier.startsWith('three/')||specifier==='electron'||/\/(?:model_parser|model_hierarchy|prepared_model_geometry|network_scene|native_ui_assets|native_rich_text|network_text|nui_skin|inventory_layout|item_icon|main)\.js$/.test(value.url)||/\/(?:export-room|export-rigs|area-staging|content-staging|gameplay-text|nui-service|inventory-service)\./.test(value.url))throw Error('Rendering dependency forbidden in native protocol owner: '+specifier+' imported by '+(context.parentURL?.split('/').at(-1)??'entry'));if(value.url.startsWith('file:'))loadedModules.add(fileURLToPath(value.url));return value;}});
const {createInstalledNetworkSession}=await import('../../electron/installed_network_session.mjs');
const chunks=[];let inputSize=0;
for await(const chunk of process.stdin){inputSize+=chunk.length;if(inputSize>16384)throw Error('Private local request exceeds limit');chunks.push(chunk);}
let request;try{request=JSON.parse(Buffer.concat(chunks).toString('utf8'));}finally{for(const chunk of chunks)chunk.fill(0);}
const install=path.resolve(request.install),run=request.run;
const interactive=request.interactive===true;
const transitionCount=request.transitionCount??1;
if(!Number.isInteger(transitionCount)||transitionCount<1||transitionCount>8||interactive&&transitionCount!==1)throw Error('Invalid local transition probe count');
const transitionScript=transitionCount>1?'tests/native_world_transitions_test.gd':'native_live_world.gd';
const testDeadline=120000+(transitionCount-1)*35000;
const dense=request.denseFixture===true,port=dense?5123:5121,moduleName=dense?'DensePerf':'Prelude',serverHome=path.join(root,'runtime-logs',dense?'dense-performance-server':'local-multiplayer-server'),moduleFile=dense?path.join(serverHome,'modules/DensePerf.mod'):path.join(install,'data/nwm/Prelude.nwm');
if(dense&&!interactive)throw Error('Dense fixture requires interactive mode');
if(!/^[a-z0-9-]+$/.test(run??''))throw Error('Invalid local run name');
const output=path.join(project,'reports',run+'.json'),nativeReport=path.join(project,'reports',run+'.native.json'),debugLog=path.join(project,'reports',run+'.cdb.log'),engineLog=path.join(project,'reports',run+'.engine.log'),commands=path.join(project,'reports',run+'.cdb.txt');
for(const file of [output,nativeReport,debugLog,engineLog,commands]){try{await fs.access(file);throw Error('Local report already exists');}catch(error){if(error.code!=='ENOENT')throw error;}}
const report={success:false,endpoint:'127.0.0.1:5121',protocolOnly:true,publicConnections:0,renderingPrepared:false,performanceAccepted:false,scope:'Live original Prelude rendered from original resources by native Godot; scripted authoritative walk, not full campaign UI/input/effects acceptance',states:[],diagnostics:[],observations:[]};
report.interactive=interactive;if(interactive)report.scope='Interactive local native Prelude with installed wizard test character. Full gameplay/UI migration remains incomplete; no automated performance acceptance.';
report.endpoint=`127.0.0.1:${port}`;report.module=moduleName;if(dense)report.scope='Native dense fixture: 48 server-controlled people, 48 braziers and 32 other props; original installed assets, loopback only. Particle/effect parity incomplete.';
const sourceFiles=['native_live_world.gd','tools/native-local-world-host.mjs','project.godot','systems/bridge_frames.gd','systems/network_motion.gd','systems/area_environment.gd','systems/camera_controller.gd','systems/entity_registry.gd','systems/native_hud.gd','systems/world_input.gd','systems/draggable_panel.gd','systems/native_gameplay_ui.gd','systems/server_text.gd','systems/server_chat.gd','systems/server_conversation.gd','systems/server_examine.gd','../electron/network_game_session.mjs'];
sourceFiles.push(transitionScript,'tools/test-native-local-world.ps1','native/particle_kernel.cpp','native/particle_simulation.hpp','native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','tools/build-particle-kernel.ps1','tools/ensure-particle-kernel.ps1');
sourceFiles.push('systems/native_ui_skin.gd','systems/native_interaction_policy.gd','systems/native_loading_screen.gd');
sourceFiles.push('systems/native_keyboard.gd','systems/keyboard_drive.gd','systems/game_camera_state.gd','../electron/network_peer.mjs');
sourceFiles.push('systems/native_inventory.gd','systems/native_item_icons.gd','systems/server_inventory.gd','systems/inventory_slot.gd','systems/inventory_repository.gd','systems/server_store.gd');
for(const directory of ['native_data','native_render'])for(const file of await fs.readdir(path.join(project,'systems',directory)))if(file.endsWith('.gd'))sourceFiles.push('systems/'+directory+'/'+file);
for(const file of ['model_rigs','model_native_animation','model_native_pose','model_runs','model_controllers'])sourceFiles.push('systems/'+file+'.gd');
for(const file of await fs.readdir(path.join(project,'native')))if(file.endsWith('.hpp')&&!sourceFiles.includes('native/'+file))sourceFiles.push('native/'+file);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),sources={};for(const file of sourceFiles)sources[file]=hash(await fs.readFile(path.join(project,file)));
let session,server,stream,child,timer,observer,ending=false,authenticated=false,walkSent=false,walkProbeSent=false,startedPlaying=0,walkStarted=0,initial=null,maximumDistance=0;
let snapshotGeneration=-1,movementRevision=0;
let driveStarted=0,driveFinished=0,driveOrigin=null,driveDistance=0;
let initialGeneration=-1,clickDistance=0;
let interactionStarted=0,interactionFinished=0;
let doorStarted=0,doorFinished=0,transitionsDone=0;
let inventoryStarted=false,inventoryFinished=false,inventoryReopenStarted=false,inventoryReopenFinished=false;
let campaignResources;
function campaignDoors(){
 const area=session.world.registry.get(session.world.areaId)?.state,bytes=campaignResources?.entries.get(area?.resRef+':2023');
 const authored=bytes?(parseGff(bytes).root['Door List']??[]).filter(row=>row.LinkedTo):[];
 const doors=[...session.world.registry.objects.values()].filter(o=>o.objectType===10&&o.areaId===session.world.areaId&&!o.replicationRemoved&&o.replicated?.hasTransition&&o.replicated?.position);
 // Fixture policy: tile-generated story-barred doors are not campaign exits.
 // Match the unchanged module's authored linked doors; never unlock or alter one.
 return authored.length?doors.filter(door=>authored.some(row=>Math.hypot(door.replicated.position[0]-row.X,door.replicated.position[1]-row.Y)<0.1)):doors;
}
const spokenTargets=new Set();
const movementKeys=['position','orientation','animation','path','walkRate','runRate','field8F4','field8EC','actionFlag'];
const token=crypto.randomBytes(32).toString('hex'),temporary=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-native-local-world-')),ticket=path.join(temporary,'ticket.json');
const coldCache=request.coldCache===true?path.join(temporary,'prepared'):null;
report.coldPreparedCache=Boolean(coldCache);
if(coldCache){await fs.mkdir(coldCache);report.coldCacheInitiallyEmpty=(await fs.readdir(coldCache)).length===0;}
const send=message=>{if(stream&&!stream.destroyed)stream.write(JSON.stringify(message,(_k,v)=>typeof v==='bigint'?{native64:String(v)}:v)+'\n');};
async function finish(reason){if(ending)return;ending=true;if(reason)report.failure=reason;clearInterval(observer);clearTimeout(timer);await session?.disconnect().catch(()=>{});send({kind:'finish'});}
async function command(message){
 report.lastCommandKind=message.kind;
 if(!authenticated){if(message.kind!=='hello'||message.token!==token)throw Error('Native protocol handshake failed');authenticated=true;send({kind:'setup',install,interactive,moduleFile,moduleName});return;}
 if(message.kind==='area-ready'){
  if(message.generation!==session.areaGeneration||message.areaId!==session.world.areaId)throw Error('Native area acknowledgement is stale');
  if(!session.areaReadySent)await session.areaReady(message.generation);report.admittedAreas??=[];report.admittedAreas.push({id:message.areaId,generation:message.generation});startedPlaying||=Date.now();return;
 }
 if(['inventory-open','inventory-close','inventory-page','inventory-container','item-action','item-use'].includes(message.kind)){
  try{
   if(message.generation!==session.areaGeneration||message.areaId!==session.world.areaId||session.phase!=='playing')throw Error('Inventory owner is stale');
   const scope={areaId:message.areaId,areaGeneration:message.generation};
   if(message.kind==='inventory-open'){await session.inventoryWindow({...scope,open:true});await session.inventoryPanel({...scope,panel:message.page});}
   else if(message.kind==='inventory-close'){const targetId=session.world.containers.get('C');if(targetId!==undefined&&targetId!==0x7f000000)await session.containerInput({...scope,targetId,operation:'close'});await session.inventoryWindow({...scope,open:false});}
   else if(message.kind==='inventory-page')await session.inventoryPanel({...scope,panel:message.page});
   else if(message.kind==='inventory-container')await session.containerInput({...scope,targetId:message.targetId,operation:message.operation});
   else if(message.kind==='item-use')await session.interact({...scope,targetId:message.itemId,action:'object.use'});
   else await session.itemAction({...scope,itemId:message.itemId,operation:message.operation,...Object.fromEntries(['slot','x','y','destinationId'].filter(key=>message[key]!==undefined).map(key=>[key,message[key]]))});
   report.inventoryRequests??=[];report.inventoryRequests.push({kind:message.kind,operation:message.operation,itemId:message.itemId});
   send({kind:'ui-protocol',generation:message.generation,message:{kind:'inventory-command-result',requestId:message.requestId,accepted:true}});
  }catch{send({kind:'ui-protocol',generation:message.generation,message:{kind:'inventory-command-result',requestId:message.requestId,accepted:false,reason:'The inventory request is stale or unavailable.'}});}
  return;
 }
 if(['walk','drive','interact','pickup','examine','chat','reply'].includes(message.kind)){
  if(message.generation!==session.areaGeneration||message.areaId!==session.world.areaId||session.phase!=='playing')throw Error('Native player command is stale');
  const scope={areaId:message.areaId,areaGeneration:message.generation};report.inputRequests??=[];report.inputRequests.push({kind:message.kind,targetId:message.targetId});
  if(message.kind==='walk'){walkSent=true;walkStarted=Date.now();await session.walkTo({...scope,position:message.position,run:false});}
  else if(message.kind==='drive'){const result=await session.keyboardMove({...scope,actorId:message.actorId,operation:message.operation,position:message.position,heading:message.heading,flags:message.flags,transmit:message.transmit??true});send({kind:'drive-ack',generation:message.generation,areaId:message.areaId,actorId:message.actorId,lifetime:message.lifetime,requestId:message.requestId,...result});report.keyboardOperations??=[];report.keyboardOperations.push(message.operation);}
  else if(message.kind==='interact')await session.interact({...scope,targetId:message.targetId,action:message.action,...(message.position?{position:message.position}:{})});
  else if(message.kind==='pickup')await session.itemAction({...scope,itemId:message.targetId,operation:'pickup'});
  else if(message.kind==='chat')await session.chat({...scope,actorId:session.world.localObjectId,channel:message.channel,text:message.text,...(message.recipient?{recipient:message.recipient}:{})});
  else if(message.kind==='reply'){
   const result=await submitNativeDialogReply(session,{...scope,entryId:message.entryId,replyId:message.replyId,abort:message.abort},value=>send({kind:'ui-protocol',generation:message.generation,message:value}));
   if(result.resynchronized)report.dialogResynchronizations=(report.dialogResynchronizations??0)+1;
  }
  else await session.examine({...scope,actorId:session.world.localObjectId,targetId:message.targetId});
  return;
 }
 if(message.kind==='observed'){
  if(report.observations.length<100)report.observations.push(message);
  if(interactive){await fs.writeFile(path.join(project,'reports',run+'.progress.json'),JSON.stringify({endpoint:report.endpoint,module:moduleName,at:new Date().toISOString(),...message}));}
  if(interactive)return;
  if(session.phase==='playing'&&message.state.ready&&message.state.pending_batches===0&&!inventoryStarted){inventoryStarted=true;send({kind:'probe-inventory'});}
  if(inventoryFinished&&session.phase==='playing'&&message.state.ready&&message.state.pending_batches===0&&!walkProbeSent){const p=session.world.registry.get(session.world.localObjectId)?.replicated?.position;if(p){initial=[...p];initialGeneration=session.areaGeneration;walkProbeSent=true;send({kind:'probe-walk',generation:session.areaGeneration,position:[p[0]+1.5,p[1],p[2]]});}}
  if(walkStarted&&message.controlledDistance>0.2&&Date.now()-walkStarted>4000&&!driveStarted){clickDistance=maximumDistance;driveStarted=Date.now();driveOrigin=session.world.registry.get(session.world.localObjectId)?.replicated?.position?.slice();send({kind:'probe-drive'});}
  if(driveFinished&&!interactionStarted&&Date.now()-driveFinished>2000){
   const player=session.world.registry.get(session.world.localObjectId)?.replicated?.position;
   const targets=[...session.world.registry.objects.values()].filter(o=>o.id!==session.world.localObjectId&&o.objectType===5&&o.areaId===session.world.areaId&&!o.replicationRemoved&&o.replicated?.position);
   targets.sort((a,b)=>Math.hypot(...a.replicated.position.map((v,i)=>v-player[i]))-Math.hypot(...b.replicated.position.map((v,i)=>v-player[i])));
   if(!targets.length)throw Error('Original campaign has no conversation target');
   interactionStarted=Date.now();spokenTargets.add(targets[0].id);send({kind:'probe-interact',targetId:targets[0].id});
  }
  if(interactionFinished&&!doorStarted&&Date.now()-interactionFinished>1000){
   const door=campaignDoors()[0];
   if(!door)throw Error('Original campaign has no transition door');doorStarted=Date.now();send({kind:'probe-door',targetId:door.id});
  }
  if(doorFinished&&transitionsDone<transitionCount&&Date.now()-doorFinished>1000){
   const player=session.world.registry.get(session.world.localObjectId)?.replicated?.position;
   const doors=campaignDoors();
   doors.sort((a,b)=>Math.hypot(...a.replicated.position.map((v,i)=>v-player[i]))-Math.hypot(...b.replicated.position.map((v,i)=>v-player[i])));
   if(!doors.length)throw Error('Original campaign return transition door is unavailable');
   doorStarted=Date.now();doorFinished=0;send({kind:'probe-door',targetId:doors[0].id});
  }
  if(doorFinished&&transitionsDone===transitionCount&&!inventoryReopenStarted&&Date.now()-doorFinished>1000){inventoryReopenStarted=true;send({kind:'probe-inventory',reopen:true});}
  if(inventoryReopenFinished)await finish();return;
 }
 if(message.kind==='drive-probe-done'){driveFinished=Date.now();return;}
 if(message.kind==='interact-probe-done'){
  const next=[...session.world.registry.objects.values()].find(o=>o.id!==session.world.localObjectId&&o.objectType===5&&o.areaId===session.world.areaId&&!o.replicationRemoved&&o.replicated?.position&&!spokenTargets.has(o.id));
  if(next&&spokenTargets.size<2){spokenTargets.add(next.id);send({kind:'probe-interact',targetId:next.id});}
  else interactionFinished=Date.now();return;
 }
 if(message.kind==='door-probe-done'){
  if(message.generation!==session.areaGeneration||transitionsDone>=transitionCount)throw Error('Transition probe acknowledgement is stale');
  transitionsDone++;doorFinished=Date.now();return;
 }
 if(message.kind==='inventory-probe-done'){
  const item=session.world.registry.get(message.itemId),location=item?.inventoryLocation;
  if(location?.channel!=='I'||location.ownerId!==session.world.localObjectId||location.slot!==message.slot)throw Error('Original server inventory differs from native equipped view');
  report.inventoryProofs??=[];report.inventoryProofs.push({itemId:message.itemId,slot:location.slot,reopen:message.reopen,generation:session.areaGeneration});
  if(message.reopen)inventoryReopenFinished=true;else inventoryFinished=true;return;
 }
 if(message.kind==='finished'){send({kind:'finish-ack'});report.nativeFinished=message.success;await finish();}
}
try{
 campaignResources=parseErf(await fs.readFile(moduleFile));
 const serverLog=await fs.readFile(path.join(serverHome,'logs/nwengineLog.txt'),'utf8'),pin=serverLog.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];
 if(!pin||!serverLog.includes('Loading Module: '+moduleName))throw Error('Owned local server identity/module unavailable');
 if(dense){const fixture=JSON.parse(await fs.readFile(path.join(root,'backups/animations/dense-server-fixture-v1.json'),'utf8'));if(hash(await fs.readFile(moduleFile))!==fixture.sha256)throw Error('Authored dense module differs');report.fixture=fixture;}
 const created=await createInstalledNetworkSession({install,host:'127.0.0.1',port,name:'GodotLocalTest',credentials:request.credentials,onDiagnostic:d=>report.diagnostics.push(d)});session=created.session;delete request.credentials;
 report.packets=[];session.peer.on('packet',p=>{if(report.packets.length<1000)report.packets.push(p);});
 session.on('state',s=>{if(report.states.at(-1)!==s.phase)report.states.push(s.phase);});
 session.on('message',({message,areaGeneration})=>{
  if(ending||!authenticated)return;
  if(['server-speech','dialog-entry','dialog-replies','dialog-selected','dialog-close','examine','custom-token','tlk-overrides','inventory-result'].includes(message.kind)){report.uiMessages??={};report.uiMessages[message.kind]=(report.uiMessages[message.kind]??0)+1;send({kind:'ui-protocol',generation:areaGeneration,message});}
  if(snapshotGeneration!==areaGeneration||message.kind!=='object-updates')return;
  const records=[];
  for(const event of session.world.presentationChanges){
   if(event.action!=='movement')continue;
   const object=session.world.registry.get(event.id);
   if(!object||object.objectType!==5||object.areaId!==session.world.areaId||object.replicationRemoved)continue;
   const initial=Object.fromEntries(movementKeys.filter(key=>object.replicated[key]!==undefined).map(key=>[key,structuredClone(object.replicated[key])]));
   records.push({id:event.id,revision:++movementRevision,created:Boolean(event.created),changes:structuredClone(event.changes),initial});
  }
  if(records.length){report.rawMovementRecords=(report.rawMovementRecords??0)+records.length;send({kind:'movement',areaId:session.world.areaId,generation:areaGeneration,records});}
 });
 // This proof cannot follow a server transfer to any other endpoint.
 session.portalTransfer.prepare=()=>{throw Error('Public transfers forbidden in native local proof');};
 const character=await fs.readFile(path.join(install,'data/lcv/wizard.bic'));try{report.characterSha256=hash(character);await session.selectCharacter(character);}finally{character.fill(0);}
 let chain=Promise.resolve();
 server=net.createServer(socket=>{if(stream){socket.destroy();return;}stream=socket;let buffered='';socket.on('data',bytes=>{buffered+=bytes.toString('utf8');if(buffered.length>16777216){void finish('Native command frame exceeds limit');socket.destroy();return;}let at;while((at=buffered.indexOf('\n'))>=0){const line=buffered.slice(0,at);buffered=buffered.slice(at+1);chain=chain.then(()=>command(JSON.parse(line))).catch(error=>finish('Native '+String(report.lastCommandKind)+' command failed: '+error.message));}});socket.on('error',()=>{void finish('Native protocol socket failed');});});
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
 await fs.writeFile(ticket,JSON.stringify({host:'127.0.0.1',port:server.address().port,token}),{flag:'wx'});
 const breakpoint='.echo NATIVE_LOCAL_EXCEPTION;.exr -1;.ecxr;kv;~* k;q';await fs.writeFile(commands,['.echo NATIVE_LOCAL_START',...['av','0xc0000374','0xc0000409','0xc000001d'].map(v=>`sxe -c "${breakpoint}" ${v}`),'.echo NATIVE_LOCAL_ARMED','g'].join('\n')+'\n',{flag:'wx'});
 const executable=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe');report.nativeExecutableSha256=hash(await fs.readFile(executable));
 child=spawn('C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe',['-hd','-G','-sins','-y',path.join(project,'.tools'),'-logo',debugLog,'-cf',commands,executable,'--path',project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--log-file',engineLog,'--script','res://'+transitionScript,'--','--ticket='+ticket,'--report='+nativeReport,...(coldCache?['--prepared-cache='+coldCache]:[]),...(request.profile===true?['--profile=true','--profile-control='+path.join(project,'reports',run+'.control.json')]:[])],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 const logs=[];child.stdout.on('data',b=>logs.push(b));child.stderr.on('data',b=>logs.push(b));
 const exited=new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',code=>resolve(code));});
 if(!interactive)timer=setTimeout(()=>{void finish('Native local rendering exceeded its '+testDeadline+' ms deadline');},testDeadline);
 await session.connect({host:'127.0.0.1',port,timeout:45000,expectedServerPublicKey:Buffer.from(pin,'base64'),metadata:created.metadata});
 observer=setInterval(()=>{
  if(ending||!authenticated||session.closed)return;
  const area=session.world.registry.get(session.world.areaId)?.state;if(!area?.tiles)return;
  const position=session.world.registry.get(session.world.localObjectId)?.replicated?.position;if(initial&&position&&session.areaGeneration===initialGeneration)maximumDistance=Math.max(maximumDistance,Math.hypot(...position.map((v,i)=>v-initial[i])));
  if(driveOrigin&&position&&!interactionStarted)driveDistance=Math.max(driveDistance,Math.hypot(...position.map((v,i)=>v-driveOrigin[i])));
  send({kind:'snapshot',generation:session.areaGeneration,data:{area,objects:[...session.world.registry.objects.values()],controlledId:session.world.localObjectId,entry:session.world.entry,time:session.world.time,module:session.world.module,inventory:{inventories:[...session.world.inventories],containers:[...session.world.containers],store:session.world.store}}});
  snapshotGeneration=session.areaGeneration;
 },100);
 report.debuggerExit=await (interactive?exited:Promise.race([exited,new Promise((_,reject)=>{const deadline=setTimeout(()=>reject(Error('Owned native debugger exceeded deadline; preserved for inspection')),testDeadline+30000);deadline.unref();})]));await finish();await fs.writeFile(path.join(project,'reports',run+'.stdout.log'),Buffer.concat(logs));
 const debug=await fs.readFile(debugLog,'utf8'),engine=await fs.readFile(engineLog,'utf8'),native=JSON.parse(await fs.readFile(nativeReport,'utf8'));
 report.debuggerArmed=/^NATIVE_LOCAL_ARMED\r?$/m.test(debug);report.nativeException=/^NATIVE_LOCAL_EXCEPTION\r?$/m.test(debug);report.engineErrors=/^ERROR:|SCRIPT ERROR|ObjectDB instances leaked|resources still in use/m.test(engine);report.native=native;report.walkSent=walkSent;report.authoritativeDistance=maximumDistance;report.authoritativeClickDistance=clickDistance;report.authoritativeDriveDistance=driveDistance;
 report.sourceUnchanged=true;for(const file of sourceFiles)if(hash(await fs.readFile(path.join(project,file)))!==sources[file])report.sourceUnchanged=false;
 report.sourceSha256=sources;report.loadedProtocolModules={};for(const file of loadedModules)if(file.startsWith(root+path.sep))report.loadedProtocolModules[path.relative(root,file).replaceAll('\\','/')]=hash(await fs.readFile(file));
 report.nativeUiReady=Boolean(native.gameplay_ui?.tables_ready&&native.gameplay_ui?.skin?.done&&native.gameplay_ui?.skin?.fonts_ready&&!native.gameplay_ui.errors.length&&!native.gameplay_ui.skin.errors.length);
 report.requestedTransitions=transitionCount;report.completedTransitions=transitionsDone;
 const gameplayPassed=interactive||(transitionsDone===transitionCount&&walkSent&&clickDistance>0.2&&clickDistance<2.0&&driveDistance>0.2&&native.keyboard_probe?.released&&native.keyboard_probe?.inventory_open&&native.inventory_probe?.visible_pixels>0&&native.inventory_reopen_probe?.visible_pixels>0&&native.interaction_probe?.server_dialog_closed&&native.door_probe?.new_area_ready&&native.camera?.valid&&report.keyboardOperations?.includes('stop'));
 report.success=!report.failure&&native.success&&gameplayPassed&&report.nativeUiReady&&report.nativeFinished&&report.debuggerArmed&&!report.nativeException&&!report.engineErrors&&report.debuggerExit===0&&report.sourceUnchanged;
}catch(error){report.failure=error.message;await finish();}
finally{
 clearTimeout(timer);clearInterval(observer);await session?.disconnect().catch(()=>{});stream?.destroy();server?.close();for(const key of Object.keys(request.credentials??{}))request.credentials[key]='';
 if(child&&child.exitCode===null){report.preservedDebuggerPid=child.pid;child.stdout.destroy();child.stderr.destroy();child.unref();}
 // Only the generated ticket in this private directory is removed.
 await fs.unlink(ticket).catch(e=>{if(e.code!=='ENOENT')throw e;});
 if(coldCache&&child?.exitCode!==null){
  const actual=await fs.realpath(coldCache),parent=await fs.realpath(temporary);
  if(actual!==path.join(parent,'prepared')||!actual.startsWith(parent+path.sep))throw Error('Cold-cache cleanup escaped its owned temporary directory');
  await fs.rm(actual,{recursive:true});report.coldCacheRemoved=true;
 }
 if(!coldCache||report.coldCacheRemoved)await fs.rmdir(temporary);
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,failure:report.failure,states:report.states,authoritativeDistance:report.authoritativeDistance,nativeDistance:report.native?.controlled_distance,debuggerExit:report.debuggerExit,engineErrors:report.engineErrors,report:output}));
}
if(!report.success)process.exitCode=1;
