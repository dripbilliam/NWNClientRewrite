import {buildRadialActions,buildGroundRadialActions} from './radial_actions.js';
import {networkDoorState,networkDoorClickState} from './network_door.js';
import {networkPartyCommandMenu} from './network_associate_input.js';
import {networkTransitionTrigger} from './network_trigger.js';
import {placeableUsable} from './placeable_hit_mesh.js';

export function networkObjectLabel(object){
 const name=object.item?.name??object.replicated?.name??object.appearance?.name??object.staticState?.name;
 return name?.text||[name?.firstName?.text,name?.lastName?.text].filter(Boolean).join(' ')||`Object ${object.id.toString(16)}`;
}
// Presentation projection only. Shared native-layout menus retain unsupported
// branches; selection diagnoses them instead of entering singleplayer handlers.
export function networkMenuObject(object){
 const s=object.replicated??{};
 return{id:object.id,kind:({5:'creature',6:'item',7:'trigger',9:'placeable',10:'door'})[object.objectType]??'object',name:networkObjectLabel(object),animationState:networkDoorState(s.animation),locked:Boolean(s.field424),lockable:s.field428===undefined?undefined:Boolean(s.field428),usable:object.objectType===9?placeableUsable(object):object.objectType===10&&s.fieldFC!==undefined?Boolean(s.fieldFC):undefined,ownerId:object.inventoryLocation?.ownerId,equipped:object.inventoryLocation?.channel==='I',stackSize:object.item?.stackSize??object.item?.field454,masterId:s.master,associateType:s.field908,player:false};
}
export function networkRadialActions(target,actor,options={}){
 if(networkTransitionTrigger(target))return{title:networkObjectLabel(target),entries:[{slot:2,label:'Enter',icon:'IR_USE',action:'trigger.transition'}]};
 const a=networkMenuObject(actor),t=target?networkMenuObject(target):null;
 // Native98e550 selects self first; self98ec00 exposes slot4 for type3.
 const menu=t?buildRadialActions(t,a,{...options,commandMenu:networkPartyCommandMenu,unpossessFamiliar:a.associateType===3}):buildGroundRadialActions(a,options);
 if(target?.objectType===10)for(const entry of menu.entries)if(entry.action==='door.toggle')entry.action=networkDoorState(target.replicated?.animation)===0?'door.open':'door.close';
 return menu;
}
export function networkDefaultInteraction(target){
 if(networkTransitionTrigger(target))return'trigger.transition';
 if(target.objectType===10){const state=networkDoorState(target.replicated?.animation),click=networkDoorClickState(target);if(click!==null&&click!==0&&target.replicated?.hasTransition)return'door.transition';if(state===0)return'door.open';if(state===1||state===2)return'door.close';return null;}
 if(target.objectType===5)return target.replicated?.reaction>1?'combat.attack':'conversation.start';
 if(target.objectType===9)return'object.use';if(target.objectType===6)return'item.pickup';return null;
}
