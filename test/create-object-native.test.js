import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptCreateObject,objectTemplateResRef} from '../src/create_object.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-create-object-observations.json',import.meta.url)));

test('CreateObject matches original five-type dispatch, ordering, placement, appearance and map-pin routing',async()=>{
 let count=0;
 for(const row of native.rows){
  const c=row.case;if(c.popFail!==undefined)continue;
  const calls=[],object={id:99,nativePathInfo:{},nativeMessageFields:{0x308:c.note??0,0x30c:c.enabled??0},trapped:c.trap??0,areaId:OBJECT_INVALID,nativeMapNote310:{strRef:10,entries:[]}},area={id:88},location={areaId:88,position:[1,2,3],nativeOrientation:[.6,.8,0].map(Math.fround)},before=structuredClone(location);
  const args=[c.type,c.reference??'MiXeD_blueprint_LONG',location,c.appear??0,c.tag??'new tag'].slice(0,c.argc??5);
  const result=await scriptCreateObject(args,77,{
   getGameObject:id=>{calls.push(['lookup',id]);return{status:c.lookupStatus??0,object:area};},
   construct:kind=>{calls.push(['construct',kind]);return object;},
   loadTemplate:(kind,o,ref,tag)=>{assert.equal(o,object);calls.push(['load',kind,ref,tag.split('\0')[0]]);return c.load??1;},
   warning:message=>calls.push(['warning',message]),destroy:o=>calls.push(['destroy',o.id]),
   asArea:o=>{assert.equal(o,area);calls.push(['asArea']);return c.nonarea?null:area;},
   orientation:(o,v)=>{assert.equal(o,object);calls.push(['orientation',v]);},
   placeableOrientation:(o,v)=>{assert.equal(o,object);calls.push(['placeableOrientation',v]);},
   position:(o,v,flag)=>{assert.equal(o,object);calls.push(['position',v,flag]);},
   safeLocation:(a,point,radius,path,flag,out)=>{assert.equal(path,object.nativePathInfo);calls.push(['safe',a?.id??null,point,radius,flag]);out.splice(0,3,...(c.safeOutput??[6,7,8]));return c.safe??1;},
   height:(a,point)=>{calls.push(['height',a?.id??null,point]);return c.height??9;},
   createEffect:flag=>{calls.push(['effect',flag]);return{integers:Array(8).fill(0)};},
   setCreator:(e,id)=>{calls.push(['creator',id]);e.creatorId=id;},
   applyEffect:(o,e,a,b)=>{assert.equal(o,object);calls.push(['apply',e.type,e.creatorId,e.integers[0],a,b]);},
   addToArea:(kind,o,a,x,y,z,flag,last)=>{calls.push(['add',kind,a?.id??null,[x,y,z],flag,last??null]);o.areaId=a?.id??OBJECT_INVALID;o.nativePosition=[x,y,z];},
   appendTrap:(a,id)=>calls.push(['trap',a?.id??null,id]),nativePosition:o=>o.nativePosition,
   message:()=>{calls.push(['message']);return{};},clients:()=>{calls.push(['clients']);return(c.clients??[]).map((_,i)=>i);},
   clientObject:i=>{calls.push(['clientObject',i]);return c.clients[i]===null?null:{areaId:c.clients[i]};},
   mapPin:(_m,i,id,point,note,enabled)=>{assert.equal(note,object.nativeMapNote310);calls.push(['mapPin',i,id,point,enabled]);},
  });
  const label=JSON.stringify(c);assert.deepEqual(calls,row.calls,label);assert.equal(result,row.result,label);assert.deepEqual(location,before,`${label}: VM location copy`);count++;
 }
 assert.equal(count,422);
});

test('original VM pop/push errors retain distinct cleanup ordering',()=>{
 for(const row of native.rows){
  const c=row.case,events=row.events,freeLocation=events.findIndex(e=>e[0]==='free'&&e[1]==='location'),push=events.findIndex(e=>e[0]==='push');
  if(c.popFail!==undefined){assert.equal(row.status,-639);assert.equal(push,-1);assert.equal(freeLocation,-1);continue;}
  assert.equal(row.status,c.push===0?-638:0);
  if(c.load===0){assert.ok(freeLocation>=0&&freeLocation<push);assert.ok(row.calls.findIndex(e=>e[0]==='destroy')>row.calls.findIndex(e=>e[0]==='warning'));}
  else if(c.push===0)assert.equal(freeLocation,-1);
  else assert.ok(freeLocation>push);
 }
});

test('native blueprint byte truncation preserves case and active resolver ownership',()=>{
 assert.equal(objectTemplateResRef('MiXeDabcdefghijklmnop'),'MiXeDabcdefghijk');
 assert.equal(objectTemplateResRef('AbC\0ignored'),'AbC');
 assert.equal(objectTemplateResRef('é€Case'),'é€Case');
 assert.throws(()=>objectTemplateResRef('💫'),/byte encoding/);
});
