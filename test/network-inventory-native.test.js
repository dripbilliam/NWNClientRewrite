import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeMessageReader} from '../src/native_message.js';
import {inventoryWindowRequest,inventoryPanelRequest} from '../src/network_player_requests.js';
import {readInventoryStats} from '../src/network_inventory_stats.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {openLocalModule} from '../scripts/local-module.mjs';
const load=n=>JSON.parse(fs.readFileSync(new URL(`../backups/animations/${n}.json`,import.meta.url))),target='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const build={number:8193,revision:37,postfix:17};

test('inventory GUI encoders match original senders and full original server routing in35 cases',()=>{
 const f=load('native-network-inventory-window-observations');assert.equal(f.target,target);assert.equal(f.cases.length,35);
 for(const row of f.cases.filter(r=>r.case.format===1)){
  const c=row.case,actual=c.kind==='window'?inventoryWindowRequest(c):inventoryPanelRequest(c),native=Buffer.from(row.packet,'hex'),used=native.at(-1)>>>5,mask=(255<<(8-used))&255;
  assert.equal(actual.length,native.length);assert.deepEqual(Buffer.from(actual.subarray(0,-1)),native.subarray(0,-1));assert.equal(actual.at(-1)&mask,native.at(-1)&mask);
  if(c.noPlayer||c.noActor||c.truncate)assert.deepEqual(row.calls,[]);
 }
 for(const ownerId of [-1,2**32,NaN])assert.throws(()=>inventoryWindowRequest({ownerId,open:true}));
 assert.throws(()=>inventoryWindowRequest({ownerId:1,open:2}));for(const panel of [-1,256,NaN])assert.throws(()=>inventoryPanelRequest({panel}));
});

test('160 complete original inventory stats readers agree on scalar cells, combat nodes, build gates and record boundaries',()=>{
 const f=load('native-network-inventory-stats-observations');assert.equal(f.target,target);assert.equal(f.cases.length,160);
 for(const row of f.cases){
  const c=row.case,b=Buffer.from(row.packet,'hex').subarray(3),r=new NativeMessageReader(c.format);assert.equal(r.setReadMessage(b,b.length,0xffffffff,1),1);assert.equal(r.readChar(),71);assert.equal(r.readChar(),83);
  const record=readInventoryStats(r,{number:8193,revision:c.revision,postfix:c.postfix},{skillCount:c.skillCount}),s=record.state;assert.equal(record.id,0xffffffff);assert.equal(record.mask,c.mask);
  if(c.mask&1){for(const [base,values]of [[0x70,s.fields70],[0x7d,s.fields7d],[0x76,s.fields76]])for(const [i,v]of values.entries())assert.equal(v,row.cells[`0x${(base+i).toString(16)}`]);}
  for(const [bit,key,offset]of [[2,'field98',0x98],[4,'field99',0x99],[8,'field9a',0x9a],[16,'field94',0x94],[0x2000,'field9c',0x9c],[0x4000,'field9d',0x9d],[0x8000,'field9e',0x9e],[0x400,'field8c',0x8c],[0x800,'field88',0x88],[0x800,'field8a',0x8a]])if(c.mask&bit)assert.equal(s[key],row.cells[`0x${offset.toString(16)}`]);
  if(c.mask&32){assert.equal(s.field9b,row.cells['0x9b']);assert.equal(s.fielda0,row.cells['0xa0']);}
  if(c.mask&64){const a=row.combat[0],v=s.combatInformation;for(const offset of [0,1,2,5,6,7,8,9,0x13,0x14])assert.equal(v[`field${offset.toString(16)}`]&255,a[offset]);assert.equal(v.field18,a[0x18]);if(v.field18)for(const offset of [3,4,0x1c,0x1d])assert.equal(v[`field${offset.toString(16)}`]&255,a[offset]);assert.deepEqual([...v.group0,...v.group1].map(n=>[n.field0&255,n.field1??0,n.field2,n.field3,n.field4,n.field5]),row.nodes);}
  if(c.mask&128){for(const v of s.skills)assert.equal(v.value&255,row.skills[v.index]);assert.equal(row.cells['0xe0'],c.optional?0x8000003:2);}
  if(c.mask&256){assert.deepEqual(s.featsRemoved,row.events.filter(e=>e[0]==='remove').map(e=>e[1]));assert.deepEqual(s.featsAdded.map(v=>v.id),row.events.filter(e=>e[0]==='add').map(e=>e[1]));}
  if(c.mask&512){assert.deepEqual(s.fields118,row.events.filter(e=>e[0]==='list118').map(e=>e[1]));assert.deepEqual(s.fields128,row.events.filter(e=>e[0]==='list128').map(e=>e[1]));}
  if(c.mask&0x1000)assert.deepEqual(s.fieldsClass,row.events.filter(e=>e[0]==='class').map(e=>e[2]));
  assert.equal(r.byteCursor44,row.reader.byteCursor);assert.equal(r.curReadBit5c,row.reader.curBit);assert.equal(r.readByte(),90);assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);
 }
});

