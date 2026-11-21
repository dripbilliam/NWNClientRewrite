import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {addCameraRate} from '../src/camera_rate_input.js';
import {GameCamera,cameraQuaternion} from '../src/game_camera.js';
import {PerspectiveCamera,Vector3} from 'three';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-camera-rate-flags-observations.json',import.meta.url)));
test('full original angular/zoom setters match raw accumulators, flags, manual events and separate prediction inputs',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.rows.length,403);
 for(const row of fixture.rows){const s={flags:row.flags,turn:1.25,tilt:-2.5,speed:3.75,turnDelta:4.5,tiltDelta:-5.5,predictionInputs:{tilt:100,turn:200,tiltDelta:300,turnDelta:400,speed:500},manual:0,yawEvent:0,zoomEvent:0};
  for(const step of row.steps){addCameraRate(s,step.axis,step.value,Boolean(step.impulse));assert.deepEqual(Object.fromEntries(Object.keys(step.follow).map(k=>[k,s[k]])),step.follow);assert.deepEqual(Object.values(s.predictionInputs),step.prediction);for(const k of ['manual','yawEvent','zoomEvent'])assert.equal(s[k],step[k]);}
 }
});
test('blocked rotation rejects new manual/script rates and preserves previously queued native inputs',()=>{
 const s=new GameCamera(),camera=new PerspectiveCamera(),controls={target:new Vector3()};s.flags=48;s.input({yaw:20,pitch:10});s.update({position:[0,0,0]},.016,camera,controls);assert.equal(s.yaw,0);assert.equal(s.pitch,50);assert.equal(s.manualLatch,0);
 s.flags=0;s.input({yaw:20,pitch:10});s.flags=48;s.update({position:[0,0,0]},.016,camera,controls);assert.equal(s.yaw,20);assert.equal(s.pitch,60,'flags block setters, not already queued values');
 s.scriptLocation={yaw:120,pitch:70,distance:s.distance,rate:45};const before=[s.yaw,s.pitch];s.update({position:[0,0,0]},.016,camera,controls);assert.deepEqual([s.yaw,s.pitch],before);assert.equal(s.scriptLocation.rate,45);s.flags=0;s.update({position:[0,0,0]},.016,camera,controls);assert.ok(s.yaw>before[0]&&s.pitch>before[1]);
});
test('native yaw impulse changes Follow yaw while updating the aliased pitch-prediction field',()=>{
 const s=new GameCamera();s.input({yaw:7});assert.equal(s.turnDelta,7);assert.equal(s.tiltDelta,0);assert.equal(s.predictionInputs.tiltDelta,7);assert.equal(s.predictionInputs.turnDelta,0);s.input({pitch:-3});assert.equal(s.predictionInputs.tiltDelta,-3);assert.deepEqual(s.quaternion,cameraQuaternion(0,50));
});
