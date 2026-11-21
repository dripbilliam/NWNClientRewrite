import test from 'node:test';
import assert from 'node:assert/strict';
import {deriveReplayCameraExpectation,verifyReplayCameraEvidence,verifyReplayProjection} from '../tools/native-replay-camera-evidence.mjs';
const scope={connection:1,generation:2,areaId:9,actorId:12,lifetime:4};
const records=()=>[{sequence:1,kind:'movement-input',value:{...scope,operation:'stop'}},{sequence:2,kind:'view',value:{fov:75,camera_state:{mode:1,yaw:0,pitch:90,distance:25}}},{sequence:3,kind:'movement-sample',at:90000,value:{...scope,state:{active:false,script:0,driveHeld:false,animation:0,position:[10,20,3],render:[10,20,3],received_position:[10,20,3]}}}];
const native=()=>({camera:{player:[10,3,-20]},runtime_features:{presentation:{camera:{pose_space:'world',position:[10,4,5],quaternion:[0,0,0,1],target:[10,4,-20],fov_degrees:45,projection:0,keep_aspect:1,near:0.1,far:150,follow_height:1,follow:{mode:1,yaw:0,pitch:90,distance:25},controlled:{actor_id:12,generation:2,area_id:9,lifetime:4,active:false,script:0,driveHeld:false,position:[10,20,3],render:[10,20,3],received_position:[10,20,3]}}}}});
test('camera expectations preserve recorded evidence while preference FOV controls actual projection',()=>{
 const r=records(),before=structuredClone(r),expected=deriveReplayCameraExpectation(r,45);
 assert.equal(expected.status,'expected');assert.equal(expected.fovDegrees,45);assert.equal(expected.recordedFovDegrees,75);assert.deepEqual(expected.player,[10,3,-20]);assert.deepEqual(r,before);
 assert.equal(verifyReplayCameraEvidence(expected,native()).status,'observed');
});
test('terminal actor drift rejects even with 360 accepted inputs and matching display/settings',()=>{
 const n=native();n.camera.player[0]-=1.4;n.movementReplay={prediction:{verified:true,expected:360}};
 const result=verifyReplayCameraEvidence(deriveReplayCameraExpectation(records(),45),n);assert.equal(result.status,'rejected');assert.ok(result.errors.some(x=>x.includes('Rendered controlled actor')));
});
test('stale lifetimes, unreceived stops and mismatched authority cannot supply terminal proof',()=>{
 for(const change of [r=>r[2].value.lifetime++,r=>r[2].value.state.script=1,r=>r[2].value.state.render[0]++,r=>r[0].value.operation='drive']){
  const r=records();change(r);assert.equal(deriveReplayCameraExpectation(r,45).status,'unavailable');
 }
 for(const field of ['active','script','driveHeld']){const n=native();n.runtime_features.presentation.camera.controlled[field]=field==='script'?1:true;assert.equal(verifyReplayCameraEvidence(deriveReplayCameraExpectation(records(),45),n).status,'rejected');}
});
test('saved FOV cannot substitute for actual perspective and projection-axis evidence',()=>{
 const n=native(),camera=n.runtime_features.presentation.camera;n.runtime_features.presentation.settings={fov_degrees:45};
 for(const [key,value] of [['fov_degrees',75],['keep_aspect',0],['projection',1],['near',0],['far',0]]){const changed=structuredClone(camera);changed[key]=value;assert.equal(verifyReplayProjection(changed,45).status,'rejected',key);}
});
test('camera target, pose and follow inputs are independently required',()=>{
 const expected=deriveReplayCameraExpectation(records(),45);
 for(const mutate of [c=>delete c.position,c=>c.position[0]++,c=>c.target[0]++,c=>c.follow.pitch++,c=>c.follow.distance++,c=>c.follow.mode=2,c=>c.quaternion=[0,0,0,2],c=>c.controlled.received_position[0]++]){const n=native();mutate(n.runtime_features.presentation.camera);assert.equal(verifyReplayCameraEvidence(expected,n).status,'rejected');}
 const n=native();n.runtime_features.presentation.camera.follow.yaw=360;assert.equal(verifyReplayCameraEvidence(expected,n).status,'observed');
});
test('a steady window requires matching camera and settled authority at both boundaries',()=>{
 const expected=deriveReplayCameraExpectation(records(),45),n=native(),camera=n.runtime_features.presentation.camera;
 n.performance_window={steady:true,view_begin:{camera:structuredClone(camera)},view_end:{camera:structuredClone(camera)}};
 assert.equal(verifyReplayCameraEvidence(expected,n).status,'observed');
 for(const key of ['view_begin','view_end'])for(const mutate of [x=>delete x.camera,x=>x.camera.position[0]++,x=>x.camera.fov_degrees=75,x=>x.camera.controlled.script=1,x=>x.camera.controlled.render[0]++,x=>x.camera.far++]){const changed=structuredClone(n);mutate(changed.performance_window[key]);assert.equal(verifyReplayCameraEvidence(expected,changed).status,'rejected',key);}
});
