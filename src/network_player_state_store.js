import {mergeNetworkActionQueue} from './network_action_queue.js';
// Apply transmitted player-state differences. This owner never calculates a
// spell's slots, availability, uses, feats or stats from local gameplay rules.
export function applyPlayerState(current,changes){
 const result=structuredClone(current??{}),c=structuredClone(changes);
 const classState=position=>{
  if(!Number.isInteger(position)||position<0||position>=8)throw new Error('Invalid native player spell-class position');
  result.spellbooks??={};return result.spellbooks[position]??={known:[],memorized:{},slots:{},usesLeft:{}};
 };
 for(const change of c.memorizedSlotCounts??[]){const s=classState(change.position);for(const {level,count}of change.levels){s.slots[level]=count;const slots=s.memorized[level]??=[];slots.length=count;for(let i=0;i<count;i++)slots[i]??=null;}}
 for(const change of c.knownSpellChanges??[]){const s=classState(change.position);for(const id of change.removed){const index=s.known.indexOf(id);if(index>=0)s.known.splice(index,1);}s.known.push(...change.added);}
 for(const change of c.memorizedSpellChanges??[]){
  const s=classState(change.position);
  for(const slot of change.removed){if(slot.level>=10)throw new Error('Invalid native prepared-spell level');const slots=s.memorized[slot.level];if(slots&&slot.index<slots.length)slots[slot.index]=null;}
  for(const slot of change.added){if(slot.level>=10)throw new Error('Invalid native prepared-spell level');const slots=s.memorized[slot.level]??=[];if(!Number.isInteger(s.slots[slot.level])||slot.index>=s.slots[slot.level])throw new Error('Prepared-spell index exceeds server slot count');slots[slot.index]=slot;}
 }
 for(const change of c.spontaneousUses??[]){const s=classState(change.position);for(const {level,count}of change.levels)s.usesLeft[level]=count;}
 if(c.featChanges){result.feats??=[];result.bonusFeats??=[];for(const change of c.featChanges){const list=['A','D'].includes(change.action)?result.feats:result.bonusFeats;if(change.action==='A'||change.action==='B')list.push(change.feat);else {const i=list.indexOf(change.feat);if(i>=0)list.splice(i,1);}}}
 if(c.featUses){result.featUses??={};for(const change of c.featUses)result.featUses[change.feat]=change.uses;}
 if(c.effectIcons){result.effectIcons??={};for(const icon of c.effectIcons.removed)delete result.effectIcons[icon];for(const icon of c.effectIcons.added)result.effectIcons[icon.icon]=icon.state;}
 if(c.specialAbilityChanges){result.specialAbilities??=[];for(const change of c.specialAbilityChanges){if(change.action==='S'){result.specialAbilities.length=change.size;for(let i=0;i<change.size;i++)result.specialAbilities[i]??=null;}else {if(change.index>=result.specialAbilities.length)throw new Error('Special-ability index exceeds server size');result.specialAbilities[change.index]=change;}}}
 if(c.visibilityChanges){result.visibility??={};for(const id of c.visibilityChanges.removed)delete result.visibility[id];for(const change of c.visibilityChanges.updated)result.visibility[change.id]=change.flags;}
 if(c.actionQueueChanges){const queue=mergeNetworkActionQueue(result.actionQueue,c.actionQueueChanges,result.actionQueueNextSerial);result.actionQueue=queue.entries;result.actionQueueNextSerial=queue.nextSerial;delete c.actionQueueChanges;}
 for(const key of ['memorizedSlotCounts','knownSpellChanges','memorizedSpellChanges','spontaneousUses','featChanges','featUses','effectIcons','specialAbilityChanges','visibilityChanges'])delete c[key];
 // Queue entries are replicated GUI metadata, never local action-runner input.
 return Object.assign(result,c);
}
