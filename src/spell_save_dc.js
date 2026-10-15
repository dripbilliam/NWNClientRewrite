import {rulesetInt} from './combat_stats.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spell save DC ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native spell save DC provider ${n} is unavailable`);return p[n](...args);};
const signed=v=>(integer(v,'ability modifier')<<24)>>24;

// ComputeSpellSaveDC1403861c0. The native override and special ability
// branches deliberately omit school focus and class negative-level penalties.
// Focus chooses the highest matching tier, rather than summing all three.
export function computeSpellSaveDC(actor,id,rules,p){
  id=integer(id,'spell ID');const spell=call(p,'spell',id);if(!spell)return 14;
  const innate=integer(spell.innate,'innate level')&255;
  if(integer(actor.nativeCasterOverride820,'override flag')!==0)return(13+innate)|0;
  if(integer(actor.nativeEquipmentLock97c,'equipment override')!==0&&[actor.nativeSpellOverride9e8,actor.nativeSpellOverride9ec,actor.nativeSpellOverride9f0].some(v=>integer(v,'override spell')===id)){
    const effects=call(p,'effects',actor);if(!Array.isArray(effects))throw new Error('Native spell save DC effect storage is unavailable');
    const effect=effects.find(e=>(integer(e.type,'effect type')&65535)===62);let ability=255;
    if(effect&&integer(call(p,'effectInteger',effect,5),'effect ability flag')===1)ability=integer(call(p,'effectInteger',effect,6),'effect ability')>>>0;
    if(ability>5){const slot=integer(call(p,'classIndex',actor,0),'fallback class index')&255;ability=integer(call(p,'classAbility',slot),'fallback class ability')&255;
      if(ability===255)ability=integer(call(p,'classPrimaryAbility',slot),'class primary ability')&255;}
    return(10+innate+signed(call(p,'abilityMod',actor,ability)))|0;
  }
  const index=integer(actor.nativeSpellClass22c,'current class')&255;
  if(index===255){
    const feat=integer(actor.nativeSpellFeat23c,'current feat')&65535;if(feat===65535)return(13+innate)|0;
    const type=integer(call(p,'featSource',actor,feat),'feat source class')&255,slot=integer(call(p,'classIndex',actor,type),'feat source slot')&255;
    return(10+(integer(call(p,'classLevel',actor,slot,0,0),'feat class level')&255)+signed(call(p,'castingMod',actor,slot)))|0;
  }
  if(index===254)return(10+innate+signed(call(p,'abilityMod',actor,5)))|0;
  const modifier=signed(call(p,'castingMod',actor,index)),type=integer(call(p,'classType',actor,index),'class type')&255;
  const penalty=integer(call(p,'negativeLevels',actor,index),'class negative levels')&255;
  let level=integer(actor.nativeSpellDomain21c,'domain level')&255;
  if(level===0){level=integer(call(p,'level',spell.id,type),'spell level')&255;
    if(level===255){const master=call(p,'spell',integer(spell.master,'master ID'));if(master)level=integer(call(p,'level',master.id,type),'master level')&255;if(level===255)level=innate;}}
  const school=integer(call(p,'school',spell),'school')&255;let focus=0;
  if(school>=1&&school<=8){
    const feats=[609+school,392+school,school===1?35:164+school],labels=['FEAT_EPIC_SPELL_FOCUS_BONUS','FEAT_GREATER_SPELL_FOCUS_BONUS','FEAT_SPELL_FOCUS_BONUS'];
    for(let i=0;i<feats.length;i++)if(integer(call(p,'hasFeat',actor,feats[i]),'focus feat')===1){focus=rulesetInt(rules,labels[i],[6,4,2][i]);break;}
  }
  return(10+modifier+level+focus-penalty)|0;
}
