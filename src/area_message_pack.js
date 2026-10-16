import {writeLocalizedServer} from './native_message_text.js';
import {OBJECT_INVALID} from './game_object_array.js';

const field=(p,o,offset,type='int')=>{
 const v=p.field(o,offset,type);
 if(type==='float'){if(typeof v!=='number')throw new Error(`Native area message FLOAT ${offset.toString(16)} is unavailable`);return Math.fround(v);}
 if(!Number.isInteger(v))throw new Error(`Native area message ${type} ${offset.toString(16)} is unavailable`);
 return type==='byte'?v&255:type==='word'?v&65535:type==='dword'?v>>>0:v|0;
};
const stringBytes=value=>{
 if(!(value instanceof Uint8Array))throw new Error('Native area message string bytes are unavailable');
 return value[0]===0?new Uint8Array():value;
};

// Verified identity prefix1403632ea..14036339b of PackAreaIntoMessage.
// The remainder of the area serializer is deliberately a separate owner.
export async function writeAreaIdentityPrefix(message,area,resRefBytes,p){
 message.writeObjectIdServer(area.id);message.writeCResRef(resRefBytes,16);
 if(!Number.isInteger(area.nativeCustomNameLength360)||area.nativeCustomNameLength360<0)throw new Error('Native area custom-name length is unavailable');
 if(area.nativeCustomNameLength360===0){message.writeBool(0);await writeLocalizedServer(message,area.nativeName188,0,p);}
 else{
  message.writeBool(1);const bytes=area.nativeCustomName358,length=area.nativeCustomNameLength360;
  if(!(bytes instanceof Uint8Array)||bytes.length<length)throw new Error('Native area custom-name bytes are unavailable');
  message.writeStringBytes(bytes[0]===0?new Uint8Array():bytes.subarray(0,length),32);
 }
}

// CNWSAmbientSound::PackIntoMessage140358750..14035881d.
export function packAmbientSound(message,ambient,p){
 for(const offset of [8,0x18,0x20])message.writeBool(field(p,ambient,offset));
 for(const offset of [0xc,0x10,0x14,0x1c,0x24,0x28])message.writeInt(field(p,ambient,offset),32);
 for(const offset of [0x2c,0x2d])message.writeByte(field(p,ambient,offset,'byte'),8,1);
}

// CNWSSoundObject::PackIntoMessage1404f5120..1404f53a8.
export function packSoundObject(message,sound,p){
 // Position is captured before the first scalar writer, as in the owner.
 const position=[0xa4,0xa8,0xac].map(o=>field(p,sound,o,'float'));
 message.writeObjectIdServer(sound.id);
 for(const offset of [0x308,0x30c,0x310])message.writeBool(field(p,sound,offset));
 for(const offset of [0x314,0x318,0x31c])message.writeByte(field(p,sound,offset,'byte'),8,1);
 message.writeFloat(field(p,sound,0x320,'float'),1,32);message.writeDword(field(p,sound,0x324,'dword'),32);message.writeByte(field(p,sound,0x328,'byte'),8,1);
 for(const offset of [0x348,0x34c])message.writeDword(field(p,sound,offset,'dword'),32);
 for(const offset of [0x350,0x354])message.writeFloat(field(p,sound,offset,'float'),1,32);
 for(const offset of [0x358,0x35c,0x32c])message.writeBool(field(p,sound,offset));
 for(const value of [field(p,sound,0x330,'float'),field(p,sound,0x334,'float'),...position])message.writeFloat(value,1,32);
 const count=field(p,sound,0x340,'word');message.writeWord(count,16);
 for(let i=0;i<count;i++)message.writeCResRef(p.soundRef(sound,i),16);
}

// GetLightIsOn1404b3e40: the 2DA query's STATUS gates the raw field594;
// its LightColor value is not treated as an on/off flag.
export async function placeableMessageLight(placeable,p){
 const entry=await p.lightColor(field(p,placeable,0x32c,'word'),'LightColor');
 return entry.status!==0?field(p,placeable,0x594):0;
}

