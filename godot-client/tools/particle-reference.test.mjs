import test from 'node:test';import assert from 'node:assert/strict';import * as T from 'three';
import {createReferenceFixture} from './reference-fixture.mjs';import {NativeParticleSimulation} from './particle-simulation.mjs';import {NativeParticleWorkers} from './particle-workers.mjs';
const layout={vertexStride:12,attributeStride:12,colorOffset:0,uvOffset:4};
function compare(output,entry){
 assert.equal(output.count,entry.drawCount);const positions=new Float32Array(output.positions),uv=entry.mesh.geometry.attributes.uv.array,color=entry.mesh.geometry.attributes.particleColor.array,attributes=new DataView(output.attributes);
 let error=0;for(let i=0;i<output.count*3;i++)error=Math.max(error,Math.abs(positions[i]-entry.mesh.geometry.attributes.position.array[i]));assert.ok(error<.00002,'Reference-linked source positions differ by '+error);
 for(let i=0;i<output.count;i++){assert.equal(attributes.getFloat32(i*12+4,true),uv[i*2]);assert.equal(attributes.getFloat32(i*12+8,true),uv[i*2+1]);for(let c=0;c<4;c++)assert.equal(attributes.getUint8(i*12+c),color[i*4+c]);}
}
test('export preserves first DIRECT reference identity, actual attachment anchor and model revision instead of nearest/nested endpoints',()=>{
 const fixture=createReferenceFixture();try{const descriptor=fixture.capture();assert.deepEqual(descriptor.referenceTarget.matrix,fixture.first.root.matrixWorld.toArray());assert.notDeepEqual(descriptor.referenceTarget.matrix,fixture.second.root.matrixWorld.toArray());assert.notDeepEqual(descriptor.referenceTarget.matrix,fixture.nested.root.matrixWorld.toArray());assert.deepEqual(descriptor.referenceTarget.attachment.binding,{objectId:2,rigNode:1,modelIndex:0,revision:20});assert.equal(descriptor.nativeParent.revision,10);assert.equal(descriptor.referenceTarget.attachment.flags,0);
 const view=fixture.source.references.poses.attachmentFor(fixture.first);view.flags=3;assert.equal(fixture.source.references.poses.attachmentFor(fixture.first).flags,0);}finally{fixture.close();}
});
test('real reference-linked worker simulation agrees with the original full reference scene through movement, node animation, scale and cached lightning phases',()=>{
 for(const flags of [0,3])for(const render of ['Linked','Normal','Motion_Blur']){
  const fixture=createReferenceFixture({flags,render}),native=new NativeParticleSimulation({layout,seed:17});
  try{const initial=fixture.update(0);native.reset({epoch:1,emitters:[initial.descriptor]});
   for(let index=0;index<30;index++){const expected=index===0?initial:fixture.update(index),actual=native.frame(expected.frame);assert.equal(actual.state[0].failed,false,render);assert.ok(actual.emitters[0].count>0);compare(actual.emitters[0],expected.entry);assert.equal(native.simulation.random.draws,fixture.particles.random.draws);const state=native.simulation.entries.get(native.nodes.get(initial.descriptor.id).mesh).e;assert.equal(state.targetListener128.active,true);assert.ok(state.target1c0);}
  }finally{native.close();fixture.close();}
 }
});
test('endpoint destruction drains the chain and cannot bind a recycled model ID; new emitter ownership can create a fresh link',async()=>{
 const fixture=createReferenceFixture(),workers=new NativeParticleWorkers({count:1,layout,seed:17});
 try{const source=fixture.update(0);await workers.reset({epoch:1,emitters:[source.descriptor]});const first=await workers.frame(source.frame);assert.ok(first.emitters[0].count>0);
 const pose=source.frame.poses[0],retired=await workers.frame({...source.frame,sequence:1,poses:[{...pose,referenceMatrix:null}]});assert.equal(retired.emitters[0].count,0);assert.ok(retired.diagnostics.some(row=>row.code==='particle.endpoint-retired'));
 const recycled=await workers.frame({...source.frame,sequence:2});assert.equal(recycled.emitters[0].count,0);
 const next={...source.descriptor,id:source.descriptor.id+10000};await workers.patch({epoch:1,remove:[source.descriptor.id],add:[next]});const fresh=await workers.frame({...source.frame,sequence:3,poses:[{...pose,id:next.id}]});assert.ok(fresh.emitters[0].count>0);
 }finally{await workers.close();fixture.close();}
});
test('reference endpoint coordinate validation rejects malformed data before advancing the original simulation',()=>{
 const fixture=createReferenceFixture(),native=new NativeParticleSimulation({layout});try{const source=fixture.update(0);native.reset({epoch:1,emitters:[source.descriptor]});assert.throws(()=>native.frame({...source.frame,poses:[{...source.frame.poses[0],referenceMatrix:[NaN]}]}),/pose matrix/);assert.equal(native.sequence,-1);}finally{native.close();fixture.close();}
});
