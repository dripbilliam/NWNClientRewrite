import {intEntry,rulesetInt,abilityModifier} from './combat_stats.js';
import {nativeStringEntry} from './spell_metadata.js';
const i8=v=>(v<<24)>>24,byte=v=>v&255,names=['Str','Dex','Con','Int','Wis','Cha'];

// Original client7f6b20. Only the wheel's client display/admission gate;
// all actual slots, cast validity and consumption remain server-authoritative.
export function clientSpellGainWithBonus(index,level,p){
 index=byte(index);level=byte(level);const classes=p.classes(),c=classes[index],info=c&&p.classInfo(c.id);if(!info)throw new Error('Native client spell-gain class metadata is unavailable');
 const ability=info.ability;if(!Number.isInteger(ability)||ability<0||ability>5)throw new Error('Native client spell-gain ability reads uninitialized metadata');
 const bonus=i8(p.abilityBonus(ability)),sum=i8(p.baseAbility(ability))+i8(p.raceAbility(ability))+i8(p.abilityIncrease(ability))+bonus,score=i8(Math.max(3,sum));
 let modifier=i8(p.modifier(ability));if(ability===1)modifier=i8(modifier+i8(p.dexBonus()));
 if(byte(score-bonus)<level-1+p.minimum())return 0;
 let extra=level!==0&&modifier>0&&modifier>=level?Math.trunc((modifier-level+4)/4):0;if(level!==0&&info.pickSchool&&c.school)extra++;
 let prestige=0;for(let other=0;other<classes.length;other++){
  if(other===index)continue;const r=classes[other],def=p.classInfo(r.id);if(!def||def.spellCaster)continue;let divisor=byte(info.arcane!==0?def.arcaneModifier:def.divineModifier);if(!divisor)continue;
  if(classes.length>2)for(let rival=0;rival<classes.length;rival++){if(rival===other||rival===index)continue;const s=classes[rival],d=p.classInfo(s.id);if(d?.spellCaster&&d.arcane===info.arcane&&(byte(s.level)>byte(c.level)||byte(s.level)===byte(c.level)&&index<rival))divisor=0;}
  if(divisor)prestige=byte(prestige+Math.trunc((byte(r.level)-1+divisor)/divisor));
 }
 const gain=byte(p.classGain(c.id,byte(c.level+prestige),level));return gain===255?0:byte(gain+extra);
}

// CNWCCreatureStats ctor7ea230 initializes bonus7d..82 and Dex7c to0.
// I/800 and G/S subsequently write the SAME client cells in arrival order.
export function mergeNetworkAbilityCache(previous,state,source){
 const cache=structuredClone(previous??{base:null,current:null,bonuses:Array(6).fill(0),dex:0});
 if(source==='player'&&state.abilities){cache.base=[...state.abilities.base];cache.current=[...state.abilities.current];}
 if(source==='stats'){
  if(state.fields70)cache.current=[...state.fields70];if(state.fields7d)cache.bonuses=[...state.fields7d];if(state.fields76){cache.base=state.fields76.slice(0,6);cache.dex=state.fields76[6];}
 }
 return cache;
}
export function clientClassGain(rules,id,level,spellLevel){
 if(((byte(level)-1)&255)>=40)return 255;const ref=nativeStringEntry(rules.classes,id,'SpellGainTable').value.toLowerCase();if(!ref)return 255;const table=rules.classTables?.get(ref);if(!table)throw new Error(`Native client spell gain table ${ref} is unavailable`);
 const count=intEntry(table,byte(level)-1,'NumSpellLevels');if(!count.found)throw new Error('Native class spell-gain level count is unavailable');if(byte(spellLevel)>=(count.value&255))return 255;const cell=intEntry(table,byte(level)-1,`SpellLevel${byte(spellLevel)}`);return cell.found?cell.value&255:255;
}
export function networkSpellGain(actor,rules,index,level){
 const classes=actor.replicated?.stats?.classes??[],race=actor.replicated?.stats?.racialType??actor.replicated?.stats?.fieldD20,cache=actor.clientAbilityCache??mergeNetworkAbilityCache(null,actor.playerState??{},'player');
 const classInfo=id=>{if(!rules.classes.orderedRows[id])return null;const get=key=>intEntry(rules.classes,id,key).value;return{ability:names.findIndex(n=>n.toLowerCase()===nativeStringEntry(rules.classes,id,'SpellcastingAbil').value.toLowerCase()),spellCaster:get('SpellCaster')!==0,pickSchool:get('PickSchool')!==0,arcane:get('Arcane'),arcaneModifier:get('ArcSpellLvlMod')&255,divineModifier:get('DivSpellLvlMod')&255};};
 return clientSpellGainWithBonus(index,level,{classes:()=>classes,classInfo,minimum:()=>rulesetInt(rules,'CHARGEN_BASE_ABILITY_MIN_PRIMARY',11),abilityBonus:n=>cache.bonuses[n],dexBonus:()=>cache.dex,
  baseAbility:n=>cache.base?.[n]??0,modifier:n=>abilityModifier(cache.current?.[n]??rulesetInt(rules,'CHARGEN_BASE_ABILITY_MIN',8),rules),
  raceAbility:n=>{if(!Number.isInteger(race)||!rules.racialtypes.orderedRows[race])throw new Error('Native client racial ability metadata is unavailable');return intEntry(rules.racialtypes,race,names[n]+'Adjust').value;},
  abilityIncrease:n=>{let total=0;for(const c of classes){const ref=nativeStringEntry(rules.classes,c.id,'StatGainTable').value.toLowerCase();if(!ref)continue;const table=rules.classTables?.get(ref);if(!table)throw new Error(`Native client stat gain table ${ref} is unavailable`);if(byte(c.level)>60)throw new Error('Native class ability gain reads outside verified storage');let sum=0;for(let l=0;l<byte(c.level);l++)sum+=intEntry(table,l,names[n].toUpperCase()).value;total+=i8(sum);}return Math.max(-128,Math.min(127,total));},
  classGain:(...a)=>clientClassGain(rules,...a)
 });
}
