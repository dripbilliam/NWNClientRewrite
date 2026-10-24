import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {BoxGeometry,Group,Mesh,MeshBasicMaterial,Raycaster,Scene,Vector3} from 'three';
import {NetworkScene} from '../src/network_scene.js';
import {NetworkWorld} from '../src/network_world.js';
import {networkTriggerSurface,networkTransitionTrigger} from '../src/network_trigger.js';
import {worldCursorId} from '../src/game_cursor.js';
import {networkDefaultInteraction,networkRadialActions} from '../src/network_action_menu.js';
import {highlightEligible} from '../src/world_highlight.js';
import {WorldHighlightRenderer} from '../src/world_highlight_renderer.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NetworkFrontend} from '../src/network_frontend.js';
import {walkToWaypointRequest} from '../src/network_player_requests.js';

const region=()=>({id:0x80000010,objectType:7,areaId:0x80000001,replicated:{name:{text:'Portal'},hasTransition:1,isTrap:0,position:[100,100,100],vertices:[[0,0,0],[3,0,0],[3,1,0],[1,1,0],[1,3,0],[0,3,0]]}});
const ray=(x,y)=>new Raycaster(new Vector3(x,10,-y),new Vector3(0,-1,0));

test('replicated transition geometry is selectable without a model or position update; concave cutouts remain empty',async()=>{
 const world=new NetworkWorld(),o=region();world.areaId=o.areaId;world.registry.addObjectAtPos(o.id,o);const scene=new NetworkScene({world,resolver:{},report:()=>{}});scene.area={id:o.areaId};
 try{await scene.sync();assert.equal(scene.objects.size,1);assert.equal(scene.objects.get(o.id).models.length,0);const inside=scene.pick(ray(.5,2));assert.equal(inside.object,o);assert.ok(Math.abs(inside.point.y-.05)<1e-6);assert.equal(scene.pick(ray(2,2)),null);assert.equal(scene.pick(ray(-1,0)),null);assert.equal(scene.pick(ray(.5,2),{objectsOnly:true}).object,o);
  const old=scene.objects.get(o.id),before=structuredClone(o);assert.equal(old.wrapper.children[0].material.opacity,0);assert.deepEqual(o,before);
  // Nearest opaque scenery remains an occluder.
  const wall=new Mesh(new BoxGeometry(1,1,1),new MeshBasicMaterial());wall.position.set(.5,2,-2);scene.root.add(wall);assert.equal(scene.pick(ray(.5,2),{objectsOnly:true}),null);wall.removeFromParent();wall.geometry.dispose();wall.material.dispose();
  o.replicated.vertices=o.replicated.vertices.map(v=>[v[0]+10,v[1],v[2]]);await scene.sync();assert.notEqual(scene.objects.get(o.id),old);assert.equal(old.wrapper.parent,null);assert.equal(scene.pick(ray(.5,2)),null);assert.equal(scene.pick(ray(10.5,2)).object,o);
  o.replicationRemoved=true;await scene.sync();assert.equal(scene.objects.size,0);assert.equal(scene.pick(ray(10.5,2)),null);
 }finally{await scene.dispose();}
});

test('transition cursor, Enter radial and highlights are limited to live non-trap transitions',()=>{
 const o=region(),context={areaId:o.areaId};assert.equal(networkTransitionTrigger(o),true);assert.equal(worldCursorId(o),21);assert.equal(worldCursorId(o,{pressed:true}),22);assert.equal(networkDefaultInteraction(o),'trigger.transition');assert.equal(networkRadialActions(o,{id:4,objectType:5}).entries[0].action,'trigger.transition');assert.equal(highlightEligible(o,context),true);
 for(const bad of [{...o,replicationRemoved:true},{...o,replicated:{...o.replicated,hasTransition:0}},{...o,replicated:{...o.replicated,isTrap:1}}]){assert.equal(networkTransitionTrigger(bad),false);assert.equal(networkTriggerSurface(bad),null);assert.equal(highlightEligible(bad,context),false);}
 for(const vertices of [[],[[0,0,0],[1,1,0]],[[0,0,0],[1,1,0],[NaN,0,0]],[[0,0,0],[1,0,0],[2,0,0]]])assert.equal(networkTriggerSurface({...o,replicated:{...o.replicated,vertices}}),null);
});

test('invisible transition surface supplies geometry to hover/Tab highlighting and releases it on removal',async()=>{
 const world=new NetworkWorld(),o=region();world.areaId=o.areaId;world.registry.addObjectAtPos(o.id,o);const scene=new NetworkScene({world,resolver:{}});scene.area={id:o.areaId};const outer=new Scene(),renderer=new WorldHighlightRenderer(outer);outer.add(scene.root);
 try{await scene.sync();const b=scene.objects.get(o.id),mesh=b.wrapper.children[0],entries=[{object:o,root:b.wrapper,meshes:[mesh],color:'#00ffff'}];renderer.update(entries,0);assert.equal(renderer.parts,1);assert.equal(entries[0].bounds.isEmpty(),false);let disposals=0;mesh.geometry.addEventListener('dispose',()=>disposals++);mesh.material.addEventListener('dispose',()=>disposals++);scene.remove(o.id);assert.equal(disposals,2);assert.equal(b.wrapper.parent,null);}finally{renderer.dispose();await scene.dispose();}
});

test('Enter retains native selected-trigger ID through owning frontend and movement request, without local teleport',async()=>{
 const world=new NetworkWorld(),o=region(),actor={id:0xffffffff,areaId:o.areaId,objectType:5,replicated:{position:[5,5,0]}};world.areaId=o.areaId;world.localObjectId=actor.id;world.registry.addObjectAtPos(o.id,o);world.registry.addObjectAtPos(actor.id,actor);
 const peer=new EventEmitter(),sent=[];peer.sendGameMessage=async p=>sent.push(p);peer.disconnect=async()=>{};
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{},dispose(){}},resources:{},openModule:async()=>null});session.world=world;session.phase='playing';session.areaReadySent=true;session.areaGeneration=2;
 const frontend=Object.assign(Object.create(NetworkFrontend.prototype),{id:'owner',world,areaGeneration:2,bridge:{interact:async(id,request)=>{assert.equal(id,'owner');return session.interact(request);}}}),before=structuredClone(actor);
 await frontend.interact(o.id,networkDefaultInteraction(o),false);assert.deepEqual(sent,[walkToWaypointRequest({areaId:o.areaId,position:networkTriggerSurface(o).destination,targetId:o.id,sequence:1,run:false,clientPath:false,fractional:0})]);assert.deepEqual(actor,before);
 await assert.rejects(session.interact({areaId:o.areaId,areaGeneration:1,targetId:o.id,action:'trigger.transition'}));o.replicated.hasTransition=0;await assert.rejects(frontend.interact(o.id,'trigger.transition'));assert.equal(sent.length,1);await session.disconnect();
});
