import {OBJECT_INVALID} from './game_object_array.js';
// AddToLookupTable14047a930 calls Left(64), then copies the C-string prefix.
// Lookup keys are case-sensitive; the object's full stored tag is separate.
export const moduleTagKey=value=>String(value).slice(0,64).split('\0')[0];
export function addModuleTag(tags,tag,id){
 const key=moduleTagKey(tag);tags.set(key,[id>>>0,...(tags.get(key)??[])]);
}
// GetObjectByTag14047d1e0 checks the incoming stored length before Left(64).
// It returns the lookup-table ID directly, with no GameObjectArray relookup.
export function scriptObjectByTag(tags,tag,ordinal=0){
 if(tag.length===0)return OBJECT_INVALID;
 return tags.get(moduleTagKey(tag))?.[ordinal|0]??OBJECT_INVALID;
}
// GetWaypoint14047de70 resolves entries and filters the native type BYTE12.
// Unlike GetObjectByTag, it admits an empty tag and skips stale IDs.
export function scriptWaypointByTag(tags,tag,object){
 for(const id of tags.get(moduleTagKey(tag))??[])if(object(id)?.objectType===12)return id>>>0;
 return OBJECT_INVALID;
}
