import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyItemOnHitSpell} from '../src/item_on_hit_spell.js';

test('item on-hit payload construction matches complete original owner across direction, widths, query statuses and allocation failure',async()=>{
 const report=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-on-hit-spell-observations.json',import.meta.url)));
 assert.equal(report.rows.length,1050);
 for(const row of report.rows){
  const c=row.case,trace=[],actor={id:0x80000042,areaId:c.invalidArea?0x7f000000:55,position:[1.25,-2.5,3.75],combatRound:{currentAttack:c.attack}},target={id:91,position:[-4.5,5.25,-6.75]};
  await applyItemOnHitSpell(actor,target,{PropertyName:c.type,Subtype:c.subtype,CostValue:c.cost},{id:123,data:{BaseItem:c.base}},{
   spellIndex:index=>{trace.push(['query',index,'SpellIndex',c.status,c.spellId]);return c.spellId;},
   spell:id=>{trace.push(['spell',id>>>0]);return c.validSpell?{impactScript:'test_impact'}:null;},
   createPayload:()=>{trace.push(['allocate',56]);return c.allocate?{}:null;},
   copyScript:text=>{trace.push(['copyScript',text]);return text;},position:o=>o.position,
   areaId:()=>{trace.push(['area','actor']);return 55;},attack:(_o,index)=>{trace.push(['attack',index]);return{};},append:(_a,list,payload)=>trace.push(['append',list,payload])});
  assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
