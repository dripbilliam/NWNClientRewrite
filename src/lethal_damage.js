const call=(p,n,...args)=>{if(typeof p[n]!=='function')throw new Error(`Native lethal damage provider ${n} is unavailable`);return p[n](...args);};
async function deathBlood(actor,p,loading){
 const blood=String(call(p,'blood',actor)).split('\0')[0],visuals={R:115,G:116,Y:117};let visual;
 if(blood==='W'||(actor.nativeField771&255)===15)visual=239;else if(Object.hasOwn(visuals,blood))visual=visuals[blood];
 if(visual!==undefined){const child=call(p,'create',30,0x7f000000,[],0);child.durationType=0;child.integers[0]=visual;await call(p,'apply',actor,child,loading);}
}
// OnApplyDamage creature140429617..140429902 and world140429c15..c95.
// Damage never doubles as the death-effect payload: a fresh19[flag,1] is
// applied, with blood visuals on the ordinary creature-death path only.
export async function applyLethalDamage(actor,creatorId,amount,p,loading=0){
 const death=call(p,'create',19,creatorId,[],0);death.durationType=0;
 if(actor.objectType===5){
  const maximum=call(p,'maximumHP',actor,1)<<16>>16;
  if((amount|0)>=Math.trunc(maximum/2)&&(call(p,'currentHP',actor,0)<<16>>16)<-10)death.integers[0]=1;
  else await deathBlood(actor,p,loading);
 }
 death.integers[1]=1;await call(p,'apply',actor,death,loading);
}

// Complete OnRemoveTemporaryHitpoints140438d60..1404391ad. The death
// effect is deferred through event5, with invalid creator and no gib threshold.
export async function removeTemporaryHitpoints(actor,effect,p){
 if(!call(p,'asCreature',actor))return 1;
 const creature=call(p,'asCreature',actor),wasDying=call(p,'dying',creature),wasDead=call(p,'dead',creature);
 if(effect)call(p,'setTemporaryHP',creature,Math.max(0,(((call(p,'temporaryHP',creature)<<16>>16)-(effect.integers[0]|0))|0)));
 if(wasDying===0&&call(p,'dying',creature)===1){
  await call(p,'ambient',creature);creature.nativeFieldEc=0;
  const module=call(p,'module');await call(p,'enqueue',10,creature.id>>>0,module.id>>>0,{type:32,integers:[],objectIds:[]});await call(p,'closePanels',creature,0);return 1;
 }
 if(wasDead!==0||call(p,'dead',creature)!==1)return 1;
 const death=call(p,'create',19,0x7f000000,[],0);death.durationType=0;await deathBlood(creature,p,0);death.integers[1]=1;
 await call(p,'enqueue',5,death.creatorId>>>0,creature.id>>>0,death);return 1;
}
