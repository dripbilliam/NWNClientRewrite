import {decodeGffText} from './gff_text.js';
const text=r=>{const s=r.readCExoString();return s.bytes?decodeGffText(s.bytes):'';};
const localized=r=>r.readBool()?{gender:r.readByte(1),strRef:r.readDword()}:{text:text(r)};
const count=(r,n,min)=>{if(n<0||n>Math.floor((r.byteSize40-r.byteCursor44)/min))throw new Error('Invalid native journal entry count');return n;};

// Client7a0c10 dispatch; full quest/update fields mirror4db220 and7a1d30.
export function readNetworkJournal(r,minor){
 const message={kind:'journal',operation:minor};
 if(minor===6){message.entry={title:localized(r),description:localized(r),date:r.readDword(),time:r.readDword(),tag:text(r),state:r.readInt(),priority:r.readDword(),picture:r.readWord(),completed:r.readBool(),isQuest:true};}
 else if(minor===7)message.tag=text(r);
 else if(minor===8){message.tag=text(r);message.picture=r.readInt();}
 else if(minor===9){message.present=r.readBool();if(message.present){message.full=r.readBool();message.entries=Array.from({length:count(r,r.readInt(),6)},()=>{
   const mask=r.readWord(),entry={mask,tag:text(r)};if(mask&0x4000)return entry;
   for(const [bit,key,read]of [[1,'title',()=>localized(r)],[2,'description',()=>localized(r)],[4,'date',()=>r.readDword()],[8,'time',()=>r.readDword()],[16,'state',()=>r.readInt()],[32,'priority',()=>r.readDword()],[64,'picture',()=>r.readWord()],[128,'completed',()=>r.readBool()]])if(message.full||(mask&(0x8000|bit)))entry[key]=read();entry.isQuest=(mask&0x100)===0;return entry;
  });}}
 else if(minor===12){message.title=localized(r);message.quest=r.readBool();message.changed=r.readBool();}
 else if(minor===1)message.worldEntry={id:r.readInt(),title:{text:text(r)},description:{text:text(r)},date:r.readDword(),time:r.readDword()};
 else if(minor===2)message.worldEntry={id:r.readDword(),strRef:r.readDword(),date:r.readDword(),time:r.readDword()};
 else if(minor===3)message.worldId=r.readInt();
 else if(minor===4)message.worldStrRef=r.readDword();
 else if(minor===5)message.clear=r.readByte();
 return message;
}
// Native sender4da310, major48/minor1. Elapsed presentation never recovers
// gameplay resources; stop/ready events still come from the server.
export function readNetworkTiming(r){const active=r.readBool();return{kind:'gui-timing',active,...(active?{duration:r.readDword(),type:r.readByte()}: {})};}
// Client7a7250 consumes sender and target PLAYER_ID DWORDs, then two BOOLs.
export function readNetworkAttitude(r){return{kind:'player-attitude',sourcePlayerId:r.readDword(),playerId:r.readDword(),likes:r.readBool(),clear:r.readBool()};}
// Native map pin creation4dc2d0 and enable4dc3f0; these are client map notes,
// not new canonical object allocation by this renderer.
export function readNetworkMapPin(r,minor){const id=r.readObjectIdClient();return minor===1?{kind:'map-pin-enabled',id,enabled:r.readBool()}:{kind:'map-pin-created',id,position:[r.readFloat(),r.readFloat(),r.readFloat()],name:localized(r),enabled:r.readBool()};}
