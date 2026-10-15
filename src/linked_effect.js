const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native linked effect ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native linked effect provider ${n} is unavailable`);return p[n](...args);};
const packed=e=>(integer(e.subtype,'subtype')|integer(e.durationType,'duration type'))&65535;
// CGameEffect::UpdateLinked140425370. Recursive updates happen BEFORE
// parent metadata is copied into each child. Preserve that order.
export function updateLinked(effect,icons,p,ancestors=new Set()){
  if(ancestors.has(effect))throw new Error('Native linked effect cycle is unavailable');ancestors.add(effect);
  for(const key of ['linkLeft','linkRight']){
    const child=effect[key];if(!child)continue;
    const subtype=packed(effect)&56,mask=({8:0xffcf,16:0xffd7,24:0xffdf,32:0xffe7})[subtype];
    if(mask!==undefined){const value=(packed(child)&mask)|subtype;child.subtype=value&~7;child.durationType=value&7;}
    if(icons!==0)child.showIcon=integer(effect.showIcon,'show icon');
    updateLinked(child,icons,p,ancestors);
    call(p,'setCreator',child,integer(effect.creatorId,'creator')>>>0);
    for(const property of ['casterLevel','spellId','duration','expiryDay','expiryTime','propertyId','id','customTag','bypassImmunity'])if(Object.hasOwn(effect,property))child[property]=effect[property];
    child.durationType=integer(effect.durationType,'duration type')&7;
  }
  ancestors.delete(effect);
}
// EffectLinkEffects14051a4d0/SetLinked140425220. VM structure arguments are
// owned copies: input values survive linking. Both children inherit uint64 ID.
export function linkEffects(left,right,creator,p){
  const effect=call(p,'create',40,creator,[],0);effect.linkLeft=structuredClone(left);effect.linkRight=structuredClone(right);
  updateLinked(effect,0,p);effect.subtype=(effect.subtype&0xffcf)|8;
  updateLinked(effect,0,p);return effect;
}
// ExecuteCommandSetSubType140544eb0: packed WORD masks preserve duration
// and unrelated bits. Only linked containers trigger metadata propagation.
export function withScriptSubtype(value,ordinal,p){
  const effect=structuredClone(value),pair=({112:[0xffcf,8],113:[0xffd7,16],114:[0xffdf,24],1036:[0xffe7,32]})[ordinal];
  if(pair){const flags=(packed(effect)&pair[0])|pair[1];effect.subtype=flags&~7;effect.durationType=flags&7;}
  if((integer(effect.type,'type')&65535)===40)updateLinked(effect,0,p);return effect;
}
// OnApplyLink14042ef20 consumes the container after left then right apply,
// detaching child ownership. Failure stops at that native delivery boundary.
export async function applyLinkedEffect(actor,effect,p,loading=0){
  updateLinked(effect,0,p);
  for(const key of ['linkLeft','linkRight'])if(effect[key])await call(p,'apply',actor,effect[key],loading);
  effect.linkLeft=null;effect.linkRight=null;updateLinked(effect,0,p);return 1;
}
