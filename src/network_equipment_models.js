import {nativeFloatEntry} from './movement_rate.js';
import {OBJECT_INVALID} from './game_object_array.js';

// SwitchWeaponEvent14080e9d0. These commands concern render attachments only;
// canonical inventory/equipment remains owned by server replication.
export function nativeWeaponAttachments(object,appearance,{localObjectId,modelAvailable=()=>true,hidden=()=>false}={}){
 const scaleEntry=nativeFloatEntry(appearance,object.appearance.appearance,'WEAPONSCALE'),scale=scaleEntry.found?scaleEntry.value:1;
 const equipped=slot=>{const e=object.appearance.equipment?.find(e=>e.slot===slot);return e&&!hidden(e)?e:null;},right=equipped(16),left=equipped(32),commands=[];
 const clear=right=>commands.push({itemId:OBJECT_INVALID,anchor:'',right,scale:1});
 const attach=(e,anchor,right)=>commands.push({itemId:e.id,anchor,right,scale,priority:object.id===localObjectId?2:4});
 if(!right)clear(1);
 else if(modelAvailable(right.id)){
  if([8,11].includes(right.item.baseItem)){attach(right,'lhand',0);clear(1);return commands;}
  attach(right,'rhand',1);
 }
 if(!left)clear(0);
 else if(modelAvailable(left.id))attach(left,[14,56,57].includes(left.item.baseItem)?'lforearm':'lhand',0);
 return commands;
}
