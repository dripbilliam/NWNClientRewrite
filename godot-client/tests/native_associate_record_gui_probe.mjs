// Protocol-only companion to installed native input; no live full-UI claim.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire,registerHooks} from 'node:module';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
const require=createRequire(import.meta.url),option=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);
const directory=option('directory'),install=option('install'),pipe=option('private-login-pipe'),output=option('report'),distinctFromAudit=option('distinct-from-audit');assert.ok(directory&&install&&pipe&&output);
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),sha=bytes=>createHash('sha256').update(bytes).digest('hex'),loaded=new Map([[fileURLToPath(import.meta.url),sha(readFileSync(fileURLToPath(import.meta.url)))]]);
registerHooks({resolve(specifier,context,next){const result=next(specifier,context);if(result.url.startsWith('file:')){const file=fileURLToPath(result.url);if(file.startsWith(root+path.sep)&&!loaded.has(file))loaded.set(file,sha(readFileSync(file)));}return result;}});
const report={success:false,checks:0,cases:[],states:[],diagnosticCodes:[],loginRejections:[],networkLoginStarted:false,records:[],wire:[],guiWire:[],speech:[],receivedTokens:[],receivedTlk:[],publicConnections:0,gameEndpoint:'127.0.0.1:5127',gpu:false,renderer:false,nativeBuilds:0,scope:'Actual Session target21/1 and GUI3/4 against unchanged original server/new authored module, real received NPC rows and selective TLK/token callbacks. Companion native-input proof is separate; no live full-UI or pixel claim.'};
let session,key='',asyncError=null,sequence=0,target=null;
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const check=(value,label)=>{report.checks++;report.cases.push({label,passed:Boolean(value)});assert.ok(value,label);};
async function wait(label,predicate,timeout=20000){report.awaiting=label;const until=Date.now()+timeout;while(Date.now()<until){if(asyncError)throw Error(asyncError);if(session?.closed)throw Error('Owned session closed');if(await predicate())return;await pause(20);}throw Error('Timed out '+label);}
try{
 const fixture=JSON.parse(await fs.readFile(path.join(directory,'fixture.json'),'utf8'));assert.equal(fixture.module,'AssocRecordGui');assert.equal(fixture.port,5127);
 const {readPrivateKey,connectPrivatePipe}=require('../tools/private-login.cjs');key=await readPrivateKey(connectPrivatePipe(pipe));
 if(distinctFromAudit){
  const audit=JSON.parse(await fs.readFile(distinctFromAudit,'utf8')),reference=audit.records?.find(row=>row.label==='accepted_npc14')?.participantPublicTagHash;
  assert.match(String(reference),/^[a-f0-9]{64}$/);
  const {publicCdKey}=await import('../../electron/network_login_identity.mjs');
  const hashPublic=value=>{const identifier=publicCdKey(value);assert.equal(identifier.length,8);return sha(identifier);};
  const publicIdentityHash=hashPublic(key);report.publicIdentityPreflight={distinct:publicIdentityHash!==reference,publicIdentityHash,referenceMainPublicIdentityHash:reference};
  assert.ok(report.publicIdentityPreflight.distinct,'Explicit alternate protected participant must differ from prior MAIN identity');
 }
 const {createInstalledNetworkSession}=await import('../../electron/installed_network_session.mjs'),{NativeMessageReader}=await import('../../src/native_message.js');
 const created=await createInstalledNetworkSession({install,userDirectory:path.join(directory,'client'),modsDirectory:null,host:'127.0.0.1',port:5127,name:'OwnedRecordGuiTest',credentials:{cdKey:key,password:''},onDiagnostic:value=>{
  if(report.diagnosticCodes.length<64)report.diagnosticCodes.push(String(value.code??'unknown'));
  if(value.code==='network.login-rejected'&&report.loginRejections.length<8)report.loginRejections.push({connectionError:Number.isInteger(value.connectionError)?value.connectionError:null,tag:['BNCR','BNVR'].includes(value.tag)?value.tag:null});
 }});key='';session=created.session;let selecting=false;
 const send=session.peer.sendGameMessage.bind(session.peer);
 session.peer.sendGameMessage=bytes=>{
  if(bytes[0]===112&&bytes[1]===21&&bytes[2]===1){const r=new NativeMessageReader(1),body=bytes.subarray(3);assert.equal(r.setReadMessage(body,body.length,0xffffffff,1),1);const page=r.readChar(),targetId=r.readObjectIdClient();assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);assert.ok(report.wire.length<16);report.wire.push({page,targetId,bytes:bytes.length});}
  if(bytes[0]===112&&bytes[1]===53&&bytes[2]===1){const r=new NativeMessageReader(1),body=bytes.subarray(3);assert.equal(r.setReadMessage(body,body.length,0xffffffff,1),1);const event=r.readWord(),rowId=r.readWord(),targetId=r.readObjectIdClient(),position=[r.readFloat(),r.readFloat(),r.readFloat()];assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);assert.ok([3,4].includes(event)&&report.guiWire.length<16);report.guiWire.push({event,rowId,targetId,position,bytes:bytes.length});}
  return send(bytes);
 };
 session.on('state',state=>{if(report.states.at(-1)!==state.phase&&report.states.length<32)report.states.push(state.phase);if(state.phase==='character-selection'&&!selecting){selecting=true;void fs.readFile(path.join(install,'data/lcv/bard.bic')).then(async bytes=>{try{report.characterSha256=sha(bytes);assert.equal(report.characterSha256,'e1e8e7e4437ae23d860e1423eef43e07792de3cfd65a0514dd5868e55dcdfd86');await session.selectCharacter(bytes);}finally{bytes.fill(0);}}).catch(()=>{asyncError='Unchanged installed Bard admission failed';});}});
 session.on('message',({message})=>{
  if(message.kind==='client-area')void session.areaReady(session.areaGeneration).catch(()=>{asyncError='Owned protocol readiness failed';});
  if(Array.isArray(message.records))for(const row of message.records)if(row.action==='inventory-stats'&&report.records.length<128)report.records.push({sequence:++sequence,id:row.id,mask:row.mask});
  const text=message.kind==='server-speech'?message.text?.text:message.kind==='combat-feedback'&&message.type===204?message.data?.strings?.[0]?.text:null;
  if(typeof text==='string'&&text.startsWith('NATIVE_RECORD_')&&report.speech.length<128)report.speech.push(text.slice(0,192));
  if(message.kind==='custom-token'&&[9011,9012].includes(message.id)&&/^Owned Record GUI[34] token \d+$/.test(message.text)&&report.receivedTokens.length<16)report.receivedTokens.push({id:message.id,text:message.text});
  if(message.kind==='tlk-overrides')for(const row of message.entries)if(typeof row.text==='string'&&/^Owned Record GUI[34] help \d+ <CUSTOM901[12]>$/.test(row.text)&&report.receivedTlk.length<16)report.receivedTlk.push({strRef:row.strRef,text:row.text});
 });
 let identity;await wait('owned identity',async()=>{try{identity=(await fs.readFile(path.join(directory,'logs/nwengineLog.txt'),'utf8')).match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];return Boolean(identity);}catch{return false;}});
 report.networkLoginStarted=true;await session.connect({host:'127.0.0.1',port:5127,expectedServerPublicKey:Buffer.from(identity,'base64'),metadata:created.metadata});
 await wait('owned actor world',()=>{try{return session.phase==='playing'&&session.controlledActor(session.world.areaId,session.areaGeneration).id===session.world.localObjectId;}catch{return false;}});
 const actorId=session.world.localObjectId,actor=session.world.registry.get(actorId),area=session.world.areaId,generation=session.areaGeneration,scope=()=>({areaId:area,areaGeneration:generation,actorId});
 const name=object=>{const value=object.appearance?.name??object.replicated?.name;return value?.text??[value?.firstName?.text,value?.lastName?.text].filter(Boolean).join(' ');};
 await wait('actual Native Speaker',()=>{target=[...session.world.registry.objects.values()].find(value=>value.objectType===5&&value.areaId===area&&!value.replicationRemoved&&name(value)==='Native Speaker'&&Number.isInteger(value.replicated?.master));return Boolean(target);});
 check(target.id!==actorId&&target.replicated.master===0x7f000000,'Received separate NPC precedes original association');
 await session.chat({...scope(),text:'-native-party-add',channel:1});await wait('original AddHenchman',()=>target.replicated.master===actorId&&target.replicated.field908===1);
 const request=()=>({...scope(),targetId:target.id,recordActorLifetime:session.world.entityDisclosures.token(actor),recordTargetLifetime:session.world.entityDisclosures.token(target)});
 report.target=request();check(report.target.recordActorLifetime>0&&report.target.recordTargetLifetime>0,'Canonical disclosure tokens bind actor and separate displayed NPC');
 const sameOwner=()=>session.world.localObjectId===actorId&&session.world.areaId===area&&session.areaGeneration===generation&&session.world.registry.get(actorId)===actor&&session.world.registry.get(target.id)===target&&target.replicated.master===actorId;
 async function page(index,requireDisclosure=true){
  const before=sequence;await session.hudPanel({...request(),panel:'character',open:true,page:index});
  if(requireDisclosure){const mask=index===0?1:index===1?128:512;await wait('received NPC page'+index,()=>report.records.some(row=>row.sequence>before&&row.id===target.id&&(row.mask&mask)!==0));}
  //21/1 is a subscription, not a request ACK. The initial actual disclosure
  // remains current when revisiting an unchanged page; don't require a delta.
  else{report.pageSubscriptionAcknowledged=false;assert.ok(index===1?Array.isArray(target.inventoryStats?.skills):Array.isArray(target.inventoryStats?.fields118));}
  check(sameOwner(),'NPC page'+index+' preserves actual controlled/world/target owners');
 }
 for(const index of [0,1,2])await page(index);
 const raw=structuredClone({skills:target.inventoryStats?.skills,primary:target.inventoryStats?.fields118,bonus:target.inventoryStats?.fields128});report.disclosed=raw;
 check(Array.isArray(target.inventoryStats?.fields70)&&target.inventoryStats.fields70.length===6,'Original NPC page0 actually supplies six abilities');
 check([fixture.rows.skill.customized,fixture.rows.skill.unchanged].every(id=>raw.skills.some(row=>row.index===id&&row.flag)),'Both customized/unchanged skills are actually disclosed by original server');
 check([fixture.rows.feat.customized,fixture.rows.feat.unchanged,fixture.proficiency.id].every(id=>raw.primary.includes(id))&&Array.isArray(raw.bonus),'Original NPC disclosure includes authored3/4 and retained real proficiency');
 let count=0;
 for(const [kind,row]of Object.entries(fixture.rows)){
  await page(kind==='skill'?1:2,false);const unchangedBefore=session.world.tlkOverrides.get(row.unchangedDescription);
  for(const id of [row.customized,row.customized,row.unchanged,row.unchanged]){
   count++;const customized=id===row.customized,notes=report.speech.length,tokens=report.receivedTokens.length,tlk=report.receivedTlk.length;
   const oldCustom=session.world.tlkOverrides.get(row.description);
   await session.hudPanel({...request(),panel:kind,open:true,[kind==='skill'?'skillId':'featId']:id});
   await wait('original target GUI'+row.event+' callback'+count,()=>{const events=report.speech.slice(notes);return events.includes('NATIVE_RECORD_COUNT:'+count)&&events.includes('NATIVE_RECORD_CUSTOMIZED:'+(customized?1:0));});
   const events=report.speech.slice(notes),wire=report.guiWire.at(-1);
   check(events.includes('NATIVE_RECORD_TYPE:'+row.event)&&events.includes('NATIVE_RECORD_INT:'+id),'Original server reads exact GUI type/WORD for callback'+count);
   check(events.includes('NATIVE_RECORD_TARGET_NPC:1')&&events.includes('NATIVE_RECORD_TARGET_PC:0')&&events.some(value=>/^NATIVE_RECORD_TARGET:[0-9a-f]+$/i.test(value)),'Original callback target is the authored NPC, separate from sender'+count);
   check(events.some(value=>value.startsWith('NATIVE_RECORD_POSITION:')&&Number(value.slice('NATIVE_RECORD_POSITION:'.length))===0)&&wire.event===row.event&&wire.rowId===id&&wire.targetId===target.id&&wire.position.every(value=>value===0),'Actual outgoing wire and original callback preserve target/zeroXYZ'+count);
   if(customized){
    const token='Owned Record GUI'+row.event+' token '+count,help='Owned Record GUI'+row.event+' help '+count+' <CUSTOM'+row.token+'>';
    await wait('decoded selective TLK/token'+count,()=>report.receivedTokens.some(value=>value.id===row.token&&value.text===token)&&report.receivedTlk.some(value=>value.strRef===row.description&&value.text===help));
    check(session.world.tlkOverrides.get(row.description)===help&&report.receivedTokens.length===tokens+1&&report.receivedTlk.length===tlk+1,'Actual original setters reach production receive owner once'+count);
   }else check(report.receivedTokens.length===tokens&&report.receivedTlk.length===tlk&&session.world.tlkOverrides.get(row.description)===oldCustom,'Unchanged row still emits GUI event without changing selected help'+count);
   check(session.world.tlkOverrides.get(row.unchangedDescription)===unchangedBefore&&sameOwner(),'Other row help and actor/target scope remain unchanged'+count);
  }
 }
 check(report.guiWire.length===8,'Exactly eight target inspections produce eight typed GUI packets');
 check(JSON.stringify(raw)===JSON.stringify({skills:target.inventoryStats?.skills,primary:target.inventoryStats?.fields118,bonus:target.inventoryStats?.fields128}),'GUI/TLK/token callbacks do not alter disclosed rank/feat ownership');
 await session.hudPanel({...request(),panel:'character',open:false});check(report.wire.length===6&&report.wire.every(row=>row.targetId===target.id)&&report.wire.map(row=>row.page).join(',')==='0,1,2,1,2,-1','Typed page/close requests retain actual displayed target and signed close');report.closeAcknowledged=false;
 await session.chat({...scope(),text:'-native-party-remove',channel:1});await wait('original RemoveHenchman',()=>target.replicated.master!==actorId);
 await assert.rejects(session.hudPanel({...request(),panel:'feat',open:true,featId:fixture.rows.feat.customized}));check(report.guiWire.length===8&&session.world.localObjectId===actorId,'Ownership loss rejects additional target GUI without changing actor');
 for(const[file,digest]of loaded)assert.equal(sha(await fs.readFile(file)),digest,'Loaded protocol source changed');report.sources=[...loaded].map(([file,sha256])=>({path:path.relative(root,file).replaceAll('\\','/'),sha256}));report.success=true;
}catch(error){report.failureType=String(error?.name??'Error');report.failureCode=typeof error?.code==='string'?error.code:null;report.lastCheck=report.cases.at(-1)?.label??null;report.failurePhase='Typed target GUI protocol companion; native full UI is separate';const login=session?.peer?.login;report.loginState={phase:['new','key-exchange','connect','validate','rejected','admitted'].includes(login?.phase)?login.phase:null,connectionError:Number.isInteger(login?.connectionError)?login.connectionError:null};}
finally{key='';await session?.disconnect().catch(()=>{});report.sessionClosed=!session||session.closed;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,checks:report.checks,failureType:report.failureType??null,report:output,sessionClosed:report.sessionClosed}));process.exit(report.success?0:1);}
