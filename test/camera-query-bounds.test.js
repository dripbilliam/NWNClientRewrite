import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {BoxGeometry,Group,Mesh,MeshBasicMaterial} from 'three';
import {cameraSceneQuery} from '../src/camera_scene_query.js';
import {cameraFaceBounds,cameraSegmentOverlaps} from '../src/camera_query_bounds.js';
import {nativePolygonPlane} from '../src/native_polygon_hit.js';

test('bounds cannot reject any of the 1876 original polygon oracle crossings',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-camera-polygon-observations.json',import.meta.url)));
 for(const row of oracle.rows){const c=row.case,face={vertices:c.vertices.map(v=>v.map(Math.fround)),normal:c.normal.map(Math.fround),constant:Math.fround(c.constant)},bounds=cameraFaceBounds(face);if(row.result)assert.equal(cameraSegmentOverlaps(bounds,c.start.map(Math.fround),c.end.map(Math.fround)),true,JSON.stringify(c));}
});

test('unsafe planes, nonplanar polygons and slivers keep the unfiltered native path',()=>{
 const face={vertices:[[0,0,0],[1,0,0],[0,1,0]],normal:[0,0,1],constant:0};
 for(const unusual of [{...face,normal:[0,0,0]},{...face,constant:5},{...face,normal:[0,0,-1]},{...face,vertices:[[0,0,0],[1,0,0],[0,1e-8,0]]},{...face,vertices:[...face.vertices,[1,1,1]]}])assert.equal(cameraFaceBounds(unusual),null);
 assert.equal(cameraSegmentOverlaps(null,[100,100,100],[200,200,200]),true);
});

test('bounded first/nearest/normal queries match exhaustive queries through changing negative scales, poses and source lists',()=>{
 const root=new Group(),geometry=new BoxGeometry(),material=new MeshBasicMaterial(),meshes=[];
 for(let i=0;i<60;i++){const tile=new Group();tile.userData.nativeStaticTile=true;tile.position.set((i%10)*2-10,.5,Math.floor(i/10)*2-6);root.add(tile);const mesh=new Mesh(geometry,material);mesh.userData.nativeModelMesh=true;tile.add(mesh);meshes.push(mesh);}
 const walkmesh=[{vertices:[[-20,0,20],[20,0,20],[-20,0,-20]],surfaceType:0}],fast=cameraSceneQuery(root,walkmesh),full=cameraSceneQuery(root,walkmesh,{broadphase:false});let state=29;const random=()=>((state=Math.imul(state,1664525)+1013904223>>>0)/2**32);
 for(let i=0;i<600;i++){
  if(i%30===0){const mesh=meshes[i/30];mesh.parent.rotation.set(random(),random(),random());mesh.scale.set(i%60?-1:2,1.5,.7);mesh.position.x=random();}
  fast.update();full.update();const from=[(random()-.5)*30,(random()-.5)*30,random()*12],to=[(random()-.5)*30,(random()-.5)*30,-random()];
  assert.equal(fast(from,to),full(from,to));assert.deepEqual(fast.nearest(from,to),full.nearest(from,to));assert.deepEqual(fast.nearestHit(from,to),full.nearestHit(from,to));
 }
 assert.ok(fast.stats().faceTests<full.stats().faceTests/3);
 const special=new BoxGeometry();meshes[0].geometry=special;special.userData.nativeCameraHitFaces=[];fast.update();full.update();assert.deepEqual(fast.nearest([0,0,10],[0,0,-1]),full.nearest([0,0,10],[0,0,-1]));
 const vertices=[[-100,-100,8],[100,-100,8],[0,100,8]];special.userData.nativeCameraHitFaces=[{vertices,...nativePolygonPlane(vertices)}];fast.update();full.update();assert.deepEqual(fast.nearestHit([0,0,10],[0,0,-1]),full.nearestHit([0,0,10],[0,0,-1]));
 // Explicit invalidation also supports an editor replacing source values in place.
 special.userData.nativeCameraHitFaces[0].vertices[0][0]=-101;fast.invalidate(special);full.invalidate(special);assert.deepEqual(fast.nearest([0,0,10],[0,0,-1]),full.nearest([0,0,10],[0,0,-1]));geometry.dispose();special.dispose();material.dispose();
});
