const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native regeneration ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native regeneration provider ${n} is unavailable`);return p[n](...args);};
// Complete OnApplyRegenerate140430d80: only creature application initializes
// the tick clock/icon. Other object types retain the parent unmodified.
export async function applyRegeneration(actor,effect,p,loading=0){
 if(call(p,'asCreature',actor)){
  const now=call(p,'time');effect.integers[2]=now.day|0;effect.integers[3]=now.time|0;
  const child=call(p,'copyConstruct',effect,1);child.type=67;child.integers[0]=2;await call(p,'apply',actor,child,loading);
 }
 return 0;
}
// Regeneration branch14049dba3..dd50. Only elapsed time-of-day is compared,
// unsigned and strictly greater. No catch-up ticks or accumulated remainder.
// Scratch is shared by the native outer effect-list pass, including untouched
// subtraction outputs; the caller owns this pass-local pair.
export async function updateRegeneration(actor,effect,now,scratch,p){
 const delta=call(p,'subtractTime',now,{day:integer(effect.integers[2],'last day')>>>0,time:integer(effect.integers[3],'last time')>>>0});
 if(delta.status===0){scratch.day=delta.day;scratch.time=delta.time;}
 const creature=call(p,'asCreature',actor);
 if(creature){if(call(p,'dead',creature)!==0)return false;const maximum=integer(call(p,'maximumHP',creature,1),'maximum HP')<<16>>16;if((integer(call(p,'currentHP',creature,1),'current HP')<<16>>16)>=maximum)return false;}
 else{const maximum=integer(call(p,'maximumHP',actor,1),'maximum HP')<<16>>16;if((integer(call(p,'currentHP',actor,1),'current HP')<<16>>16)>=maximum||call(p,'dead',actor)!==0)return false;}
 if((integer(effect.integers[1],'interval')>>>0)>=(scratch.time>>>0))return false;
 const child=call(p,'create',39,effect.creatorId,[integer(effect.integers[0],'amount')],0);child.durationType=0;await call(p,'apply',actor,child,0);
 effect.integers[2]=now.day|0;effect.integers[3]=now.time|0;return true;
}
