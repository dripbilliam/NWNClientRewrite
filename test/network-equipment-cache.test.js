import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {NetworkWorld} from '../src/network_world.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {clientEquipmentItem,setClientEquipmentSlot} from '../src/network_equipment_cache.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
const target='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const actorId=0xffffffff,itemId=0x80000002,otherId=0x80000003,areaId=0x80000001;
const add=(id=itemId,slot=2)=>({action:'inventory',channel:'I',operation:'A',slot,id,item:{baseItem:16,name:{text:'Robe'},canUse:1}});
const ack=(operation='unequip',extra={})=>({kind:'inventory-result',operation,success:true,alternate:0,itemId,...extra});
function fixture(){const world=new NetworkWorld();world.localObjectId=actorId;world.areaId=areaId;world.applyObjectUpdates([{action:'appearance',id:actorId,objectType:5,state:{equipment:[{action:'A',slot:2,id:itemId,item:{baseItem:16,canUse:1}}]}},add()]);return world;}

test('private equipment setter follows108 executed original attachment branches including shared hands',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-quickbar-equipment-cache-observations-v1.json',import.meta.url)));assert.equal(oracle.target,target);assert.equal(oracle.attachment.length,108);
 for(const row of oracle.attachment){
  const c=row.case,actor={id:actorId,objectType:5,clientEquipmentSlots:{[c.slot]:c.oldId}},items=new Map([itemId,otherId].map(id=>[id,{id,objectType:6,equipmentOwnerId:actorId}]));
  if(c.slot===16||c.slot===32)actor.clientEquipmentSlots[c.slot===16?32:16]=c.otherId;
  assert.equal(setClientEquipmentSlot(actor,c.slot,c.newId===OBJECT_INVALID?null:items.get(c.newId),id=>items.get(id)),true);
  assert.equal(clientEquipmentItem(actor,c.slot),row.slotId,JSON.stringify(c));
  assert.equal(items.get(itemId).equipmentOwnerId??OBJECT_INVALID,row.newOwner,JSON.stringify(c));
  assert.equal(items.get(otherId).equipmentOwnerId??OBJECT_INVALID,row.oldOwner,JSON.stringify(c));
 }
});

test('primary12/7 cache retirement matches all192 complete original reader cases without fabricated positions',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-quickbar-equipment-cache-observations-v1.json',import.meta.url)));assert.equal(oracle.cases.length,192);
 for(const row of oracle.cases){
  const c=row.case,world=fixture(),actor=world.registry.get(actorId),item=world.registry.get(itemId);actor.clientEquipmentSlots={[c.slot]:c.match?itemId:otherId};item.inventoryEquipmentSlot=c.slot;item.inventoryLocation={channel:'I',ownerId:actorId,slot:c.slot};world.inventories.set('I',{entries:c.widget?[{id:itemId,slot:c.slot}]:[]});
  const location=structuredClone(item.inventoryLocation);world.apply(ack('unequip',{alternate:c.alternate,success:c.success}));
  // Associate/alternate ownership is intentionally unresolved in this adapter.
  const nativeRetired=!c.alternate&&row.cachedGuiSlot===-1&&c.slot!==-1;
  assert.equal(item.inventoryEquipmentSlot,nativeRetired?-1:c.slot,JSON.stringify(c));
  assert.deepEqual(item.inventoryLocation,location);assert.equal(world.inventories.has('R'),false);
  const removed=!c.alternate&&row.calls.some(call=>call.kind==='equipment-set');
  assert.equal(clientEquipmentItem(actor,c.slot),c.slot===-1||removed?OBJECT_INVALID:c.match?itemId:otherId,JSON.stringify(c));
  assert.equal(item.equipmentOwnerId,removed?null:actorId,JSON.stringify(c));
 }
});

test('GI widget deletion and closed-view acknowledgment retain canonical object identity and separate attachment state',()=>{
 const world=fixture(),actor=world.registry.get(actorId),item=world.registry.get(itemId),before=world.registry.objects.size;
 world.applyObjectUpdates([{action:'inventory',channel:'I',operation:'D',slot:2}]);
 assert.equal(item.inventoryLocation,null);assert.equal(item.inventoryEquipmentSlot,2);assert.equal(item.equipmentOwnerId,actorId);assert.equal(clientEquipmentItem(actor,2),itemId);
 assert.equal(world.apply(ack()),true);assert.equal(world.registry.get(itemId),item);assert.equal(world.registry.get(actorId),actor);assert.equal(world.registry.objects.size,before);assert.equal(item.equipmentOwnerId,null);assert.equal(clientEquipmentItem(actor,2),OBJECT_INVALID);assert.deepEqual(actor.appearance.equipment,[]);assert.equal(world.inventories.has('R'),false);
 const after=structuredClone([...world.registry.objects]);assert.equal(world.apply(ack()),false);assert.deepEqual([...world.registry.objects],after);
});

test('closed GUI result marks last disclosed I location, then current R disclosure replaces provenance',()=>{
 const world=fixture(),item=world.registry.get(itemId);assert.equal(world.apply(ack()),true);assert.deepEqual(item.inventoryLocation,{channel:'I',ownerId:actorId,slot:2});assert.equal(item.inventoryLocationStatus,'last-disclosed');assert.deepEqual(world.inventories.get('I').entries,[]);
 world.applyObjectUpdates([{action:'inventory',channel:'R',operation:'A',id:itemId,x:4,y:5,item:{baseItem:16,canUse:1}}]);assert.equal(item.inventoryLocationStatus,'current');assert.deepEqual(item.inventoryLocation,{channel:'R',ownerId:actorId,x:4,y:5});
});

