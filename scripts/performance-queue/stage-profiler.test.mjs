import test from 'node:test';
import assert from 'node:assert/strict';
import {installStageProfiler} from '../performance-candidates/stage-profiler.mjs';

test('stage times preserve receivers, arguments and results; nested durations stay inclusive',()=>{
 let time=0;const particles={marker:4,update(n){time+=n;return this.marker;}};
 const shadow={cache:{plan(){time+=2;}},instances:{list(){time+=3;}},original(){time+=5;return 17;},render(n){assert.equal(n,9);this.cache.plan();this.instances.list();return this.original();}};
 const profiler=installStageProfiler({particles,shadowTraversal:shadow,now:()=>time});
 assert.equal(particles.update(4),4);assert.equal(shadow.render(9),17);
 const sample=profiler.finishFrame();assert.deepEqual(sample.particleRuntime,{calls:1,totalMs:4,maxMs:4});assert.equal(sample.shadowTotal.totalMs,10);assert.equal(sample.shadowSubmission.totalMs,5);assert.equal(sample.shadowInputs.totalMs,2);assert.equal(sample.shadowGrouping.totalMs,3);
 const copy=profiler.snapshot();copy.shadowTotal.totalMs=999;assert.equal(profiler.snapshot().shadowTotal.totalMs,10);assert.deepEqual(profiler.finishFrame(),{});profiler.dispose();
});

test('exception and teardown restore only owned methods and leave later replacements intact',()=>{
 let time=0;const error=Error('expected'),particles={update(){time+=7;throw error;}},original=particles.update,shadow={render(){}};
 const profiler=installStageProfiler({particles,shadowTraversal:shadow,now:()=>time});assert.throws(()=>particles.update(),value=>value===error);assert.equal(profiler.finishFrame().particleRuntime.totalMs,7);
 const replacement=()=>42;shadow.render=replacement;profiler.dispose();assert.equal(particles.update,original);assert.equal(shadow.render,replacement);profiler.dispose();assert.deepEqual(profiler.snapshot(),{});
});
