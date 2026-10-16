import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {NativeIdList} from '../src/native_id_list.js';
import {initializeAutomapState,clearAutomap,postProcessAutomap,reconcileAutomap,setAutomap,getTileExplored,setTileExplored,setAllTilesExplored,updateAutomap,exploreArea,loadAutomap,automapByteCount} from '../src/automap.js';
const pattern=(seed,step,i)=>Uint8Array.from({length:128},(_,j)=>(seed+i*step+j)&255);
test('automap storage, import, bits and exploration coordinators match 2,200 original executions',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-automap-observations.json',import.meta.url)));assert.equal(data.rows.length,2200);
 for(const row of data.rows){
  const c=row.case,calls=[],actor={id:99,nativeField89c:c.pc??1,nativeAutoMapEnabled6e0:c.enabled??1,nativeAutoMapTileX6e4:0x78,nativeAutoMapTileY6e5:0x56,nativeAutoMapArea6e8:0x76543210},target={id:100},o=['update','explore'].includes(c.operation)?target:actor;
  initializeAutomapState(actor);initializeAutomapState(target);const list=o.nativeAutoMapAreaIds6c8;list.setSize(c.old.length);list.ids.set(c.old);
  const old=c.old.map((_,i)=>pattern(c.seed??7,31,i));o.nativeAutoMapBuffers6d8=c.null?null:old.slice();
  const area={id:88,width:c.width??4,height:c.height??3,flags:c.flags??0,nativeMapByteCount348:c.bytes??2},module={},p={
   module:()=>{calls.push(['module']);return module;},moduleIds:()=>c.next,
   areaById:id=>{calls.push(['areaById',id]);return c.area!==false&&id===88?area:null;},
   client:id=>{calls.push(['client',id]);return c.client?{}:null;},update:(o,id)=>calls.push(['update',o.id,id]),
   area:o=>{calls.push(['area',o.id]);return c.area===false?null:area;},creature:id=>{calls.push(['creature',id]);return c.target===false?null:target;},
   possessedFamiliar:o=>{calls.push(['possessed',o.id]);return c.possessed??0;},position:()=>c.position??[15,15,2],tileExists:()=>true,
   explore:(a,o,x,y,r)=>calls.push(['explore',a.id,o.id,x,y,r]),
   dfs:(a,visited,depth,x,y,lx,ly)=>{calls.push(['dfs',a.id,depth,x,y,lx,ly]);visited.set(c.visited);},
  };
  let result;
  if(c.operation==='clear')clearAutomap(actor);
  else if(c.operation==='load'){
   const bytes=new Uint8Array(c.saved.length*4),view=new DataView(bytes.buffer);c.saved.forEach((id,i)=>view.setUint32(i*4,id,true));
   loadAutomap(actor,{Mod_MapNumAreas:c.saved.length,Mod_MapAreasData:bytes,Mod_MapAutoExplores:c.auto,...(c.list==='absent'?{}:{Mod_MapDataList:c.list==='empty'?[]:c.saved.map((_,i)=>({Mod_MapData:pattern(111,17,i)}))})});
  }
  else if(c.operation==='reconcile')await reconcileAutomap(actor,p);
  else if(c.operation==='set')await setAutomap(actor,c.incoming,c.incoming.map((_,i)=>pattern(111,17,i)),p);
  else if(c.operation==='post')await postProcessAutomap(actor,p);
  else if(c.operation==='get')result=await getTileExplored(actor,88,c.x,c.y,p);
  else if(c.operation==='bit')await setTileExplored(actor,88,c.x,c.y,c.value,p);
  else if(c.operation==='all')await setAllTilesExplored(actor,88,c.value,p);
  else if(c.operation==='update')await updateAutomap(actor,100,p);
  else result=await exploreArea(area,target,c.x,c.y,c.range,p);
  const maps=o.nativeAutoMapBuffers6d8,got={calls,ids:[...list.view()],capacity:list.capacity,outer:maps!==null,maps:maps?Array.from({length:list.count},(_,i)=>maps[i]?createHash('sha256').update(maps[i]).digest('hex'):null):Array(list.count).fill(null),owners:maps?Array.from({length:list.count},(_,i)=>{const index=old.indexOf(maps[i]);return index<0?null:index;}):Array(list.count).fill(null),enabled:actor.nativeAutoMapEnabled6e0,cache:[0x12345678,actor.nativeAutoMapArea6e8],...(['get','explore'].includes(c.operation)?{result}:{})};
  assert.deepEqual(got,{calls:row.calls,ids:row.ids,capacity:row.capacity,outer:row.outer,maps:row.maps,owners:row.owners,enabled:row.enabled,cache:row.cache,...(['get','explore'].includes(c.operation)?{result:row.result}:{})},JSON.stringify(c));
 }
});
test('incomplete imported automap buffers remain explicit failures',()=>{
 const o={};initializeAutomapState(o);
 assert.throws(()=>loadAutomap(o,{Mod_MapDataList:[{Mod_MapData:new Uint8Array(12)}]}),/indeterminate/);
 assert.throws(()=>loadAutomap(o,{Mod_MapNumAreas:1}),/indeterminate/);
});
test('area map byte sizing matches 1,089 original loader/CRT executions',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-automap-size-observations.json',import.meta.url)));assert.equal(data.rows.length,1089);
 for(const row of data.rows)assert.equal(automapByteCount(row.width,row.height),row.bytes,JSON.stringify(row));
});
