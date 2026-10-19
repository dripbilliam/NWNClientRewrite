import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeMessageReader} from '../src/native_message.js';
import {readQuickbarItemUses,applyClientItemUses,mergeNetworkItem} from '../src/network_item_uses.js';
import {NetworkWorld} from '../src/network_world.js';
const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-item-use-count-observations.json',import.meta.url)));
test('1728 complete original G/Q writer/readers agree on IDs, stack and property-use WORD state without assigning slots',()=>{
 assert.equal(f.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(f.cases.length,1728);
 for(const row of f.cases){const c=row.case,bytes=Buffer.from(row.packet,'hex').subarray(3),r=new NativeMessageReader(c.format);r.setReadMessage(bytes,bytes.length,0xffffffff,1);assert.equal(r.readChar(),71);assert.equal(r.readChar(),81);const record=readQuickbarItemUses(r);assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);assert.deepEqual(record.entries.map(v=>[v.index,v.type,v.id,v.propertyIndex,v.count]),[0,35].map(index=>[index,c.type,0xfffffffe,c.propertyIndex&255,c.missingProperty||c.cost===1||[55,80].includes(c.propertyType)?42:c.uses]));
  const item={stackSize:99,field454:99,properties:Array.from({length:8},()=>({type:c.propertyType,costValue:c.cost})),propertyUses:Array.from({length:8},(_,i)=>100+i),selectedProperty:c.propertyIndex&255};
  if(c.clientPresent)for(const entry of record.entries)applyClientItemUses(item,entry);
  assert.equal(item.stackSize,row.stack,JSON.stringify(c));assert.deepEqual(item.propertyUses,row.uses,JSON.stringify(c));assert.equal(item.selectedProperty,row.selected,JSON.stringify(c));
 }
});
test('Q updates preserve item identity and ownership and ignore missing IDs instead of allocating canonical objects',()=>{
 const world=new NetworkWorld(),o={id:0xffffffff,objectType:6,item:{field454:9},areaId:10,inventoryLocation:{ownerId:0x80000001,channel:'R'}};world.registry.addObjectAtPos(o.id,o);const cursor=[...world.registry.nextObjectId];world.applyObjectUpdates([{action:'item-use-counts',entries:[{index:3,type:9,id:o.id,propertyIndex:255,count:2},{index:0,type:1,id:0x80000009,propertyIndex:0,count:3}]}]);assert.equal(world.registry.get(o.id),o);assert.equal(o.item.stackSize,2);assert.equal(o.inventoryLocation.ownerId,0x80000001);assert.equal(world.registry.get(0x80000009),undefined);assert.deepEqual(world.registry.nextObjectId,cursor);
});
test('sparse active-item counters retain server WORD uses and update only transmitted bits across quickbar and inventory imports',()=>{
 const world=new NetworkWorld(),id=0x80000001,properties=[{type:15,costValue:2},{type:15,costValue:2}],previous={properties,propertyUses:[300,8,0,0,0,0,0,0],selectedProperty:0};
 const incoming={properties,field350:2,reserved:1,field351:[0,null,null,null,null,null,null,null],field454:1};
 const item=mergeNetworkItem(previous,incoming);assert.deepEqual(item.propertyUses,[0,8,0,0,0,0,0,0]);assert.equal(item.selectedProperty,1);assert.equal(item.properties[0].remaining,0);assert.equal(item.properties[1].remaining,1);assert.equal(previous.propertyUses[0],300);assert.equal(previous.properties[0].remaining,undefined);
 world.applyQuickbar({entries:[{index:2,button:{type:1,itemId:id},items:[{id,item:previous}]}]});const canonical=world.registry.get(id);world.applyObjectUpdates([{action:'inventory',channel:'R',operation:'A',id,x:0,y:0,item:incoming}]);assert.equal(world.registry.get(id),canonical);assert.deepEqual(canonical.item.propertyUses,item.propertyUses);assert.equal(canonical.item.selectedProperty,1);
 applyClientItemUses(canonical.item,{propertyIndex:255,count:9});assert.equal(canonical.item.stackSize,9);world.applyQuickbar({entries:[{index:2,button:{type:1,itemId:id},items:[{id,item:{...incoming,field454:3,reserved:0,field351:Array(8).fill(null)}}]}]});assert.equal(canonical.item.stackSize,3);assert.deepEqual(canonical.item.propertyUses,item.propertyUses);
});
test('real ranger replay consumes Q and recovers every object-update boundary while unrelated packet owners stay explicit',()=>{
 const report=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-item-use-replay-v43.json',import.meta.url)));assert.equal(report.updates,27);assert.deepEqual(report.unhandled,[]);assert.equal(report.uses.length,1);assert.deepEqual(report.uses[0].entries,[{index:2,type:1,id:0x80000297,propertyIndex:255,count:1},{index:3,type:1,id:0x80000291,propertyIndex:255,count:1}]);assert.equal(report.unsupported.some(([key])=>key==='30/1'),false);
});
