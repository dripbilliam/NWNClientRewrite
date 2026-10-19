import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {correctClientMotion,NetworkMotion} from '../src/network_motion.js';import {clientMovementCue} from '../src/network_movement_cue.js';
test('208 complete original correction + animation owner calls match positions, timers, directional steps and queued speeds',()=>{
 const o=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-correction-observations.json',import.meta.url)));assert.equal(o.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(o.cases.length,208);
 for(const r of o.cases){const c={...r.case,position:r.case.position.map(Math.fround),render:r.case.render.map(Math.fround),orientation:r.case.orientation.map(Math.fround)},s={...structuredClone(c),correction:c.timer},position=correctClientMotion(s,c.position,c.dt);assert.equal(s.correction,r.timer);for(let i=0;i<3;i++)assert.ok(Math.abs(position[i]-r.render[i])<.000002,JSON.stringify({c,position,native:r.render}));assert.deepEqual(s.correctionCue?[s.correctionCue]:[],r.requests);const cues=s.correctionCue?[clientMovementCue(s.correctionCue,c.clipMs/1000)]:[];assert.deepEqual(cues,r.queues.map(q=>({...q,record:null})));}
});
test('correction is frame-driven even from world origin and uses horizontal snap threshold on vertical updates',()=>{
 const o={id:1,replicated:{position:[0,0,0],orientation:[1,0,0],animation:0}},m=new NetworkMotion();m.ensure(o);m.observe(o,{position:[1,0,0]});assert.deepEqual(m.pose(1).position.map(v=>v||0),[0,0,0]);m.update(.016);assert.ok(m.pose(1).position[0]>0&&m.pose(1).position[0]<1);assert.equal(m.objects.get(1).correctionCue.animation,24);
 m.observe(o,{position:[1,0,5]});m.update(.016);assert.ok(m.pose(1).position[1]<5);m.observe(o,{position:[20,0,5]});m.update(.016);assert.deepEqual(m.pose(1).position.map(v=>v||0),[20,5,0]);assert.equal(m.objects.get(1).correction,0);assert.deepEqual(o.replicated.position,[0,0,0]);
});
