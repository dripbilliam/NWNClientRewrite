import test from 'node:test';
import assert from 'node:assert/strict';
import {FrameWorkBudget} from '../src/frame_work_budget.js';
function fixture(budgetMs=2){let now=0,serial=0;const scheduled=new Map(),owner=new FrameWorkBudget({budgetMs,clock:()=>now,schedule:callback=>{scheduled.set(++serial,callback);return serial;},cancel:handle=>scheduled.delete(handle)});return{owner,advance:ms=>now+=ms,frame:()=>{const [id,callback]=scheduled.entries().next().value;scheduled.delete(id);callback();},scheduled};}

test('urgent tasks run first; budget overshoot yields before another task without dropping results',async()=>{
 const f=fixture(),order=[],job=(name,cost)=>()=>{order.push(name);f.advance(cost);return name;};
 const slow=f.owner.run(job('background',.5),{priority:2}),urgent=f.owner.run(job('player',3),{priority:0}),normal=f.owner.run(job('normal',.5));f.frame();assert.deepEqual(order,['player']);assert.equal(await urgent,'player');assert.equal(f.owner.snapshot().oversized,1);assert.equal(f.owner.snapshot().queued,2);f.frame();assert.deepEqual(await Promise.all([slow,normal]),['background','normal']);assert.deepEqual(order,['player','normal','background']);assert.equal(f.scheduled.size,0);
});

test('multipart async continuations consume remaining budget in the current frame',async()=>{
 const f=fixture(),order=[],multipart=(async()=>{for(let i=0;i<5;i++)await f.owner.run(()=>{order.push(i);f.advance(.3);},{kind:'model'});})();f.frame();for(let i=0;i<12;i++)await Promise.resolve();await multipart;assert.deepEqual(order,[0,1,2,3,4]);assert.equal(f.owner.snapshot().frames,1);assert.equal(f.scheduled.size,0);
});

test('expired budget sends the next continuation to a new frame and observes changed budget',async()=>{
 let budget=1;const f=fixture(()=>budget),first=f.owner.run(()=>f.advance(1.2));f.frame();await first;budget=4;const second=f.owner.run(()=>7);assert.equal(f.owner.snapshot().queued,1);f.frame();assert.equal(await second,7);assert.equal(f.owner.snapshot().frames,2);
});

test('stale owners, task exceptions and area disposal reject work and release scheduled references',async()=>{
 const f=fixture(),stale=f.owner.run(()=>assert.fail('Stale owner ran'),{current:()=>false}),failure=f.owner.run(()=>{throw Error('construction failed');});const handled=Promise.allSettled([stale,failure]);f.frame();assert.deepEqual((await handled).map(x=>x.status),['rejected','rejected']);assert.equal(f.owner.snapshot().cancelled,1);assert.equal(f.owner.snapshot().failed,1);
 f.advance(3);const pending=f.owner.run(()=>assert.fail('Closed area ran'));const rejected=assert.rejects(pending,{code:'FRAME_WORK_CLOSED'});f.owner.dispose();await rejected;assert.equal(f.scheduled.size,0);assert.equal(f.owner.snapshot().queued,0);assert.equal(f.owner.snapshot().active,0);await assert.rejects(f.owner.run(()=>{}),{code:'FRAME_WORK_CLOSED'});
});

test('task failures do not starve following work and async functions are outside the queue contract',async()=>{
 const f=fixture(),bad=f.owner.run(()=>Promise.resolve(1)),good=f.owner.run(()=>2),handled=Promise.allSettled([bad,good]);f.frame();const results=await handled;assert.match(results[0].reason.message,/synchronous/);assert.equal(results[1].value,2);assert.equal(f.owner.snapshot().completed,1);
});
