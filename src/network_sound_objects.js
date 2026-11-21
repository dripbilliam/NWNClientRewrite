import {decodeGffText} from './gff_text.js';
const fields=(r,offsets,method,target)=>{for(const offset of offsets)target[offset.toString(16)]=r[method]();};
// Shared inverse of CNWSSoundObject::PackIntoMessage4f5120. Both area4/1
// and standalone23/6 carry this exact packed record, including its own ID.
export function readNetworkSoundState(r){
 const sound={id:r.readObjectIdClient(),fields:{}},s=sound.fields;
 fields(r,[0x308,0x30c,0x310],'readBool',s);fields(r,[0x314,0x318,0x31c],'readByte',s);fields(r,[0x320],'readFloat',s);fields(r,[0x324],'readDword',s);fields(r,[0x328],'readByte',s);
 fields(r,[0x348,0x34c],'readDword',s);fields(r,[0x350,0x354],'readFloat',s);fields(r,[0x358,0x35c,0x32c],'readBool',s);fields(r,[0x330,0x334],'readFloat',s);
 sound.position=[r.readFloat(),r.readFloat(),r.readFloat()];sound.refs=[];const count=r.readWord();if(count>Math.floor((r.byteSize40-r.byteCursor44)/16))throw new Error('Invalid native sound-reference count');
 for(let i=0;i<count;i++){const raw=r.readCResRef(),end=raw.indexOf(0);sound.refs.push(decodeGffText(end<0?raw:raw.subarray(0,end)));}return sound;
}
// Client7b0000 admits only minors2..7. Commands reference existing sound
// objects; creation has an outer lookup ID, area ID and packed inner ID.
export function readNetworkSoundObject(r,operation){
 const objectId=r.readObjectIdClient(),message={kind:'sound-object',operation,objectId};
 if(operation===4)message.volume=r.readInt();
 else if(operation===5)message.position=[r.readFloat(),r.readFloat(),r.readFloat()];
 else if(operation===6){message.areaId=r.readObjectIdClient();message.sound=readNetworkSoundState(r);}
 else if(![2,3,7].includes(operation))throw new Error('Unsupported native sound-object command');
 return message;
}
