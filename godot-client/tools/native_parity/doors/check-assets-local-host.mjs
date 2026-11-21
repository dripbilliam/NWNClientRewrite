// Loopback-only authoritative interaction fixture. Protocol JavaScript owns
// no rendering, model calculation or optimistic door state.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import net from 'node:net';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {createInstalledNetworkSession} from '../../../../electron/installed_network_session.mjs';
import {submitNativeDialogReply} from '../../native-dialog-input.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),project=path.resolve(here,'../../..'),root=path.dirname(project);
const label=process.argv[2];if(!/^check-assets-local-[a-z0-9-]+$/.test(label??''))throw Error('Fresh local label required');
const directory=path.join(project,'.cache/native-presentation-parity/loading-agent',label),stage=JSON.parse(await fs.readFile(path.join(directory,'stage.json')));
const output=path.join(directory,'local-run.json'),nativeReport=path.join(directory,'native-result.json');
try{await fs.access(output);throw Error('Existing receipt preserved');}catch(error){if(error.code!=='ENOENT')throw error;}
if(stage.test!=='tests/native_parity_door_server_test.gd')throw Error('Not an explicit local receiver stage');
const hash=raw=>crypto.createHash('sha256').update(raw).digest('hex');
for(const pin of stage.pins)if(hash(await fs.readFile(path.join(stage.project,pin.relative)))!==pin.sha256)throw Error('Staged source differs');
if(hash(await fs.readFile(stage.engine.file))!==stage.engine.sha256)throw Error('Actual engine differs');
const chunks=[];let count=0;
for await(const chunk of process.stdin){count+=chunk.length;if(count>8192)throw Error('Private credential input exceeds bound');chunks.push(chunk);}
let credentials;try{credentials=JSON.parse(Buffer.concat(chunks).toString('utf8'));}finally{for(const chunk of chunks)chunk.fill(0);}
if(typeof credentials.cdKey!=='string'||credentials.cdKey.length!==41)throw Error('Private local credential unavailable');
const token=crypto.randomBytes(32).toString('hex'),ticket=path.join(directory,'local-ticket.json');
const report={success:false,started:new Date().toISOString(),endpoint:'127.0.0.1:5121',module:'Prelude',publicConnections:0,nativeBuilds:0,actions:[],serverStates:[],nativeStates:[],phases:[],diagnostics:[],scope:'Original loopback server interaction requests -> canonical replication -> actual native DoorInstance clips; no GUI/FPS/general gameplay acceptance'};
let session,child,server,socket,authenticated=false,selected,scope,version=0,last='',actionPhase='initial',closing=false,reading=false,phaseArea=-1,playingSince=0,talkTarget=null,talkStarted=0,lastAction=0;
const talked=new Set();
let resolveDone;const done=new Promise(resolve=>resolveDone=resolve);let socketChain=Promise.resolve();
const send=value=>{if(socket&&!socket.destroyed)socket.write(JSON.stringify(value)+'\n');};
async function end(reason){if(closing)return;closing=true;if(reason)report.failure=reason;send({kind:'finish'});await session?.disconnect().catch(()=>{});resolveDone();}
function doorState(object){const state=object?.replicated;if(!state)return null;const value=state.doorOpenState;if(Number.isInteger(value)&&value>=0&&value<=3)return value;return({22:0,50:1,51:2,72:3})[state.animation]??null;}
function publish(){
 const object=session?.world.registry.get(selected?.id);if(!object)return;
 if(object.areaId!==scope.areaId||session.areaGeneration!==scope.areaGeneration||object.replicationRemoved){void end('Selected door scope retired');return;}
 const replicated=Object.fromEntries(['position','orientation','doorType','genericType','doorOpenState','animation','destroyedModel','hasTransition'].filter(key=>object.replicated[key]!==undefined).map(key=>[key,structuredClone(object.replicated[key])]));
 const value={id:object.id,objectType:10,areaId:object.areaId,replicated},signature=JSON.stringify(value);if(signature===last)return;last=signature;
 report.serverStates.push({version:++version,state:doorState(object),animation:replicated.animation??null,at:Date.now()});send({kind:'door',version,object:value});
}
async function action(name){
 if(!selected||session.phase!=='playing')throw Error('Door action scope not playing');
 const result=await session.interact({...scope,targetId:selected.id,action:name});
 lastAction=Date.now();
 report.actions.push({action:name,targetId:selected.id,sent:result?.sent===true,at:Date.now()});
 if(result?.sent!==true)throw Error('Original interaction sender did not send');
}
async function command(message){
 if(!authenticated){if(message.kind!=='hello'||message.token!==token)throw Error('Private native handshake failed');authenticated=true;return;}
 if(message.kind==='failed')throw Error('Native receiver failed: '+String(message.reason));
 if(message.kind==='finished'){report.nativeFinished=true;return;}
 if(message.kind==='reply'){
  const currentScope={areaId:session.world.areaId,areaGeneration:session.areaGeneration};
  const result=await submitNativeDialogReply(session,{...currentScope,entryId:message.entryId,replyId:message.replyId,abort:message.abort},value=>send({kind:'ui',message:value}));
  report.replies??=[];report.replies.push({entryId:message.entryId,replyId:message.replyId,abort:message.abort,sent:result.sent===true});return;
 }
 if(message.kind==='conversation-done'){
  if(message.targetId!==talkTarget)throw Error('Tutorial conversation owner changed');
  talked.add(talkTarget);talkTarget=null;talkStarted=0;report.conversations=[...talked];return;
 }
 if(message.kind!=='door-rest')return;
 if(!selected||message.id!==selected.id||message.version!==version||message.state!==doorState(session.world.registry.get(selected.id)))throw Error('Native rest acknowledgement scope/state differs');
 report.nativeStates.push(message);
 if(actionPhase==='initial'){
  if(message.state!==0){actionPhase='prepare-close';await action('door.close');}
  else{actionPhase='open';await action('door.open');}
 }else if(actionPhase==='prepare-close'){
  if(message.state!==0)throw Error('Authoritative precondition close failed');actionPhase='open';await action('door.open');
 }else if(actionPhase==='open'){
  if(message.state!==1&&message.state!==2)throw Error('Server did not open selected door');actionPhase='close';await action('door.close');
 }else if(actionPhase==='close'){
  if(message.state!==0)throw Error('Server did not close selected door');report.completed=true;await end();
 }
}
const stdout=[],stderr=[];let interval,timeout,childExit;
try{
 const log=await fs.readFile(path.join(root,'runtime-logs/local-multiplayer-server/logs/nwengineLog.txt'),'utf8');
 const pin=log.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];
 if(!pin||!log.includes('Loading Module: Prelude'))throw Error('Existing Prelude identity/module not proven');
 server=net.createServer(client=>{
  if(socket){client.destroy();return;}socket=client;let pending='';
  client.on('data',bytes=>{pending+=bytes.toString('utf8');if(Buffer.byteLength(pending)>1048576){void end('Native frame exceeds bound');return;}let at;while((at=pending.indexOf('\n'))>=0){const line=pending.slice(0,at);pending=pending.slice(at+1);socketChain=socketChain.then(()=>command(JSON.parse(line))).catch(error=>end(error.message));}});
  client.on('error',()=>{void end('Native loopback socket failed');});
 });
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
 await fs.writeFile(ticket,JSON.stringify({host:'127.0.0.1',port:server.address().port,token}),{flag:'wx'});
 const userdata=path.join(directory,'userdata-local');await fs.mkdir(userdata,{recursive:true});
 const args=['--headless','--max-fps','60','--path',stage.project,'--script','res://'+stage.test,'--','--ticket='+ticket,'--report='+nativeReport,'--install='+stage.install.directory,'--cache='+path.join(directory,'prepared-local'),'--prepared-cache-write=sync','--particle-kernel=gd','--particles=false'];
 child=spawn(stage.engine.file,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,APPDATA:userdata,LOCALAPPDATA:userdata,NWN_PARTICLE_KERNEL:'gd'}});
 report.childPid=child.pid;report.engine=stage.engine;report.nativeArgs=args;
 child.stdout.on('data',bytes=>stdout.push(bytes));child.stderr.on('data',bytes=>stderr.push(bytes));
 childExit=new Promise(resolve=>{child.once('error',error=>{void end('Native child failed: '+error.message);resolve(null);});child.once('exit',code=>{if(!closing)void end('Native child exited before completed authority proof');resolve(code);});});
 const created=await createInstalledNetworkSession({install:stage.install.directory,userDirectory:path.join(directory,'protocol-user'),cacheDirectory:path.join(directory,'protocol-cache'),host:'127.0.0.1',port:5121,name:'NativeDoorParity',credentials,onDiagnostic:value=>{if(report.diagnostics.length<128)report.diagnostics.push({code:value.code??'unknown'});}});session=created.session;credentials=null;
 if(closing)throw Error('Native receiver retired before protocol connection');
 session.portalTransfer.prepare=()=>{throw Error('All server transfers forbidden in local door proof');};
 session.on('state',state=>{if(report.phases.at(-1)!==state.phase)report.phases.push(state.phase);});
 session.on('message',({message})=>{
  if(closing)return;
  if(['dialog-entry','dialog-replies','dialog-selected','dialog-close','server-speech','combat-feedback'].includes(message.kind)){
   report.feedback??=[];if(report.feedback.length<96)report.feedback.push(structuredClone(message));
   if(message.kind==='dialog-entry'&&talkTarget===null&&!selected){talkTarget=message.ownerId;talkStarted=Date.now();send({kind:'talk-target',targetId:talkTarget});}
   send({kind:'ui',message});
  }
  if(selected)publish();
 });
 const character=await fs.readFile(path.join(stage.install.directory,'data/lcv/wizard.bic'));
 try{report.characterSha256=hash(character);await session.selectCharacter(character);}finally{character.fill(0);}
 await session.connect({host:'127.0.0.1',port:5121,timeout:45000,expectedServerPublicKey:Buffer.from(pin,'base64'),metadata:created.metadata});
 interval=setInterval(async()=>{
  if(closing||reading||!authenticated||session.closed)return;reading=true;
  try{
   const area=session.world.registry.get(session.world.areaId)?.state;
   if(session.resourceResult?.ready&&area?.tiles&&phaseArea!==session.areaGeneration){phaseArea=session.areaGeneration;await session.areaReady(phaseArea);}
   if(session.phase!=='playing')return;
   playingSince||=Date.now();
   scope??={areaId:session.world.areaId,areaGeneration:session.areaGeneration};
   if(scope.areaId!==session.world.areaId||scope.areaGeneration!==session.areaGeneration)throw Error('Prelude scope changed without transition request');
   if(lastAction&&Date.now()-lastAction>20000)throw Error('Original server did not acknowledge '+report.actions.at(-1)?.action+' within20s');
   if(!selected){
    const actor=session.world.registry.get(session.world.localObjectId),point=actor?.replicated?.position;
    if(!point){if(Date.now()-playingSince>5000)throw Error('Controlled actor has no received position');return;}
    if(talkTarget!==null){if(Date.now()-talkStarted>20000)throw Error('Original tutorial conversation did not complete within20s');return;}
    if(talked.size<2){
     const npcs=[...session.world.registry.objects.values()].filter(object=>object.objectType===5&&object.id!==session.world.localObjectId&&object.areaId===session.world.areaId&&!object.replicationRemoved&&Array.isArray(object.replicated?.position)&&!talked.has(object.id));
     npcs.sort((a,b)=>Math.hypot(...a.replicated.position.map((value,index)=>value-point[index]))-Math.hypot(...b.replicated.position.map((value,index)=>value-point[index])));
     if(!npcs.length){if(Date.now()-playingSince>5000)throw Error('Original Prelude tutorial NPC unavailable');return;}
     talkTarget=npcs[0].id;talkStarted=Date.now();send({kind:'talk-target',targetId:talkTarget});
     const result=await session.interact({...scope,targetId:talkTarget,action:'conversation.start'});
     report.talkRequests??=[];report.talkRequests.push({targetId:talkTarget,sent:result.sent===true});return;
    }
    const known=[...session.world.registry.objects.values()].filter(object=>object.objectType===10&&object.areaId===session.world.areaId&&!object.replicationRemoved);
    report.doorCensus=known.slice(0,32).map(object=>({id:object.id,position:object.replicated?.position??null,state:doorState(object),animation:object.replicated?.animation??null,hasTransition:object.replicated?.hasTransition??null,fields:Object.keys(object.replicated??{})}));
    const doors=known.filter(object=>Array.isArray(object.replicated?.position)&&doorState(object)!==null&&doorState(object)!==3);
    doors.sort((a,b)=>(a.replicated.hasTransition===false?0:1)-(b.replicated.hasTransition===false?0:1)||(doorState(a)===0?0:1)-(doorState(b)===0?0:1)||Math.hypot(...a.replicated.position.map((value,index)=>value-point[index]))-Math.hypot(...b.replicated.position.map((value,index)=>value-point[index])));
    if(!doors.length){if(Date.now()-playingSince>5000)await end('No current-area door has received position and supported state');return;}
    // OPEN/CLOSE packets21/22 never request door.transition or a waypoint.
    // Prefer a non-transition target; a linked campaign door is still a real
    // open/close owner, with any actual scope change rejected above.
    selected=doors[0];scope={areaId:session.world.areaId,areaGeneration:session.areaGeneration};report.selected={id:selected.id,state:doorState(selected),position:selected.replicated.position,hasTransition:selected.replicated.hasTransition??null,appearance:{doorType:selected.replicated.doorType,genericType:selected.replicated.genericType},scope};
   }
   publish();
  }catch(error){await end(error.message);}finally{reading=false;}
 },50);
 timeout=setTimeout(()=>{void end('Local authoritative door deadline exceeded');},90000);
 await done;
 report.nativeExit=await Promise.race([childExit,new Promise(resolve=>setTimeout(()=>resolve('preserved-after-timeout'),10000))]);
 if(report.nativeExit==='preserved-after-timeout')report.preservedChildPid=child.pid;
 let native;try{native=JSON.parse(await fs.readFile(nativeReport));}catch{}
 report.native=native;
 const problems=Buffer.concat([...stdout,...stderr]).toString('utf8').split(/\r?\n/).filter(line=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances leaked|resources still in use|Invalid call/.test(line));
 report.problems=problems;report.sourceChanged=[];
 for(const pin of stage.pins)if(hash(await fs.readFile(path.join(stage.project,pin.relative)))!==pin.sha256)report.sourceChanged.push(pin.relative);
 report.success=!report.failure&&report.completed===true&&native?.success===true&&report.nativeExit===0&&report.nativeStates.length>=3&&report.actions.some(row=>row.action==='door.open'&&row.sent)&&report.actions.some(row=>row.action==='door.close'&&row.sent)&&!problems.length&&!report.sourceChanged.length;
}catch(error){await end(error.message);report.failure??=error.message;}
finally{
 clearInterval(interval);clearTimeout(timeout);await session?.disconnect().catch(()=>{});socket?.destroy();server?.close();
 if(credentials)for(const key of Object.keys(credentials))credentials[key]='';
 if(child&&child.exitCode===null){report.preservedChildPid=child.pid;child.stdout.destroy();child.stderr.destroy();child.unref();}
 await fs.writeFile(path.join(directory,'local-stdout.log'),Buffer.concat(stdout),{flag:'wx'});await fs.writeFile(path.join(directory,'local-stderr.log'),Buffer.concat(stderr),{flag:'wx'});
 await fs.unlink(ticket).catch(error=>{if(error.code!=='ENOENT')throw error;});
 report.finished=new Date().toISOString();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({success:report.success,failure:report.failure,actions:report.actions,serverStates:report.serverStates,nativeStates:report.nativeStates,nativeExit:report.nativeExit,preservedChildPid:report.preservedChildPid,receipt:output}));
}
if(!report.success)process.exitCode=1;
