import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyBlindness,applyInactiveBlindness,removeBlindness,applyDarkness,removeDarkness,applyVisionFilter,applyMissChance,applyDeafness} from '../src/vision_effect.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-vision-observations-v2.json',import.meta.url)));
test('blindness/darkness gates, byte flags and child ownership match untouched native handlers',async()=>{
 for(const row of oracle.rows){
  const c=row.case,calls=[],o={id:99,objectType:c.kind??5,visionFlags:c.flags??0},source={id:98},e={id:'4d',type:c.type??73,integers:[c.mode??16,...Array(7).fill(0)],exposed:true,showIcon:1,bypassImmunity:c.bypass??0,creatorId:98,durationType:c.durationType??2},effects=[e,...(c.remaining??[]).map(n=>({type:73,integers:[n]}))];
  const p={creature:()=>source,immunity:(_o,n)=>{calls.push(['immunity',n]);return c.immune??0;},plot:()=>c.plot??0,dm:()=>c.dm??0,dead:()=>c.dead??0,effects:()=>effects,
   copyConstruct:(e,icons)=>({...structuredClone(e),integers:Array(e.integers.length).fill(0),exposed:false,showIcon:icons?e.showIcon:0}),apply:(_o,e,loading)=>calls.push(['apply',{type:e.type,integers:e.integers,exposed:Number(e.exposed),showIcon:e.showIcon},loading]),
   feedback:(o,code,data)=>calls.push(['feedback',o.id,code,{objects:data.objects}]),floaty:(o,id)=>calls.push(['floaty',o.id,id])};
  const result=c.owner==='inactive'?await applyInactiveBlindness(o,e,p,c.loading??0):c.owner==='blind'?await applyBlindness(o,e,{},p,c.loading??0):c.owner==='dark'?await applyDarkness(o,e,p,c.loading??0):c.owner==='removeBlind'?removeBlindness(o,e,p):
   c.owner==='removeDark'?removeDarkness(o,e,p):c.owner==='deaf'?await applyDeafness(o,e,p,c.loading??0):c.owner==='filter'?await applyVisionFilter(o,e,p,c.loading??0):applyMissChance(o,e,p,c.loading??0);
  assert.equal(result,row.result,JSON.stringify(c));assert.equal(o.visionFlags,row.flags,JSON.stringify(c));assert.equal(e.type,row.type,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
