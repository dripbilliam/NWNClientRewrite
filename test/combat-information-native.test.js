import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {filteredCombatEffects,createCombatInformation,updateCombatInformation,refreshDirtyCreatureStats} from '../src/combat_information.js';
import {abilityModifierCells} from '../src/ability_modifier_cache.js';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-combat-information-observations.json',import.meta.url)));
const rank=c=>value=>c.ranks?.[value]??value*3;
test('native constructor feat defaults survive empty loaded cells and unsupported legacy columns fail explicitly',()=>{
 const s=new ModuleSession(null),columns=Object.keys(capture.baseDefaults);assert.deepEqual(Object.values(capture.baseDefaults),[65535,65535,65535]);
 s.characterRules={baseitems:parse2da(`2DA V2.0\n\n${columns.join(' ')}\n0 **** **** ****\n1 101 102 103`)};
 for(const[column,value]of Object.entries(capture.baseDefaults))assert.equal(s.combat.baseItemFeat({baseItem:0},column),value);
 assert.deepEqual(columns.map(c=>s.combat.baseItemFeat({baseItem:1},c)),[101,102,103]);
 s.characterRules.baseitems=parse2da('2DA V2.0\n\nLabel\n0 legacy');assert.throws(()=>s.combat.baseItemFeat({baseItem:0},columns[0]),/legacy.*fallback/);
});
test('frame refresh matches exact dirty and subscription gates, callback order and flag clearing',()=>{
 assert.equal(capture.frames.length,76);
 for(const row of capture.frames){const c=row.case,actor={nativeField544:c.spells,combatInformationDirty:c.dirty,nativeField540:c.consumers},calls=[];
  refreshDirtyCreatureStats(actor,{memorized:()=>calls.push('memorized'),spellUses:()=>{calls.push('spellUses');if(c.afterUses)[actor.combatInformationDirty,actor.nativeField540]=c.afterUses;},combat:()=>calls.push('combat')});
  assert.deepEqual({calls,spells:actor.nativeField544,dirty:actor.combatInformationDirty,consumers:actor.nativeField540},{calls:row.calls,spells:row.spells,dirty:row.dirty,consumers:row.consumers},JSON.stringify(c));
 }
});

test('filtered combat effects preserve native identity, starts, spell wildcard and magnitude/rank selection',()=>{
 assert.equal(capture.rows.length,997);
 for(const {case:c,indices}of capture.rows){if(c.mode!=='filter')continue;const effects=structuredClone(c.effects),result=filteredCombatEffects(effects,c.kind,c.start??0,rank(c));assert.deepEqual(result.map(e=>effects.indexOf(e)),indices,JSON.stringify(c));assert.deepEqual(effects,c.effects);}
});
test('complete combat information owner matches native scalar/node/weapon caches, capacities, mutation and query order',()=>{
 for(const row of capture.rows){const c=row.case;if(c.mode!=='cache')continue;
  const actor={nativeCombatInformationD70:createCombatInformation(),effects:c.effects??[],nativeArcaneEffectD78:(c.failure??[30,20,10])[0],nativeArcaneChestD79:(c.failure??[30,20,10])[1],nativeArcaneShieldD7a:(c.failure??[30,20,10])[2]},calls=[];
  const items=Object.fromEntries(Object.entries(c.items??{}).map(([slot,item])=>[slot,{...structuredClone(item),id:item.objectId??100+Number(slot),baseItem:item.id,properties:structuredClone(item.properties??[]).map(p=>({subtype:0,param1Value:0,remaining:0,costValue:0,...p}))}]));
  const p={create:createCombatInformation,dispose:()=>calls.push(['dispose']),score:(o,i)=>{calls.push(['score',i]);return(c.scores??[10,12,14,16,18,20])[i];},modifier:value=>{calls.push(['modifier',value&255]);return(value&255)-10;},
   filtered:(o,kind)=>{calls.push(['filtered',kind]);return o.effects.filter(e=>kind===1?[10,11].includes(e.type):[13,14].includes(e.type));},
   damageIndex:flags=>flags<=1?0:31-Math.clz32(flags),monk:()=>{calls.push(['monk']);return c.monk??0;},baseAttack:(o,n)=>{calls.push(['bab',n]);return c.bab??7;},
   equipped:(o,slot)=>{calls.push(['equipped',slot]);return items[slot]??null;},base:item=>{calls.push(['base',item.baseItem]);return{monk:item.monk??0,ranged:item.ranged??0,weaponType:item.weaponType??1,weaponWield:item.wield??0,criticalMultiplier:item.criticalMultiplier??2,weaponOfChoice:item.weaponOfChoice??100};},
   baseById:id=>{calls.push(['base',id]);const item=Object.entries(c.items??{}).find(([,i])=>i.id===id);assert.ok(item);return{equipableSlots:item[1].equipableSlots??Number(item[0])};},
   passive:item=>item.properties,rank:rank(c),damageFlags:()=>c.damageFlags??3,
   meleeAttack:(o,hand)=>{calls.push(['meleeAttack',hand]);return(c.meleeAttack??[17,11])[Number(hand!==0)];},rangedAttack:()=>{calls.push(['rangedAttack']);return c.rangedAttack??23;},
   meleeDamage:(o,hand,natural)=>{calls.push(['meleeDamage',hand,natural]);return natural===255?(c.meleeDamage??[7,3])[Number(hand!==0)]:(c.naturalDamage??[4,5,6])[natural];},rangedDamage:()=>{calls.push(['rangedDamage']);return c.rangedDamage??9;},
   spellResistance:()=>{calls.push(['resistance']);return c.resistance??13;},armorPenalties:()=>c.penalties??[255,254],unarmedDice:()=>{calls.push(['unarmedDice']);return(c.unarmed??[1,3])[0];},unarmedDie:()=>{calls.push(['unarmedDie']);return(c.unarmed??[1,3])[1];},
   propertyExists:(item,type)=>Number(item.properties.some(p=>p.type===type)),property:(item,type)=>item.properties.find(p=>p.type===type)??null,monsterCost:(cost,column)=>c.monster?.[cost]?.[column]??0,
   hasStoredFeat:(o,id)=>Number(c.stored?.includes(id)??false),hasFeat:(o,id)=>{calls.push(['feat',id]);return Number(c.feats?.includes(id)??false);},
   criticalRoll:(o,hand)=>{calls.push(['criticalRoll',hand]);return(c.criticalRoll??[19,18])[Number(hand!==0)];},criticalMultiplier:(o,hand)=>{calls.push(['criticalMultiplier',hand]);return c.offMultiplier??3;}};
  const cache=updateCombatInformation(actor,p),actual={scalars:[...cache.scalars.slice(0,21),...cache.scalars.slice(24,30)],weaponIds:cache.weaponIds,attackNodes:cache.attackNodes.map(n=>[...n]),damageNodes:cache.damageNodes.map(n=>[...n]),capacity:[cache.attackCapacity,cache.damageCapacity],modifiers:abilityModifierCells.map(k=>actor[k]),propertyRemaining:Object.fromEntries(Object.entries(items).map(([slot,item])=>[slot,item.properties.map(p=>p.remaining)])),calls};
  const {case:_,...expected}=row;assert.deepEqual(actual,expected,JSON.stringify(c));
 }
});
