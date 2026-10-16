import {damageImmunityTotal} from './damage_effect.js';
const at=(e,i)=>(e.integers[i]??0)|0;
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native damage buff provider ${n} is unavailable`);return p[n](...args);};
async function icon(actor,effect,id,p,loading){const child=call(p,'copyConstruct',effect,1);child.type=67;child.integers[0]=id;await call(p,'apply',actor,child,loading);}
// Full OnApplyDamageIncrease/Decrease42a290/429ce0 and mitigation
// 42a380/42a420. Damage penalties have no positive magnitude or plot gate.
export async function applyDamageBuff(actor,effect,p,loading=0){
  const type=effect.type;
  if(type===2||type===12){
    if(effect.exposed)await call(p,'floaty',actor,type===2?2234:2233);
    await icon(actor,effect,type===2?1:3,p,loading);return 0;
  }
  if(type===14&&actor.objectType!==5)return 1;
  if(loading!==0&&call(p,'dead',actor)!==0&&![3,4].includes(effect.durationType&7))return 1;
  if(type===14){const source=call(p,'creature',effect.creatorId>>>0);if(!effect.bypassImmunity&&await call(p,'immunity',actor,21,source,1)!==0)return 1;}
  if(actor.objectType===5)actor.combatInformationDirty=1;
  await icon(actor,effect,type===13?31:32,p,loading);return 0;
}
// Full OnApplyDamageImmunityIncrease42a080/Decrease429e10: exact flags,
// INT wrapping, cache update BEFORE child application, no overlap merging.
export async function applyDamageImmunityBuff(actor,effect,p,loading=0){
  if(loading!==0&&call(p,'dead',actor)!==0&&![3,4].includes(effect.durationType&7))return 1;
  const down=effect.type===17,amount=at(effect,1),flags=at(effect,0)>>>0;
  if(amount<0||down&&call(p,'plot',actor)!==0)return 1;
  if(down&&actor.objectType===5){const source=call(p,'creature',effect.creatorId>>>0);if(!effect.bypassImmunity&&await call(p,'immunity',actor,22,source,1)!==0)return 1;}
  const total=(damageImmunityTotal(call(p,'effects',actor),flags)+(down?-amount:amount))|0;call(p,'setImmunity',actor,flags,total);
  const elemental=({8:111,16:112,32:113,64:114,128:115,256:116,512:117,1024:118,2048:119})[flags];
  await icon(actor,effect,elemental===undefined?(down?34:33):elemental+(down?9:0),p,loading);return 0;
}
// Matching removal runs against the live pool BEFORE erasure and subtracts
// only this contribution, even when another record has the same uint64 ID.
export function removeDamageBuff(actor,effect,p){
  if(effect.type===13||effect.type===14){if(actor.objectType===5)actor.combatInformationDirty=1;return 1;}
  const flags=at(effect,0)>>>0,total=(damageImmunityTotal(call(p,'effects',actor),flags)+(effect.type===17?at(effect,1):-at(effect,1)))|0;
  call(p,'setImmunity',actor,flags,total);return 1;
}
