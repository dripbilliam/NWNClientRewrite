import assert from 'node:assert/strict';
import test from 'node:test';
import * as THREE from 'three';
import {createModelEmitter,ModelParticlePresentation} from '../src/model_particles.js';
import {ModelAnimator} from '../src/model_animation.js';
import {pointWindVector} from '../src/point_wind.js';
function fixture(overrides={}){
 const texture=new THREE.Texture(),node={name:'emitter',properties:{texture:'texture',update:'Fountain',render:'Normal',blend:'Lighten',birthrate:20,lifeexp:.2,sizestart:1,sizeend:1,colorstart:[1,.5,.25],colorend:[1,.5,.25],alphastart:.5,alphaend:.5,xgrid:1,ygrid:1,velocity:1,affectedbywind:'false',...overrides}},template=new THREE.Group();template.userData.mdlRoot='model';
 const group=new THREE.Group();template.add(group);group.add(createModelEmitter(node,new Map([['texture',texture]]),'model'));
 const root=new THREE.Group(),a=template.clone(true),b=template.clone(true);b.position.x=10;root.add(a,b);
 const records=[],presentation=new ModelParticlePresentation({camera:new THREE.PerspectiveCamera(),report:(...args)=>records.push(args)});
 return{root,a,b,template,records,presentation,group:group,texture};
}

test('stable emitter discovery avoids repeated hierarchy walks and follows new, reordered and removed instances',()=>{
 const {root,a,b,template,presentation}=fixture();presentation.update(root,.1);const traverse=root.traverse;let walks=0;
 root.traverse=function(...args){walks++;return traverse.apply(this,args);};presentation.update(root,.1);assert.equal(walks,0);
 const c=template.clone(true);root.add(c);presentation.update(root,.1);assert.equal(presentation.entries.size,3);assert.equal(walks,1);
 root.remove(a);root.add(a);presentation.update(root,.1);const ordered=[];traverse.call(root,n=>{if(n.userData.mdlEmitter)ordered.push(n);});assert.deepEqual(presentation.emitters,ordered);
 b.removeFromParent();presentation.update(root,.1);assert.equal(presentation.entries.size,2);assert.ok(presentation.emitters.every(mesh=>mesh.parent.parent!==b));
 walks=0;c.visible=false;presentation.update(root,.1);assert.equal(walks,0);assert.ok([...presentation.entries.values()].every(e=>!e.failed));presentation.dispose();
});

test('collision matrices refresh only for collision consumers, once per particle frame',()=>{
 for(const bounce of [0,1]){
  const {root,presentation}=fixture({bounce,lifeexp:2});presentation.update(root,.1);
  const original=presentation.collisionQuery.update;let refreshes=0;
  presentation.collisionQuery.update=()=>{refreshes++;original();};
  for(let frame=0;frame<3;frame++){
   const before=refreshes;presentation.update(root,.1);
   assert.equal(refreshes-before,bounce);
  }
  assert.ok([...presentation.entries.values()].every(e=>!e.failed));presentation.dispose();
 }
});
test('instantiated model emitters own independent native CPU state and GPU buffers and clean up removed models',()=>{
 const {root,a,b,template,presentation,records,texture}=fixture();presentation.update(root,.1);
 const [first,second]=[...presentation.entries.values()],templateMesh=template.children[0].children[0];
 assert.equal(first.failed,false);assert.equal(second.failed,false);assert.notEqual(first.e,second.e);assert.equal(first.e.active188.records.length,2);assert.equal(second.e.active188.records.length,2);
 assert.notEqual(first.mesh.geometry,second.mesh.geometry);assert.notEqual(first.mesh.material,second.mesh.material);assert.notEqual(first.mesh.material,templateMesh.material);assert.equal(first.mesh.material.uniforms.particleMap.value,texture);
 assert.equal(first.mesh.visible,true);assert.equal(templateMesh.visible,false);assert.equal(first.drawCount,12);assert.equal(first.mesh.geometry.drawRange.count,12);
 assert.deepEqual([...first.mesh.geometry.getAttribute('particleColor').array.slice(0,4)],[255,127,63,127]);
 assert.equal(second.e.active188.records[0].position10[0]-first.e.active188.records[0].position10[0],10);
 // Scoped animated parameters belong to the node instance, not its template
 // or sibling. Existing particles keep moving when birth rate becomes zero.
 a.children[0].userData.mdlEmitterProperties={...templateMesh.userData.mdlEmitter.properties,birthrate:0};
 presentation.update(root,.1);assert.equal(first.e.active188.records.length,2);assert.equal(second.e.active188.records.length,4);
 presentation.update(root,.1);presentation.update(root,.1);assert.equal(first.e.active188.records.length,0);assert.equal(first.e.free130.records.length,2);assert.equal(first.mesh.visible,false);
 assert.ok(second.e.active188.records.length>0);assert.equal(records.filter(r=>r[0]==='particle.runtime-unavailable').length,0);
 let geometryDisposed=0,materialDisposed=0;second.mesh.geometry.addEventListener('dispose',()=>geometryDisposed++);second.mesh.material.addEventListener('dispose',()=>materialDisposed++);
 b.removeFromParent();presentation.update(root,.1);assert.equal(presentation.entries.size,1);assert.equal(geometryDisposed,1);assert.equal(materialDisposed,1);
 presentation.dispose();assert.equal(presentation.entries.size,0);assert.equal(templateMesh.material.uniforms.particleMap.value,texture);
});

