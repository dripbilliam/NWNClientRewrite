const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native defense effect ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native defense effect provider ${n} is unavailable`);return p[n](...args);};
const byte=v=>(v<<24)>>24;
function loadingDead(actor,effect,p,loading){return loading!==0&&actor&&call(p,'dead',actor)!==0&&! [3,4].includes(integer(effect.durationType,'duration type')&7);}
async function icon(actor,effect,id,p,loading){const copy=structuredClone(effect);copy.type=67;copy.integers[0]=id;copy.exposed=false;await call(p,'applyIcon',actor,copy,loading);}
// Registered type33/34 owners140433c20/140433aa0. Increased resistance
// compares with TOTAL resistance. Raw integer storage survives clamping.
export async function applySpellResistanceEffect(actor,effect,p,loading=0){
  if(loadingDead(actor,effect,p,loading))return 1;if(actor.objectType!==5)return 0;
  const down=effect.type===34;
  if(down){const source=call(p,'object',integer(effect.creatorId,'creator')>>>0);if(integer(effect.bypassImmunity,'immunity override')===0&&await call(p,'immunity',actor,26,source?.objectType===5?source:null,1)!==0)return 1;}
  const raw=integer(effect.integers?.[0],'magnitude');if(raw<0||down&&integer(call(p,'plot',actor),'plot')!==0)return 1;
  const amount=Math.min(raw,128);actor.combatInformationDirty=1;
  if(down){if(byte(integer(actor.nativeSpellResistanceDecreaseD85,'decrease cache'))<=amount)call(p,'setCache',actor,true,amount&255);}
  else if(amount>byte(integer(call(p,'resistance',actor),'total resistance')))call(p,'setCache',actor,false,amount&255);
  await icon(actor,effect,down?42:41,p,loading);return 0;
}
// Removal scans the sorted pool BEFORE erase. Increase excludes all equal
// uint64 IDs; decrease excludes the same pointer only. Max raw INT is BYTE
// narrowed without the apply clamp, matching the original removal owners.
export function removeSpellResistanceEffect(actor,effect,p){
  if(actor.objectType!==5)return 1;let amount=0;
  const down=effect.type===34,rows=call(p,'effects',actor);
  for(const other of rows){const type=integer(other.type,'effect type')&65535;if(type>effect.type)break;
    if(type!==effect.type||(down?other===effect:other.id===effect.id))continue;const v=integer(other.integers?.[0],'remaining magnitude');if(v>amount)amount=v;}
  actor.combatInformationDirty=1;call(p,'setCache',actor,down,amount&255);return 1;
}
// Registered type50/65 protection owners1404338f0/1404339c0. They retain
// on any NWSObject, even dead when script applies with loading0.
export async function applySpellProtectionEffect(actor,effect,p,loading=0){
  if(loadingDead(actor,effect,p,loading))return 1;
  await icon(actor,effect,effect.type===50?106:integer(effect.integers?.[3],'absorption kind')===1?106:57,p,loading);return 0;
}
