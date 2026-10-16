import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveContainerInput,stepContainerPage} from '../src/container_input.js';
import {createInventoryGUI} from '../src/inventory_gui.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-container-input-observations.json',import.meta.url)));
test('container input matches full original close-before-lookup, item possession, retained denied owner, malformed and page paths',async()=>{
 for(const row of data.inputs){const c=row.case,calls=[],gui=createInventoryGUI(),old={role:'old',objectType:c.oldType??9},target={role:'target',objectType:c.targetType??9,possessorId:c.possessor??99};Object.assign(gui.openInventory,{id:c.previous??100,field4:7,field8:c.page??2});
  const result=await receiveContainerInput({},c.subtype??1,{primary:()=>gui,readObjectId:()=>{calls.push(['readObjectId']);return c.id??200;},overflow:()=>{calls.push(['overflow']);return c.overflow??0;},underflow:()=>{calls.push(['underflow']);return c.underflow??0;},clientObject:()=>{calls.push(['clientObject']);return c.controlled===false?null:{id:99};},lookup:id=>{calls.push(['lookup',id]);return id===(c.previous??100)?{status:c.oldStatus??0,object:old}:{status:c.targetStatus??0,object:target};},
   asItem:o=>{calls.push(['asItem',o.role]);return c[`${o.role}Cast`]===false?null:o;},asPlaceable:o=>{calls.push(['asPlaceable',o.role]);return c[`${o.role}Cast`]===false?null:o;},repository:()=>c.repository===false?null:{},closeItem:(o,...args)=>calls.push(['closeItem',o.role,...args]),closePlaceable:(o,...args)=>calls.push(['closePlaceable',o.role,...args]),setOwner:(owner,_client,id,open)=>{calls.push(['setOwner',id,open]);Object.assign(owner,{id,field4:open,field8:0});},step:(_o,_c,n)=>calls.push(['step',n])});
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(gui.openInventory,row.owner,JSON.stringify(c));
 }
});
test('container page owners match original placeable-only lookup, primary cache reset and BYTE wrap/count arithmetic',async()=>{
 for(const row of data.pages){const c=row.case,calls=[],primary=createInventoryGUI(),alternate=createInventoryGUI(),owner=(c.alternate?alternate:primary).openInventory;Object.assign(owner,{id:c.previous??100,field4:7,field8:c.page??2});primary.lastUpdate.listA0=[{}];primary.lastUpdate.dirtyA8=0;alternate.lastUpdate.listA0=[{}];
  await stepContainerPage(owner,{},c.direction,{primary:()=>primary,placeable:id=>{calls.push(['placeable',id]);return c.placeable===false?null:{};},repository:()=>c.repository===false?null:{width:c.width??7,height:c.height??15,boundary:c.boundary??35},releaseEntry:()=>calls.push(['clearContainer'])});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(owner,row.owner,JSON.stringify(c));assert.equal(primary.lastUpdate.dirtyA8,Number(c.placeable!==false&&c.repository!==false));assert.equal(alternate.lastUpdate.listA0.length,1);
 }
});
