import test from 'node:test';
import assert from 'node:assert/strict';
import {frameMetrics} from './frame-observer.mjs';
const observation=gaps=>({dropped:0,rows:gaps.map((gapMs,i)=>({at:i,gapMs}))});
test('frame rate weights all intervals instead of averaging sampled FPS',()=>{
  const result=frameMetrics(observation([10,10,80]));assert.equal(result.fps,30);assert.equal(result.averageMs,100/3);assert.equal(result.p95Ms,80);assert.equal(result.hitchesOver50Ms,1);
});
test('nearest-rank p95 and maximum retain rare loading freezes',()=>{
  const result=frameMetrics(observation([...Array(99).fill(16),8400]));assert.equal(result.p95Ms,16);assert.equal(result.maxMs,8400);assert.equal(result.freezesOver1000Ms,1);assert.equal(result.sampledLocalTargetMet,false);
});
test('empty and truncated observations cannot claim acceptance',()=>{
  for(const input of [null,observation([]),{...observation([16]),dropped:1}])assert.equal(frameMetrics(input).complete,false);
});
test('invalid observer intervals fail instead of producing misleading FPS',()=>{
  for(const gap of [0,-1,Infinity,NaN])assert.throws(()=>frameMetrics(observation([gap])),/Invalid RAF/);
});
test('short or slow samples cannot satisfy sustained local target',()=>{
  assert.equal(frameMetrics(observation(Array(119).fill(16))).sampledLocalTargetMet,false);assert.equal(frameMetrics(observation(Array(240).fill(40))).sampledLocalTargetMet,false);
});
test('sufficient fast sample records local threshold without completing overall goal',()=>{
  const result=frameMetrics(observation(Array(240).fill(16)));assert.equal(result.sampledLocalTargetMet,true);assert.ok(!('goalComplete' in result));
});
