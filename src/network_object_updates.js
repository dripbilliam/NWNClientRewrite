import {satisfiesNativeBuild} from './network_build.js';
import {decodeGffText} from './gff_text.js';
import {readPlayerState} from './network_player_state.js';
import {readInventoryStats} from './network_inventory_stats.js';
import {readQuickbarItemUses} from './network_item_uses.js';
const text=r=>{const v=r.readCExoString();return v.bytes?decodeGffText(v.bytes):'';};
const localized=r=>r.readBool()?{gender:r.readByte(1),strRef:r.readDword()}:{text:text(r)};
const named=r=>r.readBool()?localized(r):{text:text(r)};
const vector=r=>[r.readFloat(),r.readFloat(),r.readFloat()];
const atLeast=(build,revision,postfix=0)=>satisfiesNativeBuild(build,{number:8193,revision,postfix});
function count(r,n,min,label){if(!Number.isInteger(n)||n<0||n>Math.floor((r.byteSize40-r.byteCursor44)/min))throw new Error(`Invalid native ${label} count`);return n;}
class UnhandledRecord extends Error{}

// ObjectVisualTransformData::Write596760 ->596610 ->596980. The two map
// passes (keys, then keyed values) are distinct and both must be consumed.
export function readObjectVisualTransform(r,build){
 const leaf=()=>{
  if(atLeast(build,35)&&r.readBool())return{identity:true};
  const channels=[];
  for(let i=0;i<10;i++){
   const c={value:r.readFloat()};
   if(atLeast(build,21)){c.type=r.readInt();c.duration=r.readInt();if(c.duration!==0){c.target=r.readFloat();c.parameter=r.readFloat();c.progress=r.readFloat();if(atLeast(build,35)){c.field18=r.readInt();c.field1c=r.readInt();}}}channels.push(c);
  }
  return{channels};
 };
 if(!atLeast(build,35))return{legacy:leaf()};
 const keys=[],entries=[];let n=count(r,r.readInt(),4,'visual-transform key');for(let i=0;i<n;i++)keys.push(r.readInt());
 n=count(r,r.readInt(),4,'visual-transform entry');for(let i=0;i<n;i++)entries.push({key:r.readInt(),value:leaf()});return{keys,entries};
}

function itemAppearance(r,build,p){
 const item={baseItem:r.readDword()},model=p.baseItemModelType?.(item.baseItem);
 if(!Number.isInteger(model))throw new UnhandledRecord(`Base-item model type ${item.baseItem} is unavailable`);
 const part=()=>atLeast(build,35)?r.readWord():r.readByte();item.modelType=model;
 if(model===0||model===1||model===2)item.parts=Array.from({length:model===2?3:1},part);
 if(model===3)item.parts=Array.from({length:19},part);
 if(model===1||model===3)item.colors=Array.from({length:6},()=>r.readByte());
 if(model===3)item.partColors=Array.from({length:19},()=>Array.from({length:6},()=>r.readByte()));
 if(model===2)item.field462=r.readByte();item.visualTransform=readObjectVisualTransform(r,build);return item;
}
function activeItemProperties(r,build,item){
 if(item.baseItem===16)item.field35c=r.readShort();
 item.name=named(r);item.identified=r.readBool();item.cost=r.readDword();item.field454=r.readDword();item.canUse=r.readBool();item.field458=r.readBool();item.field450=r.readBool();item.field468=r.readBool();
 if(atLeast(build,36,2)){item.field2b8=r.readInt();item.field2c0=text(r);}
 const n=count(r,r.readByte(),7,'active-item property');item.properties=[];
 for(let i=0;i<n;i++)item.properties.push({type:r.readWord(),subtype:r.readWord(),costValue:r.readWord(),field9:r.readByte()});
 item.field350=r.readByte();item.reserved=r.readByte();item.field351=Array.from({length:8},(_,i)=>item.reserved&(1<<i)?r.readByte():null);return item;
}
export const readNetworkItem=(r,build,p)=>activeItemProperties(r,build,itemAppearance(r,build,p));
function inventoryEntry(r,build,p){
 const action=String.fromCharCode(r.readChar()&255),id=r.readObjectIdClient(),slot=r.readDword(),entry={action,id,slot};
 if(action==='D')return entry;
 if(action==='A')return{...entry,item:activeItemProperties(r,build,itemAppearance(r,build,p))};
 throw new UnhandledRecord(`Inventory appearance action ${action} is unavailable`);
}

