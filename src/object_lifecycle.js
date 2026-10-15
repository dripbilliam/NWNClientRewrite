import {OBJECT_INVALID} from './game_object_array.js';

// ExecuteCommandSetIsDestroyable1405420a0 stores boolean +f0 but raw INT
// +f4/+f8. Enabling destruction of a dead NPC schedules event11 after3000ms;
// the event's cleanup owner is separate and must never be replaced by a timer
// that directly deletes a canonical object.
export async function setObjectDestroyable(object,destroyable,raiseable,selectable,p){
  if(!object||object.objectType<=4)return;
  object.nativeDestroyableF0=Number((destroyable|0)!==0);
  if(object.nativeDestroyableF0===1&&object.objectType===5&&await p.dead(object)!==0){
    await p.setLock(object,OBJECT_INVALID);
    if(!Number.isInteger(object.nativeField89c))throw new Error('Native dead creature PC field89c is unavailable');
    if(object.nativeField89c===0&&await p.possessedFamiliar(object)===0)
      await p.enqueue(11,object.lastDamagerId??OBJECT_INVALID,object.id,3000,null);
  }
  object.nativeRaiseableF4=raiseable|0;object.nativeSelectableWhenDeadF8=selectable|0;
}
