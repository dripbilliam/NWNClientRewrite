import test from 'node:test';
import assert from 'node:assert/strict';
import * as T from 'three';
import {NativeParticleSimulation} from './particle-simulation.mjs';
import {NativeParticleWorkers} from './particle-workers.mjs';
import {MAX_PARTICLE_VERTICES, packParticleBuffers} from './particle-buffers.mjs';
import {ModelParticlePresentation, createModelEmitter} from '../../src/model_particles.js';

export const layout = {vertexStride:12, attributeStride:12, colorOffset:0, uvOffset:4};
export const identity = new T.Matrix4().toArray();
export function descriptor(id = 1, extra = {}) {
 return {id, node:'authored', model:'authored', matrix:identity, rootMatrix:identity, textureAvailable:true,
  properties:{texture:'authored', update:'Fountain', render:'Normal', blend:'Lighten', birthrate:20, lifeexp:.3,
   sizestart:1, sizeend:.2, sizestart_y:1, sizeend_y:.5, colorstart:[1,.5,.25], colorend:[.1,.2,.3],
   alphastart:.8, alphaend:.1, xgrid:2, ygrid:2, framestart:0, frameend:3, fps:10, velocity:1,
   spread:.25, randvel:.1, affectedbywind:'false', ...extra}};
}
function sourceFixture(row, seed = 3, collision = []) {
 const scene = new T.Scene(), root = new T.Group(), parent = new T.Group(), camera = new T.PerspectiveCamera();
 const texture = new T.Texture(), mesh = createModelEmitter({name:row.node, properties:row.properties}, new Map([['authored',texture]]), row.model);
 scene.add(root); root.add(parent); parent.add(mesh); root.userData.mdlRoot = true;
 root.matrixAutoUpdate = parent.matrixAutoUpdate = camera.matrixAutoUpdate = false;
 const diagnostics = [], presentation = new ModelParticlePresentation({camera, seed, report:(code,message,data) => diagnostics.push({code,message,data})});
 for (const row of collision) {
  const tile = new T.Group(); tile.userData.nativeStaticTile = true; tile.matrixAutoUpdate = false; tile.matrix.fromArray(row.matrix);
  const geometry = new T.BufferGeometry(); geometry.userData.nativeCameraHitFaces = row.faces;
  const part = new T.Mesh(geometry); part.userData.nativeModelMesh = true; tile.add(part); scene.add(tile);
 }
 return {scene, root, parent, camera, mesh, presentation, diagnostics, frame(frame) {
  const pose = frame.poses[0]; root.matrix.fromArray(pose.rootMatrix);
  parent.matrix.copy(root.matrix).invert().multiply(new T.Matrix4().fromArray(pose.matrix)); parent.matrix.decompose(parent.position,parent.quaternion,parent.scale);
  parent.userData.mdlEmitterProperties = {...row.properties, ...pose.properties}; if(pose.detonate) mesh.userData.mdlPendingDetonate = true;
  camera.matrix.fromArray(frame.camera); presentation.update(scene, frame.delta);
  const entry = presentation.entries.get(mesh); return {entry, state:presentation.snapshot(), diagnostics};
 }, close() {presentation.dispose(); texture.dispose();}};
}
function assertStreams(row, source) {
 assert.equal(row.count, source.entry.drawCount);
 const positions = new Float32Array(row.positions), uv = source.entry.mesh.geometry.attributes.uv?.array, colors = source.entry.mesh.geometry.attributes.particleColor?.array;
 const attributes = new DataView(row.attributes);
 assert.deepEqual(Array.from(positions.slice(0,row.count*3)), Array.from(source.entry.mesh.geometry.attributes.position?.array.slice(0,row.count*3) ?? []));
 for(let i=0; i<row.count; i++) {
  assert.equal(attributes.getFloat32(i*12+4,true),uv[i*2]); assert.equal(attributes.getFloat32(i*12+8,true),uv[i*2+1]);
  for(let c=0;c<4;c++) assert.equal(attributes.getUint8(i*12+c), colors[i*4+c]);
 }
 assert.ok(new Uint8Array(row.positions).subarray(row.count*12).every(v=>v===0));
 assert.ok(new Uint8Array(row.attributes).subarray(row.count*12).every(v=>v===0));
}

