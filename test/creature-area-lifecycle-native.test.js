import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {removeAreaObject,removeCreatureFromArea,addAreaObject,addCreatureToArea} from '../src/creature_area_lifecycle.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';

test('area/creature removal matches original spatial, AI, observer and following-effect ordering',async()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-creature-area-removal-observations.json',import.meta.url)));
 for(const [kind,rows]of [['object',native.objects],['creature',native.creatures]])for(const row of rows){
  const c=row.case,calls=[],objects=new Map([99,100,101,102,103,104,105].map(id=>[id,{id,objectType:[99,100,103].includes(id)?5:id===104?11:9,nativeAILevel7c:1}])),actor=objects.get(99),
   area={id:88,ids:[...(c.ids??[99,100,101,103])],nativePlayerCount150:c.players??1};
  actor.areaId=c.noArea?OBJECT_INVALID:88;actor.position=[1,2,3];
  const erase=(_a,id)=>{const n=area.ids.indexOf(id);if(n>=0)area.ids.splice(n,1);},
   p={removeSpatial:erase,client:id=>{calls.push(['client',id]);return c.client?{}:null;},ids:a=>a.ids,
    object:id=>{calls.push(['object',id]);return objects.get(id)??null;},asCreature:o=>o.objectType===5?o:null,
    creature:id=>{calls.push(['creature',id]);const o=objects.get(id);return o?.objectType===5?o:null;},
    setAILevel:(o,n)=>{calls.push(['ai',o.id,n]);o.nativeAILevel7c=n;},exitSuppressed:()=>c.suppressed??0,dead:o=>{calls.push(['dead',o.id]);return c.dead??0;},
    enqueue:(day,time,caller,target,event,data)=>calls.push(['event',day,time,caller,target,event,data.type,Object.fromEntries(['integers','objectIds'].filter(key=>data[key]?.length).map(key=>[key,Object.fromEntries(data[key].map((v,i)=>[String(i),v>>>0]))]))]),
    area:()=>{calls.push(['area']);return actor.areaId===88?area:null;},removeObject:(a,id)=>{calls.push(['removeObject',id]);erase(a,id);},clearVisible:()=>calls.push(['clearVisible']),
    visibilityNode:(o,id)=>{calls.push(['visibility',o.id,id]);return(c.flags??3)<0?null:{flags:c.flags??3};},removeVisible:(o,id)=>calls.push(['removeVisible',o.id,id]),
    statsPC:()=>c.pc??0,areaService:()=>c.service?{}:null,playerLeft:()=>calls.push(['playerLeft']),followingIds:()=>c.following??[],asAreaEffect:o=>o.objectType===11?o:null,
    removeAreaEffect:o=>calls.push(['removeAoE',o.id]),setArea:o=>{calls.push(['setArea',null]);o.areaId=OBJECT_INVALID;},position:(o,point)=>{o.position=point;},barter:()=>c.barter?{}:null,cleanBarter:()=>calls.push(['barter'])};
  if(kind==='object')assert.equal(await removeAreaObject(area,c.id??99,p),1);else await removeCreatureFromArea(actor,c.skip??0,p);
  const label=JSON.stringify({kind,...c});assert.deepEqual(calls,row.calls,label);assert.deepEqual(area.ids,row.ids,label);assert.equal(area.nativePlayerCount150,row.players,label);
  assert.equal(actor.areaId,row.areaId,label);assert.deepEqual(actor.position,row.position,label);assert.deepEqual(Object.fromEntries([...objects].map(([id,o])=>[String(id),o.nativeAILevel7c])),row.levels,label);
 }
});

test('nonclient area insertion matches original ordering, enter gates, following effects and AI levels',async()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-creature-area-add-observations.json',import.meta.url)));
 for(const [kind,rows]of [['object',native.objects],['creature',native.creatures]])for(const row of rows){
  const c=row.case,calls=[],objects=new Map([99,100,101,103,104].map(id=>[id,{id,objectType:id===99?c.type??5:id===100?5:id===103?11:6,position:[id===99?1:id===100?0:2,0,0]}])),actor=objects.get(99),
   area={id:88,ids:[...(c.ids??[100,101])],nativePlayerCount150:c.players??1};
  actor.areaId=c.same?88:OBJECT_INVALID;actor.nativeAILevel7c=c.level??0;actor.nativeLastClientArea4f4=OBJECT_INVALID;
  const erase=id=>{const n=area.ids.indexOf(id);if(n>=0)area.ids.splice(n,1);},p={
   ids:a=>a.ids,object:id=>{calls.push(['object',id]);return c.missing&&id===99?null:objects.get(id)??null;},
   removeObject:(_a,id)=>{calls.push(['removeObject',id]);erase(id);},insertSpatial:(_a,id)=>{const x=objects.get(id).position[0],n=area.ids.findIndex(other=>objects.get(other).position[0]>=x);area.ids.splice(n<0?area.ids.length:n,0,id);},
   asCreature:o=>o.objectType===5?o:null,creature:id=>{calls.push(['creature',id]);const o=objects.get(id);return o?.objectType===5?o:null;},
   client:id=>{calls.push(['client',id]);return null;},exitSuppressed:()=>c.suppressed??0,enqueue:(d,t,caller,target,id,data)=>calls.push(['event',d,t,caller,target,id,data.type]),
   area:()=>{calls.push(['area']);return actor.areaId===88?area:null;},removeCreature:(o,flag)=>{calls.push(['removeCreature',flag]);o.areaId=OBJECT_INVALID;erase(o.id);},
   followingIds:()=>c.following??[],asAreaEffect:o=>o.objectType===11?o:null,addAreaEffect:(o,a,x,y,z,flag)=>calls.push(['addAoE',o.id,a?.id??null,[x,y,z],flag]),
   dead:o=>{calls.push(['dead',o.id]);return c.dead??0;},dying:o=>{calls.push(['dying',o.id]);return 0;},autoMapEnabled:()=>0,
   position:(o,point)=>{o.position=point;},addObject:(_a,id,flag)=>calls.push(['addObject',id,flag]),setArea:(o,a)=>{calls.push(['setArea',a?.id??null]);o.areaId=a?.id??OBJECT_INVALID;},
   hasAI:()=>c.hasAI!==false,setAILevel:(o,n)=>{calls.push(['ai',n]);o.nativeAILevel7c=n;}};
  if(kind==='object')assert.equal(await addAreaObject(area,99,c.flag??1,p),row.result);else await addCreatureToArea(actor,c.nullArea?null:area,3,4,5,c.force??0,c.flag??1,p);
  const label=JSON.stringify({kind,...c});assert.deepEqual(calls,row.calls,label);assert.deepEqual(area.ids,row.ids,label);assert.equal(actor.areaId,row.areaId,label);assert.deepEqual(actor.position,row.position,label);assert.equal(actor.nativeAILevel7c,row.level,label);
 }
});
