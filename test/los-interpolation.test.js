import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {clipAreaTileLOS,intersectLOSBox,clearTileSurfaceLOS} from '../src/tile_los.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-los-interpolation-observations.json',import.meta.url)));
const decode=v=>v==='NaN'?NaN:v==='+Infinity'?Infinity:v==='-Infinity'?-Infinity:v;
test('LOS tile clipping matches original quarter-turn IEEE height outputs without invented finite heights',()=>{
  for(const row of capture.rows){const c=row.case,value=clipAreaTileLOS({x:1,y:2,orientation:c.orientation,mesh:{}},c.start,c.goal);
    assert.deepEqual(value,{status:row.status,entry:row.entry.map(decode),exit:row.exit.map(decode)},JSON.stringify(c));
  }
});
test('original box/AABB/polygon kernels agree on finite, NaN and infinite clipped heights',()=>{
  const mesh={vertices:[[0,-2,-2],[0,2,-2],[0,0,2]],faces:[[0,1,2]],adjacency:[[-3,-3,-3]],materials:[1],normals:[[1,0,0]],constants:[0],
    aabb:{min:[-.01,-2.01,-2.01].map(Math.fround),max:[.01,2.01,2.01].map(Math.fround),sourceFace:0,face:0,denied:false}};
  for(const row of capture.kernels){const c=row.case,start=c.start.map(decode),goal=c.goal.map(decode),output=[99,99,99];
    const box=intersectLOSBox(start,goal,mesh.aabb.min,mesh.aabb.max),status=clearTileSurfaceLOS(mesh,1,start,goal,output,2n);
    assert.deepEqual({box:box>>>0,status,output},{box:row.box,status:row.status,output:row.output.map(decode)},JSON.stringify(c));
  }
});
