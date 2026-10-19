import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {applyOnHitInstant,canSlayAlignment} from '../src/on_hit_instant.js';
import {ModuleSession} from '../src/module_session.js';
import {rulesetHash} from '../src/combat_stats.js';
import {createAttackData,totalAttackDamage} from '../src/combat_attack_data.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-onhit-instant-observations.json',import.meta.url)));
const names={'poison':'Poison','disease':'Disease','ability-damage':'AbilityDamage','level-drain':'LevelDrain','slay-racial':'SlayRacialGroup','slay-alignment-group':'SlayAlignmentGroup','slay-alignment':'SlayAlignment','vorpal':'Vorpal','dispel-property':'DispelMagic','wounding':'Wounding','vampiric':'VampiricRegeneration'};
const snapshot=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,duration:e.duration,creatorId:e.creatorId,spellId:e.spellId,casterLevel:e.casterLevel,exposed:Number(e.exposed),showIcon:Number(e.showIcon),integers:e.integers.slice(0,8)});
test('eleven instant/permanent on-hit owners and alignment gate match original instructions and raw parameter boundaries',async()=>{
 assert.equal(Object.keys(data.owners).length,12);assert.ok(data.rows.length>500);
 for(const row of data.rows){const c=row.case,s=new ModuleSession(null),actor={id:c.creator??99,combatRound:{currentAttack:c.attack??0}},target={},property={PropertyName:c.type??48,Param1Value:c.param??3,CostValue:c.cost??4},trace=[];let allocations=0;s.effects.nextId=101n;
  const p={create:()=>++allocations===c.fail?null:s.effects.create(0),setCreator:(e,id)=>{e.creatorId=id>>>0;e.spellId=c.spell??-1;e.casterLevel=c.casterLevel??-1;if(c.mutateAttack!==undefined)actor.combatRound.currentAttack=c.mutateAttack;},
   creature:()=>{trace.push(['creature']);return c.creature===false?null:target;},race:()=>c.race??1,alignment:(_o,axis)=>{trace.push(['alignment',axis]);return c[axis]??1;},
   costTable:id=>{trace.push(['costTable',id]);return{};},int:(_table,r,column)=>{const found=c.costFound!==false;trace.push(['table',r,column,Number(found),found?c.dc??17:null]);return{found,value:c.dc??17};},rulesDC:(name,value)=>{trace.push(['rulesDC',rulesetHash(name).toString(16).padStart(16,'0'),value]);return c.rulesDC??20;},
   totalDamage:(_o,index)=>{trace.push(['attack',index]);const a=createAttackData();a.damage.set(c.damage??[3,-1,7,0,...Array(28).fill(-1)]);return totalAttackDamage(a,0);},
   append:(_o,e,index)=>trace.push(['attack',index],['append',0xb0,snapshot(e)])};
  if(c.owner==='can-slay')assert.equal(canSlayAlignment(actor,target,property,p),row.result,JSON.stringify(c));
  else await applyOnHitInstant(names[c.owner],actor,target,property,p);
  assert.deepEqual(trace,row.trace,JSON.stringify(c));assert.equal(allocations,row.allocations,JSON.stringify(c));
 }
});