// ClientG dispatcher7b3c90: no record lengths. Repository7b4620,
// container7b3790, equipment7b3f30 all use item reader79fe30, whose
// appearance79fac0 and active fields76bd30 match the existing item helpers.
function guiInventory(r,build,p){
 const channel=String.fromCharCode(r.readChar()&255);
 if(channel==='Q')return readQuickbarItemUses(r);
 if(channel==='S')return readInventoryStats(r,build,{...p,unsupported:reason=>{throw new UnhandledRecord(reason);}});
 if(!['R','r','A','B','C','c','I','i'].includes(channel))throw new UnhandledRecord(`Inventory channel ${channel} is unavailable`);
 const operation=String.fromCharCode(r.readChar()&255),entry={action:'inventory',channel,operation};
 const equipped=channel==='I'||channel==='i',container=channel==='C'||channel==='c';
 if(operation==='P'&&container){entry.page=r.readByte();return entry;}
 if(operation==='U'&&equipped){entry.state={field28c:r.readInt(),field8c:r.readShort(),field70:r.readByte()};return entry;}
 if(operation==='A'){
  if(equipped)entry.slot=r.readDword();else{entry.x=r.readByte();entry.y=r.readByte();}
  entry.id=r.readObjectIdClient();entry.item=activeItemProperties(r,build,itemAppearance(r,build,p));return entry;
 }
 if(operation==='D'){if(equipped)entry.slot=r.readDword();else entry.id=r.readObjectIdClient();return entry;}
 if(operation==='U'){entry.id=r.readObjectIdClient();entry.stackSize=r.readDword();entry.field280=r.readDword();return entry;}
 if(operation==='M'&&!equipped){entry.x=r.readByte();entry.y=r.readByte();entry.id=r.readObjectIdClient();return entry;}
 throw new UnhandledRecord(`Inventory ${channel}/${operation} is unavailable`);
}

// CreateNewLastUpdateObject4cbb70 emits A records before appearance/U deltas.
// New creature positions/orientations are full FLOATs, unlike quantized U.
function creation(r,build,p){
 const objectType=r.readByte(),id=r.readObjectIdClient(),record={action:'create',objectType,id,state:{}};const s=record.state;
 if(objectType===5){s.position=vector(r);s.orientation=vector(r);s.animation=r.readWord();s.visualTransform=readObjectVisualTransform(r,build);}
 else if(objectType===6)s.item=activeItemProperties(r,build,itemAppearance(r,build,p));
 else if(objectType===10){
  s.doorType=r.readDword();if(s.doorType===0)s.genericType=r.readDword();s.visualTransform=readObjectVisualTransform(r,build);s.name=named(r);s.reaction=r.readBool();s.animation=r.readWord();s.field424=r.readBool();s.field428=r.readBool();s.fieldFC=r.readBool();s.hasTransition=r.readBool();
 }else if(objectType===11){s.field30c=r.readInt();s.creator=r.readObjectIdClient();}
 else if(objectType===9){
  s.name=named(r);s.field540=r.readByte();s.reaction=r.readBool();s.appearance=r.readWord();s.animation=r.readWord();s.field514=r.readBool();if(s.field514)s.field510=r.readObjectIdClient();
  for(const key of ['fieldFC','field264','field3BC','field500','field378','field4FC','hasDescription','lightOn'])s[key]=r.readBool();s.visualTransform=readObjectVisualTransform(r,build);
 }
 else if(objectType===7){
  s.name=localized(r);s.isTrap=r.readBool();s.hasTransition=r.readBool();s.displayType=r.readByte();if(s.isTrap)s.reaction=r.readBool();s.field40c=r.readFloat();s.vertices=[];const n=count(r,r.readByte(),12,'trigger vertex');for(let i=0;i<n;i++)s.vertices.push(vector(r));
 }else throw new UnhandledRecord(`Object creation type ${objectType} is unavailable`);
 return record;
}

