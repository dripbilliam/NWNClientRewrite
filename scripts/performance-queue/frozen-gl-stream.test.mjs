import test from 'node:test';import assert from 'node:assert/strict';import {captureFrozenGLCommands} from '../performance-candidates/frozen-gl-stream.mjs';
test('frozen commands snapshot mutable input bytes and leave normal methods intact',()=>{
 const calls=[],gl={getExtension:()=>null,uniform2fv(_location,value){calls.push([...value]);},drawArrays(){calls.push('draw');}},before=gl.uniform2fv,source=new Float32Array([1,2]),stream=captureFrozenGLCommands(gl,()=>{gl.uniform2fv({},source);source[0]=9;gl.uniform2fv({},source);gl.drawArrays();});assert.equal(gl.uniform2fv,before);calls.length=0;source.fill(44);stream.replay();assert.deepEqual(calls,[[1,2],[9,2],'draw']);assert.equal(stream.bytes,16);assert.deepEqual(stream.counts,{uniform2fv:2,drawArrays:1});stream.clear();calls.length=0;stream.replay();assert.equal(calls.length,0);
});
test('raw replay bypasses renderer instance hooks and restores wrappers after errors/capacity failures',()=>{
 class GL{getExtension(){return null;}drawArrays(){this.rawCalls++;}}const gl=new GL();gl.rawCalls=0;let observed=0;const native=gl.drawArrays;gl.drawArrays=function(...args){observed++;return native.apply(this,args);};const before=gl.drawArrays,stream=captureFrozenGLCommands(gl,()=>gl.drawArrays());stream.replay();assert.equal(observed,1);assert.equal(gl.rawCalls,2);assert.equal(gl.drawArrays,before);assert.throws(()=>captureFrozenGLCommands(gl,()=>{throw Error('source');}),/source/);assert.equal(gl.drawArrays,before);
 gl.uniform2fv=()=>{};const uniform=gl.uniform2fv;assert.throws(()=>captureFrozenGLCommands(gl,()=>gl.uniform2fv(null,new Float32Array(2)),{maxBytes:1}),/capacity/);assert.equal(gl.uniform2fv,uniform);stream.clear();
});
test('resource lifetime work is observed but cannot be replayed or silently claimed as a reusable frame',()=>{
 const gl={getExtension:()=>null,createBuffer:()=>({})},before=gl.createBuffer,stream=captureFrozenGLCommands(gl,()=>assert.ok(gl.createBuffer()));assert.equal(gl.createBuffer,before);assert.deepEqual(stream.unsupported,['createBuffer']);assert.throws(()=>stream.replay(),/lifetime/);stream.clear();
});
