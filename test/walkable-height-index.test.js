import test from 'node:test';import assert from 'node:assert/strict';
import {findWalkableHeight} from '../src/walkmesh.js';import {WalkableHeightIndex} from '../src/walkable_height_index.js';import {NetworkScene} from '../src/network_scene.js';
const triangle=(...vertices)=>({vertices});
function terrain(size=24){const rows=[];for(let x=-size;x<size;x++)for(let z=-size;z<size;z++){const a=[x*10,Math.sin(x+z),z*10],b=[x*10+10,Math.sin(x+z+1),z*10],c=[x*10+10,Math.sin(x+z+2),z*10+10],d=[x*10,Math.sin(x+z+1),z*10+10];rows.push(triangle(a,b,c),triangle(a,c,d));}return rows;}
test('spatial candidates preserve exact barycentric results, sloped layers, ties and tolerant edges',()=>{
 const rows=terrain(10);rows.splice(17,0,triangle([0,2,0],[10,2,0],[10,2,10]),triangle([0,-2,0],[10,-2,0],[10,-2,10]));const index=new WalkableHeightIndex(rows);let seed=19;
 const random=()=>((seed=Math.imul(seed,1664525)+1013904223|0)>>>0)/2**32;
 const check=(x,z,r=Infinity,d=Infinity)=>assert.ok(Object.is(index.height(x,z,r,d),findWalkableHeight(rows,x,z,r,d)),JSON.stringify([x,z,r,d]));
 for(let i=0;i<12000;i++)check(random()*240-120,random()*240-120,i%3?random()*8-4:Infinity,i%5?Infinity:.2);
 for(let i=-10;i<=10;i++)for(const e of [-1e-4,-1e-5,-1e-8,0,1e-8,1e-5,1e-4]){check(i*10+e,i*10-e);check(i*10+e,0,0);}
 check(5,2,0);check(5,2,Infinity);check(5,2,NaN);check(5,2,0,NaN);
 const stats=index.snapshot();assert.ok(stats.candidates<stats.queries*rows.length*.03);assert.equal(stats.fullScans,0);index.dispose();assert.equal(index.snapshot().cells,0);assert.equal(index.source,null);
});
test('exceptional numerical geometry and bounded-memory fallback retain original order and behavior',()=>{
 const rows=[...terrain(2),triangle([0,NaN,0],[4,NaN,0],[0,NaN,4]),triangle([0,0,0],[1e10,2,1e10],[1e10+1,3,1e10]),triangle([0,0,0],[100000,1,0],[100000,2,1e-12]),triangle([0,3,0],[1e4,3,0],[0,3,1e4])];
 for(const options of [{},{maxReferences:1}]){const index=new WalkableHeightIndex(rows,options);for(const [x,z]of [[0,0],[2,1],[20,20],[-1e10,1e10],[Infinity,0],[NaN,0],[1e300,1e300]])for(const reference of [0,4,Infinity,NaN])assert.ok(Object.is(index.height(x,z,reference),findWalkableHeight(rows,x,z,reference)));if(options.maxReferences)assert.equal(index.fallback,true);index.dispose();}
});
test('source length changes fall back, and NetworkScene replacement/disposal owns the static index',async()=>{
 const rows=terrain(1),index=new WalkableHeightIndex(rows);rows.push(triangle([0,9,0],[10,9,0],[0,9,10]));assert.equal(index.height(2,2),findWalkableHeight(rows,2,2));assert.equal(index.fullScans,1);
 const scene=new NetworkScene({world:{registry:{objects:new Map()}},resolver:{},report:()=>{},loadAsset:async()=>{},instantiate:()=>{},releaseAsset:()=>{}});
 assert.equal(scene.motion.height([2,-2,0],4),4,'Before ground arrives, preserve the replicated height');
 scene.setGroundWalkmesh({triangles:rows,cameraTriangles:[]});const first=scene.groundHeightIndex;assert.equal(first.height(2,2),9);
 scene.setGroundWalkmesh({triangles:[],cameraTriangles:[]});assert.equal(first.closed,true);assert.equal(first.source,null);const second=scene.groundHeightIndex;await scene.dispose();assert.equal(second.closed,true);assert.equal(second.cells.size,0);assert.equal(scene.groundHeightIndex,null);assert.equal(scene.retiredGroundHeightIndex.closed,true);assert.equal(scene.retiredGroundHeightIndex.cells,0);
 scene.setGroundWalkmesh({triangles:rows,cameraTriangles:[]});assert.equal(scene.groundHeightIndex,null);index.dispose();
});
