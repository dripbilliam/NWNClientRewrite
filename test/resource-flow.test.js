import test from 'node:test';import assert from 'node:assert/strict';import {resourceFlow} from '../src/resource_flow.js';
test('ready resource work finishes in the calling frame and cold work resumes in order',async()=>{
 const run=provider=>resourceFlow((function*(){const one=yield provider(1),two=yield provider(one+1);return two*2;})());assert.equal(run(value=>value),4);
 const calls=[];let release;const cold=run(value=>{calls.push(value);return value===1?new Promise(r=>release=r):value;});assert.deepEqual(calls,[1]);release(1);assert.equal(await cold,4);assert.deepEqual(calls,[1,2]);
});
test('a cold-resource failure reaches the algorithm catch and releases its owner once',async()=>{
 const failure=new Error('Missing active-resource mesh');let released=0;const result=resourceFlow((function*(){try{yield Promise.reject(failure);assert.fail('Rejected IO continued');}catch(error){assert.equal(error,failure);return null;}finally{released++;}})());assert.equal(await result,null);assert.equal(released,1);
 assert.throws(()=>resourceFlow((function*(){yield 1;throw failure;})()),error=>error===failure);
 await assert.rejects(resourceFlow((function*(){yield Promise.resolve(1);throw failure;})()),error=>error===failure);
});
