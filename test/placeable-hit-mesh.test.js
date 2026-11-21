import test from 'node:test';import assert from 'node:assert/strict';import {EventEmitter} from 'node:events';
import {BoxGeometry,Group,Mesh,MeshBasicMaterial,Raycaster,Scene,Vector3} from 'three';
import {createModelHierarchy} from '../src/model_hierarchy.js';import {attachPlaceableHitMeshes,disposePlaceableHitMeshes} from '../src/placeable_hit_mesh.js';
import {NetworkScene} from '../src/network_scene.js';import {NetworkWorld} from '../src/network_world.js';import {networkDefaultInteraction,networkRadialActions} from '../src/network_action_menu.js';import {worldCursorId} from '../src/game_cursor.js';import {highlightEligible} from '../src/world_highlight.js';import {WorldHighlightRenderer} from '../src/world_highlight_renderer.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';import {useObjectRequest} from '../src/network_player_requests.js';

const model=()=>({modelName:'authored-hidden-hit',nodes:[{name:'root',type:'dummy',parent:'NULL',position:[0,0,0],orientation:[0,0,1,0],properties:{}},{name:'selection',type:'trimesh',render:false,parent:'root',position:[0,0,0],orientation:[0,0,1,0],verts:[[-1,-1,0],[1,-1,0],[0,1,1]],faces:[[0,1,2]],properties:{}}]});
const portal=()=>({id:0x80000002,objectType:9,areaId:0x80000001,replicated:{appearance:391,name:{text:'Portal'},field264:1,position:[0,0,0],orientation:{yaw:0}}});
const ray=()=>new Raycaster(new Vector3(0,5,0),new Vector3(0,-1,0));
function setup(){const world=new NetworkWorld(),object=portal();world.areaId=object.areaId;world.registry.addObjectAtPos(object.id,object);const scene=new NetworkScene({world,resolver:{},loadAsset:async()=>({model:model()}),instantiate:asset=>({root:createModelHierarchy(asset.model).root,dispose(){}}),releaseAsset(){},report(){}});scene.area={id:object.areaId};scene.tables={placeables:{rows:new Map([[391,{ModelName:'authored-hidden-hit'}]])}};return{world,object,scene};}

test('hidden model triangles remain undrawn while providing normal placeable picking, cursor, Use and highlighting',async()=>{
 const h=setup();await h.scene.sync();const binding=h.scene.objects.get(h.object.id),instance=binding.models[0],mesh=instance.placeableHitMeshes[0];
 try{assert.equal(mesh.material.visible,false);assert.equal(mesh.material.colorWrite,false);assert.equal(h.scene.pick(ray()).object,h.object);assert.equal(networkDefaultInteraction(h.object),'object.use');assert.equal(worldCursorId(h.object),25);assert.equal(highlightEligible(h.object,{areaId:h.object.areaId}),true);const menu=networkRadialActions(h.object,{id:4,objectType:5});assert.ok(menu.entries.some(e=>e.action==='placeable.use'&&!e.disabled));assert.ok(menu.entries.some(e=>e.action==='object.examine'));
  const highlights=new WorldHighlightRenderer(new Scene());try{highlights.update([{object:h.object,root:binding.wrapper,meshes:[mesh],color:'#00ffff'}],0);assert.equal(highlights.parts,1);assert.equal(mesh.material.visible,false);}finally{highlights.dispose();}
 }finally{await h.scene.dispose();}
});

test('ordinary portal object wins over an overlapping transition region and walls still occlude it',async()=>{
 const h=setup();h.world.registry.addObjectAtPos(0x80000003,{id:0x80000003,objectType:7,areaId:h.object.areaId,replicated:{hasTransition:1,isTrap:0,vertices:[[-2,-2,0],[2,-2,0],[2,2,0],[-2,2,0]]}});
 try{await h.scene.sync();assert.equal(h.scene.pick(ray()).object,h.object);const wall=new Mesh(new BoxGeometry(2,1,2),new MeshBasicMaterial());wall.position.set(0,2,0);h.scene.root.add(wall);assert.equal(h.scene.pick(ray(),{objectsOnly:true}),null);wall.removeFromParent();wall.geometry.dispose();wall.material.dispose();}finally{await h.scene.dispose();}
});

test('hidden triangles cannot turn disabled/static scenery into usable objects and cleanup follows model lifetime',async()=>{
 const h=setup();try{await h.scene.sync();const instance=h.scene.objects.get(h.object.id).models[0],mesh=instance.placeableHitMeshes[0];assert.equal(attachPlaceableHitMeshes(instance).length,1);h.object.replicated.field264=0;assert.equal(h.scene.pick(ray()),null);assert.ok(networkRadialActions(h.object,{id:4,objectType:5}).entries.find(e=>e.action==='placeable.use').disabled);h.object.replicated.field264=1;assert.equal(h.scene.pick(ray()).object,h.object);
  let disposed=0;mesh.geometry.addEventListener('dispose',()=>disposed++);mesh.material.addEventListener('dispose',()=>disposed++);h.object.replicationRemoved=true;await h.scene.sync();assert.equal(disposed,2);assert.equal(mesh.parent,null);assert.equal(h.scene.pick(ray()),null);
 }finally{await h.scene.dispose();}
 const source=model();source.nodes[1].render=true;const instance={model:source,root:createModelHierarchy(source).root};assert.equal(attachPlaceableHitMeshes(instance).length,0);disposePlaceableHitMeshes(instance);
});

test('portal Use preserves the original object ID and server request instead of walking or activating a local transition',async()=>{
 const h=setup(),actor={id:0xffffffff,objectType:5,areaId:h.object.areaId,replicated:{position:[5,5,0]}},peer=new EventEmitter(),sent=[];h.world.localObjectId=actor.id;h.world.registry.addObjectAtPos(actor.id,actor);peer.sendGameMessage=async p=>sent.push(p);peer.disconnect=async()=>{};
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{},dispose(){}},resources:{},openModule:async()=>null});session.world=h.world;session.phase='playing';session.areaReadySent=true;session.areaGeneration=1;const before=structuredClone(actor);
 try{await session.interact({areaId:h.object.areaId,areaGeneration:1,targetId:h.object.id,action:networkDefaultInteraction(h.object)});assert.deepEqual(sent,[useObjectRequest({targetId:h.object.id,flag0:false,flag1:true})]);assert.deepEqual(actor,before);}finally{await session.disconnect();await h.scene.dispose();}
});
