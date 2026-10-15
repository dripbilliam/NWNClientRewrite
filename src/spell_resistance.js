import {rulesetInt} from './combat_stats.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spell resistance ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native spell resistance provider ${n} is unavailable`);return p[n](...args);};
const signedByte=v=>(integer(v,'BYTE')<<24)>>24;

// CNWSCreatureStats::GetSpellResistance140408dd0. Innate resistance and
// cached effect resistance have distinct signed-BYTE/wrap behavior.
export function spellResistance(actor,rules,p){
  let innate=0;
  if(call(p,'hasFeat',actor,215)!==0){
    innate=rulesetInt(rules,'DIAMOND_SOUL_SPELL_RESISTANCE_BASE',10)&255;
    const classes=call(p,'classes',actor);if(!Array.isArray(classes))throw new Error('Native spell resistance class list is unavailable');
    const monk=classes.slice(0,classes.length&255).find(c=>(integer(c.Class,'class type')&255)===5);
    if(monk)innate=(innate+(integer(monk.ClassLevel,'class level')&255))&255;
  }
  for(let tier=10;tier>=1;tier--)if(call(p,'hasFeat',actor,698+tier)!==0){innate=(innate+rulesetInt(rules,`EPIC_SPELL_RESISTANCE_${tier}`,tier*2))&255;break;}
  const decrease=integer(actor.nativeSpellResistanceDecreaseD85,'decrease cache')&255;
  if(rulesetInt(rules,'MONK_SPELL_RESISTANCE_CAN_BE_LOWERED',0)!==0)innate=(innate-decrease)&255;
  const effect=signedByte(actor.nativeSpellResistanceIncreaseD84)-signedByte(decrease);
  if(signedByte(innate)<effect)innate=effect&255;
  return signedByte(innate)>0?innate:0;
}

// ExecuteCommandResistSpell14053bb30. AoE SELF owns the spell/context
// when valid. Absorption precedes immunity, then UserType1/3 resistance.
// Feat casts skip these gates; native override==1 skips penetration feats.
export async function resistSpell(casterId,targetId,self,rules,p){
  casterId=integer(casterId,'caster ID')>>>0;targetId=integer(targetId,'target ID')>>>0;
  const caster=call(p,'object',casterId),target=call(p,'object',targetId);
  if(!caster||caster.objectType<=4||!target)return 0;
  const scriptSelf=call(p,'object',integer(self,'SELF')>>>0),selfAoE=scriptSelf?.objectType===11?scriptSelf:null;
  let areaEffect=selfAoE,spell=areaEffect?call(p,'spell',integer(call(p,'effectSpell',areaEffect),'AoE spell')):null;
  if(!spell){areaEffect=null;spell=call(p,'spell',integer(caster.nativeSpellId218,'caster spell'));}
  if(!spell)return 0;
  let level,featCast=false;
  if(selfAoE)level=integer(selfAoE.nativeCasterLevel344,'AoE level');
  else if(caster.objectType===5){
    if(integer(caster.nativeCasterOverride820,'override flag')===1)level=integer(caster.nativeCasterOverride824,'override level');
    else{
      featCast=(integer(caster.nativeSpellFeat23c,'casting feat')&65535)!==65535;
      level=featCast?targetId|0:integer(call(p,'casterLevel',caster),'caster level');
      for(const [feat,label,amount] of [[618,'FEAT_EPIC_SPELL_PENETRATION_LEVEL_BONUS',6],[401,'FEAT_GREATER_SPELL_PENETRATION_LEVEL_BONUS',4],[36,'FEAT_SPELL_PENETRATION_LEVEL_BONUS',2]])
        if(call(p,'hasFeat',caster,feat)===1){level=(level+rulesetInt(rules,label,amount))|0;break;}
    }
  }else level=(Math.imul(integer(spell.innate,'innate level')&255,2)-1)|0;
  if(target.objectType!==5||featCast)return 0;
  let result=integer(await call(p,'absorption',target,caster,areaEffect),'absorption result');
  if(result===-1)result=integer(await call(p,'immunity',target,caster,areaEffect),'immunity result');
  if(result===-1){
    if(![1,3].includes(integer(spell.userType,'UserType')&255))return -1;
    const resistance=signedByte(call(p,'resistance',target));
    if(resistance<=0)return 0;
    const roll=integer(call(p,'dice',1,20),'d20')&65535;
    result=Number(((roll+level)|0)<resistance);
  }else if(result===0)return 0;
  // Both clients receive separately, including when caster==target.
  for(const id of [casterId,targetId]){const client=call(p,'client',id);if(client)await call(p,'send',client,10,{objectIds:[targetId],integers:[result]});}
  return result;
}