test('particle uploads retain packed native position/UV/color values and update only active vertices',()=>{
 const {root,presentation}=fixture();presentation.update(root,.1);const entry=[...presentation.entries.values()][0],buffer=new ArrayBuffer(24*2),view=new DataView(buffer);
 for(let i=0;i<2;i++){const off=i*24;view.setUint32(off,0x1234abcd+i,true);for(let c=0;c<5;c++)view.setFloat32(off+4+c*4,Math.fround((i+1)*.25+c),true);}
 presentation.upload(entry,{count:2,buffer});const geometry=entry.mesh.geometry;
 assert.deepEqual([...geometry.attributes.position.array.slice(0,6)],[.25,2.25,-1.25,.5,2.5,-1.5]);assert.deepEqual([...geometry.attributes.uv.array.slice(0,4)],[3.25,4.25,3.5,4.5]);assert.deepEqual([...geometry.attributes.particleColor.array.slice(0,8)],[205,171,52,18,206,171,52,18]);
 for(const attribute of Object.values(geometry.attributes))assert.deepEqual(attribute.updateRanges,[{start:0,count:2*attribute.itemSize}]);assert.equal(geometry.drawRange.count,2);presentation.dispose();
});
test('selected missing model particle services are recorded once and unavailable emitters remain hidden',()=>{
 for(const overrides of [{p2p:1},{chunkname:'chunk'},{blend:'Punch-Through'},{affectedbywind:'true'},{tinted:1},{detonate:1}]){
  const {root,presentation,records}=fixture(overrides);presentation.update(root,.1);presentation.update(root,.1);presentation.update(root,.1);
  assert.equal(records.filter(r=>r[0]==='particle.runtime-unavailable').length,1,JSON.stringify(overrides));
  assert.ok([...presentation.entries.values()].every(e=>e.failed&&!e.mesh.visible));presentation.dispose();
 }
});

test('bounce emitters keep simulating with static-scene collision and retain the dynamic-scene limitation diagnostic',()=>{
 const {root,presentation,records}=fixture({bounce:1,bounce_co:.5,lifeexp:2});
 for(let i=0;i<5;i++)presentation.update(root,.05);
 assert.ok([...presentation.entries.values()].every(e=>!e.failed&&e.frames===5&&e.drawCount>0));
 assert.equal(records.filter(r=>r[0]==='particle.runtime-unavailable').length,0);
 assert.equal(records.filter(r=>r[0]==='particle.scene-collision-partial').length,1);presentation.dispose();
});
test('Lightning without a direct reference has no endpoint, drains without decorative particles and keeps canonical state absent',()=>{
 const {root,presentation,records}=fixture({update:'Lightning',render:'Linked',birthrate:3,lifeexp:0});presentation.update(root,.05);presentation.update(root,.05);
 for(const entry of presentation.entries.values()){assert.equal(entry.failed,false);assert.equal(entry.e.target1c0,null);assert.equal(entry.e.targetListener128.active,false);assert.equal(entry.e.ageMode1cc,0);assert.equal(entry.e.active188.records.length,0);assert.equal(entry.drawCount,0);}
 assert.equal(records.filter(r=>r[0]==='particle.runtime-unavailable').length,0);presentation.dispose();
});
test('camera-facing particle vertices face the actual Three camera across camera rotations',()=>{
 for(const rotation of [[0,0,0],[.3,.7,-.2],[-.7,-.2,.4]]){
  const {root,presentation}=fixture();presentation.camera.rotation.set(...rotation);presentation.update(root,.1);
  const entry=[...presentation.entries.values()][0],positions=entry.mesh.geometry.getAttribute('position'),vertices=[0,1,2].map(i=>new THREE.Vector3().fromBufferAttribute(positions,i)),normal=new THREE.Vector3().crossVectors(vertices[1].clone().sub(vertices[0]),vertices[2].clone().sub(vertices[0])).normalize(),towardCamera=presentation.camera.getWorldDirection(new THREE.Vector3()).negate();
  assert.ok(normal.dot(towardCamera)>.99999,JSON.stringify(rotation));assert.equal(entry.mesh.raycast(),undefined);presentation.dispose();
 }
});

