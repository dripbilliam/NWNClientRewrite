import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spellTouchAttack} from '../src/spell_touch_attack.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-touch-observations.json',import.meta.url)));
test('touch attack rolls, defenses, confirmations and recipient feedback match original instructions',async()=>{
 for(const row of oracle.rows){
  const c=row.case,calls=[],actor={id:99,objectType:c.actorType??5},target={id:100,objectType:c.targetType??5};let draw=0;
  const result=await spellTouchAttack(c.ordinal??146,100,c.feedback??1,99,{object:id=>id===99?actor:target,creature:o=>o.objectType===5?o:null,worldObject:()=>true,
   enemyBonus:()=>c.enemyBonus??0,attackBonus:(_o,ranged)=>{calls.push(['bonus',ranged]);return c.bonus??0;},
   armorClass:(_o,a,touch)=>{calls.push(['ac',a?.id??null,touch]);return c.ac??10;},roll:()=>{const v=(c.rolls??[10,10])[Math.min(draw++,1)];calls.push(['roll',v]);return v;},
   defensive:()=>{calls.push(['defensive']);return c.blocked??0;},attack:()=>({result:c.defenseResult??8,concealmentChance:c.concealment??50}),
   client:id=>(id===99?c.clientA!==false:c.clientT!==false)?{id}:null,send:(client,type,data)=>calls.push(['send',client.id,type,{objects:data.objects,integers:Object.fromEntries(Object.entries(data.integers).map(([k,v])=>[k,v>>>0]))}])});
  assert.equal(result,row.outputs[0],JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
