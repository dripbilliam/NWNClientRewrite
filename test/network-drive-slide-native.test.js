import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {drivePreviewPath,drivePreviewPlan,partialDriveSendTimestamp} from '../src/network_drive_preview.js';
import {NetworkKeyboardInput} from '../src/network_keyboard_input.js';
import {NetworkMotion} from '../src/network_motion.js';
import {NetworkScene} from '../src/network_scene.js';import {Group} from 'three';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-drive-slide-v1.json',import.meta.url)));
test('original mode2 blocked-line search agrees on ordered queries, final admission, endpoint and speed factor',async()=>{
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,118);
 for(const [index,row]of oracle.cases.entries()){
  const c=row.case,queries=[],result=await drivePreviewPath(c.position,c.target,async(start,end)=>{
   const clear=c.planes.every(p=>end.reduce((n,v,i)=>n+(v-p.origin[i])*p.normal[i],0)<=(p.offset??0));queries.push({start,end,clear});return clear;
  },{render:c.render});
  const detail=JSON.stringify({index,c,result,native:row.paths,queries:queries.length,nativeQueries:row.queries.length});
  assert.equal(Boolean(result),Boolean(row.result),detail);assert.equal(queries.length,row.queries.length,detail);
  for(let q=0;q<queries.length;q++){assert.equal(queries[q].clear,row.queries[q].clear,detail+' query'+q);for(const key of ['start','end'])for(let i=0;i<3;i++)assert.ok(Math.abs(queries[q][key][i]-row.queries[q][key][i])<2e-5,detail+' query'+q);}
  if(result){for(let i=0;i<3;i++)assert.ok(Math.abs(result.target[i]-row.paths[0].points[1][i])<2e-5,detail);assert.ok(Math.abs(result.factor-row.factor)<2e-6,detail);}
 }
});
test('original held-key animation is selected even if both slide directions and the final path fail',()=>{
 assert.equal(oracle.blockedAnimation.length,8);
 for(const row of oracle.blockedAnimation){assert.equal(row.result,1);assert.deepEqual(row.paths,[]);const plan=drivePreviewPlan({...row.case,walkRate:2200,runRate:4400},row.case.flags);assert.deepEqual(row.animations,[plan.animation]);}
});
test('production scene restores the movement base after a short path finishes and supports a blocked animation without inventing a path',()=>{
 const actor={id:1,objectType:5,replicated:{position:[10,20,1],orientation:[1,0,0],animation:0,walkRate:2000,runRate:4000}},before=structuredClone(actor),motion=new NetworkMotion(),s=motion.ensure(actor),b={wrapper:new Group(),models:[{animator:{model:{animations:[]}}}],combat:{base:78,visual:78},animation:78},bases=[];
 const scene={closed:false,motion,world:{registry:new Map([[1,actor]])},objects:new Map([[1,b]]),animators:[],poses:{updateAttachments:()=>{}},combat:{base:(_o,a)=>{b.combat.base=b.combat.visual=a;bases.push(a);return true;},update:()=>{}},report:()=>{throw Error('Unexpected animation failure');}};
 motion.previewDrive(actor,{target:[10,20.01,1],facing:[1,0,0],animation:78});NetworkScene.prototype.update.call(scene,.02);assert.equal(b.combat.base,0);assert.equal(b.animation,0);
 // Also exercise a stale binding cache: the actual combat base owns playback.
 b.animation=78;motion.previewDrive(actor,{target:[10,20.81,1],facing:[1,0,0],animation:78});NetworkScene.prototype.update.call(scene,.016);assert.equal(b.combat.base,78);assert.deepEqual(bases,[0,78]);
 s.active=false;s.path=[];b.combat.base=b.combat.visual=0;motion.previewAnimation(actor,78);NetworkScene.prototype.update.call(scene,0);assert.equal(b.combat.base,78);assert.deepEqual(s.path,[]);assert.equal(s.active,false);assert.deepEqual(actor,before);
});
test('slide distance and native speed factor keep the full400ms lookahead without changing facing or server state',()=>{
 const actor={id:1,replicated:{position:[10,20,1],orientation:[1,0,0],animation:0,walkRate:2000,runRate:4000}},before=structuredClone(actor),motion=new NetworkMotion(),s=motion.ensure(actor);
 motion.previewDrive(actor,{target:[10,19.6,1],facing:[1,0,0],animation:4,factor:.25});motion.update(.25);
 assert.equal(s.active,true);assert.deepEqual(s.orientation,[1,0,0]);assert.ok(Math.abs(s.position[1]-19.75)<1e-5);assert.deepEqual(actor,before);
});
test('native partial resend can refresh before250ms and late geometry cannot rearm released or replaced input',async()=>{
 const events=new EventTarget(),doc=new EventTarget(),sent=[];let now=0,resolve,context={sessionId:'session',areaGeneration:1,areaId:1,actorId:1,position:[10,20,1],orientation:[1,0,0]};
 const input=new NetworkKeyboardInput({context:()=>context,enabled:()=>true,events,document:doc,now:()=>now,send:async(_c,r)=>sent.push(r),preview:()=>new Promise(r=>resolve=r)});
 const key=(type,code)=>{const e=new Event(type,{cancelable:true});Object.assign(e,{code,key:code.slice(3).toLowerCase()});events.dispatchEvent(e);};
 key('keydown','KeyW');await input.queue;resolve({resendFraction:.125});await Promise.resolve();
 now=62;input.update();await input.queue;assert.equal(sent.length,1);
 now=63;input.update();await input.queue;assert.equal(sent.length,2);assert.equal(sent[1].transmit,true);
 const oldResolve=resolve;key('keyup','KeyW');await input.queue;oldResolve({resendFraction:.01});await Promise.resolve();assert.equal(input.lastAt,-Infinity);
 key('keydown','KeyW');await input.queue;const areaResolve=resolve;context={...context,areaGeneration:2};input.update();areaResolve({resendFraction:.01});await Promise.resolve();assert.equal(input.lastAt,-Infinity);
});
test('partial path retains native speed and adjusts the wire timer using the original bisection fraction',async()=>{
 for(const row of oracle.partialLines){const c=row.case,result=await drivePreviewPath(c.position,c.target,async(_from,end)=>end[0]<=c.wall);assert.deepEqual(result.target,row.paths[0].points[1]);assert.equal(result.factor,row.factor);assert.equal(result.resendFraction,row.refresh[0]);}
 const timer=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-drive-refresh-v1.json',import.meta.url)));
 for(const row of timer.cases)assert.equal(Math.round(partialDriveSendTimestamp(row.nowMicroseconds/1000,row.fraction)*1000),row.lastWireMicroseconds);
});
