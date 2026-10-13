import test from 'node:test';
import assert from 'node:assert/strict';
import { parseTileSurfaceMesh,tileSurfaceHeight,areaTileHeight } from '../src/tile_surface_mesh.js';
import { parse2da } from '../src/area.js';
import { NativeAreaGeometry } from '../src/area_geometry.js';

function mesh(material=0){return parseTileSurfaceMesh(`#MAXWALKMESH ASCII\nnode aabb surface\nposition 0 0 0\nverts 3\n-5 -5 0\n5 -5 10\n-5 5 0\nfaces 1\n0 1 2 0 0 0 0 ${material}\nendnode\n`,parse2da('2DA V2.0\n\nWalk\n0 1\n1 0\n'));}
test('native tile height preserves source face order, walks before denied faces and ignores input height',()=>{
  const m=mesh(),denied=mesh(1);assert.equal(tileSurfaceHeight(m,[2,3,100]),2);assert.equal(tileSurfaceHeight(denied,[2,3,-100]),2);
  m.vertices.push([0,0,7],[10,0,7],[0,10,7]);m.faces.push([3,4,5]);m.normals.push([0,0,1]);m.constants.push(-7);
  assert.equal(tileSurfaceHeight(m,[2,3,100]),2);assert.equal(tileSurfaceHeight(m,[9,9,100]),0);
  assert.equal(tileSurfaceHeight(m,[0,0,100]),-0);assert.equal(tileSurfaceHeight(m,[10,0,100]),10);
});
test('native tile height rotates local coordinates and adds tile height once, including far tile coordinates',()=>{
  const tile={x:31,y:30,orientation:1,heightOffset:7.5,mesh:mesh()};
  assert.equal(areaTileHeight(tile,[318,302,100]),9.5);
  tile.orientation=2;assert.equal(areaTileHeight(tile,[318,307,100]),9.5);
});
test('native area height uses lower-inclusive ten-unit slots, native32-slot limit and outside -6',async()=>{
  const a={width:40,height:1},geometry=new NativeAreaGeometry(a,{}),calls=[];
  geometry.tile=async(x,y)=>{calls.push([x,y]);return y===0&&x<a.width?{x,y,orientation:0,heightOffset:x*2.5,mesh:mesh()}:null;};
  assert.equal(await geometry.height([12,3,500]),4.5);assert.deepEqual(calls,[[1,0]]);
  assert.equal(await geometry.height([-0.001,3,0]),-6);assert.equal(await geometry.height([320,3,0]),-6);
  assert.equal(await geometry.height([10,3,0]),2.5);assert.equal(await geometry.height([0,10,0]),-6);
});
