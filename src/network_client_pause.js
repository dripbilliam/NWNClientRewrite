// Original module3/9: sender4dd0c0 -> receiver7a5680. This is a detached
// protocol DTO only; clock/flag/list transitions belong to a separate owner.
// ReadBOOL is one wire bit (not Boolean(senderInteger)). Client OBJECTIDs are
// copied unchanged; do not clear or add the external namespace bit here.
export function readNetworkClientPause(reader){
 const mask=reader.readByte(2,1),value=reader.readBool(),count=reader.readWord(16);
 // Every declared OBJECTID requires four byte-stream bytes, independently of
 // residual mask/BOOL bits. Reject before allocating/looping on a false count.
 if(reader.messageReadOverflow()||count>Math.floor((reader.byteSize40-reader.byteCursor44)/4))throw Error('Invalid native module-pause exclusion count');
 const exclusionIds=[];
 for(let index=0;index<count;index++)exclusionIds.push(reader.readObjectIdClient());
 // Native7a5680 checks overflow only. Exact underflow rejection is the remote
 // decoder's stricter admission contract: extra undeclared data is not applied.
 if(reader.messageReadOverflow()||reader.messageReadUnderflow())throw Error('Invalid native module-pause fields');
 return{kind:'module-pause-state',mask,value,exclusionIds};
}
