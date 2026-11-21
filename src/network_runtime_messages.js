import {NativeMessageWriter} from './native_message.js';
import {decodeGffText,encodeGffText} from './gff_text.js';

const text=r=>{const s=r.readCExoString();return s.bytes?decodeGffText(s.bytes):'';};
// SetTlkOverride1404e0210/List1404e02e0 -> client1407ab2f0.
// List is a sequence of SetOverride calls, not a replacement/clear operation.
export function readNetworkTlkOverrides(r,minor){
 const count=minor===2?1:r.readDword();if(count>Math.floor((r.byteSize40-r.byteCursor44)/8))throw new Error('Invalid native TLK override count');
 return{kind:'tlk-overrides',entries:Array.from({length:count},()=>({strRef:r.readDword(),text:text(r)}))};
}
export function readDeviceEchoRequest(r){
 const length=r.readDword();if(length>r.byteSize40-r.byteCursor44)throw new Error('Invalid native device echo length');
 const data=r.readOpaqueBytes(length);if(data===null)throw new Error('Invalid native device echo storage');return{kind:'device-echo-request',data};
}
// Original client1407bbba0 copies opaque bytes unchanged into major54/minor3.
export function deviceEchoResponse(data,format=1){
 if(!(data instanceof Uint8Array))throw new Error('Native device echo data is unavailable');const w=new NativeMessageWriter(format);w.create(data.length+4,0xffffffff,1);w.writeDword(data.length);w.writeOpaqueBytes(data);w.setPrefix(Uint8Array.of(112,54,3));return Uint8Array.from(w.getWriteMessage().data);
}
// Native login1407a31b0 sends nothing when client waypoint478 is empty.
// A configured waypoint is text passed to1407c21f0, never a guessed object ID.
export function loginWaypointResponse(waypoint){
 if(typeof waypoint!=='string'||waypoint.includes('\0'))throw new Error('Native login waypoint is unavailable');if(!waypoint.length)return null;
 const bytes=encodeGffText(waypoint),w=new NativeMessageWriter(1);w.create(bytes.length,0xffffffff,1);w.writeStringBytes(bytes);w.setPrefix(Uint8Array.of(112,2,13));return Uint8Array.from(w.getWriteMessage().data);
}
