import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native module item ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native module item provider ${name} is unavailable`);return p[name];};

// CNWSModule ctor1404785dc..140478655. Persistent histories are separate
// cells: acquisition never overwrites loss, and missing scripts retain state.
export function initializeModuleItemHistory(module){
  for(const cell of ['nativeAcquiredItem34c','nativeAcquiredFrom350','nativeAcquiredBy354','nativeLostItem358','nativeLostBy35c'])module[cell]??=OBJECT_INVALID;
  module.nativeAcquiredQuantity360??=0;module.nativeLostQuantity364??=0;
  for(const cell of ['nativeEquippedItem368','nativeEquippedBy36c','nativeUnequippedItem370','nativeUnequippedBy374'])module[cell]??=OBJECT_INVALID;
  module.nativeEquippedSlot378??=-1; // ctor140478694 zeroes neither: QWORD -1.
  module.nativeScriptObjectType34??=3; // module ctor140478108, DAT140dc2a42.
}

// Module EventHandler script event19/20 at14047ce36..14047ced4.
export async function receiveModuleItemEvent(module,caller,payload,p){
  if(!payload||!Array.isArray(payload.objectIds)||!Array.isArray(payload.integers))throw new Error('Native module item event storage is unavailable');
  const type=integer(payload.type,'event type')&65535;
  if(![19,20,39,40].includes(type))return false;
  const object=index=>integer(payload.objectIds[index]??OBJECT_INVALID,'event object ID')>>>0;
  const quantity=integer(payload.integers[0]??0,'event quantity');
  if(type===39||type===40){
    if(type===39){module.nativeEquippedBy36c=object(1);module.nativeEquippedItem368=object(0);module.nativeEquippedSlot378=quantity;}
    else{module.nativeUnequippedBy374=object(1);module.nativeUnequippedItem370=object(0);}
    await required(p,'runEventScript')(module,type===39?15:16);
  }else if(type===19){
    module.nativeAcquiredFrom350=object(1);module.nativeAcquiredItem34c=object(0);module.nativeAcquiredQuantity360=quantity;module.nativeAcquiredBy354=object(2);
    const name=required(p,'scriptName')(module,7);
    if(typeof name!=='string')throw new Error('Native acquired-item script name is unavailable');
    if(name.length!==0)await required(p,'runScript')(module,name,(integer(module.nativeScriptObjectType34,'script object type')&255)*1000+7);
  }else{
    module.nativeLostItem358=object(0);module.nativeLostBy35c=integer(caller,'event caller')>>>0;module.nativeLostQuantity364=quantity;
    await required(p,'runEventScript')(module,8);
  }
  return true;
}

// ExecuteCommandGetModuleItemStuff14052bb70 returns stored values even when
// the referenced item has already been deleted from the canonical registry.
export function moduleItemHistory(module,ordinal){
  if(ordinal===579)return module?integer(module.nativeAcquiredQuantity360,'acquired quantity'):0;
  if(!module)return OBJECT_INVALID;
  const cell=({282:'nativeAcquiredItem34c',283:'nativeAcquiredFrom350',292:'nativeLostItem358',293:'nativeLostBy35c',707:'nativeAcquiredBy354'})[ordinal];
  return cell?integer(module[cell],cell)>>>0:OBJECT_INVALID;
}
