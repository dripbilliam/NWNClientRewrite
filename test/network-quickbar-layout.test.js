import test from 'node:test';
import assert from 'node:assert/strict';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NetworkWorld} from '../src/network_world.js';
import {NativeMessageReader} from '../src/native_message.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';

const actorId=0x80000001,primary=0x80000002,secondary=0x80000003,previous=0x80000004;
function fixture(){
 const world=new NetworkWorld(),packets=[],actor={id:actorId,objectType:5};world.localObjectId=actorId;
 for(const [id,value]of [[actorId,actor],...[primary,secondary,previous].map(id=>[id,{id,objectType:6,replicationRemoved:false,inventoryLocation:{channel:'I',ownerId:actorId}}])])assert.equal(world.registry.addObjectAtPos(id,value).status,0);
 const owner={world,controlledActor:(area,generation)=>{assert.equal(area,4);assert.equal(generation,8);return actor;},peer:{sendGameMessage:async bytes=>packets.push(Uint8Array.from(bytes))}};
 return{world,packets,owner};
}
function itemPacket(bytes){
 assert.deepEqual([...bytes.subarray(0,3)],[112,30,2]);const r=new NativeMessageReader(1);r.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1);
 const result={index:r.readByte(),type:r.readByte(),itemId:r.readObjectIdClient(),intParam:r.readInt()},hasSecondary=r.readBool();result.secondaryItemId=hasSecondary?r.readObjectIdClient():OBJECT_INVALID;
 assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);return result;
}
test('omitted secondary item reflects the exact no-pair value already encoded on wire',async()=>{
 for(const old of [null,{type:1,itemId:previous,secondaryItemId:secondary}])for(const optional of [{},{secondaryItemId:null}]){
  const {world,packets,owner}=fixture();if(old)Object.assign(world.quickbar[35],old);
  const button={type:1,itemId:primary,intParam:0xff00ff,...optional},before=structuredClone(button);
  await NetworkGameSession.prototype.assignQuickbar.call(owner,{areaId:4,areaGeneration:8,index:35,button});
  assert.equal(packets.length,1);const encoded=itemPacket(packets[0]);assert.equal(encoded.index,35);assert.equal(encoded.itemId,primary);assert.equal(encoded.secondaryItemId,OBJECT_INVALID);assert.equal(world.quickbar[35].secondaryItemId,encoded.secondaryItemId);assert.equal(world.quickbar[35].itemId,primary);assert.deepEqual(button,before);
 }
});
test('explicit valid pair survives both protocol serialization and client-owned reflection',async()=>{
 const {world,packets,owner}=fixture(),button={type:1,itemId:primary,secondaryItemId:secondary,intParam:0xff00ff};
 await NetworkGameSession.prototype.assignQuickbar.call(owner,{areaId:4,areaGeneration:8,index:35,button});
 assert.equal(itemPacket(packets[0]).secondaryItemId,secondary);assert.equal(world.quickbar[35].secondaryItemId,secondary);
});
test('normalization does not admit zero, foreign, destroyed, failed-send or retired input',async()=>{
 for(const invalid of ['zero','foreign-primary','foreign-secondary','removed','stale-before','stale-after','send-failure']){
  const {world,packets,owner}=fixture();const before=structuredClone(world.quickbar[35]);let calls=0;
  const button={type:1,itemId:primary,intParam:0xff00ff};
  if(invalid==='zero')button.secondaryItemId=0;
  if(invalid==='foreign-primary')world.registry.get(primary).inventoryLocation.ownerId=0x800000ff;
  if(invalid==='foreign-secondary'){button.secondaryItemId=secondary;world.registry.get(secondary).inventoryLocation.ownerId=0x800000ff;}
  if(invalid==='removed')world.registry.get(primary).replicationRemoved=true;
  if(invalid.startsWith('stale')){const original=owner.controlledActor;owner.controlledActor=(...args)=>{if(++calls===(invalid==='stale-before'?1:2))throw Error('Retired scope');return original(...args);};}
  if(invalid==='send-failure')owner.peer.sendGameMessage=async()=>{throw Error('Transport refused');};
  await assert.rejects(NetworkGameSession.prototype.assignQuickbar.call(owner,{areaId:4,areaGeneration:8,index:35,button}));assert.deepEqual(world.quickbar[35],before);
  assert.equal(packets.length,invalid==='stale-after'?1:0);
 }
});
