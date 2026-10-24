import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {lerpedVisualCurveValue} from '../src/visual_curve.js';
const observations=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-visual-transforms-v1.json',import.meta.url)));
const float=bits=>{const v=new DataView(new ArrayBuffer(4));v.setUint32(0,bits,true);return v.getFloat32(0,true);};
test('all native interpolation types and unknown types match original FLOAT branches',()=>{
 assert.equal(observations.curves.length,630);
 for(const row of observations.curves){
  const bytes=new Uint8Array(64),v=new DataView(bytes.buffer);v.setFloat32(4,row.target,true);v.setFloat32(8,row.source,true);v.setInt32(12,row.kind,true);
  const expected=float(row.bits),actual=lerpedVisualCurveValue(bytes,()=>Math.fround(row.progress));
  assert.ok(Math.abs(expected-actual)<=Math.max(1,Math.abs(expected))*2e-6,JSON.stringify({...row,expected,actual}));
 }
});
test('repeat endpoint mutation is read after progress and constant curves never sample a clock',()=>{
 const bytes=new Uint8Array(64),v=new DataView(bytes.buffer);v.setFloat32(4,2,true);
 assert.equal(lerpedVisualCurveValue(bytes,()=>{throw Error('No clock');}),2);
 v.setInt32(12,1,true);assert.equal(lerpedVisualCurveValue(bytes,()=>{v.setFloat32(4,4,true);return 1;}),4);
});
