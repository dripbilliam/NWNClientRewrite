import test from 'node:test';import assert from 'node:assert/strict';import * as T from 'three';import {updateSkinnedMesh} from '../src/model_skinning.js';
function reference(mesh,vertices){const g=mesh.geometry,p=g.getAttribute('position');mesh.userData.sourceVertexIndices.forEach((source,index)=>p.setXYZ(index,...vertices[source]));p.needsUpdate=true;g.computeVertexNormals();g.boundingBox=null;g.computeBoundingSphere();}
function compare(geometry,vertices,sources){
 const a=new T.Mesh(geometry),b=new T.Mesh(geometry.clone());a.userData.sourceVertexIndices=b.userData.sourceVertexIndices=sources;geometry.computeBoundingBox();b.geometry.computeBoundingBox();
 try{updateSkinnedMesh(a,vertices);reference(b,vertices);for(const name of['position','normal']){const actual=a.geometry.getAttribute(name),expected=b.geometry.getAttribute(name);assert.deepEqual(new Uint8Array(actual.array.buffer),new Uint8Array(expected.array.buffer),name+' bytes');assert.equal(actual.version,expected.version,name+' version');}assert.deepEqual(a.geometry.boundingSphere,b.geometry.boundingSphere);assert.equal(a.geometry.boundingBox,null);assert.deepEqual(new T.Box3().setFromObject(a),new T.Box3().setFromObject(b));}finally{a.geometry.dispose();b.geometry.dispose();a.material.dispose();b.material.dispose();}
}
test('flat skin normals and bounds match Three byte-for-byte across varied triangles and repeated source indices',()=>{
 let seed=561237;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
 for(const scale of[1e-12,1e-3,1,1e3,1e10]){const vertices=Array.from({length:173},()=>Array.from({length:3},()=>Math.fround((random()-.5)*scale))),sources=Array.from({length:300*3},()=>Math.floor(random()*vertices.length)),geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.Float32BufferAttribute(new Float32Array(sources.length*3),3));geometry.setAttribute('normal',new T.Float32BufferAttribute(new Float32Array(sources.length*3).fill(7),3));compare(geometry,vertices,sources);}
});
test('empty, degenerate and signed-zero triangles retain Three normal and sphere results',()=>{
 for(const vertices of[[],[[0,0,0],[0,0,0],[0,0,0]],[[0,-0,0],[-0,0,-0],[1,-0,0]],[[0,0,0],[1,0,0],[0,1,0]]]){const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(new Float32Array(vertices.length*3),3));compare(g,vertices,vertices.map((_,i)=>i));}
});
test('indexed, normalized and interleaved skin positions retain the generic Three path',()=>{
 const vertices=[[0,0,0],[1,0,0],[0,1,0],[0,0,1]],indexed=new T.BufferGeometry();indexed.setAttribute('position',new T.Float32BufferAttribute(new Float32Array(12),3));indexed.setIndex([0,1,2,1,3,2]);compare(indexed,vertices,[0,1,2,3]);
 const normalized=new T.BufferGeometry();normalized.setAttribute('position',new T.BufferAttribute(new Int16Array(9),3,true));compare(normalized,vertices,[0,1,2]);
 const interleaved=new T.BufferGeometry();interleaved.setAttribute('position',new T.InterleavedBufferAttribute(new T.InterleavedBuffer(new Float32Array(12),4),3,0));compare(interleaved,vertices,[0,1,2]);
});
