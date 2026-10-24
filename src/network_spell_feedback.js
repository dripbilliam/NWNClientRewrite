import {readSpellCombatMessage} from './client_spell_message.js';
import {decodeGffText} from './gff_text.js';
// CC8/1407760c1 uses a BYTE for unidentified item base type, with no build gate.
// Item names are copied from the packet, never looked up on a consumed item.
export function readNetworkSpellFeedback(r){
 const string=()=>{const s=r.readCExoString();return{text:s.bytes?decodeGffText(s.bytes):''};};
 const fields=readSpellCombatMessage({objectId:()=>r.readObjectIdClient(),dword:()=>r.readDword(),bool:()=>r.readBool(),byte:()=>r.readByte(),string,localizedString:()=>r.readBool()?{gender:r.readByte(1),strRef:r.readDword()}:string(),overflow:()=>r.messageReadOverflow()});
 if(!fields)throw new Error('Invalid native spell-feedback fields');return{kind:'spell-feedback',...fields};
}
