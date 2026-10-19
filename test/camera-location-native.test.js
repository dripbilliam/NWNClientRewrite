import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {GameCamera,stepCameraLocation,stepCameraFollow} from '../src/game_camera.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-camera-location-observations.json',import.meta.url)));
const near=(a,b,label)=>assert.ok(Math.abs(a-b)<=.0001,`${label}: ${a} vs ${b}`);
test('original location receiver agrees on all masks, radians conversion, snapping and transition-rate handling',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.packets.length,104);
 for(const row of fixture.packets){assert.deepEqual(row.diagnostics,[]);assert.equal(row.overflow,false);assert.equal(row.underflow,false);const s=new GameCamera();Object.assign(s,row.case);const bytes=Uint8Array.from([80,16,1,...Buffer.from(row.body,'hex')]);const command=decodeServerGameMessage(bytes);assert.equal(s.applyCommand(command),true);
  assert.deepEqual(Object.values(s.scriptLocation),row.observation.target);for(const key of ['yaw','pitch','distance'])assert.equal(s[key],row.observation[key]);assert.throws(()=>decodeServerGameMessage(bytes.subarray(0,6)));
 }
});
test('original synchronized transition and scalar helpers agree across modes, rates and frame times',()=>{
 assert.equal(fixture.frames.length,378);for(const row of fixture.frames){const c=row.case,s={...c,turn:0,tilt:0,speed:0,scriptLocation:{distance:c.target[0],yaw:c.target[1],pitch:c.target[2],rate:Math.fround(c.transition)}};assert.equal(Number(stepCameraLocation(s,c.dt,c.paused)),row.result,JSON.stringify(c));for(const key of ['yaw','pitch','distance','turn','tilt','speed'])near(s[key],row.observation[key],JSON.stringify({c,key}));}
});
test('native transitions integrate through Follow to completion, preserve locks and are cancelled by restore',()=>{
 const s=new GameCamera();s.mode=1;s.scriptLocation={distance:5,yaw:70,pitch:60,rate:90};s.focus=[0,0,1];let complete=false;
 for(let n=0;n<10000&&!complete;n++){complete=stepCameraLocation(s,1/60);stepCameraFollow(s,1/60,[0,0,0]);}
 assert.ok(complete);near(s.yaw,70,'yaw endpoint');near(s.pitch,60,'pitch endpoint');near(s.distance,5,'distance endpoint');
 s.scriptLocation.rate=90;s.applyCommand({kind:'camera-restore'});assert.equal(s.scriptLocation.rate,0);
 s.applyCommand({kind:'camera-lock',axis:'pitch',locked:true});const lockedPitch=s.pitch;s.scriptLocation={distance:5,yaw:70,pitch:70,rate:90};for(let n=0;n<60;n++){stepCameraLocation(s,1/60);stepCameraFollow(s,1/60,[0,0,0]);}assert.equal(s.pitch,lockedPitch);
 assert.equal(s.applyCommand({kind:'camera-location',mask:1}),false);
});
