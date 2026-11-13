import {OBJECT_INVALID} from './game_object_array.js';
import {CLIENT_PERMISSION_SOURCE,DM_PERMISSION_SOURCE,validGameMasterPermission} from './network_dm_permission.js';
const uint=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
const lifetime=value=>Number.isSafeInteger(value)&&value>0;
function normalPermission(value){
 if(value?.source===CLIENT_PERMISSION_SOURCE)return value.permission===0&&value.field114===null&&value.parameter===null;
 return value?.source===DM_PERMISSION_SOURCE&&validGameMasterPermission({kind:'game-master-permission',permission:value.permission,field114:value.field114,parameter:value.parameter})&&value.permission===0;
}
// Typed transport admission only. Native rules own row projection/descriptions;
// the existing World owns identities, replicated association and disclosure runs.
export function nativeRecordTarget(world,actor,{targetId,recordActorLifetime,recordTargetLifetime}){
 targetId=targetId===undefined?actor.id:targetId;
 if(!uint(targetId)||targetId===OBJECT_INVALID)throw Error('Native character-record target is unavailable');
 const foreign=targetId!==actor.id,tagged=recordActorLifetime!==undefined||recordTargetLifetime!==undefined;
 if(!foreign&&!tagged)return{target:actor,foreign:false,scoped:false};
 if(!lifetime(recordActorLifetime)||!lifetime(recordTargetLifetime))throw Error('Native character-record disclosure scope is unavailable');
 const target=world.registry.get(targetId);
 if(world.registry.get(actor.id)!==actor||actor.objectType!==5||actor.areaId!==world.areaId||actor.replicationRemoved||actor.destroyed||!target||target.id!==targetId||target.objectType!==5||target.areaId!==world.areaId||target.replicationRemoved||target.destroyed||world.entityDisclosures?.token(actor)!==recordActorLifetime||world.entityDisclosures?.token(target)!==recordTargetLifetime)throw Error('Native character-record disclosure owner has retired');
 if(foreign&&(!normalPermission(world.gameMasterPermission)||target.replicated?.master!==actor.id||!Number.isInteger(target.replicated?.field908)||target.replicated.field908<1||target.replicated.field908>4))throw Error('Native character-record associate ownership is unavailable');
 return{target,foreign,scoped:true};
}
export function nativeRecordFeatPresent(target,featId){
 const inv=target.inventoryStats??{},player=target.playerState??{},contains=list=>Array.isArray(list)&&list.includes(featId);
 const primary=Object.hasOwn(inv,'fields118')?contains(inv.fields118):Object.hasOwn(player,'feats')?contains(player.feats):Array.isArray(inv.feats)&&inv.feats.some(entry=>entry?.id===featId);
 const secondary=contains(Object.hasOwn(inv,'fields128')?inv.fields128:player.bonusFeats);
 return primary||secondary;
}
