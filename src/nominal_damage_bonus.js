import {rulesetInt,rulesetFloat} from './combat_stats.js';

const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native nominal damage ${n} is unavailable`);return v|0;};
const call=(p,n,...a)=>{if(typeof p?.[n]!=='function')throw new Error(`Native nominal damage provider ${n} is unavailable`);return p[n](...a);};
const signedByte=v=>(integer(v,'strength cache')<<24)>>24;
// GetPropertyByType returns a CNWItemProperty whose strength limit is WORD+6
// (CostValue), distinct from WORD+2 (Subtype). Both damage-summary and actual
// strike owners use this layout; negative strength remains negative.
export function mightyStrengthBonus(strength,costValue){return Math.min(integer(strength,'strength'),integer(costValue,'Mighty cost')&65535);}
// Both original owners use MULSS then CVTTSS2SI into a 32-bit register.
export function scaledStrengthBonus(strength,multiplier){
  const value=Math.fround(Math.fround(integer(strength,'strength'))*Math.fround(multiplier));
  return Number.isFinite(value)&&value>=-2147483648&&value<2147483648?Math.trunc(value):-2147483648;
}

function specialization(actor,item,rules,p){
  const base=item?call(p,'base',item):null;
  const ordinary=base?integer(base.specialization,'specialization')&65535:138;
  let value=call(p,'hasFeat',actor,ordinary)!==0?rulesetInt(rules,'WEAPON_SPECIALIZATION_BONUS',2):0;
  // Native calls GetBaseItem again between the two feat queries.
  const epicBase=item?call(p,'base',item):null,epic=epicBase?integer(epicBase.epicSpecialization,'epic specialization')&65535:668;
  if(call(p,'hasFeat',actor,epic)!==0)value=(value+rulesetInt(rules,'EPIC_WEAPON_SPECIALIZATION_BONUS',4))|0;
  return value;
}

// Complete GetMeleeDamageBonus1404047c0..140404a98. The optional natural
// selector is a BYTE:255 right hand;0/1/2 creature weapon slots. Nonzero
// offhand chooses left before a double-weapon fallback in the right slot.
export function nominalMeleeDamageBonus(actor,offhand,natural,rules,p){
  offhand=integer(offhand,'offhand');natural=integer(natural,'natural selector')&255;
  let item=null;
  if(offhand!==0){
    item=call(p,'equipped',actor,32);
    if(!item){const right=call(p,'equipped',actor,16),base=right?call(p,'base',right):null;if(right&&(!base||integer(base.weaponWield,'wield')===8))item=right;}
  }else{const slot=({255:16,0:16384,1:32768,2:65536})[natural];if(slot!==undefined)item=call(p,'equipped',actor,slot);}
  if(item&&integer(call(p,'base',item).ranged,'ranged')!==0)return 0;
  let strength=signedByte(actor.nativeStrModifierD39);
  if(offhand!==0){if(strength>0)strength=scaledStrengthBonus(strength,rulesetFloat(rules,'OFFHAND_WEAPON_STRENGTH_MODIFIER',.5));}
  else if(item){
    const base=call(p,'base',item);
    if((integer(base.weaponSize,'weapon size')&255)-integer(actor.nativeSize718,'creature size')===1&&integer(base.weaponWield,'wield')!==8&&natural===255&&strength>0)
      strength=scaledStrengthBonus(strength,rulesetFloat(rules,'TWO_HANDED_WEAPON_STRENGTH_MODIFIER',1.5));
  }
  return(strength+specialization(actor,item,rules,p))|0;
}

// Complete GetRangedDamageBonus1404061f0..14040681d. No point-blank,
// favored-enemy, mode or random bonuses belong in this nominal cache query.
export function nominalRangedDamageBonus(actor,rules,p){
  const item=call(p,'equipped',actor,16);let strength=0;
  if(item){
    if(integer(call(p,'base',item).ranged,'ranged')===0)return 0;
    const base=call(p,'base',item),id=integer(item.baseItem,'base item'),str=signedByte(actor.nativeStrModifierD39);
    if(integer(base.weaponWield,'wield')===11&&id!==59)strength=str;
    else{
      if(((id-6)>>>0)>1&&id!==59&&str<0)strength=str;
      const mighty=call(p,'property',item,45,0);if(mighty)strength=mightyStrengthBonus(str,mighty.costValue);
    }
    if(id===8||id===11){
      for(let tier=20;tier>=1;tier--)if(call(p,'hasFeat',actor,tier<=5?444+tier:1039+tier)!==0){strength=(strength+rulesetInt(rules,`PRESTIGE_ENCHANT_ARROW_${tier}_BONUS`,tier))|0;break;}
    }
  }
  return(strength+specialization(actor,item,rules,p))|0;
}
