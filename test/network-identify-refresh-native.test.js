import test from 'node:test';import assert from 'node:assert/strict';import {EventEmitter} from 'node:events';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {storeRequest} from '../src/network_store.js';import {examineRequest} from '../src/network_player_requests.js';
test('original Identify callback order sends7/7 then6/5 without predicting identification or gold',async()=>{
 const sent=[],peer=new EventEmitter();peer.sendGameMessage=async packet=>sent.push(packet);
 const s=new NetworkGameSession({peer,identity:{},build:{},resources:{}});s.phase='playing';s.areaReadySent=true;s.areaGeneration=3;s.world.areaId=0x80000000;s.world.localObjectId=0xffffffff;
 const actor={id:0xffffffff,areaId:s.world.areaId,objectType:5,playerState:{combat:{field898:1000}}};
 const item={id:0x80000007,objectType:6,areaId:0x7f000000,item:{identified:false,baseItem:49},inventoryLocation:{channel:'R',ownerId:actor.id}};
 s.world.registry.addObjectAtPos(actor.id,actor);s.world.registry.addObjectAtPos(item.id,item);s.world.store={open:true,generation:7,identifyPrice:100};
 const scope={areaId:s.world.areaId,areaGeneration:3,actorId:actor.id,storeGeneration:7,operation:'identify',itemId:item.id},before=structuredClone({actor,item,store:s.world.store});
 await s.storeInput(scope);assert.equal(sent.length,2);assert.deepEqual(sent[0],storeRequest({operation:'identify',itemId:item.id}));assert.deepEqual(sent[1],examineRequest({targetId:item.id}));assert.deepEqual({actor,item,store:s.world.store},before);
 for(const change of [{actorId:item.id},{storeGeneration:6},{areaGeneration:2},{itemId:0x80000008}])await assert.rejects(s.storeInput({...scope,...change}));
 assert.equal(sent.length,2);item.inventoryLocation={channel:'M',ownerId:null};await assert.rejects(s.storeInput(scope));assert.equal(sent.length,2);
});
