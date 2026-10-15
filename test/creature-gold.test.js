import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {setCreatureGold,addCreatureGold,removeCreatureGold} from '../src/creature_gold.js';
test('gold mutations match full original bodies across signed balances, overflow, caps and effective feedback deltas',async()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-gold-observations.json',import.meta.url)));
  assert.equal(capture.observations.length,900);
  for(const c of capture.observations){
    const actor={nativeGold898:c.old},calls=[];
    if(c.method==='set')setCreatureGold(actor,c.amount);
    else await (c.method==='add'?addCreatureGold:removeCreatureGold)(actor,c.amount,c.feedback,{feedback:(_o,code,data)=>calls.push({code,integers:data.integers})});
    assert.equal(actor.nativeGold898,c.balance,JSON.stringify(c));assert.deepEqual(calls,c.calls,JSON.stringify(c));
  }
});
test('gold storage and required feedback cannot silently become unavailable',async()=>{
  assert.throws(()=>setCreatureGold({},undefined),/unavailable/);
  await assert.rejects(()=>addCreatureGold({},1,0,{}),/stored balance/);
  await assert.rejects(()=>addCreatureGold({nativeGold898:0},1,1,{}),/feedback owner/);
});
