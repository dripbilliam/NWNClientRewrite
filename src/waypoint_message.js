import {localizedMessageValue} from './native_message_text.js';
const bool=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native waypoint BYTE ${name} is unavailable`);return Number((value&255)!==0);};

// Constructor140508dc0 clears flags308/30c and constructs localized310.
// LoadWaypoint note block14050a222..14050a2e8 commits only when HasMapNote
// succeeds/nonzero AND MapNote localized read succeeds. Missing/false data
// on a reload leaves an existing note unchanged; Enabled alone is not the gate.
export function loadWaypointMessageState(object,data){
 const fields=object.nativeMessageFields??={};fields[0x308]??=0;fields[0x30c]??=0;
 object.nativeMapNote310??={strRef:0xffffffff,entries:[]};
 if(!Object.hasOwn(data,'HasMapNote')||data.HasMapNote===null||data.HasMapNote===undefined||bool(data.HasMapNote,'HasMapNote')===0)return;
 const note=data.MapNote;if(note===undefined||note===null)return;
 const enabled=bool(data.MapNoteEnabled??0,'MapNoteEnabled'),value=localizedMessageValue(note);
 fields[0x308]=1;fields[0x30c]=enabled;object.nativeMapNote310=value;
}
