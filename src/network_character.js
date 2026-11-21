import {NativeMessageWriter} from './native_message.js';
import {isNetworkBytes} from './network_bytes.js';
import {decodeGffText} from './gff_text.js';
export const MAX_NETWORK_CHARACTER_BYTES=948*65535-16;
// Original client7bfbe0 ->7c25c0; server4531b0 case31. No local SaveCreature.
export const characterExportRequest=()=>Uint8Array.of(112,6,31);
// Server4bca90/4dceb0 -> client79b1c0, module3/10. Keep the server's BIC
// opaque and byte-exact; saved active effects are valid multiplayer content.
export function readCharacterExport(r){
 const localized=()=>{if(r.readBool())return{gender:r.readByte(1),strRef:r.readDword()};const value=r.readCExoString();return{text:value.bytes?decodeGffText(value.bytes):''};};
 const firstName=localized(),lastName=localized(),length=r.readDword();
 if(length>MAX_NETWORK_CHARACTER_BYTES||length>r.byteSize40-r.byteCursor44)throw new Error('Invalid native character export size');
 const data=r.readOpaqueBytes(length);if(data===null)throw new Error('Invalid native character export storage');
 return{kind:'character-export',firstName,lastName,data:Uint8Array.from(data)};
}

// HandlePlayerToServerLoginMessage457850 consumes DWORD size then VOIDPtr blob
// for subtypes1(local),4(DM),19(create-server). Calls457e5e..457e7d confirm the
// exact pointer/size ABI passed to native LoadCharacterStart. Server validation
// remains authoritative; this writer never edits BIC statistics/object IDs.
export function characterBlobRequest(bytes,{subtype=1}={}){
 if(![1,4,19].includes(subtype)||!isNetworkBytes(bytes)||bytes.length===0||bytes.length>MAX_NETWORK_CHARACTER_BYTES)throw new Error('Invalid native character upload');
 const writer=new NativeMessageWriter(1);writer.create(bytes.length+4,0xffffffff,1);writer.writeDword(bytes.length);writer.rawBytes(bytes);writer.setPrefix(Uint8Array.from([112,2,subtype]));
 return Uint8Array.from(writer.getWriteMessage().data);
}
