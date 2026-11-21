import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveItemInput} from '../src/item_input.js';
test('native player item input matches optional fields, gates, return0 and rejection feedback',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-input-observations.json',import.meta.url)));
 for(const row of oracle.rows){const c=row.case,calls=[],actor={nativeField8ac:c.field8ac??0,areaId:c.areaId??7};let overflow=0,objectRead=0,byte=0,boolean=0,axis=0;
  const p={clientObject:()=>{calls.push(['clientObject']);return c.object===false?null:{};},asCreature:()=>{calls.push(['asCreature']);return c.creature===false?null:actor;},
   overflow:()=>{calls.push(['overflow']);return Number((c.overflow??0)===++overflow);},underflow:()=>{calls.push(['underflow']);return c.underflow??0;},
   readObjectId:()=>{calls.push(['readObjectId']);return objectRead++===0?c.itemId??55:c.targetId??100;},readByte:()=>{calls.push(['readByte']);return byte++===0?c.propertyIndex??0:c.variant??3;},
   readBool:()=>{calls.push(['readBool']);return[c.hasVariant??0,c.hasTarget??1,c.hasPoint??0][boolean++];},readFloat:()=>{calls.push(['readFloat']);return[1.25,2.5,3.75][axis++];},
   actionManager:(_o,n)=>calls.push(['actionManager',n]),use:(_o,...a)=>{calls.push(['use',...a]);return c.useResult??1;},feedback:(_o,n)=>calls.push(['feedback',n])};
  assert.equal(await receiveItemInput(null,p),row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
