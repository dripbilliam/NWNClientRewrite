import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {scriptCos,scriptSin} from '../src/script_scalar.js';
test('script cosine/sine match32790 exact float32 results of the original wrapper and SSE double CRT',()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-script-cos-observations.json',import.meta.url))),bits=new DataView(new ArrayBuffer(4));
  assert.equal(capture.degreesToRadians,0.01745329238474369);assert.equal(capture.observations.length,32790);
  for(const row of capture.observations){bits.setFloat32(0,(row.ordinal===68?scriptCos:scriptSin)(row.degrees),true);assert.equal(bits.getUint32(0,true),row.bits,JSON.stringify(row));}
  assert.throws(()=>scriptCos(Infinity),/exceptional/);assert.throws(()=>scriptCos(1025),/large-angle/);
});
