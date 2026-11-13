import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {NativeMessageWriter} from '../../src/native_message.js';
import {networkLevelUpSnapshot,levelUpBeginRequest} from '../../src/network_level_up.js';
import {characterSheetRequest} from '../../src/network_hud_input.js';
import {nativeLevelUpDraftContext} from '../../src/network_level_up_context.js';

const [modulePath,report,mode]=process.argv.slice(2);
if(!modulePath||!report||!['before','staged'].includes(mode)||fs.existsSync(report))throw Error('Supply an isolated module, new report and before/staged mode');
const {NetworkGameSession}=await import(pathToFileURL(modulePath));
let checks=0;const equal=(a,b)=>{assert.deepEqual(a,b);checks++;};
const observations=[];
function harness(){
 const peer=new EventEmitter(),sent=[];peer.sendGameMessage=async bytes=>sent.push(Uint8Array.from(bytes));peer.disconnect=async()=>{};
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision:37,postfix:0},dispose(){}},resources:{},language:0,openModule:async()=>null});
 const actor={id:0xffffffce,objectType:5,areaId:0x80000001,replicated:{stats:{classes:[{id:4,level:1}],racialType:0,fieldDE4:50,fieldDE6:50}},playerState:{combat:{canLevelUp:true},abilities:{base:[12,12,12,12,12,12]},levelUp:{fieldDC6:0,skills:[0],fieldE34:255,fieldE48:'',fieldE30:255,fieldE38:'',fieldD4:0,fieldC0:0},feats:[]}};
 session.phase='playing';session.areaReadySent=true;session.areaGeneration=2;session.world.areaId=actor.areaId;session.world.localObjectId=actor.id;session.world.registry.addObjectAtPos(actor.id,actor);session.objectRules={skillCount:1,classInfo:()=>({})};
 return{session,actor,sent,request:{operation:'begin',actorId:actor.id,areaId:actor.areaId,areaGeneration:2}};
}
async function availability(session){
 const writer=new NativeMessageWriter(1);writer.create(16,0xffffffff,1);writer.writeByte(5);
 for(let id=0;id<5;id++)writer.writeBool(Number(id===4));writer.setPrefix(Uint8Array.of(80,29,4));
 await session.receive(Uint8Array.from(writer.getWriteMessage().data));
}
for(const raw of [-128,-7,0,17,127,null,undefined,NaN,Infinity,-129,128,1.5,'0']){
 const actor=raw===undefined?{}:{inventoryStats:{field9c:raw,unrelated:[1,2]}};
 const before=structuredClone(actor),value=nativeLevelUpDraftContext(actor),expected=typeof raw==='number'&&Number.isInteger(raw)&&raw>=-128&&raw<=127?raw:null;
 equal(value,{baseFortitude:expected});value.baseFortitude=72;equal(actor,before);equal(nativeLevelUpDraftContext(actor),{baseFortitude:expected});
}
equal(nativeLevelUpDraftContext({inventoryStats:Object.create({field9c:4})}),{baseFortitude:null});
for(const [label,stats,expected]of [['minimum',{field9c:-128},-128],['negative',{field9c:-3},-3],['zero',{field9c:0},0],['positive',{field9c:12},12],['maximum',{field9c:127},127],['missing',undefined,null],['unknown',{},null],['malformed',{field9c:'12'},null]]){
 const h=harness();if(stats!==undefined)h.actor.inventoryStats=stats;
 const actorBefore=JSON.stringify(h.actor),snapshotBefore=networkLevelUpSnapshot(h.actor),started=performance.now();
 const pending=h.session.levelUp(h.request);await Promise.resolve();await Promise.resolve();await availability(h.session);const result=await pending;
 equal(result.draftContext,mode==='staged'?{baseFortitude:expected}:undefined);
 equal(result.snapshot,snapshotBefore);equal(result.snapshot,h.session.levelUpDraft.snapshot);
 equal(Object.keys(h.session.levelUpDraft).sort(),['actorId','areaGeneration','areaId','available','snapshot','token'].sort());
 equal(JSON.stringify(h.actor),actorBefore);equal(result.protocolFeatures,{multiclassRuleset:true});equal(result.available,[false,false,false,false,true]);equal(h.sent.map(bytes=>[...bytes]),[characterSheetRequest({targetId:h.actor.id,page:0}),levelUpBeginRequest()].map(bytes=>[...bytes]));equal(h.session.pendingLevelUp,null);
 const token=h.session.levelUpToken;h.session.completeLevelUpBegin();equal(h.session.levelUpToken,token);
 if(mode==='staged'){result.draftContext.baseFortitude=99;equal(JSON.stringify(h.actor),actorBefore);equal(result.snapshot,snapshotBefore);}
 observations.push({label,forwarded:mode==='staged'?expected:null,contextPresent:mode==='staged',elapsedMs:performance.now()-started});
}
{
 const h=harness();let resolved=0;h.session.pendingLevelUp={...h.request,available:[true],resolve:()=>resolved++};h.session.world.localObjectId=123;
 const prior=h.session.pendingLevelUp,oldDraft=h.session.levelUpDraft;h.session.completeLevelUpBegin();equal(resolved,0);equal(h.session.pendingLevelUp,prior);equal(h.session.levelUpDraft,oldDraft);
}
{
 const h=harness(),pending=h.session.levelUp(h.request);await Promise.resolve();await Promise.resolve();h.actor.inventoryStats={field9c:9};await availability(h.session);const result=await pending;
 equal(result.draftContext,mode==='staged'?{baseFortitude:9}:undefined);equal(h.actor.inventoryStats,{field9c:9});
}
fs.writeFileSync(report,JSON.stringify({success:true,checks,mode,observations,serverConnections:0,nativeBuilds:0,scope:'Copied actual Session begin/availability boundaries with detached received-only private context; canonical actor/snapshot/private transaction equality, valid zero and explicit unavailable data, stale actor and current reply capture. No game server, Godot UI or server level-up acceptance.'},null,2)+'\n');
console.log(JSON.stringify({success:true,checks,mode,report}));
