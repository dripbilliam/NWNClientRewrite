import {NativeMessageWriter} from './native_message.js';
import {encodeGffText} from './gff_text.js';
const uint=v=>Number.isInteger(v)&&v>=0&&v<=0xffffffff;
const vector=v=>Array.isArray(v)&&v.length===3&&v.every(n=>Number.isFinite(n)&&Number.isFinite(Math.fround(n)));
// Original7bdf30 and map-click892a30. This is OnPlayerGuiEvent type7,
// not Examine/use-object or a local map-note success notification.
export function mapPinClickRequest({reference,includePosition}){
 if(!uint(reference)||typeof includePosition!=='boolean')throw Error('Invalid native map-pin click');
 const w=new NativeMessageWriter(1);w.create(20,0xffffffff,1);w.writeWord(7);w.writeWord(0);w.writeObjectIdClient(reference);if(includePosition)for(const n of [0,0,0])w.writeFloat(n,1,32);w.setPrefix(Uint8Array.of(112,53,1));return Uint8Array.from(w.getWriteMessage().data);
}
// Original add7c22d0/change7c2400/delete7c2540. Editing/deletion have no
// ordinary reply; transport completion must not be labeled server confirmation.
export function mapNoteRequest({operation,reference,position,text}){
 if(!['add','change','delete'].includes(operation)||operation!=='add'&&!uint(reference))throw Error('Invalid native map-note operation');
 const w=new NativeMessageWriter(1);let bytes;
 if(operation!=='delete'){
  if(!vector(position)||typeof text!=='string'||text.includes('\0'))throw Error('Invalid native map-note fields');
  bytes=encodeGffText(text);if(bytes.length>65535)throw Error('Native map note exceeds the supported text allocation');
 }
 w.create((bytes?.length??0)+16,0xffffffff,1);
 if(operation!=='delete'){for(const n of position)w.writeFloat(n,1,32);w.writeStringBytes(bytes);}
 if(operation!=='add')w.writeInt(reference|0,32);
 w.setPrefix(Uint8Array.of(112,32,operation==='add'?2:operation==='change'?5:3));return Uint8Array.from(w.getWriteMessage().data);
}
