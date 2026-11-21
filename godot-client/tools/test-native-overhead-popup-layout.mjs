import assert from 'node:assert/strict';
import fs from 'node:fs';
import {nativePopupLayout} from './overhead-popup-layout-reference.mjs';
const path=new URL('../reports/native-overhead-popup-layout-original-v1.json',import.meta.url);
const oracle=JSON.parse(fs.readFileSync(path));
assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
assert.equal(oracle.cases.length,64);
const bits=n=>{const b=Buffer.alloc(4);b.writeFloatLE(n);return b.toString('hex');};
let checks=0;
for(const {case:input,result,placed} of oracle.cases){
 const before=structuredClone(input),actual=nativePopupLayout(input.rows,input.mode,input.enabled);
 assert.deepEqual(input,before,`${input.name} input source immutability`);checks++;
 assert.equal(actual.rows.length,result.length);
 for(let i=0;i<result.length;i++)for(const key of ['x','y','z']){assert.equal(bits(actual.rows[i][key]),bits(result[i][key]),`${input.name}/row${i}/${key}`);checks++;}
 assert.deepEqual(actual.placed.map(p=>({index:p.index,xyz:[p.x,p.y,p.z].map(bits)})),placed.map(p=>({index:p.index,xyz:p.bits})),`${input.name} exact native setter order/arguments`);checks++;
}
console.log(JSON.stringify({clean:true,cases:oracle.cases.length,checks,scope:'Original whole-routine x64 versus pure reference; GDScript/render integration remains unrun.'}));
