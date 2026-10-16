import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {parseObjectSurfaceMesh} from '../src/object_surface_mesh.js';
import {computePlaceableActionPoints,nearestPlaceableActionPoint} from '../src/placeable_action_point.js';
const read=name=>JSON.parse(fs.readFileSync(new URL(`../backups/animations/${name}`,import.meta.url)));

test('PWK action-point parsing matches original constructor and full dummy-node loader',()=>{
 const data=read('native-placeable-point-loader-observations.json');
 for(const row of data.rows){const warnings=[],mesh=parseObjectSurfaceMesh(row.text,'placeable',{warning:message=>warnings.push(message)});assert.deepEqual(mesh.actionPoints,row.points,row.text);assert.deepEqual(warnings,row.warnings,row.text);assert.equal(row.result,1);}
 assert.equal(data.rows.length,55);
});

test('placeable world points match original transforms, retained cells, height inputs and one-sided slope rejection',async()=>{
 const data=read('native-placeable-action-point-observations.json');assert.equal(data.angleLimit,1.0472);
 for(const row of data.rows){
  const c=row.case,calls=[],object={nativePlaceableActionPoints550:(c.old??[[7,8,9],[-7,-8,-9]]).map(v=>v.map(Math.fround)),position:(c.position??[10,20,3]).map(Math.fround),orientation:(c.orientation??[0,1,0]).map(Math.fround)},references=[...object.nativePlaceableActionPoints550],
   p={area:()=>{calls.push(['area']);return c.area===false?null:{};},walkMesh:()=>{calls.push(['mesh',(c.appearance??50)&65535]);return c.mesh===false?null:{actionPoints:(c.local??[[1,2,0],[-1,-2,0]]).map(v=>v.map(Math.fround))};},
    orientation:o=>o.orientation,position:o=>o.position,height:(_a,point)=>{calls.push(['height',point]);return c.height;}};
  const label=JSON.stringify({mode:row.mode,...c});
  if(row.mode==='compute')await computePlaceableActionPoints(object,p);
  else assert.deepEqual(nearestPlaceableActionPoint(object,c.from??[10,20,3],p),row.point,label);
  assert.deepEqual(calls,row.calls,label);assert.deepEqual(object.nativePlaceableActionPoints550,row.points,label);assert.equal(object.nativePlaceableActionPoints550[0],references[0]);assert.equal(object.nativePlaceableActionPoints550[1],references[1]);
 }
 assert.equal(data.rows.length,514);
});

test('unmapped malformed point storage and CRT NaN state fail explicitly',async()=>{
 assert.throws(()=>parseObjectSurfaceMesh('node dummy plc_pwk_use03\nposition 1 2 3\n','placeable'),/diagnostic delivery/);
 assert.throws(()=>nearestPlaceableActionPoint({},[0,0,0],{}),/world action points/);
 const object={nativePlaceableActionPoints550:[[0,0,0],[0,0,0]]};
 await assert.rejects(computePlaceableActionPoints(object,{area:()=>({}),walkMesh:()=>({actionPoints:[[0,0,1],[0,0,0]]}),position:()=>[0,0,0],orientation:()=>[0,1,0],height:()=>0}),/NaN\/CRT/);
});
