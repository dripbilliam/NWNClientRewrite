import fs from 'node:fs';import test from 'node:test';import assert from 'node:assert/strict';import * as THREE from 'three';
import {nativeSkinBoneMatrices,deformSkinnedVertices} from '../src/model_skinning.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-skin-bones-v1.json',import.meta.url)));
test('30 original ExecuteSkinGPU cases match inverse binds, slot mapping and duplicate-root termination',()=>{
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,30);
 for(const row of oracle.cases){const before=structuredClone(row),actual=nativeSkinBoneMatrices(row.slots,row.positions,row.quaternions,row.inversePositions,row.inverseQuaternions);assert.deepEqual(Object.keys(actual).map(Number),row.matrices.map(m=>m.slot));
  for(const m of row.matrices)for(let i=0;i<16;i++)assert.ok(Math.abs(actual[m.slot][i]-m.matrix[i])<2e-6,JSON.stringify({row,slot:m.slot,index:i,actual:actual[m.slot][i]}));assert.deepEqual(row,before);
 }
});
test('inverse bind cancels rest pose, retains animated displacement, and excludes Part scale and world placement',()=>{
 const root=new THREE.Group(),bone=new THREE.Group(),skin=new THREE.Group();root.add(bone,skin);root.position.set(100,20,-70);root.scale.setScalar(3);bone.position.set(2,3,-4);bone.scale.setScalar(7);root.updateMatrixWorld(true);
 const node={verts:[[1,2,3]],skinData:{boneConstantSlots:[0],qboneRefInv:[[1,0,0,0]],tboneRefInv:[[-2,-4,-3]],weights:[[1,0,0,0]],boneIndices:[[0,65535,65535,65535]]}},nodes=[{name:'bone'}],groups=new Map([['bone',bone]]);
 assert.deepEqual(deformSkinnedVertices(node,nodes,groups,skin),[[1,3,-2]]);bone.position.x+=.5;root.updateMatrixWorld(true);assert.deepEqual(deformSkinnedVertices(node,nodes,groups,skin),[[1.5,3,-2]]);
 assert.throws(()=>nativeSkinBoneMatrices([0],[[0,0,0]],[[1,0,0,0]],[],[]),/inverse-bind/);
});
