import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {cameraQuaternion,stepCameraFollow,stepCameraSteering,GameCamera} from '../src/game_camera.js';
import {PerspectiveCamera,Vector3} from 'three';
import {cameraPointerDelta} from '../src/game_camera_input.js';
import {NativeMessageWriter} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-camera-observations.json',import.meta.url)));
const near=(a,b,label)=>assert.ok(Math.abs(a-b)<.0001,`${label}: ${a} vs ${b}`);
test('original Follow control agrees on spring, zoom, orbit, tilt, quaternion and focus',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of fixture.frames){const c=row.case,s={height:1.7,distance:20,minDist:1,maxDist:25,clampDist:1,minPitch:1,maxPitch:89,clampPitch:1,focus:[1,1,1],...c,quaternion:cameraQuaternion(c.oldYaw,c.oldPitch)};stepCameraFollow(s,c.dt,[2,3,.5]);
  for(const key of ['distance','yaw','pitch','turn','tilt','speed'])near(s[key],row[key],JSON.stringify({c,key}));
  for(const key of ['focus','position','quaternion'])for(let i=0;i<row[key].length;i++)near(s[key][i],row[key][i],JSON.stringify({c,key,i}));
 }
});
test('original chase, top-down and stiff chase steering agree across facing, manual input and idle states',()=>{
 for(const row of fixture.modes){const c=row.case,s={turn:0,manualLatch:0,wasIdle:0,...c,quaternion:cameraQuaternion(c.yaw,50)};stepCameraSteering(s,c,c.dt);for(const key of ['turn','manual','turning','manualLatch','wasIdle'])near(s[key],row[key],JSON.stringify({c,key}));}
});
test('original mouse handlers agree on resolution-scaled yaw and pitch impulses',()=>{
 assert.equal(fixture.pointers.length,100);for(const row of fixture.pointers){const actual=cameraPointerDelta(row.case.dx,row.case.dy,row.case.width);for(const event of row.events){near(actual[event.axis],event.value,JSON.stringify(row.case));assert.equal(event.impulse,1);}for(const axis of ['yaw','pitch'])if(!row.events.some(e=>e.axis===axis))assert.ok(actual[axis]===0);}
});
test('native server camera-mode packets reach the same three gameplay modes and reject truncated fields',()=>{
 for(const mode of [0,1,2,255]){const w=new NativeMessageWriter(1);w.create(1,0xffffffff,1);w.writeByte(mode);w.setPrefix(Uint8Array.from([80,16,2]));const packet=w.getWriteMessage().data,value=decodeServerGameMessage(packet);assert.deepEqual(value,{kind:'camera-mode',major:16,minor:2,mode});const state=new GameCamera();assert.equal(state.setMode(mode),mode<=2);assert.throws(()=>decodeServerGameMessage(packet.subarray(0,packet.length-2)));}
});
test('camera keeps character focus, converts native axes, consumes wheel input and switches modes',()=>{
 const camera=new PerspectiveCamera(),controls={target:new Vector3()},state=new GameCamera();state.reset({position:[2,3,0],height:1.7});state.update({position:[2,3,0]},1/60,camera,controls);
 assert.ok(controls.target.distanceTo(new Vector3(2,1.2,-3))<.00001);const direction=camera.getWorldDirection(new Vector3()),toward=controls.target.clone().sub(camera.position).normalize();assert.ok(direction.distanceTo(toward)<.00001);
 const before=state.distance;state.input({zoom: 7.5});state.update({position:[3,4,0],animation:4},1/60,camera,controls);assert.ok(state.distance<before);assert.ok(controls.target.distanceTo(new Vector3(3,1.2,-4))<.001);assert.ok(!state.setMode(255));assert.ok(state.setMode(0,1.7));assert.equal(state.mode,0);
});
