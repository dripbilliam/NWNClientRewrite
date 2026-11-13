// Protocol-only owned loopback test; no renderer/private settings writes.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire,registerHooks} from 'node:module';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {performance} from 'node:perf_hooks';
const require=createRequire(import.meta.url),option=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);
const directory=option('directory'),install=option('install'),pipe=option('private-login-pipe'),output=option('report');assert.ok(directory&&install&&pipe&&output);
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),loaded=new Map(),hash=bytes=>createHash('sha256').update(bytes).digest('hex');
registerHooks({resolve(specifier,context,next){const result=next(specifier,context);if(result.url.startsWith('file:')){const file=fileURLToPath(result.url);if(file.startsWith(workspace+path.sep)&&!loaded.has(file))loaded.set(file,hash(readFileSync(file)));}return result;}});
const report={success:false,checks:0,cases:[],states:[],diagnosticCodes:[],speech:[],receivedTokens:[],receivedAccess:[],wire:[],callbackMs:[],publicConnections:0,gameEndpoint:'127.0.0.1:5127',gpu:false,renderer:false,nativeBuilds:0,scope:'Production typed GUI26/14 Session and canonical current-area source targets -> unchanged original server module callback -> exact53/2 responses and XYZ/type/custom-token barriers. Native pointer input separate; no game window/pixels/public world.'};
const check=(value,label)=>{report.checks++;report.cases.push({label,passed:Boolean(value)});assert.ok(value,label);};
let session,key='',asyncError=null;const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function wait(label,predicate,timeout=20000){const until=Date.now()+timeout;while(Date.now()<until){if(asyncError)throw Error(asyncError);if(session?.closed)throw Error('Owned session closed during '+label);if(await predicate())return;await pause(30);}throw Error('Timed out: '+label);}
try{
 const fixture=JSON.parse(await fs.readFile(path.join(directory,'fixture.json'),'utf8'));assert.equal(fixture.module,'GuiContext');assert.equal(fixture.port,5127);
 const {readPrivateKey,connectPrivatePipe}=require('../tools/private-login.cjs');key=await readPrivateKey(connectPrivatePipe(pipe));
 const {createInstalledNetworkSession}=await import('../../electron/installed_network_session.mjs');
 const created=await createInstalledNetworkSession({install,userDirectory:path.join(directory,'client'),modsDirectory:null,host:'127.0.0.1',port:5127,name:'OwnedGuiContextTest',credentials:{cdKey:key,password:''},onDiagnostic:value=>{if(report.diagnosticCodes.length<64)report.diagnosticCodes.push(String(value.code??'unknown'));}});key='';session=created.session;let selecting=false;
 const {guiPanelEventForHost,guiPanelHeaderForHost}=await import('../../src/network_gui_panel_access.js');
 const {GUI_CONTEXT_SOURCES}=await import('../../src/network_gui_context_input.js');
 const {NativeMessageReader}=await import('../../src/native_message.js'),send=session.peer.sendGameMessage.bind(session.peer);
 session.peer.sendGameMessage=bytes=>{
  if(bytes[0]===112&&bytes[1]===28&&[10,11].includes(bytes[2])&&report.wire.length<32)report.wire.push({kind:'subscription',operation:bytes[2],bytes:bytes.length});
  if(bytes[0]===112&&bytes[1]===53&&bytes[2]===1){
   const reader=new NativeMessageReader(1),body=bytes.subarray(3);assert.equal(reader.setReadMessage(body,body.length,0xffffffff,1),1);
   const event=reader.readWord(),selection=reader.readWord(),targetId=reader.readObjectIdClient(),position=[reader.readFloat(),reader.readFloat(),reader.readFloat()];assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);
   if(report.wire.length<32)report.wire.push({kind:'gui',event,selection,targetId,position,bytes:bytes.length});
  }
  return send(bytes);
 };
 session.on('state',state=>{if(report.states.at(-1)!==state.phase&&report.states.length<32)report.states.push(state.phase);if(state.phase==='character-selection'&&!selecting){selecting=true;void fs.readFile(path.join(install,'data/lcv/bard.bic')).then(async bytes=>{try{report.characterSha256=hash(bytes);assert.equal(report.characterSha256,'e1e8e7e4437ae23d860e1423eef43e07792de3cfd65a0514dd5868e55dcdfd86');await session.selectCharacter(bytes);}finally{bytes.fill(0);}}).catch(()=>{asyncError='Unchanged installed Bard admission failed';});}});
 session.on('message',({message,areaGeneration})=>{
  if(message.kind==='client-area')void session.areaReady(areaGeneration).catch(()=>{asyncError='Authored protocol-only ready failed';});
  const text=message.kind==='server-speech'?message.text?.text:message.kind==='combat-feedback'&&message.type===204?message.data?.strings?.[0]?.text:null;
  if(typeof text==='string'&&text.startsWith('NATIVE_CONTEXT_')&&report.speech.length<128)report.speech.push(text.slice(0,256));
  if(['gui-panel-disabled','gui-panel-popup'].includes(message.kind)&&report.receivedAccess.length<64){const event=guiPanelEventForHost(session.world,message,areaGeneration);report.receivedAccess.push({kind:message.kind,major:message.major,minor:message.minor,event});}
  if(message.kind==='custom-token'&&message.id===9005&&/^Owned GUI context callback [1-9][0-9]*$/.test(message.text)&&report.receivedTokens.length<16)report.receivedTokens.push({kind:message.kind,id:message.id,text:message.text,major:message.major,minor:message.minor,areaGeneration,at:performance.now()});
 });
 let identity;await wait('owned server identity',async()=>{try{identity=(await fs.readFile(path.join(directory,'logs/nwengineLog.txt'),'utf8')).match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];return Boolean(identity);}catch{return false;}});
 await session.connect({host:'127.0.0.1',port:5127,expectedServerPublicKey:Buffer.from(identity,'base64'),metadata:created.metadata});
 await wait('owned player world',()=>{try{return session.controlledActor(session.world.areaId,session.areaGeneration).id===session.world.localObjectId;}catch{return false;}});
 check(session.phase==='playing'&&session.areaReadySent,'Original server admits the unchanged installed Bard through the protocol-only ready boundary');
 const scope=()=>({areaId:session.world.areaId,areaGeneration:session.areaGeneration,actorId:session.world.localObjectId});
 const actor=session.world.localObjectId,INVALID=0x7f000000,ground=[50.25,40.5,0.125],targets={};
 const visible=object=>object.areaId===session.world.areaId&&!object.replicationRemoved&&!object.destroyed;
 function selectTargets(){for(const [name,source]of Object.entries(GUI_CONTEXT_SOURCES)){if(name==='ground')targets[name]=INVALID;else if(name==='creature')targets[name]=actor;else{const object=[...session.world.registry.objects.values()].find(o=>o.objectType===source.objectType&&visible(o));if(object)targets[name]=object.id;}}return Object.keys(targets).length===6;}
 report.knownObjects=()=>{};
 try{await wait('six actual disclosed world context sources',()=>selectTargets());}finally{report.knownObjects=[...session.world.registry.objects.values()].slice(0,128).map(o=>({id:o.id,objectType:o.objectType,areaId:o.areaId??null,removed:Boolean(o.replicationRemoved)}));report.selectedTargets=targets;}
 check(Object.keys(targets).length===6,'Every tested source target comes from actual client-known typed current-area state');
 // Original observed GetObjectType(INVALID) is0, despite the SDK filter-mask
 // constant OBJECT_TYPE_INVALID32767. Identity remains explicitly INVALID.
 const scriptTypes={ground:0,trigger:4,creature:1,item:2,placeable:64,door:8};let count=0,serial=0;
 async function callback(sourceKind,type,selection,target,position,began){
  await wait('original context callback '+count,()=>report.speech.includes('NATIVE_CONTEXT_DONE:'+count)&&report.receivedTokens.some(m=>m.text==='Owned GUI context callback '+count));
  const rows=report.speech.slice((count-1)*9,count*9),token=report.receivedTokens.find(m=>m.text==='Owned GUI context callback '+count),serverTarget=target===INVALID?INVALID:target&0x7fffffff;
  check(rows.includes('NATIVE_CONTEXT_TYPE:'+type)&&rows.includes('NATIVE_CONTEXT_INT:'+selection),'Original module observes exact GUI type/selection for '+sourceKind+' #'+count);
  check(rows.some(v=>/^NATIVE_CONTEXT_TARGET:[0-9a-f]{1,8}$/i.test(v)&&Number.parseInt(v.split(':')[1],16)===serverTarget)&&rows.includes('NATIVE_CONTEXT_TARGET_TYPE:'+scriptTypes[sourceKind]),'Original callback resolves exact typed target for '+sourceKind+' #'+count);
  check(['X','Y','Z'].every((axis,i)=>rows.some(v=>v.startsWith('NATIVE_CONTEXT_POSITION_'+axis+':')&&Number(v.split(':')[1])===position[i])),'Original callback observes each exact XYZ component for '+sourceKind+' #'+count);
  check(token.major===50&&token.minor===1&&token.areaGeneration===session.areaGeneration,'Actual script token9005 barrier passes production decoder #'+count);
  report.callbackMs.push(token.at-began);
 }
 for(const [sourceKind,source]of Object.entries(GUI_CONTEXT_SOURCES)){
  const targetId=targets[sourceKind],position=sourceKind==='ground'?ground:[0,0,0];
  for(const blocked of [false,true]){
   count++;const before=report.receivedAccess.length,began=performance.now(),request={...scope(),panel:'context-attempt',open:true,sourceKind,guiPanelId:source.panelId,targetId,position,accessRevision:session.world.guiPanelAccess.sequence,attemptSerial:++serial};
   const result=await session.hudPanel(request);check(result.sent===true&&result.blocked===blocked&&result.serverAcknowledged===false,'Canonical Session chooses actual admitted/blocked event for '+sourceKind+' #'+count);
   await callback(sourceKind,blocked?14:26,blocked?source.panelId:source.selection,targetId,blocked?[0,0,0]:position,began);
   await wait('exact original disable/enable response #'+count,()=>report.receivedAccess.length===before+1);
   const event=report.receivedAccess[before];check(event.major===53&&event.minor===2&&event.event.panelId===source.panelId&&event.event.targetId===targetId&&event.event.disabled===!blocked&&event.event.targetSource==='received','Original script returns exact53/2 membership for '+sourceKind+' #'+count);
   check(session.world.guiPanelAccess.matches(source.panelId,targetId)===!blocked,'Canonical received membership follows actual script result #'+count);
   await assert.rejects(session.hudPanel(request));
  }
 }
 check(report.wire.filter(v=>v.event===26).length===6&&report.wire.filter(v=>v.event===14).length===6&&report.receivedTokens.length===12&&report.speech.length===108,'Twelve original callback/token counters prove no replay or hidden request');
 const seed=guiPanelHeaderForHost(session.world,session.areaGeneration);check(seed.disabled.length===0&&seed.events.length===12&&seed.events.every((v,i)=>v.sequence===i+1),'All exact memberships clear with twelve detached ordered receive effects');
 check(report.wire.filter(v=>v.event===26&&v.selection!==1||v.event===14).every(v=>v.position.every(n=>Object.is(n,0))),'Only admitted ground context carries nonzero XYZ on actual wire');
 const sorted=[...report.callbackMs].sort((a,b)=>a-b);report.callbackTimingMs={count:sorted.length,p50:sorted[Math.floor(sorted.length*.5)],max:sorted.at(-1)};for(const token of report.receivedTokens)delete token.at;
 for(const[file,digest]of loaded)assert.equal(hash(await fs.readFile(file)),digest,'Loaded protocol source changed');report.sources=[...loaded].map(([file,sha256])=>({path:path.relative(workspace,file).replaceAll('\\','/'),sha256}));report.success=true;
}catch(error){report.failure=key&&String(error.message).includes(key)?'Private local session input failed':String(error.message).slice(0,240);}
finally{key='';await session?.disconnect().catch(()=>{});report.sessionClosed=!session||session.closed;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,checks:report.checks,failure:report.failure??null,report:output,sessionClosed:report.sessionClosed}));process.exit(report.success?0:1);}