// Complete decoded PackAreaIntoMessage140363200..140364661. Typed field,
// resource/list/virtual lookup, expansion and script-local owners are supplied
// explicitly. This does not by itself bind the native player transport/receiver.
export async function packAreaIntoMessage(area,x,y,z,client,p){
 const message=await p.message(),array=await p.objectArray();if(!message)return 0;
 const F=(offset,type='int')=>field(p,area,offset,type),B=offset=>message.writeBool(F(offset)),Y=offset=>message.writeByte(F(offset,'byte'),8,1),D=offset=>message.writeDword(F(offset,'dword'),32),R=offset=>message.writeFloat(F(offset,'float'),1,32);
 await writeAreaIdentityPrefix(message,area,p.resRef(area,0x120),p);
 for(const value of [x,y,z])message.writeInt(value,32);
 for(const offset of [8,0x98,0x9c])D(offset);
 if(await p.hasExpansion(client,0x2001,0x23,0)!==0)for(const offset of [0xac,0xb0,0xb4])R(offset);
 D(0xa0);Y(0xa4);B(0xa8);D(0xb8);D(0xbc);
 if(await p.hasExpansion(client,0x2001,0x23,0)!==0)for(const offset of [0xcc,0xd0,0xd4])R(offset);
 D(0xc0);Y(0xc4);B(0xc8);B(0xd8);B(0xdc);message.writeByte(await p.pvp(area),8,1);B(0x100);Y(0x104);R(0x108);message.writeInt(F(0x34c),32);
 packAmbientSound(message,p.ambient(area),p);
 const time=await p.moduleTime(await p.module()),dawn=field(p,await p.module(),0x3b9,'byte'),dusk=field(p,await p.module(),0x3ba,'byte');
 message.writeByte(time[4],8,1);message.writeDword(time[5],32);for(const i of [3,2,1])message.writeByte(time[i],8,1);message.writeDword(time[0],32);
 message.writeByte(dawn,8,1);message.writeByte(dusk,8,1);for(const offset of [0xe0,0xe3,0xe4])Y(offset);
 if(await p.hasExpansion(client,0x2001,0xe,0)!==0&&F(0xe4,'byte')===3)for(const offset of [0xe8,0xec,0xf0,0xf4,0xf8,0xfc])R(offset);
 const override=F(0x344,'byte');message.writeByte(override===255?F(0x330,'byte'):override,8,1);message.writeBool(override===255?F(0x334):1);
 message.writeInt(F(0xc),32);message.writeInt(F(0x10),32);message.writeCResRef(p.resRef(area,0x1a8),16);
 if(await p.hasExpansion(client,0x2001,0x24,3)!==0){
  B(0x368);message.writeInt(F(0x380),32);
  for(const entry of p.grassEntries(area)){
   message.writeByte(field(p,entry,0x10,'byte'),8,1);message.writeStringBytes(stringBytes(p.string(entry,0x18)),32);
   for(const offset of [0x28,0x2c,0x30,0x34,0x38,0x3c,0x40,0x44])message.writeFloat(field(p,entry,offset,'float'),1,32);
  }
 }
 if(await p.hasExpansion(client,0x2001,0x24,5)!==0)B(0x10c);
 // Re-evaluate the live signed width*height bound each iteration.
 for(let i=0;i<Math.imul(F(0xc),F(0x10));i++){
  const tile=p.tile(area,i),T=(o,type='int')=>field(p,tile,o,type);
  for(const offset of [0x14,0x24,0x18])message.writeInt(T(offset),32);
  const main=await p.mainLight(tile),source=await p.sourceLight(tile),replacement=T(0x2c,'byte'),anim=await p.animLoop(tile);
  const mask=(main[0]?1:0)|(main[1]?2:0)|12|(replacement?16:0)|(anim[0]?32:0)|(anim[1]?64:0)|(anim[2]?128:0);
  message.writeWord(mask,16);
  for(const [bit,value]of [[1,main[0]],[2,main[1]],[4,source[0]],[8,source[1]],[16,T(0x2c,'byte')],[32,anim[0]],[64,anim[1]],[128,anim[2]]])if(mask&bit)message.writeByte(value,8,1);
 }
 const lookup=async id=>{const result=await p.lookup(array,id>>>0);if((result.status&255)!==0)return null;if(!result.object)throw new Error('Native successful area object lookup has no object');return result.object;};
 const waypoints=[],sounds=[];
 for(let i=0;i<F(0x230);i++){
  const id=p.objectId(area,i)>>>0,object=await lookup(id);if(!object)continue;
  const waypoint=await p.asWaypoint(object);
  if(waypoint){if(field(p,waypoint,0x308)!==0)waypoints.push(id);}
  else if(await p.asSound(object))sounds.push(id);
 }
 message.writeInt(waypoints.length,32);
 for(const id of waypoints){
  const object=await lookup(id),waypoint=object&&await p.asWaypoint(object);if(!waypoint)continue;
  message.writeObjectIdServer(waypoint.id);
  const point=[0xa4,0xa8,0xac].map(o=>field(p,waypoint,o,'float'));for(const value of point)message.writeFloat(value,1,32);
  message.writeBool(field(p,waypoint,0x30c));await writeLocalizedServer(message,p.localized(waypoint,0x310),0,p);
 }
 const controlled=await p.clientObject(client),creature=controlled&&await p.asCreature(controlled);let owner=creature;
 if(owner&&field(p,owner,0x8fc,'dword')!==OBJECT_INVALID)owner=await p.creature(field(p,owner,0x8fc,'dword'));
 const pins=[];
 if(owner){
  const total=(await p.localInt(owner,'NW_TOTAL_MAP_PINS'))>>>0;
  if(total>1_000_000)throw new Error('Native area message map-pin enumeration is unsupported');
  if(total!==0)for(let i=0;i<=total;i++){
   const text=stringBytes(await p.localString(owner,`NW_MAP_PIN_NTRY_${i}`));
   if(text.length!==0&&(await p.localObject(owner,`NW_MAP_PIN_AREA_${i}`))>>>0===(area.id>>>0))pins.push(i);
  }
 }
 message.writeInt(pins.length,32);
 for(const i of pins){
  message.writeInt(i,32);message.writeStringBytes(stringBytes(await p.localString(owner,`NW_MAP_PIN_NTRY_${i}`)),32);
  for(const axis of ['X','Y','Z'])message.writeFloat(await p.localFloat(owner,`NW_MAP_PIN_${axis}POS_${i}`),1,32);
 }
 const count=sounds.length&65535;message.writeWord(count,16);
 for(let i=0;i<count;i++){const object=await lookup(sounds[i]),sound=object&&await p.asSound(object);if(sound)packSoundObject(message,sound,p);}
 let lights=0,statics=0;
 for(let i=0;i<F(0x230);i++){
  const object=await p.placeable(p.objectId(area,i)>>>0);if(!object)continue;
  if(await p.light(object)!==0)lights=(lights+1)&65535;if(field(p,object,0x5a0)!==0)statics=(statics+1)&65535;
 }
 message.writeWord(lights,16);
 for(let i=0;i<F(0x230);i++){
  const object=await p.placeable(p.objectId(area,i)>>>0);if(!object||await p.light(object)===0)continue;
  const point=[0xa4,0xa8,0xac].map(o=>field(p,object,o,'float'));
  message.writeObjectIdServer(object.id);message.writeWord(field(p,object,0x32c,'word'),16);for(const value of point)message.writeFloat(value,1,32);
 }
 message.writeWord(statics,16);
 for(let i=0;i<F(0x230);i++){
  const object=await p.placeable(p.objectId(area,i)>>>0);if(!object||field(p,object,0x5a0)!==1)continue;
  const vectors=[0xa4,0xa8,0xac,0xb0,0xb4,0xb8].map(o=>field(p,object,o,'float'));
  message.writeObjectIdServer(object.id);message.writeWord(field(p,object,0x32c,'word'),16);for(const value of vectors)message.writeFloat(value,1,32);
 }
 message.writeWord(0,16);message.writeWord(0,16);return 1;
}
