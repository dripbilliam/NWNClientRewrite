import test from 'node:test';import assert from 'node:assert/strict';import * as T from 'three';
import {pickedWorldObject,withWorldPickFrame} from '../src/world_picking.js';
test('shared picks preserve player filtering, occlusion, differing rays and changes between scopes',()=>{
 const root=new T.Group(),registry={objects:new Map(),get(id){return this.objects.get(id);}},geometry=new T.BoxGeometry(),material=new T.MeshBasicMaterial();
 for(const [id,z]of [[1,0],[2,-2]]){const mesh=new T.Mesh(geometry,material);mesh.position.z=z;mesh.userData.worldObjectId=id;if(id===1)mesh.userData.worldPickingPlayer=true;root.add(mesh);registry.objects.set(id,{id});}
 const owner={root},ray=new T.Raycaster(new T.Vector3(0,0,4),new T.Vector3(0,0,-1));let matrices=0,intersections=0;const update=root.updateWorldMatrix;root.updateWorldMatrix=function(...args){matrices++;return update.apply(this,args);};const intersect=ray.intersectObject;ray.intersectObject=function(...args){intersections++;return intersect.apply(this,args);};
 const pick=includePlayer=>pickedWorldObject(ray,root,registry,{includePlayer,frame:owner.pickFrame});
 withWorldPickFrame(owner,()=>{assert.equal(pick(true).object.id,1);assert.equal(pick(false).object.id,2);assert.equal(pick(true).object.id,1);assert.equal(matrices,1);assert.equal(intersections,1);ray.near=4;assert.equal(pick(true).object.id,2);assert.equal(intersections,2);});
 assert.equal(owner.pickFrame,undefined);root.children[0].position.x=4;ray.near=0;
 withWorldPickFrame(owner,()=>assert.equal(pick(true).object.id,2));assert.equal(matrices,2);
 root.children[1].userData.worldObjectId=undefined;withWorldPickFrame(owner,()=>assert.equal(pick(true).object,null));
 geometry.dispose();material.dispose();
});
test('picking scope releases references on failure and restores an outer scope',()=>{
 const owner={root:new T.Group()};assert.throws(()=>withWorldPickFrame(owner,()=>{const first=owner.pickFrame;withWorldPickFrame(owner,()=>assert.notEqual(owner.pickFrame,first));assert.equal(owner.pickFrame,first);throw Error('consumer failed');}),/consumer failed/);assert.equal(owner.pickFrame,undefined);
});
