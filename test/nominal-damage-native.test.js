import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {parse2da} from '../src/area.js';
import {nominalMeleeDamageBonus,nominalRangedDamageBonus} from '../src/nominal_damage_bonus.js';
import {damageBonus} from '../src/damage_bonus.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-nominal-damage-observations.json',import.meta.url)));
const table=(columns,rows)=>parse2da(`2DA V2.0\n\n${columns}\n${rows}`);
function fixture(c){
  const items=Object.entries(c.items??{}).map(([slot,i])=>({...i,baseItem:i.id,slot:Number(slot),data:{BaseItem:i.id,PropertiesList:c.mighty==null?[]:[{PropertyName:45,Subtype:0,CostValue:c.mighty}]}}));
  const actor={nativeStrModifierD39:c.strength??3,nativeSize718:c.size??3,position:[0,0,0],combatMode:0,creatureData:{Race:0,Appearance_Type:0,ClassList:[]},stats:{feats:c.feats??[],equippedAbilities:{Str:c.strength??3},level:0}};
  const rules={ruleset:table('Label Value',Object.entries({CHARGEN_ABILITY_NEUTRAL_VALUE:0,CHARGEN_ABILITY_MODIFIER_INCREMENT:1,...c.rules}).map(([k,v],i)=>`${i} ${k} ${v}`).join('\n')),
    appearance:table('SIZECATEGORY','0 '+(c.size??3)),baseitems:table('WeaponSize WeaponWield WeaponSpecializationFeat EpicWeaponSpecializationFeat',
      Array.from({length:Math.max(0,...items.map(i=>i.id))+1},(_,id)=>{const i=items.find(i=>i.id===id);return `${id} ${i?.size??3} ${i?.wield??0} ${i?.specialization??100} ${i?.epicSpecialization??101}`;}).join('\n'))};
  const p={equipped:(o,slot)=>items.find(i=>i.slot===slot)??null,base:i=>({weaponWield:i.wield??0,weaponSize:i.size??3,ranged:i.ranged??0,specialization:i.specialization??100,epicSpecialization:i.epicSpecialization??101}),hasFeat:(o,id)=>Number(o.stats.feats.includes(id)),property:()=>c.mighty==null?null:{costValue:c.mighty}};
  return{actor,items,rules,p};
}
test('nominal melee and ranged damage match complete original owners across selectors, caches, feats and Mighty',()=>{
  assert.equal(capture.rows.length,1771);
  for(const {case:c,result}of capture.rows){if(c.mode==='strike')continue;const {actor,rules,p}=fixture(c),actual=c.mode==='melee'?nominalMeleeDamageBonus(actor,c.offhand??0,c.natural??255,rules,p):nominalRangedDamageBonus(actor,rules,p);assert.equal(actual,result,JSON.stringify(c));}
});
test('actual strike damage uses Mighty CostValue rather than subtype, matching controlled original GetDamageBonus calls',()=>{
  for(const {case:c,result}of capture.rows){if(c.mode!=='strike')continue;const {actor,items,rules}=fixture(c),actual=damageBonus(actor,null,rules,items,{dice(){assert.fail('Unexpected random damage');}},{offhand:Boolean(c.offhand),attack:{weaponAttackType:1,ranged:c.ranged??1,attackType:0}});assert.equal(actual.total,result,JSON.stringify(c));}
});
