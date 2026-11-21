import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {calculateContentsWeight} from '../src/inventory_weight.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-contents-weight-observations.json',import.meta.url)));
test('Repository weight reduction, active/passive selection and repeated nested reads match original instructions',async()=>{
  for(const row of oracle.rows){const c=row.case,calls=[],repo={ownerId:99},nodes=Array.from({length:c.count??2},(_,i)=>({id:100+i}));let reads=0;
    const p={first:()=>nodes[0]??null,next:(_r,n)=>nodes[nodes.indexOf(n)+1]??null,nodeId:n=>n.id,
      item:id=>id===99?c.owner===false?null:{id}:c.missing?.includes(id)?null:{id},warning:()=>calls.push(['warning']),
      weightReduction:()=>{const p=[...(c.active??[]),...(c.passive??[])].find(p=>(p[0]&65535)===32);return p?{costValue:p[1]}:null;},
      repository:()=>c.nested?{ownerId:100}:null,unitWeight:()=>c.unit??10,stack:()=>c.stack??1,
      reductionValue:row=>{calls.push(['table',15],['row',row]);return c.reduction??.5;},
      contents:()=>{calls.push(['nested']);const values=c.nestedValues??[5,7];return values[Math.min(reads++,values.length-1)];}};
    assert.equal(await calculateContentsWeight(repo,p),row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
  }
});
