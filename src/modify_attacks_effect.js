const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native bonus attacks ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native bonus attacks provider ${n} is unavailable`);return p[n](...args);};
const amount=e=>integer(e.integers?.[0],'stored amount');
const round=actor=>{if(!actor.combatRound||!Number.isInteger(actor.combatRound.bonusEffectAttacks))throw new Error('Native combat-round bonus attacks are unavailable');return actor.combatRound;};

// ExecuteCommandEffectModifyAttacks14051a730. Signed values below6 are
// accepted, including negative values; invalid input leaves creator/subtype0.
export function modifyAttacksEffect(value,creator,p){
  value=integer(value,'constructor amount');return value<6?call(p,'create',44,creator,[value],8):call(p,'invalid');
}
// OnApplyModifyNumAttacks14042f010, type44. Unlike removal, application
// scans the whole live array, with no early stop on a higher effect type.
export function applyModifyAttacks(object,effect,p,loading=0){
  if(loading!==0&&object&&call(p,'dead',object)!==0&&![3,4].includes(effect.durationType&7))return 1;
  const actor=call(p,'asCreature',object);if(!actor)return 0;
  const state=round(actor);if(state.bonusEffectAttacks>5)return 1;
  let total=amount(effect);for(const e of call(p,'effects',actor))if((integer(e.type,'type')&65535)===44)total=(total+amount(e))|0;
  state.bonusEffectAttacks=Math.min(total,5);return 0;
}
// OnRemoveModifyNumAttacks1404378d0 executes BEFORE erase. POINTER identity
// excludes only the current record, even when a sibling has the same uint64 ID.
export function removeModifyAttacks(object,effect,p){
  const actor=call(p,'asCreature',object);if(!actor)return 1;
  let total=0;for(const e of call(p,'effects',actor)){const type=integer(e.type,'type')&65535;if(type>44)break;if(type===44&&e!==effect)total=(total+amount(e))|0;}
  round(actor).bonusEffectAttacks=Math.min(total,5);return 1;
}
