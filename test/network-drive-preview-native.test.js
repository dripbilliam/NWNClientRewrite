import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {drivePreviewPlan,clipDrivePreview} from '../src/network_drive_preview.js';
import {NetworkMotion} from '../src/network_motion.js';
import {NetworkKeyboardInput} from '../src/network_keyboard_input.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-drive-preview-v1.json',import.meta.url)));
test('90 original local-drive plans agree on distance, direction, turn target, animation and path mode',()=>{
 for(const row of oracle.cases){const p=drivePreviewPlan(row.case,row.case.flags),native=row.paths[0];assert.equal(p.animation,row.animations[0]);assert.equal(p.run,Boolean(native.run));assert.equal(p.mode,native.mode);for(let i=0;i<3;i++){assert.ok(Math.abs(p.target[i]-native.target[i])<2e-5,JSON.stringify({c:row.case,p,native}));if(row.case.flags&48)assert.ok(Math.abs(p.facing[i]-row.targetOrientation[i])<2e-6);}}
});
test('original free/partly blocked preview installation agrees on endpoint; fully blocked preview never invents motion',async()=>{
 for(const row of oracle.partialLines){const c=row.case,result=await clipDrivePreview(c.position,c.target,async(_start,end)=>end[0]<=c.wall);assert.deepEqual(result,row.paths[0].points[1]);assert.equal(row.script,1);assert.equal(row.factor,1);assert.equal(row.newPath,0);}
 assert.equal(await clipDrivePreview([0,0,0],[2,0,0],async()=>false),null);
});
test('250ms local refresh advances each displayed frame between 500ms wire sends without changing canonical state',()=>{
 const actor={id:1,replicated:{position:[1,2,0],orientation:[1,0,0],animation:0,walkRate:2200,runRate:4400}},before=structuredClone(actor),m=new NetworkMotion();m.ensure(actor);let next=0,previous=m.pose(1).position[0],moving=0,largest=0;
 for(let ms=0;ms<2000;ms+=16){if(ms>=next){const s=m.objects.get(1);m.previewDrive(actor,drivePreviewPlan(s,3));next=ms+250;}m.update(.016);const x=m.pose(1).position[0];if(x>previous)moving++;largest=Math.max(largest,x-previous);previous=x;}
 assert.equal(moving,125);assert.ok(largest<.071&&largest>.07);assert.ok(previous>9.7);assert.deepEqual(actor,before);
});
test('stale drive replies preserve preview, matching interruption stops it, and remote motion remains independent',()=>{
 const actor={id:1,replicated:{position:[1,2,0],orientation:[1,0,0],animation:0,walkRate:2200,runRate:4400}},m=new NetworkMotion(),s=m.ensure(actor);m.previewDrive(actor,drivePreviewPlan(s,3));m.driveSequence(1,2);m.update(.1);const path=structuredClone(s.path),position=s.position.slice();m.observe(actor,{actionFlag:1,position:[1,2,0],animation:0,path:[]});assert.deepEqual(s.path,path);assert.deepEqual(s.position,position);assert.equal(s.animation,4);
 m.observe(actor,{actionFlag:2,position:[1.4,2,0],animation:0,path:[]});assert.equal(s.active,false);assert.equal(s.previewBase,false);m.update(.6);assert.deepEqual(s.render,[Math.fround(1.4),2,0]);
 const remote={id:2,replicated:{position:[5,6,0],animation:0}},r=m.ensure(remote);m.observe(remote,{position:[6,6,0],animation:0});assert.equal(r.position[0],6);assert.equal(r.driveSequence,undefined);
});
test('original script paths retain keyboard-facing independently of back, strafe and collision direction',()=>{
 const rows=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-motion-facing-v1.json',import.meta.url))).cases;
 for(const row of rows){assert.deepEqual(row.facingTargets,[[1,0,0]]);}
 for(const flags of [2,4,8,5,9,7,11]){
  const actor={id:1,replicated:{position:[1,2,0],orientation:[1,0,0],animation:0,walkRate:2200,runRate:4400}},m=new NetworkMotion(),s=m.ensure(actor),plan=drivePreviewPlan(s,flags);
  m.previewDrive(actor,plan);m.update(.016);assert.deepEqual(s.orientation,[1,0,0]);assert.notDeepEqual(s.position,[1,2,0]);
 }
});
test('switching from translation to turn-only replaces the local lookahead with an in-place path',()=>{
 const actor={id:1,replicated:{position:[1,2,0],orientation:[1,0,0],animation:0,walkRate:2200,runRate:4400}},m=new NetworkMotion(),s=m.ensure(actor);
 m.previewDrive(actor,drivePreviewPlan(s,3));m.update(.016);const position=s.position.slice();m.previewTurn(actor,[.8660254,.5,0]);m.update(.016);assert.deepEqual(s.position,position);assert.equal(s.active,false);assert.ok(s.orientation[1]>0);
});
test('input refreshes local preview and sequence twice as often as network drive transmission',async()=>{
 const events=new EventTarget(),doc=new EventTarget(),previews=[],packets=[];let time=0;
 const context={sessionId:'test',areaId:1,areaGeneration:1,actorId:1,position:[0,0,0],orientation:[1,0,0]},input=new NetworkKeyboardInput({context:()=>context,enabled:()=>true,events,document:doc,now:()=>time,send:async(_c,r)=>packets.push(r),preview:(_c,flags)=>previews.push(flags)});
 const e=new Event('keydown',{cancelable:true});Object.assign(e,{code:'KeyW',key:'w'});events.dispatchEvent(e);await input.queue;time=250;input.update();await input.queue;time=500;input.update();await input.queue;assert.equal(previews.length,3);assert.equal(packets.length,3);assert.deepEqual(packets.map(p=>p.transmit),[true,false,true]);
});
