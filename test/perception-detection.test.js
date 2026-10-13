import test from 'node:test';
import assert from 'node:assert/strict';
import { NativeRandom } from '../src/native_random.js';
import { initializePerceptionRolls,initializeCreaturePerception,detectMode,stealthDetection } from '../src/perception_detection.js';
function fixture(){
  const random=new NativeRandom(1),actor={animationState:0,nativeField6ec:0,nativeField6ed:0},target={},area={};
  initializePerceptionRolls(actor,random);const calls=[];
  const p={area:()=>area,dm:()=>0,worldTime:()=>({day:1,time:5999}),dayLength:7200000,
    hasFeat:()=>0,rollDice:(count,sides)=>{calls.push(['dice',count,sides]);return random.dice(count,sides);},
    listen:(a,b,flag)=>{calls.push(['listen',flag]);return 1;},spot:(a,b,flag)=>{calls.push(['spot',flag]);return 0;}};
  return {random,actor,target,area,p,calls};
}
test('native constructor detection cache consumes four CRT draws in MoveSilently/Hide/Spot/Listen order',()=>{
  const {actor,random}=fixture();assert.equal(random.draws,4);
  assert.deepEqual([actor.nativeMoveSilentlyRoll7c5,actor.nativeHideRoll7c4,actor.nativeSpotRoll7c6,actor.nativeListenRoll7c7],[2,8,5,1]);
  assert.equal(actor.nativeDetectionDay56c,0);assert.equal(actor.nativeDetectionTime570,0);
});
test('whole creature constructor consumes seven CRT draws in native order, including heartbeat and AI counters',()=>{
  const random=new NativeRandom(1),actor={};initializeCreaturePerception(actor,random);
  assert.equal(random.draws,7);assert.equal(actor.nativeHeartbeatInterval554,6041);
  assert.deepEqual([actor.nativeMoveSilentlyRoll7c5,actor.nativeHideRoll7c4,actor.nativeSpotRoll7c6,actor.nativeListenRoll7c7],[8,5,1,10]);
  assert.equal(actor.nativePerceptionCounter580,24);assert.equal(actor.nativeHeartbeatCounter584,78);
});
test('native detect mode respects Keen Senses, idle auto-detection and exact detect byte',async()=>{
  const {actor,p}=fixture();assert.equal(await detectMode(actor,p),2);
  actor.animationState=4;assert.equal(await detectMode(actor,p),0);
  actor.nativeField6ec=1;assert.equal(await detectMode(actor,p),1);
  actor.nativeField6ec=3;actor.animationState=0;assert.equal(await detectMode(actor,p),2);
  p.hasFeat=(a,id)=>Number(id===240);assert.equal(await detectMode(actor,p),1);
});
test('stealth detection refreshes at6000ms, evaluates Listen before Spot and retains cached hide rolls outside stealth1',async()=>{
  const {actor,target,p,calls,random}=fixture(),out={seen:9,heard:9};
  assert.equal(await stealthDetection(actor,target,1,out,1,p),1);assert.deepEqual(calls,[['listen',1],['spot',1]]);assert.equal(random.draws,4);
  calls.length=0;p.worldTime=()=>({day:1,time:6000});
  assert.equal(await stealthDetection(actor,target,1,out,0,p),1);
  assert.deepEqual(calls,[['dice',1,20],['dice',1,20],['listen',0],['spot',0]]);assert.equal(random.draws,6);
  assert.equal(actor.nativeHideRoll7c4,8);assert.deepEqual(out,{seen:0,heard:1});
  assert.equal(actor.nativeDetectionDay56c,1);assert.equal(actor.nativeDetectionTime570,6000);
  calls.length=0;await stealthDetection(actor,target,0,out,0,p);assert.deepEqual(calls,[['listen',0]]);
});
test('stealth1 refreshes Hide/MoveSilently before passive Spot/Listen dice; mode lookup repetition is observable',async()=>{
  const {actor,target,p,calls}=fixture(),out={};actor.nativeField6ed=1;actor.animationState=4;
  let feats=0;p.hasFeat=()=>{feats++;return 0;};p.worldTime=()=>({day:0,time:6000});
  await stealthDetection(actor,target,0,out,0,p);
  assert.deepEqual(calls,[['dice',1,20],['dice',1,20],['dice',1,10],['dice',1,10],['listen',0]]);assert.equal(feats,2);
});
test('DM, another area and absent targets zero both outputs without consuming dice or detection callbacks',async()=>{
  for(const mode of ['dm','area','null']){
    const {actor,target,p,calls,random}=fixture(),out={seen:1,heard:1};
    if(mode==='dm')p.dm=()=>2;if(mode==='area')p.area=o=>o===actor?{}:null;
    assert.equal(await stealthDetection(actor,mode==='null'?null:target,1,out,1,p),0);
    assert.deepEqual(out,{seen:0,heard:0});assert.equal(random.draws,4);assert.deepEqual(calls,[]);
  }
});
test('refresh compares elapsed remainder, while uninitialized time and unavailable callbacks fail explicitly',async()=>{
  const {actor,target,p,calls}=fixture(),out={seen:9,heard:9};
  p.worldTime=()=>({day:3,time:5999});await stealthDetection(actor,target,0,out,0,p);assert.deepEqual(calls,[['listen',0]]);
  actor.nativeDetectionDay56c=4;await assert.rejects(stealthDetection(actor,target,0,out,0,p),/uninitialized/);
  actor.nativeDetectionDay56c=0;p.listen=undefined;
  await assert.rejects(stealthDetection(actor,target,0,out,0,p),/provider listen/);
});
