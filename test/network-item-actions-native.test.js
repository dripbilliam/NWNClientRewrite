import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import {equipItemRequest,dropItemRequest,pickupItemRequest,unequipItemRequest,moveItemRequest,toggleItemEquipmentRequest} from '../src/network_player_requests.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {openLocalModule} from '../scripts/local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
const load=n=>JSON.parse(fs.readFileSync(new URL(`../backups/animations/${n}.json`,import.meta.url))),target='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const encode={equip:equipItemRequest,drop:dropItemRequest,pickup:pickupItemRequest,unequip:unequipItemRequest,move:moveItemRequest};
async function replay(version){const report=load(`local-network-renderer-v${version}`),install=path.resolve('../FullDecomp/NwnRootInstall'),res=installedNetworkResources({install}),rules=await loadNetworkObjectRules(await openLocalModule(install,await res.findFile('nwm','Prelude','nwm'))),world=new NetworkWorld(),messages=[];for(const hex of report.wireMessages){const m=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(m);if(m.kind==='object-updates')assert.equal(m.complete,true);messages.push(m);}return{report,world,messages};}
test('195 original item senders/server dispatch executions match item action codecs and queued boundaries',()=>{
 const f=load('native-network-item-actions-observations');assert.equal(f.target,target);assert.equal(f.cases.length,195);
 for(const row of f.cases.filter(v=>v.case.format===1)){
  const c=row.case,p=encode[c.kind](c),native=Buffer.from(row.packet,'hex'),used=native.at(-1)>>>5,mask=(255<<(8-used))&255;
  assert.equal(p.length,native.length);assert.deepEqual(Buffer.from(p.subarray(0,-1)),native.subarray(0,-1));assert.equal(p.at(-1)&mask,native.at(-1)&mask);
  const queued=row.calls.find(v=>v.kind===c.kind),cancel=row.calls.find(v=>v.kind==='cancel');
  const blocked=c.badCast||c.missingItem&&['equip','unequip','move'].includes(c.kind)||c.kind==='equip'&&(c.cursed&&c.ownerId!==99||c.slotMask===0||c.badAssociate)||c.kind==='unequip'&&c.badAssociate;
  if(blocked){assert.equal(queued,undefined);assert.equal(cancel.action,c.kind);continue;}
  assert.ok(queued,JSON.stringify(c));assert.equal(queued.itemId,c.itemId&0x7fffffff);
  if(c.kind==='equip'){assert.equal(queued.slot,c.slot);assert.equal(queued.actor,c.destinationId===0x80000013?'associate':'self');assert.equal(queued.flag0,c.destinationId===0x80000013?1:0);}
  if(c.kind==='drop')assert.deepEqual(queued.position,[...c.position.slice(0,2),Math.fround(Math.fround(c.position[2])+Math.fround(.1))]);
  if(['pickup','unequip','move'].includes(c.kind)){assert.equal(queued.destinationId,c.destinationId&0x7fffffff);assert.equal(queued.x,c.x);assert.equal(queued.y,c.y);}
  if(c.actionResult===0&&['drop','unequip','move'].includes(c.kind))assert.equal(cancel.action,c.kind);
 }
 for(const fn of Object.values(encode))for(const itemId of [-1,2**32,NaN])assert.throws(()=>fn({itemId,position:[0,0,0],slot:16}));
 assert.throws(()=>equipItemRequest({itemId:1,slot:NaN}));assert.throws(()=>dropItemRequest({itemId:1,position:[0,Infinity,0]}));assert.throws(()=>moveItemRequest({itemId:1,x:256}));
});

test('240 original success/cancel writers and complete native client readers agree on inventory result envelopes',()=>{
 const f=load('native-network-item-results-observations');assert.equal(f.target,target);assert.equal(f.cases.length,240);
 for(const row of f.cases.filter(v=>v.case.format===1)){
  const c=row.case,result=decodeServerGameMessage(Buffer.from(row.packet,'hex'));
  assert.equal(result.kind,'inventory-result');assert.equal(result.major,12);assert.equal(result.itemId,c.itemId===0x7f000000?c.itemId:(c.itemId|0x80000000)>>>0);assert.equal(result.alternate,c.alternate);assert.equal(result.operation,c.operation.replace('-cancel',''));assert.equal(result.success,!c.operation.endsWith('-cancel'));if(result.operation==='equip')assert.equal(result.slot,c.slot);assert.equal(row.result,1);assert.deepEqual(row.lookups,[c.alternate?'alternate':'primary']);
  assert.throws(()=>decodeServerGameMessage(Buffer.from(row.packet,'hex').subarray(0,-1)));
 }
});

