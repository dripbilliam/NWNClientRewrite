import {OBJECT_INVALID} from './game_object_array.js';

// Client GUI metadata only. Native receiver7b728d and list owners873df0,
// 8741f0,8748b0: A appends, S inserts after existing special entries, D
// removes the first type/group match. U consumes a target but creates no GUI.
// widgetSerial identifies a local widget, never a game object or wire ID.
export function mergeNetworkActionQueue(current=[],changes=[],nextSerial=0){
 const entries=structuredClone(current);let target=OBJECT_INVALID,position=[0,0,0];
 for(const change of changes){
  if(change.action==='D'){const i=entries.findIndex(e=>e.type===change.type&&e.group===change.group);if(i>=0)entries.splice(i,1);continue;}
  if(change.target!==undefined)target=change.target;
  if(change.action==='U')continue;
  if(change.action!=='A'&&change.action!=='S')throw new Error('Invalid native action-queue update');
  if(change.action==='A'&&change.position)position=[...change.position];
  const entry={type:change.type,group:change.group,target,position:change.action==='S'?[0,0,0]:[...position],special:change.action==='S',widgetSerial:nextSerial++};
  if(change.field5A4!==undefined)entry.spell=change.field5A4;
  if(entry.special)entries.splice(entries.filter(e=>e.special).length,0,entry);else entries.push(entry);
 }
 return{entries,nextSerial};
}
