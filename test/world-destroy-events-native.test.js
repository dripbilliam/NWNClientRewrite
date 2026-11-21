import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveWorldDestroy,closePlaceableInventory,placeableItemCount} from '../src/world_destroy_event.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-world-destroy-events-observations.json',import.meta.url)));
test('world destroy events preserve original type-specific gates and ordered cleanup',async()=>{
 for(const row of data.events){
  const c=row.case,calls=[],o={id:99,objectType:{placeable:9,waypoint:12,store:14}[c.kind],areaId:c.area?88:OBJECT_INVALID,nativeDestroyableF0:c.destroyable};
  if(c.event===11)await receiveWorldDestroy(o,{
   closeInventory:()=>calls.push(['close']),spawnBag:()=>calls.push(['bag']),
   removePlaceableArea:o=>{calls.push(['removeArea']);o.areaId=OBJECT_INVALID;},removeWaypointArea:o=>{calls.push(['removeArea']);o.areaId=OBJECT_INVALID;},
   area:o=>{calls.push(['area']);return o.areaId===88?{}:null;},removeAreaObject:(_a,id)=>calls.push(['removeObject',id]),setArea:o=>{calls.push(['setArea',null]);o.areaId=OBJECT_INVALID;},destroy:(_o,flag)=>calls.push(['destroy',flag]),
  });
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(o.areaId,row.areaId,JSON.stringify(c));
 }
 assert.equal(data.events.length,96);
});
test('placeable CloseInventory matches original live-client recheck, nonzero gates and last-observer event',async()=>{
 for(const row of data.closes){
  const c=row.case,calls=[],o={id:99,nativeHasInventory4f8:c.hasInventory,nativeField508:c.count},clients=c.controlled.map((_,i)=>({i,live:false}));
  await closePlaceableInventory(o,{
   clients:()=>{calls.push(['clients']);return clients;},clientObject:client=>{calls.push(['controlled',client.i]);return c.controlled[client.i]?{id:100+client.i}:null;},
   inventory:client=>({ownerId:(client.live?c.liveOwners:c.owners)[client.i],open:c.open[client.i]}),
   client:id=>{const i=id-100;calls.push(['client',i]);return c.live[i]?{i,live:true}:null;},
   inventoryStatus:(client,...args)=>calls.push(['status',client.i,...args]),setInventoryOpen:(client,...args)=>calls.push(['setOpen',client.i,...args]),
   clearInventory:(client,...args)=>calls.push(['clear',client.i,...args]),guiMessage:(client,...args)=>calls.push(['gui',client.i,...args]),
   enqueue:(caller,target,id,payload)=>calls.push(['event',caller,target,id,payload.type]),setAnimation:(_o,animation)=>calls.push(['animation',animation]),
  });
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(o.nativeField508,row.count,JSON.stringify(c));
 }
 assert.equal(data.closes.length,480);
});
test('placeable direct item count matches original HasInventory and droppable gates',()=>{
 for(const row of data.counts){
  const c=row.case,calls=[],nodes=c.items.map((v,i)=>({value:v,i}));nodes.forEach((node,i)=>node.next=nodes[i+1]??null);
  const result=placeableItemCount({nativeHasInventory4f8:c.hasInventory},c.filter,{repository:()=>c.repo?{head:nodes[0]??null}:null,repositoryItem:(_r,n)=>{calls.push(['item',n.i]);return n.value===null?null:{droppable:n.value};}});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(result,row.result,JSON.stringify(c));
 }
 assert.equal(data.counts.length,96);
});
