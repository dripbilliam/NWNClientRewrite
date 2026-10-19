import {decodeGffText} from './gff_text.js';import {satisfiesNativeBuild} from './network_build.js';
const text=r=>{const v=r.readCExoString();return v.bytes?decodeGffText(v.bytes):'';};
const loc=r=>r.readBool()?{gender:r.readByte(1),strRef:r.readDword()}:{text:text(r)};
const description=r=>r.readBool()?{text:text(r)}:loc(r);
const ref=r=>{const b=r.readCResRef(),end=b.indexOf(0);return decodeGffText(end<0?b:b.subarray(0,end));};
const bounded=(r,n,size)=>{if(n<0||n>Math.floor((r.byteSize40-r.byteCursor44)/size))throw new Error('Invalid native examination list count');return n;};
// Client79d350 routes server27/2..6. Preserve fields and disclosure gates;
// descriptions, identification, properties and CR are decided by the server.
export function readNetworkExamine(r,minor,build){
 const targetId=r.readObjectIdClient(),out={kind:'examine',targetId,type:({2:'item',3:'creature',4:'placeable',5:'trap',6:'door'})[minor]};
 if(minor===2){if(targetId===0x7f000000)return{...out,close:true};out.actorId=r.readObjectIdClient();out.identified=r.readBool();if(out.identified)out.canUse=r.readBool();out.description=description(r);out.meetsLevel=r.readBool();if(!out.meetsLevel)out.minimumLevel=r.readByte();out.baseItem=r.readInt();out.weight=r.readInt();if(r.readBool())out.value=r.readDword();if(out.identified)out.properties=Array.from({length:bounded(r,r.readWord(),7)},()=>({type:r.readWord(),subtype:r.readWord(),costValue:r.readWord(),uses:r.readByte(),usable:r.readBool()}));}
 else if(minor===3){out.description=description(r);out.hasDetails=r.readBool();if(out.hasDetails){if(r.readBool())out.name={firstName:loc(r),lastName:loc(r)};else out.name={text:text(r)};out.portraitId=r.readWord();if(out.portraitId>=0xfffe)out.portrait=ref(r);out.damageLevel=r.readByte();out.reaction=r.readByte();if(r.readBool())out.challengeRating=r.readFloat();if(r.readBool()){const wide=satisfiesNativeBuild(build,{number:8193,revision:37,postfix:2});out.effects=Array.from({length:bounded(r,wide?r.readWord():r.readByte(),wide?2:1)},()=>wide?r.readWord():r.readByte());}if(r.readBool()){out.playerLevel=r.readInt();out.playerFlags=r.readDword();}}}
 else if(minor===5){out.success=r.readBool();if(r.readBool())out.name={text:text(r)};out.trapType=r.readByte();out.assessment=r.readByte();}
 else out.description=description(r);
 return out;
}
