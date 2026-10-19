import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {computeModifiedMovement} from '../src/modified_movement.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-modified-movement-observations.json',import.meta.url)));
test('complete modified movement matches original rules/feat gates, ID removal/restart, shared-ID construction and application order',async()=>{
 assert.equal(data.rows.length,211);
 for(const row of data.rows){const c=row.case,actor={id:0x80000042,animationState:c.animation??0,nativeField6ec:c.detect??0,nativeField6ed:c.stealth??0,nativeEncumbrance970:c.encumbrance??0,effects:structuredClone(row.before)},trace=[];let feat=0;
  await computeModifiedMovement(actor,{hasFeat:(_o,id)=>{trace.push(['feat',id]);const values=c.feats??[0,0];return values[Math.min(feat++,values.length-1)];},rule:(key,fallback)=>{trace.push(['rule',key,fallback]);return c.rules?.[key]??fallback;},effects:o=>o.effects,start:(o,type)=>{const n=o.effects.findIndex(e=>e.type>=type);return n<0?o.effects.length:n;},remove:(o,id)=>{trace.push(['remove',id]);o.effects.splice(o.effects.findIndex(e=>e.id===id),1);},
   create:()=>{trace.push(['create','00000000000003e9']);return{id:'00000000000003e9',type:0,durationType:0,creatorId:0x7f000000,integers:Array(8).fill(0)};},creator:(e,id)=>{trace.push(['creator',e.id,id]);e.creatorId=id;},copy:(e,flag)=>{trace.push(['copy',e.id,flag]);return{...structuredClone(e),type:0,integers:Array(8).fill(0)};},apply:(o,e,loading,flag)=>{trace.push(['apply',structuredClone(e),loading,flag]);o.effects.push(e);o.effects.sort((a,b)=>a.type-b.type);}});
  assert.deepEqual(actor.effects,row.after,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
