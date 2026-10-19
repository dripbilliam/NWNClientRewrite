import {decodeGffText} from './gff_text.js';
const text=r=>{const v=r.readCExoString();return v.bytes?decodeGffText(v.bytes):'';};
const localized=r=>r.readBool()?{gender:r.readByte(1),strRef:r.readDword()}:{text:text(r)};
const ref=r=>{const b=r.readCResRef(),end=b.indexOf(0);return decodeGffText(end<0?b:b.subarray(0,end));};
// Original PlayerList_All4de710/Add4de300 share this entry schema. Preserve
// unknown server140/peerD8/peerC8 fields without guessing their UI semantics.
function entry(r){
 const p={playerId:r.readDword(),objectId:r.readObjectIdClient(),isDM:r.readBool(),name:text(r)},hasCharacter=r.readBool();
 p.peerD8=r.readByte();p.peerC8=text(r);
 if(hasCharacter){p.character={id:r.readObjectIdClient(),firstName:localized(r),lastName:localized(r),portrait:r.readWord()};if(p.character.portrait>0xfffd)p.character.portraitRef=ref(r);}
 return p;
}
export function readPlayerList(r,minor){
 const server140=r.readBool();
 if(minor===3)return{kind:'player-list-delete',server140,playerId:r.readDword()};
 const players=[],count=minor===1?r.readByte():1;
 if(count>Math.floor((r.byteSize40-r.byteCursor44)/17))throw new Error('Invalid native player-list count');
 for(let i=0;i<count;i++)players.push(entry(r));
 return{kind:minor===1?'player-list-all':'player-list-add',server140,players};
}
