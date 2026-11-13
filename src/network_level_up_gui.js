import {NativeMessageWriter} from './native_message.js';
// Original final level-up callback838950(code2) -> GUI6f9bd0/7bdf30:
// event16, zero WORD, OBJECT_INVALID and versioned zeroXYZ. This closes the
// server's GUI lifecycle; it neither reverts nor acknowledges a level.
export function levelUpCancelGuiRequest({includePosition}){
 if(typeof includePosition!=='boolean')throw Error('Native level-up cancellation protocol feature is unavailable');
 const writer=new NativeMessageWriter(1);writer.create(20,0xffffffff,1);writer.writeWord(16);writer.writeWord(0);writer.writeObjectIdClient(0x7f000000);
 if(includePosition)for(const value of [0,0,0])writer.writeFloat(value,1,32);
 writer.setPrefix(Uint8Array.of(112,53,1));return Uint8Array.from(writer.getWriteMessage().data);
}