// WriteGameObjUpdate_UpdateAppearance4ea6c0: native WORD mask, sparse/full
// nineteen-part body changes, followed by counted equipment-appearance deltas.
function appearance(r,build,p){
 const objectType=r.readByte(),id=r.readObjectIdClient(),mask=r.readWord(),s={},record={action:'appearance',objectType,id,mask,state:s};
 if(objectType!==5)throw new Error('Invalid native creature appearance type');
 if(mask&0x400)s.name=r.readBool()?{firstName:localized(r),lastName:localized(r)}:{text:text(r)};
 const part=()=>atLeast(build,35)?r.readWord():r.readByte();
 if(mask&1)s.appearance=r.readWord();if(mask&2)s.phenotype=r.readByte();if(mask&4)s.gender=r.readByte();if(mask&128)s.head=part();
 if(mask&0x800)s.fieldAA4=r.readDword();if(mask&0x1000)s.fieldAA8=r.readDword();
 for(const [bit,name]of [[8,'skin'],[16,'hair'],[32,'tattoo1'],[64,'tattoo2']])if(mask&bit)s[name]=r.readByte();
 if(mask&256){const n=r.readByte();if(n>19)throw new Error('Invalid native creature body-part count');s.bodyParts=[];if(n<10){for(let i=0;i<n;i++){const index=r.readByte();if(index>=19)throw new Error('Invalid native creature body-part index');s.bodyParts.push({index,value:part()});}}else for(let index=0;index<19;index++)s.bodyParts.push({index,value:part()});}
 if(mask&0x2000){s.field8A0=r.readWord();s.field8A4=r.readInt();}if(mask&0x4000&&atLeast(build,14))s.field8F0=r.readByte();
 if(mask&512){s.equipment=[];const n=count(r,r.readByte(),9,'equipment appearance');for(let i=0;i<n;i++)s.equipment.push(inventoryEntry(r,build,p));}
 return record;
}