test('258 original equipment toggles preserve optional paired IDs and leave slot/unequip decisions to the server',()=>{
 const f=load('native-network-item-toggle-observations');assert.equal(f.target,target);assert.equal(f.cases.length,258);
 for(const row of f.cases.filter(v=>v.case.format===1)){
  const c=row.case,p=toggleItemEquipmentRequest({itemId:0x80000002,secondId:c.secondId}),native=Buffer.from(row.packet,'hex'),used=native.at(-1)>>>5,mask=(255<<(8-used))&255;
  assert.equal(p.length,native.length);assert.deepEqual(Buffer.from(p.subarray(0,-1)),native.subarray(0,-1));assert.equal(p.at(-1)&mask,native.at(-1)&mask);
  if(c.missing||c.absent){assert.deepEqual(row.calls,[]);continue;}
  const unequip=Boolean(c.slot&&(c.mask&c.slot)&&(c.secondId===0x7f000000||c.slot===16)&&(c.secondId===0x7f000000||c.secondSlot));
  assert.equal(row.calls.some(v=>v.kind==='unequip'),unequip);
  for(const v of row.calls){assert.equal(v.flag0,1);assert.equal(v.flag1,0);assert.equal(v.sourceId,0x7f000000);if(v.kind==='equip'&&v.itemId===2)assert.equal(v.slot,c.wield&&(c.mask&16)?16:Array.from({length:18},(_,i)=>1<<i).find(v=>c.mask&v));}
 }
});

test('real vanilla equipment cycle moves items through native GUI events and preserves the invalid-slot rejection',async()=>{
 const {report,messages,world}=await replay(22);assert.equal(report.failure,undefined);assert.equal(report.sampleFailure,undefined);assert.equal(report.itemActions.length,8);assert.equal(report.renderer.state.phase,'playing');
 const results=messages.filter(m=>m.kind==='inventory-result');assert.deepEqual(results.map(m=>[m.operation,m.success]),[['unequip',true],['equip',true],['equip',true],['unequip',true],['move',true],['equip',false],['equip',true],['unequip',true]]);
 assert.equal(world.inventories.get('I').entries.length,3);assert.equal(world.inventories.get('R').entries.length,5);const initial=report.samples.find(s=>s.inventory).inventory,final=report.samples.at(-1).inventory;assert.deepEqual(initial.equipment.map(i=>[i.id,i.slot]).sort(),final.equipment.map(i=>[i.id,i.slot]).sort());assert.deepEqual(initial.backpack.map(i=>i.id).sort(),final.backpack.map(i=>i.id).sort());assert.deepEqual(final.pending,[]);
 const diagnostics=load('local-network-renderer-v22-diagnostics');assert.equal(diagnostics.some(d=>d.severity==='error'||/invalid|record-unhandled|inventory.*failed/.test(d.code)),false);
});

test('captured inventory-to-world A/type6 reattaches the existing item ID; NPC appearance items remain nonspatial',async()=>{
 const {report,world,messages}=await replay(23),id=report.itemActions[0].itemId,item=world.registry.get(id);assert.equal(item.areaId,world.areaId);assert.equal(item.inventoryLocation,null);assert.equal(item.equipmentOwnerId,null);assert.ok(item.replicated.position[2]>.09&&item.replicated.position[2]<.11);assert.equal(world.inventories.get('R').entries.some(e=>e.id===id),false);assert.ok(messages.some(m=>m.records?.some(r=>r.action==='create'&&r.objectType===6&&r.id===id)));
 const npc=[...world.registry.objects.values()].find(o=>o.objectType===5&&o.id!==world.localObjectId);for(const e of npc.appearance.equipment){const held=world.registry.get(e.id);assert.equal(held.areaId,0x7f000000);assert.equal(held.equipmentOwnerId,npc.id);}
});

test('native equipment slot clears can carry OBJECT_INVALID without creating an invalid item proxy',()=>{
 const world=new NetworkWorld(),id=0x80000001,itemId=0x80000002;world.applyObjectUpdates([{action:'appearance',id,objectType:5,state:{equipment:[{action:'A',id:itemId,slot:16,item:{baseItem:22}}]}}]);const item=world.registry.get(itemId);assert.equal(item.equipmentOwnerId,id);
 world.applyObjectUpdates([{action:'appearance',id,objectType:5,state:{equipment:[{action:'D',id:0x7f000000,slot:16},{action:'D',id:0x7f000000,slot:32}]}}]);assert.equal(world.registry.get(itemId),item);assert.equal(item.equipmentOwnerId,null);assert.equal(world.registry.get(0x7f000000),undefined);assert.deepEqual(world.registry.get(id).appearance.equipment,[]);
});

