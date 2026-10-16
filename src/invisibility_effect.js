const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native invisibility effect ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native invisibility effect provider ${n} is unavailable`);return p[n](...args);};
// ExecuteCommandEffectInvisibility51a3b0 accepts1,2,4; invalid values
// return the untouched invalid effect rather than a new normal invisibility.
export function invisibilityEffect(kind,creator,p){
  kind=integer(kind,'kind');if(![1,2,4].includes(kind))return call(p,'invalid');return call(p,'create',47,creator,[kind,28],8);
}
// OnApplyInvisibility42e490. Module330 is a unique canonical ID list used
// by existing observer-specific visibility checks. There is no dead/plot gate.
export async function applyInvisibility(actor,effect,p,loading=0){
  if(actor.objectType!==5||!effect)return 0;call(p,'addInvisible',actor.id);
  const kind=integer(effect.integers?.[0],'kind');if(kind===1||kind===4){const icon=call(p,'copyConstruct',effect,1);icon.type=67;icon.integers[0]=kind===1?45:46;await call(p,'apply',actor,icon,loading);}return 0;
}
// OnRemoveInvisibility4372d0 shares the module list with sanctuary63.
// Any remaining source with a DIFFERENT uint64 ID keeps the creature listed.
export function removeInvisibility(actor,effect,p){
  if(actor.objectType!==5)return 1;let remaining=false;
  for(const e of call(p,'effects',actor)){if(e.type>63)break;if((e.type===47||e.type===63)&&e.id!==effect.id)remaining=true;}
  if(!remaining)call(p,'removeInvisible',actor.id);return 1;
}
