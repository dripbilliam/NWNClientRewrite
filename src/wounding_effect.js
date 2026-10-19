const call=(p,n,...args)=>{if(typeof p[n]!=='function')throw new Error(`Native wounding provider ${n} is unavailable`);return p[n](...args);};
// OnApplyWounding140435640 and OnApplyVampiricRegeneration140434d80.
export async function applyWounding(actor,effect,p,loading=0){
 if(effect){const icon=call(p,'copyConstruct',effect,1);icon.type=67;icon.integers[0]=129;await call(p,'apply',actor,icon,loading);}
 return 0;
}
export async function applyVampiricRegeneration(actor,effect,p,loading=0){
 const creator=call(p,'creature',effect.creatorId>>>0);
 if(creator){const heal=call(p,'create',39,effect.creatorId,[],0);heal.durationType=0;heal.integers[0]=Math.min(effect.integers[0]|0,effect.integers[1]|0);await call(p,'apply',creator,heal,loading);}
 return 1;
}
// ApplyWounding140382570: damage is queued, blood visual is applied now.
export async function applyWoundingTick(actor,effect,p){
 const damage=call(p,'create',38,effect.creatorId,[],0);damage.durationType=0;damage.integers=Array(39).fill(0);damage.integers.fill(-1,0,32);
 const index=call(p,'damageIndex',0x1007),amount=effect.integers[0]|0;if(amount<1)call(p,'warning','wounding for less than one damage!?');
 damage.integers[index]=amount;damage.integers[33]=1000;damage.integers[34]=0x1007;damage.integers[35]=0;
 await call(p,'enqueue',5,effect.creatorId>>>0,actor.id>>>0,damage);
 const blood=String(call(p,'blood',actor)).split('\0')[0],visual=call(p,'create',30,0x7f000000,[],0);visual.durationType=0;
 if(blood==='W'||(actor.nativeField771&255)===15)visual.integers[0]=238;
 else if(Object.hasOwn({R:109,G:110,Y:111},blood))visual.integers[0]=({R:109,G:110,Y:111})[blood];
 await call(p,'apply',actor,visual,0);return 1;
}
// UpdateEffectList14049e0ce..14049e1dd uses the same pass-local subtraction
// outputs as regeneration; strict >6000, one tick, even when removal is queued.
export async function updateWounding(actor,effect,now,scratch,p){
 const delta=call(p,'subtractTime',now,{day:effect.integers[1]>>>0,time:effect.integers[2]>>>0});
 if(delta.status===0){scratch.day=delta.day;scratch.time=delta.time;}
 if(!call(p,'asCreature',actor))return false;
 if(call(p,'dead',call(p,'asCreature',actor))!==0)return false;
 const source=call(p,'creature',effect.creatorId>>>0);
 if(!source||(source.areaId>>>0)!==(actor.areaId>>>0))await call(p,'enqueue',14,actor.id>>>0,actor.id>>>0,effect);
 if((scratch.time>>>0)>6000){await call(p,'tick',call(p,'asCreature',actor),effect);effect.integers[1]=now.day|0;effect.integers[2]=now.time|0;}
 return false;
}
