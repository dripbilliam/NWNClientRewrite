import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {sampleModelFloat,sampleModelVector,sampleModelQuaternion} from '../src/model_controller_sample.js';
test('scalar model controller sampling matches original including Bezier tails, runtime WORD index wrap and unsupported columns',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-float-sample-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,720);
 const pool=Float32Array.from({length:65600},(_,i)=>((i*13)%37-18)*.125);
 for(const row of oracle.rows){const c=row.case;pool.set(c.times);const output=[77.5];
  const result=sampleModelFloat({rows4:c.rows,columnsA:c.flags,timeIndex6:0,valueIndex8:c.valueBase},c.time,{values88:pool},output);
  assert.deepEqual({result,value:output[0]},{result:row.result,value:row.value},JSON.stringify(c));
 }
});

test('quaternion model controller sampling matches original CRT-backed cases including shortest path, nonunit inputs and full index sum',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-quaternion-sample-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,432);
 const pool=Float32Array.from({length:65600},(_,i)=>((i*13)%37-18)*.125);
 for(const row of oracle.rows){const c=row.case;pool.set(c.times);for(let i=0;i<c.quaternions.length;i++)pool.set(c.quaternions[i],c.valueBase+i*4);const output=[77.5,88.5,99.5,111.5];
  const result=sampleModelQuaternion({rows4:c.rows,columnsA:c.flags,timeIndex6:0,valueIndex8:c.valueBase},c.time,{values88:pool},output,{acos:Math.acos,sin:Math.sin});
  assert.deepEqual({result,value:output},{result:row.result,value:row.value},JSON.stringify(c));
 }
});

test('vector model controller sampling matches original including position-only scale, linear WORD wrap and unclamped Bezier tail',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-vector-sample-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,1152);
 const pool=Float32Array.from({length:65600},(_,i)=>((i*13)%37-18)*.125);
 for(const row of oracle.rows){const c=row.case;pool.set(c.times);const output=[77.5,88.5,99.5];
  const result=sampleModelVector({rows4:c.rows,columnsA:c.flags,timeIndex6:0,valueIndex8:c.valueBase,displacement0:c.displacement},c.time,{values88:pool},output,c.scale);
  assert.deepEqual({result,value:output},{result:row.result,value:row.value},JSON.stringify(c));
 }
});