test('vanilla inventory window returns canonical equipment and backpack items without importing the BIC inventory',async()=>{
 const report=load('local-network-renderer-v20');assert.equal(report.connected,true);assert.equal(report.failure,undefined);assert.deepEqual(report.inventoryRequests.map(v=>[v.open,v.result.sent]),[[true,true],[false,true]]);
 const install=path.resolve('../FullDecomp/NwnRootInstall'),resources=installedNetworkResources({install}),rules=await loadNetworkObjectRules(await openLocalModule(install,await resources.findFile('nwm','Prelude','nwm'))),world=new NetworkWorld(),inventory=[];
 for(const hex of report.wireMessages){const d=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:build,objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(d);if(d.kind==='object-updates'){assert.equal(d.complete,true);inventory.push(...d.records.filter(r=>r.action==='inventory'));}}
 assert.equal(inventory.length,8);assert.equal(world.inventories.get('I').entries.length,3);assert.equal(world.inventories.get('R').entries.length,5);
 for(const r of inventory){const o=world.registry.get(r.id);assert.equal(o.objectType,6);assert.equal(o.areaId,0x7f000000);const {propertyUses,selectedProperty,stackSize,...wire}=structuredClone(o.item);wire.properties=wire.properties.map(({remaining,...p})=>p);assert.deepEqual(wire,r.item);assert.equal(stackSize,r.item.field454);assert.deepEqual(propertyUses,r.item.field351);assert.ok(selectedProperty===255||r.item.properties[selectedProperty]?.type===15);assert.equal(o.inventoryLocation.ownerId,world.localObjectId);}
 const before=structuredClone([...world.registry.objects]),views=structuredClone(world.inventories);
 assert.throws(()=>world.applyObjectUpdates([{action:'inventory',channel:'R',operation:'D',id:inventory[0].id},{action:'create',objectType:10,id:world.localObjectId,state:{}}]),/Conflicting/);assert.deepEqual([...world.registry.objects],before);assert.deepEqual(world.inventories,views);
});

test('inventory deltas preserve canonical IDs, separate GUI channels and remove stale slot locations',()=>{
 const diagnostics=[],world=new NetworkWorld({onDiagnostic:d=>diagnostics.push(d)}),id=0xffffffff,a=0x80001000,b=0x80001001;
 world.applyObjectUpdates([{action:'player-state',objectType:5,id,state:{}}]);
 const add=(channel,itemId,position)=>({action:'inventory',channel,operation:'A',id:itemId,item:{name:{text:'Item'},field454:1},...position});
 world.applyObjectUpdates([add('I',a,{slot:16})]);const canonical=world.registry.get(a);
 world.applyObjectUpdates([add('I',b,{slot:16})]);assert.equal(world.registry.get(a),canonical);assert.equal(canonical.inventoryLocation,null);assert.deepEqual(world.inventories.get('I').entries,[{id:b,slot:16}]);
 world.applyObjectUpdates([add('R',b,{x:2,y:3}),{action:'inventory',channel:'I',operation:'D',slot:16}]);assert.deepEqual(world.inventories.get('I').entries,[]);assert.equal(world.registry.get(b).inventoryLocation.channel,'R');
 world.applyObjectUpdates([{action:'inventory',channel:'R',operation:'M',id:b,x:4,y:5},{action:'inventory',channel:'R',operation:'U',id:b,stackSize:7,field280:31}]);assert.equal(world.registry.get(b).item.stackSize,7);assert.deepEqual(world.registry.get(b).inventoryLocation,{channel:'R',ownerId:id,x:4,y:5});
 world.applyObjectUpdates([add('r',a,{x:1,y:1})]);assert.equal(canonical.inventoryLocation.ownerId,null);assert.equal(world.inventories.get('R').entries.length,1);world.applyObjectUpdates([{action:'inventory',channel:'R',operation:'D',id:b}]);assert.equal(world.registry.get(b).inventoryLocation,null);assert.equal(world.inventories.get('r').entries.length,1);
 world.applyObjectUpdates([add('A',a,{x:2,y:2}),add('A',a,{x:3,y:3}),{action:'inventory',channel:'i',operation:'U',state:{field28c:5}}]);assert.equal(world.inventories.get('A').entries.length,1);assert.equal(world.inventories.get('A').entries[0].x,3);assert.equal(world.inventories.get('i').stats.field28c,5);assert.equal(diagnostics.filter(d=>d.code==='network.inventory-owner-unavailable').length,3);
 world.applyObjectUpdates([{action:'inventory-stats',objectType:5,id,state:{skills:[{index:1,value:2,flag:1}],featsAdded:[{id:25,flag:1}]}},{action:'inventory-stats',objectType:5,id,state:{skills:[{index:1,value:3,flag:0}],featsRemoved:[25],featsAdded:[{id:101,flag:0}]}}]);assert.deepEqual(world.registry.get(id).inventoryStats.skills,[{index:1,value:3,flag:1}]);assert.deepEqual(world.registry.get(id).inventoryStats.feats,[{id:101,flag:0}]);
});

test('real inventory UI opens, closes and reopens with the same server item IDs and installed names',()=>{
 const report=load('local-network-renderer-v21');assert.equal(report.connected,true);assert.equal(report.failure,undefined);assert.equal(report.sampleFailure,undefined);assert.deepEqual(report.inventoryRequests.map(v=>[v.open,v.result.clicked]),[[true,true],[false,true],[true,true]]);
 const first=report.samples.find(s=>s.inventory)?.inventory,last=report.samples.at(-1).inventory;assert.equal(first.equipment.length,3);assert.equal(first.backpack.length,5);assert.deepEqual(last,first);assert.ok([...last.equipment,...last.backpack].every(v=>v.name&&!v.name.includes('<')&&v.stackSize>=1));assert.ok(report.samples.some(s=>s.at>report.inventoryRequests[1].at&&s.at<report.inventoryRequests[2].at&&!s.inventory));
 const diagnostics=load('local-network-renderer-v21-diagnostics');assert.equal(diagnostics.some(d=>d.level==='error'||d.severity==='error'||/invalid|record-unhandled|inventory.*failed/.test(d.code)),false);
});
