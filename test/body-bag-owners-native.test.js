import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {loadBodyBag,spawnBodyBag,receiveBodyBagAreaEvent} from '../src/body_bag.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-body-bag-owners-observations.json',import.meta.url)));
test('full body-bag synthetic loader matches original fields, normalized tag, strings and initialization order',async()=>{
 for(const row of data.loads){
  const calls=[],bag={id:777,fields:{}},p={
   resref:(_o,offset,value)=>calls.push(['resref',offset,value]),tag:(o,value)=>o.tag=value,
   localized:(_o,offset,value)=>calls.push(['localized',offset,value.strRef]),field:(o,offset,value)=>o.fields[offset]=value,
   string:(_o,offset,value)=>calls.push(['string',offset,value]),portrait:(_o,value)=>calls.push(['portrait',value]),
   animation:(_o,value)=>calls.push(['animation',value]),addTag:o=>calls.push(['addTag',o.tag,o.id]),
  };
  assert.equal(await loadBodyBag(bag,row.case.appearance,p),row.result);assert.deepEqual(calls,row.calls,JSON.stringify(row.case));assert.equal(bag.tag,row.tag);
  for(const [offset,value]of Object.entries(row.fields))assert.equal(bag.fields[offset]??0xa5a5a5a5,value,`${offset}: ${JSON.stringify(row.case)}`);
 }
 assert.equal(data.loads.length,6);
});
test('full body-bag spawn matches original short circuits, stale corpse link, transfer and delayed insertion event',async()=>{
 for(const row of data.spawns){
  const c=row.case,calls=[],source={id:99,areaId:88,objectType:c.type,nativeLootable4e8:c.lootable,nativeDecayTime4ec:7000,nativeBodyBagId4f0:OBJECT_INVALID},bag={id:777,fields:Object.fromEntries(Object.keys(row.fields).map(key=>[key,0])),nativeBodyBagSource510:OBJECT_INVALID},area={id:88};
  await spawnBodyBag(source,{
   asCreature:()=>{calls.push(['asCreature']);return c.creature?source:null;},asPlaceable:()=>{calls.push(['asPlaceable']);return c.placeable?source:null;},
   object:id=>{calls.push(['object',id]);return c.area?area:null;},asArea:()=>{calls.push(['asArea']);return c.asArea?area:null;},
   creatureCount:(_o,flag)=>{calls.push(['count','creature',flag]);return c.count;},placeableCount:(_o,flag)=>{calls.push(['count','placeable',flag]);return c.count;},
   construct:id=>{if(!c.construct)return null;calls.push(['construct',id]);return bag;},appearance:o=>{calls.push(['appearance',o===source&&c.creature?'creature':'placeable']);return c.appearance&65535;},
   load:(_o,value)=>{calls.push(['load',value]);return c.load;},destroy:(_o,flag)=>calls.push(['destroy',flag]),transfer:(_o,id,flag)=>{calls.push(['transfer',id,flag]);return c.transferred;},payload:()=>c.payload?{}:null,
   localized:(_o,offset,value)=>calls.push(['localized',offset,value.strRef]),sourceName:()=>{calls.push(['sourceName']);return{strRef:4242,entries:[]};},position:()=>[1.25,-2.5,3.75],field:(o,offset,value)=>o.fields[offset]=value,
   enqueue:(...args)=>calls.push(['event',...args]),
  });
  const label=JSON.stringify(c);assert.deepEqual(calls,row.calls,label);assert.deepEqual(bag.fields,row.fields,label);assert.equal(source.nativeBodyBagId4f0,row.sourceBagId,label);assert.equal(bag.nativeBodyBagSource510,row.bagSourceId,label);
 }
 assert.equal(data.spawns.length,240);
});
test('area event17 matches original canonical lookup, insertion coordinates and payload release',async()=>{
 for(const row of data.areas){
  const c=row.case,calls=[],area={id:88},bag={id:777};
  if(c.event===17)await receiveBodyBagAreaEvent(area,c.payload?{id:777,position:[1.25,-2.5,3.75]}:null,{
   lookup:id=>{calls.push(['object',id]);return{status:c.status,object:c.found?bag:null};},asPlaceable:()=>{calls.push(['asPlaceable']);return c.placeable?bag:null;},
   addToArea:(_o,a,...args)=>{assert.equal(a,area);calls.push(['addToArea',...args]);},releasePayload:()=>calls.push(['release']),
  });
  assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
 assert.equal(data.areas.length,70);
});
