const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native effect creator ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native effect creator provider ${n} is unavailable`);return p[n](...args);};
// CGameEffect::SetCreator140425110. Resolve an AoE's original caster for
// attribution, but read spell context/level from the AoE object itself.
// Existing non--1 spell and caster-level metadata remain untouched.
export function setEffectCreator(effect,id,p){
  id=integer(id,'object ID')>>>0;const object=call(p,'object',id);effect.creatorId=id;
  if(!object||!call(p,'asWorld',object))return;
  const aoe=call(p,'asAreaEffect',object);if(aoe)effect.creatorId=integer(call(p,'areaEffectCreator',aoe),'AoE caster')>>>0;
  if(integer(effect.spellId,'effect spell')===-1)effect.spellId=integer(call(p,'effectSpell',object),'context spell');
  if(integer(effect.casterLevel,'effect caster level')===-1)effect.casterLevel=integer(call(p,'casterLevel',object),'context caster level');
}
