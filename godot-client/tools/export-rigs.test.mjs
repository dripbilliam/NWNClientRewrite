import {test} from 'node:test';
import assert from 'node:assert/strict';
import * as T from 'three';
import {prepareRigTransfer,transferTrack} from './export-rigs.mjs';
import {createRigFixture,rigFixtureOracle} from './rig-fixture.mjs';

test('sparse model transfer retains external animated endpoint bindings without re-exporting their skins',()=>{
 const a=createRigFixture(),b=createRigFixture(),first=a.presentation.objects.get(1),second=b.presentation.objects.get(1),object=a.presentation.world.registry.get(1);
 const presentation={...a.presentation,objects:new Map([[1,first],[2,second]]),world:{registry:{get:id=>[1,2].includes(id)?{...object,id}:null}}};
 const complete=prepareRigTransfer(presentation),endpoint=b.rigid.parent;
 Object.defineProperty(b.skinNode,'skinData',{configurable:true,get(){throw Error('External skin was recalculated');}});
 const sparse=prepareRigTransfer(presentation,new Set([1]));
 assert.deepEqual(sparse.data.entities.map(row=>row.id),[1]);assert.equal(sparse.data.counts.entities,1);assert.equal(sparse.binding(b.skinMesh),null);
 assert.deepEqual(sparse.nodeBinding(endpoint),complete.nodeBinding(endpoint));assert.equal(sparse.nodeBinding(endpoint).objectId,2);
 assert.deepEqual(sparse.nodeBinding(b.heldMesh.parent),complete.nodeBinding(b.heldMesh.parent));
});

test('rig transfer retains physical hierarchy, ordinary clips and mesh ownership without changing source poses',()=>{
 const f=createRigFixture();f.animator.apply(f.model.animations[0],.37);f.wrapper.updateMatrixWorld(true);const before=f.rigid.matrixWorld.toArray(),beforeSkin=Array.from(f.skinMesh.geometry.attributes.position.array),r=prepareRigTransfer(f.presentation);
 assert.equal(r.data.entities.length,1);assert.equal(r.data.counts.animatedModels,1);assert.equal(r.data.assets[0].clips.length,3);assert.equal(r.data.assets[0].clips[0].events[0].name,'authored_event');assert.equal(r.binding(f.skinMesh).skin.part,2);assert.deepEqual(f.rigid.matrixWorld.toArray(),before);assert.deepEqual(Array.from(f.skinMesh.geometry.attributes.position.array),beforeSkin);
 const entity=r.data.entities[0],parts=entity.models[0].parts;assert.equal(entity.nodes[parts[1]].parent,parts[0]);assert.equal(r.binding(f.rigid).rigNode,parts[1]);
});
test('skin export preserves sparse native slots, nonunit totals and zero-weight vertices',()=>{
 const f=createRigFixture(),r=prepareRigTransfer(f.presentation),s=r.binding(f.skinMesh).skin;
 assert.deepEqual(s.slots.slice(0,4),[1,0,0,-1]);assert.deepEqual(s.weights.slice(0,4),[.5,.2,0,0]);assert.deepEqual(s.weights.slice(8,12),[0,0,0,0]);assert.deepEqual(s.position,[0,0,-0,1,0,-0,0,1,-0]);assert.deepEqual(s.uv,[0,0,1,0,0,1]);
});
test('track conversion retains quaternion basis and original key boundaries',()=>{
 const f=createRigFixture(),track=f.model.animations[0].tracks[1],converted=transferTrack(track),q=new T.Quaternion(...converted.keys[1].value),v=new T.Vector3(1,0,0).applyQuaternion(q);
 assert.ok(v.distanceTo(new T.Vector3(0,0,-1))<1e-6);assert.deepEqual(converted.keys.map(k=>k.time),[0,1]);
});
test('Bezier transfer preserves authored knots and basis-converted relative handles without resampling',()=>{
 const track={property:'position',interpolation:'bezier',frames:[{time:0,value:[0,0,0],out:[.3,.2,0],in:[0,0,0]},{time:.43,value:[1,1,0],in:[-.2,0,0],out:[0,0,0]},{time:1,value:[2,0,0],in:[-.3,.1,0],out:[0,0,0]}]},converted=transferTrack(track);
 assert.deepEqual(converted.keys.map(k=>k.time),[0,.43,1]);assert.deepEqual(converted.keys[0].out,[.3,0,-.2]);assert.deepEqual(converted.keys[1].in,[-.2,0,-0]);assert.equal(converted.sourceInterpolation,'bezier');
});
test('authored oracle exposes actual moving skin and attached rigid geometry',()=>{
 const oracle=rigFixtureOracle();assert.equal(oracle.metadata.rigs.counts.skinMeshes,1);assert.equal(oracle.meshes.length,3);assert.notDeepEqual(oracle.samples[0].skin,oracle.samples[2].skin);assert.notDeepEqual(oracle.samples[0].rigidMatrix,oracle.samples[2].rigidMatrix);assert.deepEqual(oracle.samples[0].skin.slice(6),oracle.samples[2].skin.slice(6));
});
test('held models outside the body subtree preserve anchor P/Q and their independent scale',()=>{
 const f=createRigFixture(),r=prepareRigTransfer(f.presentation),entity=r.data.entities[0],attachment=entity.attachments[0];assert.equal(r.data.counts.attachments,1);assert.ok(r.binding(f.heldMesh));assert.equal(entity.nodes[attachment.node].parent,-1);assert.deepEqual(attachment.scale,[2,2,2]);assert.equal(entity.nodes[attachment.anchor].scale[0],3);
});
test('only source body/follower animators receive replicated locomotion and source loop categories survive',()=>{
 const f=createRigFixture(),r=prepareRigTransfer(f.presentation),entity=r.data.entities[0];assert.equal(entity.models[0].follow,true);assert.equal(entity.models[1].follow,false);assert.equal(entity.clipMap[4],'crun');assert.equal(entity.loopMap[4],true);assert.equal(entity.loopMap[5],false);
});
test('sharing original clip assets does not share character-specific rest overrides',()=>{
 const a=createRigFixture(),b=createRigFixture(),first=a.presentation.objects.get(1),second=b.presentation.objects.get(1),objectA=a.presentation.world.registry.get(1),objectB={...b.presentation.world.registry.get(1),id:2};
 second.models[0].model=a.model;second.models[0].animator.model=a.model;second.models[0].animator.bindings.get('hand').position.set(9,0,0);
 const r=prepareRigTransfer({objects:new Map([[1,first],[2,second]]),world:{registry:{get:id=>id===1?objectA:objectB}},tables:{}}),one=r.data.entities[0].models[0],two=r.data.entities[1].models[0];
 assert.equal(one.asset,two.asset);assert.equal(one.defaults[1].position[0],1);assert.equal(two.defaults[1].position[0],9);
});
