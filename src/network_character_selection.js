import {NativeMessageWriter} from './native_message.js';
import {decodeGffText,encodeGffText} from './gff_text.js';
import {MAX_NETWORK_CHARACTER_BYTES} from './network_character.js';
const text=r=>{const v=r.readCExoString();return v.bytes?decodeGffText(v.bytes):'';};
const localized=r=>r.readBool()?{gender:r.readByte(1),strRef:r.readDword()}:{text:text(r)};
const reference=r=>{const b=r.readCResRef(),end=b.indexOf(0);return decodeGffText(end<0?b:b.subarray(0,end));};
const validSource=value=>[2,14,17].includes(value);
export function selectionReference(value){
 if(typeof value!=='string'||!value.length||/[\x00-\x1f/\\:]/.test(value))throw new Error('Invalid server character reference');
 const bytes=encodeGffText(value);if(bytes.length>16)throw new Error('Invalid server character reference');const result=new Uint8Array(16);result.set(bytes);return result;
}
const packet=(major,minor,write)=>{const w=new NativeMessageWriter(1);w.create(128,0xffffffff,1);write(w);w.setPrefix(Uint8Array.of(112,major,minor));return Uint8Array.from(w.getWriteMessage().data);};
// HandlePlayerToServerCharListMessage444a00: request17/1 is empty.
export const serverCharacterListRequest=()=>Uint8Array.of(112,17,1);
// PlayModuleCharacterListStart45c5e0 / Stop45c690 subscribe to connected PCs.
export const lobbyPlayerListRequest=open=>Uint8Array.of(112,49,open?1:2);
export function readLobbyPlayer(r){
 const present=r.readBool(),id=r.readDword(),character={id};
 if(present){character.firstName=localized(r);character.lastName=localized(r);character.portrait=r.readWord();if(character.portrait>0xfffd)character.portraitRef=reference(r);const count=r.readByte();if(count>Math.floor((r.byteSize40-r.byteCursor44)/2))throw new Error('Invalid lobby player classes');character.classes=[];for(let i=0;i<count;i++)character.classes.push({id:r.readByte(),level:r.readByte()});}
 return{kind:'server-character-player',present,character};
}
// UpdateCharResponse4e12d0:1=base SERVERVAULT,5=account SERVERVAULT,
// 4=module saved player. List records carry admission subtype2/17/14.
export function serverCharacterPreviewRequest({source,resref}){
 if(!validSource(source))throw new Error('Unsupported server character source');const ref=selectionReference(resref),type=source===17?5:source===14?4:1;
 return packet(17,3,w=>{w.writeByte(type);w.writeCResRef(ref);});
}
// Login handler457850 passes the exact advertised reference to LoadCharacterStart.
export function serverCharacterPlayRequest({source,resref}){
 if(!validSource(source))throw new Error('Unsupported server character source');const ref=selectionReference(resref);return packet(2,source,w=>w.writeCResRef(ref));
}
// SendServerToPlayerCharList4d1260: localized names, CResRef, source,
// portrait WORD + unconditional custom CResRef, class BYTE count + INT/BYTE.
export function readServerCharacterList(r){
 const count=r.readWord(),characters=[];if(count>Math.floor((r.byteSize40-r.byteCursor44)/44))throw new Error('Invalid server character list count');
 for(let i=0;i<count;i++){
  const firstName=localized(r),lastName=localized(r),resref=reference(r),source=r.readByte(),portrait=r.readWord(),portraitRef=reference(r),classCount=r.readByte(),classes=[];
  if(classCount>Math.floor((r.byteSize40-r.byteCursor44)/5))throw new Error('Invalid server character class count');
  for(let j=0;j<classCount;j++)classes.push({id:r.readInt(),level:r.readByte()});
  if(!validSource(source))throw new Error('Unsupported server character list source');selectionReference(resref);
  characters.push({firstName,lastName,resref,source,portrait,portraitRef,classes});
 }
 return{kind:'server-character-list',characters};
}
//17/4 transfers the server's SaveStats BIC for inspection, never character upload.
export function readServerCharacterPreview(r){
 const previewType=r.readByte(),resref=reference(r),length=r.readDword();if(![1,4,5].includes(previewType)||length>MAX_NETWORK_CHARACTER_BYTES||length>r.byteSize40-r.byteCursor44)throw new Error('Invalid server character preview');
 const data=r.readOpaqueBytes(length);if(data===null)throw new Error('Invalid server character preview bytes');return{kind:'server-character-preview',previewType,resref,data:Uint8Array.from(data)};
}
