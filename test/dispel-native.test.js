import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyDispel} from '../src/dispel_effect.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-dispel-observations.json',import.meta.url)));
test('dispel all/best ID deduplication, rolls, feedback and deferred ownership match original handlers',async()=>{
 for(const {case:c,result:expected,calls:expectedCalls} of oracle.rows){
  const calls=[],o={id:99,effects:c.effects.map(e=>({casterLevel:1,subtype:8,durationType:2,spellId:1,...e}))},source={id:c.sourceId??98,objectType:c.sourceType??5};let draw=0;
  const result=await applyDispel(o,{creatorId:source.id,integers:[c.level??10]},
   {object:()=>c.sourceExists===false?null:source,level:()=>c.totalLevel??7,effects:o=>o.effects,
    roll:(count,sides)=>{calls.push(['roll',count,sides]);const values=c.rolls??[20];return values[Math.min(draw++,values.length-1)];},
    spell:id=>(c.validSpells??[1,2,3]).includes(id)?{id}:null,client:id=>(c.clients??[99,98]).includes(id)?{id}:null,
    send:(client,type,data)=>calls.push(['message',client.id,type,structuredClone(data)]),enqueue:(...args)=>calls.push(['event',...args])},c.best??false);
  assert.equal(result,expected,JSON.stringify(c));assert.deepEqual(calls,expectedCalls,JSON.stringify(c));
 }
});
