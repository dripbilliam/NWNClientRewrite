import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NativeMessageReader} from '../src/native_message.js';
import {featDescriptionGuiRequest} from '../src/network_hud_input.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';

function fields(packet,includePosition){
 assert.deepEqual([...packet.subarray(0,3)],[112,53,1]);
 const reader=new NativeMessageReader(1),body=packet.subarray(3);
 assert.equal(reader.setReadMessage(body,body.length,0xffffffff,1),1);
 const value={eventType:reader.readWord(),featId:reader.readWord(),targetId:reader.readObjectIdClient()};
 if(includePosition)value.position=[reader.readFloat(),reader.readFloat(),reader.readFloat()];
 assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);
 return value;
}
function harness(actorData={}){
 const peer=new EventEmitter(),sent=[];peer.sendGameMessage=async bytes=>sent.push(Uint8Array.from(bytes));peer.disconnect=async()=>peer.emit('closed');
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision:37,postfix:2},dispose(){}},resources:{},language:0,openModule:async()=>null});
 const actor={id:0xffffffce,areaId:0x80000001,objectType:5,...actorData};
 session.phase='playing';session.areaReadySent=true;session.areaGeneration=2;session.world.areaId=actor.areaId;session.world.localObjectId=actor.id;session.world.registry.addObjectAtPos(actor.id,actor);
 session.objectRules={featInputInfo(){throw Error('GUI4 admission must not project JS feat rules');}};
 const request={areaId:actor.areaId,areaGeneration:2,actorId:actor.id,targetId:actor.id,panel:'feat',open:true};
 return{session,actor,sent,request};
}

test('GUI4 encodes selected feat WORD, displayed OBJECT_ID and versioned zero XYZ',()=>{
 for(const featId of [0,1,255,256,303,65535])for(const targetId of [0,42,0x80000001,0xffffffce,0xffffffff])for(const includePosition of [false,true]){
  const value=fields(featDescriptionGuiRequest({featId,targetId,includePosition}),includePosition);
  assert.deepEqual(value,{eventType:4,featId,targetId,...(includePosition?{position:[0,0,0]}:{})});
 }
 for(const featId of [undefined,null,false,'0',-1,65536,1.5,NaN])assert.throws(()=>featDescriptionGuiRequest({featId,targetId:42,includePosition:true}));
 for(const targetId of [undefined,null,'42',-1,0x100000000,1.5])assert.throws(()=>featDescriptionGuiRequest({featId:0,targetId,includePosition:true}));
 for(const includePosition of [undefined,null,0,1,'true'])assert.throws(()=>featDescriptionGuiRequest({featId:0,targetId:42,includePosition}));
});

test('repeated GUI4 respects current actor/scope/build, without local rule projection or mutation',async()=>{
 const {session:s,actor,sent,request}=harness({inventoryStats:{fields118:[303],fields128:[304]}}),before=structuredClone(actor);
 for(const revision of [34,35])for(let click=0;click<2;click++){
  s.serverBuild={number:8193,revision,postfix:0};assert.deepEqual(await s.hudPanel({...request,featId:303}),{sent:true});
  assert.deepEqual(fields(sent.at(-1),revision>=35),{eventType:4,featId:303,targetId:actor.id,...(revision>=35?{position:[0,0,0]}:{})});
 }
 await s.hudPanel({...request,featId:304});assert.deepEqual(actor,before);
 const count=sent.length;
 for(const change of [{actorId:1},{areaId:0},{areaGeneration:1},{targetId:0xffffffff},{featId:305},{featId:'303'},{featId:null},{featId:65536},{featId:303.5},{open:false},{open:1}])await assert.rejects(s.hudPanel({...request,featId:303,...change}));
 actor.inventoryStats.fields118=[];await assert.rejects(s.hudPanel({...request,featId:303}));
 s.phase='area-loading';await assert.rejects(s.hudPanel({...request,featId:304}));
 assert.equal(sent.length,count);await s.disconnect();
});

test('raw field118/128 lists override stale primary and bonus fallbacks, including explicit empty lists',async()=>{
 const {session:s,actor,sent,request}=harness({inventoryStats:{fields118:[2],fields128:[3],feats:[{id:6,flag:false}]},playerState:{feats:[4],bonusFeats:[5]}});
 for(const featId of [2,3])await s.hudPanel({...request,featId});
 for(const featId of [0,4,5,6])await assert.rejects(s.hudPanel({...request,featId}));
 actor.inventoryStats.fields118=[];actor.inventoryStats.fields128=[];
 for(const featId of [2,3,4,5,6])await assert.rejects(s.hudPanel({...request,featId}));
 assert.equal(sent.length,2);await s.disconnect();
});

test('fallback player primary/bonus and inventory feat records preserve exact disclosed IDs regardless of flag',async()=>{
 const {session:s,actor,sent,request}=harness({inventoryStats:{feats:[{id:6,flag:false},{id:7,flag:true}]},playerState:{feats:[4],bonusFeats:[5]}});
 for(const featId of [4,5])await s.hudPanel({...request,featId});
 await assert.rejects(s.hudPanel({...request,featId:6}));
 actor.playerState.feats=[];await assert.rejects(s.hudPanel({...request,featId:6}));
 delete actor.playerState.feats;for(const featId of [6,7])await s.hudPanel({...request,featId});
 actor.inventoryStats.fields128=[];await assert.rejects(s.hudPanel({...request,featId:5}));
 assert.equal(sent.length,4);await s.disconnect();
});

test('missing, null and malformed identity fields never invent feat zero',async()=>{
 for(const actorData of [{},{inventoryStats:{}},{playerState:{feats:[]}},{inventoryStats:{feats:[{},null,{flag:false},{id:'0'}]}},{inventoryStats:{fields118:[null,undefined,false,'0',{},NaN],fields128:[]}},{inventoryStats:{fields118:null},playerState:{feats:[0]}},{inventoryStats:{fields118:[],fields128:null},playerState:{feats:[0],bonusFeats:[0]}}]){
  const {session:s,sent,request}=harness(actorData);await assert.rejects(s.hudPanel({...request,featId:0}));assert.equal(sent.length,0);await s.disconnect();
 }
 const {session:s,sent,request}=harness({playerState:{feats:[0]}});await s.hudPanel({...request,featId:0});assert.equal(fields(sent[0],true).featId,0);await s.disconnect();
});

test('received primary/bonus membership changes retire old requests without a JS successor calculation',async()=>{
 const {session:s,actor,sent,request}=harness({inventoryStats:{fields118:[1],fields128:[2]}});
 await s.hudPanel({...request,featId:2}); // Native UI may display this owned successor.
 actor.inventoryStats.fields128=[];await assert.rejects(s.hudPanel({...request,featId:2}));
 actor.inventoryStats.fields118=[2];await s.hudPanel({...request,featId:2});
 s.world.localObjectId=0x80000033;await assert.rejects(s.hudPanel({...request,featId:2}));
 assert.equal(sent.length,2);await s.disconnect();
});
