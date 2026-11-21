import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptLog} from '../src/script_scalar.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-log-observations.json',import.meta.url)));
test('spell script log FLOAT outputs match original wrapper and double CRT SSE instructions',()=>{
  const b=new ArrayBuffer(4),v=new DataView(b);
  for(const row of oracle.rows){v.setUint32(0,row.inputBits,true);const result=scriptLog(v.getFloat32(0,true));v.setFloat32(0,result,true);assert.equal(v.getUint32(0,true),row.bits,`input ${row.inputBits.toString(16)}`);}
  assert.equal(new ModuleSession(null).commands.log([0]),0);
  assert.throws(()=>scriptLog(Infinity),/CRT exception owner/);
});