test('worker adapter matches retained scene adapter for all seven render modes, moving roots, cameras, atlas/life clocks and sampled properties', () => {
 for(const render of ['Normal','Billboard_to_Local_Z','Billboard_to_World_Z','Linked','Aligned_to_World_Z','Aligned_to_Particle_Dir','Motion_Blur']) {
  const row = descriptor(1,{render, blurlength:.2}), native = new NativeParticleSimulation({layout, seed:3}), source=sourceFixture(row);
  native.reset({epoch:1,emitters:[row]});
  try {for(let i=0;i<18;i++) {
   const root = new T.Matrix4().compose(new T.Vector3(i*.05,1,0),new T.Quaternion().setFromAxisAngle(new T.Vector3(0,1,0),i*.1),new T.Vector3(1.2,1.2,1.2));
   const parent = root.clone().multiply(new T.Matrix4().makeTranslation(.2,.1,-.1));
   const camera = new T.Matrix4().compose(new T.Vector3(0,3,6), new T.Quaternion().setFromEuler(new T.Euler(i*.01,i*.03,0)), new T.Vector3(1,1,1));
   const frame = {epoch:1,sequence:i,delta:.05,camera:camera.toArray(),poses:[{id:1,rootMatrix:root.toArray(),matrix:parent.toArray(),properties:{birthrate:i>10?0:20}}]};
   const actual=native.frame(frame), expected=source.frame(frame); assert.equal(actual.diagnostics.filter(r=>r.code==='particle.runtime-unavailable').length,0,render);
   assert.deepEqual(actual.state,expected.state); assertStreams(actual.emitters[0], expected);
  }} finally {native.close(); source.close();}
 }
});

test('Explosion detonation, Single particles and no-endpoint Lightning preserve original owners rather than decorative stand-ins', () => {
 for(const update of ['Explosion','Single','Lightning']) {
  const row=descriptor(1,{update,render:update==='Lightning'?'Linked':'Normal',birthrate:3,lifeexp:1}), native=new NativeParticleSimulation({layout,seed:3}), source=sourceFixture(row);
  native.reset({epoch:1,emitters:[row]});
  try {for(let i=0;i<8;i++) {const frame={epoch:1,sequence:i,delta:.05,camera:identity,poses:[{id:1,rootMatrix:identity,matrix:identity,detonate:i===1||i===5}]}, actual=native.frame(frame), expected=source.frame(frame); assert.deepEqual(actual.state,expected.state); assertStreams(actual.emitters[0],expected);}}
  finally {native.close();source.close();}
 }
});

test('static original collision faces are reused by the worker bounce owner', () => {
 const collision=[{matrix:identity,faces:[{vertices:[[-20,-20,0],[20,-20,0],[20,20,0],[-20,20,0]],normal:[0,0,1],constant:0}]}];
 const row=descriptor(1,{bounce:1,bounce_co:.7,velocity:-1,mass:.8,lifeexp:2}), native=new NativeParticleSimulation({layout,seed:3}), source=sourceFixture(row,3,collision);
 native.reset({epoch:1,emitters:[row],collision});
 try {for(let i=0;i<20;i++) {const transform=new T.Matrix4().makeTranslation(0,.2,0).toArray(), frame={epoch:1,sequence:i,delta:.05,camera:identity,poses:[{id:1,matrix:transform,rootMatrix:transform}]}; const actual=native.frame(frame), expected=source.frame(frame);assertStreams(actual.emitters[0],expected);assert.deepEqual(actual.state,expected.state);}}
 finally {native.close();source.close();}
});

test('missing original services remain explicit failures; direct reference endpoints cannot silently disappear', () => {
 for(const extra of [{p2p:1},{chunkname:'chunk'},{blend:'Punch-Through'},{affectedbywind:'true'},{tinted:1},{detonate:1},{texture:'NULL'}]) {
  const native=new NativeParticleSimulation({layout}); native.reset({epoch:1,emitters:[{...descriptor(1,extra),textureAvailable:extra.texture!=='NULL'}]});
  try {native.frame({epoch:1,sequence:0,delta:.1,camera:identity});const second=native.frame({epoch:1,sequence:1,delta:.1,camera:identity});assert.ok(second.state[0].failed);assert.equal(second.emitters[0].count,0);}
  finally {native.close();}
 }
 const native=new NativeParticleSimulation({layout});assert.throws(()=>native.reset({epoch:1,emitters:[{...descriptor(),referenceTarget:{id:2}}]}),/pose matrix/);native.close();
});

