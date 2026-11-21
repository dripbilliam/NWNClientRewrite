import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {openItemInventory,closeItemInventory,receiveItemInventoryEvent} from '../src/item_inventory.js';
import {commonObjectHitPoints} from '../src/object_life_state.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-inventory-observations.json',import.meta.url)));
for(const [mode,rows]of [['open',data.opens],['close',data.closes]])test(`item inventory ${mode} matches full original owner routing, observer/event and GUI call ordering`,async()=>{
 for(const row of rows){const c=row.case,calls=[],item={id:100,baseItem:7,possessorId:c.possessor??99,nativeInventoryObservers364:c.count??0},primary={field8:c.openFlag??0,ownerId:99,openInventory:{id:c.primaryId??0x7f000000,field4:c.field4??1,field8:7}},alternate={field8:c.openFlag??0,ownerId:c.alternateOwner??101,openInventory:{id:c.alternateId??0x7f000000,field4:c.field4??1,field8:7}},name=g=>g===primary||g===primary.openInventory?'primary':'alternate';
  const p={baseInfo:o=>{calls.push(['baseInfo',o.baseItem]);return{container:c.container??1};},client:id=>{calls.push(['client',id]);return c.client===false?null:{};},primary:()=>primary,alternate:()=>alternate,clientObject:()=>{calls.push(['clientObject']);return c.controlled===false?null:{id:99};},lookup:id=>{calls.push(['lookup',id]);return{status:c.status??0,object:{objectType:c.type??9}};},
   asItem:o=>{calls.push(['asItem']);return c.cast===false?null:o;},asPlaceable:o=>{calls.push(['asPlaceable']);return c.cast===false?null:o;},closeItem:(_o,id,flag)=>calls.push(['closeItem',id,flag]),closePlaceable:(_o,id,flag)=>calls.push(['closePlaceable',id,flag]),
   setOwner:(g,_client,id,flag)=>{calls.push(['setOwner',name(g),id,flag]);Object.assign(g,{id,field4:flag,field8:0});},setOpen:(g,value,notify)=>{calls.push(['setOpen',name(g),value,notify]);g.field8=value;},guiMessage:(_client,id,flag)=>calls.push(['gui',id,flag]),inventoryStatus:(_client,value,id)=>calls.push(['status',value,id]),enqueue:(caller,target,event,payload)=>calls.push(['event',caller,target,event,payload.type])};
  if(mode==='open')await openItemInventory(item,99,p);else await closeItemInventory(item,99,c.closeGUI??1,p);
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(item.nativeInventoryObservers364,row.count);assert.deepEqual([primary,alternate].map(g=>({field8:g.field8,id:g.openInventory.id,field4:g.openInventory.field4,field8owner:g.openInventory.field8})),row.guis);
 }
});
test('item event10 ignores script payloads, matching the full original handler without placeable callbacks',()=>{
 for(const row of data.events){receiveItemInventoryEvent({eventId:10,payload:{type:row.case.event}});assert.deepEqual(row.calls,[]);}
});
test('common item HP getters match original WORD arithmetic, signed result and exact temporary exclusion flag',()=>{
 for(const row of data.hps)assert.equal(commonObjectHitPoints({nativeBaseHPE0:row.base,nativeMaxHPE4:row.base,nativeTemporaryHPE8:row.temp},row.maximum,row.flag),row.result,JSON.stringify(row));
});