test('real radial/drag/drop/pickup cycle keeps one canonical server item ID and returns it to the backpack',async()=>{
 const {report,messages,world}=await replay(25);assert.equal(report.failure,undefined);assert.equal(report.sampleFailure,undefined);assert.equal(report.renderer.state.phase,'playing');assert.equal(report.itemActions.length,6);const id=report.itemActions[0].itemId;assert.equal(report.itemActions.every(a=>a.itemId===id),true);
 const results=messages.filter(m=>m.kind==='inventory-result');assert.deepEqual(results.map(m=>[m.itemId,m.operation,m.success]),['equip','unequip','equip','unequip','drop','pickup'].map(op=>[id,op,true]));assert.equal(world.registry.get(id).inventoryLocation.channel,'R');assert.equal(world.registry.get(id).areaId,0x7f000000);assert.equal(world.inventories.get('I').entries.length,3);assert.equal(world.inventories.get('R').entries.length,5);assert.deepEqual(report.samples.at(-1).inventory.pending,[]);
 const during=report.samples.filter(s=>s.at>report.itemActions[4].at&&s.at<report.itemActions[5].at).find(s=>s.server.items.some(i=>i.id===id&&i.areaId===s.server.areaId&&!i.location));assert.ok(during);const diagnostics=load('local-network-renderer-v25-diagnostics');assert.equal(diagnostics.some(d=>d.severity==='error'||/invalid|record-unhandled|inventory.*failed/.test(d.code)),false);assert.equal(diagnostics.filter(d=>d.code==='network.scene-ground-item-unhandled').length,1);
});

test('final renderer grid, native page changes and server-owned toggle/drop/pickup cycle retain all item IDs',async()=>{
 const {report,messages,world}=await replay(26);assert.equal(report.failure,undefined);assert.equal(report.sampleFailure,undefined);assert.equal(report.renderer.state.phase,'playing');assert.equal(report.itemActions.length,5);assert.deepEqual(report.inventoryPanels.map(v=>v.page),[1,0]);
 const results=messages.filter(m=>m.kind==='inventory-result');assert.deepEqual(results.map(m=>[m.operation,m.success]),['move','equip','unequip','drop','pickup'].map(op=>[op,true]));const id=report.itemActions[0].itemId;assert.equal(report.itemActions.every(v=>v.itemId===id),true);
 const otherPage=report.samples.find(s=>s.inventory?.page===1),final=report.samples.at(-1).inventory;assert.ok(otherPage);assert.equal(final.page,0);assert.equal(final.equipment.length,3);assert.equal(final.backpack.length,5);assert.deepEqual(final.pending,[]);assert.equal(world.registry.get(id).inventoryLocation.channel,'R');const first=report.samples.find(s=>s.inventory).inventory;assert.deepEqual(first.backpack.map(v=>v.id).sort(),final.backpack.map(v=>v.id).sort());assert.ok(final.backpack.every(v=>v.width>0&&v.height>0));
 const diagnostics=load('local-network-renderer-v26-diagnostics');assert.equal(diagnostics.some(d=>d.severity==='error'||/invalid|record-unhandled|inventory.*failed/.test(d.code)),false);assert.equal(diagnostics.filter(d=>d.code==='network.scene-ground-item-unhandled').length,1);
});

test('native page buttons change actual visible item nodes while retaining the server item cache',()=>{
 const report=load('local-network-renderer-v27');assert.equal(report.failure,undefined);assert.equal(report.sampleFailure,undefined);assert.equal(report.renderer.state.phase,'playing');assert.deepEqual(report.inventoryPanels.map(v=>v.page),[1,0]);const first=report.samples.find(s=>s.inventory),empty=report.samples.find(s=>s.inventory?.page===1),last=report.samples.at(-1);assert.equal(first.inventoryVisible.length,5);assert.equal(empty.inventory.backpack.length,5);assert.deepEqual(empty.inventoryVisible,[]);assert.deepEqual([...last.inventoryVisible].sort(),[...first.inventoryVisible].sort());assert.equal(last.inventory.page,0);
});
