const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native silence effect provider ${n} is unavailable`);return p[n](...args);};
// OnApplySilence432f10. Children retain their parent's uint64 effect ID;
// AI mask23/-9 and icon67/23 are separate records, then cache75c is set.
export async function applySilence(actor,effect,p,loading=0){
  if(loading!==0&&actor&&call(p,'dead',actor)!==0&&![3,4].includes(effect.durationType&7))return 1;
  if(actor.objectType!==5)return 0;const source=call(p,'creature',effect.creatorId>>>0);
  if(effect.bypassImmunity===0&&await call(p,'immunity',actor,11,source,1)!==0){const data={type:0,objects:[actor.id]};
    if(source)await call(p,'feedback',source,145,structuredClone(data));await call(p,'feedback',actor,145,data);return 1;}
  if(call(p,'plot',actor)!==0)return 1;
  const state=call(p,'copyConstruct',effect,0);state.type=23;state.integers[0]=-9;await call(p,'apply',actor,state,loading);
  const icon=call(p,'copyConstruct',effect,1);icon.type=67;icon.integers[0]=23;await call(p,'apply',actor,icon,loading);actor.nativeSilence75c=1;return 0;
}
// OnRemoveSilence4387f0 clears the cache unconditionally. Do not invent a
// remaining-source count: the original does not inspect other silence effects.
export function removeSilence(actor){if(actor.objectType===5)actor.nativeSilence75c=0;return 1;}
