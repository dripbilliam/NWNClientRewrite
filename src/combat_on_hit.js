import { currentAttackWeapon } from './combat_weapon.js';
import { getAttackData } from './combat_attack_data.js';
import { intEntry } from './combat_stats.js';

const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native on-hit ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native on-hit provider ${name} is unavailable`);return p[name];};

// CNWSItem::ActiveProperty 1404640e0..140464107. This classification is
// independent of whether a property has remaining uses or an active effect.
export function activeItemProperty(type){
  type=integer(type,'property type')&65535;const offset=(type-15)&65535;
  return Number(type===80||offset<=55&&(0x80010000000001n>>BigInt(offset)&1n)!==0n);
}
export function itemProperties(item,active){
  if(!item)return [];
  const list=[...(item.data.PropertiesList??[]),...(item.temporaryProperties??[])];
  return list.filter(property=>activeItemProperty(property.PropertyName)===Number(active));
}
// GetPropertyByType 140468f20: active before passive; subtype zero is wildcard.
export function itemPropertyByType(item,type,subtype=0){
  type=integer(type,'query type')&65535;subtype=integer(subtype,'query subtype')&65535;
  return [...itemProperties(item,true),...itemProperties(item,false)].find(property=>
    (property.PropertyName&65535)===type&&(subtype===0||(property.Subtype&65535)===subtype))??null;
}
// Shared weapon/ammunition substitution in ResolveOnHitEffect and
// ResolveItemCastSpell. Even a missing ammo item replaces the original bow.
export function onHitItem(actor,items,rules){
  const data=getAttackData(actor.combatRound,actor.combatRound.currentAttack&255);
  const item=currentAttackWeapon(items,rules,data.weaponAttackType);if(!item)return null;
  const base=item.data.BaseItem,slot=[8,11].includes(base)?2048:[6,7].includes(base)?8192:base===61?4096:null;
  return slot===null?item:items.find(i=>i.slot===slot)??null;
}

// ResolveOnHitEffect 1403e7840: scan selected item's passive pool in order.
// Actual property handlers have separate saves, RNG and effect side effects.
export async function resolveOnHitProperties(actor,target,items,rules,offhand,critical,p){
  const item=onHitItem(actor,items,rules);if(!item)return;
  for(const property of itemProperties(item,false)){
    const offset=((property.PropertyName&65535)-36)&65535;
    if(offset<=36&&(0x1080001001n>>BigInt(offset)&1n)!==0n)
      await required(p,'applyProperty')(actor,target,item,property,offhand,critical);
  }
}
// ResolveItemCastSpell 1403e60a0: attacker weapon/ammo, defender chest or
// creature armor, then defender shield. Property82 uses the FIRST match.
export async function resolveItemOnHitSpells(actor,target,items,targetItems,rules,p){
  const apply=async item=>{const property=itemPropertyByType(item,82);if(property)await required(p,'castSpell')(actor,target,item,property);};
  await apply(onHitItem(actor,items,rules));
  if(target.objectType!==5)return;
  await apply(targetItems.find(i=>i.slot===2)??targetItems.find(i=>i.slot===131072));
  const shield=targetItems.find(i=>i.slot===32);
  if(shield&&[14,56,57].includes(shield.data.BaseItem))await apply(shield);
}
// ResolveOnHitVisuals 1403e8c50..1403e8ef6 queries all 32 positive damage
// components independently. Failed INT reads create no effect, even DEFAULT.
// Creates type30, duration type0, creator attacker, integer0 visual ID.
export async function resolveOnHitVisuals(actor,rules,p){
  const data=getAttackData(actor.combatRound,actor.combatRound.currentAttack&255);
  for(let index=0;index<32;index++){
    if(data.damage[index]<=0)continue;
    if(!rules.damagehitvisual)throw new Error('Native DamageHitVisual table is unavailable');
    const entry=intEntry(rules.damagehitvisual,index,data.ranged===1?'RangedEffectID':'VisualEffectID');
    if(entry.found)data.lists[0].push(await required(p,'effect')(30,actor.id,[entry.value],0));
  }
}
