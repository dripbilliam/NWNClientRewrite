import test from 'node:test';import assert from 'node:assert/strict';
import fs from 'node:fs';
import {activityRequest,submitNativeActivity} from './activity-input.mjs';
test('Original input6/10 sender bytes and strict values',()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../reports/native-radial-activity-wire-v3.json',import.meta.url)));
 assert.equal(native.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of native.cases.filter(row=>row.format===1)){
  const actual=activityRequest(row.activityId,row.targetId),expected=Buffer.from(row.packet,'hex'),mask=row.lastBitOffset?255<<(8-row.lastBitOffset)&255:255;
  assert.equal(actual.length,expected.length);assert.deepEqual(Buffer.from(actual.subarray(0,-1)),expected.subarray(0,-1));assert.equal(actual.at(-1)&mask,expected.at(-1)&mask);
 }
 for(const value of [-1,2,256,0.5,'0',null,undefined])assert.throws(()=>activityRequest(value));
 for(const value of [-1,0x100000000,null,'99'])assert.throws(()=>activityRequest(5,value));
});

test('Counterspell requires the current other creature in the current area',async()=>{
 const actor={id:99},other={id:100,objectType:5,areaId:10},sent=[];
 const session={controlledActor:()=>actor,world:{registry:new Map([[99,actor],[100,other]])},peer:{sendGameMessage:async bytes=>sent.push([...bytes])}},scope={actor,actorId:99,areaId:10,areaGeneration:2};
 await submitNativeActivity(session,scope,{activityId:5,targetId:100});assert.deepEqual(sent,[[...activityRequest(5,100)]]);
 for(const targetId of [99,101])await assert.rejects(submitNativeActivity(session,scope,{activityId:5,targetId}),/current creature/);
 other.replicationRemoved=true;await assert.rejects(submitNativeActivity(session,scope,{activityId:5,targetId:100}),/current creature/);
 other.replicationRemoved=false;other.areaId=11;await assert.rejects(submitNativeActivity(session,scope,{activityId:5,targetId:100}),/current creature/);assert.equal(sent.length,1);
});
test('Only the current controlled actor can submit an activity',async()=>{
 const actor={id:99},sent=[];const session={controlledActor:(area,generation)=>{assert.equal(area,10);assert.equal(generation,2);return actor;},peer:{sendGameMessage:async bytes=>sent.push([...bytes])}};
 const scope={actor,actorId:99,areaId:10,areaGeneration:2};await submitNativeActivity(session,scope,{activityId:1});assert.deepEqual(sent,[[...activityRequest(1)]]);
 await assert.rejects(submitNativeActivity(session,{...scope,actor:{id:99}},{activityId:0}),/retired/);assert.equal(sent.length,1);
});
test('Native active Counterspell shortcut cancels with OBJECT_INVALID, only in server-confirmed mode4',async()=>{
 const actor={id:99,playerState:{playerFlags:512}},sent=[];const session={controlledActor:()=>actor,peer:{sendGameMessage:async bytes=>sent.push([...bytes])}},scope={actor,actorId:99,areaId:10,areaGeneration:2};
 await submitNativeActivity(session,scope,{activityId:5});assert.deepEqual(sent,[[...activityRequest(5,0x7f000000)]]);
 actor.playerState.playerFlags=0;await assert.rejects(submitNativeActivity(session,scope,{activityId:5,targetId:0x7f000000}),/server mode4/);assert.equal(sent.length,1);
});
