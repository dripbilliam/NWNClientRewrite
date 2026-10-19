import {decodeGffText} from './gff_text.js';

const text=r=>{const value=r.readCExoString();return value.bytes?decodeGffText(value.bytes):'';};
const localized=r=>r.readBool()?{gender:r.readByte(1),strRef:r.readDword()}:{text:text(r)};
// Original client7962f0, ReadCExoLocStringClient9735f0, reply UI6fb8e0.
// IDs/flags remain server values. Client never evaluates DLG conditions/scripts.
export function readNetworkDialog(r,minor){
 if(minor===5)return{kind:'dialog-close'};
 if(minor===1)return{kind:'dialog-entry',ownerId:r.readObjectIdClient(),speakerId:r.readObjectIdClient(),tokenObjectId:r.readObjectIdClient(),text:localized(r)};
 if(minor===2){
  const entryId=r.readDword(),end=r.readBool(),flag1=r.readBool(),tokenObjectId=r.readObjectIdClient(),firstCount=r.readDword(),secondCount=r.readDword(),n=firstCount+secondCount;
  if(!Number.isSafeInteger(n)||n>Math.floor((r.byteSize40-r.byteCursor44)/8))throw new Error('Invalid native dialog reply count');
  const replies=[];for(let i=0;i<n;i++)replies.push({text:localized(r),id:r.readDword()});
  return{kind:'dialog-replies',entryId,end,flag1,tokenObjectId,firstCount,secondCount,replies};
 }
 if(minor===4)return{kind:'dialog-selected',end:r.readByte(),field0:r.readDword(),field1:r.readDword(),tokenObjectId:r.readObjectIdClient(),text:localized(r)};
 throw new Error('Native dialog subtype is unavailable');
}
