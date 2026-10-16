import {OBJECT_INVALID} from './game_object_array.js';

const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native item on-hit spell provider ${name} is unavailable`);return p[name](...args);};

// ApplyOnHitCastSpell1403de8a0..1403deaec. This only creates an owned
// attack payload. SignalMelee/RangedDamage schedule event19 at impact;
// the existing receiver installs/restores that spell's caster context.
export async function applyItemOnHitSpell(actor,target,property,item,p){
 const base=item.data.BaseItem|0,offset=(base-14)>>>0;
 const offensive=!(offset<=59&&(0x8000c0000000005n>>BigInt(offset)&1n)!==0n);
 if((property.PropertyName&65535)!==82)return;
 // Original ignores the INT query status and uses its output cell.
 const spellId=call(p,'spellIndex',property.Subtype&65535)|0;
 const casterLevel=(property.CostValue&65535)+1,spell=call(p,'spell',spellId);
 if(!spell)return;
 const payload=call(p,'createPayload');if(!payload)return;
 payload.spellId=spellId;payload.script=call(p,'copyScript',spell.impactScript);
 payload.casterLevel=casterLevel;payload.featId=65535;payload.itemId=item.id>>>0;
 const caster=offensive?actor:target,victim=offensive?target:actor;
 payload.targetId=victim.id>>>0;payload.position=call(p,'position',victim).map(Math.fround);payload.casterId=caster.id>>>0;
 payload.areaId=(actor.areaId>>>0)===OBJECT_INVALID?OBJECT_INVALID:call(p,'areaId',actor)>>>0;
 const attack=call(p,'attack',actor,actor.combatRound.currentAttack&255);
 await call(p,'append',attack,offensive?1:2,payload);
}
