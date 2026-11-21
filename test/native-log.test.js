import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {nativeLogfBranches} from '../src/native_log.js';
const view=new DataView(new ArrayBuffer(4)),float=r=>{view.setUint32(0,r,true);return view.getFloat32(0,true);},bits=v=>{view.setFloat32(0,v,true);return view.getUint32(0,true);};
test('portable log SSE matches6018 original executions; independent Windows CRT matches a traced branch',()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-logf-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
  for(const row of oracle.rows){const outputs=nativeLogfBranches(float(row.inputBits)).map(bits);
    assert.equal(outputs[0],row.outputs[0].bits,`original SSE input ${row.inputBits.toString(16)}`);
    assert.ok(outputs.includes(row.independentCrtBits),`independent Windows CRT input ${row.inputBits.toString(16)}`);
  }
});
test('unmapped log exceptional inputs remain unavailable',()=>{
  for(const input of [-1,NaN,Infinity,-Infinity])assert.throws(()=>nativeLogfBranches(input),/unavailable/);
  assert.deepEqual(nativeLogfBranches(0),[-Infinity,-Infinity]);
});
