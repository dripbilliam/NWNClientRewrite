import test from 'node:test';import assert from 'node:assert/strict';import * as T from 'three';
import {prepareGodotRoom,sourceObjectId,describeGodotEntities} from './export-room.mjs';
function fixture(){const scene=new T.Scene(),camera=new T.PerspectiveCamera(),geometry=new T.BoxGeometry(),map=new T.DataTexture(new Uint8Array([255,255,255,255]),1,1),material=new T.MeshLambertMaterial({map}),mesh=new T.Mesh(geometry,material);scene.add(mesh);return{scene,camera,geometry,map,material,mesh,inventory:[{id:1,resources:['authored_fixture']}],buffer:[1424,921]};}
test('frozen bridge retains membership and world poses and never mutates manual texture transforms',()=>{
 const f=fixture();f.map.matrixAutoUpdate=false;f.map.matrix.makeTranslation(.2,.3);const before=f.map.matrix.toArray();f.mesh.position.set(2,3,4);const hidden=f.mesh.clone();hidden.visible=false;f.scene.add(hidden);
 const prepared=prepareGodotRoom(f);assert.equal(prepared.manifest.counts.meshes,1);assert.deepEqual(prepared.manifest.inventory,f.inventory);assert.deepEqual(prepared.scene.children[0].matrix.elements.slice(12,15),[2,3,4]);assert.deepEqual(f.map.matrix.toArray(),before);assert.deepEqual(prepared.scene.children[0].material.map.matrix.toArray(),before);assert.equal(prepared.manifest.accepted,false);assert.ok(prepared.manifest.gaps.length);prepared.dispose();
});
test('particle positions are already world-space and their RGBA tint survives transfer',()=>{
 const f=fixture(),geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.Float32BufferAttribute([1,2,3,2,2,3,1,3,3],3));geometry.setAttribute('particleColor',new T.Uint8BufferAttribute(new Uint8Array(12).fill(255),4,true));geometry.setDrawRange(0,3);f.mesh.geometry=geometry;f.mesh.material=new T.ShaderMaterial({uniforms:{particleMap:{value:f.map}},transparent:true});f.mesh.userData.mdlEmitter={};f.mesh.position.set(99,99,99);
 const p=prepareGodotRoom(f),mesh=p.scene.children[0];assert.equal(p.manifest.counts.particles,1);assert.deepEqual(mesh.matrix.toArray(),new T.Matrix4().toArray());assert.equal(mesh.geometry.getAttribute('color').itemSize,4);assert.equal(mesh.geometry.getAttribute('color').normalized,true);p.dispose();
});
test('unknown shader/material stages fail explicitly rather than silently dropping content',()=>{
 const f=fixture();f.mesh.material=new T.ShaderMaterial();assert.throws(()=>prepareGodotRoom(f),/Unmapped material/);f.mesh.material=f.material;f.material.normalMap=f.map;assert.throws(()=>prepareGodotRoom(f),/Unmapped additional/);
});

test('object identity survives nested body/equipment parts and particle blend semantics are explicit',()=>{
 const f=fixture(),owner=new T.Group();owner.userData.networkObjectId=4294967091;f.scene.remove(f.mesh);owner.add(f.mesh);f.scene.add(owner);assert.equal(sourceObjectId(f.mesh),4294967091);
 f.mesh.material=new T.ShaderMaterial({uniforms:{particleMap:{value:f.map}},blendDst:T.OneFactor});f.mesh.userData.mdlEmitter={};f.geometry.setAttribute('particleColor',new T.Uint8BufferAttribute(new Uint8Array(f.geometry.attributes.position.count*4).fill(255),4,true));
 const p=prepareGodotRoom({...f,focus:[1,2,3]});assert.equal(p.manifest.meshes[0].objectId,4294967091);assert.equal(p.manifest.meshes[0].blend,'additive');assert.deepEqual(p.manifest.focus,[1,2,3]);p.dispose();
});

test('entity snapshots reuse replicated eligibility and resolved names without inventing usable scenery',async()=>{
 const objects=[{id:1,areaId:3,objectType:5,replicated:{name:{text:'Hero'},reaction:1}},{id:2,areaId:3,objectType:9,staticState:{name:'Scenery'}}],world={areaId:3,localObjectId:1,registry:{objects:new Map(objects.map(o=>[o.id,o]))}},inventory=objects.map(o=>({id:o.id,resources:['source']}));
 const rows=await describeGodotEntities({world,inventory,resolve:async v=>v.text});assert.equal(rows[0].name,'Hero');assert.equal(rows[0].controlled,true);assert.equal(rows[0].eligible,true);assert.equal(rows[1].eligible,false);
});

