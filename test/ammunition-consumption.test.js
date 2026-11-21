import test from 'node:test';
import assert from 'node:assert/strict';
import {consumeAmmunition as consume} from '../src/ammunition.js';
test('consumption captures possessor first, decrements stack then equipped weight and calls encumbrance',async()=>{
  const item={id:0x80000001,stack:30},actor={id:2,nativeEquippedWeight968:100},trace=[];
  await consume(item,{possessor:()=>{trace.push('possessor');return actor.id;},creature:()=>{trace.push('creature');return actor;},
    stack:()=>{trace.push('stack');return item.stack;},writeStack:(i,n)=>{trace.push('write');i.stack=n;},inEquipment:()=>1,weight:()=>3,
    encumbrance:(o,n)=>{trace.push('encumbrance');assert.equal(n,1);assert.equal(o.nativeEquippedWeight968,97);}});
  assert.equal(item.stack,29);assert.deepEqual(trace,['possessor','creature','stack','write','encumbrance']);
});
test('last or nonpositive unit queues event11 with item as caller/target, preserving stack and captured possessor',async()=>{
  for(const stack of [1,0,-1]){
    const item={id:7,stack},actor={nativeEquippedWeight968:0},trace=[];
    await consume(item,{possessor:()=>2,creature:()=>actor,stack:()=>stack,aiMaster:()=> 'AI',
      enqueue:(...args)=>trace.push(args),inEquipment:()=>0,encumbrance:(o,n)=>trace.push([o,n])});
    assert.deepEqual(trace,[['AI',11,7,7,0,null],[actor,1]]);assert.equal(item.stack,stack);
  }
});
test('no current creature possessor still consumes stack without equipment/encumbrance query',async()=>{
  let after;
  await consume({id:1},{possessor:()=>0x7f000000,creature:()=>null,stack:()=>3,writeStack:(o,n)=>after=n});assert.equal(after,2);
});
