import {NativeMessageWriter} from './native_message.js';
import {encodeGffText} from './gff_text.js';
// Complete client7ba540..7bab8e; server445030. Tell recipients are PLAYER_ID
// values or first-name strings, never canonical creature OBJECT_ID values.
export function chatRequest({channel,text,playerId,recipient}){
 if(![1,2,3,4,6,14].includes(channel)||typeof text!=='string')throw new Error('Invalid native chat request');
 let bytes,name;
 try{bytes=encodeGffText(text);if(channel===4&&recipient!==undefined){if(typeof recipient!=='string'||!recipient.length)throw new Error();name=encodeGffText(recipient);}}
 catch{throw new Error('Chat text cannot be encoded with the active native text codec');}
 // Bounded IPC allocation, not a claimed native edit-box limit. CExoString
 // carries a32-bit byte length; no trimming, command parsing or local echo.
 if(bytes.length>65535||text.includes('\0')||name?.length>65535||recipient?.includes('\0'))throw new Error('Native chat text is invalid or too long');
 if(channel===4&&(name&&playerId!==undefined||!name&&(!Number.isInteger(playerId)||playerId<0||playerId>0xffffffff)))throw new Error('Invalid native tell recipient');
 if(channel!==4&&(playerId!==undefined||recipient!==undefined))throw new Error('Unexpected native chat recipient');
 const w=new NativeMessageWriter(1);w.create(bytes.length+(name?.length??0)+12,0xffffffff,1);
 if(channel===4){w.writeBool(name?1:0);if(name)w.writeStringBytes(name);else w.writeDword(playerId);}
 w.writeStringBytes(bytes);w.setPrefix(Uint8Array.of(112,9,channel));return Uint8Array.from(w.getWriteMessage().data);
}
