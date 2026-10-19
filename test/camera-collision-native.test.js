import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {GameCamera,cameraQuaternion,stepCameraFollow} from '../src/game_camera.js';
import {cameraCollisionState,stepCameraCollision} from '../src/camera_collision.js';
import {Group,Mesh,MeshBasicMaterial,PlaneGeometry,PerspectiveCamera,Vector3} from 'three';
import {cameraSceneQuery} from '../src/camera_scene_query.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-camera-collision-observations.json',import.meta.url))),f=Math.fround;
const close=(a,b,label)=>assert.ok(Math.abs(a-b)<.000025,`${label}: ${a} != ${b}`);
test('full original collision dispatcher, ordered queries and recovery state agree across all three modes',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.rows.length,891);
 for(const row of fixture.rows){const c=row.case,s=new GameCamera();Object.assign(s,c);s.offset=[0,0,f(c.height??1.7)];s.quaternion=cameraQuaternion(c.oldYaw??c.yaw??0,c.oldPitch??c.pitch??50);s.findClearView=Boolean(c.findClear);const caches=cameraCollisionState();for(const state of Object.values(caches)){state.focus=c.cachedFocus??[0,0,0];state.distance=c.cachedDistance??0;}let position=c.target??[2,3,.5];
  for(const step of row.steps){const frame={...c,...step.frame};if(step.frame.position)position=step.frame.position;let index=0;
   const predict=(focus,speed)=>stepCameraFollow({...s,focus:[...focus],quaternion:[...s.quaternion],offset:[0,0,1],spring:750,clampYaw:0,clampPitch:1,minPitch:1,maxPitch:89,clampDist:1,minDist:1,maxDist:25,speed},frame.dt,position);
   const speed=stepCameraCollision(s,caches,{position,cameraPosition:c.cameraPosition??[4,-7,8],enabled:c.enabled!==0,eligible:c.eligible!==0,clampsEnabled:c.clampsEnabled!==0,flags:c.flags??0},frame.dt,frame.speed,(start,end)=>{const ray=step.rays[index++];assert.ok(ray,JSON.stringify({c,frame,index}));for(let i=0;i<3;i++){close(start[i],ray.start[i],`start${i} ${JSON.stringify({c,frame,index})}`);close(end[i],ray.end[i],`end${i}`);}return ray.point;},predict);
   assert.equal(index,step.rays.length);close(speed,step.speed,'returned speed');close(s.distance,step.distance,JSON.stringify({c,frame}));assert.equal(s.clampDist,step.clampDist);assert.equal(s.manual,step.manual);
   for(const [key,state]of Object.entries(caches)){close(state.distance,step.cache[key].distance,'saved distance');state.focus.forEach((v,i)=>close(v,step.cache[key].focus[i],'cached focus'));}
  }
 }
});
test('native scene-query adapter clips to the nearest front-facing hit and ignores draw material visibility',()=>{
 const root=new Group(),tile=new Group();root.add(tile);tile.userData.nativeStaticTile=true;const meshes=[];
 for(const y of [1,-1]){const mesh=new Mesh(new PlaneGeometry(10,10),new MeshBasicMaterial({visible:false}));mesh.userData.nativeModelMesh=true;mesh.position.z=-y;tile.add(mesh);meshes.push(mesh);}
 const query=cameraSceneQuery(root);assert.deepEqual(query.nearest([0,-3,0],[0,3,0]),[0,-1,0]);assert.equal(query.nearest([0,3,0],[0,-3,0]),null);assert.equal(query.nearest([0,-3,0],[0,-2,0]),null);assert.equal(query([0,-3,0],[0,3,0]),true);for(const mesh of meshes){mesh.geometry.dispose();mesh.material.dispose();}
});
test('normal view collision shortens distance and restores the native saved distance after obstruction removal',()=>{
 const s=new GameCamera(),camera=new PerspectiveCamera(),controls={target:new Vector3()},position=[2,3,.5];s.setMode(2);s.update({position},1,camera,controls);const original=s.distance;
 const collision={position,cameraPosition:[...s.position],query:(a,b)=>a.map((n,i)=>f(f(n*.5)+f(b[i]*.5))),keyholeActive:false};s.update({position,collision},.016,camera,controls);assert.ok(s.distance<original);assert.equal(s.collisionState.stiff.distance,original);
 collision.query=()=>null;for(let i=0;i<320;i++){collision.cameraPosition=[...s.position];s.update({position,collision},.016,camera,controls);}const native=fixture.rows.find(r=>r.case.mode===2&&r.steps.length===321).steps.at(-1);assert.equal(s.distance,native.distance);assert.equal(s.collisionState.stiff.distance,native.cache.stiff.distance);close(s.distance,original,'native f32 stiff-recovery endpoint');
});
test('native keyhole bypass, forced collision, bypass flag and zoom block preserve server camera policy',()=>{
 const camera=new PerspectiveCamera(),controls={target:new Vector3()},s=new GameCamera(),position=[2,3,.5];s.update({position},1,camera,controls);let calls=0;const collision={position,cameraPosition:[...s.position],query:()=>{calls++;return null;},keyholeActive:true};
 s.update({position,collision},.016,camera,controls);assert.equal(calls,0);s.applyCommand({kind:'camera-flags',flags:1});s.update({position,collision},.016,camera,controls);assert.ok(calls>0);const previous=calls;s.applyCommand({kind:'camera-flags',flags:3});s.update({position,collision},.016,camera,controls);assert.equal(calls,previous);
 const distance=s.distance;s.applyCommand({kind:'camera-flags',flags:64});s.input({zoom:7.5});s.update({position,collision},.016,camera,controls);assert.equal(s.distance,distance);assert.equal(s.applyCommand({kind:'camera-flags',flags:2**32}),false);
});
test('native zoom blocking also suppresses timed script zoom without discarding the pending location',()=>{
 const camera=new PerspectiveCamera(),controls={target:new Vector3()},s=new GameCamera();s.applyCommand({kind:'camera-flags',flags:64});s.scriptLocation={yaw:0,pitch:50,distance:10,rate:45};s.update({position:[0,0,0]},.016,camera,controls);assert.equal(s.distance,20);assert.equal(s.scriptLocation.rate,45);s.applyCommand({kind:'camera-flags',flags:0});s.update({position:[0,0,0]},.016,camera,controls);assert.ok(s.distance<20);
});
