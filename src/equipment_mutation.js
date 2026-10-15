const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native equipment ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native equipment mutation provider ${n} is unavailable`);return p[n];};
// EquipItem14038c1c0. Module equip event queues before ownership/slot changes;
// existing-slot unequip, item properties, AC/combat caches and weight follow.
export async function equipCreatureItem(o,slot,item,applyProperties,loading,eventFlag,p){
  slot=integer(slot,'slot')>>>0;applyProperties=integer(applyProperties,'property flag');loading=integer(loading,'loading flag');eventFlag=integer(eventFlag,'event flag');
  if(integer(o.nativeStatsIsPCb0,'stats PC')===1&&eventFlag!==0)await required(p,'equipEvent')(o,item,slot);
  if(item.possessorId!==o.id)await required(p,'setPossessor')(item,o.id,0,0,0);
  if(required(p,'contains')(o,item)!==0)await required(p,'unequip')(o,item,0,1);
  if(applyProperties!==0)await required(p,'applyProperties')(item,o,slot,loading);
  await required(p,'put')(o,slot,item);await required(p,'armor')(o,item,1,0);await required(p,'combatInformation')(o);
  const weight=integer(o.nativeEquippedWeight968,'equipped weight');o.nativeEquippedWeight968=(weight+integer(await required(p,'weight')(item),'item weight'))|0;return 1;
}
// UnequipItem1403a6150. Locked inventory only rejects force==0. The PC
// unequip script is synchronous and sees the old slot/property state.
export async function unequipCreatureItem(o,item,force,eventFlag,p){
  force=integer(force,'force flag');eventFlag=integer(eventFlag,'event flag');
  if(integer(o.nativeEquipmentLock97c,'equipment lock')!==0&&force===0)return 0;
  if(integer(o.nativeStatsIsPCb0,'stats PC')===1&&eventFlag!==0)await required(p,'unequipEvent')(o,item,required(p,'slot')(o,item));
  const slot=required(p,'slot')(o,item);await required(p,'removeProperties')(item,o,slot);await required(p,'remove')(o,item);await required(p,'armor')(o,item,1,0);
  const weight=integer(o.nativeEquippedWeight968,'equipped weight');o.nativeEncumbranceDirty53c=1;
  o.nativeEquippedWeight968=(weight-integer(await required(p,'weight')(item),'item weight'))|0;return 1;
}
