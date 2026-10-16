import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {constructBeamEffect} from '../src/visual_effect.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-beam-constructor-observations.json',import.meta.url)));
test('beam constructor admission and grouped transforms match original instructions',()=>{
 for(const {case:c,output:expected} of oracle.rows){
  const invalid={type:0,subtype:0,creatorId:0x7f000000,spellId:-1,casterLevel:-1,integers:Array(8).fill(0),objectIds:Array(4).fill(0),floats:Array(4).fill(0),vectors:[[0,0,0],[0,0,0]]};
  const args=[c.id,0x80000001,c.body,c.miss];if(c.argc>=7)args.push(c.scale,[1,2,3],[-4,5,6]);
  const actual=constructBeamEffect(args,99,{visualType:()=>({found:c.found,value:c.kind}),invalid:()=>structuredClone(invalid),
   create:(type,creatorId,ints,subtype)=>({...structuredClone(invalid),type,subtype,creatorId,spellId:17,casterLevel:3,integers:[...ints,...Array(8-ints.length).fill(0)]})});
  assert.deepEqual(actual,expected,JSON.stringify(c));
 }
});
