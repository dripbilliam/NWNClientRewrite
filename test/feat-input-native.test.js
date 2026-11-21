import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveFeatInput} from '../src/combat_input.js';
test('decoded feat input keeps original area, zero object point and independent packet acceptance',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-like-input-observations.json',import.meta.url)));
 for(const {case:c,calls}of oracle.featRows){
  const actual=[],actor={nativeField8ac:c.field8ac};let word=0,axis=0,overflow=0;
  const p={clientObject:()=>c.actor?actor:null,asCreature:o=>o,overflow:()=>Number(c.overflow===++overflow),underflow:()=>c.underflow,
   readWord:()=>word++===0?c.featId:c.auxiliary,readObjectId:()=>c.targetId,readFloat:()=>[1.25,2.5,3.75][axis++],
   area:()=>{actual.push(['area']);return c.area?{id:7}:null;},use:(_o,...args)=>{actual.push(['feat',...args]);return c.addResult;}};
  const result=await receiveFeatInput(null,p);assert.equal(result,Number(calls.some(v=>v[0]==='feat')),JSON.stringify(c));assert.deepEqual(actual,calls,JSON.stringify(c));
 }
});
