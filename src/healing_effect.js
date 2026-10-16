const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native healing ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native healing provider ${n} is unavailable`);return p[n](...args);};
const hp=(o,n,p)=>integer(call(p,n,o,1),n)<<16>>16;
function restoreHP(actor,effect,p){
 let amount=integer(effect.integers[0],'amount'),current=hp(actor,'currentHP',p),maximum=hp(actor,'maximumHP',p);
 if(((current+amount)|0)>maximum){current=hp(actor,'currentHP',p);maximum=hp(actor,'maximumHP',p);amount=(maximum-current)|0;}
 call(p,'writeHP',actor,(hp(actor,'currentHP',p)+amount)|0);return amount;
}
// Complete OnApplyHeal14042df10. Heal consumes its record regardless of
// duration; signed INT addition precedes signed SHORT HP comparisons.
export async function applyHealing(actor,effect,p,loading=0){
 if(call(p,'asCreature',actor)&&effect&&call(p,'dead',actor)===0){
  const dying=integer(call(p,'dying',actor),'dying'),amount=restoreHP(actor,effect,p),data={objectIds:[actor.id>>>0],integers:[amount]};
  await call(p,'feedback',actor,151,structuredClone(data));const source=call(p,'creature',effect.creatorId>>>0);
  if(source&&source!==actor)await call(p,'feedback',source,151,data);
  // The native sorted scan restarts after each group removal. Later-type
  // records terminate this pass; do not remove records from a stale snapshot.
  let index=0;while(index<call(p,'effects',actor).length){const record=call(p,'effects',actor)[index];if((record.type&65535)>84)break;
   if((record.type&65535)===84){await call(p,'remove',actor,record.id);index=0;}else index++;
  }
  if(dying===1&&call(p,'dying',actor)===0){const child=call(p,'create',4,0x7f000000,[],0);child.durationType=0;await call(p,'apply',actor,child,loading);}
  await call(p,'encumbrance',actor,1);
 }
 if(call(p,'asDoor',actor)&&effect)restoreHP(actor,effect,p);
 if(call(p,'asPlaceable',actor)&&effect)restoreHP(actor,effect,p);
 return 1;
}
// Complete OnApplyResurrection140430e60. RaiseableF4 is the gate, even for
// living actors. Restore the existing state cells; never replace the object.
export async function applyResurrection(actor,effect,p){
 if(integer(actor.nativeRaiseableF4,'raiseable flag')===0||!call(p,'asCreature',actor))return 1;
 if((integer(call(p,'currentHP',actor,0),'current HP')<<16>>16)<1)call(p,'writeHP',actor,1);
 await call(p,'clearActions',actor);actor.nativeListening1ec=1;actor.nativeField8d4=65535;actor.nativeFieldEc=1;
 await call(p,'encumbrance',actor,1);await call(p,'ambient',actor);
 if(integer(Number(effect.exposed),'exposed flag')!==0)await call(p,'floaty',actor,903);
 const client=call(p,'client',actor.id);if(client)await call(p,'destroyDeathGUI',client);
 let index=0;while(index<call(p,'effects',actor).length){const record=call(p,'effects',actor)[index];if((record.type&65535)>57)break;
  if((record.type&65535)===57&&(record.durationType&7)===1){await call(p,'remove',actor,record.id);index=0;}else index++;
 }
 return 1;
}