test('entity delta includes only selected meshes/lights and leaves scenery, camera and other entities alone',()=>{
 const f=fixture(),first=new T.Group();first.userData.networkObjectId=1;first.add(f.mesh);f.scene.add(first);
 const light=new T.PointLight();first.add(light);
 const other=new T.Group();other.userData.networkObjectId=2;other.add(f.mesh.clone());f.scene.add(other);
 f.scene.add(new T.Mesh(f.geometry,f.material),new T.AmbientLight());
 const p=prepareGodotRoom({...f,objectIds:new Set([1]),namePrefix:'delta_7_',includeCamera:false});
 assert.equal(p.manifest.counts.meshes,1);assert.equal(p.manifest.counts.lights,1);assert.equal(p.manifest.counts.ambient,0);
 assert.equal(p.manifest.meshes[0].name,'delta_7_nwn_mesh_0');assert.equal(p.manifest.lights[0].objectId,1);
 assert.equal(p.scene.children.length,2);assert.equal(f.scene.children.length,4);p.dispose();
});

test('directional and spot exports face the real world target under transformed parents without changing the source',()=>{
 for(const Type of [T.DirectionalLight,T.SpotLight]){
  const f=fixture(),parent=new T.Group();parent.position.set(7,3,-2);parent.rotation.y=.6;f.scene.add(parent);
  const light=new Type(0xffdd99,1);light.position.set(2,5,3);parent.add(light);light.target.position.set(-2,.5,1);f.scene.add(light.target);
  f.scene.updateMatrixWorld(true);const before=light.matrixWorld.clone(),expected=light.target.getWorldPosition(new T.Vector3()).sub(light.getWorldPosition(new T.Vector3())).normalize();
  const p=prepareGodotRoom(f),row=p.manifest.lights[0],copy=p.scene.getObjectByName(row.name),axis=new T.Vector3(0,0,-1).transformDirection(copy.matrix);
  assert.ok(axis.distanceTo(expected)<1e-12);assert.deepEqual(row.direction,expected.toArray());assert.deepEqual(light.matrixWorld.toArray(),before.toArray());assert.equal(copy.target.parent,copy);assert.deepEqual(copy.target.position.toArray(),[0,0,-1]);p.dispose();
 }
});

test('ambient and background retain linear color values for one native conversion',()=>{
 const f=fixture();f.scene.background=new T.Color().setRGB(.05,.1,.2);f.scene.add(new T.AmbientLight(new T.Color().setRGB(.1,.2,.3),.75));
 const p=prepareGodotRoom(f);assert.deepEqual(p.manifest.background,[.05,.1,.2]);assert.deepEqual(p.manifest.ambient,[.07500000000000001,.15000000000000002,.22499999999999998]);p.dispose();
 const delta=prepareGodotRoom({...f,includeCamera:false});assert.equal(delta.manifest.background,undefined);delta.dispose();
});

test('only an explicitly tagged source area sun is handed to the native atmosphere owner',()=>{
 const f=fixture(),sun=new T.DirectionalLight(),other=new T.PointLight();sun.userData.nativeAreaLight=true;f.scene.add(sun,other);
 const p=prepareGodotRoom(f);assert.equal(p.manifest.lights[0].areaPrimary,true);assert.equal(p.manifest.lights[1].areaPrimary,false);assert.equal(sun.userData.nativeAreaLight,true);p.dispose();
});
test('real hidden placeable hit faces survive transfer only for explicitly usable owners and remain invisible',()=>{
 const f=fixture();f.mesh.userData.networkObjectId=9;f.mesh.userData.nativeObjectHitMesh=true;f.mesh.material=new T.MeshBasicMaterial({visible:false,transparent:true,opacity:0,colorWrite:false,depthWrite:false});
 const p=prepareGodotRoom({...f,entities:[{id:9,type:9,eligible:true}]});assert.equal(p.manifest.counts.meshes,1);assert.equal(p.manifest.meshes[0].pickOnly,true);assert.equal(p.scene.children[0].material.opacity,0);assert.equal(p.scene.children[0].material.depthWrite,false);assert.equal(f.mesh.material.visible,false);p.dispose();
 for(const entities of [[{id:9,type:9,eligible:false}],[{id:9,type:5,eligible:true}],[]]){const skipped=prepareGodotRoom({...f,entities});assert.equal(skipped.manifest.counts.meshes,0);skipped.dispose();}
});
