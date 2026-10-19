const call=(p,n,...a)=>{if(typeof p[n]!=='function')throw new Error(`Native skill buff provider ${n} is unavailable`);return p[n](...a);};
// OnApplySkillIncrease1404332d0 / Decrease140433190. Magnitude zero is
// admitted. Dead gating applies only during loading, with equipped/innate
// exceptions. Child icon67 uses the clearing copy constructor with icons1.
export async function applySkillBuff(actor,effect,p,loading=0){
 if(loading!==0&&actor&&call(p,'dead',actor)!==0&&![3,4].includes(effect.durationType&7))return 1;
 const amount=effect.integers?.[1]??0;if(!Number.isInteger(amount))throw new Error('Native skill buff magnitude is unavailable');
 const down=(effect.type&65535)===56;if((amount|0)<0||down&&call(p,'plot',actor)!==0||!call(p,'asCreature',actor))return 1;
 if(down){const source=call(p,'creature',effect.creatorId>>>0);if(effect.bypassImmunity===0&&await call(p,'immunity',call(p,'asCreature',actor),27,source,1)!==0)return 1;}
 const icon=call(p,'copyConstruct',effect,1);if(!icon)throw new Error('Native skill icon allocation is unavailable');icon.type=67;icon.integers[0]=down?44:43;await call(p,'apply',actor,icon,loading);return 0;
}
