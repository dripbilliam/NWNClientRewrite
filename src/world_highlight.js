// Client presentation only. Never infer an interactable object from scenery,
// create a proxy, or change a replicated object's usable/visibility flags.
import {networkTransitionTrigger} from './network_trigger.js';
export function highlightEligible(object,{areaId}={}){
 if(!object||object.replicationRemoved||object.destroyed||object.areaId!==areaId)return false;
 if(object.objectType===5||object.objectType===10)return true;
 if(object.objectType===7)return networkTransitionTrigger(object);
 if(object.objectType===6)return!object.inventoryLocation?.channel&&!object.equipped;
 if(object.objectType!==9||object.staticState)return false;
 const usable=object.replicated?.field264??object.nativeUseable264??object.usable??object.authored?.Useable;
 return usable!==undefined&&Boolean(usable);
}
export function highlightColor(object,playerId){
 if(object.id===playerId)return'#fff2b2';
 if(object.objectType===5){const reaction=object.replicated?.reaction;return reaction>1?'#ff5555':reaction===1?'#40ff40':'#a080ff';}
 return'#00ffff';
}
export function highlightNameColor(object,playerId){return object.objectType!==5?'#cfffff':object.id===playerId||object.replicated?.reaction===1?'#80ff80':object.replicated?.reaction>1?'#ff5555':'#9080ff';}
// Original CNWSObject::GetDamageLevel495290: prefer the server's category;
// the controlled creature can instead provide its exact replicated HP pair.
export function highlightDamageLevel(object){
 const level=object.replicated?.damageLevel;if(Number.isInteger(level)&&level>=0&&level<=5)return level;
 const hp=object.replicated?.hitPoints;if(!Number.isFinite(hp?.current)||!Number.isFinite(hp.maximum)||hp.maximum<=0)return null;
 const ratio=(hp.current+(hp.fieldE8??0))/hp.maximum;
 return ratio>=.95?0:ratio>=.75?1:ratio>=.5?2:ratio>=.25?3:ratio>0?4:5;
}
export function highlightNameValue(object){
 return object.item?.name??object.replicated?.name??object.appearance?.name??object.staticState?.name??object.authored?.LocName??object.authored?.LocalizedName??object.name??object.tag??'';
}
export async function highlightName(value,resolve){
 if(typeof value==='string')return value;
 if(value?.firstName||value?.lastName)return(await Promise.all([resolve(value.firstName),resolve(value.lastName)])).filter(Boolean).join(' ');
 return value?await resolve(value):'';
}
