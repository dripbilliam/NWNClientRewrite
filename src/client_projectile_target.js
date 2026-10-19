import {scriptStringRight,scriptSubString} from './script_string.js';

// Successful model loaders86e2cb/87168c install the requested resource name,
// not the model's internal root name. Placeables then remove its first4 bytes.
// Unloaded objects retain their constructor's empty string.
export function clientProjectileTargetPrefix(type,loadedModelName){
 if(loadedModelName===null||loadedModelName===undefined)return '';
 const name=scriptStringRight(loadedModelName,0x7fffffff).split('\0')[0];
 return type===9?scriptSubString(name,4,-1):name;
}

// CNWCProjectile9873d0. RTTI/vtables: placeable A0->870b10, door28->86df20.
// Missing object briefly writes INVALID, but the shared tail overwrites it with
// the requested ID. Door/placeable prefixes override even a supplied part name.
export function setClientProjectileTarget(state,id,node,p){
 id>>>=0;const target=p.object(id);
 if(target?.objectType===9)state.impactNode=p.targetPrefix(target)+'_impact';
 else if(target?.objectType===10)state.impactNode=p.targetPrefix(target)+'impc';
 else state.impactNode=node.length?scriptStringRight(node,0x7fffffff):'impact';
 state.targetId=id;
}
