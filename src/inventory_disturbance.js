import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native inventory disturbance ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native inventory disturbance provider ${n} is unavailable`);return p[n];};
// CNWSObject constructor14048baaf/14048bb2b, separate from module histories.
export function initializeInventoryDisturbance(o){o.nativeLastDisturbed19c??=OBJECT_INVALID;o.nativeDisturbItem1b0??=OBJECT_INVALID;o.nativeDisturbType1b4??=0;}
// Creature EventHandler script event27 at14038faa4..14038faf0.
export async function receiveInventoryDisturbance(o,caller,payload,p){
  if((integer(payload?.type,'event type')&65535)!==27)throw new Error('Native noninventory disturbance event owner is unavailable');
  o.nativeLastDisturbed19c=integer(caller,'caller')>>>0;
  await required(p,'setLastHostile')(o,o.nativeLastDisturbed19c,0);
  o.nativeDisturbType1b4=integer(payload.integers?.[0]??0,'disturb type');
  o.nativeDisturbItem1b0=integer(payload.objectIds?.[0]??OBJECT_INVALID,'item ID')>>>0;
  await required(p,'runEventScript')(o,5);
}
// Wrapper14052a120 accepts only creature/placeable after CNWSObject cast.
export function lastDisturbed(o){return o&&[5,9].includes(o.objectType)?integer(o.nativeLastDisturbed19c,'last disturber')>>>0:OBJECT_INVALID;}
// Wrappers140526870/140526920 accept any nonnull CNWSObject cast.
export function inventoryDisturbItem(o){return o?integer(o.nativeDisturbItem1b0,'item ID')>>>0:OBJECT_INVALID;}
export function inventoryDisturbType(o){return o?integer(o.nativeDisturbType1b4,'disturb type'):0;}
