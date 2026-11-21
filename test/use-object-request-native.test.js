import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveUseObjectInput,scriptInteractObject} from '../src/use_object.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-use-object-request-observations.json',import.meta.url)));
test('full client UseObject input matches original scalar reads, actor veto, popup write, notification ordering and independent acceptance',async()=>{
 for(const row of data.inputs){const c=row.case,calls=[],actor={id:99,nativeField8ac:c.field8ac??0},gui={openInventory:{field4:7}};let overflow=0,boolean=0;
  const result=await receiveUseObjectInput({}, {
   clientObject:()=>{calls.push(['clientObject']);return c.object===false?null:{};},asCreature:()=>{calls.push(['asCreature']);return c.creature===false?null:actor;},
   overflow:()=>{calls.push(['overflow']);return Number((c.overflow??0)===++overflow);},underflow:()=>{calls.push(['underflow']);return c.underflow??0;},readObjectId:()=>{calls.push(['readObjectId']);return c.targetId??100;},readBool:()=>{calls.push(['readBool']);return boolean++===0?c.popup??0:c.notify??0;},primary:()=>gui,
   event:(id,caller,target,payload)=>calls.push(['event',id,caller,target,payload.type]),actionManager:(o,n)=>calls.push(['actionManager',o.id,n]),addUse:(o,id)=>{calls.push(['use',o.id,id]);return c.addResult??1;},
  });
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(gui.openInventory.field4,row.field4);
 }
 assert.equal(data.inputs.length,201);
});
test('script ActionInteractObject matches original placeable-before-creature lookup and ignored AddUse result',async()=>{
 for(const row of data.commands){const c=row.case;
  if(c.pop===0){assert.deepEqual(row.calls,[['popObject']]);assert.equal(row.result,0xfffffd81);continue;}
  const calls=[];await scriptInteractObject(99,c.targetId,{placeable:id=>{calls.push(['placeable',id]);return c.target?{id}:null;},creature:id=>{calls.push(['creature',id]);return c.actor?{id}:null;},addUse:(o,id)=>{calls.push(['use',o.id,id]);return c.addResult;}});
  assert.deepEqual(calls,row.calls.slice(1),JSON.stringify(c));assert.equal(row.result,0);
 }
 assert.equal(data.commands.length,96);
});
