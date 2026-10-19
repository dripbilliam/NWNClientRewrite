import {NativeMessageWriter} from './native_message.js';
import {isNetworkBytes} from './network_bytes.js';

// HandlePlayerToServerLoginMessage457850 consumes DWORD size then VOIDPtr blob
// for subtypes1(local),4(DM),19(create-server). Calls457e5e..457e7d confirm the
// exact pointer/size ABI passed to native LoadCharacterStart. Server validation
// remains authoritative; this writer never edits BIC statistics/object IDs.
export function characterBlobRequest(bytes,{subtype=1}={}){
 if(![1,4,19].includes(subtype)||!isNetworkBytes(bytes)||bytes.length===0||bytes.length>948*65535-16)throw new Error('Invalid native character upload');
 const writer=new NativeMessageWriter(1);writer.create(bytes.length+4,0xffffffff,1);writer.writeDword(bytes.length);writer.rawBytes(bytes);writer.setPrefix(Uint8Array.from([112,2,subtype]));
 return Uint8Array.from(writer.getWriteMessage().data);
}
