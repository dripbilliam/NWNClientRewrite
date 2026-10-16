import {packAreaIntoMessage,placeableMessageLight} from './area_message_pack.js';
import {nativeMessageField} from './area_message_metadata.js';
import {playerMessageLanguage,serverMessageLanguage} from './native_message_text.js';
import {encodeGffText} from './gff_text.js';
import {intEntry} from './combat_stats.js';
const f=Math.fround,native=v=>{
 if(!Array.isArray(v)||v.length<3)throw new Error('Native message object vector is unavailable');
 return[f(v[0]),f(-v[2]),f(v[1])];
};
const required=(value,name)=>{if(value===undefined||value===null)throw new Error(`Native area message ${name} is unavailable`);return value;};
const ref=value=>{const result=new Uint8Array(17);result.set(encodeGffText(String(value)).subarray(0,16));return result;};

// Normal-session bindings for the decoded complete packer. Missing loaded
// owners remain errors; no empty ambient/sound/map-note state is substituted.
export class AreaMessageRuntime{
 constructor(session){this.session=session;}
 providers(message,{clients,hasExpansion}={}){
  const s=this.session,field=(o,offset)=>{
   if(o.objectType>4){
    if([0xa4,0xa8,0xac].includes(offset))return native(o.position)[(offset-0xa4)/4];
    if([0xb0,0xb4,0xb8].includes(offset))return native(o.orientation)[(offset-0xb0)/4];
    if(o.objectType===5&&offset===0x8fc)return o.masterId;
    if(o.objectType===9&&offset===0x5a0)return o.nativeStatic5a0;
   }
   try{
    const value=nativeMessageField(o,offset);if(value===undefined)throw new Error(`Native message field ${offset.toString(16)} is unavailable`);return value;
   }catch(error){error.diagnosticContext={...error.diagnosticContext,objectId:o.id,objectType:o.objectType,fieldOffset:offset};throw error;}
  };
  const p={
   message:()=>message,objectArray:()=>s.registry,field,server:()=>s,
   playerLanguage:(_s,id)=>playerMessageLanguage(required(clients,'transport client list'),id),serverLanguage:serverMessageLanguage,
   warning:site=>s.report(new Error(`Native localized area message warning: ${site}`),{operation:'native-area-localized-message'}),
   resRef:(a,offset)=>ref(offset===0x120?a.resRef:offset===0x1a8?a.tilesetResRef:required(undefined,'resource reference offset')),
   hasExpansion:(...args)=>{if(typeof hasExpansion!=='function')throw new Error('Native area message client expansion state is unavailable');return hasExpansion(...args);},
   pvp:a=>s.getPVPSetting(a),ambient:a=>required(a.nativeAmbientSound328,'ambient sound state328'),module:()=>s.module,
   moduleTime:m=>[0x3c0,0x3c4,0x3c8,0x3cc,0x3d4,0x3d0].map(offset=>field(m,offset)),
   grassEntries:a=>required(a.nativeMessageGrassEntries,'grass overrides'),string:o=>required(o.nativeName18,'grass name bytes'),
   tile:(a,i)=>required(a.nativeMessageTiles?.[i],'tile metadata'),mainLight:o=>[0x28,0x29].map(offset=>field(o,offset)),sourceLight:o=>[0x2a,0x2b].map(offset=>field(o,offset)),animLoop:o=>[0x2d,0x2e,0x2f].map(offset=>field(o,offset)),
   objectId:(a,i)=>required(a.nativeSpatial?.ids[i],'spatial object ID'),lookup:(array,id)=>array.getGameObject(id),
   asWaypoint:o=>o?.objectType===12?o:null,asSound:o=>o?.objectType===16?o:null,asCreature:o=>o?.objectType===5?o:null,
   localized:o=>required(o.nativeMapNote310,'waypoint map-note string'),clientObject:c=>c?.object?s.registry.get(c.object.id):null,
   creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},placeable:id=>{const o=s.registry.get(id);return o?.objectType===9?o:null;},
   lightColor:async(row,column)=>{const table=await s.items.table('placeables');if(!table)throw new Error('Native placeables.2da is unavailable');const value=intEntry(table,row,column);return{status:Number(value.found),value:value.value};},
   localInt:(o,key)=>o.locals.getInt(key),localObject:(o,key)=>o.locals.getObject(key),localFloat:(o,key)=>o.locals.getFloat(key),localString:(o,key)=>encodeGffText(o.locals.getString(key)),
   soundRef:(o,i)=>required(o.nativeSoundRefs338?.[i],'sound resource reference'),
  };p.light=o=>placeableMessageLight(o,p);return p;
 }
 async pack(message,area,x,y,z,client,options){
  try{return await packAreaIntoMessage(area,x,y,z,client,this.providers(message,options));}
  catch(error){this.session.report(error,{areaId:area.id,area:area.resRef,operation:'native-pack-area-message'});throw error;}
 }
}
