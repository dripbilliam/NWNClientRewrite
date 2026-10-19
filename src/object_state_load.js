import {readNativeGff} from './native_gff_fields.js';

// Whole CNWSObject::LoadObjectState1404974b0..140497609 coordinator.
// Effect construction uses argument0, so restoring IDs consumes no new ID.
// ApplyEffect receives loading1/special0 and owns deadline/application behavior.
export async function loadObjectState(object,data,p){
 const list=(p.read??readNativeGff)(data,'EffectList',15,null);
 if(list.status!==0)for(const row of list.value){
  const effect=await p.constructEffect(0);await p.loadEffect(effect,row);
  if(effect.skipOnLoad===1||((effect.subtype|effect.durationType)&7)===3)await p.releaseEffect(effect);
  else await p.applyEffect(object,effect,1,0);
 }
 await p.variables(object,data);await p.actions(object,data);await p.transition(object,data);
}
