import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {removeCharmEffectsByFaction,removeSleepEffects} from '../src/damage_status.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-damage-status-observations.json',import.meta.url)));
test('damage-triggered charm and sleep cleanup match original live traversal, faction, duration, protection and ordered removal',async()=>{
 assert.equal(data.rows.length,350);
 for(const row of data.rows){const c=row.case,actor={id:99,effects:c.effects.map((e,i)=>({id:BigInt(e.id??10+i).toString(16).padStart(16,'0'),type:e.type??8,durationType:e.durationType??1,creatorId:e.creator??100,integers:[e.kind??9,e.protected??0]}))},source={},trace=[],p={arrayAvailable:()=>c.array!==false,object:id=>{trace.push(['object',id]);return id===100&&c.source!==false?source:null;},creature:()=>c.creature!==false?source:null,faction:()=>c.sourceFaction??1,reputation:(_s,id,delta,decays,duration)=>trace.push(['reputation',100,id,delta>>>0,decays,duration]),remove:(_o,id)=>{trace.push(['remove',id]);actor.effects=actor.effects.filter(e=>e.id!==id);}};
  const result=c.mode==='sleep'?await removeSleepEffects(actor,p):await removeCharmEffectsByFaction(actor,c.faction??1,c.adjustment??-100,p);if(c.mode==='charm')assert.equal(result,row.result);assert.deepEqual(trace,row.trace,JSON.stringify(c));assert.deepEqual(actor.effects.map(e=>({id:e.id,type:e.type,kind:e.integers[0],protected:e.integers[1]})),row.effects,JSON.stringify(c));
 }
});
