import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeMessageWriter} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';

// Read-only original: GameObjectUpdate79bce0 subtype2 ->781380 ->6acc50
// writes client+48 unconditionally, before optional creature/GUI lookup.
// Party7a7440 subtype14 updates player+34 and does not call that setter.
// Full saved code/assembly: rea-loading-control-identity-v1.json. These tests
// exercise port wire/state/input paths; they do not execute the original PE.
function packet(major,minor,playerId,objectId){
 const w=new NativeMessageWriter(1);w.create(8,0xffffffff,1);
 w.setPrefix(Uint8Array.of(80,major,minor));w.writeDword(playerId);w.writeObjectIdServer(objectId);
 return w.getWriteMessage().data;
}

test('private 5/2 control selects the server object before the creature arrives',()=>{
 for(const playerId of [0,1,0xffffffff])for(const objectId of [0x80000001,0xffffffff,OBJECT_INVALID]){
  const world=new NetworkWorld(),message=decodeServerGameMessage(packet(5,2,playerId,objectId));
  assert.deepEqual(message,{kind:'object-control',major:5,minor:2,playerId,objectId});
  world.apply(message);assert.equal(world.localObjectId,objectId);assert.equal(world.controls.get(playerId),objectId);
  assert.equal(world.registry.objects.size,0,'ownership must not fabricate a player proxy');
 }
});

test('party 14/14 and full player lists cannot select the locally controlled actor',()=>{
 const world=new NetworkWorld(),own=0x80000001,other=0xffffffff;
 world.apply(decodeServerGameMessage(packet(5,2,0,own)));
 world.scriptTargeting={objectMask:1,actorId:own};const targeting=world.scriptTargeting;
 for(const playerId of [0,3,0xffffffff]){
  world.apply(decodeServerGameMessage(packet(14,14,playerId,other)));
  assert.equal(world.controls.get(playerId),other);assert.equal(world.localObjectId,own);assert.equal(world.scriptTargeting,targeting);
 }
 world.apply({kind:'player-list-all',players:[{playerId:0,objectId:other}]});
 assert.equal(world.localObjectId,own);assert.equal(world.controls.get(0),other);assert.equal(world.scriptTargeting,targeting);
 world.apply({kind:'player-list-delete',playerId:0});assert.equal(world.localObjectId,own);
});

test('control transfers invalidate old targeting and wait for actual current-area proxies',()=>{
 const world=new NetworkWorld(),areaId=0x80000001,oldId=0x80000002,newId=0xffffffff;
 const apply=id=>world.apply(decodeServerGameMessage(packet(5,2,7,id)));
 world.areaId=areaId;world.registry.addObjectAtPos(oldId,{id:oldId,objectType:5,areaId,replicated:{}});apply(oldId);
 world.scriptTargeting={objectMask:1,actorId:oldId};const targeting=world.scriptTargeting;apply(oldId);
 assert.equal(world.scriptTargeting,targeting,'a repeat is not a new control transfer');
 const session={world,closed:false,phase:'playing',areaReadySent:true,areaGeneration:3};
 const controlled=()=>NetworkGameSession.prototype.controlledActor.call(session,areaId,3);
 assert.equal(controlled().id,oldId);apply(newId);assert.equal(world.scriptTargeting,null);
 assert.throws(controlled,/not ready/);assert.equal(world.registry.objects.size,1);
 world.registry.addObjectAtPos(newId,{id:newId,objectType:5,areaId:areaId+1,replicated:{}});
 assert.throws(controlled,/not ready/);const actor=world.registry.get(newId);actor.areaId=areaId;
 assert.equal(controlled(),actor);actor.replicationRemoved=true;assert.throws(controlled,/not ready/);
 actor.replicationRemoved=false;assert.equal(controlled(),actor);
 world.apply({kind:'object-updates',records:[{action:'player-state',objectType:5,id:newId,state:{}}]});
 assert.equal(world.localObjectId,newId);assert.equal(world.registry.get(newId),actor);assert.ok(actor.playerState);
 apply(OBJECT_INVALID);assert.equal(world.localObjectId,OBJECT_INVALID);assert.throws(controlled,/not ready/);
 assert.equal(world.registry.objects.size,2);world.reset();assert.equal(world.localObjectId,OBJECT_INVALID);assert.equal(world.controls.size,0);
});

test('malformed control messages cannot partially replace local identity',()=>{
 const world=new NetworkWorld();world.apply(decodeServerGameMessage(packet(5,2,3,0xffffffff)));
 const before=world.snapshot();const bytes=packet(5,2,4,0x80000001);
 for(let size=3;size<bytes.length;size++)assert.throws(()=>world.apply(decodeServerGameMessage(bytes.subarray(0,size))));
 assert.throws(()=>world.apply(decodeServerGameMessage(Buffer.concat([bytes,Buffer.of(0)]))));
 assert.deepEqual(world.snapshot(),before);
});
