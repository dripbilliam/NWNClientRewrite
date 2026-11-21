import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {removeGroundObjectFromArea,addGroundObjectToArea,addStoreToArea,removePlaceableFromArea,addPlaceableToArea} from '../src/world_object_area.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-world-object-area-observations.json',import.meta.url)));

test('world-object area ownership matches full original add/remove paths for null, same and new areas',async()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],actor={id:99,areaId:c.oldArea?88:OBJECT_INVALID,position:[1,2,3],orientation:[.6,.8,0].map(Math.fround),nativeCollisionSlot:c.slot},areas=new Map([[88,{id:88}],[89,{id:89}]]),
   destination=c.destination==='null'?null:areas.get(c.destination==='same'?88:89),mesh=c.mesh==='null'?null:{vertices:c.mesh==='full'?[[1,0,0],[1,1,0],[1,1,1]]:[],faces:c.mesh==='full'?[[0,1,2]]:[]},p={
    area:o=>{calls.push(['area']);return areas.get(o.areaId)??null;},setArea:(o,a)=>{calls.push(['setArea',a?.id??null]);o.areaId=a?.id??OBJECT_INVALID;},
    position:(o,point)=>{o.position=[...point];},orientation:o=>o.orientation,nativePosition:o=>o.position,
    removeObject:(a,id)=>calls.push(['removeObject',a.id,id]),addObject:(a,id,flag)=>calls.push(['addObject',a.id,id,flag]),
    removeStatic:(a,slot)=>calls.push(['removeStatic',a.id,slot]),removeTrap:(a,id)=>calls.push(['removeTrap',a.id,id]),
    walkMesh:()=>{calls.push(['mesh',(c.appearance??50)&65535]);return mesh;},
    addStatic:(a,id,orientation,position,surface)=>{calls.push(['addStatic',a.id,id,orientation,[...position],surface.vertices.length,surface.faces.length]);return c.newSlot??4;},
    computeBoundingBox:()=>calls.push(['bbox']),staticBounds:(a,slot)=>{calls.push(['bounds',a.id,slot]);return[[-1,-2,-3],[4,5,6]];},
    displaceObjects:(a,point,min,max,id,flag)=>calls.push(['displace',a.id,[...point],min,max,id,flag]),
   };
  p.removeGround=o=>removeGroundObjectFromArea(o,p);p.removePlaceable=o=>removePlaceableFromArea(o,p);
  if(row.mode==='addPlaceable')await addPlaceableToArea(actor,destination,6.125,-7.25,8.5,c.flag,p);
  else if(row.mode==='removePlaceable')await removePlaceableFromArea(actor,p);
  else if(row.mode==='addStore')await addStoreToArea(actor,destination,6.125,-7.25,8.5,c.flag,p);
  else if(row.mode.startsWith('add'))await addGroundObjectToArea(actor,destination,6.125,-7.25,8.5,c.flag,p);
  else await removeGroundObjectFromArea(actor,p);
  const label=JSON.stringify({mode:row.mode,...c});assert.deepEqual(calls,row.calls,label);assert.equal(actor.areaId,row.areaId,label);assert.deepEqual(actor.position,row.position,label);assert.equal(actor.nativeCollisionSlot,row.slot,label);
 }
 assert.equal(native.rows.length,426);
});