test('NULL-textured helper simulation remains valid until drawing is requested; runtime failure clears the old live quads', () => {
 const helper=new NativeParticleSimulation({layout}); helper.reset({epoch:1,emitters:[{...descriptor(1,{texture:'NULL',update:'Explosion',lifeexp:0,blastradius:2,blastlength:1}),textureAvailable:false}]});
 try {const result=helper.frame({epoch:1,sequence:0,delta:.1,camera:identity,poses:[{id:1,matrix:identity,rootMatrix:identity,detonate:true}]});assert.equal(result.emitters[0].count,0);assert.equal(result.state[0].failed,false);assert.equal(result.state[0].active,20);}finally{helper.close();}
 const native=new NativeParticleSimulation({layout}); native.reset({epoch:1,emitters:[descriptor()]});
 try {
  const first=native.frame({epoch:1,sequence:0,delta:.1,camera:identity});assert.ok(first.emitters[0].count>0);
  const failed=native.frame({epoch:1,sequence:1,delta:.1,camera:identity,poses:[{id:1,matrix:identity,rootMatrix:identity,properties:{detonate:1}}]});
  assert.equal(failed.state[0].failed,true);assert.equal(failed.emitters[0].count,0);assert.equal(failed.emitters[0].capacity,first.emitters[0].capacity);assert.ok(new Uint8Array(failed.emitters[0].attributes).every(byte=>byte===0));
 }finally{native.close();}
});

test('packed streams preserve coordinate basis and bytes, clear retired vertices and reject invalid sizes/layouts', () => {
 const buffer=new ArrayBuffer(144), view=new DataView(buffer);
 for(let i=0;i<6;i++) {view.setUint32(i*24,0x80402010,true);for(let c=0;c<5;c++)view.setFloat32(i*24+4+c*4,i+c+.25,true);}
 const result=packParticleBuffers({count:6,buffer},layout,192);
 assert.deepEqual([...new Float32Array(result.positions).slice(0,3)],[.25,2.25,-1.25]);
 assert.deepEqual([...new Uint8Array(result.attributes).slice(0,4)],[16,32,64,128]);
 assert.ok(new Uint8Array(result.positions).subarray(72).every(v=>v===0));
 assert.ok(new Uint8Array(packParticleBuffers(null,layout,192).attributes).every(v=>v===0));
 assert.throws(()=>packParticleBuffers({count:MAX_PARTICLE_VERTICES+6,buffer},layout),/count/);
 assert.throws(()=>packParticleBuffers({count:6,buffer:new ArrayBuffer(1)},layout),/stream/);
 assert.throws(()=>packParticleBuffers(null,{...layout,attributeStride:8}),/layout/);
 view.setFloat32(4,NaN,true);assert.throws(()=>packParticleBuffers({count:6,buffer},layout),/Nonfinite/);
});

test('real worker threads retain state and return byte-identical streams with bounded busy admission', async () => {
 const rows=[descriptor(1),descriptor(2)], workers=new NativeParticleWorkers({count:2,layout,seed:3}), references=[3,4].map(seed=>new NativeParticleSimulation({layout,seed}));
 try {
  await workers.reset({epoch:1,emitters:rows}); references.forEach((ref,i)=>ref.reset({epoch:1,emitters:[rows[i]]}));
  for(let i=0;i<12;i++) {
   const frame={epoch:1,sequence:i,delta:.05,camera:identity}, pending=workers.frame(frame);
   assert.equal((await workers.frame({...frame,sequence:1000})).busy,true);
   const actual=await pending, expected=references.flatMap(ref=>ref.frame(frame).emitters);
   assert.deepEqual(actual.emitters,expected);assert.equal(workers.pending.size,0);
  }
  const inFlight=workers.frame({epoch:1,sequence:12,delta:.05,camera:identity}), reset=workers.reset({epoch:2,emitters:[descriptor(3)]});
  assert.equal((await inFlight).stale,true);await reset;
  assert.equal((await workers.frame({epoch:1,sequence:100,delta:.05,camera:identity})).stale,true);
  const current=await workers.frame({epoch:2,sequence:0,delta:.05,camera:identity});assert.deepEqual(current.emitters.map(r=>r.id),[3]);
  await assert.rejects(workers.frame({epoch:2,sequence:1,delta:.05,camera:identity,poses:[{id:1}]}),/Unknown/);
 } finally {await workers.close();references.forEach(ref=>ref.close());}
 assert.equal(workers.pending.size,0);await assert.rejects(workers.frame({}),/closed/);
});

test('worker errors and close reject outstanding jobs instead of leaving a dead frame promise', async () => {
 const workers=new NativeParticleWorkers({count:1,layout});
 await workers.reset({epoch:1,emitters:[descriptor()]});
 await assert.rejects(workers.frame({epoch:1,sequence:0,delta:-1,camera:identity}),/Invalid particle simulation frame/);
 const pending=workers.frame({epoch:1,sequence:1,delta:.05,camera:identity}); const rejected=assert.rejects(pending,/closed/);
 await workers.close(); await rejected;assert.equal(workers.pending.size,0);
});
