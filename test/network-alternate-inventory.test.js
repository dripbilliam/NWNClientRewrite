import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import fs from 'node:fs';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {inventoryWindowRequest,inventoryPanelRequest} from '../src/network_player_requests.js';
const INVALID=0x7f000000,PC=0xffffffff,NPC=0x80000002,OTHER=0x80000003,AREA=0x80000004;
function world(){const w=new NetworkWorld();w.localObjectId=PC;w.areaId=AREA;for(const id of [PC,NPC,OTHER])w.registry.addObjectAtPos(id,{id,objectType:5,areaId:AREA});return w;}
const status=(w,ownerId,open=true)=>w.apply({kind:'inventory-window-status',ownerId,open});
function harness(){const peer=new EventEmitter(),sent=[],s=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision:37,postfix:17},dispose(){}},resources:{},decodeMessage:m=>m});peer.sendGameMessage=async packet=>{sent.push([...packet]);};peer.disconnect=async()=>{};s.world=world();s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;return{s,peer,sent};}
function request(w){const b=w.inventoryWindows.alternate;return{areaId:AREA,areaGeneration:2,inventoryRole:'alternate',ownerId:b.ownerId,windowSerial:b.serial,inventoryReceipt:b.receiptSerial};}
test('actual decoder admits original13/1 separately from25/1 and rejects truncated fields',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-inventory-window-observations-v1.json',import.meta.url)));
 for(const row of oracle.cases.filter(v=>v.case.format===1)){const bytes=Buffer.from(row.packet,'hex'),d=decodeServerGameMessage(bytes);assert.deepEqual(d,{kind:'inventory-window-status',open:row.case.open!==0,ownerId:row.case.ownerId,major:13,minor:1});assert.throws(()=>decodeServerGameMessage(bytes.subarray(0,3)));}
});
test('received owners select independent primary/alternate windows; raw INVALID refresh and duplicates retain original lifetime semantics',()=>{
 const w=world();status(w,NPC);const a=w.inventoryWindows.snapshot();assert.equal(a.alternate.ownerId,NPC);assert.equal(a.alternate.open,true);assert.equal(a.primary.ownerId,INVALID);assert.equal(w.containers.size,0);
 status(w,NPC);assert.equal(w.inventoryWindows.alternate.serial,a.alternate.serial);assert.ok(w.inventoryWindows.alternate.receiptSerial>a.alternate.receiptSerial);
 status(w,INVALID);const p=w.inventoryWindows.primary.serial;assert.equal(w.inventoryWindows.primary.ownerId,PC);status(w,INVALID);assert.ok(w.inventoryWindows.primary.serial>p);const forced=w.inventoryWindows.primary.serial;status(w,PC);assert.equal(w.inventoryWindows.primary.serial,forced);
 status(w,NPC,false);const closed=w.inventoryWindows.alternate;assert.equal(closed.ownerId,NPC);assert.equal(closed.open,false);status(w,NPC,false);assert.equal(w.inventoryWindows.alternate.serial,closed.serial);assert.equal(w.inventoryWindows.primary.open,true);
});
test('lowercase inventory uses only an accepted canonical owner, never C/name/current actor or an invented creature',()=>{
 const w=world(),id=0x80000009;w.containers.set('C',OTHER);w.applyObjectUpdates([{action:'inventory',channel:'r',operation:'A',id,x:1,y:2,item:{baseItem:1}},{action:'inventory',channel:'i',state:{field8c:17}}]);assert.equal(w.registry.get(id).inventoryLocation.ownerId,null);assert.equal(w.registry.get(PC).inventoryStats,undefined);
 status(w,NPC);assert.equal(w.registry.get(id).inventoryLocation.ownerId,NPC);assert.equal(w.inventories.get('r').ownerId,NPC);assert.equal(w.registry.get(NPC).inventoryStats.field8c,17);assert.equal(w.containers.get('C'),OTHER);
 const previous=structuredClone(w.registry.get(id)),size=w.registry.objects.size;status(w,0x80000055);assert.equal(w.registry.get(0x80000055),undefined);assert.equal(w.inventoryWindows.rejected.ownerId,0x80000055);assert.deepEqual(w.registry.get(id),previous);assert.equal(w.registry.objects.size,size);
 w.registry.get(OTHER).replicationRemoved=true;status(w,OTHER);assert.equal(w.inventoryWindows.rejected.ownerId,OTHER);assert.equal(w.inventoryWindows.alternate.ownerId,NPC);
});
test('alternate owner replacement retires displayed membership without destroying items or changing attachment/equipment namespaces',()=>{
 const w=world(),id=0x80000009;status(w,NPC);w.applyObjectUpdates([{action:'inventory',channel:'i',operation:'A',id,slot:2,item:{baseItem:1}}]);const item=w.registry.get(id);item.equipmentOwnerId=NPC;item.clientEquipmentSlots=[2];const before=structuredClone(item.item);
 status(w,OTHER);assert.deepEqual(w.inventories.get('i').entries,[]);assert.equal(item.inventoryLocation.ownerId,NPC);assert.equal(item.inventoryLocationStatus,'last-disclosed');assert.equal(item.equipmentOwnerId,NPC);assert.deepEqual(item.clientEquipmentSlots,[2]);assert.deepEqual(item.item,before);assert.equal(w.inventories.get('i').ownerId,OTHER);
 w.applyObjectUpdates([{action:'inventory',channel:'r',operation:'A',id,x:2,y:3,item:{baseItem:1}}]);assert.equal(w.registry.get(id).inventoryLocation.ownerId,OTHER);assert.equal(w.registry.get(id).inventoryLocation.channel,'r');assert.equal(w.registry.get(id).inventoryLocationStatus,'current');
});
test('actual Session alternate paging sends original self=false and close retains owner with client-owned retirement only',async()=>{
 const {s,sent}=harness();status(s.world,NPC);s.world.applyObjectUpdates([{action:'inventory',channel:'r',operation:'A',id:0x80000009,x:1,y:2,item:{baseItem:1}},{action:'inventory',channel:'R',operation:'A',id:0x8000000a,x:0,y:0,item:{baseItem:1}}]);const r=request(s.world),before=structuredClone(s.world.registry.get(NPC));
 assert.deepEqual(await s.inventoryPanel({...r,panel:1}),{sent:true});assert.deepEqual(sent.at(-1),[...inventoryPanelRequest({panel:1,self:false})]);assert.equal(s.world.inventories.get('r').entries.length,0);assert.equal(s.world.inventories.get('R').entries.length,1);
 assert.deepEqual(await s.inventoryWindow({...r,open:false}),{sent:true});assert.deepEqual(sent.at(-1),[...inventoryWindowRequest({ownerId:NPC,open:false})]);assert.equal(s.world.inventoryWindows.alternate.ownerId,NPC);assert.equal(s.world.inventoryWindows.alternate.open,false);assert.equal(s.world.inventoryWindows.alternate.source,'client-close');assert.deepEqual(s.world.registry.get(NPC),before);await assert.rejects(s.inventoryPanel({...r,panel:0}),/retired/);
});
test('Session validates exact current owner, receipt, actor and area both before and after async transmission',async()=>{
 const {s,peer,sent}=harness();status(s.world,NPC);const r=request(s.world);
 for(const change of [{ownerId:OTHER},{windowSerial:r.windowSerial+1},{inventoryReceipt:r.inventoryReceipt-1},{areaGeneration:1},{areaId:AREA+1}])await assert.rejects(s.inventoryPanel({...r,panel:0,...change}));assert.equal(sent.length,0);
 let finish;peer.sendGameMessage=()=>new Promise(resolve=>{finish=resolve;});const pending=s.inventoryPanel({...r,panel:2});status(s.world,OTHER);finish();await assert.rejects(pending,/retired/);assert.equal(s.world.inventoryWindows.alternate.ownerId,OTHER);
 status(s.world,NPC);const newer=request(s.world),close=s.inventoryWindow({...newer,open:false});s.areaGeneration=3;finish();await assert.rejects(close,/not ready/);assert.equal(s.world.inventoryWindows.alternate.open,true);
});
test('failed sends and unavailable-owner replies do not forge an alternate view or consume another request lifetime',async()=>{
 const {s,peer,sent}=harness();status(s.world,NPC);const r=request(s.world),before=s.world.inventoryWindows.snapshot();peer.sendGameMessage=async()=>{throw Error('authored send failure');};await assert.rejects(s.inventoryWindow({...r,open:false}),/send failure/);assert.deepEqual(s.world.inventoryWindows.snapshot(),before);
 peer.sendGameMessage=async packet=>{sent.push([...packet]);};const absent=0x80000055;status(s.world,absent);const rejected=s.world.inventoryWindows.rejected;await assert.rejects(s.inventoryWindow({areaId:AREA,areaGeneration:2,inventoryRole:'rejected',ownerId:absent,inventoryReceipt:rejected.receiptSerial,open:true}),/retired/);
 await s.inventoryWindow({areaId:AREA,areaGeneration:2,inventoryRole:'rejected',ownerId:absent,inventoryReceipt:rejected.receiptSerial,open:false});assert.deepEqual(sent.at(-1),[...inventoryWindowRequest({ownerId:absent,open:false})]);assert.equal(s.world.inventoryWindows.rejected,null);assert.equal(s.world.registry.get(absent),undefined);assert.equal(s.world.inventoryWindows.alternate.ownerId,NPC);
});
