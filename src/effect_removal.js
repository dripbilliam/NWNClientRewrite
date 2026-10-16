import {equalEffectValues} from './effect_identity.js';

const then=(value,next)=>value?.then?value.then(next):next(value);
const id=value=>{if(typeof value!=='string'||!/^[0-9a-f]{1,16}$/i.test(value))throw new Error('Native removal effect ID is unavailable');return BigInt('0x'+value);};

// RemoveEffectTarget1404986c0. +170 is the shared base-object target list,
// also used for created area effects. Keep the SAME owned NativeIdList.
export function removeEffectTarget(source,targetId,p){
 const target=p.object(targetId),world=target&&p.asWorld(target);
 if(!world||!source.nativeCreatedAreaEffects170?.count)return;
 if((world.effects??[]).some(e=>(e.creatorId>>>0)===(source.id>>>0)))return;
 source.nativeCreatedAreaEffects170.remove(targetId>>>0);
}

// One iteration of RemoveEffectById140498280. Assignment snapshots all
// payload fields BEFORE the callback; the copy constructor clears payloads.
// Callback==1 re-finds by full VALUE, not pointer or ID alone. In particular,
// a replacement with equal value can be erased while the original is freed.
export function removeEffectRecord(object,effect,p){
 const snapshot=structuredClone(effect),source=p.object(effect.creatorId);
 if(snapshot.strings?.length!==6||snapshot.floats?.length!==4||snapshot.objectIds?.length!==4||snapshot.vectors?.length!==2)
  throw new Error('Native effect removal fixed payload storage is unavailable');
 return then(p.onRemove(object,effect),status=>{
  if(status!==1)return 0;
  const index=(object.effects??[]).findIndex(e=>equalEffectValues(e,snapshot));
  if(index>=0){object.effects.splice(index,1);p.destroy?.(effect);}
  return then(object.objectType===5?p.afterRemove(object,snapshot):undefined,()=>{
   p.afterErase?.(object,snapshot);
   if(source){const world=p.asWorld(source);if(world)p.removeTarget(world,object.id);}
   return 1;
  });
 });
}

// The native cursor advances on non-matches and rejected removal, but stays
// at its old index after success. Re-read live count/list after every callback.
// Keep synchronous handlers synchronous for existing engine-call owners.
export function removeEffectsById(object,effectId,p){
 const wanted=id(effectId);let index=0,result=0;
 const step=status=>{if(status===1)result=1;else index++;};
 const next=()=>{
  while(index<(object.effects??[]).length){const effect=object.effects[index];
   if(id(effect.id)!==wanted){index++;continue;}
   const status=removeEffectRecord(object,effect,p);
   if(status?.then)return status.then(value=>{step(value);return next();});
   step(status);
  }
  return result;
 };
 return next();
}

// UpdateEffectList14049dae0 common traversal/expiry coordinator. A periodic
// owner that ran, or ANY expired-ID removal attempt, restarts at index0.
// Captured providers own the active timer and individual periodic effect bodies.
export function updateEffectList(object,p){
 let index=0;
 const advance=restart=>{index=restart?0:index+1;},next=()=>{
  while(index<(object.effects??[]).length){const effect=object.effects[index];
   const restart=then(p.poll(object,effect),polled=>{
    if((effect.durationType&7)===1&&p.expired(effect))return then(p.remove(object,effect.id),()=>true);
    return polled;
   });
   if(restart?.then)return restart.then(value=>{advance(value);return next();});advance(restart);
  }
 };
 return next();
}