function update(r,build,p){
 const objectType=r.readByte(),id=r.readObjectIdClient(),mask=r.readDword(),s={},record={action:'update',objectType,id,mask,state:s};
 if(mask&1)s.position=[r.readFloat(100,16),r.readFloat(100,16),r.readFloatRange(-20,320,18)];
 if(mask&2){s.orientation=r.readBool()?{vector:[r.readFloatRange(-2,2,16),r.readFloatRange(-2,2,16),r.readFloatRange(-2,2,16)]}:{yaw:r.readFloat(10,12)};if(objectType===5)s.facingTarget=r.readBool()?r.readObjectIdClient():0x7f000000;}
 if(mask&0x100000)s.visualTransform=readObjectVisualTransform(r,build);
 if(mask&0x200000){s.uniforms=[];const n=count(r,r.readWord(),9,'shader uniform');for(let i=0;i<n;i++){const u={type:r.readByte()};if(u.type===1)u.value=r.readInt();else if(u.type===2)u.value=Array.from({length:4},()=>r.readFloat());u.name=text(r);u.selector=text(r);s.uniforms.push(u);}}
 if(mask&32){s.portrait=r.readWord();if(s.portrait>0xfffd){const b=r.readCResRef();s.portraitRef=decodeGffText(b.subarray(0,b.indexOf(0)<0?b.length:b.indexOf(0)));}}
 if(mask&0x400000){s.light={};if(atLeast(build,14)){s.light.position=vector(r);s.light.field260=r.readInt();}if(atLeast(build,35)){s.light.field264=r.readBool();s.light.field26c=r.readInt();s.light.field270=r.readInt();s.light.field278=text(r);}}
 for(const [bit,name]of [[0x800000,'materials'],[0x1000000,'textures']])if(mask&bit&&atLeast(build,bit===0x800000?14:35)){
  const n=count(r,r.readDword(),32,'material override');s[name]=[];for(let i=0;i<n;i++)s[name].push([r.readCResRef(),r.readCResRef()]);
 }
 if(mask&4){
  // Legacy public field name; client781e80 stores this FLOAT at+60 as speed,
  // not a timestamp. NetworkWorld exposes animationSpeed to presentation.
  s.animationTime=r.readFloat();s.animation=r.readWord();
  if(objectType===5){
   if(s.animation===9){s.attacks=[];const n=r.readByte(2);for(let i=0;i<n;i++){const a={target:r.readObjectIdClient(),fieldA:r.readWord(),fieldC:r.readWord(),field2:r.readWord(),result:r.readByte(4),field7A:r.readWord(),damage:r.readWord(9),field5C:r.readBool(),field68:r.readBool(),field56:r.readByte(4)};s.attacks.push(a);}}
   else{
    if((s.animation>=15&&s.animation<=20)||s.animation===61)s.cast={spell:r.readDword(),casterTarget:r.readObjectIdClient(),silent:r.readBool()};
    if((s.animation>=17&&s.animation<=20)||s.animation===61){const c=s.cast;c.targetType=r.readByte();if(c.targetType===1)c.target=r.readObjectIdClient();else if(c.targetType===2)c.position=vector(r);else throw new Error('Invalid native casting target type');c.field220=r.readDword();}
   }
  }
 }
 if(mask&8){
  s.visualEffects=[];const n=count(r,r.readWord(),3,'looping visual effect');
  for(let i=0;i<n;i++){
   const e={action:String.fromCharCode(r.readByte()),visualId:r.readWord()},beam=p.isBeam?.(e.visualId);
   if(typeof beam!=='boolean')throw new UnhandledRecord(`Looping-effect beam classification ${e.visualId} is unavailable`);
   if(beam){e.target=r.readObjectIdClient();e.field8=r.readByte();}if(atLeast(build,14))e.visualTransform=readObjectVisualTransform(r,build);s.visualEffects.push(e);
  }
 }
 if(mask&16){
  if(objectType===10){s.interactionFlags=Array.from({length:6},()=>r.readBool());s.field424=s.interactionFlags[2];s.field428=s.interactionFlags[3];s.hasTransition=s.interactionFlags[5];}
  else if(objectType===9)s.interactionFlags=Array.from({length:5},()=>r.readBool());
  else if(objectType===7){const base=p.objectState?.(id);if(typeof base?.isTrap!=='number')throw new UnhandledRecord('Trigger creation state for update is unavailable');s.interactionFlags=Array.from({length:base.isTrap?2:1},()=>r.readBool());}
 }
 if(mask&0x80000&&[6,9,10].includes(objectType))s.name=named(r);
 if(mask&64&&objectType===6)s.field468=r.readBool();
 if(objectType!==5)return record;
 if(mask&4){s.actionFlag=r.readByte();const n=count(r,r.readWord(),4,'creature path');s.path=[];if(n){s.field8F4=r.readBool();if(s.field8F4)s.field8EC=r.readFloat();}for(let i=0;i<n;i++)s.path.push([r.readFloat(100,16),r.readFloat(100,16)]);}
 if(mask&64){s.field8D4=r.readWord();s.field8D6=r.readByte();s.field8E0=r.readWord();s.reaction=r.readByte();s.field700=r.readBool();if(s.field8D6===2)s.field8D8=r.readObjectIdClient();}
 if(mask&256){s.walkRate=r.readFloat();s.runRate=r.readFloat();}if(mask&0x40000)s.areaId=r.readObjectIdClient();if(mask&512)s.mapPosition=[r.readInt(10),r.readInt(10)];
 if(mask&1024)s.hitPoints={current:r.readShort(),fieldE4:r.readShort(),fieldE8:r.readShort(),maximum:r.readShort()};
 if(mask&0x10000)s.name=r.readBool()?{firstName:localized(r),lastName:localized(r)}:{text:text(r)};
 if(mask&0x4000){s.party={player:r.readBool(),field8D4Bit6:r.readBool(),singleton:r.readBool(),leader:r.readBool(),field7DC:r.readBool()};if(s.party.field7DC){s.party.field7D8=r.readObjectIdClient();s.party.firstName=localized(r);s.party.lastName=localized(r);}s.party.field8B4=r.readBool();s.party.field8B0=r.readBool();}
 if(mask&0x8000)s.visibility=Array.from({length:3},()=>r.readBool());if(mask&0x20000)s.associateState=r.readWord();if(mask&0x800)s.damageLevel=r.readByte();
 if(mask&0x1000){
  s.stats={fieldD20:r.readWord(),fieldD28:text(r),fieldE58:text(r),race:r.readByte(),fieldDE4:r.readShort(),fieldDE6:r.readShort(),fieldF8:r.readBool(),field4E8:r.readBool(),classes:[]};
  // Client781e80 writes this WORD to stats+50, the racialtypes index used by
  //7f6b20. The legacy public name `race` above belongs to a different BYTE68.
  s.stats.racialType=s.stats.fieldD20;const n=count(r,r.readByte(),2,'creature class');
  for(let i=0;i<n;i++){const c={id:r.readByte(),level:r.readByte()},schema=p.classInfo?.(c.id);if(!schema)throw new UnhandledRecord(`Creature class schema ${c.id} is unavailable`);if(schema.pickSchool)c.school=r.readByte();if(schema.pickDomains)c.domains=[r.readByte(),r.readByte()];s.stats.classes.push(c);}
 }
 if(mask&0x2000){s.master=r.readObjectIdClient();s.field908=r.readWord();s.field910=r.readBool();s.field914=r.readBool();if(atLeast(build,31))s.takesCommands=r.readBool();}
 return record;
}

