import {OBJECT_INVALID} from './game_object_array.js';
const uint=(v,n)=>{if(!Number.isInteger(v)||v<0||v>0xffffffff)throw new Error(`Native projectile message ${n} is unavailable`);return v>>>0;};
const scalar=(v,n)=>{if(typeof v!=='number')throw new Error(`Native projectile message ${n} is unavailable`);return Math.fround(v);};

// WriteOBJECTIDServer1404763e0..: client lookup IDs retain the external bit.
// This conversion never registers, allocates or changes an authoritative object.
export function serverObjectIdForClient(id){id=uint(id,'object ID');return id===OBJECT_INVALID?id:(id|0x80000000)>>>0;}

// Client ReadOBJECTID9737c0 advances even on a short read, returning0.
// The bytes are a decoded CNWMessage data stream, not a raw transport packet.
export function readClientObjectId(state){
 const cursor=uint(state.cursor,'read cursor'),available=uint(state.available,'read byte count');state.cursor=(cursor+4)>>>0;
 if(available<cursor+4)return 0;
 if(!(state.bytes instanceof Uint8Array)||cursor+4>state.bytes.length)throw new Error('Native projectile object-ID backing bytes are unavailable');
 return new DataView(state.bytes.buffer,state.bytes.byteOffset,state.bytes.byteLength).getUint32(cursor,true);
}

// Safe-projectile receive1407ac7d1..1407ac97b, before object lookup/model
// allocation. The three overflow guards and appearance-dependent reads matter:
// 6:spell; 7:spell+path; other:path+baseItem+result. Not full packet framing.
export function readSafeProjectileHeader(p){
 if(p.overflow()!==0)return null;
 const sourceId=p.objectId()>>>0,targetId=p.objectId()>>>0,
  from=[p.float(1,32),p.float(1,32),p.float(1,32)],to=[p.float(1,32),p.float(1,32),p.float(1,32)],duration=p.dword(32)>>>0,appearance=p.byte(8,1)&255;
 if(p.overflow()!==0)return null;
 let spellId=null,path=null,baseItem=255,result=0;
 if(appearance===6)spellId=p.dword(32)>>>0;
 else if(appearance===7){spellId=p.dword(32)>>>0;path=p.byte(8,1)&255;}
 else{path=p.byte(8,1)&255;baseItem=p.byte(8,1)&255;result=p.byte(8,1)&255;}
 if(p.overflow()!==0)return null;
 return{sourceId,targetId,from,to,duration,appearance,spellId,path,baseItem,result};
}

// Local server delivery has already decoded scalar fields, not raw NWN bytes.
// Project exactly the typed field layout emitted by4df550; the client reader
// then owns branch/default semantics. Debug/type-bit/framing/transport are separate.
export function localSafeProjectileFields(data){
 const fields=[],add=(type,value)=>fields.push({type,value}),byte=(v,n)=>uint(v,n)&255;
 add('object',serverObjectIdForClient(data.sourceId));add('object',serverObjectIdForClient(data.targetId));
 for(const [name,point]of[['from',data.from],['to',data.to]]){
  if(!Array.isArray(point)||point.length!==3)throw new Error(`Native projectile message ${name} point is unavailable`);
  for(const value of point)add('float',scalar(value,name));
 }
 add('dword',uint(data.duration,'duration'));const appearance=byte(data.appearance,'appearance');add('byte',appearance);
 if(appearance===6||appearance===7){if(!Number.isInteger(data.flags)||data.flags< -0x80000000||data.flags>0xffffffff)throw new Error('Native projectile message spell flags are unavailable');add('dword',data.flags>>>0);if(appearance===7)add('byte',byte(data.deflection,'path'));}
 else{add('byte',byte(data.deflection,'path'));add('byte',byte(data.baseItem,'base item'));add('byte',byte(data.result,'result'));}
 return fields;
}
export function decodeLocalSafeProjectile(data){
 const fields=localSafeProjectileFields(data);let index=0,failed=0;
 const take=type=>{const field=fields[index++];if(!field||field.type!==type){failed=1;return 0;}return field.value;};
 const header=readSafeProjectileHeader({overflow:()=>failed,objectId:()=>take('object'),float:()=>take('float'),dword:()=>take('dword'),byte:()=>take('byte')});
 if(!header||index!==fields.length)throw new Error('Native local projectile field sequence is invalid');return header;
}
