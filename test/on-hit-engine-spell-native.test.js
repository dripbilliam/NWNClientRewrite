import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {applyEngineOnHitSpell} from '../src/item_on_hit_spell.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-onhit-engine-spell-observations.json',import.meta.url)));
const names={'dispel-item':'DispelMagic','lesser-dispel':'LesserDispel','greater-dispel':'GreaterDispel','disjunction':'MordysDisjunction','knock':'Knock'};
test('five engine on-hit spell payload owners match original gates, active spell lookup, metadata, area calls and ownership',async()=>{
 assert.equal(Object.keys(data.owners).length,5);assert.equal(data.rows.length,376);
 for(const row of data.rows){const c=row.case,trace=[],actor={id:0x80000042,combatRound:{currentAttack:c.attack??0}},target={id:91,objectType:c.type??10},door={locked:c.doorLocked??1},placeable={locked:c.placeableLocked??1};
  await applyEngineOnHitSpell(names[c.owner],actor,target,c.itemId??123,{
   door:()=>{trace.push(['door']);return c.door===false?null:door;},placeable:()=>{trace.push(['placeable']);return c.placeable?placeable:null;},locked:o=>o.locked,
   spell:id=>{trace.push(['spell',id]);return c.validSpell===false?null:{impactScript:'test_impact'};},createPayload:()=>{trace.push(['allocate',56]);return c.allocate===false?null:{};},copyScript:text=>{trace.push(['copyScript',text]);return text;},position:()=>c.position??[-4.5,5.25,-6.75],
   area:()=>{trace.push(['area']);return c.area===false?null:{id:c.areaId??55};},attack:(_o,i)=>{trace.push(['attack',i]);return{};},append:(_a,list,payload)=>trace.push(['append',list===1?0xc0:0xd0,payload])});
  assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