function spellForImmunity(caster,areaEffect,p){return call(p,'spell',integer(areaEffect?call(p,'effectSpell',areaEffect):caster.nativeSpellId218,'immunity spell'));}
async function pairedFeedback(target,caster,code,data,p){
  await call(p,'feedback',target,code,structuredClone(data));
  if(caster.objectType===5)await call(p,'feedback',caster,code,structuredClone(data));
}
function effectRows(target,p){const rows=call(p,'effects',target);if(!Array.isArray(rows))throw new Error('Native immunity effect storage is unavailable');return rows;}
const effectInt=(e,index)=>integer(e.integers?.[index],`effect integer${index}`);
// SpellAbsorption140494890. Consumable records choose the largest admitted
// cap, spend spell LEVEL, remove exhausted IDs before feedback, and return3.
// Nonconsumable records return2 and do not emit absorption feedback.
export async function spellAbsorption(target,caster,areaEffect,p){
  if(caster?.objectType!==5||effectRows(target,p).length===0)return -1;
  const spell=spellForImmunity(caster,areaEffect,p);if(!spell)return -1;
  const school=integer(spell.school,'school')&255;let level=255;
  if(integer(caster.nativeCasterOverride820,'absorption override')!==1){
    const type=integer(call(p,'classType',caster,integer((areaEffect??caster).nativeSpellClass22c,'casting class')&255),'class type')&255;
    if(type!==255){
      level=integer(call(p,'level',spell.id,type),'spell level')&255;
      if(level===255){const master=call(p,'spell',integer(spell.master,'master spell'));if(master)level=integer(call(p,'level',master.id,call(p,'classType',caster,integer(caster.nativeSpellClass22c,'caster class')&255)&255),'master level')&255;}
    }
  }
  if(level===255)level=integer(spell.innate,'absorption innate')&255;
  if((integer(spell.userType,'absorption UserType')&255)!==1)return -1;
  for(const mode of [0,1]){
    let chosen=null,cap=0;
    for(const effect of effectRows(target,p)){
      const type=integer(effect.type,'effect type')&65535;if(type>65)break;if(type!==65)continue;
      const max=effectInt(effect,0),category=effectInt(effect,2);
      if(level<=max&&(category===school||category===0)&&max>cap&&effectInt(effect,3)===mode){cap=max;chosen=effect;}
    }
    if(chosen){
      if(mode===1)return 2;
      const remaining=(effectInt(chosen,1)-level)|0;
      if(remaining<=0)await call(p,'remove',target,chosen);else chosen.integers[1]=remaining;
      await pairedFeedback(target,caster,70,{objectIds:[target.id>>>0],integers:[0,level,remaining>0?remaining:0]},p);
      return 3;
    }
  }
  return -1;
}
// SpellImmunity140494650: exact spell or-1 wildcard in sorted type50 pool.
export async function spellImmunity(target,caster,areaEffect,p){
  const id=integer(areaEffect?call(p,'effectSpell',areaEffect):caster.nativeSpellId218,'immunity spell');
  if(target?.objectType!==5)return -1;
  for(const effect of effectRows(target,p)){
    const type=integer(effect.type,'effect type')&65535;if(type>50)break;if(type!==50)continue;
    if([id,-1].includes(effectInt(effect,0))){await pairedFeedback(target,caster,68,{objectIds:[target.id>>>0],integers:[0,id]},p);return 2;}
  }
  return -1;
}
