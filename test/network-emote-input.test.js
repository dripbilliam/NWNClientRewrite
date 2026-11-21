import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeMessageReader} from '../src/native_message.js';
import {emoteAnimationRequest} from '../src/network_emote_input.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';

test('native6/4 animation envelope preserves WORD, raw OBJECT_ID and four original FLOAT fields',()=>{
 for(const actorId of [0,0x7f000000,0x80000012,0xffffffff])for(const animation of [0,47,65535]){
  const input={actorId,animation,position:[1.25,-20.5,0.03125],duration:10},before=structuredClone(input),bytes=emoteAnimationRequest(input);
  assert.deepEqual(Array.from(bytes.subarray(0,3)),[112,6,4]);const r=new NativeMessageReader(1);r.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1);
  assert.equal(r.readWord(),animation);assert.equal(r.readObjectIdClient(),actorId);for(const v of [...input.position,input.duration])assert.equal(r.readFloat(1,32),Math.fround(v));assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);assert.deepEqual(input,before);
 }
 for(const patch of [{actorId:-1},{actorId:2**32},{animation:-1},{animation:65536},{position:[NaN,0,0]},{position:[1,2]},{duration:-1},{duration:Infinity}])assert.throws(()=>emoteAnimationRequest({actorId:1,animation:47,position:[0,0,0],duration:10,...patch}));
});
test('protocol owner forwards native-selected animation then optional voice without changing actor state',async()=>{
 const packets=[],actor=Object.freeze({id:0xffffffff}),owner={controlledActor:(area,generation)=>{assert.equal(area,4);assert.equal(generation,8);return actor;},peer:{sendGameMessage:async p=>packets.push(p)}};
 const input={areaId:4,areaGeneration:8,actorId:actor.id,animation:41,position:[0,1,2],duration:0,voice:42};assert.deepEqual(await NetworkGameSession.prototype.playEmote.call(owner,input),{sent:true});assert.deepEqual(packets.map(p=>Array.from(p.subarray(0,3))),[[112,6,4],[112,22,0]]);
 const r=new NativeMessageReader(1),p=packets[1];r.setReadMessage(p.subarray(3),p.length-3,0xffffffff,1);assert.equal(r.readWord(),42);
 packets.length=0;await NetworkGameSession.prototype.playEmote.call(owner,{...input,voice:65535});assert.equal(packets.length,1);assert.equal(actor.id,0xffffffff);
 await assert.rejects(NetworkGameSession.prototype.playEmote.call(owner,{...input,actorId:2}),/old controlled/);await assert.rejects(NetworkGameSession.prototype.playEmote.call(owner,{...input,voice:65536}),/old controlled/);
});
