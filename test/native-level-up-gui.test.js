import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {levelUpCancelGuiRequest} from '../src/network_level_up_gui.js';
import {NativeMessageReader,NativeMessageWriter} from '../src/native_message.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
function decode(packet,includePosition){
 assert.deepEqual([...packet.subarray(0,3)],[112,53,1]);const reader=new NativeMessageReader(1),body=packet.subarray(3);assert.equal(reader.setReadMessage(body,body.length,0xffffffff,1),1);
 assert.equal(reader.readWord(),16);assert.equal(reader.readWord(),0);assert.equal(reader.readObjectIdClient(),0x7f000000);if(includePosition)for(let index=0;index<3;index++)assert.equal(reader.readFloat(),0);assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);
}
function harness(revision=37){
 const peer=new EventEmitter(),sent=[];peer.sendGameMessage=async bytes=>sent.push(Uint8Array.from(bytes));peer.disconnect=async()=>{};
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision,postfix:0},dispose(){}},resources:{},language:0,openModule:async()=>null});
 const actor={id:0xffffffce,objectType:5,areaId:0x80000001,replicated:{stats:{classes:[{id:4,level:1}],racialType:0,fieldDE4:50,fieldDE6:50}},playerState:{combat:{canLevelUp:true},abilities:{base:[12,12,12,12,12,12]},levelUp:{fieldDC6:0,skills:[0],fieldE34:255,fieldE48:'',fieldE30:255,fieldE38:'',fieldD4:0,fieldC0:0},feats:[]}};
 session.phase='playing';session.areaReadySent=true;session.areaGeneration=2;session.world.areaId=actor.areaId;session.world.localObjectId=actor.id;session.world.registry.addObjectAtPos(actor.id,actor);
 const request={operation:'cancel',actorId:actor.id,areaId:actor.areaId,areaGeneration:2};return{session,peer,sent,actor,request};
}
test('typed original GUI16 preserves fixed event, zero selection, invalid target and both versioned zero-position shapes',()=>{for(const includePosition of [false,true])decode(levelUpCancelGuiRequest({includePosition}),includePosition);for(const includePosition of [null,undefined,0,1,'true'])assert.throws(()=>levelUpCancelGuiRequest({includePosition}));});
for(const revision of [34,35])test('actual Session cancel sends GUI16 for revision'+revision+' without changing canonical character state or claiming server acknowledgment',async()=>{
 const h=harness(revision),before=JSON.stringify(h.actor),draft={token:7};h.session.levelUpDraft=draft;const result=await h.session.levelUp(h.request);assert.equal(h.sent.length,1);decode(h.sent[0],revision>=35);assert.equal(result.cancelled,true);assert.equal(result.sent,true);assert.equal(result.serverAcknowledged,false);assert.equal(h.session.levelUpDraft,null);assert.equal(JSON.stringify(h.actor),before);
});
test('cancel preserves an already pending original-server submission and its private draft',async()=>{const h=harness(),pending={operation:'submit'},draft={token:8};h.session.pendingLevelUp=pending;h.session.levelUpDraft=draft;await h.session.levelUp(h.request);assert.equal(h.sent.length,1);assert.equal(h.session.pendingLevelUp,pending);assert.equal(h.session.levelUpDraft,draft);});
test('wrong actor and stale area never send a cancellation event',async()=>{for(const change of [{actorId:22},{areaId:22},{areaGeneration:1}]){const h=harness();await assert.rejects(async()=>h.session.levelUp({...h.request,...change}));assert.equal(h.sent.length,0);}});
test('failed transport is not successful cancellation or draft retirement',async()=>{const h=harness(),draft={token:9};h.session.levelUpDraft=draft;h.peer.sendGameMessage=async()=>{throw Error('authored transport failure');};await assert.rejects(h.session.levelUp(h.request),/authored transport failure/);assert.equal(h.session.levelUpDraft,draft);});
test('replaced world or peer during send cannot retire a later level-up draft',async()=>{for(const replace of ['world','peer']){const h=harness(),later={token:10};let release;h.peer.sendGameMessage=()=>new Promise(resolve=>release=resolve);const pending=h.session.levelUp(h.request);if(replace==='world'){const other=harness();h.session.world=other.session.world;}else h.session.peer=new EventEmitter();h.session.levelUpDraft=later;release();await assert.rejects(pending,/retired|changed|stale/i);assert.equal(h.session.levelUpDraft,later);}});
for(const serverRevision of [34,35])test('actual begin result publishes only protocol capability metadata from the negotiated server revision'+serverRevision,async()=>{
 const h=harness(37);h.session.serverBuild={number:8193,revision:serverRevision,postfix:0};h.session.objectRules={skillCount:1,classInfo:()=>({})};
 const pending=h.session.levelUp({...h.request,operation:'begin'});await Promise.resolve();await Promise.resolve();const writer=new NativeMessageWriter(1);writer.create(16,0xffffffff,1);writer.writeByte(5);for(let id=0;id<5;id++)writer.writeBool(Number(id===4));writer.setPrefix(Uint8Array.of(80,29,4));await h.session.receive(Uint8Array.from(writer.getWriteMessage().data));
 const result=await pending;assert.deepEqual(result.protocolFeatures,{multiclassRuleset:serverRevision>=35});assert.equal('protocolFeatures'in result.snapshot,false);assert.equal(JSON.stringify(result.snapshot),JSON.stringify(h.session.levelUpDraft.snapshot));assert.deepEqual(h.actor.replicated.stats.classes,[{id:4,level:1}]);assert.deepEqual(result.available,[false,false,false,false,true]);assert.equal(h.session.pendingLevelUp,null);
});
test('unavailable build metadata leaves the original pending begin and private transaction intact',()=>{
 const h=harness(),draft={token:31};h.session.serverBuild={number:8193,revision:null,postfix:0};h.session.levelUpDraft=draft;let resolutions=0;
 const pending={...h.request,operation:'begin',available:[true],resolve:()=>resolutions++};h.session.pendingLevelUp=pending;
 h.session.completeLevelUpBegin();assert.equal(resolutions,0);assert.equal(h.session.pendingLevelUp,pending);assert.equal(h.session.levelUpDraft,draft);assert.equal(h.session.levelUpToken,undefined);
});
