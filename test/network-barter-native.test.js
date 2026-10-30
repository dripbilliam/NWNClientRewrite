import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {barterRequest} from '../src/network_barter.js';import {decodeServerGameMessage} from '../src/network_game_messages.js';import {NetworkWorld} from '../src/network_world.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';import {EventEmitter} from 'node:events';
const original=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-barter-wire-observations-v1.json',import.meta.url)));
test('128 original client barter packets and16 original server replies preserve IDs, coordinates and side/value ordering',()=>{
 assert.equal(original.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(original.cases.length,288);
 for(const row of original.cases.filter(v=>v.case.format===1)){
  const c=row.case,native=Buffer.from(row.packet,'hex');
  if(row.direction==='client'){const actual=Buffer.from(barterRequest(c)),used=native.at(-1)>>>5,mask=255<<(8-used)&255;assert.equal(actual.length,native.length);assert.deepEqual(actual.subarray(0,-1),native.subarray(0,-1));assert.equal(actual.at(-1)&mask,native.at(-1)&mask);}
  else{
   const expected=c.operation==='start'?{kind:'barter-start',firstId:c.firstId,secondId:c.secondId,major:35,minor:2}:c.operation==='close'?{kind:'barter-close',completed:c.value,major:35,minor:4}:{kind:'barter-'+c.operation,initiator:c.initiator,value:c.value,major:35,minor:c.operation==='lock'?8:10};assert.deepEqual(decodeServerGameMessage(native),expected);
   for(let n=3;n<native.length-1;n++)assert.throws(()=>decodeServerGameMessage(native.subarray(0,n)));
  }
 }
});
test('session barter actions validate current trade/item/lock context and never predict server membership or acceptance',async()=>{
 const sent=[],peer=new EventEmitter();peer.sendGameMessage=async bytes=>sent.push(bytes);const s=new NetworkGameSession({peer,identity:{},build:{},resources:{}});
 s.phase='playing';s.areaReadySent=true;s.areaGeneration=3;s.world.areaId=0x80000000;s.world.localObjectId=0xffffffff;
 for(const id of [0xffffffff,0x80000013])s.world.registry.addObjectAtPos(id,{id,objectType:5,areaId:s.world.areaId,playerState:{combat:{field898:27}}});
 const ctx={actorId:0xffffffff,areaId:s.world.areaId,areaGeneration:3,targetId:0x80000013};await s.barterInput({...ctx,operation:'start'});assert.equal(sent.length,1);assert.equal(s.world.barter.open,false);
 s.world.apply({kind:'barter-start',firstId:ctx.actorId,secondId:ctx.targetId});const serial=s.world.barter.serial;
 await s.barterInput({...ctx,serial,operation:'window',value:true});await s.barterInput({...ctx,serial,operation:'lock',value:true});assert.equal(s.world.barter.ownLocked,false);
 await assert.rejects(s.barterInput({...ctx,serial,operation:'accept',value:true}));await assert.rejects(s.barterInput({...ctx,serial:serial+1,operation:'lock',value:true}));
 s.world.applyObjectUpdates([{action:'inventory',channel:'R',operation:'A',id:0x80000002,x:0,y:0,item:{baseItem:22}}]);
 const item=s.world.registry.get(0x80000002),before=structuredClone(item);await s.barterInput({...ctx,serial,operation:'add',itemId:item.id,x:1,y:2});assert.deepEqual(item,before);assert.equal(s.world.inventories.get('B').entries.length,0);
 s.world.apply({kind:'barter-lock',initiator:true,value:true});await assert.rejects(s.barterInput({...ctx,serial,operation:'add',itemId:item.id}));
 s.world.apply({kind:'barter-lock',initiator:false,value:true});await s.barterInput({...ctx,serial,operation:'accept',value:true});assert.equal(s.world.barter.ownAccepted,false);
 s.world.apply({kind:'barter-lock',initiator:true,value:false});s.world.applyObjectUpdates([{action:'inventory',channel:'B',operation:'A',id:item.id,x:1,y:2,item:{baseItem:22}}]);
 await s.barterInput({...ctx,serial,operation:'remove',itemId:item.id});assert.equal(s.world.registry.get(item.id).inventoryLocation.channel,'B');
 const balance=s.world.registry.get(ctx.actorId).playerState.combat.field898;await s.transferGold({...ctx,barterSerial:serial,amount:5,placement:true,x:1,y:2});assert.equal(s.world.registry.get(ctx.actorId).playerState.combat.field898,balance);
 s.world.apply({kind:'barter-close',completed:false});await assert.rejects(s.barterInput({...ctx,serial,operation:'accept',value:true}));await s.barterInput({...ctx,serial,operation:'window',value:false});
 await assert.rejects(s.barterInput({...ctx,areaGeneration:2,serial,operation:'window',value:false}));assert.equal(s.world.registry.get(item.id).item.baseItem,22);
});
test('both native participant roles keep B as own offer, A as remote, independent authoritative flags and canonical item identity',()=>{
 for(const own of [0xffffffff,0x80000013]){
  const world=new NetworkWorld(),other=own===0xffffffff?0x80000013:0xffffffff;world.areaId=0x80000000;world.localObjectId=own;
  const initial=world.apply({kind:'barter-start',firstId:0xffffffff,secondId:0x80000013});assert.equal(initial,true);assert.equal(world.barter.partnerId,other);const serial=world.barter.serial;
  world.applyObjectUpdates([{action:'inventory',channel:'R',operation:'A',id:0x80000002,x:0,y:0,item:{baseItem:22}},{action:'inventory',channel:'B',operation:'A',id:0x80000002,x:1,y:2,item:{baseItem:22}},{action:'inventory',channel:'A',operation:'A',id:0x80000003,x:2,y:3,item:{baseItem:24}}]);
  assert.equal(world.inventories.get('R').entries.length,0);assert.equal(world.registry.get(0x80000002).inventoryLocation.ownerId,own);assert.equal(world.registry.get(0x80000003).inventoryLocation.ownerId,other);assert.equal(world.registry.objects.size,2);
  world.apply({kind:'barter-lock',initiator:world.barter.initiator,value:true});assert.equal(world.barter.ownLocked,true);assert.equal(world.barter.otherLocked,false);
  world.apply({kind:'barter-lock',initiator:!world.barter.initiator,value:true});world.apply({kind:'barter-accept',initiator:!world.barter.initiator,value:true});assert.equal(world.barter.otherAccepted,true);assert.equal(world.barter.ownAccepted,false);
  world.apply({kind:'barter-lock',initiator:world.barter.initiator,value:false});assert.equal(world.barter.otherLocked,true);assert.equal(world.barter.otherAccepted,true); // No unreceived acceptance reset is invented.
  world.apply({kind:'barter-close',completed:false});assert.equal(world.barter.open,false);assert.equal(world.inventories.has('A'),false);assert.equal(world.registry.get(0x80000002).inventoryLocation,null);assert.equal(world.registry.objects.size,2);
  world.apply({kind:'barter-lock',initiator:true,value:true});assert.equal(world.barter.open,false);world.apply({kind:'barter-start',firstId:0xffffffff,secondId:0x80000013});assert.equal(world.barter.serial,serial+1);assert.equal(world.barter.ownAccepted,false);
 }
});
