import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveInventoryInput,setInventoryCharacter,setInventoryPanel} from '../src/inventory_input.js';
import {createInventoryGUI} from '../src/inventory_gui.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-inventory-input-observations.json',import.meta.url)));
test('inventory input matches full original decoded status, owner routing, page routing and error returns',async()=>{
 for(const row of data.inputs){const c=row.case,calls=[],primary=createInventoryGUI(),alternate=createInventoryGUI();primary.ownerId=alternate.ownerId=100;const name=g=>g===primary?'primary':'alternate',client=c.client===false?null:{};
  const result=await receiveInventoryInput(client,c.subtype??1,{readBool:()=>{calls.push(['readBool']);return c.open??1;},readObjectId:()=>{calls.push(['readObjectId']);return c.id??99;},readByte:()=>{calls.push(['readByte',8,1]);return c.panel??1;},
   overflow:()=>{calls.push(['overflow']);return c.overflow??0;},underflow:()=>{calls.push(['underflow']);return c.underflow??0;},clientObject:()=>{calls.push(['clientObject']);return c.controlled===false?null:{id:99};},primary:()=>primary,alternate:()=>alternate,
   setOpen:(g,value,notify)=>calls.push(['setOpen',name(g),value>>>0,notify]),setCharacter:(g,id)=>{calls.push(['setCharacter',name(g),id]);g.ownerId=id;},setPanel:(g,_client,page)=>calls.push(['setPanel',name(g),page]),});
  assert.equal(result,row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual([primary.ownerId,alternate.ownerId],row.owners);
 }
});
test('inventory character owner matches original lookup order, dirty flags and encumbrance-before-commit',async()=>{
 for(const row of data.characters){const c=row.case,calls=[],gui=createInventoryGUI(),previous={id:c.old,nativeWeightDirty96c:7},next={id:c.id,nativeWeightDirty96c:8};gui.ownerId=c.old;
  await setInventoryCharacter(gui,c.id,{creature:id=>{calls.push(['creature',id]);return id===c.old?(c.previous?previous:null):(c.next?next:null);},encumbrance:(o,flag)=>{calls.push(['encumbrance',o.id,flag]);assert.equal(gui.ownerId,c.old);}});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(gui.ownerId,row.owners[0]);assert.deepEqual([previous.nativeWeightDirty96c,next.nativeWeightDirty96c],row.dirty);
 }
});
test('inventory panel matches original repeated object lookup, cast, low-byte page count and repository cache reset',async()=>{
 for(const row of data.panels){const c=row.case,calls=[],gui=createInventoryGUI();gui.fieldC=c.current??0;gui.lastUpdate.list90=[1,2];const object={objectType:c.type??5};
  await setInventoryPanel(gui,{},c.panel,{clientObjectId:()=>99,object:id=>{calls.push(['object',id]);return c.object===false?null:object;},asCreature:()=>{calls.push(['asCreature']);return c.cast===false?null:{};},repository:()=>c.repository===false?null:{width:c.width??10,height:c.height??36,boundary:c.boundary??60},releaseEntry:()=>{}});
  if(gui.lastUpdate.list90.length===0)calls.push(['clearRepository']);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(gui.fieldC,row.panel);
 }
});
