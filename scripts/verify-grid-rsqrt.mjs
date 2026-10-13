import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import { nativeFastRsqrt } from '../src/path_grid_storage.js';
const capture=JSON.parse(await fs.readFile(process.argv[2],'utf8')),word=new DataView(new ArrayBuffer(4));
for(const [input,expected] of capture.observations){
  word.setUint32(0,input,true);const result=nativeFastRsqrt(word.getFloat32(0,true));word.setFloat32(0,result,true);
  assert.equal(word.getUint32(0,true),expected,`fast_rsqrt ${input.toString(16)}`);
}
console.log(JSON.stringify({reference:capture.reference,exactOutputs:capture.observations.length}));
