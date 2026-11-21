import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {performanceCandidateDefinitions,performanceCandidateFlags,validatePerformanceCandidateFlags,summarizeCandidateFrames} from '../performance-candidates/live-performance-profile.mjs';
import {transformLivePerformance} from './live-performance-transform.mjs';
test('baseline and all-candidate presets enumerate every flag without persistent storage',()=>{
 assert.equal(performanceCandidateDefinitions.length,11);assert.ok(Object.values(performanceCandidateFlags()).every(flag=>flag===false));assert.ok(Object.values(performanceCandidateFlags('candidates')).every(flag=>flag===true));assert.throws(()=>performanceCandidateFlags('unknown'));
});
test('invalid partial/extra/nonboolean candidate settings reject before application',()=>{
 for(const value of [{},{...performanceCandidateFlags(),extra:true},{...performanceCandidateFlags(),modelCache:'true'}])assert.throws(()=>validatePerformanceCandidateFlags(value));assert.deepEqual(validatePerformanceCandidateFlags(performanceCandidateFlags()),performanceCandidateFlags());
});
test('live diagnostics retain rare frame gaps and separate rendered frame count',()=>{
 const result=summarizeCandidateFrames([10,10,1000].map((gapMs,i)=>({gapMs,rendered:i!==2,workMs:5,renderMs:2,cameraMs:1,particlesMs:1,networkMs:1})));assert.equal(result.frames,3);assert.equal(result.renderedFrames,2);assert.equal(result.fps,3000/1020);assert.equal(result.maxMs,1000);assert.equal(result.p95Ms,1000);assert.equal(summarizeCandidateFrames([]),null);
});
test('live build connects actual per-area and frame hooks while retaining production default source',async()=>{
 const source=await fs.readFile(new URL('../../src/main.js',import.meta.url),'utf8'),result=transformLivePerformance(source);assert.ok(result.code.includes('presentation.qaAreaSettings={...qaPerformanceFlags}'));assert.ok(result.code.includes('qaPerformanceDiagnostics?.record(frameEnded,timing,!rendererWarmupCount)'));assert.ok(result.code.includes('cachedRootMatrices:qaPerformanceFlags.cachedRoots'));assert.ok(result.code.includes('qaPerformanceFlags.frameBudget'));assert.ok(!source.includes('qaPerformanceFlags'));
});
