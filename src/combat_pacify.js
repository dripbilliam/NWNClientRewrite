import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native pacify ${n} is unavailable`);return v>>>0;};

// PacifyCreature(uint)140399b50..140399c26. Clear combat only if one
// of the five native target cells matches; +738 is deliberately not queried.
export async function pacifyCreature(actor,id,p){
 const target=p.creature(id>>>0);if(!target)return;
 if(!['attackActionTargetId','nativeAttackTarget724','spellActionTargetId','nativeTarget740','lastHostileActorId'].some(n=>integer(target[n],n)===(actor.id>>>0)))return;
 await p.combatState(target,0);
 if(integer(target.lastHostileActorId,'last hostile')===(actor.id>>>0))await p.lastHostile(target,OBJECT_INVALID,1);
 await p.clearHostile(target,actor);
}
