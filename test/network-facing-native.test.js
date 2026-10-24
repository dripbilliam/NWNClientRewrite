import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {stepClientFacing} from '../src/network_facing.js';
import {NetworkMotion} from '../src/network_motion.js';
test('1176 complete original facing calls match finite vector turns, elapsed times and turn requests',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-facing-observations.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,1176);
 for(const row of oracle.cases){const c=row.case,result=stepClientFacing(c.orientation,c.target,c.animation,c.dt,c);for(const key of ['orientation','target'])for(let i=0;i<3;i++)assert.ok(Math.abs(result[key][i]-row[key][i])<2e-6,JSON.stringify({c,key,result,native:row}));assert.deepEqual(result.requests,row.requests);}
});
test('standing updates retain displayed facing and advance native turns on frames without changing authority',()=>{
 const object={id:0xffffffff,objectType:5,replicated:{position:[1,2,0],orientation:[1,0,0],animation:0}},motion=new NetworkMotion();motion.ensure(object);const before=structuredClone(object);motion.observe(object,{orientation:[0,1,0]});assert.equal(motion.pose(object.id).rotation,-Math.PI/2);
 motion.update(.016);const first=motion.pose(object.id).rotation;assert.ok(first> -Math.PI/2&&first<0);motion.update(.016);assert.ok(motion.pose(object.id).rotation>first);for(let i=0;i<120;i++)motion.update(.016);assert.ok(Math.abs(motion.pose(object.id).rotation)<.15);assert.deepEqual(object,before);
});

test('96 original facing calls handle long load frames through the native inline trig range',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-facing-stalls-observations.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,96);
 for(const row of oracle.cases){const c=row.case,result=stepClientFacing(c.orientation,c.target,c.animation,c.dt,c);for(const key of ['orientation','target'])for(let i=0;i<3;i++)assert.ok(Math.abs(result[key][i]-row[key][i])<2e-6,JSON.stringify({c,key,result,native:row}));assert.deepEqual(result.requests,row.requests);}
});

test('an unavailable facing branch diagnoses once, leaves server state intact and permits frame recovery',()=>{
 const issues=[],motion=new NetworkMotion({report:(...args)=>issues.push(args)}),object={id:0xffffffff,objectType:5,replicated:{position:[1,2,0],orientation:[1,0,0],animation:0}},other={...structuredClone(object),id:0xfffffff8},before=structuredClone(object);
 motion.ensure(object);motion.ensure(other);motion.observe(object,{orientation:[0,1,0]});
 assert.doesNotThrow(()=>motion.update(90000));assert.equal(issues.length,1);assert.equal(issues[0][0],'network.scene-facing-unavailable');assert.equal(issues[0][2].objectId,object.id);assert.deepEqual(object,before);
 motion.update(90000);assert.equal(issues.length,1);assert.deepEqual(motion.objects.get(object.id).orientation,[1,0,0]);
 motion.update(.016);assert.ok(motion.objects.get(object.id).orientation[1]>0);assert.equal(motion.objects.get(object.id).facingFailure,null);assert.deepEqual(object,before);
});
test('a right-angle server path keeps continuous heading between waypoints and retains native destination suppression',()=>{
 const object={id:2,objectType:5,replicated:{position:[0,0,0],orientation:[1,0,0],animation:4,walkRate:2200,runRate:4400}},motion=new NetworkMotion();motion.ensure(object);motion.observe(object,{path:[[.1,0],[.1,10]]});let last=motion.pose(2).rotation,maxTurn=0;
 for(let i=0;i<100;i++){motion.update(.016);const angle=motion.pose(2).rotation;maxTurn=Math.max(maxTurn,Math.abs(angle-last));last=angle;}assert.ok(maxTurn<.11);assert.ok(last> -1);const cursor=motion.objects.get(2).cursor;motion.observe(object,{path:[[.1,0],[.1,10]]});assert.equal(motion.objects.get(2).cursor,cursor);assert.deepEqual(object.replicated.position,[0,0,0]);
});
