import {satisfiesNativeBuild} from './network_build.js';
const atLeast=(b,r,p=0)=>satisfiesNativeBuild(b,{number:8193,revision:r,postfix:p});
const bounded=(r,n,min=1)=>{if(!Number.isInteger(n)||n<0||n>Math.floor((r.byteSize40-r.byteCursor44)/min))throw new Error('Invalid native inventory stats count');return n;};

// Client7b2740. Preserve native field offsets until their meaning is proven;
// this is replicated character-sheet information, never local rules results.
export function readInventoryStats(r,build,{skillCount,unsupported=reason=>{throw new Error(reason);}}={}){
 const id=r.readObjectIdClient(),mask=r.readDword(),s={},record={action:'inventory-stats',id,objectType:5,mask,state:s};
 if(mask&1){s.fields70=Array.from({length:6},()=>r.readByte());s.fields7d=Array.from({length:6},()=>r.readChar());s.fields76=Array.from({length:7},()=>r.readChar());}
 for(const [bit,key]of [[2,'field98'],[4,'field99'],[8,'field9a'],[0x2000,'field9c'],[0x4000,'field9d'],[0x8000,'field9e']])if(mask&bit)s[key]=r.readChar();
 if(mask&16)s.field94=r.readDword();if(mask&32){s.field9b=r.readByte();s.fielda0=r.readBool();}
 if(mask&64){
  const c={field0:r.readByte(3),field1:r.readChar(),field2:r.readChar(),field5:r.readChar(),field6:r.readByte(7),field7:r.readByte(5),field8:r.readByte(5),field9:r.readByte(5)};
  c.triplets=Array.from({length:3},()=>[r.readByte(5),r.readByte(5),r.readChar()]);c.field13=r.readByte(4);c.field14=r.readByte(3);c.field18=r.readBool();
  if(c.field18){c.field3=r.readChar();c.field4=r.readChar();c.field1c=r.readByte(4);c.field1d=r.readByte(3);}
  const node=second=>{const n={field0:r.readChar()};if(second)n.field1=r.readByte(atLeast(build,35)?5:4);n.field2=r.readByte(3);n.field5=r.readBool()?r.readByte():28;n.field3=r.readBool()?r.readByte(2):0;n.field4=r.readBool()?r.readByte(3):0;return n;};
  c.group0=Array.from({length:bounded(r,r.readByte())},()=>node(false));c.group1=Array.from({length:bounded(r,r.readByte())},()=>node(true));s.combatInformation=c;
 }
 if(mask&0x400)s.field8c=r.readShort();if(mask&0x800){s.field88=r.readShort();s.field8a=r.readShort();}
 if(mask&128){
  if(!Number.isInteger(skillCount)||skillCount<0||skillCount>255)return unsupported('Inventory skill schema is unavailable');
  const bits=r.readDword(skillCount);s.skills=[];for(let index=0;index<skillCount;index++)if(bits&(1<<(index&31)))s.skills.push({index,value:r.readChar(),flag:r.readBool()});
 }
 if(mask&256){
  // Assembly3234/3280/32d3/3320 supplies postfix2 at every call,
  // including calls whose decompiler display omits the fourth argument.
  const wide=atLeast(build,37,2),feat=()=>wide?r.readWord():r.readByte();s.featsRemoved=Array.from({length:bounded(r,feat(),wide?2:1)},feat);
  s.featsAdded=Array.from({length:bounded(r,feat(),wide?2:1)},()=>({id:feat(),flag:r.readBool()}));
 }
 if(mask&512){s.fields118=Array.from({length:bounded(r,r.readWord(),2)},()=>r.readWord());s.fields128=Array.from({length:bounded(r,r.readWord(),2)},()=>r.readWord());}
 if(mask&0x1000)s.fieldsClass=Array.from({length:bounded(r,r.readByte())},()=>r.readByte());return record;
}
