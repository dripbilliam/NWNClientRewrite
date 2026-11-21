import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {deformSkinnedVertices,updateSkinnedMesh} from '../src/model_skinning.js';

test('a cached diagnostic box cannot reject a click after skin deformation',()=>{
 const bone=new THREE.Group(),skin=new THREE.Group(),nodes=[{name:'bone'}],groups=new Map([['bone',bone]]);
 const node={verts:[[0,0,0],[1,0,0],[0,0,1]],skinData:{boneConstantSlots:[0],qboneRefInv:[[1,0,0,0]],tboneRefInv:[[0,0,0]],weights:Array.from({length:3},()=>[1,0,0,0]),boneIndices:Array.from({length:3},()=>[0,65535,65535,65535])}};
 const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(new Float32Array(9),3));
 const mesh=new THREE.Mesh(geometry,new THREE.MeshBasicMaterial({side:THREE.DoubleSide}));mesh.userData.sourceVertexIndices=[0,1,2];mesh.updateMatrixWorld(true);
 const update=()=>updateSkinnedMesh(mesh,deformSkinnedVertices(node,nodes,groups,skin));
 try{
  update();const before=new THREE.Box3().setFromObject(mesh);assert.equal(before.max.x,1);assert.ok(geometry.boundingBox);
  bone.position.x=5;update();
  const ray=new THREE.Raycaster(new THREE.Vector3(5.2,.2,2),new THREE.Vector3(0,0,-1));
  assert.equal(ray.intersectObject(mesh).length,1,'the moved triangle is pickable before diagnostics rebuild its box');
  const after=new THREE.Box3().setFromObject(mesh);assert.equal(after.min.x,5);assert.equal(after.max.x,6);
  bone.position.x=-5;update();
  assert.equal(ray.intersectObject(mesh).length,0);assert.equal(new THREE.Box3().setFromObject(mesh).max.x,-4);
 }finally{geometry.dispose();mesh.material.dispose();}
});
