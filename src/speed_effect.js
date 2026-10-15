const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native speed effect ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native speed effect provider ${n} is unavailable`);return p[n](...args);};
const loadingDead=(o,e,p,loading)=>loading!==0&&o&&call(p,'dead',o)!==0&&! [3,4].includes(e.durationType&7);
function factor(effect){const n=f(integer(effect.integers?.[0],'magnitude'));return effect.type===28?f(n/f(100)):f(f(1)-f(n/f(100)));}
function remainingFactor(actor,p,initial,exclude){let value=initial;for(const e of call(p,'effects',actor)){
  const type=integer(e.type,'stored type')&65535;if(type>29)break;if((type===28||type===29)&&(!exclude||e.id!==exclude.id))value=f(value*factor(e));
}return value;}
async function icon(actor,effect,id,p,loading){const copy=call(p,'copy',effect,1);copy.type=67;copy.integers[0]=id;await call(p,'apply',actor,copy,loading);}
// OnApplyMovementSpeedIncrease42f320/decrease42f110. Increase values<100
// add100 in the SAME integer cell; decreases>=100 are rejected. Existing
// sorted modifiers multiply in FLOAT order before the clamping setter.
export async function applySpeedEffect(actor,effect,p,loading=0){
  if(loadingDead(actor,effect,p,loading))return 1;if(actor.objectType!==5)return 0;
  const down=effect.type===29;
  if(down){const source=call(p,'creature',integer(effect.creatorId,'creator')>>>0);if(integer(effect.bypassImmunity,'immunity override')===0&&await call(p,'immunity',actor,24,source,1)!==0)return 1;}
  const amount=integer(effect.integers?.[0],'magnitude');
  if(down){if(amount>=100||integer(call(p,'plot',actor),'plot')!==0)return 1;}
  else if(amount<100)effect.integers[0]=(amount+100)|0;
  call(p,'setFactor',actor,remainingFactor(actor,p,factor(effect),null));
  await icon(actor,effect,down?38:37,p,loading);return 0;
}
export function removeSpeedEffect(actor,effect,p){
  if(actor.objectType!==5||!effect)return 1;
  call(p,'setFactor',actor,remainingFactor(actor,p,f(1),effect));return 1;
}
// OnApplyModifyNumAttacks42ee20 sets76c even when the stored override is0.
// Removal tests for another POINTER of type59 before erase, not its ID.
export async function applyAttackCountEffect(actor,effect,p,loading=0){
  if(loadingDead(actor,effect,p,loading))return 1;if(actor.objectType!==5)return 0;
  if(integer(call(p,'plot',actor),'plot')!==0)return 1;
  actor.nativeField76c=1;await icon(actor,effect,38,p,loading);return 0;
}
export function removeAttackCountEffect(actor,effect,p){
  if(actor.objectType!==5)return 1;let found=0;for(const e of call(p,'effects',actor)){
    if(e.type>59)break;if(e.type===59&&e!==effect){found=1;break;}
  }
  actor.nativeField76c=found;return 1;
}