test('particle world-pose caching is frame-local and preserves source scale and changing parent transforms',()=>{
 const {root,a,presentation}=fixture();let calls=0;const before=a.updateWorldMatrix;a.updateWorldMatrix=function(...args){calls++;return before.apply(this,args);};
 for(let frame=0;frame<4;frame++){a.position.set(frame,frame*.2,-frame);a.scale.set(frame%2?-2:1,1.5,.75);a.rotation.y=frame*.4;presentation.update(root,.05);const entry=[...presentation.entries.values()].find(e=>e.root===a),position=a.getWorldPosition(new THREE.Vector3()),scale=a.getWorldScale(new THREE.Vector3());assert.deepEqual(entry.e.source50.position,[position.x,-position.z,position.y].map(Math.fround));assert.equal(entry.e.source50.adjustedScale,Math.fround(scale.x));const count=calls;presentation.worldPose(a);presentation.worldPose(a);assert.equal(calls,count,'repeated pose reads did not update ancestors');}
 presentation.dispose();
});
test('authored model Detonate events activate only their own Explosion instance and are consumed as a BYTE command',()=>{
 const {root,a,b,presentation}=fixture({update:'Explosion',birthrate:3});
 const model={modelName:'model',nodes:[],animations:[{name:'burst',length:1,tracks:[],events:[{time:Math.fround(.0666667),name:'dEtOnAtE'}]}]},animator=new ModelAnimator(model,a);
 animator.play('burst',{loop:false});presentation.update(root,.05);
 const [first,second]=[...presentation.entries.values()];assert.equal(first.e.active188.records.length,0);assert.equal(second.e.active188.records.length,0);
 animator.update(.1);assert.equal(a.children[0].children[0].userData.mdlPendingDetonate,1);assert.equal(b.children[0].children[0].userData.mdlPendingDetonate,undefined);
 presentation.update(root,.05);assert.equal(first.e.active188.records.length,3);assert.equal(second.e.active188.records.length,0);assert.equal(first.e.detonate108,0);assert.equal(first.e.blastLatch1c8,1);
 animator.update(.1);presentation.update(root,.05);assert.equal(first.e.active188.records.length,3);assert.equal(first.e.blastLatch1c8,0);
 animator.play('burst',{loop:false});animator.update(.1);presentation.update(root,.05);assert.equal(first.e.active188.records.length,6);assert.equal(second.e.active188.records.length,0);presentation.dispose();
});

test('untextured zero-lifetime emitters simulate detonation and retain point wind without requesting a draw bitmap',()=>{
 const {root,a,presentation,records}=fixture({texture:'NULL',update:'Explosion',birthrate:1,lifeexp:0,blastradius:8,blastlength:1.2});
 presentation.update(root,.05);a.children[0].children[0].userData.mdlPendingDetonate=1;presentation.update(root,.05);
 const first=[...presentation.entries.values()][0],winds=presentation.pointWinds;
 assert.equal(first.failed,false);assert.equal(first.e.active188.records.length,1);assert.equal(first.drawCount,0);assert.equal(first.mesh.visible,false);
 assert.equal(winds.records.length,1);assert.deepEqual(winds.records[0],{position:[0,-0,0],radius:8,duration:Math.fround(1.2),remaining:Math.fround(1.2),strength:1});assert.deepEqual(pointWindVector(winds,[0,0,0]),[1,0,0]);
 assert.deepEqual(records.filter(r=>r[0]==='particle.runtime-unavailable'),[]);assert.equal(records.filter(r=>r[0]==='particle.wind-scene-unimplemented').length,1);
 presentation.update(root,Math.fround(1.2));assert.equal(winds.records.length,1);assert.equal(winds.records[0].remaining,0);presentation.update(root,.001);assert.equal(winds.records.length,0);assert.equal(winds.capacity,16);
 presentation.dispose();assert.equal(presentation.pointWinds.capacity,0);
});

test('NULL textures still fail if particle drawing is selected, and missing named bitmaps remain diagnosed',()=>{
 for(const overrides of [{texture:'NULL'},{texture:'absent',lifeexp:0}]){
  const {root,presentation,records}=fixture(overrides);presentation.update(root,.1);presentation.update(root,.1);
  assert.equal(records.filter(r=>r[0]==='particle.runtime-unavailable').length,1);assert.match(records.find(r=>r[0]==='particle.runtime-unavailable')[1],/bitmap/);assert.ok([...presentation.entries.values()].every(e=>e.failed&&!e.mesh.visible));presentation.dispose();
 }
});

test('scene replacement clears point wind ownership even when a previous burst still has time left',()=>{
 const {root,a,presentation}=fixture({texture:'NULL',update:'Explosion',birthrate:1,lifeexp:0,blastradius:8,blastlength:5});
 presentation.update(root,.1);a.children[0].children[0].userData.mdlPendingDetonate=1;presentation.update(root,.1);assert.equal(presentation.pointWinds.records.length,1);
 presentation.update(new THREE.Group(),.1);assert.equal(presentation.pointWinds.records.length,0);assert.equal(presentation.entries.size,0);presentation.dispose();
});
