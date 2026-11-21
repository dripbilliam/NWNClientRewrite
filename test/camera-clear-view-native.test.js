import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {GameCamera,cameraQuaternion,findCameraClearView} from '../src/game_camera.js';
import {Group,Mesh,MeshBasicMaterial,PlaneGeometry,PerspectiveCamera,Vector3} from 'three';
import {cameraSceneQuery} from '../src/camera_scene_query.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-camera-clear-view-observations.json',import.meta.url)));
const close=(a,b,label)=>assert.ok(Math.abs(a-b)<.00002,`${label}: ${a} != ${b}`);
test('entry clear-view candidate order, prediction and state agree with original7cc070/7cc730',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.rows.length,257);
 for(const row of fixture.rows){const c=row.case;if(c.present===false)continue;const s=new GameCamera();Object.assign(s,c);s.offset=[0,0,c.height??Math.fround(1.7)];s.focus=c.focus??[1,1,1];s.quaternion=cameraQuaternion(c.oldYaw,c.oldPitch);let index=0;
  const before={focus:[...s.focus],quaternion:[...s.quaternion],turn:s.turn,tilt:s.tilt,speed:s.speed};
  const result=findCameraClearView(s,{position:[2,3,.5],facing:row.yaw},c.dt,(a,b)=>{const ray=row.rays[index++];assert.ok(ray);assert.equal(ray.query,1);assert.equal(ray.mask,'ffffffffbfffffff');for(let i=0;i<3;i++){close(a[i],ray.start[i],`start ${i}, ${JSON.stringify(c)}`);close(b[i],ray.end[i],'end');}return ray.blocked;});
  assert.equal(result.selected,Boolean(row.result));assert.equal(index,row.rays.length);assert.equal(s.yaw,row.result?row.selected[0]:row.yaw);assert.equal(s.pitch,row.result?row.selected[1]:c.pitch);assert.equal(s.manualLatch,row.manualLatch);assert.equal(s.turning,row.turning);
  for(let i=0;i<3;i++)close(result.focus[i],row.focus[i],'prediction focus');assert.deepEqual({focus:s.focus,quaternion:s.quaternion,turn:s.turn,tilt:s.tilt,speed:s.speed},before,'prediction leaves Follow inputs and display state intact');
 }
});
test('scene clear-view adapter includes static tile geometry, ignores dynamic objects, and preserves front-face segment direction',()=>{
 const root=new Group(),dynamic=new Mesh(new PlaneGeometry(10,10),new MeshBasicMaterial()),tile=new Group(),wall=new Mesh(new PlaneGeometry(10,10),new MeshBasicMaterial());root.add(dynamic,tile);tile.userData.nativeStaticTile=true;wall.userData.nativeModelMesh=true;tile.add(wall);
 // Three +Z wall normal maps to native -Y. A native Y=-2 -> +2 segment hits.
 assert.equal(cameraSceneQuery(root)([0,-2,0],[0,2,0]),true);assert.equal(cameraSceneQuery(root)([0,2,0],[0,-2,0]),false);assert.equal(cameraSceneQuery(root)([0,-2,0],[0,-1,0]),false);
 tile.remove(wall);assert.equal(cameraSceneQuery(root)([0,-2,0],[0,2,0]),false,'dynamic geometry excluded even when visible');
 const triangle={surfaceType:30,vertices:[[-5,-5,0],[5,-5,0],[0,5,0]]};assert.equal(cameraSceneQuery(root,[triangle])([0,-2,0],[0,2,0]),false);triangle.surfaceType=1;assert.equal(cameraSceneQuery(root,[triangle])([0,-2,0],[0,2,0]),true);
 wall.geometry.dispose();wall.material.dispose();dynamic.geometry.dispose();dynamic.material.dispose();
});
test('one-shot search clears state and normal scripted interpolation resumes on the following frame',()=>{
 const s=new GameCamera(),camera=new PerspectiveCamera(),controls={target:new Vector3()};s.rememberedPose={yaw:35,pitch:50,distance:20};s.attach({position:[2,3,.5],height:1.7,findClearView:true});s.scriptLocation={yaw:120,pitch:50,distance:20,rate:90};let queries=0;
 s.update({position:[2,3,.5],clearViewFacing:45,clearViewQuery:()=>++queries===1},.016,camera,controls);assert.equal(s.findClearView,false);assert.equal(s.yaw,225);assert.equal(s.clearViewResult.selected,true);assert.equal(queries,2);assert.equal(s.scriptLocation.rate,90);
 s.update({position:[2,3,.5]},.016,camera,controls);assert.ok(s.yaw<225);assert.equal(queries,2);assert.deepEqual(s.rememberedPose,{yaw:225,pitch:50,distance:20});
});
