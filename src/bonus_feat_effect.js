const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native bonus-feat ${n} is unavailable`);return v|0;};
// CNWSCreatureStats +20 pointer/+28 count/+2c capacity. pendingFeats was
// the earlier adapter name for this same list, not a second owned feat pool.
export function bonusFeats(actor){const value=actor.nativeBonusFeats20??actor.pendingFeats??[];if(!Array.isArray(value))throw new Error('Native bonus-feat pool is unavailable');return value;}
export function initializeBonusFeats(actor){
 if(!Object.hasOwn(actor,'nativeBonusFeats20'))actor.nativeBonusFeats20=bonusFeats(actor);
 const list=bonusFeats(actor);let capacity=actor.nativeBonusFeatCapacity2c??0;
 if(!Number.isInteger(capacity)||capacity<0)throw new Error('Native bonus-feat capacity is unavailable');
 while(capacity<list.length)capacity=capacity===0?16:capacity*2;actor.nativeBonusFeatCapacity2c=capacity;
 const alias=Object.getOwnPropertyDescriptor(actor,'pendingFeats');if(!alias?.get){delete actor.pendingFeats;Object.defineProperty(actor,'pendingFeats',{configurable:true,enumerable:true,get(){return this.nativeBonusFeats20;},set(value){if(!Array.isArray(value))throw new Error('Native bonus-feat pool is unavailable');this.nativeBonusFeats20=value;}});}
 return list;
}
// Complete HasBonusFeat140425ba0. Native sentinel optimizations restore
// the last element before returning; membership has no lasting pool mutation.
export function hasBonusFeat(actor,id){id=integer(id,'ID')&65535;return Number(bonusFeats(actor).some(v=>(integer(v,'stored ID')&65535)===id));}
// Complete OnApplyBonusFeat140427fd0. It checks only the bonus pool, so a
// permanent copy does not prevent granting a separately removable bonus copy.
export function applyBonusFeat(actor,effect){
 if(actor.objectType!==5)return 1;const id=integer(effect.integers[0],'effect ID')&65535,list=initializeBonusFeats(actor);
 if(!hasBonusFeat(actor,id)){
  if(list.length===actor.nativeBonusFeatCapacity2c)actor.nativeBonusFeatCapacity2c=list.length===0?16:actor.nativeBonusFeatCapacity2c*2;
  if(list.length>=actor.nativeBonusFeatCapacity2c)throw new Error('Native bonus-feat allocation capacity is invalid');list.push(id);
 }
 return 0;
}
// Complete OnRemoveBonusFeat1404360c0. Preserve a grant supplied by a
// DIFFERENT effect ID with the same raw INT; only then narrow to owned WORD.
export function removeBonusFeat(actor,effect){
 if(actor.objectType!==5)return 1;const raw=integer(effect.integers[0],'effect ID');
 for(const other of actor.effects??[]){const type=integer(other.type,'effect type')&65535;if(type>83)break;
  if(other.id!==effect.id&&type===83&&integer(other.integers[0],'other effect ID')===raw)return 1;
 }
 if(hasBonusFeat(actor,raw)){const list=bonusFeats(actor),index=list.findIndex(v=>(integer(v,'stored ID')&65535)===(raw&65535));if(index>=0)list.splice(index,1);}
 return 1;
}
