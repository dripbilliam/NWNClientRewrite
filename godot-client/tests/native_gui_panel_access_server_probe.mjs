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
const report={success:false,checks:0,cases:[],states:[],diagnosticCodes:[],speech:[],receivedTokens:[],receivedAccess:[],wire:[],callbackMs:[],publicConnections:0,gameEndpoint:'127.0.0.1:5127',gpu:false,renderer:false,nativeBuilds:0,scope:'Production access decoder/World/host binding and typed GUI14 session writer -> unchanged original nwserver -> authored module SetGuiPanelDisabled/PopUpGUIPanel and custom-token outcomes. Separate native input acceptance; no game window/pixels/public world.'};
const check=(value,label)=>{report.checks++;report.cases.push({label,passed:Boolean(value)});assert.ok(value,label);};
let session,key='',asyncError=null;const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function wait(label,predicate,timeout=20000){const until=Date.now()+timeout;while(Date.now()<until){if(asyncError)throw Error(asyncError);if(session?.closed)throw Error('Owned session closed during '+label);if(await predicate())return;await pause(30);}throw Error('Timed out: '+label);}
try{
 const fixture=JSON.parse(await fs.readFile(path.join(directory,'fixture.json'),'utf8'));assert.equal(fixture.module,'GuiAccess');assert.equal(fixture.port,5127);
 const {readPrivateKey,connectPrivatePipe}=require('../tools/private-login.cjs');key=await readPrivateKey(connectPrivatePipe(pipe));
 const {createInstalledNetworkSession}=await import('../../electron/installed_network_session.mjs');
 const created=await createInstalledNetworkSession({install,userDirectory:path.join(directory,'client'),modsDirectory:null,host:'127.0.0.1',port:5127,name:'OwnedGuiAccessTest',credentials:{cdKey:key,password:''},onDiagnostic:value=>{if(report.diagnosticCodes.length<64)report.diagnosticCodes.push(String(value.code??'unknown'));}});key='';session=created.session;let selecting=false;
 const {guiPanelEventForHost,guiPanelHeaderForHost}=await import('../../src/network_gui_panel_access.js');
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
  if(typeof text==='string'&&text.startsWith('NATIVE_ACCESS_')&&report.speech.length<64)report.speech.push(text.slice(0,256));
  if(['gui-panel-disabled','gui-panel-popup'].includes(message.kind)&&report.receivedAccess.length<64){const event=guiPanelEventForHost(session.world,message,areaGeneration);report.receivedAccess.push({kind:message.kind,major:message.major,minor:message.minor,event});}
  if(message.kind==='custom-token'&&message.id===9004&&/^Owned GUI access callback [1-9][0-9]*$/.test(message.text)&&report.receivedTokens.length<8)report.receivedTokens.push({kind:message.kind,id:message.id,text:message.text,major:message.major,minor:message.minor,areaGeneration,at:performance.now()});
 });
 let identity;await wait('owned server identity',async()=>{try{identity=(await fs.readFile(path.join(directory,'logs/nwengineLog.txt'),'utf8')).match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];return Boolean(identity);}catch{return false;}});
 await session.connect({host:'127.0.0.1',port:5127,expectedServerPublicKey:Buffer.from(identity,'base64'),metadata:created.metadata});
 await wait('owned player world',()=>{try{return session.controlledActor(session.world.areaId,session.areaGeneration).id===session.world.localObjectId;}catch{return false;}});
 check(session.phase==='playing'&&session.areaReadySent,'Original server admits the unchanged installed Bard through the protocol-only ready boundary');
 const scope=()=>({areaId:session.world.areaId,areaGeneration:session.areaGeneration,actorId:session.world.localObjectId});
 const actor=session.world.localObjectId,INVALID=0x7f000000;
 const bootstrap=performance.now(),start=report.receivedAccess.length;
 await session.hudPanel({...scope(),panel:'journal',open:true,journalLifetime:1});
 let serial=0;
 async function callback(count,type,panel,targetSelf,began){
  await wait('original access callback '+count,()=>report.speech.includes('NATIVE_ACCESS_DONE:'+count)&&report.receivedTokens.some(m=>m.text==='Owned GUI access callback '+count));
  const rows=report.speech.slice((count-1)*8,count*8),token=report.receivedTokens.find(m=>m.text==='Owned GUI access callback '+count);
  check(rows.includes('NATIVE_ACCESS_TYPE:'+type)&&rows.includes('NATIVE_ACCESS_INT:'+panel),'Original module observes exact GUI type and WORD for callback '+count);
  check(rows.includes('NATIVE_ACCESS_TARGET_'+(targetSelf?'SELF':'INVALID')+':1'),'Original module resolves exact displayed/INVALID target for callback '+count);
  check(rows.some(v=>v.startsWith('NATIVE_ACCESS_POSITION_MAGNITUDE:')&&Number(v.split(':')[1])===0),'Original module receives zero XYZ for callback '+count);
  check(token.major===50&&token.minor===1&&token.areaGeneration===session.areaGeneration,'Actual module custom-token outcome passes production receive '+count);
  report.callbackMs.push(token.at-began);
 }
 await callback(1,10,0,false,bootstrap);
 await wait('initial original disable/popup commands',()=>report.receivedAccess.length>=start+5);
 const initial=report.receivedAccess.slice(start);
 check(initial.slice(0,4).every((row,i)=>row.kind==='gui-panel-disabled'&&row.major===53&&row.minor===2&&row.event.panelId===i+5&&row.event.disabled&&row.event.targetId===INVALID&&row.event.targetSource==='received'),'Actual SetGuiPanelDisabled sends four versioned53/2 global memberships');
 check(initial[4].kind==='gui-panel-popup'&&initial[4].major===36&&initial[4].minor===4&&initial[4].event.panelId===6&&initial[4].event.scope.actorId===actor,'Actual PopUpGUIPanel sends distinct36/4 scoped command');
 check([5,6,7,8].every(id=>session.world.guiPanelAccess.matches(id,id===8?actor:INVALID)),'Received policy keeps all four disables despite forced popup');
 async function attempt(panel,count){
  const before=report.receivedAccess.length,began=performance.now(),targetId=panel===8?actor:INVALID;
  const request={...scope(),panel:'blocked-attempt',open:true,guiPanelId:panel,targetId,accessRevision:session.world.guiPanelAccess.sequence,attemptSerial:++serial};
  const result=await session.hudPanel(request);check(result.sent===true,'Production current-scope blocked attempt submits once '+count);
  await callback(count,14,panel,panel===8,began);
  await assert.rejects(session.hudPanel(request));
  return report.receivedAccess.slice(before);
 }
 const twice=await attempt(6,2);
 check(twice.length===4&&twice[0].event.kind==='popup'&&twice[1].event.kind==='popup'&&twice[2].event.kind==='disabled'&&twice[2].event.disabled&&twice[3].event.targetId===actor&&!twice[3].event.disabled,'Original callback publishes duplicate popup then disable then exact-target enable in order');
 check(session.world.guiPanelAccess.matches(6,INVALID),'Removing exact actor membership cannot erase a global Journal disable');
 const opened=await attempt(6,3);
 check(opened.length===4&&!opened[0].event.disabled&&opened[0].event.targetId===INVALID&&opened.slice(1).map(v=>v.event.panelId).join(',')==='5,7,8','Original callback globally enables Journal and forces Players/Book/Sheet as distinct commands');
 check(!session.world.guiPanelAccess.matches(6,INVALID),'Actual global enable removes only Journal membership');
 const player=await attempt(5,4);check(player.length===2&&!player[0].event.disabled&&player[1].event.panelId===5,'Original Players callback enables and forces the same logical owner');
 const book=await attempt(7,5);check(book.length===2&&!book[0].event.disabled&&book[1].event.panelId===7,'Original Book callback enables and forces the same logical owner');
 const character=await attempt(8,6);check(character.length===3&&character[0].event.targetId===actor&&character[0].event.disabled&&character[1].event.targetId===INVALID&&!character[1].event.disabled&&character[2].event.panelId===8,'Original Sheet callback adds exact target, erases global and forces without clearing exact membership');
 check(session.world.guiPanelAccess.matches(8,actor)&&!session.world.guiPanelAccess.matches(8,(actor+1)>>>0),'Exact displayed-character membership remains after global enable');
 const cleared=await attempt(8,7);check(cleared.length===1&&cleared[0].event.targetId===actor&&!cleared[0].event.disabled&&!session.world.guiPanelAccess.matches(8,actor),'Final original callback removes only exact displayed-character membership');
 check(report.wire.filter(v=>v.event===14).length===6&&report.receivedTokens.length===7&&report.speech.length===56,'Server counters prove replayed/stale requests create no hidden callback');
 check(report.wire.filter(v=>v.event===14).every(v=>v.targetId===(v.selection===8?actor:INVALID)&&v.position.every(n=>Object.is(n,0))),'All actual GUI14 wire packets have exact ordinary target and zero XYZ');
 const seed=guiPanelHeaderForHost(session.world,session.areaGeneration);check(seed.disabled.length===0&&seed.events.length===21&&seed.events.every((v,i)=>v.sequence===i+1),'Compact canonical header preserves all21 ordered server effects without invented enabled flags');
 const detached=structuredClone(seed);detached.events.length=0;check(guiPanelHeaderForHost(session.world,session.areaGeneration).events.length===21,'Header callers cannot mutate canonical received command history');
 const sorted=[...report.callbackMs].sort((a,b)=>a-b);report.callbackTimingMs={count:sorted.length,p50:sorted[Math.floor(sorted.length*.5)],max:sorted.at(-1)};for(const token of report.receivedTokens)delete token.at;
 await session.hudPanel({...scope(),panel:'journal',open:false,journalLifetime:1});
 for(const[file,digest]of loaded)assert.equal(hash(await fs.readFile(file)),digest,'Loaded protocol source changed');report.sources=[...loaded].map(([file,sha256])=>({path:path.relative(workspace,file).replaceAll('\\','/'),sha256}));report.success=true;
}catch(error){report.failure=key&&String(error.message).includes(key)?'Private local session input failed':String(error.message).slice(0,240);}
finally{key='';await session?.disconnect().catch(()=>{});report.sessionClosed=!session||session.closed;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,checks:report.checks,failure:report.failure??null,report:output,sessionClosed:report.sessionClosed}));process.exit(report.success?0:1);}
