import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {featAbilityDeltas,computeFeatAbilityBonuses} from '../src/feat_ability_bonuses.js';
import {abilityModifierCells} from '../src/ability_modifier_cache.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-feat-ability-bonuses-observations.json',import.meta.url))),names=['Str','Dex','Con','Int','Wis','Cha'];
test('feat ability delta and application owners match937 original executions with active rule, BYTE wrap, cache/dirty/encumbrance order',async()=>{
 assert.equal(capture.rows.length,937);
 for(const expected of capture.rows){
  const c=expected.case,calls=[];
  if(c.mode==='deltas'){
   const deltas=await featAbilityDeltas(c.nullFeats?null:c.feats,c.remove??0,{hasFeat:(feats,id)=>{calls.push(['hasFeat',id]);return Number(feats.includes(id));},rule:(label,fallback)=>{calls.push(['rule',label,fallback]);return c.bonus??1;}});
   assert.deepEqual({calls,deltas},{calls:expected.calls,deltas:expected.deltas},JSON.stringify(c));
  }else{
   const actor={creatureData:Object.fromEntries(names.map((name,i)=>[name,c.bases[i]])),nativeField97c:c.polymorphed,nativeField544:17,nativeStr9de:c.polyBases[0],nativeDex9e0:c.polyBases[1],nativeCon9df:c.polyBases[2]};for(const key of abilityModifierCells)actor[key]=0xa5;
   await computeFeatAbilityBonuses(actor,{},c.remove??0,{deltas:(_feats,remove)=>{calls.push(['deltas',remove]);return c.deltas;},score:(o,i)=>{calls.push(['score',i,o.creatureData[names[i]]]);return c.scores[i];},modifier:(_o,value)=>{calls.push(['modifier',value]);return c.modifier;},encumbrance:(_o,flag)=>calls.push(['encumbrance',flag])});
   assert.deepEqual({calls,bases:names.map(name=>actor.creatureData[name]),caches:abilityModifierCells.map(name=>actor[name]),poly:[actor.nativeStr9de,actor.nativeDex9e0,actor.nativeCon9df],dirty:actor.nativeField544},{calls:expected.calls,bases:expected.bases,caches:expected.caches,poly:expected.poly,dirty:expected.dirty},JSON.stringify(c));
  }
 }
});
