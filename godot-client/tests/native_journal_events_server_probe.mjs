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
const report={success:false,checks:0,cases:[],states:[],diagnosticCodes:[],speech:[],receivedTokens:[],wire:[],callbackMs:[],publicConnections:0,gameEndpoint:'127.0.0.1:5127',gpu:false,renderer:false,nativeBuilds:0,scope:'Production native-lifetime journal session transport -> unchanged original nwserver GUI10/11 handler -> authored module callback metadata/custom tokens. Protocol-only area-ready fixture; no game-window, pixel, disabled-panel access or public-world claim.'};
const check=(value,label)=>{report.checks++;report.cases.push({label,passed:Boolean(value)});assert.ok(value,label);};
let session,key='',asyncError=null;const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function wait(label,predicate,timeout=20000){const until=Date.now()+timeout;while(Date.now()<until){if(asyncError)throw Error(asyncError);if(session?.closed)throw Error('Owned session closed during '+label);if(await predicate())return;await pause(30);}throw Error('Timed out: '+label);}
try{
 const fixture=JSON.parse(await fs.readFile(path.join(directory,'fixture.json'),'utf8'));assert.equal(fixture.module,'JournalGui');assert.equal(fixture.port,5127);
 const {readPrivateKey,connectPrivatePipe}=require('../tools/private-login.cjs');key=await readPrivateKey(connectPrivatePipe(pipe));
 const {createInstalledNetworkSession}=await import('../../electron/installed_network_session.mjs');
 const created=await createInstalledNetworkSession({install,userDirectory:path.join(directory,'client'),modsDirectory:null,host:'127.0.0.1',port:5127,name:'OwnedJournalGuiTest',credentials:{cdKey:key,password:''},onDiagnostic:value=>{if(report.diagnosticCodes.length<64)report.diagnosticCodes.push(String(value.code??'unknown'));}});key='';session=created.session;let selecting=false;
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
  if(typeof text==='string'&&text.startsWith('NATIVE_JOURNAL_')&&report.speech.length<64)report.speech.push(text.slice(0,256));
  if(message.kind==='custom-token'&&message.id===9003&&/^Owned journal GUI callback [1-9][0-9]*$/.test(message.text)&&report.receivedTokens.length<8)report.receivedTokens.push({kind:message.kind,id:message.id,text:message.text,major:message.major,minor:message.minor,areaGeneration,at:performance.now()});
 });
 let identity;await wait('owned server identity',async()=>{try{identity=(await fs.readFile(path.join(directory,'logs/nwengineLog.txt'),'utf8')).match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];return Boolean(identity);}catch{return false;}});
 await session.connect({host:'127.0.0.1',port:5127,expectedServerPublicKey:Buffer.from(identity,'base64'),metadata:created.metadata});
 await wait('owned player world',()=>{try{return session.controlledActor(session.world.areaId,session.areaGeneration).id===session.world.localObjectId;}catch{return false;}});
 check(session.phase==='playing'&&session.areaReadySent,'Original server admits the unchanged installed Bard through the protocol-only ready boundary');
 const scope=()=>({areaId:session.world.areaId,areaGeneration:session.areaGeneration,actorId:session.world.localObjectId,panel:'journal'});
 let count=0;
 for(const journalLifetime of [1,2,3])for(const open of [true,false]){
  count++;const before=report.wire.length,began=performance.now();await session.hudPanel({...scope(),open,journalLifetime});
  await wait('original journal callback '+count,()=>report.speech.includes('NATIVE_JOURNAL_DONE:'+count)&&report.receivedTokens.some(m=>m.text==='Owned journal GUI callback '+count));
  const events=report.speech.slice((count-1)*7,count*7),token=report.receivedTokens.find(m=>m.text==='Owned journal GUI callback '+count);
  report.callbackMs.push(token.at-began);
  check(events.includes('NATIVE_JOURNAL_TYPE:'+(open?10:11))&&events.includes('NATIVE_JOURNAL_INT:0'),'Original module observes the exact journal event/zero WORD for callback '+count);
  check(events.includes('NATIVE_JOURNAL_TARGET_INVALID:1')&&events.includes('NATIVE_JOURNAL_TARGET:7f000000'),'Original module resolves the journal target as OBJECT_INVALID for callback '+count);
  check(events.some(value=>value.startsWith('NATIVE_JOURNAL_POSITION_MAGNITUDE:')&&Number(value.split(':')[1])===0),'Original module observes zero position for callback '+count);
  check(token.major===50&&token.minor===1&&token.areaGeneration===session.areaGeneration,'Actual module custom-token response passes the production receive decoder for callback '+count);
  const batch=report.wire.slice(before);check(batch.length===2&&batch[open?0:1].kind==='subscription'&&batch[open?0:1].operation===(open?10:11)&&batch[open?1:0].event===(open?10:11),'Production wire preserves original subscription/callback order '+count);
  const duplicate=await session.hudPanel({...scope(),open,journalLifetime});check(duplicate.sent===false&&duplicate.duplicate===true&&report.wire.length===before+2,'Duplicate boundary emits no replay packet '+count);
  if(!open){await assert.rejects(session.hudPanel({...scope(),open:true,journalLifetime}));await assert.rejects(session.hudPanel({...scope(),open:true,journalLifetime:0}));}
 }
 check(report.speech.length===42&&report.receivedTokens.length===6&&report.wire.length===12,'Subsequent server callback counters prove duplicates/stale requests did not create hidden callbacks');
 check(report.wire.filter(row=>row.kind==='gui').every(row=>row.selection===0&&row.targetId===0x7f000000&&row.position.every(value=>Object.is(value,0))),'All actual GUI packets retain invalid object/zero selection/zero XYZ');
 check(session.world.journal.loaded===true,'The original journal subscription still publishes through the existing canonical journal owner');
 const sorted=[...report.callbackMs].sort((a,b)=>a-b);report.callbackTimingMs={count:sorted.length,p50:sorted[Math.floor(sorted.length*.5)],max:sorted.at(-1)};for(const token of report.receivedTokens)delete token.at;
 for(const[file,digest]of loaded)assert.equal(hash(await fs.readFile(file)),digest,'Loaded protocol source changed');report.sources=[...loaded].map(([file,sha256])=>({path:path.relative(workspace,file).replaceAll('\\','/'),sha256}));report.success=true;
}catch(error){report.failure=key&&String(error.message).includes(key)?'Private local session input failed':String(error.message).slice(0,240);}
finally{key='';await session?.disconnect().catch(()=>{});report.sessionClosed=!session||session.closed;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,checks:report.checks,failure:report.failure??null,report:output,sessionClosed:report.sessionClosed}));process.exit(report.success?0:1);}
