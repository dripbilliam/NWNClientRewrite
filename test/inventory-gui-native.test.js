import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createInventoryLastUpdate,createInventoryGUI,setOpenInventory,setInventoryGUIOpen,openPlaceableInventory,closePlaceableInventoryForPlayer,receivePlaceableInventoryEvent} from '../src/inventory_gui.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-inventory-gui-observations.json',import.meta.url)));
const luoView=o=>({...o,...Object.fromEntries(['list90','listA0','listB0','listB8'].map(name=>[name,o[name].length]))});
const guiView=o=>({...o,lastUpdate:luoView(o.lastUpdate)});
function state(c){
 const make=name=>({field8:c.oldOpen??0,fieldC:7,ownerId:100,openInventory:{id:c[name==='primary'?'primaryId':'alternateId']??OBJECT_INVALID,field4:c.field4??1,field8:7},lastUpdate:{
  items:Array.from({length:18},(_,i)=>200+i),itemFields:Array.from({length:18},(_,i)=>7+i),field98:555,dirtyA8:0,...Object.fromEntries(['list90','listA0','listB0','listB8'].map(list=>[list,Array.from({length:c.listCount??2},(_,i)=>`${name}:${list}:${i}`)])),
 }});
 const primary=make('primary'),alternate=make('alternate'),calls=[],client={primary,alternate},object={objectType:c.type??9},p={
  releaseEntry:value=>calls.push(['release',value]),primary:c=>c.primary,alternate:c=>c.alternate,
  lookup:id=>{calls.push(['lookup',id]);return{status:c.status??0,object};},
  asItem:o=>{calls.push(['asItem']);return o;},asPlaceable:o=>{calls.push(['asPlaceable']);return o;},
  closeItem:(_o,id,flag)=>calls.push(['closeItem',id,flag]),closePlaceable:(_o,id,flag)=>calls.push(['closePlaceable',id,flag]),
  client:id=>{calls.push(['client',id]);return c.client===false?null:client;},clientObject:()=>{calls.push(['controlled']);return c.controlled===false?null:{id:100};},
  setOwner:(owner,_client,id,open)=>{calls.push(['setOwner',id,open]);Object.assign(owner,{id,field4:open,field8:0});},
  setOpen:(gui,value,notify)=>{calls.push(['setOpen',value,notify]);gui.field8=value;},guiMessage:(_c,id,value)=>calls.push(['gui',id,value]),inventoryStatus:(_c,value,id)=>calls.push(['status',value,id]),
  enqueue:(caller,target,id,payload)=>calls.push(['event',caller,target,id,payload.type]),animation:(_o,value)=>calls.push(['animation',value]),
 };
 return{primary,alternate,client,calls,p};
}
test('inventory GUI and retained-update constructors match original18 slots, four lists, flags and owners',()=>{
 for(const row of data.constructors){if(row.case.mode==='luoCtor')assert.deepEqual(luoView(createInventoryLastUpdate()),row.luo);else assert.deepEqual(guiView(createInventoryGUI()),row.primary);}
 assert.equal(data.constructors.length,2);
});
test('retained inventory owner setter matches original primary-before-alternate reset and same-ID semantics',async()=>{
 for(const row of data.owners){
  const c=row.case,s=state(c),owner=c.owner==='detached'?{id:c.previous}:s[c.owner].openInventory;owner.id=c.previous;
  await setOpenInventory(owner,c.client?s.client:null,c.id,c.open,s.p);const label=JSON.stringify(c);
  assert.deepEqual(s.calls,row.calls,label);assert.deepEqual(owner,row.owner,label);assert.deepEqual(guiView(s.primary),row.primary,label);assert.deepEqual(guiView(s.alternate),row.alternate,label);
 }
 assert.equal(data.owners.length,288);
});
test('inventory GUI SetOpen matches original exact notification, list resets, item/placeable closure and retained B8',async()=>{
 for(const row of data.opens){
  const c=row.case,s=state(c);await setInventoryGUIOpen(s.primary,c.value,c.notify,s.p);const label=JSON.stringify(c);
  assert.deepEqual(s.calls,row.calls,label);assert.deepEqual(guiView(s.primary),row.primary,label);assert.deepEqual(guiView(s.alternate),row.alternate,label);
 }
 assert.equal(data.opens.length,864);
});
test('placeable inventory open matches original owner replacement, first-observer event and client-absence count',async()=>{
 for(const row of data.placeableOpens){
  const c=row.case,s=state(c),o={id:99,nativeHasInventory4f8:c.hasInventory,nativeField508:c.count};await openPlaceableInventory(o,100,s.p);const label=JSON.stringify(c);
  assert.deepEqual(s.calls,row.calls,label);assert.deepEqual(guiView(s.primary),row.primary,label);assert.equal(o.nativeField508,row.count,label);
 }
 assert.equal(data.placeableOpens.length,648);
});
test('per-player placeable close matches original optional GUI closure, mismatch return and last-observer event',async()=>{
 for(const row of data.closes){
  const c=row.case,s=state(c),o={id:99,nativeHasInventory4f8:c.hasInventory,nativeField508:c.count};await closePlaceableInventoryForPlayer(o,100,c.closeGUI,s.p);const label=JSON.stringify(c);
  assert.deepEqual(s.calls,row.calls,label);assert.deepEqual(guiView(s.primary),row.primary,label);assert.equal(o.nativeField508,row.count,label);
 }
 assert.equal(data.closes.length,432);
});
test('placeable inventory observer events match original native caller cells and script indices',async()=>{
 for(const row of data.events){const c=row.case,calls=[],o={eventObjects:{},nativeLastOpenedBy520:OBJECT_INVALID,nativeLastClosedBy524:OBJECT_INVALID};
  await receivePlaceableInventoryEvent(o,c.caller,{type:c.event},{runEventScript:(_o,...args)=>calls.push(['script',...args])});
  assert.deepEqual(calls,row.calls);assert.deepEqual([o.nativeLastOpenedBy520,o.nativeLastClosedBy524],row.eventFields);assert.equal(o.eventObjects[c.event===22?'opened':'closed'],c.caller);
 }
 assert.equal(data.events.length,8);
});
