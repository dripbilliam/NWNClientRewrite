import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {applyOnHitSlow} from '../src/on_hit_slow.js';
import {ModuleSession} from '../src/module_session.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-onhit-slow-observations.json',import.meta.url)));
const snapshot=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,duration:e.duration,creatorId:e.creatorId,spellId:e.spellId,casterLevel:e.casterLevel,exposed:Number(e.exposed),showIcon:Number(e.showIcon),integers:e.integers.slice(0,8),linkLeft:e.linkLeft?snapshot(e.linkLeft):null,linkRight:e.linkRight?snapshot(e.linkRight):null});
test('on-hit Slow queues original instant visual and linked mechanical/visual effects, with native IDs/flags and partial allocation cleanup',()=>{
 assert.equal(data.rows.length,60);
 for(const row of data.rows){const c=row.case,s=new ModuleSession(null),actor={id:c.creator??99},trace=[],names=new Map();let allocation=0;s.effects.nextId=101n;
  const allocate=factory=>{allocation++;if(c.fail===allocation)return null;const e=factory();names.set(e,allocation);return e;};
  applyOnHitSlow(actor,{},c.rounds,{create:()=>allocate(()=>s.effects.create(0)),copy:(e,icons)=>allocate(()=>s.effects.copyConstruct(e,icons)),setCreator:(e,id)=>{e.creatorId=id>>>0;e.spellId=c.spell??-1;e.casterLevel=c.casterLevel??-1;},append:(_o,e)=>{trace.push(['attack',(c.attack??0)&255]);trace.push(['append',0xb0,snapshot(e)]);},dispose:e=>{trace.push(['destroy',names.get(e)],['free',names.get(e)]);}});
  assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
