const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native concealment provider ${n} is unavailable`);return p[n](...args);};
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native concealment ${n} is unavailable`);return v|0;};
// ExecuteCommandEffectConcealment518a70 maps the script selector to the
// engine attack-type enum, retaining percentages only in1..100.
export function concealmentEffect(percent,kind,creator,p){
  percent=integer(percent,'percent');kind=integer(kind,'selector');if(percent<1||percent>100)return call(p,'invalid');
  return call(p,'create',76,creator,[percent,28,0,0,kind===1?2:kind===2?3:0],8);
}
// OnApplyConcealment4280b0 has no creature or plot gate. Combat's existing
// ResolveDefensiveEffects owner reads the retained type76 record directly.
export async function applyConcealment(actor,effect,p,loading=0){
  if(loading!==0&&actor&&call(p,'dead',actor)!==0&&![3,4].includes(effect.durationType&7))return 1;
  const percent=integer(effect.integers?.[0],'percent');if(percent>100||percent<1)return 1;
  const icon=call(p,'copyConstruct',effect,1);icon.type=67;icon.integers[0]=108;await call(p,'apply',actor,icon,loading);return 0;
}
