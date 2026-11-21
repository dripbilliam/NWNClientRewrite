import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeServerMessage} from '../src/native_message.js';
import {packAreaIntoMessage,placeableMessageLight} from '../src/area_message_pack.js';
import {playerMessageLanguage,serverMessageLanguage} from '../src/native_message_text.js';
const heap=size=>({bytes:new Uint8Array(size).fill(0xa5),defined:new Uint8Array(size).fill(255)}),bytes=hex=>Uint8Array.from(Buffer.from(hex,'hex'));
const ref=value=>{const result=new Uint8Array(17);result.set(new TextEncoder().encode(value).subarray(0,16));return result;};

test('complete area/ambient/sound packing matches original payload bytes, live lists, counts and lower-call order',async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-area-pack-observations.json',import.meta.url)));assert.equal(fixture.rows.length,439);
 for(const [index,row]of fixture.rows.entries()){
  const c=row.case,trace=[],diagnostics=[],message=new NativeServerMessage(c.format,{allocate:heap}),area={id:c.id,fields:structuredClone(c.area),nativeName188:{strRef:123,entries:(c.nameEntries??[]).map(([key,hex])=>({key,bytes:bytes(hex)}))},nativeCustomName358:bytes(c.custom??''),nativeCustomNameLength360:(c.custom??'').length/2},ambient={fields:c.ambient},module={fields:c.module},client={},objects=new Map(c.objects.map(o=>[o.id,structuredClone(o)])),array={};
  const state={ids:[...c.ids],lookups:0,lightQueries:0,removed:new Set()};message.create(c.size??0,0x80000001,1);
  const field=(o,offset)=>{
   if(o===area&&offset===0x230)return state.ids.length;
   const record=o.fields[offset.toString(16)];assert.ok(record,`Missing field ${offset.toString(16)}`);return record[1];
  };
  const getLocal=(o,kind,key)=>{const value=o.locals?.[kind]?.[key]??{int:0,object:0x7f000000,float:0,string:''}[kind];trace.push(['local',o.id,kind,key,value]);return value;};
  const p={
   field,message:()=>{trace.push(['message']);return c.noMessage?null:message;},objectArray:()=>{trace.push(['objectArray']);return array;},
   resRef:(_a,offset)=>ref(offset===0x120?'fixture_area':'tni01'),server:()=>({clients:[{nativePlayerId48:0x80000001,nativeLanguage4c:c.language??0}]}),
   playerLanguage:(s,id)=>playerMessageLanguage(s.clients,id),serverLanguage:serverMessageLanguage,warning:kind=>diagnostics.push({kind}),
   hasExpansion:(_c,family,feature,version)=>{const value=c.expansions[`${feature}:${version}`]??0;trace.push(['expansion',family,feature,version,value]);return value;},
   pvp:()=>{trace.push(['pvp']);return c.pvp;},ambient:()=>ambient,module:()=>{trace.push(['module']);return module;},
   moduleTime:()=>{trace.push(['time']);return[0x3c0,0x3c4,0x3c8,0x3cc,0x3d4,0x3d0].map(offset=>field(module,offset));},
   grassEntries:()=>c.grass.map(g=>({fields:g.fields,name:g.name})),string:o=>bytes(o.name),tile:(_a,i)=>({fields:c.tiles[i],index:i}),
   mainLight:o=>{trace.push(['main',o.index]);return[0x28,0x29].map(offset=>field(o,offset)&255);},sourceLight:o=>{trace.push(['source',o.index]);return[0x2a,0x2b].map(offset=>field(o,offset)&255);},animLoop:o=>{trace.push(['anim',o.index]);return[0x2d,0x2e,0x2f].map(offset=>field(o,offset)&255);},
   objectId:(_a,i)=>state.ids[i],lookup:(_array,id)=>{
    assert.equal(_array,array);state.lookups++;const mutation=c.onLookup??{};
    if(mutation.at===state.lookups){if(mutation.ids)state.ids=[...mutation.ids];if(mutation.remove!==undefined)state.removed.add(mutation.remove);}
    const object=objects.get(id),status=!object||state.removed.has(id)?1:object.status??0;trace.push(['lookup',id,status]);return{status,object:status===0?object:null};
   },
   asWaypoint:o=>o.type===12?o:null,asSound:o=>o.type===16?o:null,asCreature:o=>o.type===5?o:null,
   localized:o=>({strRef:123,entries:o.nameEntries.map(([key,hex])=>({key,bytes:bytes(hex)}))}),
   clientObject:()=>{trace.push(['clientObject']);return objects.get(c.controlled??0x7f000000);},
   creature:id=>{const o=objects.get(id),valid=!!o&&o.type===5&&!state.removed.has(id);trace.push(['creature',id,valid]);return valid?o:null;},
   placeable:id=>{const o=objects.get(id),valid=!!o&&o.type===9&&!state.removed.has(id);trace.push(['placeable',id,valid]);return valid?o:null;},
   lightColor:(row,column)=>{
    state.lightQueries++;const mutation=c.onLight??{};
    if(mutation.at===state.lightQueries){if(mutation.ids)state.ids=[...mutation.ids];for(const [id,changes]of Object.entries(mutation.fields??{}))Object.assign(objects.get(Number(id)).fields,structuredClone(changes));}
    const [status,value]=c.lightRows?.[row]??[0,0];trace.push(['lightColor',row,column,status,value]);return{status,value};
   },
   localInt:(o,key)=>getLocal(o,'int',key),localObject:(o,key)=>getLocal(o,'object',key),localFloat:(o,key)=>getLocal(o,'float',key),localString:(o,key)=>bytes(getLocal(o,'string',key)),
   soundRef:(o,i)=>ref(o.refs[i]),
  };p.light=o=>placeableMessageLight(o,p);
  const result=await packAreaIntoMessage(area,...c.point,client,p),payload=message.getWriteMessage(),observation={result:payload.status,length:payload.length,hex:payload.data?Buffer.from(payload.data).toString('hex'):null,byteLength:message.byteLength14,bitLength:message.bitLength24,bitOffset:message.bitOffset2c,total:message.total28,byteCapacity:message.byteStorage.bytes.length,bitCapacity:message.bitStorage.bytes.length,writing:message.writing30,flag:message.flag60,playerId:message.playerId64};
  assert.deepEqual({result,trace,observation,diagnostics},{result:row.result,trace:row.trace,observation:row.observation,diagnostics:row.diagnostics},JSON.stringify({index,case:c}));
 }
});
