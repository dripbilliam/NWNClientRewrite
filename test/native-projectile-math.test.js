import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {nativeAcosf,nativePositiveLogf,nativeProjectileSpeedRange} from '../src/native_projectile_math.js';
import {nativeLogTable} from '../src/native_log_table.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-projectile-math-observations.json',import.meta.url))),v=new DataView(new ArrayBuffer(4)),bits=x=>{v.setFloat32(0,x,true);return v.getUint32(0,true);},number=x=>{v.setUint32(0,x,true);return v.getFloat32(0,true);};
test('projectile acos and both explicit native log CPU profiles match original CRT instruction results',()=>{
 for(const r of capture.rows){const input=number(r.bits),actual=r.kind==='acos'?nativeAcosf(input):nativePositiveLogf(input,r.dispatch);assert.equal(bits(actual),r.result,JSON.stringify(r));}
 assert.equal(capture.rows.length,6042);
 assert.deepEqual(nativeLogTable.inverse.map(bits),capture.tables.inverse);assert.deepEqual(nativeLogTable.head.map(bits),capture.tables.high);assert.deepEqual(nativeLogTable.tail.map(bits),capture.tables.low);
});
test('native projectile speed accepts interior log differences only when CPU profiles have the same observable integer bound',()=>{
 for(const r of capture.rows.filter(r=>r.kind==='log')){
  const x=number(r.bits),bound=d=>Math.abs(Math.trunc(Math.fround(nativePositiveLogf(x,d)*5)))+1,a=bound(0),b=bound(1);
  if(a!==b)assert.throws(()=>nativeProjectileSpeedRange(x),/CPU dispatch/);else assert.equal(nativeProjectileSpeedRange(x),a);
 }
 assert.throws(()=>nativeAcosf(2),/exceptional/);assert.throws(()=>nativePositiveLogf(0,0),/unavailable/);
});
