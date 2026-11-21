// Protocol-only local original-server test. No renderer, browser or private settings writes.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire,registerHooks} from 'node:module';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
const require=createRequire(import.meta.url);
const option=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);
const directory=option('directory'),install=option('install'),pipe=option('private-login-pipe'),output=option('report');
assert.ok(directory&&install&&pipe&&output,'Explicit owned fixture arguments required');
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const loaded=new Map(),hash=bytes=>createHash('sha256').update(bytes).digest('hex');
registerHooks({resolve(specifier,context,next){const result=next(specifier,context);if(result.url.startsWith('file:')){const file=fileURLToPath(result.url);if(file.startsWith(workspace+path.sep)&&!loaded.has(file))loaded.set(file,hash(readFileSync(file)));}return result;}});
const report={success:false,checks:0,cases:[],states:[],diagnosticCodes:[],speech:[],received_tokens:[],guiWire:[],publicConnections:0,gameEndpoint:'127.0.0.1:5127',gpu:false,renderer:false,nativeBuilds:0,scope:'Production NetworkGameSession.hudPanel -> actual unchanged original nwserver GUI3 handler -> authored module event metadata and SetCustomToken messages. Protocol-only area-ready fixture; no renderer readiness, Arelith disguise logic, pixel comparison or public-world acceptance.'};
const check=(value,label)=>{report.checks++;report.cases.push({label,passed:Boolean(value)});assert.ok(value,label);};
let session,key='',asyncError=null;
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function wait(label,predicate,timeout=20000){const until=Date.now()+timeout;while(Date.now()<until){if(asyncError)throw Error(asyncError);if(session?.closed)throw Error('Owned session closed during '+label);if(await predicate())return;await pause(30);}throw Error('Timed out: '+label);}
try{
 const fixture=JSON.parse(await fs.readFile(path.join(directory,'fixture.json'),'utf8'));
 assert.equal(fixture.module,'SkillGui3');assert.equal(fixture.port,5127);
 const {readPrivateKey,connectPrivatePipe}=require('../tools/private-login.cjs');key=await readPrivateKey(connectPrivatePipe(pipe));
 const {createInstalledNetworkSession}=await import('../../electron/installed_network_session.mjs');
 const created=await createInstalledNetworkSession({install,userDirectory:path.join(directory,'client'),modsDirectory:null,host:'127.0.0.1',port:5127,name:'OwnedSkillGuiTest',credentials:{cdKey:key,password:''},onDiagnostic:value=>{if(report.diagnosticCodes.length<64)report.diagnosticCodes.push(String(value.code??'unknown'));}});
 key='';session=created.session;let selecting=false;
 const {NativeMessageReader}=await import('../../src/native_message.js');
 const sendGameMessage=session.peer.sendGameMessage.bind(session.peer);
 session.peer.sendGameMessage=bytes=>{
  // A transparent observer of only GUI packets; forward the same bytes through
  // the real transport. Login, crypto and other payloads are never captured.
  if(bytes[0]===112&&bytes[1]===53&&bytes[2]===1){
   const reader=new NativeMessageReader(1),body=bytes.subarray(3);assert.equal(reader.setReadMessage(body,body.length,0xffffffff,1),1);
   const eventType=reader.readWord(),skillId=reader.readWord(),targetId=reader.readObjectIdClient(),position=[reader.readFloat(),reader.readFloat(),reader.readFloat()];
   assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);
   report.guiWire.push({prefix:[...bytes.subarray(0,3)],eventType,skillId,targetId,position,bytes:bytes.length});
  }
  return sendGameMessage(bytes);
 };
 session.on('state',state=>{if(report.states.at(-1)!==state.phase&&report.states.length<32)report.states.push(state.phase);if(state.phase==='character-selection'&&!selecting){selecting=true;void fs.readFile(path.join(install,'data/lcv/bard.bic')).then(async bytes=>{try{report.characterSource='installed:bard.bic';report.characterSha256=hash(bytes);await session.selectCharacter(bytes);}finally{bytes.fill(0);}}).catch(()=>{asyncError='Read-only installed bard selection failed';});}});
 session.on('message',({message,areaGeneration})=>{
  if(message.kind==='client-area')void session.areaReady(areaGeneration).catch(()=>{asyncError='Authored protocol-only area-ready failed';});
  const authoredText=message.kind==='server-speech'?message.text?.text:message.kind==='combat-feedback'&&message.type===204?message.data?.strings?.[0]?.text:null;
  if(typeof authoredText==='string'&&authoredText.startsWith('NATIVE_SKILL_')&&report.speech.length<32)report.speech.push(authoredText.slice(0,256));
  if(message.kind==='custom-token'&&message.id===9001&&/^Owned GUI3 acknowledgement [1-9][0-9]*$/.test(message.text)&&report.received_tokens.length<8)report.received_tokens.push({kind:message.kind,id:message.id,text:message.text,major:message.major,minor:message.minor,areaGeneration});
 });
 let identity;
 await wait('owned server identity',async()=>{try{const serverLog=await fs.readFile(path.join(directory,'logs/nwengineLog.txt'),'utf8');identity=serverLog.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];return Boolean(identity);}catch{return false;}});
 await session.connect({host:'127.0.0.1',port:5127,expectedServerPublicKey:Buffer.from(identity,'base64'),metadata:created.metadata});
 await wait('owned character world',()=>{try{return session.controlledActor(session.world.areaId,session.areaGeneration).id===session.world.localObjectId;}catch{return false;}});
 check(session.phase==='playing'&&session.areaReadySent,'Real original server admits a read-only installed BIC through protocol-only ready boundary');
 const scope=()=>({areaId:session.world.areaId,areaGeneration:session.areaGeneration,actorId:session.world.localObjectId});
 await session.hudPanel({...scope(),panel:'character',open:true,page:1});
 await wait('received current skill rows',()=>session.world.registry.get(session.world.localObjectId)?.inventoryStats?.skills?.some(row=>row.flag));
 const actor=session.world.registry.get(session.world.localObjectId);
 report.disclosedSkillIndices=actor.inventoryStats.skills.filter(item=>item.flag).map(item=>item.index);
 const row=actor.inventoryStats.skills.find(item=>item.index===fixture.customizedSkill&&item.flag);
 const other=actor.inventoryStats.skills.find(item=>item.index!==fixture.customizedSkill&&item.flag);
 assert.ok(row&&other,'Customized and unchanged rows must both be disclosed by the original server');const receivedSkills=structuredClone(actor.inventoryStats.skills);
 report.skillId=row.index;report.actorId=actor.id;report.areaGeneration=session.areaGeneration;report.moduleSha256=fixture.sha256;report.scriptSha256=fixture.scriptSha256;
 check(Number.isInteger(row.index)&&row.flag,'Selection uses a current server-disclosed skill row without fabricating ranks');
 for(const count of [1,2]){
  const sent=await session.hudPanel({...scope(),panel:'skill',open:true,skillId:row.index,targetId:actor.id});
  check(sent.sent===true,'Production HUD admission sends GUI3 inspection '+count);
  const wire=report.guiWire.at(-1);check(JSON.stringify(wire.prefix)==='[112,53,1]'&&wire.eventType===3&&wire.skillId===row.index&&wire.targetId===actor.id&&wire.position.every(value=>value===0),'Actual outgoing GUI subtype1/type3 packet retains selected WORD/displayed OBJECT_ID/zero XYZ '+count);
  await wait('original GUI3 callback '+count,()=>report.speech.includes('NATIVE_SKILL_COUNT:'+count)&&report.speech.filter(value=>value==='NATIVE_SKILL_CUSTOMIZED:1').length>=count&&report.received_tokens.some(message=>message.text==='Owned GUI3 acknowledgement '+count));
  const offset=(count-1)*7,events=report.speech.slice(offset,offset+7);
  check(events.includes('NATIVE_SKILL_TYPE:3'),'Original server observes GUI event type3 for inspection '+count);
  check(events.includes('NATIVE_SKILL_INT:'+row.index),'Original server observes selected skill WORD for inspection '+count);
  check(events.includes('NATIVE_SKILL_TARGET_PC:1')&&events.some(value=>/^NATIVE_SKILL_TARGET:[0-9a-f]+$/i.test(value)),'Original server target resolves to this displayed player object for inspection '+count);
  check(events.some(value=>value.startsWith('NATIVE_SKILL_POSITION_MAGNITUDE:')&&Number(value.slice('NATIVE_SKILL_POSITION_MAGNITUDE:'.length))===0),'Original server observes zero position vector for inspection '+count);
  check(report.received_tokens.some(message=>message.id===9001&&message.text==='Owned GUI3 acknowledgement '+count),'Actual server SetCustomToken reaches production receive parser for inspection '+count);
 }
 for(const count of [3,4]){
  await session.hudPanel({...scope(),panel:'skill',open:true,skillId:other.index,targetId:actor.id});
  await wait('unchanged skill callback '+count,()=>report.speech.includes('NATIVE_SKILL_COUNT:'+count)&&report.speech.filter(value=>value==='NATIVE_SKILL_CUSTOMIZED:0').length>=count-2);
  const events=report.speech.slice((count-1)*7,count*7);
  check(events.includes('NATIVE_SKILL_TYPE:3')&&events.includes('NATIVE_SKILL_INT:'+other.index),'Unchanged skill still reaches original GUI3 callback '+count);
  check(report.received_tokens.length===2&&events.includes('NATIVE_SKILL_CUSTOMIZED:0'),'Original module selectively leaves the other skill token unchanged on callback '+count);
 }
 report.unchangedSkillId=other.index;
 check(report.guiWire.length===4,'All four customized/unchanged selections use ordinary GUI3 packets');
 check(JSON.stringify(session.world.registry.get(actor.id).inventoryStats.skills)===JSON.stringify(receivedSkills),'GUI inspection and authored acknowledgements do not alter received skill ranks');
 const before=report.speech.length;
 await assert.rejects(session.hudPanel({...scope(),panel:'skill',open:true,skillId:row.index,targetId:actor.id+1}));
 await pause(150);check(report.speech.length===before,'Wrong displayed target is rejected before any additional original-server GUI callback');
 for(const[file,digest]of loaded)assert.equal(hash(await fs.readFile(file)),digest,'Loaded protocol source changed');
 report.sources=[...loaded].map(([file,sha256])=>({path:path.relative(workspace,file).replaceAll('\\','/'),sha256}));
 report.success=true;
}catch(error){report.failure=key&&String(error.message).includes(key)?'Private local session input failed':String(error.message).slice(0,240);}
finally{
 key='';await session?.disconnect().catch(()=>{});report.sessionClosed=!session||session.closed;
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({success:report.success,checks:report.checks,failure:report.failure??null,report:output,sessionClosed:report.sessionClosed}));
 process.exit(report.success?0:1);
}
