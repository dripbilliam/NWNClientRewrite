import {writeLocalizedServer,readLocalizedClient} from './native_message_text.js';

// SendServerToPlayerMapPinCreated1404dc2d0..1404dc3ec. The localized
// argument is an owned by-value temporary; dispose it on either return path.
export async function writeMapPinCreated(message,id,point,note,enabled,p){
 await p.create(message,16,0xffffffff,1);await p.writeObject(message,id);
 for(const index of [0,1,2])await p.writeFloat(message,point[index],1,32);
 await writeLocalizedServer(message,note,0,p);await p.writeBool(message,enabled);
 return p.payload(message);
}
export async function sendMapPinCreated(message,client,id,point,note,enabled,p){
 const payload=await writeMapPinCreated(message,id,point,note,enabled,p);
 if(!payload.status){await p.disposeLocalized(note);return 0;}
 if(!Number.isInteger(client.nativePlayerId48))throw new Error('Native map-pin recipient PLAYER_ID is unavailable');
 const result=await p.send(message,client.nativePlayerId48,0x20,6,payload.data,payload.length);
 await p.disposeLocalized(note);return result|0;
}

// SendServerToPlayerMapPinEnabled1404dc3f0..1404dc485.
export async function writeMapPinEnabled(message,id,enabled,p){
 await p.create(message,8,0xffffffff,1);await p.writeObject(message,id);await p.writeBool(message,enabled);
 return p.payload(message);
}
export async function sendMapPinEnabled(message,client,id,enabled,p){
 const payload=await writeMapPinEnabled(message,id,enabled,p);if(!payload.status)return 0;
 if(!Number.isInteger(client.nativePlayerId48))throw new Error('Native map-pin recipient PLAYER_ID is unavailable');
 return (await p.send(message,client.nativePlayerId48,0x20,1,payload.data,payload.length))|0;
}

// HandleServerToPlayerMapPinCreated1407a3990..1407a3cac, profiling disabled.
// Message/localized-string readers retain their own allocator and TLK owners.
// Both check overflow first. Created checks underflow BEFORE scene mutation.
export async function receiveMapPinCreated(message,p){
 if(message.messageReadOverflow())return 0;
 const id=message.readObjectIdClient(),point=[message.readFloat(1,32),message.readFloat(1,32),message.readFloat(1,32)];
 const text=await readLocalizedClient(message,p),enabled=message.readBool();
 if(message.messageReadUnderflow())return 0;
 const area=await p.area(),pin=await p.construct();pin.nativeReference188=id>>>0;
 await p.position(pin,point);await p.text(pin,text);pin.nativeType18c=0;pin.nativeEnabled170=enabled|0;
 await p.append(area,pin);const gui=await p.gui();if(gui)await p.refresh(gui,1);return 1;
}

// GetMapPin1407daeb0..1407daeef returns the FIRST matching reference/type,
// skipping null entries; duplicate server references are not deduplicated.
export function findMapPin(area,reference,type){
 for(const pin of area.nativeMapPins2b8)if(pin&&(pin.nativeReference188>>>0)===(reference>>>0)&&(pin.nativeType18c|0)===(type|0))return pin;
 return null;
}

// HandleServerToPlayerMapPinEnabled1407a3cb0..1407a3e7b. The final
// underflow check can return0 AFTER an existing pin and GUI have changed.
export async function receiveMapPinEnabled(message,p){
 if(message.messageReadOverflow())return 0;
 const id=message.readObjectIdClient(),enabled=message.readBool(),pin=await p.find(await p.area(),id,0);
 if(pin){pin.nativeEnabled170=enabled|0;const gui=await p.gui();if(gui)await p.refresh(gui,1);}
 return message.messageReadUnderflow()?0:1;
}

// HandleServerToPlayerMapPin1407a3810..1407a3982, profiling disabled.
export async function receiveMapPin(message,minor,p){
 switch(minor&255){case 1:return receiveMapPinEnabled(message,p);case 4:return p.referenceNumber(message);case 6:return receiveMapPinCreated(message,p);default:return 0;}
}
