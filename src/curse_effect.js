const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native curse ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native curse provider ${n} is unavailable`);return p[n](...args);};

// ExecuteCommandEffectComplex1405180b0, ordinal138. With no arguments all
// six magnitudes default to1. The native constructor preserves raw signed INTs.
export function curseEffect(args,creator,p){
  const values=args.length?Array.from({length:6},(_,i)=>integer(args[i],'ability magnitude')):Array(6).fill(1);
  return call(p,'create',45,creator,values,8);
}

// Complete OnApplyCurse1404281a0. CON is delivered as zero-delay AI event5;
// the other five abilities apply immediately, followed by the shared-ID icon.
// OnRemoveCurse140436290 returns1; existing shared-ID removal owns children.
export async function applyCurse(object,effect,p,loading=0){
  if(loading!==0&&object&&call(p,'dead',object)!==0&&![3,4].includes(effect.durationType&7))return 1;
  const actor=call(p,'asCreature',object);if(!actor)return 0;
  if(integer(call(p,'plot',actor),'plot')!==0)return 1;
  const source=call(p,'creature',integer(effect.creatorId,'creator')>>>0);
  if(integer(effect.bypassImmunity,'immunity override')===0&&await call(p,'immunity',actor,17,source,1)!==0){
    const data={objectIds:[actor.id>>>0]};
    if(source)await call(p,'feedback',source,141,structuredClone(data));
    await call(p,'feedback',call(p,'asCreature',object),141,data);return 1;
  }
  for(let ability=0;ability<6;ability++){
    const child=call(p,'copyConstruct',effect,0);child.type=37;child.integers[0]=ability;child.integers[1]=integer(effect.integers?.[ability],'ability magnitude');
    if(ability===2)await call(p,'enqueue',object,5,child);
    else await call(p,'apply',object,child,loading);
  }
  const icon=call(p,'copyConstruct',effect,1);icon.type=67;icon.integers[0]=22;await call(p,'apply',object,icon,loading);return 0;
}
