import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {updateFloatingText} from '../src/client_floating_text.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-floating-text-frame-observations.json',import.meta.url)));
test('576 original floaty frames match lifetime, fade, missing owners, world rise and negative screen rounding',()=>{
 assert.equal(oracle.cases.length,576);
 for(const row of oracle.cases){assert.equal(row.error,null);const c=row.case,calls=[],state={objectId:0xffffffff,duration:Math.fround(1.5),remaining:Math.fround(c.remaining),rgb:[.25,.5,1],shadow:Boolean(c.shadow)};
  updateFloatingText(state,c.delta,{destroy:()=>calls.push(['destroy',1]),object:id=>{calls.push(['object',id]);return c.actor?{}:null;},model:()=>{calls.push(['model']);return c.model?{}:null;},world:()=>{calls.push(['world']);return c.world?{}:null;},position:()=>[3,4,5],project:(_world,point)=>{calls.push(['project',point]);return c.screen.map(Math.fround);},color:(...v)=>calls.push(['color',...v]),screen:p=>calls.push(['position',p])});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(state.remaining,row.remaining);
 }
});
