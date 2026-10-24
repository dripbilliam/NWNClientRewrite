import test from 'node:test';
import assert from 'node:assert/strict';
import {NetworkSceneDelivery} from '../src/network_scene_delivery.js';
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};};
function fixture(){const actor={id:1,areaId:7},objects=new Map([[1,actor]]),gate=deferred(),events=[],scene={world:{areaId:7,registry:{get:id=>objects.get(id)}},closed:false,report:(...v)=>events.push(['error',...v]),requestSync:()=>gate.promise,receiveMovementChanges:e=>events.push(['motion',e[0]?.changes?.position]),receiveAnimationChanges:e=>events.push(['animation',e]),receiveVisualChanges:async e=>events.push(['visual',e]),receiveObjectVisual:async e=>events.push(['instant',e]),receiveProjectile:async h=>events.push(['projectile',h])};return{scene,actor,objects,gate,events,delivery:new NetworkSceneDelivery(scene)};}
test('movement is imported immediately while model IO is pending; captured attack/effect events retain order',async()=>{
 const f=fixture(),batch=[{id:1,action:'movement',changes:{position:[1,2,3]}},{id:1,action:'attack-animation',records:[{result:1}]}];const a=f.delivery.updates(batch);batch[1].records[0].result=99;
 const b=f.delivery.updates([{id:1,action:'movement',changes:{position:[4,5,6]}},{id:1,action:'visual-effects',changes:[{action:'A',visualId:5}]}]);assert.deepEqual(f.events.map(e=>e[0]),['motion','motion']);f.gate.resolve();await Promise.all([a,b]);assert.equal(f.events[2][1][0].records[0].result,1);assert.deepEqual(f.events.slice(2).map(e=>e[0]),['animation','visual','animation','visual']);assert.equal(f.delivery.pending,0);
});
test('deletion, ID reuse, area change and disposal reject stale presentation',async()=>{
 for(const operation of ['delete','replace','area','close']){const f=fixture(),a=f.delivery.objectVisual({targetId:1,visualId:5});await Promise.resolve();if(operation==='delete')f.actor.replicationRemoved=true;if(operation==='replace')f.objects.set(1,{id:1,areaId:7});if(operation==='area')f.scene.world.areaId=8;if(operation==='close')f.delivery.dispose();f.gate.resolve();await a;assert.ok(!f.events.some(e=>e[0]==='instant'),operation);}
});
test('projectiles snapshot their payload and check both canonical endpoints',async()=>{
 const f=fixture(),header={sourceId:1,targetId:1,position:[1,2,3]},p=f.delivery.projectile(header);header.position[0]=99;f.gate.resolve();await p;assert.equal(f.events[0][1].position[0],1);
});
