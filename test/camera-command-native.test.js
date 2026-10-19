import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {PerspectiveCamera,Vector3} from 'three';
import {GameCamera} from '../src/game_camera.js';
import {NetworkPlayerCamera} from '../src/network_camera.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NativeMessageWriter} from '../src/native_message.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-camera-command-observations.json',import.meta.url)));
const clampKeys=['clampYaw','minYaw','maxYaw','clampPitch','minPitch','maxPitch','clampDist','minDist','maxDist'];
const envelope=step=>Uint8Array.from([80,16,step.minor,...Buffer.from(step.body,'hex')]);
test('original camera receiver packets and state agree for height, locks, limits and one-use saved cameras',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.rows.length,52);
 for(const row of fixture.rows){
  const c=row.case,s=new GameCamera(),mode=c.mode??1;s.reset({height:mode===1?1.75:1.25,mode,yaw:c.yaw??35});s.distance=c.distance??20;s.pitch=c.pitch??50;
  for(const [i,step]of row.steps.entries()){
   assert.deepEqual(step.diagnostics,[]);assert.equal(step.overflow,false);assert.equal(step.underflow,false);
   if(i===1&&row.steps[0].minor===3)Object.assign(s,{distance:7,yaw:-20,pitch:30});
   const decoded=decodeServerGameMessage(envelope(step));assert.equal(s.applyCommand(decoded),true,JSON.stringify(step));const expected=step.state;
   assert.equal(s.flags,expected.flags);
   for(const key of ['mode','distance','yaw','pitch'])assert.equal(s[key],expected[key],JSON.stringify({step,key}));
   assert.deepEqual(s.offset,expected.height);assert.deepEqual(clampKeys.map(k=>s[k]),expected.clamps);
   assert.deepEqual(Object.values(s.rawLimits),expected.limits);assert.deepEqual([s.locks.distance,s.locks.pitch,s.locks.yaw].map(Number),expected.locks);
   assert.deepEqual(s.savedCamera,expected.saved.mode===255?null:{mode:expected.saved.mode,distance:expected.saved.values[0],yaw:expected.saved.values[1],pitch:expected.saved.values[2]});
  }
 }
});
test('typed packet writers match original scalar bodies and truncated camera payloads fail',()=>{
 for(const row of fixture.rows)for(const step of row.steps){if(step.minor===12)continue;
  const w=new NativeMessageWriter(1);w.create(0,0xffffffff,1);for(const[kind,value]of step.ops)w[{float:'writeFloat',bool:'writeBool',int:'writeInt'}[kind]](value);w.setPrefix(Uint8Array.from([80,16,step.minor]));const {data,defined}=w.getWriteMessage(),expected=Buffer.from(step.body,'hex');
  assert.equal(data?data.length-3:0,expected.length); // Native unused bits retain the oracle's A5 heap tail.
  for(let i=0;i<expected.length;i++)assert.equal(data[i+3]&defined[i+3],expected[i]&defined[i+3]);
  if(step.body.length){assert.throws(()=>decodeServerGameMessage(envelope(step).subarray(0,6)));}
 }
 assert.equal(decodeServerGameMessage(Uint8Array.from([80,16,11])).kind,'unsupported');assert.throws(()=>decodeServerGameMessage(Uint8Array.from([80,16,12])));
});
test('server axis locks survive native input and replacement recenter without canonical mutation',()=>{
 const p=new NetworkPlayerCamera();p.reset([2,0,-3]);const s=p.controller;s.yaw=35;s.pitch=42.5;s.distance=12.75;
 for(const axis of ['yaw','pitch','distance'])s.applyCommand({kind:'camera-lock',axis,locked:true});s.input({yaw:90,pitch:70,zoom:7.5});p.recenter([3,0,-4]);
 const camera=new PerspectiveCamera(),controls={target:new Vector3()};s.update({position:[3,4,0],animation:4},.1,camera,controls);
 assert.equal(s.yaw,35);assert.equal(s.pitch,42.5);assert.equal(s.distance,12.75);assert.ok(controls.target.distanceTo(new Vector3(3,1,-4))<.001);
});
test('height overrides persist across deferred first appearance binding and zero restores native appearance height',()=>{
 const s=new GameCamera();s.applyCommand({kind:'camera-height',height:3});s.setHeight(1.75,{preserveOverride:true});assert.equal(s.height,3);s.applyCommand({kind:'camera-height',height:0});assert.equal(s.height,1.25);
 assert.equal(s.applyCommand({kind:'camera-height',height:NaN}),false);assert.equal(s.applyCommand({kind:'camera-limits',limits:{minPitch:NaN}}),false);
});
test('received collision flags retain their native signed bits and diagnose remaining unsupported behavior bits',()=>{
 const reports=[],p=new NetworkPlayerCamera({report:(...r)=>reports.push(r)});assert.equal(p.receive({kind:'camera-flags',flags:115},null,null),true);assert.equal(p.controller.flags,115);assert.equal(reports.length,0);assert.equal(p.receive({kind:'camera-flags',flags:-2},null,null),true);assert.equal(p.controller.flags,-2);assert.equal(reports.length,1);assert.equal(reports[0][0],'network.camera-flags-partial');assert.equal(reports[0][2].unsupportedBits,(-2&~115)>>>0);
});
