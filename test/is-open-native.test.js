import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptIsOpen,nativeDoorOpenState} from '../src/script_object_queries.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-is-open-observations.json',import.meta.url)));
test('GetIsOpen matches original casts, door cache/getter, exact placeable animation and VM boundary results',async()=>{
 for(const row of data.rows){const c=row.case,calls=[],o={nativeDoorField498:c.field498??1,nativeAnimationD8:c.animation??75,animationState:c.cached??0};
  if(c.pop===0){assert.equal(row.result,0xfffffd81);assert.deepEqual(row.calls,[['popObject']]);continue;}
  const result=await scriptIsOpen(c.id??100,{object:id=>{calls.push(['object',id]);return c.object===false?null:o;},asDoor:()=>{calls.push(['asDoor']);return c.door?o:null;},asPlaceable:()=>{calls.push(['asPlaceable']);return c.placeable?o:null;},openState:o=>{calls.push(['openState']);return nativeDoorOpenState(o);}});
  assert.deepEqual(calls,row.calls.slice(1,-1),JSON.stringify(c));assert.equal(result,row.pushed,JSON.stringify(c));assert.equal(o.animationState,row.cached,JSON.stringify(c));assert.equal(row.result,c.push===0?0xfffffd82:0);
 }
});