test('matching native equipment results never mutate absent, removed, foreign, displaced or alternate items',()=>{
 for(const kind of ['absent','removed','actor-removed','foreign','displaced','alternate','failed','unknown-slot']){
  const world=fixture(),item=world.registry.get(itemId),actor=world.registry.get(actorId);let result=ack();
  if(kind==='absent')result.itemId=0x800000ff;if(kind==='removed')item.replicationRemoved=true;if(kind==='actor-removed')actor.replicationRemoved=true;if(kind==='foreign')item.equipmentOwnerId=otherId;if(kind==='displaced')actor.clientEquipmentSlots[2]=otherId;if(kind==='alternate')result.alternate=1;if(kind==='failed')result.success=false;if(kind==='unknown-slot')item.inventoryEquipmentSlot=3;
  const objects=structuredClone([...world.registry.objects]),inventories=structuredClone(world.inventories);assert.equal(world.apply(result),false,kind);assert.deepEqual([...world.registry.objects],objects,kind);assert.deepEqual(world.inventories,inventories,kind);
 }
});

test('GI and GE source updates are transactional and displaced slots detach only their actual old item',()=>{
 const world=fixture(),item=world.registry.get(itemId),before=structuredClone([...world.registry.objects]),views=structuredClone(world.inventories);
 assert.throws(()=>world.applyObjectUpdates([add(otherId),{action:'create',id:actorId,objectType:10,state:{}}]),/Conflicting/);assert.deepEqual([...world.registry.objects],before);assert.deepEqual(world.inventories,views);
 world.applyObjectUpdates([add(otherId)]);assert.equal(item.equipmentOwnerId,null);assert.equal(world.registry.get(otherId).equipmentOwnerId,actorId);assert.equal(clientEquipmentItem(world.registry.get(actorId),2),otherId);
 world.applyObjectUpdates([{action:'appearance',id:actorId,objectType:5,state:{equipment:[{action:'D',id:OBJECT_INVALID,slot:2}]}}]);assert.equal(world.registry.get(otherId).equipmentOwnerId,null);assert.equal(clientEquipmentItem(world.registry.get(actorId),2),OBJECT_INVALID);
});

test('received12/1 attaches known canonical items after unequip without claiming fresh GUI slot or R coordinates',()=>{
 const world=fixture(),actor=world.registry.get(actorId),item=world.registry.get(itemId);world.apply(ack());const location=structuredClone(item.inventoryLocation);
 assert.equal(world.apply(ack('equip',{slot:2})),true);assert.equal(item.inventoryEquipmentSlot,-1);assert.equal(item.equipmentOwnerId,actorId);assert.equal(clientEquipmentItem(actor,2),itemId);assert.deepEqual(item.inventoryLocation,location);assert.equal(world.inventories.has('R'),false);assert.equal(actor.appearance.equipment[0].id,itemId);
 const before=structuredClone([...world.registry.objects]);assert.equal(world.apply(ack('equip',{slot:1})),false);assert.deepEqual([...world.registry.objects],before);
});

test('real item admission sends exact native actions and only decoded original result changes equipped state',async()=>{
 const world=fixture(),sent=[],actor=world.registry.get(actorId),owner={world,controlledActor:(area,generation)=>{assert.equal(area,areaId);assert.equal(generation,3);return actor;},peer:{sendGameMessage:async packet=>sent.push(packet)}},request={areaId,areaGeneration:3,itemId,operation:'unequip'};
 const before=structuredClone([...world.registry.objects]);await NetworkGameSession.prototype.itemAction.call(owner,request);assert.deepEqual([...world.registry.objects],before);assert.deepEqual([...sent[0].subarray(0,3)],[112,12,7]);
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-quickbar-equipment-cache-observations-v1.json',import.meta.url))),row=oracle.cases.find(row=>row.case.format===1&&row.case.success&&row.case.slot===2&&row.case.match&&!row.case.alternate&&!row.case.widget),decoded=decodeServerGameMessage(Buffer.from(row.packet,'hex'));
 assert.deepEqual([decoded.kind,decoded.itemId,decoded.operation,decoded.success],['inventory-result',itemId,'unequip',true]);world.apply(decoded);assert.equal(world.registry.get(itemId).equipmentOwnerId,null);assert.equal(clientEquipmentItem(actor,2),OBJECT_INVALID);
 await assert.rejects(NetworkGameSession.prototype.itemAction.call(owner,request),/equipped item/);assert.equal(sent.length,1);
 await NetworkGameSession.prototype.itemAction.call(owner,{...request,operation:'equip',slot:2});assert.deepEqual([...sent[1].subarray(0,3)],[112,12,1]);assert.equal(world.registry.get(itemId).equipmentOwnerId,null);
 world.registry.get(itemId).replicationRemoved=true;await assert.rejects(NetworkGameSession.prototype.itemAction.call(owner,{...request,operation:'equip',slot:2}),/unavailable/);assert.equal(sent.length,2);
});

test('early GI disclosure never constructs a missing controlled creature or binds an unknown owner',()=>{
 for(const controlled of [OBJECT_INVALID,actorId]){const world=new NetworkWorld();world.localObjectId=controlled;world.applyObjectUpdates([add()]);assert.equal(world.registry.objects.size,1);assert.equal(world.registry.get(controlled),undefined);assert.equal(world.registry.get(itemId).inventoryEquipmentSlot,2);assert.equal(world.registry.get(itemId).equipmentOwnerId,undefined);}
});
