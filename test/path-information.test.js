import test from 'node:test';
import assert from 'node:assert/strict';
import { PathInformation } from '../src/path_information.js';

test('native path reset releases local search allocations while preserving owner, radius, target and untouched neighboring fields',()=>{
  const p=new PathInformation(0x80000000);
  assert.equal(p.field8,Math.fround(.6));assert.equal(p.field28,0);
  p.field8=.01;p.field28=7;
  p.raw.setUint32(0x40,43,true);p.raw.setUint32(0x5c,44,true);p.raw.setUint32(0x19c,1,true);
  p.raw.setUint32(0xcc,99,true);p.allocations.set(0x1d0,[{},{}]);p.raw.setInt32(0x1d8,2,true);
  p.resetAtEnd();
  assert.equal(p.raw.getUint32(0x24,true),0x80000000);assert.equal(p.field8,Math.fround(.01));assert.equal(p.field28,7);
  assert.equal(p.raw.getUint32(0x40,true),43);assert.equal(p.raw.getUint32(0x5c,true),44);
  assert.equal(p.raw.getUint32(0x19c,true),0);assert.equal(p.raw.getUint32(0xcc,true),0);
  assert.equal(p.raw.getUint32(0x78,true),1);assert.equal(p.raw.getFloat32(0x144,true),1);
  assert.equal(p.allocations.size,0);p.resetAtEnd();
});

test('unmapped native path search-node disposal retains work instead of discarding a live search',()=>{
  const p=new PathInformation(0),search={};p.allocations.set(0x118,search);p.raw.setUint32(0x19c,1,true);
  assert.throws(()=>p.resetAtEnd(),/search-node disposal/);
  assert.equal(p.allocations.get(0x118),search);assert.equal(p.raw.getUint32(0x19c,true),1);
});
