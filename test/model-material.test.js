import assert from 'node:assert/strict';
import test from 'node:test';
import * as THREE from 'three';
import { parseBinaryMdl } from '../src/binary_mdl.js';
import { parseAsciiMdl } from '../src/model_parser.js';
import { modelMaterialOptions } from '../src/model_material.js';
import { ModelAnimator } from '../src/model_animation.js';
import fs from 'node:fs';

function binaryNode(flags,alpha) {
  const buffer = new ArrayBuffer(2048), view = new DataView(buffer), bytes = new Uint8Array(buffer);
  const u32 = (offset,value) => view.setUint32(offset,value,true);
  const f32 = (offset,value) => view.setFloat32(offset,value,true);
  u32(4,2036); u32(84,232); u32(88,1);
  bytes.set(new TextEncoder().encode('sample'),20);
  const node = 244;
  bytes.set(new TextEncoder().encode('sam'),node+32); u32(node+108,flags);
  u32(node+84,1300); u32(node+88,1); u32(node+96,1400); u32(node+100,2);
  u32(1312,128); view.setUint16(1316,1,true); view.setUint16(1320,1,true); bytes[1322]=1;
  f32(1412,0); f32(1416,alpha);
  return buffer;
}

test('base binary opacity reads mesh controller 128 without confusing emitter FPS', () => {
  for (const alpha of [0,0.25,1]) assert.equal(parseBinaryMdl(binaryNode(0x20,alpha)).nodes[0].alpha,alpha);
  assert.equal(parseBinaryMdl(binaryNode(0x4,10)).nodes[0].alpha,1);
});

test('ASCII base opacity hides zero-alpha helpers and preserves fractional and opaque material state', () => {
  const model = parseAsciiMdl('newmodel sample\nbeginmodelgeom sample\nnode trimesh sam\nalpha 0\nendnode\nendmodelgeom sample');
  const hidden = modelMaterialOptions(model.nodes[0]);
  assert.equal(hidden.opacity,0); assert.equal(hidden.visible,false); assert.equal(hidden.depthWrite,false);
  assert.equal(modelMaterialOptions({}).opacity,1);
  assert.equal(modelMaterialOptions({alpha:0.25}).transparent,true);
  assert.equal(modelMaterialOptions({properties:{transparencyhint:1}}).depthWrite,false);
});

test('MDL front-face material default follows the complete original GL render-state reset',()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-render-reset-observations.json',import.meta.url)));assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 assert.ok(native.calls.some(c=>c.name==='glEnable'&&c.args[0]===0xb44));assert.ok(native.calls.some(c=>c.name==='glFrontFace'&&c.args[0]===0x901));assert.equal(modelMaterialOptions({}).side,THREE.FrontSide);
 const a=new THREE.Vector3(1,0,0),b=new THREE.Vector3(0,0,-1),c=new THREE.Vector3(0,1,0);assert.equal(a.dot(b.clone().cross(c)),1);
});

test('a zero-alpha rest mesh can animate to opaque and restore when the next clip omits alpha', () => {
  const model = {modelName:'sample',nodes:[{name:'sam'}],animations:[
    {name:'reveal',length:0,tracks:[{node:'sam',property:'alpha',interpolation:'linear',frames:[{time:0,value:[1]}]}]},
    {name:'rest',length:0,tracks:[]}
  ]};
  const root = new THREE.Group(), node = new THREE.Group(); root.add(node);
  node.userData = {mdlNode:'sam',mdlModel:'sample'};
  const mesh = new THREE.Mesh(new THREE.BufferGeometry(),new THREE.MeshBasicMaterial(modelMaterialOptions({alpha:0})));
  node.add(mesh);
  const animator = new ModelAnimator(model,root);
  animator.pose('reveal');
  assert.equal(mesh.material.visible,true); assert.equal(mesh.material.opacity,1);
  assert.equal(mesh.material.transparent,false); assert.equal(mesh.material.depthWrite,true);
  animator.pose('rest');
  assert.equal(mesh.material.visible,false); assert.equal(mesh.material.opacity,0);
  assert.equal(mesh.material.transparent,true); assert.equal(mesh.material.depthWrite,false);
  mesh.geometry.dispose(); mesh.material.dispose();
});