// Retain a verified prefix when a later record owner is still unavailable.
// There is no record-length field to skip unknown records safely. The caller
// must diagnose incomplete messages; neither byte scanning nor guessed reads
// can establish the next native record boundary.
export function readObjectUpdates(r,{clientBuild,...providers}={}){
 if(!clientBuild||![clientBuild.number,clientBuild.revision,clientBuild.postfix].every(Number.isInteger))throw new Error('Native client build for object updates is unavailable');
 const records=[],states=new Map(),externalState=providers.objectState;
 providers={...providers,objectState:id=>states.get(id)??externalState?.(id)};
 while(r.byteCursor44<r.byteSize40){
  const cursor=r.byteCursor44,fragmentCursor=r.fragmentCursor54,bit=r.curReadBit5c;
  const tag=String.fromCharCode(r.readChar()&255);
  try{
   if(tag==='A')records.push(creation(r,clientBuild,providers));
   else if(tag==='P')records.push(appearance(r,clientBuild,providers));
   else if(tag==='U')records.push(update(r,clientBuild,providers));
   else if(tag==='I')records.push(readPlayerState(r,clientBuild,{...providers,unsupported:reason=>{throw new UnhandledRecord(reason);}}));
   else if(tag==='G')records.push(guiInventory(r,clientBuild,providers));
   else if(tag==='D'){
    const objectType=r.readByte(),id=r.readObjectIdClient(),record={action:'delete',objectType,id};if([5,6,9].includes(objectType))record.remove=r.readBool();records.push(record);
   }else if(tag==='W')records.push({action:'work-remaining',completed:r.readByte(),total:r.readByte()});
   else throw new UnhandledRecord(`Object update record ${tag} is unavailable`);
   if(r.messageReadOverflow())throw new Error('Invalid native object-update record fields');
   const last=records.at(-1);if(last.state)states.set(last.id,{...providers.objectState(last.id),...last.state});
  }catch(error){
   if(!(error instanceof UnhandledRecord))throw error;
   return{records,complete:false,unhandled:{tag,reason:error.message,cursor,fragmentCursor,bit}};
  }
 }
 return{records,complete:true};
}
