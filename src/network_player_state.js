import {satisfiesNativeBuild} from './network_build.js';
import {decodeGffText} from './gff_text.js';
const text=r=>{const v=r.readCExoString();return v.bytes?decodeGffText(v.bytes):'';};
const atLeast=(b,revision,postfix=0)=>satisfiesNativeBuild(b,{number:8193,revision,postfix});
function count(r,n,min,label){if(!Number.isInteger(n)||n<0||n>Math.floor((r.byteSize40-r.byteCursor44)/min))throw new Error(`Invalid native player ${label} count`);return n;}
const list=(r,n,min,label,read)=>Array.from({length:count(r,n,min,label)},read);
const char=r=>String.fromCharCode(r.readChar()&255);
function levelCounts(r){
 const n=count(r,r.readByte(),3,'spell-class change'),changes=[];
 if(n>8)throw new Error('Invalid native spell-class change count');
 for(let i=0;i<n;i++){
  const position=r.readByte(),mask=r.readWord(),levels=[];if(position>=8||mask&~1023)throw new Error('Invalid native spell-class level mask');
  for(let level=0;level<10;level++)if(mask&(1<<level))levels.push({level,count:r.readByte()});changes.push({position,levels});
 }
 return changes;
}

// WriteGuiEffectIconsUpdate4ee2d0.8193.37.2 widens icon IDs/counts from BYTE
// to WORD; the Boolean is the native icon state, not an effect identity.
export function readPlayerEffectIcons(r,build){
 const id=()=>atLeast(build,37,2)?r.readWord():r.readByte();
 const removed=list(r,id(),atLeast(build,37,2)?2:1,'removed effect-icon',id);
 const added=list(r,id(),atLeast(build,37,2)?2:1,'added effect-icon',()=>({icon:id(),state:r.readBool()}));return{removed,added};
}

// Complete wire-field inverse of WriteGameObjUpdate_PlayerUpdate4e8420.
// The I record describes this connection's controlled creature. The source
// owner computes differences; this client applies the transmitted differences.
export function readPlayerState(r,build,p={}){
 const id=r.readObjectIdClient(),mask=r.readWord(),state={},record={action:'player-state',objectType:5,id,mask,state};
 if(mask&1){
  state.combat={armorClass:r.readShort(),field898:r.readDword(),field978:r.readInt(),canLevelUp:r.readBool()};
  if(state.combat.canLevelUp){
   const n=p.skillCount;if(!Number.isInteger(n)||n<0||n>255)p.unsupported?.('Native skill-count owner for level-up state is unavailable');
   if(!Number.isInteger(n)||n<0||n>255)throw new Error('Native skill-count owner is unavailable');
   state.levelUp={fieldDC6:r.readWord(),skills:list(r,n,1,'level-up skill',()=>r.readChar()),fieldE34:r.readInt(),fieldE48:text(r),fieldE30:r.readInt(),fieldE38:text(r),fieldD4:atLeast(build,36,4)?r.readDword():r.readByte(),fieldC0:r.readByte()};
  }
 }
 if(mask&2)state.skillFlags=r.readDword();if(mask&8)state.playerFlags=r.readDword();
 if(mask&0x8000)state.fields9E8=[r.readInt(),r.readInt(),r.readInt()];
 if(mask&128)state.memorizedSlotCounts=levelCounts(r);
 const classSlots=atLeast(build,35)?8:3;
 if(mask&16){
  state.knownSpellChanges=[];
  // ComputeLastUpdate_GuiKnownSpells4c9ae0 stores removals at b98 and
  // additions at c18; the serializer writes those lists in that order.
  for(let position=0;position<classSlots;position++)state.knownSpellChanges.push({position,removed:list(r,r.readWord(),4,'known spell removal',()=>r.readDword()),added:list(r,r.readWord(),4,'known spell addition',()=>r.readDword())});
 }
 if(mask&32){
  state.memorizedSpellChanges=[];
  for(let position=0;position<classSlots;position++)state.memorizedSpellChanges.push({position,
   removed:list(r,r.readWord(),2,'prepared-spell removal',()=>({level:r.readByte(),index:r.readByte()})),
   // GuiMemorizedSpells4c9d80 constructs these native10-byte records:
   // DWORD spell, BOOL ready/domain, BYTE metamagic/index/level at c/d/e.
   added:list(r,r.readWord(),7,'prepared-spell addition',()=>({spell:r.readDword(),index:r.readByte(),level:r.readByte(),ready:r.readBool(),domain:r.readBool(),metamagic:r.readByte()}))});
 }
 if(mask&64)state.spontaneousUses=levelCounts(r);
 if(mask&0x400)state.effectIcons=readPlayerEffectIcons(r,build);
 if(mask&4){
  state.featChanges=list(r,r.readWord(),3,'feat change',()=>{const action=char(r),feat=r.readWord();if(!['A','B','D','X'].includes(action))throw new Error('Invalid native feat-change action');return{action,feat};});
  state.featUses=list(r,r.readWord(),3,'feat use',()=>({feat:r.readWord(),uses:r.readByte()}));
 }
 if(mask&0x200){
  // Original mask0x200 reader gives the packed flag priority. Both bits
  // set is valid; rejecting it loses the rest of this server message.
  const mode=[r.readBool(),r.readBool()];
  const map={mode};
  if(mode[1])map.bytes=Uint8Array.from(list(r,r.readByte(),1,'automap byte',()=>r.readByte()));
  else map.points=list(r,r.readDword(),2,'automap point',()=>mode[0]?{x:r.readByte(),y:r.readByte()}:{state:r.readBool(),x:r.readByte(),y:r.readByte()});
  state.automap=map;
 }
 if(mask&256){
  state.actionQueueChanges=list(r,r.readByte(),5,'action-queue change',()=>{
   const action=char(r),entry={action,type:r.readWord(),group:r.readWord()};
   if(action==='D')return entry;
   if(action==='S'||action==='U'){entry.target=r.readObjectIdClient();return entry;}
   if(action!=='A')throw new Error('Invalid native action-queue change');
   if(entry.type!==0&&entry.type!==2)entry.target=r.readObjectIdClient();
   if([0,2,4,12,19].includes(entry.type))entry.position=[r.readFloat(),r.readFloat(),r.readFloat()];
   if(entry.type===4||entry.type===19)entry.field5A4=r.readDword();return entry;
  });
 }
 if(mask&0x2000){state.visibilityChanges={removed:list(r,r.readDword(),4,'visibility removal',()=>r.readObjectIdClient()),updated:list(r,r.readDword(),4,'visibility update',()=>({id:r.readObjectIdClient(),flags:[r.readBool(),r.readBool(),r.readBool()]}))};}
 if(mask&0x800)state.abilities=r.readBool()?{base:Array.from({length:6},()=>r.readByte()),current:Array.from({length:6},()=>r.readByte())}:null;
 if(mask&0x4000)state.specialAbilityChanges=list(r,r.readWord(),3,'special ability change',()=>{
  const action=String.fromCharCode(r.readByte());if(action==='S')return{action,size:r.readWord()};
  if(action==='U')return{action,index:r.readWord(),state:r.readBool(),level:r.readByte(),spell:r.readWord()};throw new Error('Invalid native special-ability change');
 });
 return record;
}
